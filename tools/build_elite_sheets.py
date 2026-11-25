import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_animated_sheets import warp_rgba

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPRITES_DIR = os.path.join(PROJECT_ROOT, "assets", "sprites")
PREVIEW_DIR = os.path.join(PROJECT_ROOT, ".tmp")

SRC_SIZE = 128
WORK_SCALE = 3
PAD = 16
WORK_SIZE = (SRC_SIZE + PAD * 2) * WORK_SCALE
FRAME_SIZE = 128
SUPERSAMPLE = 4
GROUND_Y = 121.0
CENTER_X = 64.0
ALPHA_FLOOR = 8


def premultiplied_resize(rgba: np.ndarray, size: tuple[int, int]) -> np.ndarray:
    alpha = rgba[:, :, 3:4] / 255.0
    premul = np.concatenate([rgba[:, :, :3] * alpha, rgba[:, :, 3:4]], axis=2)
    im = Image.fromarray(np.clip(premul, 0, 255).astype(np.uint8), "RGBA")
    im = im.resize(size, Image.Resampling.LANCZOS)
    out = np.array(im, dtype=np.float32)
    a = out[:, :, 3:4]
    safe = np.maximum(a / 255.0, 1e-4)
    rgb = np.clip(out[:, :, :3] / safe, 0, 255)
    a = np.where(a <= ALPHA_FLOOR, 0.0, a)
    rgb[a[:, :, 0] <= 0.0] = 0.0
    return np.concatenate([rgb, a], axis=2)


def strip_bottom_shadow(rgba: np.ndarray) -> tuple[np.ndarray, int]:
    out = rgba.copy()
    alpha = out[:, :, 3]
    ys = np.where(alpha > 16)[0]
    if len(ys) == 0:
        return out, 0
    bottom = int(ys.max())
    band_top = bottom - max(3, int(round((bottom - int(ys.min())) * 0.06)))
    rgb = out[:, :, :3]
    sat = rgb.max(axis=2) - rgb.min(axis=2)
    lum = rgb.mean(axis=2)
    grayish = (sat < 26.0) & (lum > 120.0) & (alpha > 0)
    band = np.zeros_like(grayish)
    band[band_top : bottom + 1, :] = True
    target = grayish & band
    removed = int(target.sum())
    out[target, 3] = 0.0
    return out, removed


def load_source(name: str) -> tuple[np.ndarray, dict]:
    path = os.path.join(SPRITES_DIR, name)
    src = np.array(Image.open(path).convert("RGBA"), dtype=np.float32)
    if src.shape[0] != SRC_SIZE or src.shape[1] != SRC_SIZE:
        raise SystemExit(f"{name}: expected {SRC_SIZE}x{SRC_SIZE}, got {src.shape[1]}x{src.shape[0]}")
    src, removed = strip_bottom_shadow(src)
    src[:, :, 3] = np.where(src[:, :, 3] < ALPHA_FLOOR, 0.0, src[:, :, 3])

    up = premultiplied_resize(src, (SRC_SIZE * WORK_SCALE, SRC_SIZE * WORK_SCALE))
    canvas = np.zeros((WORK_SIZE, WORK_SIZE, 4), dtype=np.float32)
    pad_px = PAD * WORK_SCALE
    canvas[pad_px : pad_px + up.shape[0], pad_px : pad_px + up.shape[1]] = up
    return canvas, {"shadow_pixels_removed": removed}


def grid() -> tuple[np.ndarray, np.ndarray]:
    h = w = WORK_SIZE
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    return (xx - PAD * WORK_SCALE) / WORK_SCALE, (yy - PAD * WORK_SCALE) / WORK_SCALE


def rect_px(xx, yy, x0, x1, y0, y1, feather=2.0):
    mx = np.clip((xx - x0) / feather, 0.0, 1.0) * np.clip((x1 - xx) / feather, 0.0, 1.0)
    my = np.clip((yy - y0) / feather, 0.0, 1.0) * np.clip((y1 - yy) / feather, 0.0, 1.0)
    return mx * my


def band_px(yy, y0, y1, feather=3.0):
    return np.clip((yy - y0) / feather, 0.0, 1.0) * np.clip((y1 - yy) / feather, 0.0, 1.0)


