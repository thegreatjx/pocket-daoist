#!/usr/bin/env python3
"""《百宝小道修》全自动 BGM 切片、无缝循环与 -14 LUFS 响度标准化管线。"""

from __future__ import annotations

import argparse
import json
import math
import pathlib
import re
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from typing import Optional

import numpy as np
from scipy.io import wavfile
from scipy.signal import correlate, stft

SAMPLE_RATE = 44100
CHANNELS = 2
XFADE_SEC = 1.8
OGG_QUALITY = "5"
RAW_EXTS = (".mp3", ".wav")


@dataclass(frozen=True)
class TrackSpec:
    raw_stem: str
    out_name: str
    min_dur: float
    max_dur: float
    pref_dur: float
    strategy: str
    search_range: tuple[float, float] = (0.0, 1.0)


SINGLE_SPECS: tuple[TrackSpec, ...] = (
    TrackSpec("raw_lobby", "bgm_lobby.ogg", 45.0, 65.0, 55.0, "mid_stable"),
    TrackSpec("raw_forest", "bgm_forest.ogg", 60.0, 80.0, 70.0, "high_energy_stable"),
    TrackSpec("raw_volcano", "bgm_volcano.ogg", 60.0, 80.0, 70.0, "high_energy_stable"),
    TrackSpec("raw_ice", "bgm_ice.ogg", 60.0, 80.0, 70.0, "high_energy_stable"),
    TrackSpec("raw_miniboss", "bgm_miniboss.ogg", 45.0, 65.0, 54.0, "urgent_high_energy"),
    TrackSpec("raw_drums", "loop_tension_drums.ogg", 12.0, 20.0, 16.0, "drum_loop"),
)

BOSS_P1_SPEC = TrackSpec(
    "raw_boss_p1", "bgm_boss_p1.ogg", 45.0, 60.0, 52.0, "mid_high_energy", (0.08, 0.72)
)
BOSS_P2_SPEC = TrackSpec(
    "raw_boss_p2", "bgm_boss_p2.ogg", 40.0, 55.0, 48.0, "climax_peak", (0.45, 1.0)
)


def find_raw_file(raw_dir: pathlib.Path, stem: str) -> Optional[pathlib.Path]:
    for ext in RAW_EXTS:
        candidate = raw_dir / f"{stem}{ext}"
        if candidate.is_file():
            return candidate
    return None


def run_cmd(cmd: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )


def decode_to_wav(src_path: pathlib.Path, wav_path: pathlib.Path) -> np.ndarray:
    cmd = [
        "ffmpeg",
        "-y",
        "-hide_banner",
        "-loglevel",
        "error",
        "-i",
        str(src_path),
        "-ar",
        str(SAMPLE_RATE),
        "-ac",
        str(CHANNELS),
        "-c:a",
        "pcm_s16le",
        str(wav_path),
    ]
    res = run_cmd(cmd)
    if res.returncode != 0:
        raise RuntimeError(f"ffmpeg decode failed for {src_path.name}: {res.stderr.strip()}")
    sr, data = wavfile.read(wav_path)
    if sr != SAMPLE_RATE:
        raise RuntimeError(f"Unexpected sample rate {sr} for {src_path.name}")
    if data.ndim == 1:
        data = np.stack([data, data], axis=1)
    audio = data.astype(np.float32) / 32768.0
    return np.ascontiguousarray(audio)


def compute_rms_envelope(mono: np.ndarray, win_sec: float = 0.5, hop_sec: float = 0.1) -> tuple[np.ndarray, int]:
    win = max(1, int(round(win_sec * SAMPLE_RATE)))
    hop = max(1, int(round(hop_sec * SAMPLE_RATE)))
    sq = np.square(mono, dtype=np.float64)
    csum = np.concatenate(([0.0], np.cumsum(sq)))
    starts = np.arange(0, max(1, len(mono) - win + 1), hop)
    means = (csum[starts + win] - csum[starts]) / float(win)
    rms = np.sqrt(np.maximum(means, 1e-12))
    return rms.astype(np.float32), hop


