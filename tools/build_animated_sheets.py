import math
import os
import sys
import numpy as np
from PIL import Image
from scipy.ndimage import binary_dilation, map_coordinates

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import process_painted_assets as ppa

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPRITES_DIR = os.path.join(PROJECT_ROOT, "assets", "sprites")
FOX_SHEET_SRC = os.path.join(PROJECT_ROOT, "assets", "concept", "fox_run_6f_sheet.jpg")
PREVIEW_DIR = r"C:\Users\jiang\.gemini\antigravity\brain\067ca6d4-73d8-49ec-8e0b-592b009819f2\scratch"


def load_hq_cutout(prefix: str, work_size: int = 384, extra_seeds=None) -> np.ndarray:
    tmp_path = os.path.join(ppa.ARTIFACT_DIR, "scratch", f"_tmp_hq_{prefix}.png")
    os.makedirs(os.path.dirname(tmp_path), exist_ok=True)
    src = ppa.find_latest_raw(prefix)
    ppa.process_cutout(src, tmp_path, target_size=work_size, extra_seeds=extra_seeds, auto_holes=False)
    return np.array(Image.open(tmp_path).convert("RGBA"), dtype=np.float32)


def warp_rgba(rgba: np.ndarray, disp_x: np.ndarray, disp_y: np.ndarray) -> np.ndarray:
    h, w, _ = rgba.shape
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    src_x = xx - disp_x * w
    src_y = yy - disp_y * h

    alpha = rgba[:, :, 3] / 255.0
    premul = rgba[:, :, :3] * alpha[:, :, None]

    out = np.zeros_like(rgba)
    out_a = np.clip(map_coordinates(alpha, [src_y, src_x], order=1, mode="constant", cval=0.0), 0.0, 1.0)
    safe_a = np.maximum(out_a, 1e-4)
    for c in range(3):
        ch = map_coordinates(premul[:, :, c], [src_y, src_x], order=1, mode="constant", cval=0.0)
        out[:, :, c] = np.clip(ch / safe_a, 0.0, 255.0)
    out[:, :, 3] = np.clip(out_a * 255.0, 0.0, 255.0)
    return out


def alpha_over(dst: np.ndarray, src: np.ndarray) -> np.ndarray:
    sa = np.clip(src[:, :, 3:4] / 255.0, 0.0, 1.0)
    da = np.clip(dst[:, :, 3:4] / 255.0, 0.0, 1.0)
    out_a = sa + da * (1.0 - sa)
    safe_a = np.maximum(out_a, 1e-4)
    out_rgb = (src[:, :, :3] * sa + dst[:, :, :3] * da * (1.0 - sa)) / safe_a
    out = np.zeros_like(dst)
    out[:, :, :3] = np.clip(out_rgb, 0.0, 255.0)
    out[:, :, 3:4] = np.clip(out_a * 255.0, 0.0, 255.0)
    return out


def rect_mask(
    xx: np.ndarray,
    yy: np.ndarray,
    x0: float,
    x1: float,
    y0: float,
    y1: float,
    feather: float = 0.015,
) -> np.ndarray:
    mx = np.clip((xx - x0) / feather, 0.0, 1.0) * np.clip((x1 - xx) / feather, 0.0, 1.0)
    my = np.clip((yy - y0) / feather, 0.0, 1.0) * np.clip((y1 - yy) / feather, 0.0, 1.0)
    return mx * my


def warp_rigid_part(
    part_rgba: np.ndarray,
    xx: np.ndarray,
    yy: np.ndarray,
    pivot: tuple[float, float],
    angle: float,
    stride_x: float,
    lift_y: float,
) -> np.ndarray:
    px, py = pivot
    ca, sa = math.cos(angle), math.sin(angle)
    rx = xx - px
    ry = yy - py
    leg_t = np.clip((yy - py) / 0.12, 0.0, 1.1)
    dx = (rx * ca - ry * sa + px) - xx + stride_x * leg_t
    dy = (rx * sa + ry * ca + py) - yy + lift_y * leg_t
    return warp_rgba(part_rgba, dx, dy)


def bone_field(
    xx: np.ndarray,
    yy: np.ndarray,
    pivot: tuple[float, float],
    center: tuple[float, float],
    sigma: tuple[float, float],
    angle: float,
    shift: tuple[float, float] = (0.0, 0.0),
    sharpness: float = 2.0,
    gate: np.ndarray | float = 1.0,
) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    px, py = pivot
    cx, cy = center
    sx, sy = sigma
    d2 = ((xx - cx) / sx) ** 2 + ((yy - cy) / sy) ** 2
    w = np.exp(-0.5 * (d2 ** (sharpness * 0.5))) * gate

    ca, sa = math.cos(angle), math.sin(angle)
    rx = xx - px
    ry = yy - py
    dx = (rx * ca - ry * sa + px) - xx + shift[0]
    dy = (rx * sa + ry * ca + py) - yy + shift[1]
    return w, dx, dy


def blend_bones(
    xx: np.ndarray,
    yy: np.ndarray,
    bones: list[tuple[np.ndarray, np.ndarray, np.ndarray]],
    base_shift: tuple[float, float] = (0.0, 0.0),
    base_angle: float = 0.0,
    base_pivot: tuple[float, float] = (0.5, 0.55),
    base_weight: np.ndarray | float = 0.35,
) -> tuple[np.ndarray, np.ndarray]:
    ca, sa = math.cos(base_angle), math.sin(base_angle)
    rx = xx - base_pivot[0]
    ry = yy - base_pivot[1]
    bdx = (rx * ca - ry * sa + base_pivot[0]) - xx + base_shift[0]
    bdy = (rx * sa + ry * ca + base_pivot[1]) - yy + base_shift[1]

    w_sum = np.broadcast_to(np.asarray(base_weight, dtype=np.float32), xx.shape).astype(np.float32).copy()
    dx_sum = bdx * w_sum
    dy_sum = bdy * w_sum
    for w, dx, dy in bones:
        w_sum += w
        dx_sum += w * dx
        dy_sum += w * dy
    return dx_sum / np.maximum(w_sum, 1e-4), dy_sum / np.maximum(w_sum, 1e-4)


