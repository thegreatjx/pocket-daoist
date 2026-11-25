import math
import os
import sys
from collections import deque
import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import binary_dilation, gaussian_filter, label, map_coordinates

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import process_painted_assets as ppa

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPRITES_DIR = os.path.join(PROJECT_ROOT, "assets", "sprites")
RAW_SHEET_DIR = r"C:\Users\jiang\.gemini\antigravity\brain\1a128617-8a1b-42f1-becf-fa18a059389b"
PREVIEW_PATH = os.path.join(RAW_SHEET_DIR, "scratch", "ai_sheets_preview.png")


def _find_split_indices(fg_mask: np.ndarray, rows: int, cols: int) -> tuple[list[int], list[list[int]]]:
    h, w = fg_mask.shape
    row_proj = fg_mask.sum(axis=1).astype(np.float32)
    y_splits = [0]
    for r in range(1, rows):
        nom = int(round(h * r / float(rows)))
        lo = max(1, int(round(nom - h * 0.16 / float(rows))))
        hi = min(h - 1, int(round(nom + h * 0.16 / float(rows))))
        best_y = lo + int(np.argmin(row_proj[lo : hi + 1]))
        y_splits.append(best_y)
    y_splits.append(h)

    col_splits_per_row: list[list[int]] = []
    for r in range(rows):
        y0, y1 = y_splits[r], y_splits[r + 1]
        col_proj = fg_mask[y0:y1, :].sum(axis=0).astype(np.float32)
        xs = [0]
        for c in range(1, cols):
            nom = int(round(w * c / float(cols)))
            lo = max(1, int(round(nom - w * 0.16 / float(cols))))
            hi = min(w - 1, int(round(nom + w * 0.16 / float(cols))))
            best_x = lo + int(np.argmin(col_proj[lo : hi + 1]))
            xs.append(best_x)
        xs.append(w)
        col_splits_per_row.append(xs)
    return y_splits, col_splits_per_row


def _cutout_cell_rgba(
    rgb: np.ndarray,
    auto_holes: bool = True,
    hole_min_rgb: int = 247,
    hole_max_chroma: int = 9,
    hole_min_area: int = 32,
) -> np.ndarray:
    h, w, _ = rgb.shape
    cmax = rgb.max(axis=2).astype(np.int16)
    cmin = rgb.min(axis=2).astype(np.int16)
    chroma = cmax - cmin
    cand = (cmin >= 232) & (chroma <= 24)

    seeds: list[tuple[int, int]] = []
    for x in range(w):
        seeds.append((0, x))
        seeds.append((h - 1, x))
    for y in range(h):
        seeds.append((y, 0))
        seeds.append((y, w - 1))
    bg = ppa.flood_fill_bg(cand, seeds)

    if auto_holes:
        pure_white = (cmin >= hole_min_rgb) & (chroma <= hole_max_chroma) & (~bg)
        comp_lbl, n_comp = label(pure_white)
        if n_comp > 0:
            counts = np.bincount(comp_lbl.ravel())
            for cid in range(1, n_comp + 1):
                if counts[cid] >= hole_min_area:
                    ys, xs = np.where(comp_lbl == cid)
                    bg |= ppa.flood_fill_bg(cand, [(int(ys[0]), int(xs[0]))])

    near_bg = binary_dilation(bg, iterations=2)
    alpha = np.where(bg, 0.0, 1.0).astype(np.float32)
    rgb_f = rgb.astype(np.float32)
    lum = rgb_f.mean(axis=2)

    fringe = (~bg) & near_bg & (cmin >= 145) & (chroma <= 26)
    a_fringe = np.clip((248.0 - lum) / 145.0, 0.05, 1.0)
    alpha = np.where(fringe, a_fringe, alpha)

    safe_a = np.maximum(alpha, 0.12)
    decontam = np.clip((rgb_f - (1.0 - alpha[:, :, None]) * 255.0) / safe_a[:, :, None], 0.0, 255.0)
    out_rgb = np.where(fringe[:, :, None], decontam, rgb_f)

    # Drop tiny isolated JPEG speck components
    fg_lbl, n_fg = label(alpha > 0.08)
    if n_fg > 1:
        fg_counts = np.bincount(fg_lbl.ravel())
        keep = np.zeros_like(alpha, dtype=bool)
        for cid in range(1, n_fg + 1):
            if fg_counts[cid] >= 36:
                keep |= fg_lbl == cid
        alpha = np.where(keep, alpha, 0.0)

    rgba = np.zeros((h, w, 4), dtype=np.uint8)
    rgba[:, :, :3] = np.clip(out_rgb, 0, 255).astype(np.uint8)
    rgba[:, :, 3] = np.clip(alpha * 255.0, 0, 255).astype(np.uint8)
    return rgba


