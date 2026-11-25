from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw
import scipy.ndimage as ndi

ROOT = Path(r"d:\AI_workspace\game")
CONCEPT = ROOT / "assets" / "concept" / "fox_parts_sheet.png"
OUT_DIR = ROOT / "assets" / "sprites" / "fox"
SCRATCH_PREVIEW = Path(
    r"C:/Users/jiang/.gemini/antigravity/brain/067ca6d4-73d8-49ec-8e0b-592b009819f2/scratch/fox_rig_preview.png"
)


def trim_rgba(arr: np.ndarray, pad: int = 2) -> Image.Image:
    ys, xs = np.where(arr[:, :, 3] > 6)
    if len(xs) == 0:
        return Image.fromarray(arr, "RGBA")
    x0 = max(0, int(xs.min()) - pad)
    y0 = max(0, int(ys.min()) - pad)
    x1 = min(arr.shape[1], int(xs.max()) + 1 + pad)
    y1 = min(arr.shape[0], int(ys.max()) + 1 + pad)
    return Image.fromarray(arr[y0:y1, x0:x1], "RGBA")


def remove_alpha_debris(arr: np.ndarray, min_area: int = 40) -> np.ndarray:
    mask = arr[:, :, 3] > 12
    lbl, n = ndi.label(mask)
    if n <= 1:
        return arr
    counts = np.bincount(lbl.ravel())
    keep = np.zeros_like(mask)
    for idx in range(1, n + 1):
        if counts[idx] >= min_area:
            keep |= lbl == idx
    out = arr.copy()
    out[~keep, 3] = 0
    return out


def smooth_curve(xs: np.ndarray, pts: list[tuple[float, float]]) -> np.ndarray:
    px = np.array([p[0] for p in pts], dtype=np.float64)
    py = np.array([p[1] for p in pts], dtype=np.float64)
    return np.interp(xs, px, py)


def feather_near_limb_top_auto(arr: np.ndarray, max_y: float, fade_px: float = 11.0) -> np.ndarray:
    h, w = arr.shape[:2]
    yy = np.mgrid[0:h, 0:w][0].astype(np.float64)
    out = arr.copy()
    alpha = out[:, :, 3].astype(np.float64)
    for x in range(w):
        ys = np.where(alpha[:, x] > 16)[0]
        if len(ys) == 0:
            continue
        y0 = float(ys.min())
        if y0 >= max_y:
            continue
        # Only melt the upper orange shoulder/thigh attachment cut, keeping lower limb contours crisp
        in_cap = (yy[:, x] <= max_y + fade_px * 0.5)
        ramp = np.clip((yy[:, x] - (y0 + 0.5)) / fade_px, 0.0, 1.0)
        ramp = ramp * ramp * (3.0 - 2.0 * ramp)
        alpha[:, x] = np.where(in_cap, alpha[:, x] * ramp, alpha[:, x])
    out[:, :, 3] = alpha.clip(0, 255).round().astype(np.uint8)
    return out