def bone(xx, yy, pivot, center, sigma, angle=0.0, shift=(0.0, 0.0), sharpness=2.0, gate=1.0):
    cx, cy = center
    sx, sy = sigma
    d2 = ((xx - cx) / sx) ** 2 + ((yy - cy) / sy) ** 2
    w = np.exp(-0.5 * np.power(np.maximum(d2, 1e-6), sharpness * 0.5)) * gate
    px, py = pivot
    ca, sa = math.cos(angle), math.sin(angle)
    rx, ry = xx - px, yy - py
    dx = (rx * ca - ry * sa + px) - xx + shift[0]
    dy = (rx * sa + ry * ca + py) - yy + shift[1]
    return w, dx, dy


def blend(xx, yy, bones, base_shift=(0.0, 0.0), base_angle=0.0, base_pivot=(0.5, 0.5), base_weight=0.6):
    px, py = base_pivot
    ca, sa = math.cos(base_angle), math.sin(base_angle)
    rx, ry = xx - px, yy - py
    bdx = (rx * ca - ry * sa + px) - xx + base_shift[0]
    bdy = (rx * sa + ry * ca + py) - yy + base_shift[1]
    w_sum = np.full(xx.shape, base_weight, dtype=np.float32)
    dx_sum = bdx * w_sum
    dy_sum = bdy * w_sum
    for w, dx, dy in bones:
        w_sum = w_sum + w
        dx_sum = dx_sum + w * dx
        dy_sum = dy_sum + w * dy
    return dx_sum / np.maximum(w_sum, 1e-4), dy_sum / np.maximum(w_sum, 1e-4)


def warp(canvas: np.ndarray, dx: np.ndarray, dy: np.ndarray) -> np.ndarray:
    scale = WORK_SCALE / float(WORK_SIZE)
    return warp_rgba(canvas, dx * scale, dy * scale)


def phase(idx: int, total: int) -> float:
    return (float(idx) / float(total)) * 2.0 * math.pi


def fox_frame(canvas, xx, yy, idx, total):
    p = phase(idx, total)
    s = math.sin(p)
    c = math.cos(p)
    bob = -abs(s) * 3.6
    front_swing = -s * 0.26
    rear_swing = s * 0.26
    front_lift = -max(0.0, -c) * 4.6
    rear_lift = -max(0.0, c) * 4.6
    bones = [
        bone(xx, yy, (99, 100), (101, 117), (11, 12), front_swing, (-s * 4.0, front_lift + bob * 0.25)),
        bone(xx, yy, (85, 99), (81, 114), (9, 11), -front_swing * 0.9, (s * 3.2, rear_lift * 0.85 + bob * 0.25)),
        bone(xx, yy, (73, 97), (74, 113), (9, 11), rear_swing, (s * 3.6, rear_lift + bob * 0.3)),
        bone(xx, yy, (57, 95), (59, 110), (9, 10), -rear_swing * 0.9, (-s * 2.8, -3.8 * max(0.0, -c))),
        bone(xx, yy, (103, 84), (104, 68), (17, 16), -c * 0.05, (0.0, bob * 0.75), gate=1.1),
        bone(xx, yy, (66, 92), (48, 74), (22, 24), np.sin(p - 0.9) * 0.06, (np.sin(p - 0.8) * 3.2, np.cos(p - 0.8) * 3.2), gate=1.0),
    ]
    dx, dy = blend(xx, yy, bones, base_shift=(0.0, bob), base_angle=-c * 0.012, base_pivot=(92, 96), base_weight=0.55)
    tail_gate = rect_px(xx, yy, 2, 62, 18, 108, feather=6.0)
    dx = dx + tail_gate * np.sin(p - 1.3) * 2.4
    dy = dy + tail_gate * np.cos(p - 1.3) * 1.8
    return warp(canvas, dx, dy)


