import argparse
import json
import os
import sys

import numpy as np
from PIL import Image
from scipy.ndimage import binary_dilation, label

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPRITES_DIR = os.path.join(PROJECT_ROOT, "assets", "sprites")
RAW_CONCEPT = r"C:/Users/jiang/Pictures/百宝/Gemini_Generated_Image_jf6lm9jf6lm9jf6l.jpg"
RAW_VIDEO = r"C:/Users/jiang/Pictures/百宝/gemini_generated_video_a59a9892.mp4"
RAW_STILLS = r"C:/Users/jiang/Pictures/百宝/Gemini_Generated_Image_pfsptqpfsptqpfsp.jpg"
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

# 靠引擎程序化动作驱动的小怪：只拆单张立绘（enemy_<id>.png），不配套绿幕视频图集
STILL_MONSTERS = [
    {"id": "fenyu_sanya", "name": "焚羽三鸦", "tier": "minion", "col": 0, "row": 0},
    {"id": "xueyi_yefu", "name": "血翼夜蝠", "tier": "minion", "col": 1, "row": 0},
    {"id": "qingyan_denglong", "name": "青焰灯笼", "tier": "minion", "col": 2, "row": 0},
    {"id": "duyan_tangsan", "name": "独眼唐伞", "tier": "minion", "col": 3, "row": 0},
    {"id": "bichi_zhongsi", "name": "碧翅螽斯", "tier": "minion", "col": 4, "row": 0},
    {"id": "linjia_chuanshan", "name": "鳞甲穿山", "tier": "minion", "col": 0, "row": 1},
    {"id": "chihuan_wugong", "name": "赤环蜈蚣", "tier": "minion", "col": 1, "row": 1},
    {"id": "kulou_dizhu", "name": "骷髅地蛛", "tier": "minion", "col": 2, "row": 1},
    {"id": "lingzhi_gujing", "name": "灵芝菇精", "tier": "minion", "col": 3, "row": 1},
    {"id": "tongke_xiejiang", "name": "铜壳蟹将", "tier": "minion", "col": 4, "row": 1},
]
# 单张图无标签文字，行带只按上下两排的实际留白切分
STILL_ROW_BANDS = ((0, 740), (740, CONCEPT_SIZE[1]))
# 列边界取上下两排投影同时为空的列，避免把火鸦的火苗、穿山甲的尾巴切一半分给邻格
STILL_COL_SPLITS = (0, 632, 1137, 1660, 2185, CONCEPT_SIZE[0])

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
    # 半透明羽化环里的绿幕色会被缩放后的 alpha 除法放大成绿边，这里直接去饱和
    ring_cap = (out[:, :, 0] + out[:, :, 2]) * 0.5 + 4
    out[:, :, 1] = np.where(ring & (out[:, :, 1] > ring_cap), ring_cap, out[:, :, 1])
    return np.dstack([np.clip(out, 0, 255), alpha * 255.0]).astype(np.uint8)


def trim_alpha(im: Image.Image, pad: int = 6) -> Image.Image:
    a = np.array(im.getchannel("A"))
    ys, xs = np.where(a > 8)
    x0 = max(0, int(xs.min()) - pad)
    x1 = min(im.width, int(xs.max()) + pad + 1)
    y0 = max(0, int(ys.min()) - pad)
    y1 = min(im.height, int(ys.max()) + pad + 1)
    return im.crop((x0, y0, x1, y1))


def _resize_rgba(im: Image.Image, size: tuple[int, int]) -> Image.Image:
    # 预乘 alpha 再缩放：透明区的残留屏幕色不会被插值拉成彩边
    arr = np.array(im, dtype=np.float32)
    a = arr[:, :, 3] / 255.0
    arr[:, :, :3] *= a[:, :, None]
    planes = [Image.fromarray(arr[:, :, i], "F").resize(size, Image.Resampling.LANCZOS)
              for i in range(4)]
    out = np.dstack([np.array(p, dtype=np.float32) for p in planes])
    out[:, :, 3] = np.clip(out[:, :, 3], 0.0, 255.0)
    safe = np.maximum(out[:, :, 3] / 255.0, 1e-3)[:, :, None]
    out[:, :, :3] = np.clip(out[:, :, :3] / safe, 0.0, 255.0)
    return Image.fromarray(out.astype(np.uint8), "RGBA")