def extract_raw_cells(
    filename: str,
    rows: int,
    cols: int,
    auto_holes: bool = True,
    hole_min_rgb: int = 247,
    hole_max_chroma: int = 9,
) -> list[np.ndarray]:
    path = os.path.join(RAW_SHEET_DIR, filename)
    rgb = np.array(Image.open(path).convert("RGB"), dtype=np.uint8)
    cmax = rgb.max(axis=2).astype(np.int16)
    cmin = rgb.min(axis=2).astype(np.int16)
    fg_mask = (cmin < 236) | ((cmax - cmin) > 20)
    y_splits, col_splits = _find_split_indices(fg_mask, rows, cols)

    cells: list[np.ndarray] = []
    for r in range(rows):
        y0, y1 = y_splits[r], y_splits[r + 1]
        for c in range(cols):
            x0, x1 = col_splits[r][c], col_splits[r][c + 1]
            cell_rgba = _cutout_cell_rgba(
                rgb[y0:y1, x0:x1],
                auto_holes=auto_holes,
                hole_min_rgb=hole_min_rgb,
                hole_max_chroma=hole_max_chroma,
            )
            cells.append(cell_rgba)
    return cells


def pack_aligned_strip(
    frames_rgba: list[np.ndarray],
    target_size: int,
    out_name: str,
    align_mode: str = "foot",
) -> None:
    bboxes: list[tuple[int, int, int, int]] = []
    torso_cx_fracs: list[float] = []
    for arr in frames_rgba:
        ys, xs = np.where(arr[:, :, 3] > 18)
        x0, x1 = int(xs.min()), int(xs.max()) + 1
        y0, y1 = int(ys.min()), int(ys.max()) + 1
        bboxes.append((x0, y0, x1, y1))
        bh = max(1, y1 - y0)
        band = (ys >= y0 + int(bh * 0.22)) & (ys <= y0 + int(bh * 0.72))
        cx = float(np.median(xs[band])) if np.any(band) else 0.5 * (x0 + x1)
        torso_cx_fracs.append(cx - float(x0))

    max_w = max(b[2] - b[0] for b in bboxes)
    max_h = max(b[3] - b[1] for b in bboxes)
    inner = max(8, round(target_size * 0.90))
    scale = min(inner / float(max_w), inner / float(max_h))

    margin_bottom = max(2, round(target_size * 0.05))
    sheet = Image.new("RGBA", (target_size * len(frames_rgba), target_size), (0, 0, 0, 0))

    for i, (arr, (x0, y0, x1, y1), torso_dx) in enumerate(zip(frames_rgba, bboxes, torso_cx_fracs)):
        crop = Image.fromarray(arr[y0:y1, x0:x1], "RGBA")
        nw = max(1, round(crop.width * scale))
        nh = max(1, round(crop.height * scale))
        resized = crop.resize((nw, nh), Image.Resampling.LANCZOS)

        ox = int(round(target_size * 0.5 - torso_dx * scale))
        ox = max(2, min(target_size - nw - 2, ox))
        if align_mode == "foot":
            oy = target_size - margin_bottom - nh
        else:
            oy = (target_size - nh) // 2
        oy = max(1, min(target_size - nh - 1, oy))

        cell = Image.new("RGBA", (target_size, target_size), (0, 0, 0, 0))
        cell.paste(resized, (ox, oy), resized)
        sheet.paste(cell, (i * target_size, 0))

    dst = os.path.join(SPRITES_DIR, out_name)
    sheet.save(dst, "PNG", optimize=True)
    print(f"Saved {out_name} -> {sheet.size}, {len(frames_rgba)} frames")