def doll_frame(canvas, xx, yy, idx, total):
    p = phase(idx, total)
    s = math.sin(p)
    c = math.cos(p)
    float_y = -s * 3.2
    sway_x = c * 1.3

    hem = band_px(yy, 86.0, 124.0, feather=5.0)
    upper = rect_px(xx, yy, 2, 100, 0, 72, feather=4.0)
    sleeve = rect_px(xx, yy, 60, 118, 66, 88, feather=3.0)
    ribbon_tail = rect_px(xx, yy, 0, 30, 66, 108, feather=4.0)
    talisman = rect_px(xx, yy, 56, 80, 22, 58, feather=3.0)

    upper_dx = -math.sin(p + 1.0) * 1.2
    upper_dy = -math.sin(p + 1.0) * 1.2

    dx = np.full_like(xx, sway_x)
    dy = np.full_like(xx, float_y)

    dx = dx + hem * np.cos(p - (xx - 40.0) * 0.10) * 1.9
    dy = dy + hem * np.sin(p - (xx - 40.0) * 0.10) * 2.4

    dx = dx + upper * upper_dx
    dy = dy + upper * upper_dy

    dx = dx + sleeve * math.sin(p + 0.6) * 1.5
    dy = dy + sleeve * (-math.sin(p + 0.6) * 0.6)

    dx = dx + ribbon_tail * math.sin(p - 0.5) * 2.2
    dy = dy + ribbon_tail * math.cos(p - 0.5) * 1.6

    dy = dy + talisman * math.sin(p * 2.0 - 1.1) * 0.5

    dx = dx + hem * np.sin(p * 2.0 - xx * 0.16) * 1.2
    return warp(canvas, dx, dy)


def shanxiao_frame(canvas, xx, yy, idx, total):
    p = phase(idx, total)
    s = math.sin(p)
    c = math.cos(p)
    bob = -abs(s) * 4.4
    step = math.sin(p)

    bones = [
        bone(xx, yy, (58, 105), (55, 118), (10, 11), -step * 0.17, (step * 3.4, -max(0.0, c) * 3.6)),
        bone(xx, yy, (78, 105), (82, 118), (10, 11), step * 0.17, (-step * 3.4, -max(0.0, -c) * 3.6)),
        bone(xx, yy, (64, 92), (64, 100), (28, 12), 0.0, (0.0, bob * 0.4), gate=1.0),
        bone(xx, yy, (66, 72), (66, 44), (24, 22), -s * 0.02, (0.0, bob * 0.7), gate=1.1),
        bone(xx, yy, (74, 54), (34, 38), (26, 16), math.sin(p - 0.6) * 0.028, (0.0, math.cos(p - 0.6) * 2.0), gate=1.0),
        bone(xx, yy, (34, 66), (30, 86), (12, 18), math.sin(p + 0.4) * 0.045, (-math.sin(p + 0.4) * 2.0, 0.0), gate=1.0),
    ]
    dx, dy = blend(xx, yy, bones, base_shift=(s * 0.8, bob), base_angle=math.sin(p) * 0.018, base_pivot=(66, 108), base_weight=0.55)
    skirt = band_px(yy, 86.0, 114.0, feather=4.0)
    dx = dx + skirt * np.sin(p - (xx - 40.0) * 0.12) * 1.8
    dy = dy + skirt * np.cos(p - (xx - 40.0) * 0.12) * 1.5
    return warp(canvas, dx, dy)


def jiangshi_frame(canvas, xx, yy, idx, total):
    p = phase(idx, total)
    s = math.sin(p)
    c = math.cos(p)
    hop = -abs(s) * 7.0
    tuck = max(0.0, -c) * 1.4

    bones = [
        bone(xx, yy, (56, 62), (78, 64), (26, 13), 0.0, (0.0, hop * 0.35), gate=1.0),
        bone(xx, yy, (60, 60), (58, 34), (20, 18), -c * 0.02, (0.0, hop * 0.6), gate=1.1),
        bone(xx, yy, (52, 104), (52, 116), (14, 11), 0.0, (0.0, hop * 0.55 + tuck), gate=1.0),
    ]
    dx, dy = blend(xx, yy, bones, base_shift=(s * 0.9, hop), base_angle=0.0, base_pivot=(58, 104), base_weight=0.6)

    robe = band_px(yy, 92.0, 120.0, feather=5.0)
    dy = dy + robe * np.sin(p - 0.7 - (xx - 50.0) * 0.12) * 2.0
    dx = dx + robe * np.cos(p - 0.7 - (xx - 50.0) * 0.12) * 1.3

    talisman = rect_px(xx, yy, 52, 82, 16, 52, feather=3.0)
    dy = dy + talisman * math.sin(p * 2.0 - 0.8) * 1.2
    dx = dx + talisman * math.cos(p * 2.0 - 0.8) * 0.8

    cap = rect_px(xx, yy, 34, 60, 6, 32, feather=4.0)
    dx = dx + cap * math.sin(p + 0.3) * 1.6
    dy = dy + cap * math.cos(p + 0.3) * 1.0
    return warp(canvas, dx, dy)


