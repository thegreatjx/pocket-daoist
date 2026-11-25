import math
import os
import wave
import av
import numpy as np
from scipy import signal

SR = 44100
SAMPLE_DIR = r"C:\Users\jiang\.gemini\antigravity\brain\ae5e230a-1459-41fc-b001-30b3232451c2\scratch\cc0_samples"
PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(PROJECT_ROOT, "assets", "audio")


def load_flac_mono(path: str) -> np.ndarray:
    container = av.open(path)
    stream = container.streams.audio[0]
    resampler = av.audio.resampler.AudioResampler(format="flt", layout="mono", rate=SR)
    chunks = []
    for frame in container.decode(stream):
        for rf in resampler.resample(frame):
            chunks.append(rf.to_ndarray().reshape(-1))
    container.close()
    if not chunks:
        return np.zeros(1, dtype=np.float32)
    audio = np.concatenate(chunks).astype(np.float32)
    # Trim leading silence for snappy rhythmic alignment
    idx = np.where(np.abs(audio) > 0.008)[0]
    if len(idx) > 0:
        start = max(0, int(idx[0]) - 64)
        audio = audio[start:]
    peak = float(np.max(np.abs(audio)))
    if peak > 1e-5:
        audio = audio / peak
    return audio


def pitch_shift(audio: np.ndarray, semitones: float) -> np.ndarray:
    if abs(semitones) < 1e-3:
        return audio.copy()
    ratio = 2.0 ** (semitones / 12.0)
    new_len = max(16, int(round(len(audio) / ratio)))
    x_old = np.linspace(0.0, 1.0, len(audio), dtype=np.float64)
    x_new = np.linspace(0.0, 1.0, new_len, dtype=np.float64)
    return np.interp(x_new, x_old, audio).astype(np.float32)


