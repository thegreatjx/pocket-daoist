from __future__ import annotations

import argparse
import functools
import http.server
import json
import pathlib
import re
import socketserver
import struct
import sys
import urllib.parse
import wave
import webbrowser
from collections import defaultdict
from datetime import datetime
from typing import Any

MEDIA_EXTS = {".png", ".jpg", ".jpeg", ".webp", ".gif", ".wav", ".ogg", ".mp3"}
IMAGE_EXTS = {".png", ".jpg", ".jpeg", ".webp", ".gif"}
AUDIO_EXTS = {".wav", ".ogg", ".mp3"}
RES_RE = re.compile(r"res://[A-Za-z0-9_./\-]+")

KNOWN_SHEET_FRAMES = {
    "anim_fox_run.png": 6,
    "anim_paper_doll_float.png": 6,
    "anim_elite_fox_run.png": 6,
    "anim_elite_doll_float.png": 6,
}


def _read_text(path: pathlib.Path) -> str:
    return path.read_text(encoding="utf-8", errors="ignore")


def _read_json(path: pathlib.Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    data = json.loads(_read_text(path))
    return data if isinstance(data, dict) else {}


def parse_image_size(path: pathlib.Path) -> tuple[int, int] | None:
    ext = path.suffix.lower()
    try:
        with path.open("rb") as f:
            head = f.read(32)
            if ext == ".png" and len(head) >= 24 and head[:8] == b"\x89PNG\r\n\x1a\n":
                return struct.unpack(">II", head[16:24])
            if ext == ".gif" and len(head) >= 10 and head[:6] in (b"GIF87a", b"GIF89a"):
                return struct.unpack("<HH", head[6:10])
            if ext == ".webp" and len(head) >= 30 and head[:4] == b"RIFF" and head[8:12] == b"WEBP":
                chunk = head[12:16]
                if chunk == b"VP8X" and len(head) >= 30:
                    w = 1 + int.from_bytes(head[24:27], "little")
                    h = 1 + int.from_bytes(head[27:30], "little")
                    return (w, h)
                if chunk == b"VP8L" and len(head) >= 25:
                    b0, b1, b2, b3 = head[21:25]
                    bits = b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
                    return ((bits & 0x3FFF) + 1, ((bits >> 14) & 0x3FFF) + 1)
                if chunk == b"VP8 " and len(head) >= 30:
                    w, h = struct.unpack("<HH", head[26:30])
                    return (w & 0x3FFF, h & 0x3FFF)
            if ext in (".jpg", ".jpeg"):
                f.seek(0)
                data = f.read(65536)
                if len(data) < 4 or data[:2] != b"\xff\xd8":
                    return None
                i = 2
                while i + 9 < len(data):
                    if data[i] != 0xFF:
                        i += 1
                        continue
                    marker = data[i + 1]
                    if marker in (0xC0, 0xC1, 0xC2, 0xC3):
                        h, w = struct.unpack(">HH", data[i + 5 : i + 9])
                        return (w, h)
                    if marker in (0xD8, 0xD9) or (0xD0 <= marker <= 0xD7):
                        i += 2
                        continue
                    if i + 4 > len(data):
                        break
                    seg_len = struct.unpack(">H", data[i + 2 : i + 4])[0]
                    if seg_len < 2:
                        break
                    i += 2 + seg_len
    except OSError:
        return None
    try:
        from PIL import Image  # type: ignore

        with Image.open(path) as im:
            return im.size
    except Exception:
        return None


def parse_wav_duration(path: pathlib.Path) -> float | None:
    if path.suffix.lower() != ".wav":
        return None
    try:
        with wave.open(str(path), "rb") as wf:
            rate = wf.getframerate()
            if rate > 0:
                return round(wf.getnframes() / float(rate), 2)
    except Exception:
        return None
    return None


def infer_spritesheet(path: pathlib.Path, w: int | None, h: int | None) -> dict[str, int] | None:
    if not w or not h:
        return None
    sib_json = path.with_suffix(".json")
    if sib_json.exists():
        meta = _read_json(sib_json)
        cols = meta.get("frames") or meta.get("cols") or meta.get("frame_count")
        rows = meta.get("rows") or meta.get("directions") or 1
        if isinstance(cols, int) and cols > 1:
            return {"frames": cols, "rows": int(rows) if isinstance(rows, int) and rows > 0 else 1}
        if isinstance(cols, list) and len(cols) > 1:
            return {"frames": len(cols), "rows": 1}
        if isinstance(meta.get("animations"), dict):
            fw = meta.get("frame_width") or meta.get("cell_w")
            fh = meta.get("frame_height") or meta.get("cell_h")
            if isinstance(fw, int) and isinstance(fh, int) and fw > 0 and fh > 0:
                return {"frames": max(1, w // fw), "rows": max(1, h // fh)}
    name = path.name
    if name in KNOWN_SHEET_FRAMES:
        return {"frames": KNOWN_SHEET_FRAMES[name], "rows": 1}
    if name.startswith("anim_") and name.endswith("_run.png") and w > h:
        return {"frames": 8, "rows": 1}
    m = re.search(r"_(\d+)f(?:_|\.)", name)
    if m:
        cnt = int(m.group(1))
        if cnt > 1:
            return {"frames": cnt, "rows": 1}
    if w > h * 1.8 and w % h == 0 and (w // h) <= 24:
        return {"frames": w // h, "rows": 1}
    if "8dir" in name and w >= 512 and h >= 512 and h % 8 == 0:
        cell = h // 8
        if cell > 0 and w % cell == 0:
            return {"frames": w // cell, "rows": 8}
    return None


def parse_project_godot(root: pathlib.Path) -> dict[str, Any]:
    pg_path = root / "project.godot"
    info: dict[str, Any] = {
        "name": "",
        "description": "",
        "version": "",
        "main_scene": "",
        "icon": "",
        "autoloads": [],
        "viewport": {"width": 1280, "height": 720},
        "rendering": {},
    }
    if not pg_path.exists():
        return info
    section = ""
    for raw in _read_text(pg_path).splitlines():
        line = raw.strip()
        if not line or line.startswith(";"):
            continue
        if line.startswith("[") and line.endswith("]"):
            section = line[1:-1].strip()
            continue
        if "=" not in line:
            continue
        k, v = [p.strip() for p in line.split("=", 1)]
        val = v.strip('"')
        if section == "application":
            if k == "config/name":
                info["name"] = val
            elif k == "config/description":
                info["description"] = val
            elif k == "config/version":
                info["version"] = val
            elif k == "run/main_scene":
                info["main_scene"] = val
            elif k == "config/icon":
                info["icon"] = val
        elif section == "autoload":
            singleton = val.lstrip("*")
            info["autoloads"].append({"name": k, "path": singleton})
        elif section == "display":
            if k == "window/size/viewport_width" and val.isdigit():
                info["viewport"]["width"] = int(val)
            elif k == "window/size/viewport_height" and val.isdigit():
                info["viewport"]["height"] = int(val)
        elif section == "rendering":
            info["rendering"][k] = val
    return info


def scan_references(root: pathlib.Path) -> tuple[dict[str, list[str]], dict[str, list[str]]]:
    file_to_refs: dict[str, list[str]] = {}
    ref_to_files: dict[str, list[str]] = defaultdict(list)
    targets: list[pathlib.Path] = []
    for folder, pattern in [
        ("scripts", "*.gd"),
        ("scenes", "*.tscn"),
        ("shaders", "*.gdshader"),
        ("data", "*.json"),
    ]:
        base = root / folder
        if base.exists():
            targets.extend(sorted(base.rglob(pattern)))
    pg = root / "project.godot"
    if pg.exists():
        targets.append(pg)
    for p in targets:
        rel = p.relative_to(root).as_posix()
        refs = sorted(set(RES_RE.findall(_read_text(p))))
        file_to_refs[rel] = refs
        for r in refs:
            ref_to_files[r].append(rel)
    return file_to_refs, {k: sorted(set(v)) for k, v in ref_to_files.items()}


def parse_ui_theme(root: pathlib.Path) -> dict[str, Any]:
    theme_path = root / "scripts/ui/xianxia_ui_theme.gd"
    tokens: list[dict[str, Any]] = []
    variants = [
        {
            "id": "primary",
            "label": "主按钮 (Primary)",
            "bg": "rgba(28, 94, 79, 0.96)",
            "border": "#e0b34d",
            "text": "#fff5d9",
        },
        {
            "id": "cinnabar",
            "label": "朱砂警示 (Cinnabar)",
            "bg": "rgba(173, 54, 36, 0.98)",
            "border": "#fcde7a",
            "text": "#fff5db",
        },
        {
            "id": "secondary",
            "label": "宣纸次按钮 (Secondary)",
            "bg": "#fcf7e8",
            "border": "#338f7a",
            "text": "#1a3830",
        },
        {
            "id": "dark_gold",
            "label": "玄玉暗金 (Dark Gold)",
            "bg": "rgba(23, 61, 54, 0.94)",
            "border": "#e0b34d",
            "text": "#fff2d1",
        },
    ]
    if not theme_path.exists():
        return {"tokens": tokens, "variants": variants}
    col_re = re.compile(
        r"const\s+(COL_[A-Z0-9_]+)\s*:=\s*Color\(\s*([0-9.]+)\s*,\s*([0-9.]+)\s*,\s*([0-9.]+)(?:\s*,\s*([0-9.]+))?\s*\)"
    )
    for m in col_re.finditer(_read_text(theme_path)):
        name = m.group(1)
        r = max(0, min(255, round(float(m.group(2)) * 255)))
        g = max(0, min(255, round(float(m.group(3)) * 255)))
        b = max(0, min(255, round(float(m.group(4)) * 255)))
        a = float(m.group(5)) if m.group(5) is not None else 1.0
        tokens.append(
            {
                "name": name,
                "hex": f"#{r:02X}{g:02X}{b:02X}",
                "css": f"rgba({r}, {g}, {b}, {a:.2f})",
                "alpha": round(a, 2),
            }
        )
    return {"tokens": tokens, "variants": variants}


def scan_ui_compliance(root: pathlib.Path) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    scripts_dir = root / "scripts"
    if not scripts_dir.exists():
        return rows
    for p in sorted(scripts_dir.rglob("*.gd")):
        rel = p.relative_to(root).as_posix()
        txt = _read_text(p)
        raw_sb = len(re.findall(r"StyleBoxFlat\.new", txt))
        theme_calls = len(re.findall(r"XianxiaUITheme", txt))
        if raw_sb == 0 and theme_calls == 0:
            continue
        is_theme_def = rel == "scripts/ui/xianxia_ui_theme.gd"
        if is_theme_def:
            status = "theme_source"
        elif raw_sb == 0:
            status = "compliant"
        elif theme_calls == 0:
            status = "full_bypass"
        else:
            status = "partial_bypass"
        rows.append(
            {
                "file": rel,
                "stylebox_new": raw_sb,
                "theme_calls": theme_calls,
                "status": status,
            }
        )
    rows.sort(key=lambda r: (0 if r["status"] == "theme_source" else 1, -r["stylebox_new"], r["file"]))
    return rows


def parse_story_gd(root: pathlib.Path) -> dict[str, Any]:
    story_path = root / "scripts/story.gd"
    out: dict[str, Any] = {
        "intros": {},
        "outros": {},
        "title_art": "",
        "ending_art": "",
    }
    if not story_path.exists():
        return out
    txt = _read_text(story_path)
    m_intro_blk = re.search(r"const\s+CHAPTER_INTRO[^=]*=\s*\{(.*?)\n\}", txt, re.S)
    if m_intro_blk:
        for cm in re.finditer(r"(\d+)\s*:\s*\[(.*?)\]", m_intro_blk.group(1), re.S):
            cid = int(cm.group(1))
            lines = re.findall(r'"([^"]*)"', cm.group(2))
            out["intros"][cid] = lines
    m_outro_blk = re.search(r"const\s+CHAPTER_OUTRO[^=]*=\s*\{(.*?)\n\}", txt, re.S)
    if m_outro_blk:
        for om in re.finditer(r'(\d+)\s*:\s*"([^"]*)"', m_outro_blk.group(1)):
            out["outros"][int(om.group(1))] = om.group(2)
    m_title = re.search(r'TITLE_ART_PATH[^=]*=\s*"([^"]+)"', txt)
    m_end = re.search(r'ENDING_ART_PATH[^=]*=\s*"([^"]+)"', txt)
    if m_title:
        out["title_art"] = m_title.group(1)
    if m_end:
        out["ending_art"] = m_end.group(1)
    return out


def parse_enemy_visual_species(root: pathlib.Path) -> dict[str, Any]:
    species_sheets = {
        0: "res://assets/sprites/anim_fox_run.png",
        1: "res://assets/sprites/anim_paper_doll_float.png",
        2: "res://assets/sprites/anim_shanxiao_run.png",
        3: "res://assets/sprites/anim_jiangshi_run.png",
        4: "res://assets/sprites/anim_jinchan_run.png",
        5: "res://assets/sprites/anim_shenjing_run.png",
        6: "res://assets/sprites/anim_huodou_run.png",
    }
    boss_sheets = {
        "wolf": "res://assets/sprites/anim_wolf_boss_run.png",
        "ghost": "res://assets/sprites/anim_paper_doll_float.png",
        "skeleton": "res://assets/sprites/anim_boar_run.png",
    }
    return {"species_sheets": species_sheets, "boss_sheets": boss_sheets}


def parse_codex_drift(root: pathlib.Path, counts: dict[str, int]) -> list[dict[str, str]]:
    codex_path = root / "scripts/v2/v2_codex_panel.gd"
    if not codex_path.exists():
        return []
    txt = _read_text(codex_path)
    m = re.search(r"const\s+TAB_NAMES\s*:=\s*\[(.*?)\]", txt)
    if not m:
        return []
    labels = re.findall(r'"([^"]+)"', m.group(1))
    drifts: list[dict[str, str]] = []
    for lbl in labels:
        if "五行反应" in lbl and f"({counts['reactions']})" not in lbl:
            drifts.append(
                {
                    "label": lbl,
                    "expected": f"五行反应 ({counts['reactions']})",
                    "file": "scripts/v2/v2_codex_panel.gd",
                }
            )
        if "法宝与超武" in lbl:
            expected = f"({counts['weapons']}+{counts['fusions']})"
            if expected not in lbl:
                drifts.append(
                    {
                        "label": lbl,
                        "expected": f"法宝与超武 {expected}",
                        "file": "scripts/v2/v2_codex_panel.gd",
                    }
                )
    return drifts


def _categorize_asset(rel: str) -> str:
    if "assets/_legacy_unused/" in rel:
        return "legacy_unused"
    if rel.startswith("addons/"):
        return "vfx_particles"
    if "/heroes/" in rel or "hero_" in pathlib.Path(rel).name:
        return "heroes"
    if "/weapons/" in rel or pathlib.Path(rel).name.startswith("wpn_"):
        return "weapons"
    if "/map_ch1/" in rel or "/maps/" in rel or "/terrain/" in rel or "/props/" in rel:
        return "terrain_maps"
    if "/icons/" in rel or "pickup_" in pathlib.Path(rel).name or "exp_gem" in pathlib.Path(rel).name:
        return "icons_pickups"
    if "/particles/" in rel or pathlib.Path(rel).name.startswith("fx_"):
        return "vfx_particles"
    if "/art/" in rel:
        return "art_story"
    if "/audio/" in rel:
        return "audio_bgm" if pathlib.Path(rel).name.startswith("music_") else "audio_sfx"
    if (
        "/sprites/" in rel
        or "/creatures/" in rel
        or "/characters/" in rel
        or "/concept/" in rel
        or "/elite_generated/" in rel
    ):
        return "enemies"
    return "fonts_other"


def _stem_cluster(filename: str) -> str:
    stem = pathlib.Path(filename).stem
    for prefix in ("anim_elite_", "anim_", "enemy_elite_", "enemy_", "lpc_wolf_", "wolf_", "hero_"):
        if stem.startswith(prefix):
            return prefix.rstrip("_")
    return stem.split("_")[0]


def scan_assets(root: pathlib.Path, ref_to_files: dict[str, list[str]]) -> list[dict[str, Any]]:
    assets: list[dict[str, Any]] = []
    scan_roots = [root / "assets", root / "addons"]
    for base in scan_roots:
        if not base.exists():
            continue
        for p in sorted(base.rglob("*")):
            if not p.is_file():
                continue
            if p.name.endswith(".import") or p.name == ".gdignore":
                continue
            rel = p.relative_to(root).as_posix()
            ext = p.suffix.lower()
            if ext not in MEDIA_EXTS and ext not in {".tres", ".ttf", ".otf", ".txt", ".md", ".json"}:
                continue
            res_path = f"res://{rel}"
            used_by = ref_to_files.get(res_path, [])
            is_legacy = "assets/_legacy_unused/" in rel
            is_media = ext in MEDIA_EXTS
            w, h = (None, None)
            duration = None
            sheet = None
            if ext in IMAGE_EXTS:
                dims = parse_image_size(p)
                if dims:
                    w, h = dims
                sheet = infer_spritesheet(p, w, h)
            elif ext in AUDIO_EXTS:
                duration = parse_wav_duration(p)
            if is_legacy:
                status = "legacy"
            elif used_by:
                status = "used"
            elif is_media:
                status = "orphan"
            else:
                status = "doc_meta"
            assets.append(
                {
                    "path": rel,
                    "res_path": res_path,
                    "name": p.name,
                    "category": _categorize_asset(rel),
                    "ext": ext,
                    "is_media": is_media,
                    "is_image": ext in IMAGE_EXTS,
                    "is_audio": ext in AUDIO_EXTS,
                    "size_bytes": p.stat().st_size,
                    "width": w,
                    "height": h,
                    "duration_sec": duration,
                    "spritesheet": sheet,
                    "used_by": used_by,
                    "status": status,
                    "cluster": _stem_cluster(p.name),
                }
            )
    return assets


def scan_scenes_and_scripts(root: pathlib.Path) -> dict[str, Any]:
    scenes: list[dict[str, Any]] = []
    scenes_dir = root / "scenes"
    if scenes_dir.exists():
        for p in sorted(scenes_dir.glob("*.tscn")):
            rel = p.relative_to(root).as_posix()
            txt = _read_text(p)
            sub_scenes = sorted(set(re.findall(r'path="(res://scenes/[^"]+\.tscn)"', txt)))
            scripts = sorted(set(re.findall(r'path="(res://scripts/[^"]+\.gd)"', txt)))
            role = "ui" if ("ui" in p.stem or p.stem in ("pause_menu", "title")) else ("core" if p.stem in ("main", "player", "enemy") else "entity")
            scenes.append({"path": rel, "name": p.stem, "role": role, "sub_scenes": sub_scenes, "scripts": scripts})
    v2_scripts = sorted(p.relative_to(root).as_posix() for p in (root / "scripts/v2").glob("*.gd")) if (root / "scripts/v2").exists() else []
    shaders = sorted(p.relative_to(root).as_posix() for p in (root / "shaders").glob("*.gdshader")) if (root / "shaders").exists() else []
    return {"scenes": scenes, "v2_scripts": v2_scripts, "shaders": shaders}


def validate_project(
    root: pathlib.Path,
    data: dict[str, Any],
    file_to_refs: dict[str, list[str]],
    assets: list[dict[str, Any]],
    ui_compliance: list[dict[str, Any]],
    story_info: dict[str, Any],
    codex_drifts: list[dict[str, str]],
) -> list[dict[str, Any]]:
    issues: list[dict[str, Any]] = []
    idx = 0

    def add_issue(
        severity: str,
        code: str,
        title: str,
        detail: str,
        file: str = "",
        entity_id: str = "",
        tab: str = "overview",
        prompt_hint: dict[str, Any] | None = None,
    ) -> None:
        nonlocal idx
        idx += 1
        issues.append(
            {
                "id": f"ISS-{idx:03d}",
                "severity": severity,
                "code": code,
                "title": title,
                "detail": detail,
                "file": file,
                "entity_id": entity_id,
                "tab": tab,
                "prompt_hint": prompt_hint,
            }
        )

    # 1. BROKEN_ASSET_REF
    for src_file, refs in sorted(file_to_refs.items()):
        for res_path in refs:
            rel = res_path[len("res://") :]
            if not (root / rel).exists():
                add_issue(
                    "error",
                    "BROKEN_ASSET_REF",
                    f"引用文件不存在：{res_path}",
                    f"在 {src_file} 中引用了 {res_path}，但磁盘中未找到该文件。",
                    file=src_file,
                    entity_id=res_path,
                    tab="assets",
                )

    # 2. BROKEN_DATA_FK
    weapons_json = data["weapons_v2"]
    weapon_ids = {w["id"] for w in weapons_json.get("weapons", [])}
    fusion_ids = {f["id"] for f in weapons_json.get("fusion_recipes", [])}
    all_weapon_ids = weapon_ids | fusion_ids
    reaction_ids = {r["id"] for r in data["reactions_v2"].get("reactions", [])}
    sh_rx = data["reactions_v2"].get("shatter_reaction", {})
    if isinstance(sh_rx, dict) and sh_rx.get("id"):
        reaction_ids.add(sh_rx["id"])
    arch_ids = {a["id"] for a in data["enemies_waves_v2"].get("archetypes", [])}
    char_ids = {c["id"] for c in data["characters_v2"].get("characters", [])}
    arcana_ids = {a["id"] for a in data["arcana_v2"].get("arcanas", [])}

    for arc in data["arcana_v2"].get("arcanas", []):
        for wid in arc.get("whitelist_weapons", []):
            if wid not in all_weapon_ids:
                add_issue(
                    "error",
                    "BROKEN_DATA_FK",
                    f"道韵 {arc['name']} 引用了不存在的法宝 {wid}",
                    f"data/v2/arcana_v2.json 中 {arc['id']}.whitelist_weapons 包含无效 ID `{wid}`。",
                    file="data/v2/arcana_v2.json",
                    entity_id=arc["id"],
                    tab="arch",
                )
        for rid in arc.get("whitelist_reactions", []):
            if rid not in reaction_ids:
                add_issue(
                    "error",
                    "BROKEN_DATA_FK",
                    f"道韵 {arc['name']} ({arc['id']}) 引用失效反应 {rid}",
                    f"data/v2/arcana_v2.json 中 whitelist_reactions 指向 `{rid}`，但 data/v2/reactions_v2.json 中仅存在 {sorted(reaction_ids)}。",
                    file="data/v2/arcana_v2.json",
                    entity_id=arc["id"],
                    tab="arch",
                )

    for ch in data["characters_v2"].get("characters", []):
        sw = ch.get("v2_start_weapon", "")
        if sw and sw not in weapon_ids:
            add_issue(
                "error",
                "BROKEN_DATA_FK",
                f"角色 {ch['name']} 初始法宝无效：{sw}",
                f"data/v2/characters_v2.json 中 {ch['id']}.v2_start_weapon 未在 weapons_v2.json 找到。",
                file="data/v2/characters_v2.json",
                entity_id=ch["id"],
                tab="arch",
            )

    for st in data["stages_v2"].get("stages", []):
        for wv in st.get("waves", []):
            for p in wv.get("pool", []):
                eid = p.get("id", "")
                if eid and eid not in arch_ids:
                    add_issue(
                        "error",
                        "BROKEN_DATA_FK",
                        f"第 {st['id']} 关第 {wv['wave']} 波引用未知怪物 {eid}",
                        "data/v2/stages_v2.json 波次怪池存在未在 enemies_waves_v2.json 定义的原型。",
                        file="data/v2/stages_v2.json",
                        entity_id=f"stage_{st['id']}",
                        tab="progression",
                    )

    for ach in data["achievements_v2"].get("achievements", []):
        rtype = ach.get("reward_type", "")
        rid = ach.get("reward_id", "")
        if rtype == "unlock_character" and rid not in char_ids:
            add_issue(
                "error",
                "BROKEN_DATA_FK",
                f"成就 {ach['name']} 解锁角色不存在：{rid}",
                "data/v2/achievements_v2.json 的 reward_id 未在 characters_v2.json 定义。",
                file="data/v2/achievements_v2.json",
                entity_id=ach["id"],
                tab="arch",
            )
        if rtype == "unlock_arcana" and rid not in arcana_ids:
            add_issue(
                "error",
                "BROKEN_DATA_FK",
                f"成就 {ach['name']} 解锁道韵不存在：{rid}",
                "data/v2/achievements_v2.json 的 reward_id 未在 arcana_v2.json 定义。",
                file="data/v2/achievements_v2.json",
                entity_id=ach["id"],
                tab="arch",
            )

    # 3. MISSING_ART_SLOT
    items_missing = [it for it in data["items_v2"].get("items", []) if not it.get("icon")]
    if items_missing:
        add_issue(
            "gap",
            "MISSING_ART_SLOT",
            f"商店宝物缺少独立图标 ({len(items_missing)}/{len(data['items_v2'].get('items', []))})",
            "data/v2/items_v2.json 所有宝物均未配置 icon 字段（如 res://assets/v2/items/item_*.png）。",
            file="data/v2/items_v2.json",
            entity_id="items_icons",
            tab="progression",
            prompt_hint={
                "kind": "item_icons",
                "title": "补齐 16 件商店宝物图标",
                "targets": [f"res://assets/v2/items/{it['id']}.png ({it['name']})" for it in items_missing],
                "spec": "64×64 或 48×48 透明底 PNG，国风 Q 版仙侠法器风格，参考 assets/v2/weapons/ 与 assets/icons/relic_*.png，并回填 data/v2/items_v2.json 的 icon 字段。",
            },
        )

    arc_missing = [a for a in data["arcana_v2"].get("arcanas", []) if not a.get("icon")]
    if arc_missing:
        add_issue(
            "gap",
            "MISSING_ART_SLOT",
            f"天道道韵缺少独立图标 ({len(arc_missing)}/{len(data['arcana_v2'].get('arcanas', []))})",
            "data/v2/arcana_v2.json 所有道韵条目均未配置 icon 字段。",
            file="data/v2/arcana_v2.json",
            entity_id="arcana_icons",
            tab="progression",
            prompt_hint={
                "kind": "arcana_icons",
                "title": "补齐 8 张天道道韵徽章图标",
                "targets": [f"res://assets/v2/arcana/{a['id']}.png ({a['name']})" for a in arc_missing],
                "spec": "64×64 透明底古玉符印徽章 PNG，参考 assets/icons/ 与 xianxia_ui_theme 鎏金青玉配色，并回填 data/v2/arcana_v2.json 的 icon 字段。",
            },
        )

    pickups_missing = [p for p in data["pickups_v2"].get("pickups", []) if not (p.get("icon") or p.get("sprite"))]
    if pickups_missing:
        add_issue(
            "gap",
            "MISSING_ART_SLOT",
            f"局内掉落物未在 JSON 登记贴图 ({len(pickups_missing)}/{len(data['pickups_v2'].get('pickups', []))})",
            "data/v2/pickups_v2.json 缺少 icon/sprite 字段（当前 assets/sprites/pickup_*.png 与代码靠硬编码关联）。",
            file="data/v2/pickups_v2.json",
            entity_id="pickup_icons",
            tab="progression",
        )

    fusions_reused = [f for f in weapons_json.get("fusion_recipes", []) if f.get("icon") in {w.get("icon") for w in weapons_json.get("weapons", [])}]
    if fusions_reused:
        add_issue(
            "gap",
            "MISSING_ART_SLOT",
            f"合体超武复用基础法宝图标 ({len(fusions_reused)}/{len(weapons_json.get('fusion_recipes', []))})",
            "3 件合体超武均复用基础法宝图标，缺少专属超武高阶图标。",
            file="data/v2/weapons_v2.json",
            entity_id="fusion_icons",
            tab="progression",
            prompt_hint={
                "kind": "fusion_icons",
                "title": "生成 3 件仙阶合体超武专属图标",
                "targets": [f"res://assets/v2/weapons/{f['id']}.png ({f['name']})" for f in fusions_reused],
                "spec": "128×128 透明底 PNG，风格与 assets/v2/weapons/wpn_jade_sword.png 一致但增加双元素合体金边特效。",
            },
        )

    map_chapters = {i + 1: ch for i, ch in enumerate(data["map_arena_v2"].get("chapters", []))}
    stages_all = data["stages_v2"].get("stages", [])
    missing_stage_maps = [st for st in stages_all if st["id"] not in map_chapters]
    if missing_stage_maps:
        missing_ids = ", ".join(str(st["id"]) for st in missing_stage_maps)
        add_issue(
            "gap",
            "MISSING_ART_SLOT",
            f"第 {missing_ids} 关缺少地图地标与掩体配置 ({len(missing_stage_maps)}/{len(stages_all)} 关空缺)",
            f"data/v2/map_arena_v2.json 未配置第 {missing_ids} 关的中心锚点、掩体柱与 4 个交互地标。",
            file="data/v2/map_arena_v2.json",
            entity_id=f"map_missing_{missing_ids.replace(', ', '_')}",
            tab="progression",
            prompt_hint={
                "kind": "stage_maps",
                "title": f"补齐第 {missing_ids} 关地图地标与掩体贴图",
                "targets": [f"关卡 {st['id']} · {st['name']}：中心锚点 + 掩体柱 + 4 个主题地标 (assets/v2/map_ch{st['id']}/)" for st in missing_stage_maps],
                "spec": "参考 assets/v2/map_ch1/ 的 6 个 PNG 规格与 data/v2/map_arena_v2.json 结构，保持俯视角 2.5D 国风水墨 Q 版一致。",
            },
        )

    species_groups: dict[int, list[str]] = defaultdict(list)
    for arch in data["enemies_waves_v2"].get("archetypes", []):
        species_groups[int(arch.get("species", -1))].append(arch["name"])
    shared_species = {sp: names for sp, names in species_groups.items() if len(names) > 1}
    if shared_species:
        detail_str = "；".join(f"species={sp}: {', '.join(names)}" for sp, names in sorted(shared_species.items()))
        add_issue(
            "gap",
            "MISSING_ART_SLOT",
            f"部分怪物原型共用同一套 species 贴图 ({len(shared_species)} 组撞皮)",
            f"enemies_waves_v2.json 未登记独立 sprite 字段，以下怪物在 enemy_visual.gd 中渲染同一张精灵表：{detail_str}。",
            file="data/v2/enemies_waves_v2.json",
            entity_id="enemy_shared_species",
            tab="progression",
        )

    # 4. STORY_STAGE_MISMATCH
    story_ch_count = len(story_info.get("intros", {}))
    stage_count = len(data["stages_v2"].get("stages", []))
    if story_ch_count != stage_count:
        add_issue(
            "warning",
            "STORY_STAGE_MISMATCH",
            f"剧情章节数 ({story_ch_count}) 与 V2 关卡数 ({stage_count}) 不一致",
            f"scripts/story.gd 维护了 {story_ch_count} 章旧剧情且 assets/art/chapter_1~6.png 均未引用；data/v2/stages_v2.json 为 {stage_count} 关，且第 2 关标题已改为《落霞花溪》但剧情仍写赤砂/红月。",
            file="scripts/story.gd",
            entity_id="story_vs_stages",
            tab="progression",
        )

    # 5. ORPHAN_ASSET
    orphan_media = [a for a in assets if a["status"] == "orphan"]
    if orphan_media:
        clusters: dict[str, int] = defaultdict(int)
        for a in orphan_media:
            clusters[a["cluster"]] += 1
        top_clusters = ", ".join(f"{k}({v})" for k, v in sorted(clusters.items(), key=lambda x: -x[1])[:6])
        add_issue(
            "warning",
            "ORPHAN_ASSET",
            f"活跃目录存在 {len(orphan_media)} 个未引用媒体文件（含多版本残留）",
            f"assets/ 非归档目录中有 {len(orphan_media)} 个 PNG/JPG/WAV/OGG 未被任何代码、场景或 JSON 引用。高频聚类：{top_clusters}。建议确认后移入 assets/_legacy_unused/。",
            file="assets/",
            entity_id="orphan_assets",
            tab="assets",
        )

    # 6. UI_THEME_BYPASS
    bypass_files = [u for u in ui_compliance if u["status"] in ("full_bypass", "partial_bypass")]
    if bypass_files:
        total_raw = sum(u["stylebox_new"] for u in bypass_files)
        top = ", ".join(f"{pathlib.Path(u['file']).name}({u['stylebox_new']})" for u in bypass_files[:5])
        add_issue(
            "warning",
            "UI_THEME_BYPASS",
            f"{len(bypass_files)} 个 UI 脚本绕过 XianxiaUITheme 私写 {total_raw} 处 StyleBoxFlat.new()",
            f"易导致弹窗与按钮样式分裂。主要脚本：{top}。请在 UI 规范板核对。",
            file="scripts/ui/xianxia_ui_theme.gd",
            entity_id="ui_theme_bypass",
            tab="uikit",
        )

    # 7. DOC_CODE_DRIFT
    for dr in codex_drifts:
        add_issue(
            "warning",
            "DOC_CODE_DRIFT",
            f"图鉴硬编码计数漂移：{dr['label']} → 实际应为 {dr['expected']}",
            f"{dr['file']} 的 TAB_NAMES 写死了数量文字，与 data/v2/*.json 实时条目数不一致。",
            file=dr["file"],
            entity_id="codex_tab_drift",
            tab="arch",
        )

    return issues


def build_progression_stages(
    data: dict[str, Any],
    story_info: dict[str, Any],
    enemy_vis: dict[str, Any],
) -> list[dict[str, Any]]:
    stages_out: list[dict[str, Any]] = []
    map_chapters = data["map_arena_v2"].get("chapters", [])
    arch_by_id = {a["id"]: a for a in data["enemies_waves_v2"].get("archetypes", [])}
    achievements = data["achievements_v2"].get("achievements", [])
    species_sheets = enemy_vis["species_sheets"]
    boss_sheets = enemy_vis["boss_sheets"]

    for idx, st in enumerate(data["stages_v2"].get("stages", [])):
        sid = int(st["id"])
        map_cfg = map_chapters[idx] if idx < len(map_chapters) else None
        wave_enemy_ids: list[str] = []
        seen_e: set[str] = set()
        events_count = 0
        for wv in st.get("waves", []):
            events_count += len(wv.get("events", []))
            for p in wv.get("pool", []):
                eid = p.get("id", "")
                if eid and eid not in seen_e:
                    seen_e.add(eid)
                    wave_enemy_ids.append(eid)
        enemies_resolved = []
        for eid in wave_enemy_ids:
            arch = arch_by_id.get(eid, {})
            sp = int(arch.get("species", 0))
            enemies_resolved.append(
                {
                    "id": eid,
                    "name": arch.get("name", eid),
                    "species": sp,
                    "sprite": species_sheets.get(sp, ""),
                }
            )
        linked_achs = [
            {"id": a["id"], "name": a["name"], "reward_desc": a.get("reward_desc", "")}
            for a in achievements
            if a.get("metric") == f"cleared_stage_{sid}"
        ]
        boss_type = st.get("boss_type", "wolf")
        stages_out.append(
            {
                "id": sid,
                "name": st.get("name", ""),
                "subtitle": st.get("subtitle", ""),
                "difficulty": st.get("difficulty", ""),
                "duration": st.get("duration", 0),
                "boss_name": st.get("boss_name", ""),
                "boss_type": boss_type,
                "boss_hp": st.get("boss_hp", 0),
                "boss_sprite": boss_sheets.get(boss_type, ""),
                "floor_tile": st.get("floor_tile", ""),
                "palette": st.get("palette", {}),
                "story": {
                    "intro": story_info["intros"].get(sid, []),
                    "outro": story_info["outros"].get(sid, ""),
                    "chapter_art": f"res://assets/art/chapter_{sid}.png",
                },
                "map_arena": {
                    "configured": map_cfg is not None,
                    "chapter_name": map_cfg.get("name", "") if map_cfg else "",
                    "center_anchor": map_cfg.get("center_anchor", {}).get("texture", "") if map_cfg else "",
                    "cover_count": len(map_cfg.get("cover_pillars", [])) if map_cfg else 0,
                    "landmarks": [
                        {"id": lm["id"], "name": lm["name"], "texture": lm.get("texture", "")}
                        for lm in (map_cfg.get("landmarks", []) if map_cfg else [])
                    ],
                },
                "wave_count": len(st.get("waves", [])),
                "events_count": events_count,
                "enemies": enemies_resolved,
                "achievements": linked_achs,
            }
        )
    return stages_out


def build_data_graph(data: dict[str, Any], issues: list[dict[str, Any]]) -> dict[str, Any]:
    broken_by_file: dict[str, list[str]] = defaultdict(list)
    for iss in issues:
        if iss["code"] == "BROKEN_DATA_FK" and iss["file"]:
            broken_by_file[iss["file"]].append(iss["title"])

    nodes = [
        {"id": "stages_v2", "label": "stages_v2.json", "count": len(data["stages_v2"].get("stages", [])), "group": "progression", "x": 80, "y": 50},
        {"id": "map_arena_v2", "label": "map_arena_v2.json", "count": len(data["map_arena_v2"].get("chapters", [])), "group": "progression", "x": 80, "y": 150},
        {"id": "story_gd", "label": "story.gd", "count": 6, "group": "code", "x": 80, "y": 250},
        {"id": "enemies_waves_v2", "label": "enemies_waves_v2.json", "count": len(data["enemies_waves_v2"].get("archetypes", [])), "group": "combat", "x": 340, "y": 50},
        {"id": "enemy_visual_gd", "label": "enemy_visual.gd", "count": 7, "group": "code", "x": 340, "y": 150},
        {"id": "characters_v2", "label": "characters_v2.json", "count": len(data["characters_v2"].get("characters", [])), "group": "meta", "x": 340, "y": 250},
        {"id": "weapons_v2", "label": "weapons_v2.json", "count": len(data["weapons_v2"].get("weapons", [])) + len(data["weapons_v2"].get("fusion_recipes", [])), "group": "combat", "x": 600, "y": 100},
        {"id": "reactions_v2", "label": "reactions_v2.json", "count": len(data["reactions_v2"].get("reactions", [])), "group": "combat", "x": 600, "y": 220},
        {"id": "arcana_v2", "label": "arcana_v2.json", "count": len(data["arcana_v2"].get("arcanas", [])), "group": "meta", "x": 850, "y": 160},
        {"id": "achievements_v2", "label": "achievements_v2.json", "count": len(data["achievements_v2"].get("achievements", [])), "group": "meta", "x": 850, "y": 270},
        {"id": "items_v2", "label": "items_v2.json", "count": len(data["items_v2"].get("items", [])), "group": "economy", "x": 600, "y": 320},
        {"id": "pickups_v2", "label": "pickups_v2.json", "count": len(data["pickups_v2"].get("pickups", [])), "group": "economy", "x": 340, "y": 340},
    ]

    arcana_broken = broken_by_file.get("data/v2/arcana_v2.json", [])
    stages_all = data["stages_v2"].get("stages", [])
    map_chapters = {i + 1: ch for i, ch in enumerate(data["map_arena_v2"].get("chapters", []))}
    missing_stage_maps = [st for st in stages_all if st["id"] not in map_chapters]
    map_edge_notes: list[str] = []
    if missing_stage_maps:
        map_edge_notes.append("第 " + "、".join(str(st["id"]) for st in missing_stage_maps) + " 关缺少 map_arena_v2 地标配置")
    story_issues = [iss for iss in issues if iss["code"] == "STORY_STAGE_MISMATCH"]
    edges = [
        {"from": "stages_v2", "to": "enemies_waves_v2", "label": "waves.pool", "valid": True, "notes": []},
        {"from": "stages_v2", "to": "map_arena_v2", "label": f"chapter {len(map_chapters)}/{len(stages_all)}", "valid": len(missing_stage_maps) == 0, "notes": map_edge_notes},
        {"from": "stages_v2", "to": "story_gd", "label": "关卡 ↔ 剧情", "valid": len(story_issues) == 0, "notes": [iss["title"] for iss in story_issues]},
        {"from": "enemies_waves_v2", "to": "enemy_visual_gd", "label": "species 0..6", "valid": True, "notes": ["靠整数 species 映射贴图，存在撞皮"]},
        {"from": "characters_v2", "to": "weapons_v2", "label": "v2_start_weapon", "valid": True, "notes": []},
        {"from": "weapons_v2", "to": "reactions_v2", "label": "element", "valid": True, "notes": []},
        {"from": "arcana_v2", "to": "weapons_v2", "label": "whitelist_weapons", "valid": True, "notes": []},
        {"from": "arcana_v2", "to": "reactions_v2", "label": "whitelist_reactions", "valid": len(arcana_broken) == 0, "notes": arcana_broken},
        {"from": "achievements_v2", "to": "characters_v2", "label": "unlock_character", "valid": True, "notes": []},
        {"from": "achievements_v2", "to": "arcana_v2", "label": "unlock_arcana", "valid": True, "notes": []},
    ]
    return {"nodes": nodes, "edges": edges}


def build_manifest(root: pathlib.Path) -> dict[str, Any]:
    proj = parse_project_godot(root)
    data = {
        "stages_v2": _read_json(root / "data/v2/stages_v2.json"),
        "map_arena_v2": _read_json(root / "data/v2/map_arena_v2.json"),
        "characters_v2": _read_json(root / "data/v2/characters_v2.json"),
        "weapons_v2": _read_json(root / "data/v2/weapons_v2.json"),
        "reactions_v2": _read_json(root / "data/v2/reactions_v2.json"),
        "items_v2": _read_json(root / "data/v2/items_v2.json"),
        "arcana_v2": _read_json(root / "data/v2/arcana_v2.json"),
        "enemies_waves_v2": _read_json(root / "data/v2/enemies_waves_v2.json"),
        "pickups_v2": _read_json(root / "data/v2/pickups_v2.json"),
        "achievements_v2": _read_json(root / "data/v2/achievements_v2.json"),
    }
    file_to_refs, ref_to_files = scan_references(root)
    ui_theme = parse_ui_theme(root)
    ui_compliance = scan_ui_compliance(root)
    story_info = parse_story_gd(root)
    enemy_vis = parse_enemy_visual_species(root)
    counts = {
        "reactions": len(data["reactions_v2"].get("reactions", [])),
        "weapons": len(data["weapons_v2"].get("weapons", [])),
        "fusions": len(data["weapons_v2"].get("fusion_recipes", [])),
    }
    codex_drifts = parse_codex_drift(root, counts)
    assets = scan_assets(root, ref_to_files)
    arch_scan = scan_scenes_and_scripts(root)
    issues = validate_project(root, data, file_to_refs, assets, ui_compliance, story_info, codex_drifts)
    progression_stages = build_progression_stages(data, story_info, enemy_vis)
    data_graph = build_data_graph(data, issues)

    active_media = [a for a in assets if a["is_media"] and a["status"] != "legacy"]
    used_media = [a for a in active_media if a["status"] == "used"]
    orphan_media = [a for a in active_media if a["status"] == "orphan"]
    legacy_media = [a for a in assets if a["status"] == "legacy"]

    # Resolve enemy sprites onto entities for gallery/matrix display
    species_sheets = enemy_vis["species_sheets"]
    entities = {
        "characters": data["characters_v2"].get("characters", []),
        "weapons": data["weapons_v2"].get("weapons", []),
        "fusions": data["weapons_v2"].get("fusion_recipes", []),
        "reactions": data["reactions_v2"].get("reactions", []),
        "items": data["items_v2"].get("items", []),
        "arcanas": data["arcana_v2"].get("arcanas", []),
        "pickups": data["pickups_v2"].get("pickups", []),
        "archetypes": [
            {**a, "resolved_sprite": species_sheets.get(int(a.get("species", 0)), "")}
            for a in data["enemies_waves_v2"].get("archetypes", [])
        ],
        "elites": list(data["enemies_waves_v2"].get("elite_variants", {}).values()),
        "achievements": data["achievements_v2"].get("achievements", []),
    }

    summary = {
        "generated_at": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "active_media_count": len(active_media),
        "used_media_count": len(used_media),
        "orphan_media_count": len(orphan_media),
        "legacy_count": len(legacy_media),
        "usage_rate_pct": round(100.0 * len(used_media) / max(1, len(active_media)), 1),
        "error_count": sum(1 for i in issues if i["severity"] == "error"),
        "gap_count": sum(1 for i in issues if i["severity"] == "gap"),
        "warning_count": sum(1 for i in issues if i["severity"] == "warning"),
        "ui_bypass_files": sum(1 for u in ui_compliance if u["status"] in ("full_bypass", "partial_bypass")),
    }

    return {
        "summary": summary,
        "project": proj,
        "issues": issues,
        "progression_stages": progression_stages,
        "entities": entities,
        "assets": assets,
        "ui_theme": ui_theme,
        "ui_compliance": ui_compliance,
        "architecture": {
            "autoloads": proj["autoloads"],
            "scenes": arch_scan["scenes"],
            "v2_scripts": arch_scan["v2_scripts"],
            "shaders": arch_scan["shaders"],
            "data_graph": data_graph,
        },
    }


def render_ai_asset_guide(manifest: dict[str, Any]) -> str:
    s = manifest["summary"]
    lines: list[str] = [
        "# 《百宝小道修 · Pocket Daoist》AI 美术与架构协作速查手册",
        "",
        f"> 由 `python tools/studio_audit.py` 自动生成（{s['generated_at']}）。派活给 Codex / Claude / Antigravity 前请附带或先读本文件，严禁绕过现有规范另起炉灶。",
        "",
        "## 1. 强制工作流",
        "1. **UI 必须走唯一主题**：使用 `scripts/ui/xianxia_ui_theme.gd`（`XianxiaUITheme`），禁止在业务脚本里手写 `StyleBoxFlat.new()`。",
        "2. **美术风格走唯一圣经**：生成或重绘任何图片前必读 `docs/ART_STYLE_BIBLE.md`，遵守 8 条风格边界与黄金参考图锚定，禁止参考漂移/旧像素资产。",
        "3. **生成前先查重**：下表已列出的资源直接引用 `res://...`，不要重复生成第二套按钮、弹窗或同名角色/怪物。",
        "4. **修改后必验**：运行 `python tools/studio_audit.py`（刷新本文件与 HTML 看板）和 `python tools/studio_audit.py --strict`。",
        "",
        "## 2. 官方 UI 规范（XianxiaUITheme）",
        "| 令牌常量 | Hex | 用途 |",
        "| :--- | :--- | :--- |",
    ]
    for tok in manifest["ui_theme"]["tokens"]:
        lines.append(f"| `{tok['name']}` | `{tok['hex']}` (`α={tok['alpha']}`) | 主题色板 |")
    lines += [
        "",
        "- **按钮变体（`XianxiaUITheme.style_button(btn, variant)`）**：`primary`（青绿金边主操作）、`cinnabar`（朱砂高危/确认）、`secondary`（宣纸次操作）、`dark_gold`（玄玉暗金）。",
        "- **容器样式**：`make_hud_plate()`（HUD 暗底金框）、`make_scroll_panel()`（宣纸大弹窗 + `attach_ornaments` 回字纹角饰）、`make_card_style()`（商店/升级卡片）。",
        "",
        "## 3. 当前明确空缺与断链（AI 待办清单）",
        "| 级别 | 问题 | 涉及文件/目标 |",
        "| :--- | :--- | :--- |",
    ]
    for iss in manifest["issues"]:
        lines.append(f"| `{iss['severity'].upper()}` ({iss['code']}) | {iss['title']} | `{iss['file']}` |")

    lines += ["", "## 4. 已有核心资产速查表（直接复用，勿重复生成）"]
    lines.append("### 英雄（8 名 · 统一存放 `assets/v2/heroes/`）")
    for ch in manifest["entities"]["characters"]:
        lines.append(f"- `{ch['id']}` ({ch['name']} / {ch['role']}) -> `{ch.get('sprite', '')}` | 初始法宝 `{ch.get('v2_start_weapon', '')}`")

    lines += ["", "### 法宝与合体超武（8+3 · 统一存放 `assets/v2/weapons/`）"]
    for w in manifest["entities"]["weapons"]:
        lines.append(f"- `{w['id']}` ({w['name']}, {w.get('element', '')}) -> `{w.get('icon', '')}`")
    for f in manifest["entities"]["fusions"]:
        lines.append(f"- `{f['id']}` ({f['name']}, 合体) -> 当前复用 `{f.get('icon', '')}`")

    lines += ["", f"### 推图关卡与地砖（{len(manifest['progression_stages'])} 关）"]
    for st in manifest["progression_stages"]:
        map_tag = "已配地标" if st["map_arena"]["configured"] else "**缺 map_arena_v2 地标**"
        lines.append(f"- 第 {st['id']} 关 `{st['name']}` | Boss `{st['boss_name']}` (`{st['boss_type']}`) | 地砖 `{st['floor_tile']}` | {map_tag}")

    lines += ["", "### 怪物与精英精灵表（`scripts/enemy_visual.gd`）"]
    for a in manifest["entities"]["archetypes"]:
        lines.append(f"- `{a['id']}` ({a['name']}, species={a.get('species')}) -> `{a.get('resolved_sprite', '')}`")

    lines += ["", "### 音频与特效白名单"]
    audio_used = [a["res_path"] for a in manifest["assets"] if a["is_audio"] and a["status"] == "used"]
    lines.append("- 已接入音频：" + ", ".join(f"`{p}`" for p in audio_used))
    lines.append(f"- 归档区 `assets/_legacy_unused/` 共有 {s['legacy_count']} 个历史弃用文件，禁止新代码引用。")
    return "\n".join(lines) + "\n"


def compile_outputs(root: pathlib.Path) -> dict[str, Any]:
    manifest = build_manifest(root)
    hub_dir = root / "tools/studio_hub"
    hub_dir.mkdir(parents=True, exist_ok=True)
    gdignore = hub_dir / ".gdignore"
    if not gdignore.exists():
        gdignore.write_text("", encoding="utf-8")

    manifest_path = hub_dir / "manifest.json"
    manifest_json = json.dumps(manifest, ensure_ascii=False, indent=2)
    manifest_path.write_text(manifest_json, encoding="utf-8")

    tpl_path = hub_dir / "template.html"
    if tpl_path.exists():
        safe_inline = (
            json.dumps(manifest, ensure_ascii=False)
            .replace("</", "<\\/")
            .replace("\u2028", "\\u2028")
            .replace("\u2029", "\\u2029")
        )
        html = _read_text(tpl_path).replace("/*__MANIFEST_PLACEHOLDER__*/null", safe_inline)
        (hub_dir / "index.html").write_text(html, encoding="utf-8")

    guide_path = root / "docs/AI_ASSET_GUIDE.md"
    guide_path.parent.mkdir(parents=True, exist_ok=True)
    guide_path.write_text(render_ai_asset_guide(manifest), encoding="utf-8")
    return manifest


class StudioHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args: Any, root_dir: pathlib.Path, **kwargs: Any) -> None:
        self.root_dir = root_dir
        super().__init__(*args, directory=str(root_dir), **kwargs)

    def log_message(self, format: str, *args: Any) -> None:
        pass

    def do_GET(self) -> None:
        parsed = urllib.parse.urlparse(self.path)
        if parsed.path in ("/", "/index.html"):
            self.send_response(302)
            self.send_header("Location", "/tools/studio_hub/index.html")
            self.end_headers()
            return
        if parsed.path == "/api/manifest":
            payload = json.dumps(compile_outputs(self.root_dir), ensure_ascii=False).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
            return
        super().do_GET()

    def do_POST(self) -> None:
        parsed = urllib.parse.urlparse(self.path)
        if parsed.path == "/api/rescan":
            payload = json.dumps(compile_outputs(self.root_dir), ensure_ascii=False).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
            return
        self.send_error(404, "Not Found")


class ReusableTCPServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    allow_reuse_address = True
    daemon_threads = True


def main() -> int:
    parser = argparse.ArgumentParser(description="Pocket Daoist Studio Asset & Architecture Auditor")
    parser.add_argument("--root", default=".", help="Project root directory")
    parser.add_argument("--strict", action="store_true", help="Exit non-zero if error-level issues exist")
    parser.add_argument("--serve", action="store_true", help="Start local HTTP server with live rescan")
    parser.add_argument("--port", type=int, default=8765, help="Local HTTP server port")
    parser.add_argument("--open", action="store_true", help="Open browser when serving")
    args = parser.parse_args()

    root = pathlib.Path(args.root).resolve()
    manifest = compile_outputs(root)
    s = manifest["summary"]
    print(
        f"[StudioAudit] active_media={s['active_media_count']} used={s['used_media_count']} "
        f"orphan={s['orphan_media_count']} legacy={s['legacy_count']} usage={s['usage_rate_pct']}% | "
        f"errors={s['error_count']} gaps={s['gap_count']} warnings={s['warning_count']}"
    )
    for iss in manifest["issues"]:
        if iss["severity"] == "error":
            print(f"  [ERROR] {iss['code']}: {iss['title']} ({iss['file']})")

    if args.serve:
        handler = functools.partial(StudioHandler, root_dir=root)
        url = f"http://127.0.0.1:{args.port}/tools/studio_hub/index.html"
        print(f"[StudioHub] Serving at {url} (Ctrl+C to stop)")
        if args.open:
            webbrowser.open(url)
        with ReusableTCPServer(("127.0.0.1", args.port), handler) as httpd:
            try:
                httpd.serve_forever()
            except KeyboardInterrupt:
                print("\n[StudioHub] Stopped.")
        return 0

    if args.strict and s["error_count"] > 0:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
