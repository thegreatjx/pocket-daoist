import math
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
INK = (18, 52, 48, 255)


def radial_glow(size: int, center: tuple[float, float], radius: float, color: tuple[int, int, int], max_a: float, power: float = 2.0) -> Image.Image:
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    dist = np.sqrt((xx - center[0]) ** 2 + (yy - center[1]) ** 2)
    t = np.clip(1.0 - dist / max(1.0, radius), 0.0, 1.0) ** power
    rgba = np.zeros((size, size, 4), dtype=np.uint8)
    rgba[:, :, 0] = color[0]
    rgba[:, :, 1] = color[1]
    rgba[:, :, 2] = color[2]
    rgba[:, :, 3] = np.clip(t * max_a * 255.0, 0, 255).astype(np.uint8)
    return Image.fromarray(rgba, "RGBA")


def save_supersampled(img: Image.Image, rel_path: str, target_size: int) -> None:
    dst = os.path.join(PROJECT_ROOT, rel_path)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    out = img.resize((target_size, target_size), Image.Resampling.LANCZOS)
    out.save(dst, "PNG", optimize=True)
    print(f"Saved {rel_path} ({target_size}x{target_size})")


def make_sword_slash() -> None:
    S = 512
    yy, xx = np.mgrid[0:S, 0:S].astype(np.float32)
    # Center arc to the left so the bright crescent sweeps to the right
    cx, cy = S * 0.24, S * 0.50
    dx, dy = xx - cx, yy - cy
    r = np.sqrt(dx * dx + dy * dy)
    ang = np.arctan2(dy, dx)

    # Angular envelope: wide crescent (-1.28 .. +1.28 rad), thickest in middle
    ang_norm = np.abs(ang) / 1.32
    ang_mask = np.clip(1.0 - ang_norm ** 2.2, 0.0, 1.0)

    # Outer radius ~ 295, inner radius curves inward to taper tips sharply
    r_outer = 305.0 - 22.0 * (ang_norm ** 2)
    thickness = 112.0 * (ang_mask ** 0.85)
    r_inner = r_outer - thickness

    # Radial profile inside crescent
    u = (r - r_inner) / np.maximum(1.0, r_outer - r_inner)
    inside = (u >= 0.0) & (u <= 1.0) & (ang_mask > 0.01)

    # Brushstroke angular streaks
    streak = 0.82 + 0.18 * np.sin(ang * 14.0 + u * 8.0) * np.cos(ang * 5.0 - u * 4.0)
    alpha = np.where(inside, (np.sin(np.clip(u, 0, 1) * np.pi) ** 0.55) * (ang_mask ** 0.65) * streak, 0.0)
    # Bright leading edge near u=0.88..0.98
    edge_hi = np.where(inside, np.exp(-((u - 0.90) / 0.11) ** 2) * ang_mask, 0.0)
    gold_band = np.where(inside, np.exp(-((u - 0.72) / 0.16) ** 2) * ang_mask, 0.0)

    R = 36.0 + 215.0 * edge_hi + 205.0 * gold_band * 0.55
    G = 212.0 + 43.0 * edge_hi + 42.0 * gold_band * 0.45
    B = 192.0 + 62.0 * edge_hi - 70.0 * gold_band * 0.40

    rgba = np.zeros((S, S, 4), dtype=np.uint8)
    rgba[:, :, 0] = np.clip(R, 0, 255).astype(np.uint8)
    rgba[:, :, 1] = np.clip(G, 0, 255).astype(np.uint8)
    rgba[:, :, 2] = np.clip(B, 0, 255).astype(np.uint8)
    rgba[:, :, 3] = np.clip(alpha * 248.0, 0, 255).astype(np.uint8)

    img = Image.fromarray(rgba, "RGBA")
    glow = img.filter(ImageFilter.GaussianBlur(10))
    base = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    base = Image.alpha_composite(base, glow)
    base = Image.alpha_composite(base, img)

    # Delicate trailing jade petals & golden ink specks
    draw = ImageDraw.Draw(base)
    rng = np.random.default_rng(2026)
    for _ in range(18):
        a = rng.uniform(-1.05, 1.05)
        rr = rng.uniform(145.0, 275.0)
        px, py = cx + math.cos(a) * rr, cy + math.sin(a) * rr
        pr = rng.uniform(4.0, 9.5)
        col = (255, 224, 128, 225) if rng.random() < 0.45 else (110, 245, 220, 220)
        draw.ellipse((px - pr, py - pr * 0.65, px + pr, py + pr * 0.65), fill=col)

    save_supersampled(base, "assets/sprites/fx_sword_slash.png", 256)