def trim_intro_outro(mono: np.ndarray, min_required_sec: float) -> tuple[int, int]:
    """基于滑动窗口 RMS 包络跳过低能量前奏与渐弱尾奏，同时保证最小可用长度。"""
    n_samples = len(mono)
    min_required_samples = int(round(min_required_sec * SAMPLE_RATE))
    if n_samples <= min_required_samples:
        return 0, n_samples

    rms, hop = compute_rms_envelope(mono, win_sec=0.5, hop_sec=0.1)
    if len(rms) < 10:
        return 0, n_samples

    rms_ref = float(np.percentile(rms, 75))
    best_span = (0, n_samples)

    for ratio in (0.45, 0.35, 0.25, 0.15):
        thresh = max(1e-4, rms_ref * ratio)
        active = np.where(rms >= thresh)[0]
        if len(active) == 0:
            continue
        s_idx = int(active[0]) * hop
        e_idx = min(n_samples, int(active[-1] + 5) * hop)
        if e_idx - s_idx >= min_required_samples:
            best_span = (s_idx, e_idx)
            break

    return best_span


def compute_normalized_stft(mono: np.ndarray, nperseg: int = 2048, noverlap: int = 1024) -> tuple[np.ndarray, float]:
    _, _, zxx = stft(
        mono,
        fs=SAMPLE_RATE,
        window="hann",
        nperseg=nperseg,
        noverlap=noverlap,
        boundary=None,
        padded=False,
    )
    mag = np.log1p(np.abs(zxx)).T  # (n_frames, n_bins)
    norms = np.linalg.norm(mag, axis=1, keepdims=True)
    mag = mag / np.maximum(norms, 1e-8)
    hop_sec = float(nperseg - noverlap) / float(SAMPLE_RATE)
    return mag.astype(np.float32), hop_sec


