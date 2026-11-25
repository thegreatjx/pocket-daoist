import glob
import os
from collections import deque
import numpy as np
from PIL import Image

ARTIFACT_DIR = r"C:\Users\jiang\.gemini\antigravity\brain\ae5e230a-1459-41fc-b001-30b3232451c2"
PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def find_latest_raw(prefix: str) -> str:
    pattern = os.path.join(ARTIFACT_DIR, f"{prefix}_*.jpg")
    matches = sorted(glob.glob(pattern))
    if not matches:
        raise FileNotFoundError(f"Missing generated raw image matching: {pattern}")
    return matches[-1]


def process_title_bg(src_path: str, dst_path: str) -> None:
    img = Image.open(src_path).convert("RGB")
    target_w, target_h = 1280, 720
    scale = max(target_w / img.width, target_h / img.height)
    nw, nh = round(img.width * scale), round(img.height * scale)
    img = img.resize((nw, nh), Image.Resampling.LANCZOS)
    left = (nw - target_w) // 2
    top = (nh - target_h) // 2
    img = img.crop((left, top, left + target_w, top + target_h))
    os.makedirs(os.path.dirname(dst_path), exist_ok=True)
    img.save(dst_path, "PNG", optimize=True)
    print(f"Saved title_bg -> {dst_path} ({img.size})")


def process_seamless_tile(src_path: str, dst_path: str, size: int = 256) -> None:
    arr = np.array(Image.open(src_path).convert("RGB"), dtype=np.float32)
    h, w, _ = arr.shape
    overlap = 64
    nw = w - overlap
    nh = h - overlap

    # 1D horizontal wrap blend: blend right strip [nw..w) into left strip [0..overlap)
    t_x = (0.5 - 0.5 * np.cos(np.pi * np.arange(overlap, dtype=np.float32) / float(overlap)))[None, :, None]
    out_x = arr[:, :nw, :].copy()
    out_x[:, :overlap, :] = arr[:, nw:, :] * (1.0 - t_x) + arr[:, :overlap, :] * t_x

    # 1D vertical wrap blend
    t_y = (0.5 - 0.5 * np.cos(np.pi * np.arange(overlap, dtype=np.float32) / float(overlap)))[:, None, None]
    out_xy = out_x[:nh, :, :].copy()
    out_xy[:overlap, :, :] = out_x[nh:, :, :] * (1.0 - t_y) + out_x[:overlap, :, :] * t_y

    img = Image.fromarray(np.clip(out_xy, 0, 255).astype(np.uint8), "RGB")
    img = img.resize((size, size), Image.Resampling.LANCZOS)
    os.makedirs(os.path.dirname(dst_path), exist_ok=True)
    img.save(dst_path, "PNG", optimize=True)
    print(f"Saved seamless tile -> {dst_path} ({img.size})")


def flood_fill_bg(cand: np.ndarray, seeds: list[tuple[int, int]]) -> np.ndarray:
    h, w = cand.shape
    bg = np.zeros((h, w), dtype=bool)
    q = deque()
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


# Background cutout and 4-pass chroma/matte soft-alpha unmixing + palette decontamination
# adapted from aldegad/sprite-gen (https://github.com/aldegad/sprite-gen, SPDX-License-Identifier: Apache-2.0).