def make_lotus_vfx(rel_path: str, outer_col: tuple, mid_col: tuple, core_col: tuple, glow_col: tuple, petals: int = 10) -> None:
    S = 512
    cx, cy = S / 2.0, S / 2.0
    base = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    base = Image.alpha_composite(base, radial_glow(S, (cx, cy), 245.0, glow_col, 0.42, 1.7))

    def draw_petal_ring(count: int, length: float, width: float, angle_off: float, fill_rgba: tuple, rim_rgba: tuple) -> None:
        layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        d = ImageDraw.Draw(layer)
        for i in range(count):
            ang = angle_off + i * (2.0 * math.pi / count)
            ca, sa = math.cos(ang), math.sin(ang)
            nx, ny = -sa, ca
            pts = []
            steps = 24
            for k in range(steps + 1):
                t = k / steps
                # Pointed lotus petal silhouette
                w_local = math.sin(t * math.pi) ** 0.72 * width * (1.0 - 0.18 * t)
                r_local = 26.0 + t * length
                pts.append((cx + ca * r_local + nx * w_local, cy + sa * r_local + ny * w_local))
            for k in range(steps, -1, -1):
                t = k / steps
                w_local = math.sin(t * math.pi) ** 0.72 * width * (1.0 - 0.18 * t)
                r_local = 26.0 + t * length
                pts.append((cx + ca * r_local - nx * w_local, cy + sa * r_local - ny * w_local))
            d.polygon(pts, fill=fill_rgba)
            d.line(pts + [pts[0]], fill=rim_rgba, width=4)
        nonlocal base
        base = Image.alpha_composite(base, layer.filter(ImageFilter.GaussianBlur(3)))
        base = Image.alpha_composite(base, layer)

    draw_petal_ring(petals, 205.0, 56.0, 0.0, outer_col, (*core_col[:3], 190))
    draw_petal_ring(petals, 152.0, 42.0, math.pi / petals, mid_col, (*core_col[:3], 225))
    draw_petal_ring(petals // 2 if petals >= 8 else petals, 96.0, 28.0, 0.25, core_col, (255, 252, 232, 235))

    base = Image.alpha_composite(base, radial_glow(S, (cx, cy), 92.0, core_col[:3], 0.82, 1.5))

    # Sparkle stamens
    d = ImageDraw.Draw(base)
    for i in range(16):
        ang = i * (2.0 * math.pi / 16.0)
        rr = 54.0 + (i % 2) * 14.0
        px, py = cx + math.cos(ang) * rr, cy + math.sin(ang) * rr
        d.ellipse((px - 5, py - 5, px + 5, py + 5), fill=(255, 248, 205, 235))

    save_supersampled(base, rel_path, 256)


def make_flying_sword() -> None:
    S = 512
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    img = Image.alpha_composite(img, radial_glow(S, (290, 256), 190, (70, 235, 210), 0.34, 1.8))
    d = ImageDraw.Draw(img)

    # Flowing cinnabar red silk tassel at pommel (left side)
    tassel1 = [(115, 256), (72, 234), (36, 248), (52, 266), (86, 260), (115, 262)]
    tassel2 = [(115, 258), (74, 276), (30, 290), (54, 304), (92, 284), (118, 264)]
    d.polygon(tassel1, fill=(235, 86, 60, 255), outline=INK)
    d.polygon(tassel2, fill=(214, 64, 46, 255), outline=INK)

    # Hilt & golden pommel
    d.rounded_rectangle((112, 244, 178, 268), radius=8, fill=(214, 168, 66, 255), outline=INK, width=6)
    d.ellipse((100, 238, 130, 274), fill=(248, 206, 88, 255), outline=INK, width=6)

    # Ornate cloud crossguard
    guard = [(172, 206), (196, 222), (206, 256), (196, 290), (172, 306), (164, 276), (164, 236)]
    d.polygon(guard, fill=(246, 198, 76, 255), outline=INK)
    d.line(guard + [guard[0]], fill=INK, width=6)
    d.ellipse((174, 244, 198, 268), fill=(52, 232, 204, 255), outline=INK, width=4)

    # Turquoise jade crystal double-edged blade (pointing right)
    blade_top = [(198, 230), (402, 234), (476, 256), (198, 256)]
    blade_bot = [(198, 256), (476, 256), (402, 278), (198, 282)]
    d.polygon(blade_top, fill=(102, 244, 222, 255))
    d.polygon(blade_bot, fill=(38, 196, 176, 255))
    blade_outline = [(198, 230), (402, 234), (476, 256), (402, 278), (198, 282)]
    d.line(blade_outline + [blade_outline[0]], fill=INK, width=7)
    # Bright white central ridge
    d.line([(204, 256), (464, 256)], fill=(245, 255, 252, 255), width=7)

    save_supersampled(img, "assets/sprites/fx_flying_sword.png", 128)


def make_talisman_paper() -> None:
    S = 256
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    img = Image.alpha_composite(img, radial_glow(S, (128, 128), 115, (255, 196, 72), 0.45, 1.8))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((74, 30, 182, 226), radius=10, fill=(252, 218, 96, 255), outline=INK, width=8)
    d.rounded_rectangle((86, 44, 170, 212), radius=5, outline=(220, 68, 42, 235), width=5)
    # Decorative auspicious crimson swirl rune
    pts = [(128, 66), (108, 86), (146, 108), (110, 134), (148, 158), (126, 192)]
    d.line(pts, fill=(216, 54, 36, 255), width=10, joint="curve")
    d.ellipse((116, 56, 140, 80), outline=(216, 54, 36, 255), width=6)
    save_supersampled(img, "assets/sprites/fx_talisman_paper.png", 64)


def make_celadon_jar() -> None:
    S = 512
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # Jar body (plump celadon vase)
    d.ellipse((112, 162, 400, 444), fill=(94, 198, 176, 255), outline=INK, width=12)
    # Shaded right half & bright celadon sheen left
    shade = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shade)
    sd.ellipse((128, 182, 278, 366), fill=(172, 238, 222, 155))
    sd.ellipse((152, 206, 222, 294), fill=(235, 255, 248, 175))
    img = Image.alpha_composite(img, shade.filter(ImageFilter.GaussianBlur(10)))
    d = ImageDraw.Draw(img)
    # Re-stroke jar outline cleanly
    d.ellipse((112, 162, 400, 444), outline=INK, width=12)
    # Golden lotus band around middle
    d.arc((116, 248, 396, 358), 8, 172, fill=(244, 196, 74, 255), width=16)
    for gx in (180, 256, 332):
        d.ellipse((gx - 18, 292, gx + 18, 326), fill=(250, 212, 92, 255), outline=INK, width=6)
    # Neck & flared rim
    d.rounded_rectangle((176, 108, 336, 184), radius=24, fill=(78, 180, 160, 255), outline=INK, width=10)
    d.ellipse((160, 88, 352, 146), fill=(244, 200, 84, 255), outline=INK, width=10)
    d.ellipse((188, 100, 324, 134), fill=(36, 98, 90, 255))
    # Festive red ribbon tied around neck
    d.rounded_rectangle((172, 154, 340, 184), radius=10, fill=(228, 72, 54, 255), outline=INK, width=8)
    d.polygon([(312, 174), (366, 212), (344, 232), (298, 186)], fill=(228, 72, 54, 255), outline=INK)
    d.ellipse((238, 150, 274, 188), fill=(246, 94, 68, 255), outline=INK, width=8)
    save_supersampled(img, "assets/props/celadon_jar.png", 96)


