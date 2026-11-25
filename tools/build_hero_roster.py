import glob
import os
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import process_painted_assets as ppa

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ARTIFACT_DIR = r"C:\Users\jiang\.gemini\antigravity\brain\8a3fb7cb-53d3-4aeb-a29a-18c5859c23dc"
HEROES_DIR = os.path.join(PROJECT_ROOT, "assets", "v2", "heroes")
SCRATCH_DIR = os.path.join(ARTIFACT_DIR, "scratch")

HERO_SPECS = [
    {
        "id": "hero_whisk_immortal",
        "raw_prefix": "hero_whisk_immortal",
        "name": "沈砚 · 御剑道君",
        "mode": "御剑/踏云浮空 (hover_ride)",
        "weapon": "青霜飞剑 / 青莲剑气",
        "flip_x": False,
        "auto_holes": True,
    },
    {
        "id": "hero_cloud_fairy",
        "raw_prefix": "hero_cloud_fairy",
        "name": "青瑶 · 踏云丹师",
        "mode": "御剑/踏云浮空 (hover_ride)",
        "weapon": "天雷符 / 九天雷印",
        "flip_x": False,
        "auto_holes": True,
    },
    {
        "id": "hero_jinyiwei_v2",
        "raw_prefix": "hero_jinyiwei_v2",
        "name": "陆昭 · 神机枪炮师",
        "mode": "烈焰火轮浮空 (hover_ride)",
        "weapon": "离火葫芦 / 神机火铳",
        "flip_x": False,
        "auto_holes": True,
    },
    {
        "id": "hero_gourd_blob",
        "raw_prefix": "hero_gourd_blob",
        "name": "阿葫 · 灵葫小仙",
        "mode": "土豆兄弟式Q弹团子 (brotato_bounce)",
        "weapon": "离火葫芦 / 炎阳火莲",
        "flip_x": False,
        "auto_holes": True,
    },
    {
        "id": "hero_mochi_daoist",
        "raw_prefix": "hero_mochi_daoist",
        "name": "圆圆 · 太极小道童",
        "mode": "土豆兄弟式Q弹团子 (brotato_bounce)",
        "weapon": "玄金古钟 / 八卦剑阵",
        "flip_x": False,
        "auto_holes": False,
    },
    {
        "id": "hero_fox_dango",
        "raw_prefix": "hero_fox_dango",
        "name": "白团 · 青丘幼狐",
        "mode": "土豆兄弟式Q弹团子 (brotato_bounce)",
        "weapon": "玄冰八卦镜 / 子母飞剑",
        "flip_x": False,
        "auto_holes": False,
    },
]


def find_raw_image(prefix: str) -> str:
    matches = sorted(glob.glob(os.path.join(ARTIFACT_DIR, f"{prefix}_*.jpg")))
    if not matches:
        matches = sorted(glob.glob(os.path.join(ARTIFACT_DIR, f"{prefix}_*.png")))
    if not matches:
        raise FileNotFoundError(f"No raw hero image found for prefix: {prefix}")
    return matches[-1]