def score_window_energy(
    rms: np.ndarray,
    hop_samples: int,
    start_sample: int,
    dur_samples: int,
    strategy: str,
    rel_pos: float,
) -> float:
    i0 = max(0, start_sample // hop_samples)
    i1 = min(len(rms), (start_sample + dur_samples) // hop_samples)
    if i1 <= i0 + 1:
        return 0.0
    seg = rms[i0:i1]
    mean_e = float(np.mean(seg))
    std_e = float(np.std(seg))
    cv = std_e / max(mean_e, 1e-6)

    if strategy == "mid_stable":
        center_bonus = 1.0 - abs(rel_pos - 0.40)
        return mean_e * 0.7 + center_bonus * 0.12 - cv * 0.35
    if strategy == "high_energy_stable":
        return mean_e * 1.15 - cv * 0.30
    if strategy == "urgent_high_energy":
        return mean_e * 1.25 + float(np.percentile(seg, 85)) * 0.35 - cv * 0.18
    if strategy == "mid_high_energy":
        return mean_e * 1.10 - cv * 0.28
    if strategy == "climax_peak":
        return mean_e * 1.35 + float(np.percentile(seg, 92)) * 0.45 - cv * 0.12
    if strategy == "drum_loop":
        return mean_e * 1.0 - cv * 0.55
    return mean_e


def align_zero_crossing(mono: np.ndarray, idx: int, search_radius: int) -> int:
    lo = max(1, idx - search_radius)
    hi = min(len(mono) - 1, idx + search_radius)
    if lo >= hi:
        return idx
    seg_prev = mono[lo - 1 : hi]
    seg_curr = mono[lo : hi + 1]
    crossings = np.where((seg_prev <= 0.0) & (seg_curr > 0.0))[0]
    if len(crossings) > 0:
        abs_idx = lo + crossings
        nearest = abs_idx[int(np.argmin(np.abs(abs_idx - idx)))]
        return int(nearest)
    # 退化兜底：选振幅绝对值最小的采样点
    abs_min = int(np.argmin(np.abs(mono[lo : hi + 1])))
    return lo + abs_min


def select_seamless_loop(
    audio: np.ndarray,
    spec: TrackSpec,
    search_range_override: Optional[tuple[float, float]] = None,
) -> tuple[np.ndarray, dict[str, float]]:
    mono = np.mean(audio, axis=1, dtype=np.float32)
    xfade_samples = int(round(XFADE_SEC * SAMPLE_RATE))
    min_samples = int(round(spec.min_dur * SAMPLE_RATE))
    max_samples = int(round(spec.max_dur * SAMPLE_RATE))

    act_start, act_end = trim_intro_outro(mono, spec.min_dur + XFADE_SEC + 0.5)
    act_len = act_end - act_start

    # 若活跃段受源音频总长限制，安全收紧目标区间而不越界
    eff_max = min(max_samples, act_len - xfade_samples - 1024)
    eff_min = min(min_samples, max(int(8.0 * SAMPLE_RATE), eff_max - int(2.0 * SAMPLE_RATE)))
    if eff_max < eff_min:
        eff_min = max(int(4.0 * SAMPLE_RATE), eff_max)

    active_mono = mono[act_start:act_end]
    rms, rms_hop = compute_rms_envelope(active_mono, win_sec=0.4, hop_sec=0.1)
    mag, frame_hop_sec = compute_normalized_stft(active_mono)
    xfade_frames = max(4, int(round(XFADE_SEC / frame_hop_sec)))

    sr_lo, sr_hi = search_range_override if search_range_override else spec.search_range
    max_start_sample = max(0, len(active_mono) - eff_min - xfade_samples - 256)
    s_lo = int(sr_lo * max_start_sample)
    s_hi = max(s_lo + 1, int(sr_hi * max_start_sample))

    # 步长约 0.5s 搜索候选起点与终点
    step_s = max(1, int(round(0.5 * SAMPLE_RATE)))
    step_d = max(1, int(round(0.5 * SAMPLE_RATE)))
    candidate_starts = list(range(s_lo, s_hi + 1, step_s))
    if not candidate_starts:
        candidate_starts = [s_lo]

    # 先按能量策略筛出 Top-12 起点，加快频谱网格搜索
    scored_starts: list[tuple[float, int]] = []
    pref_len_samples = int(round(min(spec.pref_dur, eff_max / float(SAMPLE_RATE)) * SAMPLE_RATE))
    for s in candidate_starts:
        rel_pos = s / float(max(1, len(active_mono)))
        e_score = score_window_energy(rms, rms_hop, s, pref_len_samples, spec.strategy, rel_pos)
        scored_starts.append((e_score, s))
    scored_starts.sort(key=lambda x: x[0], reverse=True)
    top_starts = [s for _, s in scored_starts[:12]]

    best_score = -1e9
    best_s = top_starts[0]
    best_e = min(len(active_mono) - xfade_samples - 1, best_s + pref_len_samples)

    max_end_limit = len(active_mono) - xfade_samples - 1
    for s in top_starts:
        sf = min(len(mag) - xfade_frames - 1, int(round(s / (frame_hop_sec * SAMPLE_RATE))))
        if sf < 0:
            continue
        start_patch = mag[sf : sf + xfade_frames]
        rms_s = float(np.mean(rms[min(len(rms) - 1, s // rms_hop) : min(len(rms), (s + xfade_samples) // rms_hop + 1)]))

        d_lo = eff_min
        d_hi = min(eff_max, max_end_limit - s)
        if d_hi < d_lo:
            continue
        for d in range(d_lo, d_hi + 1, step_d):
            e = s + d
            ef = min(len(mag) - xfade_frames - 1, int(round(e / (frame_hop_sec * SAMPLE_RATE))))
            if ef <= sf:
                continue
            end_patch = mag[ef : ef + xfade_frames]
            spec_sim = float(np.mean(np.sum(start_patch * end_patch, axis=1)))
            rms_e = float(np.mean(rms[min(len(rms) - 1, e // rms_hop) : min(len(rms), (e + xfade_samples) // rms_hop + 1)]))
            rms_diff = abs(rms_s - rms_e) / max(rms_s, rms_e, 1e-6)
            dur_sec = d / float(SAMPLE_RATE)
            dur_pen = abs(dur_sec - spec.pref_dur) / max(1.0, spec.max_dur - spec.min_dur)
            rel_pos = s / float(max(1, len(active_mono)))
            e_bonus = score_window_energy(rms, rms_hop, s, d, spec.strategy, rel_pos)
            total = spec_sim * 1.40 - rms_diff * 0.45 - dur_pen * 0.10 + e_bonus * 0.30
            if total > best_score:
                best_score = total
                best_s = s
                best_e = e

    # 波形互相关精调（在 e ± 60ms 内寻找相位最对齐的位置）
    corr_pad = int(round(0.06 * SAMPLE_RATE))
    ref_wave = active_mono[best_s : best_s + xfade_samples]
    search_lo = max(best_s + eff_min, best_e - corr_pad)
    search_hi = min(len(active_mono) - xfade_samples - 1, best_e + corr_pad)
    if search_hi > search_lo:
        cand_wave = active_mono[search_lo : search_hi + xfade_samples]
        if len(cand_wave) >= len(ref_wave):
            xc = correlate(cand_wave, ref_wave, mode="valid", method="fft")
            best_offset = int(np.argmax(xc))
            best_e = search_lo + best_offset

    # 零交叉点对齐（±15ms）
    zc_radius = int(round(0.015 * SAMPLE_RATE))
    best_s = align_zero_crossing(active_mono, best_s, zc_radius)
    best_e = align_zero_crossing(active_mono, best_e, zc_radius)
    best_e = max(best_s + eff_min, min(len(active_mono) - xfade_samples - 1, best_e))

    # 映射到全曲坐标并做 1.8s 等功率交叉淡化
    abs_s = act_start + best_s
    abs_e = act_start + best_e
    loop_len = abs_e - abs_s
    out = audio[abs_s:abs_e].copy()
    tail_fade = audio[abs_e : abs_e + xfade_samples]
    head_fade = audio[abs_s : abs_s + xfade_samples]

    theta = np.linspace(0.0, math.pi * 0.5, xfade_samples, dtype=np.float32)[:, None]
    out[:xfade_samples] = tail_fade * np.cos(theta) + head_fade * np.sin(theta)
    out = np.clip(out, -0.999, 0.999)

    info = {
        "src_start_sec": abs_s / float(SAMPLE_RATE),
        "src_end_sec": abs_e / float(SAMPLE_RATE),
        "loop_dur_sec": loop_len / float(SAMPLE_RATE),
        "score": float(best_score),
    }
    return out, info


def encode_loudnorm_ogg(loop_audio: np.ndarray, out_ogg: pathlib.Path, tmp_dir: pathlib.Path) -> None:
    tmp_wav = tmp_dir / f"{out_ogg.stem}_loop.wav"
    pcm16 = np.round(np.clip(loop_audio, -1.0, 1.0) * 32767.0).astype(np.int16)
    wavfile.write(tmp_wav, SAMPLE_RATE, pcm16)

    # Pass 1: 测量响度参数
    pass1_cmd = [
        "ffmpeg",
        "-y",
        "-hide_banner",
        "-i",
        str(tmp_wav),
        "-af",
        "loudnorm=I=-14:TP=-1.5:LRA=11:print_format=json",
        "-f",
        "null",
        "-",
    ]
    res1 = run_cmd(pass1_cmd)
    if res1.returncode != 0:
        raise RuntimeError(f"loudnorm pass1 failed for {out_ogg.name}: {res1.stderr.strip()}")

    m = re.search(r"\{\s*\"input_i\".*?\}", res1.stderr, re.S)
    if not m:
        raise RuntimeError(f"Cannot parse loudnorm JSON for {out_ogg.name}")
    stats = json.loads(m.group(0))

    # Pass 2: 线性模式标准化到 -14 LUFS，输出 44.1kHz 立体声 Ogg Vorbis Q5
    af_pass2 = (
        "loudnorm=I=-14:TP=-1.5:LRA=11:"
        f"measured_I={stats['input_i']}:"
        f"measured_LRA={stats['input_lra']}:"
        f"measured_TP={stats['input_tp']}:"
        f"measured_thresh={stats['input_thresh']}:"
        f"offset={stats['target_offset']}:"
        "linear=true:print_format=summary"
    )
    pass2_cmd = [
        "ffmpeg",
        "-y",
        "-hide_banner",
        "-loglevel",
        "error",
        "-i",
        str(tmp_wav),
        "-af",
        af_pass2,
        "-ar",
        str(SAMPLE_RATE),
        "-ac",
        str(CHANNELS),
        "-c:a",
        "libvorbis",
        "-q:a",
        OGG_QUALITY,
        str(out_ogg),
    ]
    res2 = run_cmd(pass2_cmd)
    if res2.returncode != 0:
        raise RuntimeError(f"loudnorm pass2 failed for {out_ogg.name}: {res2.stderr.strip()}")


def measure_ogg_metrics(ogg_path: pathlib.Path) -> tuple[float, float, float, float]:
    dur_res = run_cmd(
        [
            "ffprobe",
            "-v",
            "error",
            "-show_entries",
            "format=duration",
            "-of",
            "default=noprint_wrappers=1:nokey=1",
            str(ogg_path),
        ]
    )
    duration = float(dur_res.stdout.strip()) if dur_res.returncode == 0 else 0.0

    ln_res = run_cmd(
        [
            "ffmpeg",
            "-hide_banner",
            "-i",
            str(ogg_path),
            "-af",
            "loudnorm=I=-14:TP=-1.5:LRA=11:print_format=json",
            "-f",
            "null",
            "-",
        ]
    )
    lufs = -99.0
    tp = -99.0
    m = re.search(r"\{\s*\"input_i\".*?\}", ln_res.stderr, re.S)
    if m:
        st = json.loads(m.group(0))
        lufs = float(st.get("input_i", -99.0))
        tp = float(st.get("input_tp", -99.0))

    size_kb = ogg_path.stat().st_size / 1024.0
    return duration, lufs, tp, size_kb


def ensure_godot_loop_imports(out_dir: pathlib.Path) -> int:
    """确保输出目录下所有 .ogg.import 开启 loop=true；若尚不存在则写最小合法配置。"""
    updated = 0
    for ogg_path in sorted(out_dir.glob("*.ogg")):
        imp_path = ogg_path.with_name(ogg_path.name + ".import")
        if imp_path.exists():
            txt = imp_path.read_text(encoding="utf-8", errors="replace")
            if re.search(r"(?m)^loop\s*=\s*true\b", txt):
                continue
            if re.search(r"(?m)^loop\s*=", txt):
                new_txt = re.sub(r"(?m)^loop\s*=.*$", "loop=true", txt)
            else:
                new_txt = txt.rstrip() + "\nloop=true\n"
            imp_path.write_text(new_txt, encoding="utf-8")
            updated += 1
        else:
            minimal = (
                '[remap]\n\nimporter="oggvorbisstr"\ntype="AudioStreamOggVorbis"\n\n'
                "[params]\n\nloop=true\nloop_offset=0\nbpm=0\nbeat_count=0\nbar_beats=4\n"
            )
            imp_path.write_text(minimal, encoding="utf-8")
            updated += 1
    return updated


def process_one(
    raw_path: pathlib.Path,
    spec: TrackSpec,
    out_dir: pathlib.Path,
    tmp_dir: pathlib.Path,
    search_range_override: Optional[tuple[float, float]] = None,
) -> tuple[str, float, float, float, float, float, float]:
    wav_path = tmp_dir / f"{spec.out_name}.decoded.wav"
    audio = decode_to_wav(raw_path, wav_path)
    looped, info = select_seamless_loop(audio, spec, search_range_override)
    out_ogg = out_dir / spec.out_name
    encode_loudnorm_ogg(looped, out_ogg, tmp_dir)
    dur, lufs, tp, size_kb = measure_ogg_metrics(out_ogg)
    return (
        spec.out_name,
        dur,
        lufs,
        tp,
        size_kb,
        info["src_start_sec"],
        info["src_end_sec"],
    )


def main() -> int:
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, OSError):
        pass

    root = pathlib.Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser(description="Pocket Daoist BGM Slicer & Seamless Loop Builder")
    parser.add_argument("--raw-dir", default=str(root / "assets/audio/raw"))
    parser.add_argument("--out-dir", default=str(root / "assets/audio/bgm"))
    parser.add_argument("--fix-imports-only", action="store_true", help="Only enforce loop=true in .ogg.import")
    args = parser.parse_args()

    raw_dir = pathlib.Path(args.raw_dir)
    out_dir = pathlib.Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    if args.fix_imports_only:
        cnt = ensure_godot_loop_imports(out_dir)
        print(f"[Imports] Updated loop=true on {cnt} .ogg.import file(s) in {out_dir}")
        return 0

    results: list[tuple[str, float, float, float, float, float, float]] = []
    skipped: list[str] = []

    with tempfile.TemporaryDirectory(prefix="bgm_slice_") as tmp_str:
        tmp_dir = pathlib.Path(tmp_str)

        for spec in SINGLE_SPECS:
            raw_path = find_raw_file(raw_dir, spec.raw_stem)
            if raw_path is None:
                print(f"[SKIP] {spec.raw_stem}.(mp3/wav) not found -> skip {spec.out_name}")
                skipped.append(spec.out_name)
                continue
            print(f"[PROC] {raw_path.name} -> {spec.out_name} ...")
            results.append(process_one(raw_path, spec, out_dir, tmp_dir))

        raw_boss_combined = find_raw_file(raw_dir, "raw_boss")
        raw_p1 = find_raw_file(raw_dir, "raw_boss_p1") or raw_boss_combined
        raw_p2 = find_raw_file(raw_dir, "raw_boss_p2") or raw_boss_combined

        if raw_p1 is None:
            print("[SKIP] raw_boss_p1 / raw_boss not found -> skip bgm_boss_p1.ogg")
            skipped.append("bgm_boss_p1.ogg")
        else:
            p1_range = (0.10, 0.65) if raw_p1 == raw_boss_combined else (0.0, 1.0)
            print(f"[PROC] {raw_p1.name} -> {BOSS_P1_SPEC.out_name} ...")
            results.append(process_one(raw_p1, BOSS_P1_SPEC, out_dir, tmp_dir, p1_range))

        if raw_p2 is None:
            print("[SKIP] raw_boss_p2 / raw_boss not found -> skip bgm_boss_p2.ogg")
            skipped.append("bgm_boss_p2.ogg")
        else:
            p2_range = (0.50, 1.0) if raw_p2 == raw_boss_combined else (0.0, 1.0)
            print(f"[PROC] {raw_p2.name} -> {BOSS_P2_SPEC.out_name} ...")
            results.append(process_one(raw_p2, BOSS_P2_SPEC, out_dir, tmp_dir, p2_range))

    imp_updated = ensure_godot_loop_imports(out_dir)

    print("\n=== BGM 处理报告 ===")
    print(f"{'输出文件':<26} {'时长(s)':>8} {'响度(LUFS)':>11} {'峰值(dBTP)':>11} {'体积(KB)':>10} {'源切片区间(s)':>16}")
    print("-" * 88)
    for name, dur, lufs, tp, size_kb, s0, s1 in results:
        span = f"{s0:.1f}~{s1:.1f}"
        print(f"{name:<26} {dur:>8.2f} {lufs:>11.2f} {tp:>11.2f} {size_kb:>10.1f} {span:>16}")
    print("-" * 88)
    print(f"完成 {len(results)} 首，跳过 {len(skipped)} 首，更新 .import loop=true: {imp_updated} 个。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