def make_pickup_peach() -> None:
    S = 256
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    img = Image.alpha_composite(img, radial_glow(S, (128, 132), 116, (255, 165, 182), 0.42, 1.8))
    d = ImageDraw.Draw(img)
    # Emerald leaves
    leaf_l = [(128, 198), (52, 182), (42, 132), (102, 148)]
    leaf_r = [(128, 198), (204, 182), (214, 132), (154, 148)]
    d.polygon(leaf_l, fill=(58, 186, 118, 255), outline=INK)
    d.line(leaf_l + [leaf_l[0]], fill=INK, width=7)
    d.polygon(leaf_r, fill=(44, 162, 106, 255), outline=INK)
    d.line(leaf_r + [leaf_r[0]], fill=INK, width=7)
    # Plump peach body (pointed top, round bottom)
    peach_pts = []
    for k in range(64):
        t = k / 64.0 * 2.0 * math.pi
        x = 128.0 + 72.0 * math.sin(t) * (1.0 + 0.14 * math.sin(t) ** 2)
        y = 132.0 - 78.0 * math.cos(t) - 18.0 * (max(0.0, math.cos(t)) ** 3)
        peach_pts.append((x, y))
    d.polygon(peach_pts, fill=(255, 152, 158, 255))
    # Warm golden blush lower body
    blush = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    bd = ImageDraw.Draw(blush)
    bd.ellipse((74, 106, 182, 206), fill=(255, 224, 156, 195))
    bd.ellipse((86, 78, 136, 134), fill=(255, 246, 236, 165))
    img = Image.alpha_composite(img, blush.filter(ImageFilter.GaussianBlur(8)))
    d = ImageDraw.Draw(img)
    d.line(peach_pts + [peach_pts[0]], fill=INK, width=8)
    save_supersampled(img, "assets/sprites/pickup_peach.png", 64)


