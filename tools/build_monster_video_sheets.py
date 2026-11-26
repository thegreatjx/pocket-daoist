import os
import sys

import numpy as np
from PIL import Image
from scipy.ndimage import binary_dilation, label

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPRITES_DIR = os.path.join(PROJECT_ROOT, "assets", "sprites")
RAW_CONCEPT = r"C:/Users/jiang/Pictures/百宝/Gemini_Generated_Image_jf6lm9jf6lm9jf6l.jpg"
RAW_VIDEO = r"C:/Users/jiang/Pictures/百宝/gemini_generated_video_a59a9892.mp4"
WORK_DIR = os.path.join(PROJECT_ROOT, ".tmp", "monsters")

CONCEPT_SIZE = (2752, 1536)
CONCEPT_COLS = 5
CONCEPT_ROWS = 2

MONSTERS = [
    {"id": "zhusha_zhiren", "name": "朱砂纸人", "tier": "minion", "col": 0, "row": 0},
    {"id": "chihuo_danling", "name": "炽火丹灵", "tier": "minion", "col": 1, "row": 0},
    {"id": "wudu_zhangchan", "name": "五毒蟾蜍", "tier": "minion", "col": 2, "row": 0},
    {"id": "canjian_jiankui", "name": "残剑剑傀", "tier": "minion", "col": 3, "row": 0},
    {"id": "yinsha_daotong", "name": "阴煞道童", "tier": "elite", "col": 4, "row": 0},
    {"id": "zhenhun_shidun", "name": "镇魂石墩", "tier": "elite", "col": 0, "row": 1},
    {"id": "bagua_danlu", "name": "成精八卦丹炉", "tier": "boss", "col": 1, "row": 1},
    {"id": "tongjia_shiwang", "name": "铜甲尸王", "tier": "boss", "col": 2, "row": 1},
    {"id": "huapi_huandao", "name": "画皮狐妖", "tier": "boss", "col": 3, "row": 1},
    {"id": "wanjian_mozun", "name": "万剑魔尊", "tier": "boss", "col": 4, "row": 1},
]

VIDEO_CELL = (256, 360)
VIDEO_ROW_CROP = ((0, 294), (360, 654))

FRAME_COUNT = 8
FRAME_TALL = {"minion": 128, "elite": 160, "boss": 224}


def key_cutout(rgb: np.ndarray, key: np.ndarray, dist: float = 70.0) -> np.ndarray:
    h, w, _ = rgb.shape
    diff = np.linalg.norm(rgb - key, axis=2)
    greenish = (rgb[:, :, 1] - np.maximum(rgb[:, :, 0], rgb[:, :, 2])) > 25
    cand = (diff < dist) & greenish

    border = np.zeros((h, w), bool)
    border[0, :] = border[-1, :] = True
    border[:, 0] = border[:, -1] = True
    bg = cand & border
    while True:
        grown = binary_dilation(bg, iterations=3) & cand
        if grown.sum() == bg.sum():
            break
        bg = grown

    strict = (diff < 22.0) & greenish & ~bg
    lbl, n = label(strict)
    if n:
        counts = np.bincount(lbl.ravel())
        for cid in range(1, n + 1):
            if counts[cid] < 200:
                continue
            ys, xs = np.where(lbl == cid)
            if ys.min() > 2 and xs.min() > 2 and ys.max() < h - 3 and xs.max() < w - 3:
                bg |= lbl == cid

    alpha = np.where(bg, 0.0, 1.0).astype(np.float32)
    ring = binary_dilation(bg, iterations=1) & ~bg
    alpha[ring] = 0.55
    edge = binary_dilation(bg, iterations=2) & ~bg
    out = rgb.astype(np.float32).copy()
    g = out[:, :, 1]
    cap = np.maximum(out[:, :, 0], out[:, :, 2]) + 8
    out[:, :, 1] = np.where(edge & (g > cap), cap, g)
    return np.dstack([np.clip(out, 0, 255), alpha * 255.0]).astype(np.uint8)