def jinchan_frame(canvas, xx, yy, idx, total):
    p = phase(idx, total)
    s = math.sin(p)
    c = math.cos(p)
    hop = -abs(s) * 3.4
    crouch = max(0.0, -c) * 1.7

    bones = [
        bone(xx, yy, (64, 86), (60, 78), (30, 22), c * 0.018, (0.0, hop), gate=1.1),
        bone(xx, yy, (46, 80), (36, 74), (17, 15), -s * 0.045, (0.0, hop * 0.9 + crouch * 0.4), gate=1.0),
        bone(xx, yy, (30, 102), (24, 111), (11, 12), -s * 0.20, (-s * 2.8, crouch)),
        bone(xx, yy, (92, 100), (98, 109), (11, 12), s * 0.20, (s * 2.8, crouch)),
        bone(xx, yy, (68, 98), (70, 109), (13, 12), 0.0, (0.0, hop * 0.5 + crouch)),
    ]
    dx, dy = blend(xx, yy, bones, base_shift=(0.0, hop), base_angle=c * 0.014, base_pivot=(64, 106), base_weight=0.7)

    sac = rect_px(xx, yy, 10, 60, 44, 86, feather=5.0)
    dx = dx + sac * (xx - 34.0) * math.sin(p * 2.0) * 0.018
    dy = dy + sac * math.sin(p * 2.0) * 1.5

    gems = rect_px(xx, yy, 62, 118, 34, 78, feather=5.0)
    dy = dy + gems * math.cos(p * 2.0 - 0.6) * 0.9
    return warp(canvas, dx, dy)


def shenjing_frame(canvas, xx, yy, idx, total):
    p = phase(idx, total)
    s = math.sin(p)
    c = math.cos(p)
    bob = -abs(s) * 2.6

    bones = [
        bone(xx, yy, (64, 64), (64, 44), (22, 23), c * 0.030, (0.0, bob * 0.7), gate=1.1),
        bone(xx, yy, (64, 86), (64, 86), (23, 18), 0.0, (0.0, bob * 0.5), gate=1.0),
        bone(xx, yy, (52, 100), (50, 112), (10, 12), -s * 0.30, (s * 3.0, -max(0.0, c) * 2.6)),
        bone(xx, yy, (76, 100), (78, 112), (10, 12), s * 0.30, (-s * 3.0, -max(0.0, -c) * 2.6)),
    ]
    dx, dy = blend(xx, yy, bones, base_shift=(s * 0.6, bob), base_angle=c * 0.028, base_pivot=(64, 104), base_weight=0.62)

    sprout = rect_px(xx, yy, 26, 100, 0, 36, feather=4.0)
    dx = dx + sprout * np.sin(p - 0.9) * 2.0
    dy = dy + sprout * np.cos(p - 0.9) * 1.2

    sash = rect_px(xx, yy, 44, 88, 84, 106, feather=4.0)
    dx = dx + sash * np.sin(p - 1.4) * 0.9
    return warp(canvas, dx, dy)


def huodou_frame(canvas, xx, yy, idx, total):
    p = phase(idx, total)
    s = math.sin(p)
    c = math.cos(p)
    bob = -abs(s) * 2.4

    bones = [
        bone(xx, yy, (100, 68), (106, 60), (18, 17), -c * 0.030, (0.0, bob), gate=1.1),
        bone(xx, yy, (74, 80), (70, 76), (27, 16), 0.0, (0.0, bob * 0.8), gate=1.0),
        bone(xx, yy, (100, 94), (106, 106), (10, 12), s * 0.28, (-s * 3.2, -max(0.0, -c) * 2.8)),
        bone(xx, yy, (52, 94), (44, 106), (11, 12), -s * 0.28, (s * 3.2, -max(0.0, c) * 2.8)),
    ]
    dx, dy = blend(xx, yy, bones, base_shift=(0.0, bob), base_angle=c * 0.018, base_pivot=(76, 102), base_weight=0.6)

    tail = rect_px(xx, yy, 0, 64, 14, 88, feather=6.0)
    dx = dx + tail * np.cos(p - xx * 0.09) * 1.6
    dy = dy + tail * np.sin(p - xx * 0.09) * 3.0

    mane = rect_px(xx, yy, 88, 122, 30, 66, feather=4.0)
    dy = dy + mane * np.sin(p * 2.0 - 0.5) * 1.1
    return warp(canvas, dx, dy)