def _asymmetric_breath_wave(phase_01: float, inhale: float = 0.40) -> float:
    t = phase_01 % 1.0
    if t <= 1e-6 or t >= 1.0 - 1e-6:
        return 0.0
    if t < inhale:
        u = t / inhale
        return 0.5 * (1.0 - math.cos(math.pi * u))
    u = (t - inhale) / max(1e-4, 1.0 - inhale)
    return 0.5 * (1.0 + math.cos(math.pi * u))


def smooth_breathe_frame(
    base_rgba: np.ndarray,
    xx: np.ndarray,
    yy: np.ndarray,
    idx: int,
    total: int,
    depth_y: float = 0.012,
    depth_x: float = 0.007,
    shoulder_lag: float = 0.12,
    sway_dx: np.ndarray | None = None,
    sway_dy: np.ndarray | None = None,
) -> np.ndarray:
    # Anatomical smooth breathing adapted from aldegad/sprite-gen (SPDX-License-Identifier: Apache-2.0):
    # Locks all pixels above the neck rigid line and grounded feet byte-for-byte, applying a 2D cos^2 chest/shoulder wave.
    fg_y, fg_x = np.where(base_rgba[:, :, 3] > 20.0)
    if len(fg_y) == 0:
        return base_rgba.copy()
    h, w, _ = base_rgba.shape
    y0_n = float(fg_y.min()) / float(h)
    y1_n = float(fg_y.max()) / float(h)
    x0_n = float(fg_x.min()) / float(w)
    x1_n = float(fg_x.max()) / float(w)
    bh = max(0.10, y1_n - y0_n)
    bw = max(0.10, x1_n - x0_n)
    axis_x = 0.5 * (x0_n + x1_n)

    rigid_y = y0_n + 0.30 * bh
    foot_y = y0_n + 0.78 * bh
    chest_y = y0_n + 0.48 * bh
    chest_rx = 0.36 * bw
    chest_ry = 0.20 * bh

    phase_01 = float(idx) / float(max(1, total))
    w_chest = _asymmetric_breath_wave(phase_01, inhale=0.40)
    w_sh = _asymmetric_breath_wave((phase_01 - shoulder_lag) % 1.0, inhale=0.40) if idx > 0 else 0.0

    r2_chest = ((xx - axis_x) / max(1e-4, chest_rx)) ** 2 + ((yy - chest_y) / max(1e-4, chest_ry)) ** 2
    chest_w = np.where(r2_chest < 1.0, np.cos(0.5 * math.pi * np.sqrt(np.clip(r2_chest, 0.0, 1.0))) ** 2, 0.0).astype(np.float32)

    sh_y = y0_n + 0.37 * bh
    sh_rx = 0.22 * bw
    sh_ry = 0.11 * bh
    r2_sh_l = ((xx - (axis_x - 0.20 * bw)) / max(1e-4, sh_rx)) ** 2 + ((yy - sh_y) / max(1e-4, sh_ry)) ** 2
    r2_sh_r = ((xx - (axis_x + 0.20 * bw)) / max(1e-4, sh_rx)) ** 2 + ((yy - sh_y) / max(1e-4, sh_ry)) ** 2
    sh_w = (
        np.where(r2_sh_l < 1.0, np.cos(0.5 * math.pi * np.sqrt(np.clip(r2_sh_l, 0.0, 1.0))) ** 2, 0.0)
        + np.where(r2_sh_r < 1.0, np.cos(0.5 * math.pi * np.sqrt(np.clip(r2_sh_r, 0.0, 1.0))) ** 2, 0.0)
    ).astype(np.float32)

    active_band = (yy > rigid_y) & (yy < foot_y)
    sign_x = np.sign(xx - axis_x).astype(np.float32)
    dx = np.where(active_band, sign_x * chest_w * (w_chest * depth_x * bw), 0.0).astype(np.float32)
    dy = np.where(active_band, -(chest_w * w_chest + 0.55 * sh_w * w_sh) * (depth_y * bh), 0.0).astype(np.float32)

    if sway_dx is not None:
        dx = dx + sway_dx
    if sway_dy is not None:
        dy = dy + sway_dy

    warped = warp_rgba(base_rgba, dx, dy)
    locked = (yy <= rigid_y) | (yy >= foot_y)
    if sway_dx is not None or sway_dy is not None:
        sway_mag = (np.abs(sway_dx) if sway_dx is not None else 0.0) + (np.abs(sway_dy) if sway_dy is not None else 0.0)
        locked = locked & (sway_mag < 1e-5)
    warped[locked] = base_rgba[locked]
    return warped