def _load_master_rgba(prefix: str, work_size: int, extra_seeds=None) -> np.ndarray:
    tmp_path = os.path.join(RAW_SHEET_DIR, "scratch", f"_tmp_master_{prefix}.png")
    os.makedirs(os.path.dirname(tmp_path), exist_ok=True)
    src = ppa.find_latest_raw(prefix)
    ppa.process_cutout(src, tmp_path, target_size=work_size, extra_seeds=extra_seeds, auto_holes=False)
    return np.array(Image.open(tmp_path).convert("RGBA"), dtype=np.float32)


def _polygon_mask(h: int, w: int, poly_norm: list[tuple[float, float]], blur_sigma: float = 1.6) -> np.ndarray:
    im = Image.new("L", (w, h), 0)
    pts = [(px * w, py * h) for px, py in poly_norm]
    ImageDraw.Draw(im).polygon(pts, fill=255)
    m = np.array(im, dtype=np.float32) / 255.0
    if blur_sigma > 0.0:
        m = gaussian_filter(m, sigma=blur_sigma)
    return np.clip(m, 0.0, 1.0)


def _rotate_translate_rgba(
    rgba: np.ndarray,
    pivot_norm: tuple[float, float],
    angle: float,
    shift_norm: tuple[float, float] = (0.0, 0.0),
    knee_y_norm: float | None = None,
    knee_bend: float = 0.0,
) -> np.ndarray:
    h, w, _ = rgba.shape
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    xn = xx / float(w)
    yn = yy / float(h)

    px, py = pivot_norm
    sx, sy = shift_norm
    rx = xn - px - sx
    ry = yn - py - sy
    ca, sa = math.cos(-angle), math.sin(-angle)
    ux = rx * ca - ry * sa + px
    uy = rx * sa + ry * ca + py

    if knee_y_norm is not None and abs(knee_bend) > 1e-4:
        below = np.clip((uy - knee_y_norm) / 0.14, 0.0, 1.0)
        kb = -knee_bend * below
        cb, sb = np.cos(kb), np.sin(kb)
        kx = ux - px
        ky = uy - knee_y_norm
        ux = kx * cb - ky * sb + px
        uy = kx * sb + ky * cb + knee_y_norm

    src_x = ux * float(w)
    src_y = uy * float(h)

    alpha = rgba[:, :, 3] / 255.0
    premul = rgba[:, :, :3] * alpha[:, :, None]
    out = np.zeros_like(rgba)
    out_a = np.clip(map_coordinates(alpha, [src_y, src_x], order=1, mode="constant", cval=0.0), 0.0, 1.0)
    safe_a = np.maximum(out_a, 1e-4)
    for c in range(3):
        ch = map_coordinates(premul[:, :, c], [src_y, src_x], order=1, mode="constant", cval=0.0)
        out[:, :, c] = np.clip(ch / safe_a, 0.0, 255.0)
    out[:, :, 3] = out_a * 255.0
    return out


def _alpha_over(dst: np.ndarray, src: np.ndarray) -> np.ndarray:
    sa = np.clip(src[:, :, 3:4] / 255.0, 0.0, 1.0)
    da = np.clip(dst[:, :, 3:4] / 255.0, 0.0, 1.0)
    out_a = sa + da * (1.0 - sa)
    safe_a = np.maximum(out_a, 1e-4)
    out_rgb = (src[:, :, :3] * sa + dst[:, :, :3] * da * (1.0 - sa)) / safe_a
    out = np.zeros_like(dst)
    out[:, :, :3] = np.clip(out_rgb, 0.0, 255.0)
    out[:, :, 3:4] = np.clip(out_a * 255.0, 0.0, 255.0)
    return out