def extract_body_head(sheet: np.ndarray) -> tuple[Image.Image, np.ndarray]:
    bh = sheet[306:481, 22:267].copy()
    h, w = bh.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)

    underside_pts = [
        (0.0, 90.0),
        (20.0, 91.0),
        (33.0, 96.0),
        (45.0, 106.0),
        (60.0, 113.0),
        (82.0, 117.0),
        (114.0, 121.0),
        (126.0, 114.0),
        (144.0, 111.0),
        (164.0, 113.0),
        (178.0, 106.0),
        (194.0, 93.0),
        (245.0, 93.0),
    ]
    y_bot = smooth_curve(np.arange(w, dtype=np.float64), underside_pts)
    keep_bot = np.clip((y_bot[None, :] - yy) * 0.8 + 0.5, 0.0, 1.0)
    bh[:, :, 3] = (bh[:, :, 3].astype(np.float64) * keep_bot).round().astype(np.uint8)

    far_left_leg = (xx < 35.0) & (yy > (88.0 + (xx - 16.0) * 0.42))
    bh[far_left_leg, 3] = 0

    torso_mask = bh[:, :, 3] > 180
    edge_band = torso_mask & (yy >= (y_bot[None, :] - 2.2)) & (xx >= 32.0) & (xx <= 176.0)
    fur_outline = np.array([152, 74, 40], dtype=np.float64)
    blend = np.clip((yy - (y_bot[None, :] - 2.4)) / 2.4, 0.0, 0.65)
    for c in range(3):
        ch = bh[:, :, c].astype(np.float64)
        ch = np.where(edge_band, ch * (1.0 - blend) + fur_outline[c] * blend, ch)
        bh[:, :, c] = ch.clip(0, 255).astype(np.uint8)

    # Smooth cranium dome tucked cleanly under ear_near and closing the skull notch between ears
    crown_pts = [
        (0.0, 48.0),
        (146.0, 49.0),
        (155.0, 45.0),
        (166.0, 38.0),
        (178.0, 30.0),
        (189.0, 24.0),
        (202.0, 25.0),
        (210.0, 30.0),
        (245.0, 35.0),
    ]
    y_crown = smooth_curve(np.arange(w, dtype=np.float64), crown_pts)

    in_ear_x = (xx >= 145.0) & (xx <= 212.0)
    alpha_crown = np.clip((yy - (y_crown[None, :] - 1.0)) * 0.85, 0.0, 1.0)
    bh_a = bh[:, :, 3].astype(np.float64)
    bh[:, :, 3] = np.where(in_ear_x, bh_a * alpha_crown, bh_a).round().astype(np.uint8)

    # Fill cranium dome and close the small V-notch between ear_near and ear_far (x=155..204)
    need_fill = (xx >= 155.0) & (xx <= 204.0) & (yy >= y_crown[None, :]) & (yy <= 48.0)
    orange_top = np.array([248.0, 121.0, 62.0])
    orange_mid = np.array([242.0, 114.0, 54.0])
    t_y = np.clip((yy - y_crown[None, :]) / 24.0, 0.0, 1.0)
    t_blend = np.clip((196.0 - xx) / 8.0, 0.0, 1.0)
    for c in range(3):
        fill_col = orange_top[c] * (1.0 - t_y) + orange_mid[c] * t_y
        orig_ch = bh[:, :, c].astype(np.float64)
        pure_mask = bh[:, :, 3] < 220
        mixed = np.where(pure_mask, fill_col, fill_col * t_blend + orig_ch * (1.0 - t_blend))
        bh[:, :, c] = np.where(need_fill, mixed.clip(0, 255).astype(np.uint8), bh[:, :, c])
    bh[:, :, 3] = np.where(need_fill & ((bh[:, :, 3] < 253) | (xx <= 195.0)), 253, bh[:, :, 3])

    crown_stroke = (
        (xx >= 155.0)
        & (xx <= 203.0)
        & (np.abs(yy - y_crown[None, :] - 0.6) < 1.0)
    )
    for c in range(3):
        bh[:, :, c] = np.where(crown_stroke, int(fur_outline[c] * 0.85), bh[:, :, c])

    bh = remove_alpha_debris(bh, min_area=120)
    ys, xs = np.where(bh[:, :, 3] > 6)
    x0 = max(0, int(xs.min()) - 2)
    y0 = max(0, int(ys.min()) - 2)
    x1 = min(w, int(xs.max()) + 3)
    y1 = min(h, int(ys.max()) + 3)
    cropped = Image.fromarray(bh[y0:y1, x0:x1], "RGBA")
    return cropped, np.array([x0, y0])


