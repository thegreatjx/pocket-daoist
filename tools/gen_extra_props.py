# 补画两件场景装饰：地蕨（替换原来的藤蔓，像素画得太散像悬空的箭头）
from PIL import Image, ImageDraw
import math, random

OUT = "assets/props"

def fern(seed: int = 7) -> Image.Image:
    rng = random.Random(seed)
    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # 根部土堆
    d.ellipse((20, 56, 44, 63), fill=(46, 38, 30, 255))
    for i in range(7):
        ang = math.radians(-160 + i * 19 + rng.randint(-6, 6))
        length = rng.randint(26, 40)
        x0, y0 = 32 + rng.randint(-4, 4), 58
        x1 = x0 + math.cos(ang) * length
        y1 = y0 + math.sin(ang) * length
        shade = rng.randint(-16, 12)
        d.line((x0, y0, x1, y1), fill=(38 + shade, 104 + shade, 52 + shade, 255), width=3)
        # 叶片
        for k in range(3):
            t = 0.35 + k * 0.28
            lx = x0 + (x1 - x0) * t
            ly = y0 + (y1 - y0) * t
            ll = rng.randint(7, 12)
            side = 1 if k % 2 == 0 else -1
            d.polygon([
                (lx, ly),
                (lx + ll * side, ly - ll * 0.45),
                (lx + ll * 0.35 * side, ly + 3),
            ], fill=(58 + shade, 132 + shade, 62 + shade, 255))
    return img

def moss(seed: int = 11) -> Image.Image:
    rng = random.Random(seed)
    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for i in range(90):
        x = rng.randint(6, 57)
        y = rng.randint(50, 61)
        c = rng.randint(60, 100)
        d.ellipse((x, y, x + rng.randint(2, 5), y + rng.randint(2, 4)), fill=(c, c + 40, c + 20, 255))
    for i in range(5):
        x = rng.randint(14, 50)
        d.ellipse((x, 46, x + 5, 54), fill=(70, 92, 70, 255))
    return img

fern().save(f"{OUT}/fern.png")
moss().save(f"{OUT}/moss.png")
print("done")