def trim_alpha(im: Image.Image, pad: int = 6) -> Image.Image:
    a = np.array(im.getchannel("A"))
    ys, xs = np.where(a > 8)
    x0 = max(0, int(xs.min()) - pad)
    x1 = min(im.width, int(xs.max()) + pad + 1)
    y0 = max(0, int(ys.min()) - pad)
    y1 = min(im.height, int(ys.max()) + pad + 1)
    return im.crop((x0, y0, x1, y1))


def square_fit(im: Image.Image, side: int, foot_y: float = 0.94) -> Image.Image:
    scale = min(side / im.width, side * foot_y / im.height)
    w = max(1, int(round(im.width * scale)))
    h = max(1, int(round(im.height * scale)))
    resized = im.resize((w, h), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    x = (side - w) // 2
    y = int(round(side * foot_y)) - h
    canvas.alpha_composite(resized, (x, y))
    return canvas


def clean_edge_blobs(im: Image.Image, min_area: int = 600) -> Image.Image:
    a = np.array(im.getchannel("A"))
    lbl, n = label(a > 8)
    if n <= 1:
        return im
    keep = np.ones(n + 1, bool)
    h, w = a.shape
    for cid in range(1, n + 1):
        ys, xs = np.where(lbl == cid)
        touches = ys.min() <= 1 or xs.min() <= 1 or ys.max() >= h - 2 or xs.max() >= w - 2
        if touches and len(ys) < min_area:
            keep[cid] = False
    out = np.array(im)
    out[~keep[lbl], 3] = 0
    return Image.fromarray(out, "RGBA")


def sample_key(rgb: np.ndarray) -> np.ndarray:
    corners = np.concatenate([
        rgb[:8, :8].reshape(-1, 3), rgb[:8, -8:].reshape(-1, 3),
        rgb[-8:, :8].reshape(-1, 3), rgb[-8:, -8:].reshape(-1, 3),
    ])
    return np.median(corners, axis=0)


def build_concept() -> dict[str, Image.Image]:
    rgb = np.array(Image.open(RAW_CONCEPT).convert("RGB"), dtype=np.float32)
    key = sample_key(rgb)
    cut = Image.fromarray(key_cutout(rgb, key), "RGBA")
    os.makedirs(WORK_DIR, exist_ok=True)
    cut.save(os.path.join(WORK_DIR, "concept_cutout.png"))

    cell_w = CONCEPT_SIZE[0] / CONCEPT_COLS
    row_bands = ((0, 640), (768, 1425))
    out = {}
    for m in MONSTERS:
        x0 = int(round(m["col"] * cell_w))
        x1 = int(round((m["col"] + 1) * cell_w))
        y0, y1 = row_bands[m["row"]]
        crop = clean_edge_blobs(trim_alpha(cut.crop((x0, y0, x1, y1))))
        out[m["id"]] = crop
        crop.save(os.path.join(WORK_DIR, f"concept_{m['id']}.png"))
        square_fit(crop, 512).save(os.path.join(WORK_DIR, f"concept_{m['id']}_512.png"))
        square_fit(crop, 256, 0.96).save(os.path.join(SPRITES_DIR, f"enemy_{m['id']}.png"))
    return out


def build_video_frames() -> dict[str, list[Image.Image]]:
    raw_dir = os.path.join(WORK_DIR, "video_raw")
    clean_dir = os.path.join(WORK_DIR, "video_clean")
    os.makedirs(raw_dir, exist_ok=True)
    os.makedirs(clean_dir, exist_ok=True)
    if len([f for f in os.listdir(raw_dir) if f.endswith(".png")]) < 240:
        os.system(f'ffmpeg -y -v error -i "{RAW_VIDEO}" -vf fps=24 "{raw_dir}/frame_%04d.png"')

    frames_rgba = []
    for i in range(1, 241):
        clean_path = os.path.join(clean_dir, f"clean_{i:04d}.png")
        if os.path.exists(clean_path):
            frames_rgba.append(Image.open(clean_path).convert("RGBA"))
            continue
        rgb = np.array(Image.open(os.path.join(raw_dir, f"frame_{i:04d}.png")).convert("RGB"), dtype=np.float32)
        if not frames_rgba:
            keys = sample_key(rgb)
        else:
            keys = sample_key(rgb)
        im = Image.fromarray(key_cutout(rgb, keys), "RGBA")
        im.save(clean_path)
        frames_rgba.append(im)

    out = {}
    for m in MONSTERS:
        x0 = m["col"] * VIDEO_CELL[0]
        y0, y1 = VIDEO_ROW_CROP[m["row"]]
        picks = [int(round(i * 240.0 / FRAME_COUNT)) for i in range(FRAME_COUNT)]
        cells = []
        for pi in picks:
            crop = frames_rgba[pi].crop((x0, y0, x0 + VIDEO_CELL[0], y1))
            if m["id"] == "wanjian_mozun":
                arr = np.array(crop)
                yy, xx = np.mgrid[0:arr.shape[0], 0:arr.shape[1]]
                cx = arr.shape[1] * 0.5
                cy = (y1 - y0) * 0.42
                ring = (xx - cx) ** 2 + (yy - cy) ** 2 < 116 ** 2
                green = (arr[:, :, 1].astype(np.int16) - np.maximum(arr[:, :, 0], arr[:, :, 2])) > 25
                kill = ring & green
                arr[kill, 3] = 0
                arr[kill, :3] = 0
                crop = Image.fromarray(arr, "RGBA")
            cells.append(crop)
        tall = FRAME_TALL[m["tier"]]
        alphas = [np.array(c.getchannel("A")) for c in cells]
        centers = []
        bottoms = []
        for a in alphas:
            ys, xs = np.where(a > 8)
            if len(xs) == 0:
                continue
            centers.append(float(xs.mean()))
            bottoms.append(int(ys.max()))
        cx = float(np.median(centers))
        foot = float(np.median(bottoms))
        scale = tall / 360.0
        aligned = []
        for crop in cells:
            w = int(round(VIDEO_CELL[0] * scale))
            h = int(round(crop.height * scale))
            resized = crop.resize((w, h), Image.Resampling.LANCZOS)
            canvas = Image.new("RGBA", (tall, tall), (0, 0, 0, 0))
            x = int(round(tall / 2.0 - cx * scale))
            y = int(round(tall * 0.94 - foot * scale))
            canvas.alpha_composite(resized, (x, y))
            aligned.append(canvas)
        sheet = Image.new("RGBA", (tall * FRAME_COUNT, tall), (0, 0, 0, 0))
        for i, im in enumerate(aligned):
            sheet.alpha_composite(im, (i * tall, 0))
        sheet.save(os.path.join(WORK_DIR, f"anim_{m['id']}_run.png"))
        sheet.save(os.path.join(SPRITES_DIR, f"anim_{m['id']}_run.png"))
        out[m["id"]] = aligned
    return out


def contact_sheet(items: list[tuple[str, Image.Image]], out_path: str) -> None:
    cols = 5
    cell = 280
    rows = (len(items) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * cell, rows * cell), (28, 28, 28))
    for i, (label, im) in enumerate(items):
        tile = Image.new("RGBA", (cell, cell), (42, 42, 42, 255))
        fitted = square_fit(im, cell, 0.94)
        tile.alpha_composite(fitted)
        sheet.paste(tile.convert("RGB"), ((i % cols) * cell, (i // cols) * cell))
    sheet.save(out_path)


if __name__ == "__main__":
    concept = build_concept()
    video = build_video_frames()
    contact_sheet([(m["name"], concept[m["id"]]) for m in MONSTERS], os.path.join(WORK_DIR, "contact_concept.png"))
    cell = 200
    sheet_all = Image.new("RGB", (FRAME_COUNT * cell, len(MONSTERS) * cell), (28, 28, 28))
    for row, m in enumerate(MONSTERS):
        sheet = Image.open(os.path.join(WORK_DIR, f"anim_{m['id']}_run.png"))
        tall = FRAME_TALL[m["tier"]]
        for i in range(FRAME_COUNT):
            tile = Image.new("RGBA", (cell, cell), (42, 42, 42, 255))
            frame = sheet.crop((i * tall, 0, (i + 1) * tall, tall))
            fitted = frame.resize((int(tall * cell / tall), cell), Image.Resampling.LANCZOS)
            tile.alpha_composite(fitted)
            sheet_all.paste(tile.convert("RGB"), (i * cell, row * cell))
    sheet_all.save(os.path.join(WORK_DIR, "contact_video.png"))
    print("ok", WORK_DIR)