def extract_ears(sheet: np.ndarray, scale: float = 0.62) -> tuple[Image.Image, Image.Image]:
    ear = sheet[317:403, 635:736].copy()
    h, w = ear.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)

    # 1. Near ear: stop strictly at right notch boundary (x <= 53.5 at top, tapering down cheek)
    near = ear.copy()
    right_limit_pts = [(0.0, 53.5), (30.0, 53.5), (38.0, 55.0), (50.0, 51.0), (68.0, 40.0)]
    y_rows = np.arange(h, dtype=np.float64)
    x_right = smooth_curve(y_rows, right_limit_pts)
    base_pts = [(0.0, 62.0), (22.0, 62.0), (32.0, 64.0), (44.0, 55.0), (53.0, 44.0), (57.0, 34.0)]
    y_base = smooth_curve(np.arange(w, dtype=np.float64), base_pts)

    keep_x = np.clip((x_right[:, None] - xx) * 0.85 + 0.5, 0.0, 1.0)
    alpha_base = np.clip((y_base[None, :] - yy) * 0.55 + 0.5, 0.0, 1.0)
    feather_bottom = np.clip((y_base[None, :] - yy) / 7.5, 0.0, 1.0)
    is_base_region = yy > 44.0
    near_alpha = near[:, :, 3].astype(np.float64) * keep_x * np.where(is_base_region, feather_bottom, alpha_base)
    near[:, :, 3] = near_alpha.clip(0, 255).round().astype(np.uint8)
    near = remove_alpha_debris(near, min_area=30)
    near_img = trim_rgba(near, pad=1)
    near_scaled = near_img.resize(
        (max(1, round(near_img.width * scale)), max(1, round(near_img.height * scale))),
        Image.Resampling.LANCZOS,
    )

    # 2. Far ear: cleanly isolate behind-skull ear peak (x >= 54.5 at top, clean bottom tuck behind dome)
    far = ear.copy()
    left_cut_x = np.where(yy < 31.0, 54.5, 55.5)
    # Cut cleanly above the forehead crease ridge around y=31..38
    far_alpha = far[:, :, 3].astype(np.float64)
    far_alpha = np.where((xx >= left_cut_x) & (xx <= 88.0) & (yy <= 36.0), far_alpha, 0.0)
    far[:, :, 3] = far_alpha.clip(0, 255).round().astype(np.uint8)
    # Sample pure clean ear orange (above the dark brow line y=20..26) and extend smoothly downward behind skull dome
    for x in range(55, 86):
        col_ys = np.where(far[:30, x, 3] > 200)[0]
        if len(col_ys) > 0:
            y_sample = min(int(col_ys.max()), 27)
            sample_rgb = far[max(0, y_sample - 2), x, :3]
            y_start_fill = min(31, int(col_ys.max()) + 1)
            for y_ext in range(y_start_fill, min(42, y_start_fill + 9)):
                far[y_ext, x, :3] = sample_rgb
                far[y_ext, x, 3] = 245
    far = remove_alpha_debris(far, min_area=30)
    far_img = trim_rgba(far, pad=1)
    far_scaled = far_img.resize(
        (max(1, round(far_img.width * scale)), max(1, round(far_img.height * scale))),
        Image.Resampling.LANCZOS,
    )
    return near_scaled, far_scaled


def extract_limb(
    sheet: np.ndarray,
    x0: int,
    y0: int,
    x1: int,
    y1: int,
    feather_max_y: float | None = None,
) -> Image.Image:
    part = sheet[y0:y1, x0:x1].copy()
    part = remove_alpha_debris(part, min_area=30)
    if feather_max_y is not None:
        part = feather_near_limb_top_auto(part, max_y=feather_max_y, fade_px=12.0)
    return trim_rgba(part, pad=2)