def _wave_mask_warp(rgba: np.ndarray, mask: np.ndarray, phase: float, amp_y: float, amp_x: float = 0.0) -> np.ndarray:
    h, w, _ = rgba.shape
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    xn = xx / float(w)
    dx = mask * np.cos(phase - xn * 13.0) * amp_x * float(w)
    dy = mask * np.sin(phase - xn * 14.0) * amp_y * float(h)
    src_x = xx - dx
    src_y = yy - dy

    alpha = rgba[:, :, 3] / 255.0
    premul = rgba[:, :, :3] * alpha[:, :, None]
    out = np.zeros_like(rgba)
    out_a = np.clip(map_coordinates(alpha, [src_y, src_x], order=1, mode="constant", cval=0.0), 0.0, 1.0)
    safe_a = np.maximum(out_a, 1e-4)
    for c in range(3):
        ch = map_coordinates(premul[:, :, c], [src_y, src_x], order=1, mode="constant", cval=0.0)
        out[:, :, c] = np.clip(ch / safe_a, 0.0, 255.0)
    out[:, :, 3] = out_a * 255.0
    return out


def _extract_part(rgba: np.ndarray, mask: np.ndarray) -> np.ndarray:
    part = rgba.copy()
    part[:, :, 3] *= mask
    return part


def build_boar_multipart_sheet() -> None:
    master = _load_master_rgba("enemy_elite_boar_raw", work_size=400)
    h, w, _ = master.shape

    m_near_hind = _polygon_mask(h, w, [(0.17, 0.56), (0.31, 0.56), (0.31, 0.69), (0.22, 0.84), (0.08, 0.84), (0.10, 0.65)], 1.5)
    m_far_hind = _polygon_mask(h, w, [(0.34, 0.60), (0.45, 0.61), (0.45, 0.79), (0.31, 0.79), (0.33, 0.66)], 1.5)
    m_far_fore = _polygon_mask(h, w, [(0.54, 0.62), (0.65, 0.62), (0.64, 0.75), (0.55, 0.81), (0.45, 0.80), (0.46, 0.69)], 1.5)
    m_near_fore = _polygon_mask(h, w, [(0.65, 0.59), (0.79, 0.59), (0.87, 0.84), (0.75, 0.85), (0.65, 0.70)], 1.5)

    p_near_hind = _extract_part(master, m_near_hind)
    p_far_hind = _extract_part(master, m_far_hind)
    p_far_fore = _extract_part(master, m_far_fore)
    p_near_fore = _extract_part(master, m_near_fore)

    # Trim protruding legs below joint sockets from torso layer while keeping shoulder/hip sockets intact
    cut_below = (
        _polygon_mask(h, w, [(0.08, 0.70), (0.29, 0.68), (0.31, 0.86), (0.08, 0.86)], 1.6)
        + _polygon_mask(h, w, [(0.31, 0.66), (0.46, 0.65), (0.46, 0.81), (0.31, 0.81)], 1.6)
        + _polygon_mask(h, w, [(0.45, 0.67), (0.65, 0.66), (0.65, 0.82), (0.45, 0.82)], 1.6)
        + _polygon_mask(h, w, [(0.65, 0.67), (0.88, 0.66), (0.88, 0.86), (0.65, 0.86)], 1.6)
    )
    torso = master.copy()
    torso[:, :, 3] *= np.clip(1.0 - cut_below, 0.0, 1.0)

    yn_grid, xn_grid = np.mgrid[0:h, 0:w].astype(np.float32)
    xn_grid /= float(w)
    yn_grid /= float(h)
    scarf_tail_mask = np.clip((0.46 - xn_grid) / 0.25, 0.0, 1.0) * np.clip((0.55 - yn_grid) / 0.22, 0.0, 1.0)

    frames: list[np.ndarray] = []
    for i in range(6):
        p = (float(i) / 6.0) * 2.0 * math.pi
        body_bob = -abs(math.sin(p)) * 0.024
        body_pitch = math.cos(p) * 0.05

        ang_nf = math.sin(p) * 0.42
        ang_ff = math.sin(p + 2.25) * 0.42
        ang_nh = math.sin(p + 3.15) * 0.40
        ang_fh = math.sin(p + 0.95) * 0.40

        bend_nf = max(0.0, -math.cos(p)) * 0.45
        bend_ff = max(0.0, -math.cos(p + 2.25)) * 0.45
        bend_nh = max(0.0, math.cos(p + 3.15)) * 0.42
        bend_fh = max(0.0, math.cos(p + 0.95)) * 0.42

        l_fh = _rotate_translate_rgba(p_far_hind, (0.40, 0.62), ang_fh, (0.0, body_bob), 0.70, bend_fh)
        l_ff = _rotate_translate_rgba(p_far_fore, (0.59, 0.64), ang_ff, (0.0, body_bob), 0.71, bend_ff)
        l_nh = _rotate_translate_rgba(p_near_hind, (0.24, 0.59), ang_nh, (0.0, body_bob), 0.70, bend_nh)
        l_nf = _rotate_translate_rgba(p_near_fore, (0.71, 0.61), ang_nf, (0.0, body_bob), 0.71, bend_nf)

        t_waved = _wave_mask_warp(torso, scarf_tail_mask, p, amp_y=0.028, amp_x=0.012)
        t_posed = _rotate_translate_rgba(t_waved, (0.52, 0.54), body_pitch, (0.0, body_bob))

        comp = np.zeros_like(master)
        for layer in (l_fh, l_ff, t_posed, l_nh, l_nf):
            comp = _alpha_over(comp, layer)
        frames.append(np.clip(comp, 0, 255).astype(np.uint8))

    pack_aligned_strip(frames, target_size=128, out_name="anim_boar_run.png", align_mode="foot")