def make_pickup_magnet() -> None:
    S = 256
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    img = Image.alpha_composite(img, radial_glow(S, (128, 128), 118, (64, 232, 212), 0.45, 1.8))
    d = ImageDraw.Draw(img)
    # Outer golden octagonal-round spirit compass
    d.ellipse((34, 34, 222, 222), fill=(242, 194, 72, 255), outline=INK, width=9)
    d.ellipse((54, 54, 202, 202), fill=(34, 114, 108, 255), outline=INK, width=6)
    # Compass notches
    for i in range(8):
        ang = i * math.pi / 4.0
        x0, y0 = 128 + math.cos(ang) * 76, 128 + math.sin(ang) * 76
        x1, y1 = 128 + math.cos(ang) * 90, 128 + math.sin(ang) * 90
        d.line([(x0, y0), (x1, y1)], fill=INK, width=5)
    # Glowing turquoise crystal needle & core
    d.polygon([(128, 66), (144, 128), (128, 190), (112, 128)], fill=(116, 252, 236, 255), outline=INK)
    d.ellipse((100, 100, 156, 156), fill=(68, 238, 216, 255), outline=INK, width=6)
    d.ellipse((114, 114, 142, 142), fill=(242, 255, 252, 255))
    save_supersampled(img, "assets/sprites/pickup_magnet.png", 64)


def make_pickup_qiankun_bag() -> None:
    S = 256
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    img = Image.alpha_composite(img, radial_glow(S, (128, 138), 120, (255, 198, 74), 0.50, 1.7))
    d = ImageDraw.Draw(img)
    pouch = []
    for k in range(72):
        t = k / 72.0 * 2.0 * math.pi
        x = 128.0 + 78.0 * math.sin(t) * (1.0 + 0.10 * max(0.0, math.cos(t * 2.0)))
        y = 150.0 + 70.0 * math.cos(t) - 16.0 * math.exp(-((t - math.pi) ** 2) * 2.0)
        pouch.append((x, y))
    d.polygon(pouch, fill=(196, 54, 58, 255))
    shade = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shade)
    sd.ellipse((84, 122, 152, 214), fill=(252, 148, 108, 150))
    sd.ellipse((96, 132, 132, 176), fill=(255, 232, 198, 130))
    img = Image.alpha_composite(img, shade.filter(ImageFilter.GaussianBlur(8)))
    d = ImageDraw.Draw(img)
    d.line(pouch + [pouch[0]], fill=INK, width=8)
    d.arc((64, 168, 198, 240), 8, 172, fill=(228, 168, 62, 255), width=12)
    for cx, cy in ((88, 204), (128, 214), (168, 204)):
        d.ellipse((cx - 12, cy - 8, cx + 12, cy + 8), fill=(250, 208, 92, 255), outline=INK, width=4)
    d.rounded_rectangle((86, 92, 170, 134), radius=16, fill=(52, 168, 150, 255), outline=INK, width=7)
    d.ellipse((74, 74, 182, 122), fill=(228, 168, 62, 255), outline=INK, width=7)
    d.ellipse((92, 84, 164, 112), fill=(36, 92, 84, 255))
    gem = [(128, 42), (156, 80), (128, 112), (100, 80)]
    d.polygon(gem, fill=(96, 246, 220, 255), outline=INK)
    d.polygon([(128, 42), (156, 80), (128, 80)], fill=(196, 255, 244, 255))
    d.line(gem + [gem[0]], fill=INK, width=6)
    d.line([(96, 110), (84, 146)], fill=(236, 180, 70, 255), width=9)
    d.line([(160, 110), (178, 146)], fill=(236, 180, 70, 255), width=9)
    d.ellipse((82, 128, 122, 160), fill=(246, 200, 88, 255), outline=INK, width=5)
    save_supersampled(img, "assets/sprites/pickup_qiankun_bag.png", 64)