def square_fit(im: Image.Image, side: int, foot_y: float = 0.94) -> Image.Image:
    scale = min(side / im.width, side * foot_y / im.height)
    w = max(1, int(round(im.width * scale)))
    h = max(1, int(round(im.height * scale)))
    resized = _resize_rgba(im, (w, h))
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


def build_stills() -> dict[str, Image.Image]:
    rgb = np.array(Image.open(RAW_STILLS).convert("RGB"), dtype=np.float32)
    cut = Image.fromarray(key_cutout(rgb, sample_key(rgb)), "RGBA")
    os.makedirs(WORK_DIR, exist_ok=True)
    cut.save(os.path.join(WORK_DIR, "stills_cutout.png"))

    out = {}
    for m in STILL_MONSTERS:
        x0, x1 = STILL_COL_SPLITS[m["col"]], STILL_COL_SPLITS[m["col"] + 1]
        y0, y1 = STILL_ROW_BANDS[m["row"]]
        crop = clean_edge_blobs(trim_alpha(cut.crop((x0, y0, x1, y1))))
        out[m["id"]] = crop
        crop.save(os.path.join(WORK_DIR, f"still_{m['id']}.png"))
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


EDGE_ALPHA = (10, 80)
SEMI_LIMIT = 0.10
GREEN_EDGE_LIMIT = 0.15
BOTTOM_BAND = 0.015


def _frame_problems(frame: Image.Image, label: str) -> list[str]:
    out = []
    a = np.array(frame.getchannel("A")).astype(np.float32)
    rgb = np.array(frame.convert("RGB")).astype(np.int16)
    h, w = a.shape
    solid = a > 8
    if solid.sum() < 0.01 * h * w:
        return [f"{label}: 空白帧"]
    ys, xs = np.where(solid)
    y0, y1 = int(ys.min()), int(ys.max())
    x0, x1 = int(xs.min()), int(xs.max())
    band = max(2, int(round(h * BOTTOM_BAND)))
    if (a[h - band:] > 8).any():
        out.append(f"{label}: 底部 {band}px 有残留像素（多半是标签文字）")
    crop = a[y0:y1 + 1, x0:x1 + 1]
    semi = float(((crop > EDGE_ALPHA[0]) & (crop < EDGE_ALPHA[1])).mean())
    if semi > SEMI_LIMIT:
        out.append(f"{label}: 低透明碎片 {semi:.1%} > {SEMI_LIMIT:.0%}")
    edge = (a > EDGE_ALPHA[0]) & (a < EDGE_ALPHA[1])
    if edge.any():
        key = np.array([51.0, 168.0, 76.0])
        near_key = np.linalg.norm(rgb - key, axis=2) < 60.0
        g_dom = (rgb[:, :, 1] - np.maximum(rgb[:, :, 0], rgb[:, :, 2])) > 20
        ratio = float((edge & g_dom & near_key).sum()) / float(edge.sum())
        if ratio > GREEN_EDGE_LIMIT:
            out.append(f"{label}: 绿边 {ratio:.1%} > {GREEN_EDGE_LIMIT:.0%}")
    return out


def verify_stills() -> list[str]:
    problems: list[str] = []
    for m in STILL_MONSTERS:
        path = os.path.join(SPRITES_DIR, f"enemy_{m['id']}.png")
        if not os.path.exists(path):
            problems.append(f"{m['id']}: 缺少 enemy_{m['id']}.png")
            continue
        still = Image.open(path).convert("RGBA")
        if still.size != (256, 256):
            problems.append(f"{m['id']}: 立绘尺寸 {still.size}，应为 (256, 256)")
            continue
        problems += _frame_problems(still, f"{m['id']}@still")
    return problems