def detect_corner_key_mode(rgb: np.ndarray) -> tuple[str, np.ndarray]:
    h, w, _ = rgb.shape
    patch = max(4, min(16, h // 20, w // 20))
    corners = np.concatenate(
        [
            rgb[:patch, :patch].reshape(-1, 3),
            rgb[:patch, w - patch :].reshape(-1, 3),
            rgb[h - patch :, :patch].reshape(-1, 3),
            rgb[h - patch :, w - patch :].reshape(-1, 3),
        ],
        axis=0,
    ).astype(np.float32)
    bg_med = np.median(corners, axis=0)
    r, g, b = float(bg_med[0]), float(bg_med[1]), float(bg_med[2])
    if g - max(r, b) > 45.0:
        return "green", bg_med
    if min(r, b) - g > 45.0:
        return "magenta", bg_med
    return "white", bg_med


def remove_chroma_background_4pass(rgb: np.ndarray, key_mode: str, painted_key: np.ndarray) -> np.ndarray:
    h, w, _ = rgb.shape
    src = rgb.astype(np.float32)
    decl = np.array([0.0, 255.0, 0.0] if key_mode == "green" else [255.0, 0.0, 255.0], dtype=np.float32)
    d_decl = np.linalg.norm(src - decl[None, None, :], axis=2)
    d_paint = np.linalg.norm(src - painted_key[None, None, :], axis=2)
    dist = np.minimum(d_decl, d_paint)

    if key_mode == "green":
        tint = src[:, :, 1] - np.maximum(src[:, :, 0], src[:, :, 2])
        key_tint = max(1.0, float(painted_key[1] - max(painted_key[0], painted_key[2])))
    else:
        tint = 0.5 * (src[:, :, 0] + src[:, :, 2]) - src[:, :, 1]
        key_tint = max(1.0, float(0.5 * (painted_key[0] + painted_key[2]) - painted_key[1]))

    # Pass 1: hard key cut
    hard_key = (dist <= 44.0) & (tint >= 18.0)

    # Pass 2 & 3: Chebyshev distance reach (up to 5px) + soft-alpha unmix F = (P - (1-a)*B)/a
    pad = np.pad(hard_key, 4, mode="constant", constant_values=True)
    near_key = np.zeros((h, w), dtype=bool)
    for dy in range(-4, 5):
        for dx in range(-4, 5):
            if max(abs(dy), abs(dx)) <= 4:
                near_key |= pad[4 + dy : 4 + dy + h, 4 + dx : 4 + dx + w]

    alpha = np.where(hard_key, 0.0, 1.0).astype(np.float32)
    in_fringe = (~hard_key) & near_key & (tint > 6.0)
    k_frac = np.clip(tint / key_tint, 0.0, 0.96)
    a_unmix = np.clip(1.0 - k_frac, 0.04, 1.0)
    alpha = np.where(in_fringe, np.minimum(alpha, a_unmix), alpha)

    safe_a = np.maximum(alpha, 0.08)[:, :, None]
    unmixed = np.clip((src - (1.0 - alpha[:, :, None]) * painted_key[None, None, :]) / safe_a, 0.0, 255.0)
    out_rgb = np.where(in_fringe[:, :, None], unmixed, src)

    # Pass 4: trapped-spill despill on remaining semi-tinted pixels
    spill_mask = (alpha > 0.0) & (tint > 10.0)
    if key_mode == "green":
        cap = np.maximum(out_rgb[:, :, 0], out_rgb[:, :, 2])
        out_rgb[:, :, 1] = np.where(spill_mask, np.minimum(out_rgb[:, :, 1], cap), out_rgb[:, :, 1])
    else:
        cap = out_rgb[:, :, 1] * 1.15
        out_rgb[:, :, 0] = np.where(spill_mask, np.minimum(out_rgb[:, :, 0], cap), out_rgb[:, :, 0])
        out_rgb[:, :, 2] = np.where(spill_mask, np.minimum(out_rgb[:, :, 2], cap), out_rgb[:, :, 2])

    out_rgb = np.where((alpha > 0.0)[:, :, None], out_rgb, 0.0)
    rgba = np.zeros((h, w, 4), dtype=np.uint8)
    rgba[:, :, :3] = np.clip(out_rgb, 0, 255).astype(np.uint8)
    rgba[:, :, 3] = np.clip(alpha * 255.0, 0, 255).astype(np.uint8)
    return rgba


def process_cutout(
    src_path: str,
    dst_path: str,
    target_size: int,
    extra_seeds: list[tuple[int, int]] | None = None,
    auto_holes: bool = False,
) -> None:
    raw_im = Image.open(src_path)
    if raw_im.mode == "RGBA":
        raw_rgba = np.array(raw_im, dtype=np.uint8)
        if int((raw_rgba[:, :, 3] < 16).sum()) > (raw_rgba.shape[0] * raw_rgba.shape[1]) // 10:
            rgba = raw_rgba.copy()
            zero_a = rgba[:, :, 3] == 0
            rgba[zero_a, :3] = 0
        else:
            rgb = raw_rgba[:, :, :3]
            key_mode, bg_med = detect_corner_key_mode(rgb)
            rgba = remove_chroma_background_4pass(rgb, key_mode, bg_med) if key_mode in ("green", "magenta") else None
    else:
        rgb = np.array(raw_im.convert("RGB"), dtype=np.uint8)
        key_mode, bg_med = detect_corner_key_mode(rgb)
        rgba = remove_chroma_background_4pass(rgb, key_mode, bg_med) if key_mode in ("green", "magenta") else None

    if rgba is None:
        h, w, _ = rgb.shape
        cmax = rgb.max(axis=2).astype(np.int16)
        cmin = rgb.min(axis=2).astype(np.int16)
        chroma = cmax - cmin
        cand = (cmin >= 238) & (chroma <= 18)

        seeds: list[tuple[int, int]] = []
        for x in range(w):
            seeds.append((0, x))
            seeds.append((h - 1, x))
        for y in range(h):
            seeds.append((y, 0))
            seeds.append((y, w - 1))
        if extra_seeds:
            for sx, sy in extra_seeds:
                seeds.append((sy, sx))

        bg = flood_fill_bg(cand, seeds)

        if auto_holes:
            pure_white = (cmin >= 246) & (chroma <= 12) & (~bg)
            ys, xs = np.where(pure_white)
            visited_h = np.zeros((h, w), dtype=bool)
            for y0, x0 in zip(ys.tolist(), xs.tolist()):
                if visited_h[y0, x0]:
                    continue
                comp_pts = []
                q = deque([(y0, x0)])
                visited_h[y0, x0] = True
                while q:
                    cy, cx = q.popleft()
                    comp_pts.append((cy, cx))
                    for ny, nx in ((cy - 1, cx), (cy + 1, cx), (cy, cx - 1), (cy, cx + 1)):
                        if 0 <= ny < h and 0 <= nx < w and not visited_h[ny, nx] and pure_white[ny, nx]:
                            visited_h[ny, nx] = True
                            q.append((ny, nx))
                if len(comp_pts) >= 70:
                    hole_bg = flood_fill_bg(cand, [comp_pts[0]])
                    bg |= hole_bg

        pad = np.pad(bg, 3, mode="constant", constant_values=True)
        near_bg = np.zeros((h, w), dtype=bool)
        for dy in range(-3, 4):
            for dx in range(-3, 4):
                if dy * dy + dx * dx <= 9:
                    near_bg |= pad[3 + dy : 3 + dy + h, 3 + dx : 3 + dx + w]

        alpha = np.where(bg, 0.0, 1.0).astype(np.float32)
        rgb_f = rgb.astype(np.float32)
        bg_color = np.array([255.0, 255.0, 255.0], dtype=np.float32)
        dist_bg = np.linalg.norm(rgb_f - bg_color[None, None, :], axis=2)

        fringe = (~bg) & near_bg & (cmin >= 145) & (chroma <= 26)
        a_fringe = np.clip((dist_bg - 12.0) / 135.0, 0.05, 1.0)
        alpha = np.where(fringe, a_fringe, alpha)

        safe_a = np.maximum(alpha, 0.12)
        decontam = np.clip((rgb_f - (1.0 - alpha[:, :, None]) * 255.0) / safe_a[:, :, None], 0.0, 255.0)
        out_rgb = np.where(fringe[:, :, None], decontam, rgb_f)
        out_rgb = np.where((alpha > 0.0)[:, :, None], out_rgb, 0.0)

        rgba = np.zeros((h, w, 4), dtype=np.uint8)
        rgba[:, :, :3] = np.clip(out_rgb, 0, 255).astype(np.uint8)
        rgba[:, :, 3] = np.clip(alpha * 255.0, 0, 255).astype(np.uint8)

    # Crop tight bounding box of non-transparent content
    fg_y, fg_x = np.where(rgba[:, :, 3] > 12)
    x0, x1 = int(fg_x.min()), int(fg_x.max()) + 1
    y0, y1 = int(fg_y.min()), int(fg_y.max()) + 1
    cropped = Image.fromarray(rgba[y0:y1, x0:x1], "RGBA")

    # Fit into square canvas with 6% safety margin on each side
    inner = max(8, round(target_size * 0.88))
    scale = min(inner / cropped.width, inner / cropped.height)
    nw = max(1, round(cropped.width * scale))
    nh = max(1, round(cropped.height * scale))
    resized = cropped.resize((nw, nh), Image.Resampling.LANCZOS)

    canvas = Image.new("RGBA", (target_size, target_size), (0, 0, 0, 0))
    ox = (target_size - nw) // 2
    oy = (target_size - nh) // 2
    canvas.paste(resized, (ox, oy), resized)

    os.makedirs(os.path.dirname(dst_path), exist_ok=True)
    canvas.save(dst_path, "PNG", optimize=True)
    print(f"Saved cutout -> {dst_path} ({canvas.size}, fg_bbox={x1-x0}x{y1-y0})")


def main() -> None:
    process_title_bg(
        find_latest_raw("title_bg_raw"),
        os.path.join(PROJECT_ROOT, "assets", "art", "title_bg.png"),
    )
    process_seamless_tile(
        find_latest_raw("tile_forest_raw"),
        os.path.join(PROJECT_ROOT, "assets", "terrain", "tile_forest.png"),
        size=256,
    )

    cutouts = [
        ("pine_raw", "assets/props/pine.png", 128, None, True),
        ("lantern_raw", "assets/props/lantern.png", 128, [(512, 126)], False),
        ("rune_stone_raw", "assets/props/rune_stone.png", 128, None, False),
        ("fern_raw", "assets/props/fern.png", 128, None, True),
        ("hero_qinglv_sword_raw", "assets/sprites/hero_qinglv_sword.png", 128, [(415, 570)], False),
        ("enemy_fox_spirit_raw", "assets/sprites/enemy_fox_spirit.png", 96, None, False),
        ("enemy_paper_doll_raw", "assets/sprites/enemy_paper_doll.png", 96, None, False),
        ("enemy_shanxiao_raw", "assets/sprites/enemy_shanxiao.png", 96, None, False),
        ("enemy_elite_boar_raw", "assets/sprites/enemy_elite_boar.png", 128, None, False),
        ("boss_wolf_king_raw", "assets/sprites/boss_wolf_king.png", 220, [(550, 270), (695, 760)], False),
    ]
    for prefix, rel_dst, sz, seeds, auto_h in cutouts:
        process_cutout(
            find_latest_raw(prefix),
            os.path.join(PROJECT_ROOT, rel_dst),
            target_size=sz,
            extra_seeds=seeds,
            auto_holes=auto_h,
        )


if __name__ == "__main__":
    main()