def build_wolf_multipart_sheet() -> None:
    master = _load_master_rgba("boss_wolf_king_raw", work_size=440, extra_seeds=[(550, 270), (695, 760)])
    h, w, _ = master.shape

    m_near_hind = _polygon_mask(h, w, [(0.28, 0.56), (0.415, 0.56), (0.415, 0.87), (0.19, 0.87), (0.19, 0.69), (0.27, 0.66)], 1.8)
    m_far_hind = _polygon_mask(h, w, [(0.425, 0.57), (0.56, 0.58), (0.57, 0.83), (0.415, 0.83), (0.415, 0.68)], 1.8)
    m_near_fore = _polygon_mask(h, w, [(0.56, 0.56), (0.708, 0.56), (0.712, 0.75), (0.720, 0.90), (0.53, 0.90), (0.54, 0.70)], 1.8)
    m_far_fore = _polygon_mask(h, w, [(0.688, 0.56), (0.83, 0.56), (0.83, 0.88), (0.720, 0.88), (0.708, 0.72)], 1.8)

    p_near_hind = _extract_part(master, m_near_hind)
    p_far_hind = _extract_part(master, m_far_hind)
    p_near_fore = _extract_part(master, m_near_fore)
    p_far_fore = _extract_part(master, m_far_fore)

    cut_below = (
        _polygon_mask(h, w, [(0.27, 0.66), (0.415, 0.63), (0.415, 0.89), (0.19, 0.89), (0.19, 0.70)], 1.8)
        + _polygon_mask(h, w, [(0.415, 0.63), (0.58, 0.64), (0.58, 0.85), (0.415, 0.85)], 1.8)
        + _polygon_mask(h, w, [(0.53, 0.65), (0.64, 0.62), (0.84, 0.65), (0.84, 0.91), (0.53, 0.91)], 1.8)
    )
    torso = master.copy()
    torso[:, :, 3] *= np.clip(1.0 - cut_below, 0.0, 1.0)

    yn_grid, xn_grid = np.mgrid[0:h, 0:w].astype(np.float32)
    xn_grid /= float(w)
    yn_grid /= float(h)
    tail_mane_mask = (
        np.clip((0.36 - xn_grid) / 0.22, 0.0, 1.0) * np.clip((0.68 - yn_grid) / 0.20, 0.0, 1.0)
        + 0.45 * np.clip((0.66 - xn_grid) / 0.20, 0.0, 1.0) * np.clip((0.50 - yn_grid) / 0.20, 0.0, 1.0)
    )
    tail_mane_mask = np.clip(tail_mane_mask, 0.0, 1.0)

    frames: list[np.ndarray] = []
    for i in range(6):
        p = (float(i) / 6.0) * 2.0 * math.pi
        body_bob = -abs(math.sin(p)) * 0.024
        body_pitch = math.cos(p) * 0.045

        ang_nf = math.sin(p) * 0.36
        ang_ff = math.sin(p + 2.2) * 0.36
        ang_nh = math.sin(p + 3.15) * 0.34
        ang_fh = math.sin(p + 0.95) * 0.34

        bend_nf = max(0.0, -math.cos(p)) * 0.42
        bend_ff = max(0.0, -math.cos(p + 2.2)) * 0.42
        bend_nh = max(0.0, math.cos(p + 3.15)) * 0.40
        bend_fh = max(0.0, math.cos(p + 0.95)) * 0.40

        l_fh = _rotate_translate_rgba(p_far_hind, (0.48, 0.59), ang_fh, (0.0, body_bob), 0.70, bend_fh)
        l_ff = _rotate_translate_rgba(p_far_fore, (0.74, 0.60), ang_ff, (0.0, body_bob), 0.73, bend_ff)
        l_nh = _rotate_translate_rgba(p_near_hind, (0.35, 0.59), ang_nh, (0.0, body_bob), 0.70, bend_nh)
        l_nf = _rotate_translate_rgba(p_near_fore, (0.65, 0.60), ang_nf, (0.0, body_bob), 0.73, bend_nf)

        t_waved = _wave_mask_warp(torso, tail_mane_mask, p, amp_y=0.026, amp_x=0.010)
        t_posed = _rotate_translate_rgba(t_waved, (0.56, 0.54), body_pitch, (0.0, body_bob))

        comp = np.zeros_like(master)
        for layer in (l_fh, l_ff, t_posed, l_nh, l_nf):
            comp = _alpha_over(comp, layer)
        frames.append(np.clip(comp, 0, 255).astype(np.uint8))

    pack_aligned_strip(frames, target_size=220, out_name="anim_wolf_boss_run.png", align_mode="foot")