def draw_rotated_part(
    canvas: Image.Image,
    part: Image.Image,
    anchor_xy: tuple[float, float],
    pivot_px: tuple[float, float],
    rot_rad: float,
    tint: tuple[float, float, float] = (1.0, 1.0, 1.0),
) -> None:
    src = np.array(part, dtype=np.float64)
    if tint != (1.0, 1.0, 1.0):
        src[:, :, 0] = (src[:, :, 0] * tint[0]).clip(0, 255)
        src[:, :, 1] = (src[:, :, 1] * tint[1]).clip(0, 255)
        src[:, :, 2] = (src[:, :, 2] * tint[2]).clip(0, 255)
    tinted = Image.fromarray(src.astype(np.uint8), "RGBA")

    # Compute affine inverse mapping from destination canvas coords to source part coords
    cw, ch = canvas.size
    pw, ph = tinted.size
    cos_r = np.cos(rot_rad)
    sin_r = np.sin(rot_rad)
    px, py = pivot_px
    ax, ay = anchor_xy
    # dest(sx, sy) = A + R * (S - P)
    # => S = P + R^T * (D - A)
    a = cos_r
    b = sin_r
    c = px - a * ax - b * ay
    d = -sin_r
    e = cos_r
    f = py - d * ax - e * ay
    transformed = tinted.transform(
        (cw, ch),
        Image.Transform.AFFINE,
        (a, b, c, d, e, f),
        resample=Image.Resampling.BICUBIC,
    )
    canvas.alpha_composite(transformed)


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    sheet = np.array(Image.open(CONCEPT).convert("RGBA"))

    body_head, bh_offset = extract_body_head(sheet)
    tail = extract_limb(sheet, 285, 315, 380, 441)
    front_near = extract_limb(sheet, 406, 345, 450, 421, feather_max_y=28.0)
    front_far = extract_limb(sheet, 455, 340, 506, 410)
    hind_near = extract_limb(sheet, 504, 354, 559, 435, feather_max_y=26.0)
    hind_far = extract_limb(sheet, 556, 351, 595, 430)
    ear_near, ear_far = extract_ears(sheet, scale=0.62)

    parts = {
        "body_head.png": body_head,
        "tail.png": tail,
        "front_leg_near.png": front_near,
        "front_leg_far.png": front_far,
        "hind_leg_near.png": hind_near,
        "hind_leg_far.png": hind_far,
        "ear_near.png": ear_near,
        "ear_far.png": ear_far,
    }
    for name, im in parts.items():
        im.save(OUT_DIR / name)
        print(f"{name}: {im.size}")

    print(f"bh_crop_offset: ({bh_offset[0]}, {bh_offset[1]})")

    # Assemble a 6-frame run cycle preview + idle frame on canvas 320x220 per panel
    # Coordinates below are in body_head local pixel space relative to top-left of body_head.png!
    ox, oy = float(bh_offset[0]), float(bh_offset[1])
    # Key anchors on raw bh (before crop), adjusted by (ox, oy)
    anchor_tail = (32.0 - ox, 76.0 - oy)
    anchor_hind_near = (56.0 - ox, 94.0 - oy)
    anchor_hind_far = (67.0 - ox, 98.0 - oy)
    anchor_front_near = (138.0 - ox, 98.0 - oy)
    anchor_front_far = (156.0 - ox, 99.0 - oy)
    anchor_ear_near = (160.0 - ox, 43.0 - oy)
    anchor_ear_far = (188.0 - ox, 26.0 - oy)

    pivots = {
        "body": (body_head.width * 0.5, body_head.height * 0.72),
        "tail": (tail.width * 0.84, tail.height * 0.84),
        "hind_near": (hind_near.width * 0.62, 16.0),
        "hind_far": (hind_far.width * 0.50, 14.0),
        "front_near": (front_near.width * 0.56, 13.0),
        "front_far": (front_far.width * 0.44, 13.0),
        "ear_near": (ear_near.width * 0.58, ear_near.height * 0.78),
        "ear_far": (ear_far.width * 0.45, ear_far.height * 0.82),
    }
    print("anchors_on_body_head:")
    for k, v in [
        ("tail", anchor_tail),
        ("hind_near", anchor_hind_near),
        ("hind_far", anchor_hind_far),
        ("front_near", anchor_front_near),
        ("front_far", anchor_front_far),
        ("ear_near", anchor_ear_near),
        ("ear_far", anchor_ear_far),
    ]:
        print(f"  {k}: ({v[0]:.1f}, {v[1]:.1f}), pivot={pivots[k]}")

    cell_w, cell_h = 310, 220
    strip = Image.new("RGBA", (cell_w * 6, cell_h), (242, 240, 236, 255))
    sheet_6f = Image.new("RGBA", (96 * 6, 96), (0, 0, 0, 0))
    body_cx, body_cy = 185.0, 118.0

    for i in range(6):
        phase = (i / 6.0) * 2.0 * np.pi
        cell = Image.new("RGBA", (cell_w, cell_h), (0, 0, 0, 0))
        bob_y = -abs(np.sin(phase)) * 6.0
        pitch = np.sin(phase) * 0.045

        def world_pt(pt: tuple[float, float]) -> tuple[float, float]:
            dx = pt[0] - body_head.width * 0.5
            dy = pt[1] - body_head.height * 0.5
            rx = dx * np.cos(pitch) - dy * np.sin(pitch)
            ry = dx * np.sin(pitch) + dy * np.cos(pitch)
            return (body_cx + rx, body_cy + bob_y + ry)

        ph_fn = phase
        ph_ff = phase + np.pi * 0.85
        ph_hn = phase + np.pi * 0.95
        ph_hf = phase + np.pi * 0.10

        rot_fn = np.sin(ph_fn) * 0.46
        rot_ff = np.sin(ph_ff) * 0.44
        rot_hn = np.sin(ph_hn) * 0.48
        rot_hf = np.sin(ph_hf) * 0.44

        lift_fn = -max(0.0, np.cos(ph_fn)) * 5.0
        lift_ff = -max(0.0, np.cos(ph_ff)) * 5.0
        lift_hn = -max(0.0, np.cos(ph_hn)) * 5.0
        lift_hf = -max(0.0, np.cos(ph_hf)) * 5.0

        rot_tail = np.sin(phase - 0.85) * 0.24 + np.cos(phase * 2.0 - 1.1) * 0.05
        rot_en = np.sin(phase - 0.55) * 0.09
        rot_ef = np.sin(phase - 0.75) * 0.08

        far_tint = (0.86, 0.82, 0.88)

        # Back-to-front draw order
        p_hf = world_pt(anchor_hind_far)
        draw_rotated_part(cell, hind_far, (p_hf[0], p_hf[1] + lift_hf), pivots["hind_far"], rot_hf + pitch, far_tint)

        p_ff = world_pt(anchor_front_far)
        draw_rotated_part(cell, front_far, (p_ff[0], p_ff[1] + lift_ff), pivots["front_far"], rot_ff + pitch, far_tint)

        draw_rotated_part(cell, tail, world_pt(anchor_tail), pivots["tail"], rot_tail + pitch)
        draw_rotated_part(cell, ear_far, world_pt(anchor_ear_far), pivots["ear_far"], rot_ef + pitch, far_tint)
        draw_rotated_part(cell, body_head, (body_cx, body_cy + bob_y), (body_head.width * 0.5, body_head.height * 0.5), pitch)
        draw_rotated_part(cell, ear_near, world_pt(anchor_ear_near), pivots["ear_near"], rot_en + pitch)

        p_hn = world_pt(anchor_hind_near)
        draw_rotated_part(cell, hind_near, (p_hn[0], p_hn[1] + lift_hn), pivots["hind_near"], rot_hn + pitch)

        p_fn = world_pt(anchor_front_near)
        draw_rotated_part(cell, front_near, (p_fn[0], p_fn[1] + lift_fn), pivots["front_near"], rot_fn + pitch)

        strip.paste(cell, (i * cell_w, 0), cell)
        thumb = cell.crop((45, 22, 305, 205)).resize((88, 62), Image.Resampling.LANCZOS)
        sheet_6f.paste(thumb, (i * 96 + 4, 24), thumb)

    strip.save(SCRATCH_PREVIEW)
    sheet_6f.save(ROOT / "assets" / "sprites" / "anim_fox_run.png")
    print(f"preview saved: {SCRATCH_PREVIEW}")


if __name__ == "__main__":
    main()