SPECS = [
    {
        "key": "fox",
        "source": "enemy_elite_fox.png",
        "output": "anim_elite_fox_run.png",
        "frames": 6,
        "fps": 10.5,
        "target_height": 100,
        "frame_fn": fox_frame,
    },
    {
        "key": "doll",
        "source": "enemy_elite_doll.png",
        "output": "anim_elite_doll_float.png",
        "frames": 6,
        "fps": 8.0,
        "target_height": 112,
        "frame_fn": doll_frame,
    },
    {
        "key": "shanxiao",
        "source": "enemy_elite_shanxiao.png",
        "output": "anim_elite_shanxiao_run.png",
        "frames": 8,
        "fps": 11.5,
        "target_height": 113,
        "frame_fn": shanxiao_frame,
    },
    {
        "key": "jiangshi",
        "source": "enemy_elite_jiangshi.png",
        "output": "anim_elite_jiangshi_run.png",
        "frames": 8,
        "fps": 10.0,
        "target_height": 108,
        "frame_fn": jiangshi_frame,
    },
    {
        "key": "jinchan",
        "source": "enemy_elite_jinchan.png",
        "output": "anim_elite_jinchan_run.png",
        "frames": 8,
        "fps": 9.0,
        "target_height": 96,
        "frame_fn": jinchan_frame,
    },
    {
        "key": "shenjing",
        "source": "enemy_elite_shenjing.png",
        "output": "anim_elite_shenjing_run.png",
        "frames": 8,
        "fps": 13.5,
        "target_height": 108,
        "frame_fn": shenjing_frame,
    },
    {
        "key": "huodou",
        "source": "enemy_elite_huodou.png",
        "output": "anim_elite_huodou_run.png",
        "frames": 8,
        "fps": 12.0,
        "target_height": 100,
        "frame_fn": huodou_frame,
    },
]


def frame_bbox(rgba: np.ndarray, threshold: float = 16.0) -> tuple[float, float, float, float] | None:
    mask = rgba[:, :, 3] > threshold
    if not mask.any():
        return None
    ys, xs = np.where(mask)
    return (
        (xs.min() - PAD * WORK_SCALE) / WORK_SCALE,
        (xs.max() + 1 - PAD * WORK_SCALE) / WORK_SCALE,
        (ys.min() - PAD * WORK_SCALE) / WORK_SCALE,
        (ys.max() + 1 - PAD * WORK_SCALE) / WORK_SCALE,
    )


def resample_frame(comp: np.ndarray, scale: float, ax: float, ay: float) -> np.ndarray:
    alpha = comp[:, :, 3:4] / 255.0
    premul = np.concatenate([comp[:, :, :3] * alpha, comp[:, :, 3:4]], axis=2)
    im = Image.fromarray(np.clip(premul, 0, 255).astype(np.uint8), "RGBA")
    a = WORK_SCALE / scale / SUPERSAMPLE
    c = (ax + PAD) * WORK_SCALE - CENTER_X * WORK_SCALE / scale
    f = (ay + PAD) * WORK_SCALE - GROUND_Y * WORK_SCALE / scale
    big = im.transform(
        (FRAME_SIZE * SUPERSAMPLE, FRAME_SIZE * SUPERSAMPLE),
        Image.AFFINE,
        (a, 0, c, 0, a, f),
        resample=Image.BICUBIC,
    )
    return premultiplied_resize(np.array(big, dtype=np.float32), (FRAME_SIZE, FRAME_SIZE))