def process_hero_sprite(spec: dict) -> str:
    os.makedirs(HEROES_DIR, exist_ok=True)
    os.makedirs(SCRATCH_DIR, exist_ok=True)

    raw_path = find_raw_image(spec["raw_prefix"])
    tmp_path = os.path.join(SCRATCH_DIR, f"{spec['id']}_tmp.png")
    ppa.process_cutout(
        raw_path,
        tmp_path,
        target_size=256,
        extra_seeds=spec.get("extra_seeds"),
        auto_holes=bool(spec.get("auto_holes", True)),
    )

    im = Image.open(tmp_path).convert("RGBA")
    if spec.get("flip_x", False):
        im = im.transpose(Image.Transpose.FLIP_LEFT_RIGHT)

    arr = np.array(im)
    ys, xs = np.where(arr[:, :, 3] > 12)
    x0, x1 = int(xs.min()), int(xs.max()) + 1
    y0, y1 = int(ys.min()), int(ys.max()) + 1
    cropped = im.crop((x0, y0, x1, y1))

    max_box = 240
    scale = min(max_box / float(cropped.width), max_box / float(cropped.height))
    nw = max(1, round(cropped.width * scale))
    nh = max(1, round(cropped.height * scale))
    resized = cropped.resize((nw, nh), Image.Resampling.LANCZOS)

    canvas = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    ox = (256 - nw) // 2
    oy = 248 - nh
    canvas.paste(resized, (ox, oy), resized)

    dst_path = os.path.join(HEROES_DIR, f"{spec['id']}.png")
    canvas.save(dst_path, "PNG", optimize=True)
    print(f"Saved bottom-anchored hero -> {dst_path} (size={nw}x{nh}, ox={ox}, oy={oy})")
    return dst_path


def make_showcase() -> str:
    f_header = ImageFont.truetype(r"C:\Windows\Fonts\msyh.ttc", 24)
    f_title = ImageFont.truetype(r"C:\Windows\Fonts\msyh.ttc", 17)
    f_meta = ImageFont.truetype(r"C:\Windows\Fonts\msyh.ttc", 13)

    cols = 3
    rows = (len(HERO_SPECS) + cols - 1) // cols
    card_w, card_h = 280, 350
    pad = 20
    gap = 16
    width = pad * 2 + cols * card_w + (cols - 1) * gap
    height = 90 + rows * card_h + (rows - 1) * gap + pad
    canvas = Image.new("RGBA", (width, height), (18, 26, 24, 255))
    draw = ImageDraw.Draw(canvas)

    draw.text((pad, 16), "《百宝小道修 (Pocket Daoist)》全阵容六主角统一画风预览", font=f_header, fill=(246, 230, 174, 255))
    draw.text((pad, 50), "上排：修仙浮空派（御剑 / 踏云 / 烈焰火轮）   |   下排：土豆兄弟式 Q 弹团子（线性挤压拉伸手感）", font=f_meta, fill=(160, 210, 195, 255))

    for idx, spec in enumerate(HERO_SPECS):
        r = idx // cols
        c = idx % cols
        x = pad + c * (card_w + gap)
        y = 86 + r * (card_h + gap)
        draw.rounded_rectangle([x, y, x + card_w, y + card_h], radius=12, fill=(28, 40, 36, 255), outline=(72, 102, 90, 255), width=2)
        draw.rounded_rectangle([x + 14, y + 14, x + card_w - 14, y + 244], radius=8, fill=(16, 24, 22, 255), outline=(56, 78, 70, 255), width=1)
        draw.line([(x + 30, y + 232), (x + card_w - 30, y + 232)], fill=(70, 130, 115, 180), width=2)

        hero_p = os.path.join(HEROES_DIR, f"{spec['id']}.png")
        if os.path.exists(hero_p):
            him = Image.open(hero_p).convert("RGBA").resize((216, 216), Image.Resampling.LANCZOS)
            canvas.paste(him, (x + (card_w - 216) // 2, y + 20), him)

        draw.text((x + 16, y + 256), spec["name"], font=f_title, fill=(250, 228, 148, 255))
        draw.text((x + 16, y + 286), spec["mode"], font=f_meta, fill=(130, 220, 235, 255))
        draw.text((x + 16, y + 312), f"初始法宝：{spec['weapon']}", font=f_meta, fill=(205, 215, 200, 255))

    out_path = os.path.join(ARTIFACT_DIR, "hero_roster_showcase.png")
    canvas.save(out_path, "PNG", optimize=True)
    print(f"Saved hero showcase -> {out_path}")
    return out_path


def main() -> None:
    for spec in HERO_SPECS:
        process_hero_sprite(spec)
    make_showcase()


if __name__ == "__main__":
    main()