class InstrumentBank:
    def __init__(self) -> None:
        self.guzheng: dict[int, np.ndarray] = {}
        self.xiao: dict[int, np.ndarray] = {}
        gz_map = {
            38: "guzheng-38-v1-rr1.flac",
            43: "guzheng-43-v1-rr1.flac",
            45: "guzheng-45-v1-rr1.flac",
            50: "guzheng-50-v1-rr1.flac",
            55: "guzheng-55-v1-rr1.flac",
            57: "guzheng-57-v1-rr1.flac",
            60: "guzheng-60-v1-rr1.flac",
            62: "guzheng-62-v1-rr1.flac",
            67: "guzheng-67-v1-rr1.flac",
            72: "guzheng-72-v1-rr1.flac",
            74: "guzheng-74-v1-rr1.flac",
            79: "guzheng-79-v1-rr1.flac",
            86: "guzheng-86-v1-rr1.flac",
        }
        for midi, fname in gz_map.items():
            p = os.path.join(SAMPLE_DIR, "guzheng", fname)
            if os.path.exists(p):
                self.guzheng[midi] = load_flac_mono(p)

        xiao_map = {
            60: "TenRecorder_SusVib_C3_rr1_Main-xiao.flac",
            62: "TenRecorder_SusVib_D3_rr1_Main-xiao.flac",
            64: "TenRecorder_SusVib_E3_rr1_Main-xiao.flac",
            67: "TenRecorder_SusVib_G3_rr1_Main-xiao.flac",
            69: "TenRecorder_SusVib_A3_rr1_Main-xiao.flac",
            72: "TenRecorder_SusVib_C4_rr1_Main-xiao.flac",
            74: "TenRecorder_SusVib_D4_rr1_Main-xiao.flac",
            76: "TenRecorder_SusVib_E4_rr1_Main-xiao.flac",
            79: "TenRecorder_SusVib_G4_rr1_Main-xiao.flac",
            81: "TenRecorder_SusVib_A4_rr1_Main-xiao.flac",
        }
        for midi, fname in xiao_map.items():
            p = os.path.join(SAMPLE_DIR, "xiao", fname)
            if os.path.exists(p):
                self.xiao[midi] = load_flac_mono(p)

    def _get_note(self, bank: dict[int, np.ndarray], midi: int, dur_sec: float, attack: float, release: float) -> np.ndarray:
        nearest = min(bank.keys(), key=lambda k: abs(k - midi))
        raw = pitch_shift(bank[nearest], midi - nearest)
        n = int(round(dur_sec * SR))
        if len(raw) < n:
            out = np.zeros(n, dtype=np.float32)
            out[: len(raw)] = raw
        else:
            out = raw[:n].copy()
        a_n = min(int(attack * SR), n // 2)
        r_n = min(int(release * SR), n // 2)
        if a_n > 1:
            out[:a_n] *= np.linspace(0.0, 1.0, a_n, dtype=np.float32)
        if r_n > 1:
            out[-r_n:] *= np.linspace(1.0, 0.0, r_n, dtype=np.float32) ** 1.4
        return out

    def play_guzheng(self, midi: int, dur_sec: float = 2.0) -> np.ndarray:
        return self._get_note(self.guzheng, midi, dur_sec, attack=0.004, release=0.35)

    def play_xiao(self, midi: int, dur_sec: float = 1.2) -> np.ndarray:
        return self._get_note(self.xiao, midi, dur_sec, attack=0.06, release=0.18)


def mix_stereo(buf: np.ndarray, mono: np.ndarray, start_sec: float, gain: float, pan: float = 0.0) -> None:
    # pan in [-1, 1]
    start = int(round(start_sec * SR))
    end = min(len(buf), start + len(mono))
    if end <= start or start < 0:
        return
    seg = mono[: end - start] * gain
    theta = (pan + 1.0) * 0.25 * math.pi
    buf[start:end, 0] += seg * math.cos(theta)
    buf[start:end, 1] += seg * math.sin(theta)


def tanggu_drum(pitch_hi: float = 148.0, pitch_lo: float = 68.0, dur: float = 0.26) -> np.ndarray:
    n = int(dur * SR)
    t = np.linspace(0.0, dur, n, dtype=np.float32)
    freq = pitch_lo + (pitch_hi - pitch_lo) * np.exp(-t * 28.0)
    phase = 2.0 * np.pi * np.cumsum(freq) / SR
    body = np.sin(phase) * np.exp(-t * 11.0)
    rng = np.random.default_rng(101)
    slap = rng.standard_normal(n).astype(np.float32) * np.exp(-t * 65.0)
    b, a = signal.butter(2, [300.0 / (SR / 2), 1800.0 / (SR / 2)], btype="band")
    slap = signal.lfilter(b, a, slap).astype(np.float32) * 0.35
    out = body + slap
    return out / (np.max(np.abs(out)) + 1e-5)


def woodblock(freq: float = 820.0, dur: float = 0.085) -> np.ndarray:
    n = int(dur * SR)
    t = np.linspace(0.0, dur, n, dtype=np.float32)
    sig = (
        np.sin(2 * np.pi * freq * t) * np.exp(-t * 48.0)
        + 0.45 * np.sin(2 * np.pi * freq * 1.48 * t) * np.exp(-t * 72.0)
        + 0.20 * np.sin(2 * np.pi * freq * 2.12 * t) * np.exp(-t * 95.0)
    )
    return (sig / (np.max(np.abs(sig)) + 1e-5)).astype(np.float32)


def edm_kick(dur: float = 0.24) -> np.ndarray:
    n = int(dur * SR)
    t = np.linspace(0.0, dur, n, dtype=np.float32)
    freq = 46.0 + 125.0 * np.exp(-t * 42.0)
    phase = 2.0 * np.pi * np.cumsum(freq) / SR
    sub = np.sin(phase) * np.exp(-t * 10.5)
    click = np.sin(2.0 * np.pi * 1600.0 * t) * np.exp(-t * 110.0) * 0.22
    out = np.tanh((sub + click) * 1.45)
    return (out / (np.max(np.abs(out)) + 1e-5)).astype(np.float32)


def synth_bass_note(midi: int, dur: float, cutoff: float = 420.0) -> np.ndarray:
    n = int(dur * SR)
    t = np.linspace(0.0, dur, n, dtype=np.float32)
    freq = 440.0 * (2.0 ** ((midi - 69) / 12.0))
    # Saw + sub-octave sine with smooth low-pass filter to prevent ear fatigue
    saw = 2.0 * ((t * freq) - np.floor(0.5 + t * freq))
    sub = np.sin(2.0 * np.pi * (freq * 0.5) * t) * 0.85
    raw = saw * 0.55 + sub
    b, a = signal.butter(2, min(0.45, cutoff / (SR / 2)), btype="low")
    filt = signal.lfilter(b, a, raw).astype(np.float32)
    env = (1.0 - np.exp(-t * 55.0)) * np.exp(-t * 4.5)
    out = filt * env
    return (out / (np.max(np.abs(out)) + 1e-5)).astype(np.float32)


def suona_note(midi: int, dur: float, vibrato: float = 5.8) -> np.ndarray:
    n = int(dur * SR)
    t = np.linspace(0.0, dur, n, dtype=np.float32)
    f0 = 440.0 * (2.0 ** ((midi - 69) / 12.0))
    # Expressive pitch bend in on attack + bold nasal reed harmonics
    bend = 1.0 - 0.025 * np.exp(-t * 35.0) + 0.007 * np.sin(2.0 * np.pi * vibrato * t) * np.clip(t * 3.0, 0.0, 1.0)
    phase = 2.0 * np.pi * np.cumsum(f0 * bend) / SR
    sig = (
        0.50 * np.sin(phase)
        + 0.95 * np.sin(2.0 * phase + 0.2)
        + 0.80 * np.sin(3.0 * phase + 0.4)
        + 0.55 * np.sin(4.0 * phase)
        + 0.30 * np.sin(5.0 * phase)
    )
    b, a = signal.butter(2, [550.0 / (SR / 2), 3800.0 / (SR / 2)], btype="band")
    sig = signal.lfilter(b, a, sig).astype(np.float32)
    env = (1.0 - np.exp(-t * 40.0)) * (1.0 - 0.15 * t / max(0.05, dur))
    r_n = min(int(0.06 * SR), n // 3)
    if r_n > 1:
        env[-r_n:] *= np.linspace(1.0, 0.0, r_n, dtype=np.float32)
    out = np.tanh(sig * env * 1.3)
    return (out / (np.max(np.abs(out)) + 1e-5)).astype(np.float32)


def erhu_note(midi: int, dur: float) -> np.ndarray:
    n = int(dur * SR)
    t = np.linspace(0.0, dur, n, dtype=np.float32)
    f0 = 440.0 * (2.0 ** ((midi - 69) / 12.0))
    vib = 1.0 + 0.008 * np.sin(2.0 * np.pi * 5.2 * t) * np.clip(t * 2.5, 0.0, 1.0)
    phase = 2.0 * np.pi * np.cumsum(f0 * vib) / SR
    sig = (
        0.90 * np.sin(phase)
        + 0.65 * np.sin(2.0 * phase + 0.3)
        + 0.42 * np.sin(3.0 * phase + 0.7)
        + 0.22 * np.sin(4.0 * phase)
    )
    b, a = signal.butter(2, [340.0 / (SR / 2), 2900.0 / (SR / 2)], btype="band")
    sig = signal.lfilter(b, a, sig).astype(np.float32)
    env = (1.0 - np.exp(-t * 16.0)) * np.exp(-t * 0.45)
    r_n = min(int(0.10 * SR), n // 3)
    if r_n > 1:
        env[-r_n:] *= np.linspace(1.0, 0.0, r_n, dtype=np.float32)
    out = sig * env
    return (out / (np.max(np.abs(out)) + 1e-5)).astype(np.float32)


def warm_pad(freq: float, dur: float) -> np.ndarray:
    n = int(dur * SR)
    t = np.linspace(0.0, dur, n, dtype=np.float32)
    env = np.maximum(0.0, np.sin(np.pi * t / dur)) ** 1.3
    sig = (
        np.sin(2 * np.pi * freq * t)
        + 0.32 * np.sin(2 * np.pi * freq * 2.0 * t + 0.4)
        + 0.14 * np.sin(2 * np.pi * freq * 1.5 * t)
    ) * env
    return (sig / (np.max(np.abs(sig)) + 1e-5)).astype(np.float32)


def stereo_reverb(stereo: np.ndarray, wet: float = 0.18) -> np.ndarray:
    out = stereo.copy()
    delays_l = [int(0.0297 * SR), int(0.0371 * SR), int(0.0437 * SR)]
    delays_r = [int(0.0313 * SR), int(0.0397 * SR), int(0.0461 * SR)]
    for ch, dlist in ((0, delays_l), (1, delays_r)):
        rev = np.zeros(len(stereo), dtype=np.float32)
        for d, g in zip(dlist, (0.45, 0.34, 0.25)):
            shifted = np.zeros_like(stereo[:, ch])
            shifted[d:] = stereo[:-d, ch]
            rev += shifted * g
            shifted2 = np.zeros_like(stereo[:, ch])
            d2 = d * 2
            if d2 < len(stereo):
                shifted2[d2:] = stereo[:-d2, ch]
                rev += shifted2 * (g * 0.48)
        b, a = signal.butter(2, 3600.0 / (SR / 2), btype="low")
        rev = signal.lfilter(b, a, rev).astype(np.float32)
        out[:, ch] = out[:, ch] * (1.0 - wet * 0.4) + rev * wet
    return out


def make_seamless_loop(buf: np.ndarray, loop_sec: float) -> np.ndarray:
    loop_n = int(round(loop_sec * SR))
    out = buf[:loop_n].copy()
    tail = buf[loop_n:]
    if len(tail) > 0:
        n_tail = min(len(tail), loop_n)
        out[:n_tail] += tail[:n_tail]
    # Short de-click fade on loop endpoints (10ms)
    fade = int(0.010 * SR)
    out[:fade] *= np.linspace(0.0, 1.0, fade, dtype=np.float32)[:, None]
    out[-fade:] *= np.linspace(1.0, 0.0, fade, dtype=np.float32)[:, None]
    return out


def save_wav(path: str, audio: np.ndarray, target_peak: float = 0.88) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    audio = np.nan_to_num(audio, nan=0.0, posinf=0.0, neginf=0.0)
    peak = float(np.max(np.abs(audio)))
    if peak > 1e-5:
        audio = audio * (target_peak / peak)
    audio = np.tanh(audio * 1.15) / math.tanh(1.15)
    pcm = np.clip(audio * 32767.0, -32768, 32767).astype(np.int16)
    channels = 2 if pcm.ndim == 2 else 1
    with wave.open(path, "wb") as wf:
        wf.setnchannels(channels)
        wf.setsampwidth(2)
        wf.setframerate(SR)
        wf.writeframes(pcm.tobytes())
    print(f"Wrote WAV -> {os.path.basename(path)} ({len(pcm)/SR:.2f}s, {channels}ch)")


def save_ogg(path: str, audio: np.ndarray, target_peak: float = 0.88) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    peak = float(np.max(np.abs(audio)))
    if peak > 1e-5:
        audio = audio * (target_peak / peak)
    audio = np.tanh(audio * 1.15) / math.tanh(1.15)
    if audio.ndim == 1:
        audio = np.stack([audio, audio], axis=1)
    container = av.open(path, mode="w", format="ogg")
    stream = container.add_stream("libvorbis", rate=SR)
    stream.layout = "stereo"
    stream.bit_rate = 160000
    chunk = 4096
    for i in range(0, len(audio), chunk):
        seg = np.ascontiguousarray(audio[i : i + chunk].T, dtype=np.float32)
        frame = av.AudioFrame.from_ndarray(seg, format="fltp", layout="stereo")
        frame.sample_rate = SR
        for pkt in stream.encode(frame):
            container.mux(pkt)
    for pkt in stream.encode():
        container.mux(pkt)
    container.close()
    print(f"Wrote OGG -> {os.path.basename(path)} ({len(audio)/SR:.2f}s, stereo)")


def build_title_music(bank: InstrumentBank) -> None:
    # 96 BPM, 16 bars (4 beats/bar = 64 beats = 40.0 seconds) in sunlit C-major pentatonic
    beat = 60.0 / 96.0
    loop_sec = 64 * beat
    buf = np.zeros((int((loop_sec + 4.0) * SR), 2), dtype=np.float32)

    # Chord progression (16 bars): C - G - Am - Em | F(Dm7) - C - Dm7 - G | C - G - Am - G | F - G - C - C
    chords = [
        (48, [55, 60, 62, 64, 67, 72]),
        (43, [50, 55, 57, 62, 67, 71]),
        (45, [52, 57, 60, 64, 69, 72]),
        (40, [47, 52, 55, 59, 64, 67]),
        (50, [57, 60, 62, 65, 69, 74]),
        (48, [55, 60, 64, 67, 72, 76]),
        (50, [57, 62, 64, 67, 69, 74]),
        (43, [50, 55, 57, 62, 67, 74]),
        (48, [55, 60, 64, 67, 72, 76]),
        (43, [50, 55, 62, 67, 71, 74]),
        (45, [52, 57, 60, 64, 69, 72]),
        (43, [50, 55, 62, 64, 67, 74]),
        (50, [57, 60, 65, 69, 72, 74]),
        (43, [50, 55, 59, 62, 67, 74]),
        (48, [55, 60, 64, 67, 72, 76]),
        (48, [55, 60, 62, 67, 72, 79]),
    ]

    for bar_i, (bass, arp) in enumerate(chords):
        t0 = bar_i * 4.0 * beat
        # Gentle warm silk pad
        freq = 440.0 * (2.0 ** ((bass - 69) / 12.0))
        mix_stereo(buf, warm_pad(freq, 4.2 * beat), t0, 0.14, pan=0.0)
        # Bass Guzheng root on beat 1
        mix_stereo(buf, bank.play_guzheng(bass, 2.8), t0, 0.46, pan=-0.22)
        # Flowing Guzheng broken arpeggio on eighth notes
        pattern = [0, 1, 2, 4, 3, 5, 4, 2]
        for step, idx in enumerate(pattern):
            note = arp[idx % len(arp)]
            vel = 0.36 if step % 2 == 0 else 0.26
            pan = -0.35 + (step / 7.0) * 0.70
            mix_stereo(buf, bank.play_guzheng(note, 1.8), t0 + step * 0.5 * beat, vel, pan=pan)
        # Sparkly pentatonic sweep every 4th bar
        if bar_i in (3, 7, 11, 15):
            sweep = [60, 62, 64, 67, 69, 72, 74, 76, 79]
            for k, sn in enumerate(sweep):
                mix_stereo(buf, bank.play_guzheng(sn, 1.4), t0 + 2.8 * beat + k * 0.065, 0.24, pan=-0.5 + k * 0.12)

    # Expressive singing Bamboo Xiao melody (bars 2..15)
    xiao_melody = [
        # (start_beat, midi, dur_beats, gain)
        (8.0, 72, 1.5, 0.42), (9.5, 74, 0.5, 0.36), (10.0, 76, 2.0, 0.44),
        (12.0, 79, 1.5, 0.46), (13.5, 76, 0.5, 0.38), (14.0, 74, 2.0, 0.42),
        (16.0, 72, 1.5, 0.42), (17.5, 69, 0.5, 0.36), (18.0, 67, 2.0, 0.40),
        (20.0, 69, 1.0, 0.38), (21.0, 72, 1.0, 0.40), (22.0, 74, 2.0, 0.44),
        (24.0, 76, 1.5, 0.44), (25.5, 79, 0.5, 0.42), (26.0, 81, 2.0, 0.48),
        (28.0, 79, 1.0, 0.44), (29.0, 76, 1.0, 0.40), (30.0, 74, 2.0, 0.42),
        (34.0, 72, 1.0, 0.40), (35.0, 74, 1.0, 0.42), (36.0, 76, 1.5, 0.46), (37.5, 79, 0.5, 0.42),
        (38.0, 76, 2.0, 0.44), (40.0, 74, 1.5, 0.42), (41.5, 72, 0.5, 0.38), (42.0, 69, 2.0, 0.40),
        (44.0, 72, 1.5, 0.42), (45.5, 74, 0.5, 0.40), (46.0, 76, 2.0, 0.45),
        (48.0, 79, 1.5, 0.48), (49.5, 81, 0.5, 0.46), (50.0, 79, 1.0, 0.44), (51.0, 76, 1.0, 0.42),
        (52.0, 74, 2.0, 0.44), (54.0, 76, 1.0, 0.42), (55.0, 74, 1.0, 0.40),
        (56.0, 72, 3.5, 0.44),
    ]
    for b_start, midi, b_dur, g in xiao_melody:
        mix_stereo(buf, bank.play_xiao(midi, b_dur * beat), b_start * beat, g, pan=0.12)

    buf = stereo_reverb(buf, wet=0.22)
    looped = make_seamless_loop(buf, loop_sec)
    save_ogg(os.path.join(OUT_DIR, "music_title.ogg"), looped, 0.85)


def build_battle_music(bank: InstrumentBank) -> None:
    # 120 BPM 4/4 Electronic Guofeng (32.0s seamless loop):
    # Warm 4/4 electronic kick + rolling low-pass synth bass + warm silk pad + Guzheng/Xiao/Erhu flow!
    beat = 60.0 / 120.0
    loop_sec = 64 * beat
    buf = np.zeros((int((loop_sec + 3.0) * SR), 2), dtype=np.float32)

    kick = edm_kick(0.24)
    drum_hi = tanggu_drum(220.0, 110.0, 0.14)
    wb_hi = woodblock(860.0, 0.07)

    # Focused flow-state A-minor / C-major pentatonic electronic progression (16 bars)
    bars = [
        (45, [57, 60, 64, 69]), (45, [57, 62, 64, 72]),
        (41, [53, 60, 64, 69]), (43, [55, 62, 67, 74]),
        (45, [57, 60, 64, 69]), (48, [60, 64, 67, 72]),
        (50, [62, 67, 69, 74]), (43, [55, 62, 67, 71]),
        (45, [57, 60, 64, 69]), (41, [53, 60, 64, 72]),
        (48, [60, 64, 67, 72]), (43, [55, 62, 67, 74]),
        (50, [62, 65, 69, 74]), (41, [53, 60, 64, 69]),
        (43, [55, 62, 67, 74]), (45, [57, 64, 69, 72]),
    ]

    for bar_i, (bass, chord) in enumerate(bars):
        t0 = bar_i * 4.0 * beat
        # Warm synthesizer pad bed to prevent auditory fatigue
        pad_f = 440.0 * (2.0 ** ((bass + 12 - 69) / 12.0))
        mix_stereo(buf, warm_pad(pad_f, 4.1 * beat), t0, 0.13, pan=0.0)

        # 4/4 Electronic Kick on every beat + offbeat rolling synth bass
        for b_i in range(4):
            tb = t0 + b_i * beat
            mix_stereo(buf, kick, tb, 0.48 if b_i in (0, 2) else 0.42, pan=0.0)
            mix_stereo(buf, synth_bass_note(bass - 12, 0.45 * beat, cutoff=360.0), tb + 0.5 * beat, 0.38, pan=0.0)
            if b_i in (1, 3):
                mix_stereo(buf, drum_hi, tb, 0.25, pan=-0.12 if b_i == 1 else 0.12)
            mix_stereo(buf, wb_hi, tb + 0.5 * beat, 0.12, pan=0.22 if b_i % 2 == 0 else -0.22)

        # Syncopated Guzheng plucking groove
        pat = [0, 2, 1, 3, 2, 0, 3, 1]
        for s, idx in enumerate(pat):
            n_midi = chord[idx]
            g = 0.34 if s in (0, 3, 6) else 0.22
            mix_stereo(buf, bank.play_guzheng(n_midi, 0.85), t0 + s * 0.5 * beat, g, pan=-0.34 + (s % 4) * 0.22)

    # Melodic Xiao (Section A) & singing Erhu (Section B)
    melody_a = [
        (0.0, 69, 1.5), (1.5, 72, 0.5), (2.0, 76, 1.0), (3.0, 74, 1.0),
        (4.0, 72, 1.5), (5.5, 69, 0.5), (6.0, 67, 2.0),
        (8.0, 69, 1.0), (9.0, 72, 1.0), (10.0, 76, 1.5), (11.5, 79, 0.5),
        (12.0, 74, 3.5),
        (16.0, 76, 1.5), (17.5, 79, 0.5), (18.0, 81, 1.0), (19.0, 79, 1.0),
        (20.0, 76, 1.0), (21.0, 74, 1.0), (22.0, 72, 2.0),
        (24.0, 74, 1.0), (25.0, 72, 1.0), (26.0, 69, 1.0), (27.0, 67, 1.0),
        (28.0, 69, 3.5),
    ]
    for b_start, midi, b_dur in melody_a:
        mix_stereo(buf, bank.play_xiao(min(midi, 81), b_dur * beat * 0.96), b_start * beat, 0.34, pan=0.14)

    melody_b = [
        (32.0, 76, 1.5), (33.5, 79, 0.5), (34.0, 81, 1.5), (35.5, 79, 0.5),
        (36.0, 76, 1.5), (37.5, 74, 0.5), (38.0, 72, 2.0),
        (40.0, 74, 1.0), (41.0, 76, 1.0), (42.0, 79, 1.5), (43.5, 76, 0.5),
        (44.0, 74, 3.5),
        (48.0, 76, 1.0), (49.0, 79, 1.0), (50.0, 81, 1.5), (51.5, 79, 0.5),
        (52.0, 76, 1.0), (53.0, 74, 1.0), (54.0, 72, 2.0),
        (56.0, 74, 1.5), (57.5, 72, 0.5), (58.0, 69, 1.0), (59.0, 67, 1.0),
        (60.0, 69, 3.5),
    ]
    for b_start, midi, b_dur in melody_b:
        mix_stereo(buf, erhu_note(midi, b_dur * beat * 0.95), b_start * beat, 0.30, pan=-0.12)
        mix_stereo(buf, bank.play_xiao(min(midi, 81), b_dur * beat * 0.95), b_start * beat, 0.24, pan=0.16)

    buf = stereo_reverb(buf, wet=0.16)
    looped = make_seamless_loop(buf, loop_sec)
    save_ogg(os.path.join(OUT_DIR, "music_battle.ogg"), looped, 0.85)


def build_sfx(bank: InstrumentBank) -> None:
    rng = np.random.default_rng(2026)

    # 1. sword_cast: airy silk slash whoosh + crisp jade blade shimmer
    dur = 0.20
    n = int(dur * SR)
    t = np.linspace(0.0, dur, n, dtype=np.float32)
    noise = rng.standard_normal(n).astype(np.float32)
    b, a = signal.butter(3, [550.0 / (SR / 2), 3400.0 / (SR / 2)], btype="band")
    whoosh = signal.lfilter(b, a, noise).astype(np.float32) * (np.maximum(0.0, np.sin(np.pi * t / dur)) ** 0.7) * np.exp(-t * 10.0)
    shimmer = (
        np.sin(2 * np.pi * (1760.0 + 440.0 * t / dur) * t) * 0.14
        + np.sin(2 * np.pi * 2637.0 * t) * 0.08
    ) * np.exp(-t * 22.0)
    save_wav(os.path.join(OUT_DIR, "sword_cast.wav"), whoosh * 0.85 + shimmer, 0.82)

    # 2. sword_hit: punchy tactile cut + tight warm body thump (never piercing!)
    dur = 0.11
    n = int(dur * SR)
    t = np.linspace(0.0, dur, n, dtype=np.float32)
    f_thump = 80.0 + 180.0 * np.exp(-t * 45.0)
    thump = np.sin(2 * np.pi * np.cumsum(f_thump) / SR) * np.exp(-t * 26.0)
    cut_n = rng.standard_normal(n).astype(np.float32)
    b, a = signal.butter(2, [1400.0 / (SR / 2), 4200.0 / (SR / 2)], btype="band")
    cut = signal.lfilter(b, a, cut_n).astype(np.float32) * np.exp(-t * 48.0) * 0.55
    save_wav(os.path.join(OUT_DIR, "sword_hit.wav"), thump * 0.75 + cut, 0.85)

    # 3. enemy_die: breezy pop-poof + tiny sparkling jade chime
    dur = 0.22
    n = int(dur * SR)
    t = np.linspace(0.0, dur, n, dtype=np.float32)
    pop_f = 130.0 + 260.0 * np.exp(-t * 28.0)
    pop = np.sin(2 * np.pi * np.cumsum(pop_f) / SR) * np.exp(-t * 18.0)
    puff = rng.standard_normal(n).astype(np.float32)
    b, a = signal.butter(2, [400.0 / (SR / 2), 2000.0 / (SR / 2)], btype="band")
    puff = signal.lfilter(b, a, puff).astype(np.float32) * np.exp(-t * 24.0) * 0.35
    chime = bank.play_guzheng(79, dur) * 0.28
    save_wav(os.path.join(OUT_DIR, "enemy_die.wav"), pop * 0.6 + puff + chime, 0.80)

    # 4. gem_pickup: REAL CC0 Guzheng crisp high crystal pluck (scales up pentatonically in Sfx!)
    pluck = bank.play_guzheng(79, 0.28)
    save_wav(os.path.join(OUT_DIR, "gem_pickup.wav"), pluck, 0.78)

    # 5. level_up: REAL CC0 Guzheng bright ascending pentatonic glissando!
    lu = np.zeros((int(1.25 * SR), 2), dtype=np.float32)
    for i, m in enumerate([60, 62, 64, 67, 69, 72, 74, 79]):
        mix_stereo(lu, bank.play_guzheng(m, 0.9), i * 0.055, 0.42, pan=-0.45 + i * 0.13)
    lu = stereo_reverb(lu, wet=0.26)
    save_wav(os.path.join(OUT_DIR, "level_up.wav"), lu, 0.88)

    # 6. chest_open: Grand joyful Guzheng flourish + radiant jade chime chord!
    ch = np.zeros((int(2.1 * SR), 2), dtype=np.float32)
    sweep = [55, 60, 62, 64, 67, 69, 72, 74, 76, 79, 84]
    for i, m in enumerate(sweep):
        mix_stereo(ch, bank.play_guzheng(m, 1.2), i * 0.055, 0.40, pan=-0.6 + i * 0.12)
    # Final heroic bright chord + Xiao glow
    for m, p in ((60, -0.3), (67, 0.0), (72, 0.3), (79, 0.0)):
        mix_stereo(ch, bank.play_guzheng(m, 1.3), 0.68, 0.42, pan=p)
    mix_stereo(ch, bank.play_xiao(79, 1.1), 0.72, 0.35, pan=0.0)
    ch = stereo_reverb(ch, wet=0.28)
    save_wav(os.path.join(OUT_DIR, "chest_open.wav"), ch, 0.90)

    # 7. thunder: soft distant thunder rumble + gentle chime decay (non-jarring at high fire rate)
    dur = 0.36
    n = int(dur * SR)
    t = np.linspace(0.0, dur, n, dtype=np.float32)
    attack_env = np.clip(t / 0.024, 0.0, 1.0) ** 1.5
    f_boom = 42.0 + 50.0 * np.exp(-t * 22.0)
    boom = np.sin(2.0 * np.pi * np.cumsum(f_boom) / SR) * np.exp(-t * 9.5) * attack_env
    rumble = rng.standard_normal(n).astype(np.float32)
    b, a = signal.butter(2, [90.0 / (SR / 2), 850.0 / (SR / 2)], btype="band")
    rumble = signal.lfilter(b, a, rumble).astype(np.float32) * np.exp(-t * 11.5) * attack_env
    chime = bank.play_guzheng(69, dur) * 0.12 * attack_env if bank.guzheng else 0.0
    save_wav(os.path.join(OUT_DIR, "thunder.wav"), boom * 0.55 + rumble * 0.35 + chime, 0.40)

    # 8. player_hurt: warm low drum thud
    hurt = tanggu_drum(180.0, 58.0, 0.22)
    save_wav(os.path.join(OUT_DIR, "player_hurt.wav"), hurt, 0.80)

    # 9. dash: silky cloud-step swoosh + ascending jade chime
    dur = 0.26
    n = int(dur * SR)
    t = np.linspace(0.0, dur, n, dtype=np.float32)
    air = rng.standard_normal(n).astype(np.float32)
    b, a = signal.butter(3, [420.0 / (SR / 2), 2600.0 / (SR / 2)], btype="band")
    air = signal.lfilter(b, a, air).astype(np.float32) * (np.maximum(0.0, np.sin(np.pi * t / dur)) ** 0.8)
    chime = bank.play_guzheng(74, dur) * 0.35
    save_wav(os.path.join(OUT_DIR, "dash.wav"), air * 0.72 + chime, 0.82)

    # 10. jar_break: porcelain clink + bright chime
    dur = 0.28
    n = int(dur * SR)
    t = np.linspace(0.0, dur, n, dtype=np.float32)
    clink = (
        np.sin(2 * np.pi * 1580.0 * t) * np.exp(-t * 28.0)
        + 0.7 * np.sin(2 * np.pi * 2420.0 * t) * np.exp(-t * 36.0)
        + 0.45 * np.sin(2 * np.pi * 3640.0 * t) * np.exp(-t * 44.0)
    )
    shard = rng.standard_normal(n).astype(np.float32)
    b, a = signal.butter(2, [2200.0 / (SR / 2), 7000.0 / (SR / 2)], btype="band")
    shard = signal.lfilter(b, a, shard).astype(np.float32) * np.exp(-t * 24.0) * 0.45
    save_wav(os.path.join(OUT_DIR, "jar_break.wav"), clink * 0.7 + shard, 0.82)

    # 11. swarm_horn: Deep bronze war-horn blast + triple Tanggu war-drum alert when a monster wave arrives!
    dur = 1.65
    h_buf = np.zeros((int(dur * SR), 2), dtype=np.float32)
    t = np.linspace(0.0, 1.25, int(1.25 * SR), dtype=np.float32)
    f_horn = 110.0 + 6.0 * (1.0 - np.exp(-t * 5.0))
    ph = 2.0 * np.pi * np.cumsum(f_horn) / SR
    horn = (0.8 * np.sin(ph) + 0.95 * np.sin(2 * ph) + 0.65 * np.sin(3 * ph) + 0.4 * np.sin(4 * ph))
    b, a = signal.butter(2, 1600.0 / (SR / 2), btype="low")
    horn = signal.lfilter(b, a, horn).astype(np.float32) * (1.0 - np.exp(-t * 8.0)) * np.exp(-t * 1.4)
    mix_stereo(h_buf, horn, 0.08, 0.55, pan=0.0)
    w_drum = tanggu_drum(135.0, 48.0, 0.28)
    for dt, g, p in ((0.0, 0.65, -0.2), (0.24, 0.68, 0.2), (0.48, 0.78, 0.0)):
        mix_stereo(h_buf, w_drum, dt, g, pan=p)
    mix_stereo(h_buf, suona_note(69, 0.75), 0.52, 0.34, pan=0.1)
    h_buf = stereo_reverb(h_buf, wet=0.22)
    save_wav(os.path.join(OUT_DIR, "swarm_horn.wav"), h_buf, 0.90)

    # 12. boss_roar: Ferocious monstrous sub-growl + metallic gong tremor
    dur = 1.15
    n = int(dur * SR)
    t = np.linspace(0.0, dur, n, dtype=np.float32)
    f_roar = 92.0 - 34.0 * (t / dur) + 14.0 * np.sin(2.0 * np.pi * 24.0 * t)
    ph = 2.0 * np.pi * np.cumsum(f_roar) / SR
    growl = np.tanh((np.sin(ph) + 0.7 * np.sin(1.5 * ph) + 0.5 * rng.standard_normal(n)) * 2.2)
    b, a = signal.butter(2, [55.0 / (SR / 2), 950.0 / (SR / 2)], btype="band")
    growl = signal.lfilter(b, a, growl).astype(np.float32) * (1.0 - np.exp(-t * 24.0)) * np.exp(-t * 2.4)
    sub_boom = tanggu_drum(110.0, 38.0, 0.45)
    out_roar = growl.copy()
    out_roar[: len(sub_boom)] += sub_boom * 0.65
    save_wav(os.path.join(OUT_DIR, "boss_roar.wav"), out_roar, 0.90)

    # 13. boss_charge: Rising demonic energy telegraph sweep before Boss attack
    dur = 0.62
    n = int(dur * SR)
    t = np.linspace(0.0, dur, n, dtype=np.float32)
    f_ch = 160.0 + 520.0 * ((t / dur) ** 1.7)
    ph = 2.0 * np.pi * np.cumsum(f_ch) / SR
    sweep_s = (np.sin(ph) + 0.45 * np.sin(2.0 * ph)) * (t / dur) * np.exp(-(dur - t) * 4.0)
    pulse_mod = 0.65 + 0.35 * np.sin(2.0 * np.pi * 18.0 * t)
    save_wav(os.path.join(OUT_DIR, "boss_charge.wav"), (sweep_s * pulse_mod).astype(np.float32), 0.82)

    # 14. boss_slam: Earth-shattering AoE red-circle detonation impact
    dur = 0.68
    n = int(dur * SR)
    t = np.linspace(0.0, dur, n, dtype=np.float32)
    slam_drum = tanggu_drum(125.0, 34.0, dur)
    debris = rng.standard_normal(n).astype(np.float32)
    b, a = signal.butter(2, [180.0 / (SR / 2), 2400.0 / (SR / 2)], btype="band")
    debris = signal.lfilter(b, a, debris).astype(np.float32) * np.exp(-t * 11.0) * 0.55
    save_wav(os.path.join(OUT_DIR, "boss_slam.wav"), slam_drum * 0.9 + debris, 0.92)

    # 15. boss_dash: Heavy razor-wind lunge burst
    dur = 0.36
    n = int(dur * SR)
    t = np.linspace(0.0, dur, n, dtype=np.float32)
    rush = rng.standard_normal(n).astype(np.float32)
    b, a = signal.butter(2, [260.0 / (SR / 2), 2800.0 / (SR / 2)], btype="band")
    rush = signal.lfilter(b, a, rush).astype(np.float32) * np.sin(np.pi * t / dur)
    whoosh_low = tanggu_drum(195.0, 62.0, 0.25)
    out_dash = rush * 0.75
    out_dash[: len(whoosh_low)] += whoosh_low * 0.65
    save_wav(os.path.join(OUT_DIR, "boss_dash.wav"), out_dash.astype(np.float32), 0.88)

    dur = 0.16
    n = int(dur * SR)
    t = np.linspace(0.0, dur, n, dtype=np.float32)
    atk_g = np.clip(t / 0.009, 0.0, 1.0)
    f_pop = 95.0 + 210.0 * np.exp(-t * 38.0)
    gun_body = np.sin(2.0 * np.pi * np.cumsum(f_pop) / SR) * np.exp(-t * 24.0) * atk_g
    powder = rng.standard_normal(n).astype(np.float32)
    b, a = signal.butter(2, [220.0 / (SR / 2), 1850.0 / (SR / 2)], btype="band")
    powder = signal.lfilter(b, a, powder).astype(np.float32) * np.exp(-t * 28.0) * atk_g
    brass = np.sin(2.0 * np.pi * 1320.0 * t) * np.exp(-t * 52.0) * 0.14 * atk_g
    save_wav(os.path.join(OUT_DIR, "gun_shot.wav"), gun_body * 0.65 + powder * 0.42 + brass, 0.56)

    dur = 0.28
    n = int(dur * SR)
    t = np.linspace(0.0, dur, n, dtype=np.float32)
    atk_c = np.clip(t / 0.014, 0.0, 1.0)
    f_can = 62.0 + 135.0 * np.exp(-t * 26.0)
    can_boom = np.sin(2.0 * np.pi * np.cumsum(f_can) / SR) * np.exp(-t * 14.0) * atk_c
    ember = rng.standard_normal(n).astype(np.float32)
    b, a = signal.butter(2, [120.0 / (SR / 2), 1150.0 / (SR / 2)], btype="band")
    ember = signal.lfilter(b, a, ember).astype(np.float32) * np.exp(-t * 16.0) * atk_c
    save_wav(os.path.join(OUT_DIR, "cannon_blast.wav"), can_boom * 0.68 + ember * 0.38, 0.54)


def chinese_gong(dur: float = 2.4) -> np.ndarray:
    n = int(dur * SR)
    t = np.linspace(0.0, dur, n, dtype=np.float32)
    # Warm resonant Chinese Luo/Gong: metallic inharmonic shimmer + deep fundamental swell
    sig = np.zeros(n, dtype=np.float32)
    for f, amp, dec in [
        (146.8, 0.55, 1.3), (218.0, 0.35, 1.7), (312.5, 0.28, 2.2),
        (468.0, 0.22, 2.8), (695.0, 0.16, 3.6), (1040.0, 0.12, 4.5),
    ]:
        swell = 1.0 - np.exp(-t * 18.0)
        sig += np.sin(2.0 * np.pi * f * t + 0.5 * np.sin(2.0 * np.pi * 3.5 * t)) * amp * swell * np.exp(-t * dec)
    rng = np.random.default_rng(77)
    crash = rng.standard_normal(n).astype(np.float32) * np.exp(-t * 14.0) * 0.25
    b, a = signal.butter(2, [800.0 / (SR / 2), 5500.0 / (SR / 2)], btype="band")
    crash = signal.lfilter(b, a, crash).astype(np.float32)
    out = sig + crash
    return (out / (np.max(np.abs(out)) + 1e-5)).astype(np.float32)


def build_swarm_music(bank: InstrumentBank) -> None:
    # 142 BPM, 16 bars (64 beats ≈ 27.04s): driving, exhilarating 妖潮来袭!
    beat = 60.0 / 142.0
    loop_sec = 64 * beat
    buf = np.zeros((int((loop_sec + 3.0) * SR), 2), dtype=np.float32)

    drum_lo = tanggu_drum(162.0, 66.0, 0.22)
    drum_hi = tanggu_drum(255.0, 128.0, 0.14)
    wb_hi = woodblock(1060.0, 0.06)
    wb_lo = woodblock(760.0, 0.07)

    # Energetic A-minor / C-major pentatonic heroic rush (upbeat martial arts feel)
    bars = [
        (45, [57, 60, 64, 69]), (45, [57, 62, 64, 69]),
        (43, [55, 62, 67, 74]), (48, [60, 64, 67, 72]),
        (50, [62, 67, 69, 74]), (45, [57, 60, 64, 69]),
        (43, [55, 62, 67, 74]), (43, [55, 62, 67, 79]),
        (45, [57, 60, 64, 69]), (48, [60, 64, 67, 72]),
        (50, [62, 67, 69, 74]), (43, [55, 62, 67, 74]),
        (45, [57, 60, 64, 69]), (48, [60, 67, 72, 76]),
        (50, [62, 67, 69, 74]), (43, [55, 62, 67, 74]),
    ]

    for bar_i, (bass, chord) in enumerate(bars):
        t0 = bar_i * 4.0 * beat
        # Double-time martial Tanggu & woodblock pulse
        for step in range(8):
            ts = t0 + step * 0.5 * beat
            if step in (0, 3, 4):
                mix_stereo(buf, drum_lo, ts, 0.46 if step == 0 else 0.36, pan=0.0)
            if step in (2, 5, 6, 7):
                mix_stereo(buf, drum_hi, ts, 0.30, pan=-0.18 if step % 2 == 0 else 0.18)
            mix_stereo(buf, wb_hi if step % 2 == 1 else wb_lo, ts, 0.19, pan=0.30 if step % 2 else -0.25)

        # Rapid driving Guzheng strums & octave bass
        mix_stereo(buf, bank.play_guzheng(bass, 1.0), t0, 0.52, pan=-0.26)
        mix_stereo(buf, bank.play_guzheng(bass + 12, 0.8), t0 + 1.5 * beat, 0.38, pan=-0.18)
        mix_stereo(buf, bank.play_guzheng(bass, 0.9), t0 + 2.0 * beat, 0.46, pan=-0.24)
        for s in range(8):
            n_midi = chord[(s * 3 + bar_i) % len(chord)]
            mix_stereo(buf, bank.play_guzheng(n_midi, 0.65), t0 + s * 0.5 * beat, 0.36 if s % 2 == 0 else 0.25, pan=-0.42 + (s % 4) * 0.28)
        if bar_i % 4 == 3:
            for k, sn in enumerate([64, 67, 69, 72, 74, 76, 79]):
                mix_stereo(buf, bank.play_guzheng(sn, 0.7), t0 + 3.0 * beat + k * 0.045, 0.30, pan=-0.4 + k * 0.14)

    # Spirited fast Xiao flourishes!
    melody = [
        (0.0, 69, 0.5), (0.5, 72, 0.5), (1.0, 74, 0.5), (1.5, 76, 0.5), (2.0, 79, 1.0), (3.0, 76, 1.0),
        (4.0, 74, 1.0), (5.0, 72, 0.5), (5.5, 74, 0.5), (6.0, 76, 2.0),
        (8.0, 79, 0.5), (8.5, 81, 0.5), (9.0, 79, 1.0), (10.0, 76, 0.5), (10.5, 74, 0.5), (11.0, 72, 1.0),
        (12.0, 74, 1.5), (13.5, 76, 0.5), (14.0, 79, 2.0),
        (16.0, 81, 1.0), (17.0, 79, 0.5), (17.5, 76, 0.5), (18.0, 74, 1.0), (19.0, 76, 1.0),
        (20.0, 72, 1.0), (21.0, 74, 1.0), (22.0, 76, 2.0),
        (24.0, 79, 0.5), (24.5, 76, 0.5), (25.0, 74, 0.5), (25.5, 72, 0.5), (26.0, 69, 1.0), (27.0, 72, 1.0),
        (28.0, 74, 3.0),
        (32.0, 76, 0.5), (32.5, 79, 0.5), (33.0, 81, 1.0), (34.0, 79, 0.5), (34.5, 81, 0.5), (35.0, 79, 1.0),
        (36.0, 76, 1.0), (37.0, 74, 1.0), (38.0, 79, 2.0),
        (40.0, 81, 0.5), (40.5, 79, 0.5), (41.0, 76, 1.0), (42.0, 74, 0.5), (42.5, 76, 0.5), (43.0, 79, 1.0),
        (44.0, 74, 1.5), (45.5, 76, 0.5), (46.0, 74, 2.0),
        (48.0, 69, 0.5), (48.5, 72, 0.5), (49.0, 74, 0.5), (49.5, 76, 0.5), (50.0, 79, 1.5), (51.5, 81, 0.5),
        (52.0, 79, 1.0), (53.0, 76, 1.0), (54.0, 74, 1.0), (55.0, 72, 1.0),
        (56.0, 74, 1.5), (57.5, 76, 0.5), (58.0, 79, 2.0), (60.0, 81, 2.0), (62.0, 79, 1.5),
    ]
    for b_start, midi, b_dur in melody:
        mix_stereo(buf, bank.play_xiao(min(midi, 81), b_dur * beat * 0.94), b_start * beat, 0.40, pan=0.14)
        mix_stereo(buf, bank.play_guzheng(midi, 0.75), b_start * beat, 0.34, pan=-0.16)

    buf = stereo_reverb(buf, wet=0.14)
    looped = make_seamless_loop(buf, loop_sec)
    save_ogg(os.path.join(OUT_DIR, "music_swarm.ogg"), looped, 0.88)


def build_boss_music(bank: InstrumentBank) -> None:
    # 132 BPM, 16 bars in D minor / D Phrygian dominant:
    # Completely distinct instrumentation & modality from battle music!
    # Features fiery Suona + dramatic Erhu + heavy Electronic/Tanggu war-drums + growling synth sub-bass + Chinese Gong.
    beat = 60.0 / 132.0
    loop_sec = 64 * beat
    buf = np.zeros((int((loop_sec + 3.5) * SR), 2), dtype=np.float32)

    gong = chinese_gong(2.4)
    kick = edm_kick(0.25)
    drum_epic = tanggu_drum(128.0, 44.0, 0.30)
    drum_mid = tanggu_drum(210.0, 96.0, 0.16)

    # Grand gong crashes on section boundaries
    for g_beat in (0.0, 16.0, 32.0, 48.0):
        mix_stereo(buf, gong, g_beat * beat, 0.44, pan=0.0)

    # Tense, dramatic D-minor / Bb / Gm / A7 progression (distinct from C/G major battle theme!)
    bars = [
        (38, [50, 53, 57, 62]), (38, [50, 56, 57, 64]),
        (34, [46, 53, 58, 62]), (33, [45, 52, 57, 61]),
        (38, [50, 53, 57, 62]), (41, [53, 57, 60, 65]),
        (31, [43, 50, 55, 58]), (33, [45, 52, 57, 61]),
        (38, [50, 53, 57, 62]), (34, [46, 53, 58, 62]),
        (31, [43, 50, 55, 58]), (33, [45, 52, 57, 61]),
        (34, [46, 53, 58, 62]), (31, [43, 50, 55, 58]),
        (33, [45, 52, 57, 61]), (38, [50, 57, 62, 65]),
    ]

    for bar_i, (bass, chord) in enumerate(bars):
        t0 = bar_i * 4.0 * beat
        # Dark dramatic low synth drone + driving 16th-note war bass
        for b_i in range(4):
            tb = t0 + b_i * beat
            mix_stereo(buf, kick, tb, 0.50, pan=0.0)
            mix_stereo(buf, synth_bass_note(bass, 0.46 * beat, cutoff=480.0), tb, 0.44, pan=0.0)
            mix_stereo(buf, synth_bass_note(bass, 0.42 * beat, cutoff=540.0), tb + 0.5 * beat, 0.36, pan=0.0)

        # Thunderous asymmetric war-drum stomp (3+3+2 pattern)
        mix_stereo(buf, drum_epic, t0 + 0.0 * beat, 0.58, pan=0.0)
        mix_stereo(buf, drum_mid, t0 + 0.75 * beat, 0.36, pan=-0.25)
        mix_stereo(buf, drum_epic, t0 + 1.5 * beat, 0.52, pan=0.0)
        mix_stereo(buf, drum_mid, t0 + 2.25 * beat, 0.38, pan=0.25)
        mix_stereo(buf, drum_epic, t0 + 3.0 * beat, 0.54, pan=0.0)
        mix_stereo(buf, drum_mid, t0 + 3.5 * beat, 0.42, pan=-0.20)

        # Aggressive low Guzheng ostinato stabs
        for s in range(8):
            note = chord[(s * 2) % len(chord)]
            mix_stereo(buf, bank.play_guzheng(note, 0.55), t0 + s * 0.5 * beat, 0.32 if s in (0, 3, 6) else 0.20, pan=-0.4 + (s % 4) * 0.26)

    # Section A (bars 0..7): Fierce, commanding Suona + Erhu unison Boss battle motif in D minor!
    boss_mel_a = [
        (0.0, 62, 1.5), (1.5, 65, 0.5), (2.0, 69, 1.5), (3.5, 68, 0.5),
        (4.0, 69, 1.0), (5.0, 74, 1.0), (6.0, 72, 1.0), (7.0, 69, 1.0),
        (8.0, 70, 1.5), (9.5, 69, 0.5), (10.0, 67, 1.0), (11.0, 65, 1.0),
        (12.0, 64, 2.5), (14.5, 61, 1.5),
        (16.0, 62, 1.5), (17.5, 65, 0.5), (18.0, 69, 1.0), (19.0, 74, 1.0),
        (20.0, 77, 1.5), (21.5, 76, 0.5), (22.0, 74, 1.0), (23.0, 72, 1.0),
        (24.0, 70, 1.0), (25.0, 69, 1.0), (26.0, 67, 1.0), (27.0, 69, 1.0),
        (28.0, 62, 3.5),
    ]
    for b_start, midi, b_dur in boss_mel_a:
        mix_stereo(buf, suona_note(midi, b_dur * beat * 0.92), b_start * beat, 0.32, pan=0.15)
        mix_stereo(buf, erhu_note(midi, b_dur * beat * 0.95), b_start * beat, 0.30, pan=-0.18)

    # Section B (bars 8..15): High-stakes climax (Suona high register + sweeping Erhu counter-melody)
    boss_mel_b = [
        (32.0, 74, 1.5), (33.5, 76, 0.5), (34.0, 77, 1.5), (35.5, 74, 0.5),
        (36.0, 70, 1.5), (37.5, 72, 0.5), (38.0, 74, 2.0),
        (40.0, 72, 1.0), (41.0, 70, 1.0), (42.0, 69, 1.5), (43.5, 67, 0.5),
        (44.0, 69, 3.5),
        (48.0, 70, 1.5), (49.5, 72, 0.5), (50.0, 74, 1.0), (51.0, 77, 1.0),
        (52.0, 76, 1.0), (53.0, 74, 1.0), (54.0, 70, 1.0), (55.0, 67, 1.0),
        (56.0, 69, 1.5), (57.5, 67, 0.5), (58.0, 64, 1.0), (59.0, 61, 1.0),
        (60.0, 62, 3.5),
    ]
    for b_start, midi, b_dur in boss_mel_b:
        mix_stereo(buf, suona_note(midi, b_dur * beat * 0.92), b_start * beat, 0.34, pan=0.14)
        mix_stereo(buf, erhu_note(midi - 12, b_dur * beat * 0.96), b_start * beat, 0.30, pan=-0.16)
        mix_stereo(buf, bank.play_guzheng(midi, 0.85), b_start * beat, 0.32, pan=0.0)

    buf = stereo_reverb(buf, wet=0.18)
    looped = make_seamless_loop(buf, loop_sec)
    save_ogg(os.path.join(OUT_DIR, "music_boss.ogg"), looped, 0.88)


def main() -> None:
    bank = InstrumentBank()
    print(f"Loaded CC0 real samples: guzheng={len(bank.guzheng)}, xiao={len(bank.xiao)}")
    build_title_music(bank)
    build_battle_music(bank)
    build_swarm_music(bank)
    build_boss_music(bank)
    build_sfx(bank)


if __name__ == "__main__":
    main()