def make_pickup_taixu_talisman() -> None:
    S = 256
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    img = Image.alpha_composite(img, radial_glow(S, (128, 128), 120, (118, 226, 240), 0.48, 1.7))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((62, 24, 194, 232), radius=12, fill=(238, 250, 242, 255), outline=INK, width=9)
    d.rounded_rectangle((76, 38, 180, 218), radius=6, outline=(226, 172, 66, 255), width=7)
    d.rounded_rectangle((88, 50, 168, 206), radius=4, fill=(202, 244, 246, 255), outline=(92, 196, 214, 255), width=4)
    d.ellipse((92, 74, 164, 146), outline=(36, 150, 168, 255), width=8)
    d.arc((92, 74, 164, 146), 20, 200, fill=(242, 190, 78, 255), width=6)
    d.line([(128, 58), (128, 162)], fill=(30, 126, 148, 255), width=8)
    d.line([(128, 162), (108, 140)], fill=(30, 126, 148, 255), width=7)
    d.line([(128, 162), (148, 140)], fill=(30, 126, 148, 255), width=7)
    d.ellipse((116, 156, 140, 180), fill=(246, 200, 88, 255), outline=INK, width=4)
    d.polygon([(128, 18), (142, 44), (128, 62), (114, 44)], fill=(106, 238, 232, 255), outline=INK)
    d.line([(128, 18), (142, 44), (128, 62), (114, 44), (128, 18)], fill=INK, width=5)
    d.line([(128, 30), (128, 50)], fill=(246, 255, 255, 255), width=4)
    for cx, cy in ((96, 184), (160, 184)):
        d.line([(cx, cy - 12), (cx, cy + 12)], fill=(32, 128, 148, 255), width=6)
        d.line([(cx - 8, cy - 4), (cx + 8, cy + 4)], fill=(32, 128, 148, 255), width=5)
    save_supersampled(img, "assets/sprites/pickup_taixu_talisman.png", 64)


def make_exp_gem() -> None:
    S = 192
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    img = Image.alpha_composite(img, radial_glow(S, (96, 96), 88, (72, 240, 198), 0.52, 1.7))
    d = ImageDraw.Draw(img)
    diamond = [(96, 26), (150, 96), (96, 166), (42, 96)]
    d.polygon(diamond, fill=(64, 226, 184, 255), outline=INK)
    d.polygon([(96, 26), (150, 96), (96, 96)], fill=(156, 252, 228, 255))
    d.polygon([(96, 26), (42, 96), (96, 96)], fill=(110, 242, 210, 255))
    d.line(diamond + [diamond[0]], fill=INK, width=7)
    d.ellipse((80, 62, 104, 86), fill=(252, 255, 252, 240))
    save_supersampled(img, "assets/sprites/exp_gem_jade.png", 48)


def main() -> None:
    make_sword_slash()
    make_lotus_vfx(
        "assets/sprites/fx_fire_lotus.png",
        outer_col=(236, 78, 44, 215),
        mid_col=(252, 148, 52, 230),
        core_col=(255, 226, 118, 245),
        glow_col=(255, 112, 48),
        petals=10,
    )
    make_lotus_vfx(
        "assets/sprites/fx_jade_lotus_aura.png",
        outer_col=(36, 198, 174, 155),
        mid_col=(104, 238, 216, 175),
        core_col=(232, 255, 242, 210),
        glow_col=(52, 224, 196),
        petals=12,
    )
    make_flying_sword()
    make_talisman_paper()
    make_celadon_jar()
    make_pickup_peach()
    make_pickup_magnet()
    make_exp_gem()


if __name__ == "__main__":
    main()
