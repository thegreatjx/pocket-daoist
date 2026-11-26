import os
from collections import deque
import numpy as np
from PIL import Image

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FOREST_SRC = r"C:\Users\jiang\Pictures\百宝\秘境 1：青冥古林"
VOLCANO_SRC = r"C:\Users\jiang\Pictures\百宝\秘境 2：赤炎丹谷"
ICE_SRC = r"C:\Users\jiang\Pictures\百宝\秘境 3：玄冰剑冢"
CHECK_SHEET = r"C:\Users\jiang\.gemini\antigravity\brain\199bd3ce-222c-4710-9224-c90982285b91\scratch\realm_cutouts_check.png"
ICE_CHECK_SHEET = r"C:\Users\jiang\.gemini\antigravity\brain\199bd3ce-222c-4710-9224-c90982285b91\scratch\realm_ice_check.png"


def _sample_corner_bg(rgb: np.ndarray) -> np.ndarray:
    h, w, _ = rgb.shape
    patch = max(8, min(24, h // 20, w // 20))
    corners = np.concatenate(
        [
            rgb[:patch, :patch].reshape(-1, 3),
            rgb[:patch, w - patch :].reshape(-1, 3),
            rgb[h - patch :, :patch].reshape(-1, 3),
            rgb[h - patch :, w - patch :].reshape(-1, 3),
        ],
        axis=0,
    ).astype(np.float32)
    return np.median(corners, axis=0)


def _dilate_mask(mask: np.ndarray, radius: int) -> np.ndarray:
    h, w = mask.shape
    pad = np.pad(mask, radius, mode="constant", constant_values=True)
    out = np.zeros((h, w), dtype=bool)
    r2 = radius * radius
    for dy in range(-radius, radius + 1):
        for dx in range(-radius, radius + 1):
            if dy * dy + dx * dx <= r2:
                out |= pad[radius + dy : radius + dy + h, radius + dx : radius + dx + w]
    return out


def _flood_fill(cand: np.ndarray, seeds: list[tuple[int, int]]) -> np.ndarray:
    h, w = cand.shape
    bg = np.zeros((h, w), dtype=bool)
    q: deque[tuple[int, int]] = deque()
    for sy, sx in seeds:
        if 0 <= sy < h and 0 <= sx < w and cand[sy, sx] and not bg[sy, sx]:
            bg[sy, sx] = True
            q.append((sy, sx))
    while q:
        cy, cx = q.popleft()
        if cy > 0 and cand[cy - 1, cx] and not bg[cy - 1, cx]:
            bg[cy - 1, cx] = True
            q.append((cy - 1, cx))
        if cy + 1 < h and cand[cy + 1, cx] and not bg[cy + 1, cx]:
            bg[cy + 1, cx] = True
            q.append((cy + 1, cx))
        if cx > 0 and cand[cy, cx - 1] and not bg[cy, cx - 1]:
            bg[cy, cx - 1] = True
            q.append((cy, cx - 1))
        if cx + 1 < w and cand[cy, cx + 1] and not bg[cy, cx + 1]:
            bg[cy, cx + 1] = True
            q.append((cy, cx + 1))
    return bg


def _border_seeds(h: int, w: int) -> list[tuple[int, int]]:
    seeds: list[tuple[int, int]] = []
    for x in range(w):
        seeds.append((0, x))
        seeds.append((h - 1, x))
    for y in range(h):
        seeds.append((y, 0))
        seeds.append((y, w - 1))
    return seeds


def process_seamless_tile(src_path: str, dst_path: str, size: int = 512, overlap: int = 32) -> None:
    arr = np.array(Image.open(src_path).convert("RGB"), dtype=np.float32)
    h, w, _ = arr.shape
    nw = w - overlap
    nh = h - overlap

    t_x = (0.5 - 0.5 * np.cos(np.pi * np.arange(overlap, dtype=np.float32) / float(overlap)))[None, :, None]
    out_x = arr[:, :nw, :].copy()
    out_x[:, :overlap, :] = arr[:, nw:, :] * (1.0 - t_x) + arr[:, :overlap, :] * t_x

    t_y = (0.5 - 0.5 * np.cos(np.pi * np.arange(overlap, dtype=np.float32) / float(overlap)))[:, None, None]
    out_xy = out_x[:nh, :, :].copy()
    out_xy[:overlap, :, :] = out_x[nh:, :, :] * (1.0 - t_y) + out_x[:overlap, :, :] * t_y

    img = Image.fromarray(np.clip(out_xy, 0, 255).astype(np.uint8), "RGB")
    img = img.resize((size, size), Image.Resampling.LANCZOS)
    os.makedirs(os.path.dirname(dst_path), exist_ok=True)
    img.save(dst_path, "PNG", optimize=True)


def key_chroma_4pass(
    rgb: np.ndarray,
    mode: str,
    fringe_radius: int = 5,
    hard_dist: float = 52.0,
    hard_tint: float = 22.0,
    flood_only: bool = False,
) -> np.ndarray:
    h, w, _ = rgb.shape
    src = rgb.astype(np.float32)
    painted_key = _sample_corner_bg(rgb)

    if mode == "magenta":
        ideal = np.array([255.0, 0.0, 255.0], dtype=np.float32)
        tint = 0.5 * (src[:, :, 0] + src[:, :, 2]) - src[:, :, 1]
        key_tint = max(1.0, float(0.5 * (painted_key[0] + painted_key[2]) - painted_key[1]))
    elif mode == "orchid":
        ideal = painted_key
        tint = np.minimum(src[:, :, 0], src[:, :, 2]) - src[:, :, 1]
        key_tint = max(1.0, float(min(painted_key[0], painted_key[2]) - painted_key[1]))
    elif mode == "blue":
        ideal = np.array([0.0, 0.0, 255.0], dtype=np.float32)
        tint = src[:, :, 2] - np.maximum(src[:, :, 0], src[:, :, 1])
        key_tint = max(1.0, float(painted_key[2] - max(painted_key[0], painted_key[1])))
    else:
        raise ValueError(f"Unsupported chroma mode: {mode}")

    d_ideal = np.linalg.norm(src - ideal[None, None, :], axis=2)
    d_paint = np.linalg.norm(src - painted_key[None, None, :], axis=2)
    dist = np.minimum(d_ideal, d_paint)

    cand_hard = (dist <= hard_dist) & (tint >= hard_tint)
    if flood_only:
        hard_key = _flood_fill(cand_hard, _border_seeds(h, w))
        # Also remove interior sky gaps that match orchid background closely
        sky_holes = (np.minimum(src[:, :, 0], src[:, :, 2]) - src[:, :, 1] > 58.0) & (d_paint <= 42.0) & (~hard_key)
        if np.any(sky_holes):
            hard_key |= _flood_fill(cand_hard, list(zip(*np.where(sky_holes))))
    else:
        hard_key = cand_hard

    near_key = _dilate_mask(hard_key, fringe_radius)
    alpha = np.where(hard_key, 0.0, 1.0).astype(np.float32)
    in_fringe = (~hard_key) & near_key & (tint > 5.0)
    k_frac = np.clip(tint / key_tint, 0.0, 0.96)
    a_unmix = np.clip(1.0 - k_frac, 0.04, 1.0)
    alpha = np.where(in_fringe, np.minimum(alpha, a_unmix), alpha)

    safe_a = np.maximum(alpha, 0.08)[:, :, None]
    unmixed = np.clip((src - (1.0 - alpha[:, :, None]) * painted_key[None, None, :]) / safe_a, 0.0, 255.0)
    out_rgb = np.where(in_fringe[:, :, None], unmixed, src)

    spill_mask = (alpha > 0.0) & (tint > 8.0)
    if mode in ("magenta", "orchid"):
        cap = out_rgb[:, :, 1] * (1.12 if mode == "magenta" else 1.25)
        out_rgb[:, :, 0] = np.where(spill_mask, np.minimum(out_rgb[:, :, 0], cap), out_rgb[:, :, 0])
        out_rgb[:, :, 2] = np.where(spill_mask, np.minimum(out_rgb[:, :, 2], cap), out_rgb[:, :, 2])
    elif mode == "blue":
        cap = np.maximum(out_rgb[:, :, 0], out_rgb[:, :, 1]) * 1.12
        out_rgb[:, :, 2] = np.where(spill_mask, np.minimum(out_rgb[:, :, 2], cap), out_rgb[:, :, 2])

    out_rgb = np.where((alpha > 0.0)[:, :, None], out_rgb, 0.0)
    rgba = np.zeros((h, w, 4), dtype=np.uint8)
    rgba[:, :, :3] = np.clip(out_rgb, 0, 255).astype(np.uint8)
    rgba[:, :, 3] = np.clip(alpha * 255.0, 0, 255).astype(np.uint8)
    return rgba


def key_white_watercolor(rgb: np.ndarray) -> np.ndarray:
    h, w, _ = rgb.shape
    cmax = rgb.max(axis=2).astype(np.int16)
    cmin = rgb.min(axis=2).astype(np.int16)
    chroma = cmax - cmin
    cand = (cmin >= 238) & (chroma <= 18)
    bg = _flood_fill(cand, _border_seeds(h, w))

    near_bg = _dilate_mask(bg, 4)
    alpha = np.where(bg, 0.0, 1.0).astype(np.float32)
    rgb_f = rgb.astype(np.float32)
    bg_color = np.array([255.0, 255.0, 255.0], dtype=np.float32)
    dist_bg = np.linalg.norm(rgb_f - bg_color[None, None, :], axis=2)

    fringe = (~bg) & near_bg & (cmin >= 150) & (chroma <= 26)
    a_fringe = np.clip((dist_bg - 12.0) / 135.0, 0.05, 1.0)
    alpha = np.where(fringe, a_fringe, alpha)

    safe_a = np.maximum(alpha, 0.12)
    decontam = np.clip((rgb_f - (1.0 - alpha[:, :, None]) * 255.0) / safe_a[:, :, None], 0.0, 255.0)
    out_rgb = np.where(fringe[:, :, None], decontam, rgb_f)
    out_rgb = np.where((alpha > 0.0)[:, :, None], out_rgb, 0.0)

    rgba = np.zeros((h, w, 4), dtype=np.uint8)
    rgba[:, :, :3] = np.clip(out_rgb, 0, 255).astype(np.uint8)
    rgba[:, :, 3] = np.clip(alpha * 255.0, 0, 255).astype(np.uint8)
    return rgba


def save_fitted_rgba(rgba: np.ndarray, dst_path: str, target_size: int = 512, anchor: str = "center") -> None:
    fg_y, fg_x = np.where(rgba[:, :, 3] > 12)
    x0, x1 = int(fg_x.min()), int(fg_x.max()) + 1
    y0, y1 = int(fg_y.min()), int(fg_y.max()) + 1
    cropped = Image.fromarray(rgba[y0:y1, x0:x1], "RGBA")

    margin = 20 if anchor == "center" else 12
    inner = target_size - margin * 2
    scale = min(inner / cropped.width, inner / cropped.height)
    nw = max(1, round(cropped.width * scale))
    nh = max(1, round(cropped.height * scale))
    resized = cropped.resize((nw, nh), Image.Resampling.LANCZOS)

    canvas = Image.new("RGBA", (target_size, target_size), (0, 0, 0, 0))
    ox = (target_size - nw) // 2
    oy = (target_size - nh) // 2 if anchor == "center" else (target_size - nh - 12)
    canvas.paste(resized, (ox, oy), resized)

    os.makedirs(os.path.dirname(dst_path), exist_ok=True)
    canvas.save(dst_path, "PNG", optimize=True)


def build_contact_sheet(paths: list[str], out_path: str) -> None:
    cols = 4
    rows = (len(paths) + cols - 1) // cols
    cell = 256
    sheet = Image.new("RGB", (cols * cell, rows * cell), (112, 118, 124))
    # Mid-gray checkerboard background
    arr = np.zeros((rows * cell, cols * cell, 3), dtype=np.uint8)
    yy, xx = np.indices((rows * cell, cols * cell))
    checker = ((yy // 16) + (xx // 16)) % 2 == 0
    arr[checker] = (108, 112, 118)
    arr[~checker] = (132, 136, 142)
    sheet = Image.fromarray(arr, "RGB")

    for i, p in enumerate(paths):
        im = Image.open(p).convert("RGBA").resize((cell, cell), Image.Resampling.LANCZOS)
        r = i // cols
        c = i % cols
        sheet.paste(im, (c * cell, r * cell), im)

    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    sheet.save(out_path, "PNG", optimize=True)


def main() -> None:
    forest_dst = os.path.join(PROJECT_ROOT, "assets", "v2", "maps", "forest")
    volcano_dst = os.path.join(PROJECT_ROOT, "assets", "v2", "maps", "volcano")
    ice_dst = os.path.join(PROJECT_ROOT, "assets", "v2", "maps", "ice")

    # Forest, Volcano & Ice tiles
    process_seamless_tile(os.path.join(FOREST_SRC, "L1tile_ground_grass.jpg"), os.path.join(forest_dst, "tile_ground_grass.png"))
    process_seamless_tile(os.path.join(VOLCANO_SRC, "tile_ground_basalt.jpg"), os.path.join(volcano_dst, "tile_ground_basalt.png"))
    process_seamless_tile(os.path.join(ICE_SRC, "Gemini_Generated_Image_h7s5yh7s5yh7s5yh.jpg"), os.path.join(ice_dst, "tile_ground_snow.png"))

    cutout_jobs = [
        # (src_path, dst_path, mode, anchor, kwargs)
        (os.path.join(FOREST_SRC, "Gemini_Generated_Image_8gm8qr8gm8qr8gm8.jpg"), os.path.join(forest_dst, "decal_road_stone.png"), "white", "center", {}),
        (os.path.join(FOREST_SRC, "Gemini_Generated_Image_fqqe63fqqe63fqqe.jpg"), os.path.join(forest_dst, "decal_spirit_array.png"), "magenta", "center", {"fringe_radius": 5}),
        (os.path.join(FOREST_SRC, "Gemini_Generated_Image_wh0z00wh0z00wh0z.jpg"), os.path.join(forest_dst, "decal_spring_pool.png"), "magenta", "center", {"fringe_radius": 8, "hard_dist": 65.0, "hard_tint": 14.0}),
        (os.path.join(FOREST_SRC, "Gemini_Generated_Image_ykoia2ykoia2ykoi.jpg"), os.path.join(forest_dst, "prop_ancient_pine.png"), "orchid", "bottom", {"fringe_radius": 4, "hard_dist": 60.0, "hard_tint": 50.0, "flood_only": True}),
        (os.path.join(FOREST_SRC, "Gemini_Generated_Image_swf9jvswf9jvswf9.jpg"), os.path.join(forest_dst, "prop_jade_rock.png"), "magenta", "bottom", {"fringe_radius": 5}),
        (os.path.join(FOREST_SRC, "Gemini_Generated_Image_eldm02eldm02eldm.jpg"), os.path.join(forest_dst, "prop_lantern_stele.png"), "magenta", "bottom", {"fringe_radius": 5}),
        (os.path.join(FOREST_SRC, "Gemini_Generated_Image_nexmg3nexmg3nexm.jpg"), os.path.join(forest_dst, "border_cliff_trees.png"), "magenta", "bottom", {"fringe_radius": 5}),

        (os.path.join(VOLCANO_SRC, "Gemini_Generated_Image_4qq7t4qq7t4qq7t4.jpg"), os.path.join(volcano_dst, "decal_road_basalt.png"), "magenta", "center", {"fringe_radius": 5}),
        (os.path.join(VOLCANO_SRC, "Gemini_Generated_Image_he7zxkhe7zxkhe7z.jpg"), os.path.join(volcano_dst, "decal_alchemy_array.png"), "magenta", "center", {"fringe_radius": 5}),
        (os.path.join(VOLCANO_SRC, "decal_lava_vent.jpg"), os.path.join(volcano_dst, "decal_lava_vent.png"), "blue", "center", {"fringe_radius": 5, "hard_dist": 60.0, "hard_tint": 22.0}),
        (os.path.join(VOLCANO_SRC, "rop_bronze_cauldron.jpg"), os.path.join(volcano_dst, "prop_bronze_cauldron.png"), "magenta", "bottom", {"fringe_radius": 5}),
        (os.path.join(VOLCANO_SRC, "Gemini_Generated_Image_24rvee24rvee24rv.jpg"), os.path.join(volcano_dst, "prop_danxia_pillar.png"), "blue", "bottom", {"fringe_radius": 5, "hard_dist": 72.0, "hard_tint": 24.0}),
        (os.path.join(VOLCANO_SRC, "border_volcano_cliff.jpg"), os.path.join(volcano_dst, "border_volcano_cliff.png"), "blue", "bottom", {"fringe_radius": 5, "hard_dist": 60.0, "hard_tint": 22.0}),

        (os.path.join(ICE_SRC, "Gemini_Generated_Image_u6i627u6i627u6i6.jpg"), os.path.join(ice_dst, "decal_road_froststone.png"), "magenta", "center", {"fringe_radius": 5}),
        (os.path.join(ICE_SRC, "Gemini_Generated_Image_3ghhx03ghhx03ghh.jpg"), os.path.join(ice_dst, "decal_sword_array.png"), "magenta", "center", {"fringe_radius": 5}),
        (os.path.join(ICE_SRC, "Gemini_Generated_Image_mavlu5mavlu5mavl.jpg"), os.path.join(ice_dst, "decal_frozen_pond.png"), "magenta", "center", {"fringe_radius": 5}),
        (os.path.join(ICE_SRC, "Gemini_Generated_Image_h0i85ph0i85ph0i8.jpg"), os.path.join(ice_dst, "prop_giant_sword.png"), "magenta", "bottom", {"fringe_radius": 5}),
        (os.path.join(ICE_SRC, "Gemini_Generated_Image_zcw7emzcw7emzcw7.jpg"), os.path.join(ice_dst, "prop_sword_stele.png"), "magenta", "bottom", {"fringe_radius": 5}),
        (os.path.join(ICE_SRC, "Gemini_Generated_Image_sbwxm7sbwxm7sbwx.jpg"), os.path.join(ice_dst, "border_ice_ridge.png"), "magenta", "bottom", {"fringe_radius": 5}),
    ]

    generated: list[str] = [
        os.path.join(forest_dst, "tile_ground_grass.png"),
        os.path.join(volcano_dst, "tile_ground_basalt.png"),
    ]
    ice_generated: list[str] = [os.path.join(ice_dst, "tile_ground_snow.png")]
    for src, dst, mode, anchor, kw in cutout_jobs:
        rgb = np.array(Image.open(src).convert("RGB"), dtype=np.uint8)
        rgba = key_white_watercolor(rgb) if mode == "white" else key_chroma_4pass(rgb, mode, **kw)
        save_fitted_rgba(rgba, dst, target_size=512, anchor=anchor)
        generated.append(dst)
        if dst.startswith(ice_dst):
            ice_generated.append(dst)
        print(f"Processed {os.path.basename(dst)}")

    build_contact_sheet(generated, CHECK_SHEET)
    build_contact_sheet(ice_generated, ICE_CHECK_SHEET)
    print(f"Generated {len(generated)} assets and ice contact sheet -> {ICE_CHECK_SHEET}")


if __name__ == "__main__":
    main()