def build_paper_doll_multipart_sheet() -> None:
    master = _load_master_rgba("enemy_paper_doll_raw", work_size=320)
    h, w, _ = master.shape

    m_l_arm = _polygon_mask(h, w, [(0.11, 0.43), (0.34, 0.48), (0.33, 0.69), (0.11, 0.66)], 1.4)
    m_r_arm = _polygon_mask(h, w, [(0.68, 0.34), (0.87, 0.33), (0.87, 0.58), (0.68, 0.58)], 1.4)
    m_l_foot = _polygon_mask(h, w, [(0.28, 0.77), (0.47, 0.77), (0.47, 0.92), (0.28, 0.92)], 1.4)
    m_r_foot = _polygon_mask(h, w, [(0.50, 0.75), (0.67, 0.75), (0.67, 0.89), (0.50, 0.89)], 1.4)

    p_l_arm = _extract_part(master, m_l_arm)
    p_r_arm = _extract_part(master, m_r_arm)
    p_l_foot = _extract_part(master, m_l_foot)
    p_r_foot = _extract_part(master, m_r_foot)

    cut_limbs = np.clip(
        _polygon_mask(h, w, [(0.10, 0.43), (0.31, 0.50), (0.30, 0.69), (0.10, 0.68)], 1.3)
        + _polygon_mask(h, w, [(0.70, 0.34), (0.88, 0.33), (0.88, 0.58), (0.71, 0.58)], 1.3)
        + _polygon_mask(h, w, [(0.28, 0.79), (0.47, 0.79), (0.47, 0.92), (0.28, 0.92)], 1.3)
        + _polygon_mask(h, w, [(0.50, 0.77), (0.67, 0.77), (0.67, 0.89), (0.50, 0.89)], 1.3),
        0.0,
        1.0,
    )
    body = master.copy()
    body[:, :, 3] *= 1.0 - cut_limbs

    yn_grid, xn_grid = np.mgrid[0:h, 0:w].astype(np.float32)
    xn_grid /= float(w)
    yn_grid /= float(h)
    talisman_mask = np.clip((xn_grid - 0.58) / 0.20, 0.0, 1.0) * np.clip((0.36 - yn_grid) / 0.16, 0.0, 1.0)

    frames: list[np.ndarray] = []
    for i in range(4):
        p = (float(i) / 4.0) * 2.0 * math.pi
        bob = math.sin(p) * 0.035
        tilt = math.cos(p) * 0.065

        la = _rotate_translate_rgba(p_l_arm, (0.31, 0.54), math.sin(p) * 0.32, (0.0, bob))
        ra = _rotate_translate_rgba(p_r_arm, (0.70, 0.49), -math.sin(p) * 0.32, (0.0, bob))
        lf = _rotate_translate_rgba(p_l_foot, (0.38, 0.78), math.sin(p) * 0.28, (0.0, bob))
        rf = _rotate_translate_rgba(p_r_foot, (0.58, 0.77), -math.sin(p) * 0.28, (0.0, bob))

        b_waved = _wave_mask_warp(body, talisman_mask, p, amp_y=0.032, amp_x=0.008)
        b_posed = _rotate_translate_rgba(b_waved, (0.50, 0.52), tilt, (0.0, bob))

        comp = np.zeros_like(master)
        for layer in (lf, rf, ra, b_posed, la):
            comp = _alpha_over(comp, layer)
        frames.append(np.clip(comp, 0, 255).astype(np.uint8))

    pack_aligned_strip(frames, target_size=96, out_name="anim_paper_doll_float.png", align_mode="center")