def verify() -> int:
    problems: list[str] = verify_stills()
    data_path = os.path.join(PROJECT_ROOT, "data", "v2", "enemies_waves_v2.json")
    data_txt = open(data_path, encoding="utf-8").read() if os.path.exists(data_path) else ""
    visual_path = os.path.join(PROJECT_ROOT, "scripts", "enemy_visual.gd")
    visual_txt = open(visual_path, encoding="utf-8").read() if os.path.exists(visual_path) else ""
    for m in MONSTERS:
        tall = FRAME_TALL[m["tier"]]
        sheet_path = os.path.join(SPRITES_DIR, f"anim_{m['id']}_run.png")
        still_path = os.path.join(SPRITES_DIR, f"enemy_{m['id']}.png")
        sheet_name = f"anim_{m['id']}_run.png"
        still_name = f"enemy_{m['id']}.png"
        if not os.path.exists(sheet_path):
            problems.append(f"{m['id']}: 缺少 {sheet_name}")
            continue
        sheet = Image.open(sheet_path).convert("RGBA")
        if sheet.size != (tall * FRAME_COUNT, tall):
            problems.append(f"{m['id']}: 图集尺寸 {sheet.size}，应为 {(tall * FRAME_COUNT, tall)}")
            continue
        for i in range(FRAME_COUNT):
            frame = sheet.crop((i * tall, 0, (i + 1) * tall, tall))
            problems += _frame_problems(frame, f"{m['id']}#{i}")
        if not os.path.exists(still_path):
            problems.append(f"{m['id']}: 缺少 {still_name}")
        else:
            still = Image.open(still_path).convert("RGBA")
            if still.size != (256, 256):
                problems.append(f"{m['id']}: 立绘尺寸 {still.size}，应为 (256, 256)")
            problems += _frame_problems(still, f"{m['id']}@still")
        if sheet_name not in data_txt:
            problems.append(f"{m['id']}: {sheet_name} 未登记到 enemies_waves_v2.json")
        if still_name not in data_txt:
            problems.append(f"{m['id']}: {still_name} 未登记到 enemies_waves_v2.json")
        if sheet_name not in visual_txt:
            problems.append(f"{m['id']}: enemy_visual.gd 未 preload {sheet_name}")
    for p in problems:
        print("[FAIL]", p)
    print(f"MONSTER_VERIFY {'OK' if not problems else 'FAILED'} problems={len(problems)}")
    return 0 if not problems else 1


def build_stills_only() -> int:
    stills = build_stills()
    contact_sheet([(m["name"], stills[m["id"]]) for m in STILL_MONSTERS],
                  os.path.join(WORK_DIR, "contact_stills.png"))
    print("STILLS OK", len(stills), WORK_DIR)
    return verify()


def build() -> int:
    concept = build_concept()
    build_video_frames()
    contact_sheet([(m["name"], concept[m["id"]]) for m in MONSTERS], os.path.join(WORK_DIR, "contact_concept.png"))
    cell = 200
    sheet_all = Image.new("RGB", (FRAME_COUNT * cell, len(MONSTERS) * cell), (28, 28, 28))
    for row, m in enumerate(MONSTERS):
        sheet = Image.open(os.path.join(WORK_DIR, f"anim_{m['id']}_run.png"))
        tall = FRAME_TALL[m["tier"]]
        for i in range(FRAME_COUNT):
            tile = Image.new("RGBA", (cell, cell), (42, 42, 42, 255))
            frame = sheet.crop((i * tall, 0, (i + 1) * tall, tall))
            tile.alpha_composite(frame.resize((cell, cell), Image.Resampling.LANCZOS))
            sheet_all.paste(tile.convert("RGB"), (i * cell, row * cell))
    sheet_all.save(os.path.join(WORK_DIR, "contact_video.png"))
    print("BUILD OK", WORK_DIR)
    return verify()


def main() -> int:
    ap = argparse.ArgumentParser(description="概念图拆立绘 + 绿幕视频拆帧为怪物动画图集")
    ap.add_argument("--verify", action="store_true", help="只校验已落库图集，不重新生成")
    ap.add_argument("--concept", default=RAW_CONCEPT)
    ap.add_argument("--video", default=RAW_VIDEO)
    ap.add_argument("--stills-concept", default=RAW_STILLS, help="静态小怪概念图（只拆单张立绘）")
    ap.add_argument("--stills", action="store_true", help="只拆 STILL_MONSTERS 的单张立绘")
    args = ap.parse_args()
    globals()["RAW_CONCEPT"] = args.concept
    globals()["RAW_VIDEO"] = args.video
    globals()["RAW_STILLS"] = args.stills_concept
    if args.verify:
        return verify()
    return build_stills_only() if args.stills else build()


if __name__ == "__main__":
    sys.exit(main())