def build_spec(spec: dict) -> dict:
    canvas, load_info = load_source(spec["source"])
    xx, yy = grid()
    comps = []
    boxes = []
    for i in range(spec["frames"]):
        comp = spec["frame_fn"](canvas, xx, yy, i, spec["frames"])
        comps.append(comp)
        box = frame_bbox(comp)
        if box is None:
            raise SystemExit(f"{spec['key']}: frame {i} is empty")
        boxes.append(box)

    heights = [b[3] - b[2] for b in boxes]
    widths = [b[1] - b[0] for b in boxes]
    scale = min(spec["target_height"] / max(heights), 116.0 / max(widths), 1.35)
    centers_x = [0.5 * (b[0] + b[1]) for b in boxes]
    bottoms = [b[3] for b in boxes]
    ax = float(np.mean(centers_x))
    ay = float(max(bottoms))

    frame_arrays = []
    for comp in comps:
        frame_arrays.append(resample_frame(comp, scale, ax, ay))

    sheet = Image.new("RGBA", (FRAME_SIZE * spec["frames"], FRAME_SIZE), (0, 0, 0, 0))
    for i, arr in enumerate(frame_arrays):
        sheet.paste(Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA"), (i * FRAME_SIZE, 0))

    out_path = os.path.join(SPRITES_DIR, spec["output"])
    sheet.save(out_path, "PNG", optimize=True)

    stats = []
    for i, arr in enumerate(frame_arrays):
        mask = arr[:, :, 3] > 16
        ys, xs = np.where(mask)
        stats.append(
            {
                "frame": i,
                "bbox": [int(xs.min()), int(xs.max()), int(ys.min()), int(ys.max())],
                "cx": round(0.5 * (int(xs.min()) + int(xs.max())), 1),
                "bottom": int(ys.max()),
                "top": int(ys.min()),
                "corner_alpha": [int(arr[0, 0, 3]), int(arr[0, -1, 3]), int(arr[-1, 0, 3]), int(arr[-1, -1, 3])],
            }
        )

    src_bbox = frame_bbox(canvas)
    return {
        "key": spec["key"],
        "source": spec["source"],
        "output": spec["output"],
        "frames": spec["frames"],
        "fps": spec["fps"],
        "scale": round(scale, 4),
        "source_content": [round(v, 1) for v in src_bbox],
        "align_x": round(ax, 2),
        "align_ground_y": round(ay, 2),
        "size": list(sheet.size),
        "stats": stats,
        "shadow_pixels_removed": load_info["shadow_pixels_removed"],
    }


def make_preview(results: list[dict]) -> None:
    os.makedirs(PREVIEW_DIR, exist_ok=True)
    widths = [
        Image.open(os.path.join(SPRITES_DIR, r["output"])).width * 2 for r in results
    ]
    width = max(widths) + 24
    height = sum(128 * 2 + 34 for _ in results) + 20
    canvas = Image.new("RGBA", (width, height), (26, 30, 36, 255))
    draw = ImageDraw.Draw(canvas)
    y = 10
    for res in results:
        sheet = Image.open(os.path.join(SPRITES_DIR, res["output"])).convert("RGBA")
        big = sheet.resize((sheet.width * 2, sheet.height * 2), Image.Resampling.NEAREST)
        canvas.alpha_composite(big, (12, y))
        draw.line(
            [(12, y + int(round(121 * 2))), (12 + big.width, y + int(round(121 * 2)))],
            fill=(255, 80, 80, 180),
            width=1,
        )
        draw.text(
            (16, y + big.height + 4),
            f"{res['output']} {sheet.width}x{sheet.height} {res['frames']}f",
            fill=(240, 230, 190, 255),
        )
        y += big.height + 34
    canvas.save(os.path.join(PREVIEW_DIR, "elite_sheet_preview.png"))
    print("preview -> .tmp/elite_sheet_preview.png")


def main() -> None:
    only = set(sys.argv[1:])
    results = []
    for spec in SPECS:
        if only and spec["key"] not in only:
            continue
        res = build_spec(spec)
        results.append(res)
        print(
            f"{res['output']}: {res['size'][0]}x{res['size'][1]} frames={res['frames']} scale={res['scale']:.3f} "
            f"align_x={res['align_x']} ground_y={res['align_ground_y']} shadow_removed={res['shadow_pixels_removed']}"
        )
        for st in res["stats"]:
            print(
                f"  f{st['frame']}: bbox x[{st['bbox'][0]}..{st['bbox'][1]}] y[{st['bbox'][2]}..{st['bbox'][3]}] "
                f"cx={st['cx']} bottom={st['bottom']} corners={st['corner_alpha']}"
            )
    if len(results) == len(SPECS):
        make_preview(results)


if __name__ == "__main__":
    main()