def smoothstep01(t):
    t = np.clip(t, 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def region_center_x(rgba: np.ndarray, roi: tuple[float, float, float, float]) -> float:
    """Alpha-weighted horizontal centroid inside a normalized torso/head ROI."""
    h, w, _ = rgba.shape
    x0, x1 = int(round(roi[0] * w)), int(round(roi[1] * w))
    y0, y1 = int(round(roi[2] * h)), int(round(roi[3] * h))
    weights = rgba[y0:y1, x0:x1, 3].astype(np.float64)
    total = weights.sum()
    if total <= 0.0:
        return 0.5 * (roi[0] + roi[1]) * w
    grid_x = np.arange(x0, x1, dtype=np.float64)[None, :]
    return float((weights * grid_x).sum() / total)


def render_sheet(
    rgba: np.ndarray,
    frame_fn,
    num_frames: int,
    target_size: int,
    out_name: str,
    anchor_roi: tuple[float, float, float, float] | None = None,
) -> None:
    h, w, _ = rgba.shape
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    xx /= float(w)
    yy /= float(h)

    frames: list[np.ndarray] = []
    for i in range(num_frames):
        comp = frame_fn(xx, yy, i, num_frames)
        frame_img = Image.fromarray(np.clip(comp, 0, 255).astype(np.uint8), "RGBA")
        frame_img = frame_img.resize((target_size, target_size), Image.Resampling.LANCZOS)
        frames.append(np.array(frame_img, dtype=np.uint8))

    if anchor_roi is not None:
        target_cx = region_center_x(frames[0], anchor_roi)
        aligned: list[np.ndarray] = []
        for frame in frames:
            shift = int(round(target_cx - region_center_x(frame, anchor_roi)))
            ys, xs = np.where(frame[:, :, 3] > 8)
            shift = max(shift, 1 - int(xs.min()))
            shift = min(shift, target_size - 2 - int(xs.max()))
            cell = Image.new("RGBA", (target_size, target_size), (0, 0, 0, 0))
            cell.paste(Image.fromarray(frame, "RGBA"), (shift, 0))
            aligned.append(np.array(cell, dtype=np.uint8))
        frames = aligned
        centers = [round(region_center_x(f, anchor_roi), 2) for f in frames]
        print(f"  body anchor cx={target_cx:.2f} -> {centers}")

    sheet = Image.new("RGBA", (target_size * num_frames, target_size), (0, 0, 0, 0))
    for i, frame in enumerate(frames):
        sheet.paste(Image.fromarray(frame, "RGBA"), (i * target_size, 0))

    dst = os.path.join(SPRITES_DIR, out_name)
    sheet.save(dst, "PNG", optimize=True)
    print(f"Saved animated sheet -> {out_name} ({sheet.size}, {num_frames} frames)")


def build_hero_sheets() -> None:
    rgba = load_hq_cutout("hero_qinglv_sword_raw", work_size=384, extra_seeds=[(415, 570)])
    h, w, _ = rgba.shape
    yy0, xx0 = np.mgrid[0:h, 0:w].astype(np.float32)
    xx0 /= float(w)
    yy0 /= float(h)

    # Extract each boot overlapping under the robe hem (y>=0.71) and clear only exposed boots below hem (y>=0.79).
    m_leg_l = rect_mask(xx0, yy0, 0.37, 0.54, 0.71, 0.96, feather=0.012)
    m_leg_r = rect_mask(xx0, yy0, 0.56, 0.74, 0.71, 0.96, feather=0.012)
    leg_l = rgba.copy()
    leg_l[:, :, 3] *= m_leg_l
    leg_r = rgba.copy()
    leg_r[:, :, 3] *= m_leg_r

    erase_legs = np.clip(
        rect_mask(xx0, yy0, 0.38, 0.54, 0.79, 0.98, feather=0.010)
        + rect_mask(xx0, yy0, 0.56, 0.74, 0.79, 0.98, feather=0.010),
        0.0,
        1.0,
    )
    body = rgba.copy()
    body[:, :, 3] *= 1.0 - erase_legs

    ribbon_mask = (
        np.clip((0.365 - xx0) / 0.025, 0.0, 1.0)
        * np.clip((yy0 - 0.30) / 0.03, 0.0, 1.0)
        * np.clip((0.76 - yy0) / 0.04, 0.0, 1.0)
    )
    ribbon_part = rgba.copy()
    ribbon_part[:, :, 3] *= ribbon_mask

    protruding_blade = (
        ((xx0 > 0.652) & (yy0 < 0.455))
        | ((xx0 > 0.622) & (yy0 >= 0.372) & (yy0 < 0.435))
    )
    body_no_blade = rgba.copy()
    body_no_blade[protruding_blade, 3] = 0.0

    on_shoulder_blade = (
        (xx0 >= 0.52)
        & (xx0 <= 0.652)
        & (yy0 >= 0.368)
        & (yy0 <= 0.465)
        & (~protruding_blade)
        & ((body_no_blade[:, :, 1] > body_no_blade[:, :, 0] + 14.0) | (body_no_blade[:, :, 2] > body_no_blade[:, :, 0] + 10.0))
    )
    src_row = np.clip(np.arange(h)[:, None] + 18, 0, h - 1)
    src_col = np.clip(np.arange(w)[None, :] - 12, 0, w - 1)
    robe_sample = body_no_blade[src_row, src_col]
    valid_sample = on_shoulder_blade & (robe_sample[:, :, 3] > 180.0)
    body_no_blade[valid_sample, :3] = robe_sample[valid_sample, :3]

    body_run = body_no_blade.copy()
    body_run[:, :, 3] *= (1.0 - erase_legs) * (1.0 - ribbon_mask)
    body_idle = body_no_blade.copy()
    body_idle[:, :, 3] *= 1.0 - ribbon_mask

    def hero_run(xx, yy, idx, total):
        p = (float(idx) / float(total)) * 2.0 * math.pi
        s = math.sin(p)
        c = math.cos(p)

        wl = warp_rigid_part(leg_l, xx, yy, (0.46, 0.73), -s * 0.24, s * 0.042, -max(0.0, c) * 0.032)
        wr = warp_rigid_part(leg_r, xx, yy, (0.62, 0.73), s * 0.24, -s * 0.042, -max(0.0, -c) * 0.032)
        w_rib = warp_rgba(ribbon_part, ribbon_mask * math.cos(p) * 0.007, ribbon_mask * np.sin(p - xx * 15.0) * 0.018)

        comp = np.zeros_like(rgba)
        for layer in (wl, wr, w_rib, body_run):
            comp = alpha_over(comp, layer)
        return comp

    def hero_idle(xx, yy, idx, total):
        p = (float(idx) / float(total)) * 2.0 * math.pi
        w_rib = warp_rgba(ribbon_part, ribbon_mask * math.cos(p) * 0.005, ribbon_mask * np.sin(p - xx * 12.0) * 0.015)
        breathed_body = smooth_breathe_frame(body_idle, xx, yy, idx, total, depth_y=0.011, depth_x=0.006)
        comp = np.zeros_like(rgba)
        for layer in (w_rib, breathed_body):
            comp = alpha_over(comp, layer)
        return comp

    def hero_attack(xx, yy, idx, _total):
        p = (float(idx) / 6.0) * 2.0 * math.pi
        w_rib = warp_rgba(ribbon_part, ribbon_mask * math.cos(p) * 0.008, ribbon_mask * np.sin(p - xx * 14.0) * 0.020)
        comp = np.zeros_like(rgba)
        for layer in (w_rib, body_idle):
            comp = alpha_over(comp, layer)
        return comp

    render_sheet(rgba, hero_run, num_frames=8, target_size=128, out_name="anim_hero_run.png")
    render_sheet(rgba, hero_idle, num_frames=6, target_size=128, out_name="anim_hero_idle.png")
    render_sheet(rgba, hero_attack, num_frames=6, target_size=128, out_name="anim_hero_attack.png")


def build_gunner_sheets() -> None:
    from scipy.ndimage import label as ndi_label
    from PIL import ImageDraw

    raw_path = os.path.join(PROJECT_ROOT, "assets", "concept", "hero_jinyiwei_gunner_raw.png")
    tmp_path = os.path.join(PREVIEW_DIR, "_tmp_hq_jinyiwei_gunner.png")
    os.makedirs(PREVIEW_DIR, exist_ok=True)
    ppa.process_cutout(raw_path, tmp_path, target_size=384, auto_holes=True)
    rgba = np.array(Image.open(tmp_path).convert("RGBA"), dtype=np.float32)

    fg_mask = rgba[:, :, 3] > 14.0
    lbl, num_comp = ndi_label(fg_mask)
    if num_comp > 1:
        counts = np.bincount(lbl.ravel())
        counts[0] = 0
        main_cid = int(np.argmax(counts))
        rgba[lbl != main_cid, 3] = 0.0

    portrait = Image.fromarray(np.clip(rgba, 0, 255).astype(np.uint8), "RGBA").resize((128, 128), Image.Resampling.LANCZOS)
    portrait.save(os.path.join(SPRITES_DIR, "hero_jinyiwei_gunner.png"), "PNG", optimize=True)

    icon_im = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(icon_im)
    d.rounded_rectangle([2, 2, 61, 61], radius=12, fill=(44, 16, 18, 240), outline=(238, 186, 78, 255), width=2)
    gun_crop = Image.fromarray(np.clip(rgba[36:210, 56:368], 0, 255).astype(np.uint8), "RGBA").resize((54, 42), Image.Resampling.LANCZOS)
    icon_im.paste(gun_crop, (5, 11), gun_crop)
    icons_dir = os.path.join(PROJECT_ROOT, "assets", "icons")
    os.makedirs(icons_dir, exist_ok=True)
    icon_im.save(os.path.join(icons_dir, "icon_shenji_musket.png"), "PNG", optimize=True)

    h, w, _ = rgba.shape
    yy0, xx0 = np.mgrid[0:h, 0:w].astype(np.float32)
    xx0 /= float(w)
    yy0 /= float(h)

    m_leg_l = rect_mask(xx0, yy0, 0.21, 0.32, 0.76, 0.96, feather=0.012)
    m_leg_r = rect_mask(xx0, yy0, 0.37, 0.53, 0.76, 0.96, feather=0.012)
    leg_l = rgba.copy()
    leg_l[:, :, 3] *= m_leg_l
    leg_r = rgba.copy()
    leg_r[:, :, 3] *= m_leg_r

    erase_legs = np.clip(
        rect_mask(xx0, yy0, 0.21, 0.32, 0.835, 0.98, feather=0.010)
        + rect_mask(xx0, yy0, 0.37, 0.53, 0.835, 0.98, feather=0.010),
        0.0,
        1.0,
    )
    body_run = rgba.copy()
    body_run[:, :, 3] *= 1.0 - erase_legs

    cape_mask = (
        np.clip((0.23 - xx0) / 0.04, 0.0, 1.0)
        * np.clip((yy0 - 0.52) / 0.04, 0.0, 1.0)
        * np.clip((0.85 - yy0) / 0.04, 0.0, 1.0)
    )

    def gunner_run(xx, yy, idx, total):
        p = (float(idx) / float(total)) * 2.0 * math.pi
        s = math.sin(p)
        c = math.cos(p)

        wl = warp_rigid_part(leg_l, xx, yy, (0.26, 0.78), -s * 0.25, s * 0.044, -max(0.0, c) * 0.032)
        wr = warp_rigid_part(leg_r, xx, yy, (0.43, 0.78), s * 0.25, -s * 0.044, -max(0.0, -c) * 0.032)
        w_body = warp_rgba(body_run, cape_mask * math.cos(p) * 0.008, cape_mask * np.sin(p - xx * 14.0) * 0.016)

        comp = np.zeros_like(rgba)
        for layer in (wl, wr, w_body):
            comp = alpha_over(comp, layer)
        return comp

    def gunner_idle(xx, yy, idx, total):
        p = (float(idx) / float(total)) * 2.0 * math.pi
        sway_dx = cape_mask * math.cos(p) * 0.005
        sway_dy = cape_mask * np.sin(p - xx * 12.0) * 0.012
        return smooth_breathe_frame(rgba, xx, yy, idx, total, depth_y=0.010, depth_x=0.005, sway_dx=sway_dx, sway_dy=sway_dy)

    def gunner_attack(xx, yy, idx, _total):
        recoil_x = [-0.016, -0.022, -0.012, -0.005, 0.0, 0.0][idx % 6]
        upper_mask = np.clip((0.76 - yy) / 0.08, 0.0, 1.0)
        dx = np.full_like(xx, recoil_x) * upper_mask
        dy = np.zeros_like(yy)
        return warp_rgba(rgba, dx, dy)

    render_sheet(rgba, gunner_run, num_frames=8, target_size=128, out_name="anim_gunner_run.png")
    render_sheet(rgba, gunner_idle, num_frames=6, target_size=128, out_name="anim_gunner_idle.png")
    render_sheet(rgba, gunner_attack, num_frames=6, target_size=128, out_name="anim_gunner_attack.png")


def _cutout_cell_rgba(rgb: np.ndarray) -> np.ndarray:
    key_mode, bg_med = ppa.detect_corner_key_mode(rgb)
    if key_mode in ("green", "magenta"):
        return ppa.remove_chroma_background_4pass(rgb, key_mode, bg_med)
    h, w, _ = rgb.shape
    cmax = rgb.max(axis=2).astype(np.int16)
    cmin = rgb.min(axis=2).astype(np.int16)
    chroma = cmax - cmin
    cand = (cmin >= 234) & (chroma <= 22)

    seeds: list[tuple[int, int]] = []
    for x in range(w):
        seeds.append((0, x))
        seeds.append((h - 1, x))
    for y in range(h):
        seeds.append((y, 0))
        seeds.append((y, w - 1))
    bg = ppa.flood_fill_bg(cand, seeds)

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
    out_rgb = np.where((alpha > 0.0)[:, :, None], out_rgb, 0.0)

    rgba = np.zeros((h, w, 4), dtype=np.uint8)
    rgba[:, :, :3] = np.clip(out_rgb, 0, 255).astype(np.uint8)
    rgba[:, :, 3] = np.clip(alpha * 255.0, 0, 255).astype(np.uint8)

    from scipy.ndimage import label as ndi_label
    fg_lbl, n_fg = ndi_label(rgba[:, :, 3] > 14)
    if n_fg > 1:
        counts = np.bincount(fg_lbl.ravel())
        counts[0] = 0
        main_cid = int(np.argmax(counts))
        rgba[fg_lbl != main_cid] = 0
    return rgba


def slice_and_normalize_sheet(
    sheet_path: str,
    rows: int,
    cols: int,
    target_size: int,
    target_height: int,
    baseline_y: int,
    out_name: str,
    selected_indices: list[int] | None = None,
) -> None:
    # Multi-cell extraction + canonical target_height and baseline_y normalization
    # adapted from aldegad/sprite-gen slice_sheet_cells.py & compose_selected_cycle.py (Apache-2.0).
    raw_im = Image.open(sheet_path)
    has_native_alpha = raw_im.mode == "RGBA" and int((np.array(raw_im)[:, :, 3] < 16).sum()) > (raw_im.width * raw_im.height) // 10
    arr_full = np.array(raw_im.convert("RGBA" if has_native_alpha else "RGB"), dtype=np.uint8)
    sh, sw = arr_full.shape[:2]
    cell_h = sh // rows

    cells: list[np.ndarray] = []
    for r in range(rows):
        y0, y1 = r * cell_h, (r + 1) * cell_h
        for c in range(cols):
            x0 = round(c * sw / float(cols))
            x1 = round((c + 1) * sw / float(cols))
            sub = arr_full[y0:y1, x0:x1]
            cut = sub.copy() if has_native_alpha else _cutout_cell_rgba(sub[:, :, :3])
            cells.append(cut)

    order = selected_indices if selected_indices is not None else list(range(len(cells)))
    sheet = Image.new("RGBA", (target_size * len(order), target_size), (0, 0, 0, 0))
    for out_idx, src_idx in enumerate(order):
        cell = cells[src_idx % len(cells)]
        ys, xs = np.where(cell[:, :, 3] > 16)
        if len(ys) == 0:
            continue
        x0, x1 = int(xs.min()), int(xs.max()) + 1
        y0, y1 = int(ys.min()), int(ys.max()) + 1
        crop = Image.fromarray(cell[y0:y1, x0:x1], "RGBA")
        scale = min(float(target_height) / float(max(1, crop.height)), (target_size * 0.90) / float(max(1, crop.width)))
        nw = max(1, round(crop.width * scale))
        nh = max(1, round(crop.height * scale))
        resized = crop.resize((nw, nh), Image.Resampling.LANCZOS)
        ox = (target_size - nw) // 2
        oy = max(1, min(target_size - nh - 1, baseline_y - nh))
        frame_im = Image.new("RGBA", (target_size, target_size), (0, 0, 0, 0))
        frame_im.paste(resized, (ox, oy), resized)
        sheet.paste(frame_im, (out_idx * target_size, 0))

    dst = os.path.join(SPRITES_DIR, out_name)
    sheet.save(dst, "PNG", optimize=True)
    print(f"Saved normalized sheet -> {out_name} ({sheet.size}, target_h={target_height}, baseline_y={baseline_y})")


def build_fox_from_uploaded_sheet() -> None:
    rgb_sheet = np.array(Image.open(FOX_SHEET_SRC).convert("RGB"), dtype=np.uint8)
    sh, sw, _ = rgb_sheet.shape
    rows, cols = 2, 3
    cell_w = max(round(sw / float(cols)), 1) + 2
    cell_h = sh // rows

    cells: list[np.ndarray] = []
    for r in range(rows):
        y0, y1 = r * cell_h, (r + 1) * cell_h
        for c in range(cols):
            x0 = round(c * sw / float(cols))
            x1 = round((c + 1) * sw / float(cols))
            cut = _cutout_cell_rgba(rgb_sheet[y0:y1, x0:x1])
            buf = np.zeros((cell_h, cell_w, 4), dtype=np.uint8)
            buf[:, : x1 - x0] = cut
            cells.append(buf)

    # Register frames 1..5 to frame 0 using head and upper-torso window (y:15..140, x:130..330).
    ty0, ty1, tx0, tx1 = 15, 140, 130, 330
    pad = 24
    ref_rgb = cells[0][ty0:ty1, tx0:tx1, :3].astype(np.float32)
    ref_a = cells[0][ty0:ty1, tx0:tx1, 3:4].astype(np.float32) / 255.0

    aligned: list[np.ndarray] = []
    canvas_h = cell_h + pad * 2
    canvas_w = cell_w + pad * 2

    c0 = np.zeros((canvas_h, canvas_w, 4), dtype=np.uint8)
    c0[pad : pad + cell_h, pad : pad + cell_w] = cells[0]
    aligned.append(c0)

    for k in range(1, len(cells)):
        padded = np.zeros((canvas_h, canvas_w, 4), dtype=np.uint8)
        padded[pad : pad + cell_h, pad : pad + cell_w] = cells[k]
        best_err = float("inf")
        best_dx, best_dy = 0, 0
        for dy in range(-20, 21):
            sy0 = pad + ty0 - dy
            sy1 = pad + ty1 - dy
            for dx in range(-20, 21):
                sx0 = pad + tx0 - dx
                sx1 = pad + tx1 - dx
                cand_rgb = padded[sy0:sy1, sx0:sx1, :3].astype(np.float32)
                cand_a = padded[sy0:sy1, sx0:sx1, 3:4].astype(np.float32) / 255.0
                mask = np.maximum(ref_a, cand_a)
                rgb_err = float(np.sum(np.abs(ref_rgb - cand_rgb) * mask)) / max(float(np.sum(mask)), 1.0)
                a_err = float(np.mean(np.abs(ref_a[:, :, 0] - cand_a[:, :, 0]))) * 255.0
                err = rgb_err + 0.6 * a_err
                if err < best_err:
                    best_err = err
                    best_dx, best_dy = dx, dy

        shifted = np.zeros((canvas_h, canvas_w, 4), dtype=np.uint8)
        shifted[pad + best_dy : pad + best_dy + cell_h, pad + best_dx : pad + best_dx + cell_w] = cells[k]
        aligned.append(shifted)
        print(f"Fox frame {k}: aligned shift=({best_dx:+d}, {best_dy:+d}), err={best_err:.2f}")

    # Final horizontal registration by the head/upper-torso mass only, so the
    # swinging tail cannot pull the body off the shared target_cx.
    def torso_anchor_x(arr: np.ndarray) -> float:
        ys, xs = np.where(arr[:, :, 3] > 16)
        bx0, bx1 = int(xs.min()), int(xs.max()) + 1
        by0, by1 = int(ys.min()), int(ys.max()) + 1
        bw, bh = max(1, bx1 - bx0), max(1, by1 - by0)
        rx0 = bx0 + int(round(bw * 0.55))
        ry0 = by0 + int(round(bh * 0.05))
        ry1 = by0 + int(round(bh * 0.65))
        weights = arr[ry0:ry1, rx0:bx1, 3].astype(np.float64)
        gx = np.arange(rx0, bx1, dtype=np.float64)[None, :]
        return float((weights * gx).sum() / max(1.0, weights.sum()))

    anchors = [torso_anchor_x(arr) for arr in aligned]
    target_cx = float(np.median(anchors))
    for arr, anchor in zip(aligned, anchors):
        shift = int(round(target_cx - anchor))
        if shift == 0:
            continue
        moved = np.zeros_like(arr)
        if shift > 0:
            moved[:, shift:] = arr[:, : canvas_w - shift]
        else:
            moved[:, : canvas_w + shift] = arr[:, -shift :]
        arr[:] = moved
    print(f"Fox torso align: target_cx={target_cx:.2f}, shifts={[int(round(target_cx - a)) for a in anchors]}")

    ux0, uy0, ux1, uy1 = canvas_w, canvas_h, 0, 0
    for arr in aligned:
        ys, xs = np.where(arr[:, :, 3] > 16)
        ux0 = min(ux0, int(xs.min()))
        uy0 = min(uy0, int(ys.min()))
        ux1 = max(ux1, int(xs.max()) + 1)
        uy1 = max(uy1, int(ys.max()) + 1)

    target_size = 96
    inner = round(target_size * 0.88)
    uw, uh = ux1 - ux0, uy1 - uy0
    scale = min(inner / float(uw), inner / float(uh))
    nw, nh = max(1, round(uw * scale)), max(1, round(uh * scale))
    ox = (target_size - nw) // 2
    oy = (target_size - nh) // 2

    sheet = Image.new("RGBA", (target_size * len(aligned), target_size), (0, 0, 0, 0))
    for i, arr in enumerate(aligned):
        crop = Image.fromarray(arr[uy0:uy1, ux0:ux1], "RGBA")
        resized = crop.resize((nw, nh), Image.Resampling.LANCZOS)
        cell_out = Image.new("RGBA", (target_size, target_size), (0, 0, 0, 0))
        cell_out.paste(resized, (ox, oy), resized)
        sheet.paste(cell_out, (i * target_size, 0))

    dst = os.path.join(SPRITES_DIR, "anim_fox_run.png")
    sheet.save(dst, "PNG", optimize=True)
    print(f"Saved registered 6-frame fox sheet -> anim_fox_run.png ({sheet.size}, union_bbox={uw}x{uh}, margin_bottom={target_size - oy - nh}px)")


def build_fox_v1_bound_sheet() -> None:
    rgba = load_hq_cutout("enemy_fox_spirit_raw", work_size=320)

    def fox_run(xx, yy, idx, total):
        p = (float(idx) / float(total)) * 2.0 * math.pi
        s = math.sin(p) + 0.24 * math.sin(2.0 * p - 0.52)
        c = math.cos(p) + 0.20 * math.cos(2.0 * p - 0.45)
        bob = -abs(math.sin(p)) * 0.045
        bones = [
            bone_field(xx, yy, (0.68, 0.64), (0.78, 0.76), (0.15, 0.13), -s * 0.62, (s * 0.032, c * 0.028)),
            bone_field(xx, yy, (0.38, 0.64), (0.34, 0.77), (0.14, 0.13), s * 0.64, (-s * 0.036, -c * 0.028)),
            bone_field(xx, yy, (0.36, 0.48), (0.21, 0.32), (0.16, 0.18), math.sin(p - 0.7) * 0.42, (0.0, math.cos(p - 0.7) * 0.024)),
            bone_field(xx, yy, (0.64, 0.46), (0.74, 0.36), (0.16, 0.16), -c * 0.09, (0.0, bob * 0.7)),
        ]
        dx, dy = blend_bones(xx, yy, bones, base_shift=(0.0, bob), base_angle=c * 0.09, base_pivot=(0.54, 0.56), base_weight=0.32)
        return warp_rgba(rgba, dx, dy)

    render_sheet(rgba, fox_run, num_frames=8, target_size=96, out_name="anim_fox_run_v1_bound.png")


def build_fox_v2_gallop_sheet() -> None:
    import process_ai_spritesheets as pas

    fox_cells = pas.extract_raw_cells(
        "enemy_fox_spirit_gallop_sheet_v3_1795380242820.jpg",
        2,
        3,
        auto_holes=True,
        hole_min_rgb=248,
        hole_max_chroma=8,
    )
    pas.pack_aligned_strip(fox_cells, target_size=96, out_name="anim_fox_run_v2_gallop.png", align_mode="foot")


def make_fox_compare_preview() -> None:
    rows = [
        ("v1_bound (8f leap)", "anim_fox_run_v1_bound.png"),
        ("v2_gallop (6f AI)", "anim_fox_run_v2_gallop.png"),
        ("uploaded_6f (active anim_fox_run)", "anim_fox_run.png"),
    ]
    canvas = Image.new("RGB", (820, 340), (107, 155, 104))
    y = 14
    for _, fname in rows:
        im = Image.open(os.path.join(SPRITES_DIR, fname)).convert("RGBA")
        scale = min(790.0 / float(im.width), 96.0 / float(im.height))
        nw, nh = max(1, round(im.width * scale)), max(1, round(im.height * scale))
        im_r = im.resize((nw, nh), Image.Resampling.LANCZOS)
        canvas.paste(im_r, (14, y), im_r)
        y += nh + 12
    os.makedirs(PREVIEW_DIR, exist_ok=True)
    out = os.path.join(PREVIEW_DIR, "fox_versions_compare.png")
    canvas.save(out)
    print(f"Saved fox comparison preview -> {out}")


def build_shanxiao_sheet() -> None:
    rgba = load_hq_cutout("enemy_shanxiao_raw", work_size=320)
    h, w, _ = rgba.shape
    yy0, xx0 = np.mgrid[0:h, 0:w].astype(np.float32)
    xx0 /= float(w)
    yy0 /= float(h)

    m_leg_l = rect_mask(xx0, yy0, 0.35, 0.545, 0.74, 0.96, feather=0.012)
    m_leg_r = rect_mask(xx0, yy0, 0.555, 0.78, 0.74, 0.96, feather=0.012)
    leg_l = rgba.copy()
    leg_l[:, :, 3] *= m_leg_l
    leg_r = rgba.copy()
    leg_r[:, :, 3] *= m_leg_r

    erase_legs = np.clip(
        rect_mask(xx0, yy0, 0.36, 0.545, 0.81, 0.98, feather=0.010)
        + rect_mask(xx0, yy0, 0.555, 0.79, 0.81, 0.98, feather=0.010),
        0.0,
        1.0,
    )
    body = rgba.copy()
    body[:, :, 3] *= 1.0 - erase_legs
    torso = smoothstep01((0.80 - yy0) / 0.13)

    def shanxiao_run(xx, yy, idx, total):
        p = (float(idx) / float(total)) * 2.0 * math.pi
        s = math.sin(p)
        c = math.cos(p)
        wl = smoothstep01(c)
        wr = smoothstep01(-c)
        bob = -0.019 * (0.5 + 0.5 * math.cos(2.0 * p))
        pitch = 0.024 * s

        ca, sa = math.cos(pitch), math.sin(pitch)
        rx = xx - 0.53
        ry = yy - 0.745
        ux = rx * ca - ry * sa + 0.53
        uy = rx * sa + ry * ca + 0.745
        dx = (ux - xx) * torso
        dy = (uy - yy + bob) * torso
        dx -= 0.004 * s * torso

        for pivot, center, sigma, angle, shift in (
            ((0.40, 0.545), (0.30, 0.38), (0.14, 0.18), -0.030 * s, (0.0, bob * 0.35)),
            ((0.71, 0.545), (0.755, 0.625), (0.072, 0.10), -0.10 * s, (0.0, bob * 0.45)),
            ((0.56, 0.40), (0.585, 0.29), (0.12, 0.14), -0.028 * s, (-0.0015 * s, -0.001 * math.sin(2.0 * p))),
        ):
            wgt, bx, by = bone_field(xx, yy, pivot, center, sigma, angle, shift)
            dx += wgt * bx
            dy += wgt * by
        wb = warp_rgba(body, dx, dy)

        wl_img = warp_rigid_part(leg_l, xx, yy, (0.445, 0.755), -0.16 * s, 0.003 * s, -0.050 * wl)
        wr_img = warp_rigid_part(leg_r, xx, yy, (0.665, 0.755), 0.16 * s, -0.003 * s, 0.020 - 0.065 * wr)

        comp = np.zeros_like(rgba)
        for layer in (wl_img, wr_img, wb):
            comp = alpha_over(comp, layer)
        return comp

    render_sheet(
        rgba,
        shanxiao_run,
        num_frames=8,
        target_size=96,
        out_name="anim_shanxiao_run.png",
        anchor_roi=(0.40, 0.90, 0.10, 0.78),
    )


def build_paper_doll_sheet() -> None:
    rgba = load_hq_cutout("enemy_paper_doll_raw", work_size=320)
    h, w, _ = rgba.shape
    yy0, xx0 = np.mgrid[0:h, 0:w].astype(np.float32)
    xx0 /= float(w)
    yy0 /= float(h)

    m_foot_l = rect_mask(xx0, yy0, 0.27, 0.445, 0.76, 0.96, feather=0.012)
    m_foot_r = rect_mask(xx0, yy0, 0.455, 0.62, 0.76, 0.96, feather=0.012)
    foot_l = rgba.copy()
    foot_l[:, :, 3] *= m_foot_l
    foot_r = rgba.copy()
    foot_r[:, :, 3] *= m_foot_r

    erase_feet = np.clip(
        rect_mask(xx0, yy0, 0.28, 0.445, 0.825, 0.98, feather=0.010)
        + rect_mask(xx0, yy0, 0.455, 0.62, 0.825, 0.98, feather=0.010),
        0.0,
        1.0,
    )
    body = rgba.copy()
    body[:, :, 3] *= 1.0 - erase_feet
    talisman_mask = np.clip((xx0 - 0.54) / 0.22, 0.0, 1.0) * np.clip((0.38 - yy0) / 0.16, 0.0, 1.0)

    def paper_doll_float(xx, yy, idx, total):
        p = (float(idx) / float(total)) * 2.0 * math.pi
        s = math.sin(p)
        c = math.cos(p)
        bob = s * 0.010

        wl = warp_rigid_part(foot_l, xx, yy, (0.37, 0.78), -s * 0.26, s * 0.032, -max(0.0, c) * 0.024 + bob)
        wr = warp_rigid_part(foot_r, xx, yy, (0.52, 0.78), s * 0.26, -s * 0.032, -max(0.0, -c) * 0.024 + bob)

        dx_b, dy_b = blend_bones(
            xx,
            yy,
            [
                bone_field(xx, yy, (0.48, 0.34), (0.48, 0.34), (0.24, 0.22), 0.0, (0.0, bob)),
                bone_field(xx, yy, (0.32, 0.54), (0.20, 0.58), (0.11, 0.11), s * 0.12, (0.0, bob)),
                bone_field(xx, yy, (0.68, 0.48), (0.78, 0.44), (0.11, 0.11), -s * 0.12, (0.0, bob)),
            ],
            base_shift=(0.0, bob),
            base_angle=0.0,
            base_weight=0.80,
        )
        dy_b += talisman_mask * np.sin(p - xx * 14.0) * 0.020
        wb = warp_rgba(body, dx_b, dy_b)

        comp = np.zeros_like(rgba)
        for layer in (wl, wr, wb):
            comp = alpha_over(comp, layer)
        return comp

    render_sheet(rgba, paper_doll_float, num_frames=6, target_size=96, out_name="anim_paper_doll_float.png")


def build_boar_sheet() -> None:
    rgba = load_hq_cutout("enemy_elite_boar_raw", work_size=384)

    def boar_run(xx, yy, idx, total):
        p = (float(idx) / float(total)) * 2.0 * math.pi
        s = math.sin(p)
        c = math.cos(p)
        bob = -abs(s) * 0.010
        bones = [
            # Steady heavy armored torso & head
            bone_field(xx, yy, (0.62, 0.46), (0.64, 0.46), (0.22, 0.18), 0.0, (0.0, bob), sharpness=2.2),
            # Front hooves stride smoothly
            bone_field(xx, yy, (0.66, 0.65), (0.70, 0.78), (0.16, 0.12), s * 0.42, (-s * 0.026, -max(0.0, -c) * 0.022)),
            # Rear hooves drive smoothly
            bone_field(xx, yy, (0.30, 0.65), (0.27, 0.77), (0.15, 0.12), -s * 0.42, (s * 0.028, -max(0.0, c) * 0.022)),
        ]
        dx, dy = blend_bones(xx, yy, bones, base_shift=(0.0, bob), base_angle=0.0, base_weight=0.60)
        scarf_mask = np.clip((0.44 - xx) / 0.24, 0.0, 1.0) * np.clip((0.56 - yy) / 0.18, 0.0, 1.0)
        dy += scarf_mask * np.sin(p - xx * 14.0) * 0.028
        dx += scarf_mask * np.cos(p - xx * 11.0) * 0.010
        return warp_rgba(rgba, dx, dy)

    render_sheet(rgba, boar_run, num_frames=8, target_size=128, out_name="anim_boar_run.png")


def build_wolf_boss_sheet() -> None:
    rgba = load_hq_cutout("boss_wolf_king_raw", work_size=440, extra_seeds=[(550, 270), (695, 760)])

    def wolf_run(xx, yy, idx, total):
        p = (float(idx) / float(total)) * 2.0 * math.pi
        s = math.sin(p)
        c = math.cos(p)
        bob = -abs(s) * 0.008
        bones = [
            # Steady majestic head, mane, chest and halo
            bone_field(xx, yy, (0.62, 0.40), (0.64, 0.40), (0.26, 0.22), 0.0, (0.0, bob), sharpness=2.2),
            # Front legs smooth stride
            bone_field(xx, yy, (0.66, 0.63), (0.68, 0.79), (0.12, 0.13), s * 0.34, (-s * 0.024, -max(0.0, -c) * 0.020)),
            # Hind legs smooth stride
            bone_field(xx, yy, (0.37, 0.63), (0.36, 0.78), (0.13, 0.13), -s * 0.34, (s * 0.024, -max(0.0, c) * 0.020)),
        ]
        dx, dy = blend_bones(xx, yy, bones, base_shift=(0.0, bob), base_angle=0.0, base_weight=0.65)
        tail_mask = np.clip((0.34 - xx) / 0.22, 0.0, 1.0) * np.clip((0.66 - yy) / 0.22, 0.0, 1.0)
        dy += tail_mask * np.sin(p - xx * 13.0) * 0.026
        return warp_rgba(rgba, dx, dy)

    render_sheet(rgba, wolf_run, num_frames=8, target_size=220, out_name="anim_wolf_boss_run.png")


def make_preview_contact() -> None:
    strips = [
        ("anim_hero_run.png", 104),
        ("anim_hero_idle.png", 104),
        ("anim_hero_attack.png", 104),
        ("anim_fox_run.png", 86),
        ("anim_shanxiao_run.png", 86),
        ("anim_paper_doll_float.png", 86),
        ("anim_boar_run.png", 104),
        ("anim_wolf_boss_run.png", 140),
    ]
    canvas = Image.new("RGB", (1120, 920), (107, 155, 104))
    y = 12
    for fname, row_h in strips:
        im = Image.open(os.path.join(SPRITES_DIR, fname)).convert("RGBA")
        scale = min(1090.0 / float(im.width), float(row_h) / float(im.height))
        nw = max(1, round(im.width * scale))
        nh = max(1, round(im.height * scale))
        im_r = im.resize((nw, nh), Image.Resampling.LANCZOS)
        canvas.paste(im_r, (15, y), im_r)
        y += nh + 10
    os.makedirs(PREVIEW_DIR, exist_ok=True)
    out = os.path.join(PREVIEW_DIR, "anim_sheets_v2_preview.png")
    canvas.save(out)
    print(f"Saved preview -> {out}")


def main() -> None:
    build_hero_sheets()
    build_gunner_sheets()
    build_fox_from_uploaded_sheet()
    build_fox_v1_bound_sheet()
    build_fox_v2_gallop_sheet()
    build_shanxiao_sheet()
    build_paper_doll_sheet()
    build_boar_sheet()
    build_wolf_boss_sheet()
    make_preview_contact()
    make_fox_compare_preview()


if __name__ == "__main__":
    main()