def make_contact_preview() -> None:
    strips = [
        ("anim_hero_run.png", 110),
        ("anim_hero_idle.png", 110),
        ("anim_hero_attack.png", 110),
        ("anim_fox_run.png", 86),
        ("anim_shanxiao_run.png", 86),
        ("anim_paper_doll_float.png", 86),
        ("anim_boar_run.png", 110),
        ("anim_wolf_boss_run.png", 150),
    ]
    canvas = Image.new("RGB", (1120, 950), (107, 155, 104))
    y = 12
    for fname, row_h in strips:
        im = Image.open(os.path.join(SPRITES_DIR, fname)).convert("RGBA")
        scale = min(1090.0 / float(im.width), float(row_h) / float(im.height))
        nw = max(1, round(im.width * scale))
        nh = max(1, round(im.height * scale))
        im_r = im.resize((nw, nh), Image.Resampling.LANCZOS)
        canvas.paste(im_r, (15, y), im_r)
        y += nh + 10
    os.makedirs(os.path.dirname(PREVIEW_PATH), exist_ok=True)
    canvas.save(PREVIEW_PATH)
    print(f"Saved preview -> {PREVIEW_PATH}")


def main() -> None:
    hero_final = extract_raw_cells("hero_qinglv_run_sheet_final_1795380250876.jpg", 2, 3, auto_holes=True, hole_min_rgb=248, hole_max_chroma=7)
    hero_v1 = extract_raw_cells("hero_qinglv_run_sheet_1795380098267.jpg", 2, 3, auto_holes=True, hole_min_rgb=248, hole_max_chroma=7)
    pack_aligned_strip(hero_final[:5] + [hero_v1[5]], target_size=128, out_name="anim_hero_run.png", align_mode="foot")

    hero_idle = extract_raw_cells("hero_qinglv_idle_sheet_v2_1795380142860.jpg", 2, 2, auto_holes=True, hole_min_rgb=248, hole_max_chroma=7)
    pack_aligned_strip(hero_idle, target_size=128, out_name="anim_hero_idle.png", align_mode="foot")

    hero_atk = extract_raw_cells("hero_qinglv_sword_slash_sheet_v3_1795380203378.jpg", 2, 2, auto_holes=True, hole_min_rgb=248, hole_max_chroma=7)
    pack_aligned_strip(hero_atk, target_size=128, out_name="anim_hero_attack.png", align_mode="foot")

    fox_cells = extract_raw_cells("enemy_fox_spirit_gallop_sheet_v3_1795380242820.jpg", 2, 3, auto_holes=True, hole_min_rgb=248, hole_max_chroma=8)
    pack_aligned_strip(fox_cells, target_size=96, out_name="anim_fox_run.png", align_mode="foot")

    sx_cells = extract_raw_cells("shanxiao_run_spritesheet_1795380208676.jpg", 2, 3, auto_holes=True, hole_min_rgb=246, hole_max_chroma=9)
    pack_aligned_strip([sx_cells[i] for i in (0, 1, 3, 4, 5)], target_size=96, out_name="anim_shanxiao_run.png", align_mode="foot")

    build_boar_multipart_sheet()
    build_wolf_multipart_sheet()
    build_paper_doll_multipart_sheet()
    make_contact_preview()


if __name__ == "__main__":
    main()
