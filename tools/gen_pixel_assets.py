#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""《百宝小道修 (Pocket Daoist)》像素美术素材程序化生成脚本。

全部素材用 Pillow 逐像素绘制（无抗锯齿、硬边），固定随机种子，重复运行结果一致。

用法:
    python tools/gen_pixel_assets.py                 # 输出到项目根目录下的 assets/
    python tools/gen_pixel_assets.py --out D:/x      # 输出到 D:/x/assets/
    python tools/gen_pixel_assets.py --seed 12345    # 换一批随机细节

风格约定: 东方修仙暗黑风，深色描边，每张图 6~10 色，透明背景（瓦片除外），
边缘带一点发光色（青蓝/血红/惨绿随类型变化）。
"""

import argparse
import math
import sys
import os
import random

from PIL import Image, ImageDraw

# ---------------------------------------------------------------- 基础工具

OUTLINE = (8, 6, 12, 255)          # 通用深色描边
INK = (14, 11, 20, 255)


def canvas(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def drect(img, x0, y0, x1, y1, color):
    x0, x1 = min(x0, x1), max(x0, x1)
    y0, y1 = min(y0, y1), max(y0, y1)
    ImageDraw.Draw(img).rectangle([x0, y0, x1, y1], fill=color)


def dellipse(img, x0, y0, x1, y1, color):
    x0, x1 = min(x0, x1), max(x0, x1)
    y0, y1 = min(y0, y1), max(y0, y1)
    ImageDraw.Draw(img).ellipse([x0, y0, x1, y1], fill=color)


def dpoly(img, pts, color):
    ImageDraw.Draw(img).polygon(pts, fill=color)


def dline(img, pts, color, width=1):
    ImageDraw.Draw(img).line(list(pts), fill=color, width=width, joint="curve")


def darc(img, x0, y0, x1, y1, start, end, color, width=1):
    x0, x1 = min(x0, x1), max(x0, x1)
    y0, y1 = min(y0, y1), max(y0, y1)
    ImageDraw.Draw(img).arc([x0, y0, x1, y1], start, end, fill=color, width=width)


def outline_silhouette(img, color=OUTLINE, diagonal=False):
    """在透明区域沿不透明像素外扩一圈描边（保持硬边，不做模糊）。"""
    out = img.copy()
    src = img.load()
    dst = out.load()
    w, h = img.size
    near = [(-1, 0), (1, 0), (0, -1), (0, 1)]
    if diagonal:
        near += [(-1, -1), (1, -1), (-1, 1), (1, 1)]
    for y in range(h):
        for x in range(w):
            if src[x, y][3] != 0:
                continue
            for dx, dy in near:
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and src[nx, ny][3] > 0:
                    dst[x, y] = color
                    break
    return out


def paste_outlined(base, layer, color=OUTLINE, diagonal=False):
    """把 layer 贴到 base 上，先画描边再画本体。"""
    base.paste(outline_silhouette(layer, color, diagonal), (0, 0))
    base.paste(layer, (0, 0))


def limit_palette(img, max_colors):
    """保留出现最多的 max_colors 个颜色，其余映射到最近的保留色，限制色阶数量。"""
    px = img.load()
    w, h = img.size
    counts = {}
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a:
                counts[(r, g, b)] = counts.get((r, g, b), 0) + 1
    if len(counts) <= max_colors:
        return img
    keep = [c for c, _ in sorted(counts.items(), key=lambda kv: -kv[1])[:max_colors]]
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if not a:
                continue
            key = (r, g, b)
            if key in keep:
                continue
            best = min(keep, key=lambda c: (r - c[0]) ** 2 + (g - c[1]) ** 2 + (b - c[2]) ** 2)
            px[x, y] = (best[0], best[1], best[2], a)
    return img


def quantize(img, palette):
    """把图像 RGB 量化到给定调色板（alpha 保留），保证色数受控。"""
    px = img.load()
    w, h = img.size
    pal = list(palette)
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            best = min(pal, key=lambda c: (r - c[0]) ** 2 + (g - c[1]) ** 2 + (b - c[2]) ** 2)
            px[x, y] = (best[0], best[1], best[2], a)
    return img


def wrapped_draw(img, size, fn):
    """在环面上作画：同一形状以 ±size 偏移各画一次，跨边部分自然接续。"""
    for dx in (-size, 0, size):
        for dy in (-size, 0, size):
            fn(dx, dy)


# ---------------------------------------------------------------- 无缝噪声

def _fade(t):
    return t * t * (3.0 - 2.0 * t)


def _lerp(a, b, t):
    return a + (b - a) * t


def value_noise(w, h, period, rng):
    """周期性 value noise：格点取模回绕，保证 w/h 为 period 整数倍时严格可平铺。"""
    lat = [[rng.random() for _ in range(period)] for _ in range(period)]
    out = [[0.0] * w for _ in range(h)]
    for y in range(h):
        fy = y * period / h
        iy = int(fy) % period
        jy = (iy + 1) % period
        ty = _fade(fy - int(fy))
        row0 = lat[iy]
        row1 = lat[jy]
        for x in range(w):
            fx = x * period / w
            ix = int(fx) % period
            jx = (ix + 1) % period
            tx = _fade(fx - int(fx))
            v = _lerp(_lerp(row0[ix], row0[jx], tx), _lerp(row1[ix], row1[jx], tx), ty)
            out[y][x] = v
    return out


def fbm(w, h, rng, periods=(4, 8, 16, 32), weights=(0.45, 0.28, 0.17, 0.10), contrast=1.5):
    field = [[0.0] * w for _ in range(h)]
    for period, weight in zip(periods, weights):
        layer = value_noise(w, h, period, rng)
        for y in range(h):
            for x in range(w):
                field[y][x] += layer[y][x] * weight
    for y in range(h):
        for x in range(w):
            v = (field[y][x] - 0.5) * contrast + 0.5
            field[y][x] = 0.0 if v < 0.0 else (1.0 if v > 1.0 else v)
    return field


def paint_field(img, field, ramp):
    px = img.load()
    w, h = img.size
    n = len(ramp)
    for y in range(h):
        for x in range(w):
            i = int(field[y][x] * n)
            if i >= n:
                i = n - 1
            px[x, y] = ramp[i]


def rand_blob_positions(rng, size, count, rmin, rmax):
    return [(rng.randrange(size), rng.randrange(size), rng.randint(rmin, rmax)) for _ in range(count)]


# ---------------------------------------------------------------- 地面瓦片

TILE_SIZE = 64

# 青冥林：墨绿草地 + 碎石 + 苔痕
FOREST_RAMP = [(16, 28, 22, 255), (22, 40, 28, 255), (28, 52, 34, 255), (34, 64, 42, 255)]
FOREST_STONE = [(70, 76, 80, 255), (48, 54, 58, 255)]
FOREST_MOSS = [(58, 112, 62, 255), (40, 76, 46, 255)]


def tile_forest(img, rng):
    field = fbm(*img.size, rng, contrast=1.4)
    paint_field(img, field, FOREST_RAMP)
    for cx, cy, r in rand_blob_positions(rng, 64, 8, 2, 4):
        def f(dx, dy, cx=cx, cy=cy, r=r):
            dellipse(img, cx + dx - r, cy + dy - r, cx + dx + r, cy + dy + r, FOREST_STONE[1])
            dellipse(img, cx + dx - r + 1, cy + dy - r + 1, cx + dx + r - 1, cy + dy - r, FOREST_STONE[0])
        wrapped_draw(img, 64, f)
    for cx, cy, r in rand_blob_positions(rng, 64, 7, 2, 5):
        def f(dx, dy, cx=cx, cy=cy, r=r):
            dellipse(img, cx + dx - r, cy + dy - r, cx + dx + r, cy + dy + r, FOREST_MOSS[1])
            dellipse(img, cx + dx - r + 1, cy + dy - r + 1, cx + dx + r - 1, cy + dy - r, FOREST_MOSS[0])
        wrapped_draw(img, 64, f)
    return img


# 赤砂荒原：沙黄 + 暗红裂纹
DESERT_RAMP = [(84, 58, 34, 255), (124, 92, 52, 255), (158, 122, 70, 255), (192, 154, 94, 255)]
DESERT_CRACK = [(92, 20, 24, 255), (54, 11, 15, 255)]
DESERT_SPEK = [(214, 180, 122, 255)]


def tile_desert(img, rng):
    field = fbm(*img.size, rng, contrast=1.2)
    paint_field(img, field, DESERT_RAMP)
    for _ in range(3):
        x = rng.randrange(64)
        y = rng.randrange(64)
        pts = [(x, y)]
        for _ in range(rng.randint(6, 9)):
            x += rng.choice((-3, -2, 2, 3, 0))
            y += rng.choice((-2, -1, 1, 2, 3))
            pts.append((x, y))
        for width, color in ((2, DESERT_CRACK[1]), (1, DESERT_CRACK[0])):
            def f(dx, dy, pts=pts, color=color, width=width):
                dline(img, [(px + dx, py + dy) for px, py in pts], color, width)
            wrapped_draw(img, 64, f)
    for _ in range(22):
        cx, cy = rng.randrange(64), rng.randrange(64)
        drect(img, cx, cy, cx + 1, cy + 1, DESERT_SPEK[0])
    return img


GHOST_RAMP = [(26, 22, 38, 255), (34, 28, 48, 255), (44, 36, 60, 255), (56, 46, 74, 255)]
GHOST_GROUT = [(16, 13, 26, 255)]
GHOST_RUNE = [(79, 216, 224, 255), (42, 140, 156, 255)]


def tile_ghosttown(img, rng):
    field = fbm(*img.size, rng, contrast=0.9)
    paint_field(img, field, GHOST_RAMP)
    for gx in (8, 24, 40, 56):
        dline(img, [(gx, 0), (gx, 63)], GHOST_GROUT[0], 1)
    for gy in (8, 24, 40, 56):
        dline(img, [(0, gy), (63, gy)], GHOST_GROUT[0], 1)
    # 符文刻印：菱形套点
    for gx in (8, 24, 40, 56):
        for gy in (8, 24, 40, 56):
            if rng.random() < 0.55:
                ox = gx + rng.randrange(1, 7)
                oy = gy + rng.randrange(1, 7)
                drect(img, ox, oy - 2, ox + 2, oy + 2, GHOST_RUNE[1])
                drect(img, ox + 1, oy - 1, ox + 1, oy + 1, GHOST_RUNE[0])
    # 鬼市幽渍
    for cx, cy, r in rand_blob_positions(rng, 64, 5, 2, 4):
        def f(dx, dy, cx=cx, cy=cy, r=r):
            dellipse(img, cx + dx - r, cy + dy - r, cx + dx + r, cy + dy + r, GHOST_RUNE[1])
            dellipse(img, cx + dx - r + 1, cy + dy - r + 1, cx + dx + r - 1, cy + dy + r - 1, GHOST_RUNE[0])
        wrapped_draw(img, 64, f)
    return img


BONE_RAMP = [(44, 42, 36, 255), (58, 55, 46, 255), (72, 68, 57, 255), (88, 83, 70, 255)]
BONE_SHARD = [(198, 190, 162, 255), (146, 140, 118, 255)]
BONE_DIRT = [(26, 24, 20, 255)]


def tile_bonefield(img, rng):
    field = fbm(*img.size, rng, contrast=1.1)
    paint_field(img, field, BONE_RAMP)
    for _ in range(16):
        cx, cy = rng.randrange(64), rng.randrange(64)
        long_x = rng.random() < 0.5
        ln = rng.randint(4, 9)
        th = rng.randint(1, 2)
        def f(dx, dy, cx=cx, cy=cy, ln=ln, th=th, long_x=long_x):
            if long_x:
                drect(img, cx + dx - ln // 2, cy + dy - th, cx + dx + ln // 2, cy + dy + th, BONE_SHARD[1])
                drect(img, cx + dx - ln // 2, cy + dy - th, cx + dx + ln // 2 - 1, cy + dy, BONE_SHARD[0])
            else:
                drect(img, cx + dx - th, cy + dy - ln // 2, cx + dx + th, cy + dy + ln // 2, BONE_SHARD[1])
                drect(img, cx + dx - th, cy + dy - ln // 2, cx + dx + th - 1, cy + dy + ln // 2, BONE_SHARD[0])
        wrapped_draw(img, 64, f)
    for _ in range(30):
        cx, cy = rng.randrange(64), rng.randrange(64)
        drect(img, cx, cy, cx + 1, cy, BONE_DIRT[0])
    return img


# 玄冥祭坛：黑金祭纹地砖
ALTAR_RAMP = [(15, 11, 19, 255), (23, 17, 29, 255), (32, 24, 38, 255)]
ALTAR_GOLD = [(198, 158, 74, 255), (132, 100, 38, 255)]
ALTAR_RUNE = [(150, 104, 224, 255)]


def tile_altar(img, rng):
    field = fbm(*img.size, rng, contrast=0.7)
    paint_field(img, field, ALTAR_RAMP)
    for g in (8, 24, 40, 56):
        dline(img, [(g, 0), (g, 63)], ALTAR_GOLD[1], 1)
        dline(img, [(0, g), (63, g)], ALTAR_GOLD[1], 1)
    for cx, cy in ((16, 16), (48, 16), (16, 48), (48, 48)):
        dpoly(img, [(cx, cy - 4), (cx + 4, cy), (cx, cy + 4), (cx - 4, cy)], ALTAR_GOLD[0])
        drect(img, cx - 1, cy - 1, cx + 1, cy + 1, ALTAR_RUNE[0])
    for _ in range(10):
        cx, cy = rng.randrange(64), rng.randrange(64)
        drect(img, cx, cy, cx + 1, cy + 1, ALTAR_GOLD[0])
    return img


# 大荒妖巢：紫黑兽血地面
LAIR_RAMP = [(18, 11, 24, 255), (28, 17, 36, 255), (38, 24, 48, 255)]
LAIR_BLOOD = [(92, 20, 34, 255), (56, 12, 22, 255)]
LAIR_CLAW = [(150, 52, 66, 255)]


def tile_lair(img, rng):
    field = fbm(*img.size, rng, contrast=1.3)
    paint_field(img, field, LAIR_RAMP)
    for cx, cy, r in rand_blob_positions(rng, 64, 6, 3, 7):
        def f(dx, dy, cx=cx, cy=cy, r=r):
            dellipse(img, cx + dx - r, cy + dy - r, cx + dx + r, cy + dy + r, LAIR_BLOOD[1])
            dellipse(img, cx + dx - r + 1, cy + dy - r + 1, cx + dx + r - 2, cy + dy + r - 2, LAIR_BLOOD[0])
        wrapped_draw(img, 64, f)
    for _ in range(3):
        cx, cy = rng.randrange(64), rng.randrange(64)
        for k in range(3):
            def f(dx, dy, cx=cx, cy=cy, k=k):
                dline(img, [(cx + dx + k * 4, cy + dy), (cx + dx + k * 4 + 3, cy + dy + 8)], LAIR_CLAW[0], 1)
            wrapped_draw(img, 64, f)
    return img


TILES = [
    ("tile_forest.png", tile_forest, FOREST_RAMP + FOREST_STONE + FOREST_MOSS),
    ("tile_desert.png", tile_desert, DESERT_RAMP + DESERT_CRACK + DESERT_SPEK),
    ("tile_ghosttown.png", tile_ghosttown, GHOST_RAMP + GHOST_GROUT + GHOST_RUNE),
    ("tile_bonefield.png", tile_bonefield, BONE_RAMP + BONE_SHARD + BONE_DIRT),
    ("tile_altar.png", tile_altar, ALTAR_RAMP + ALTAR_GOLD + ALTAR_RUNE),
    ("tile_lair.png", tile_lair, LAIR_RAMP + LAIR_BLOOD + LAIR_CLAW),
]


# ---------------------------------------------------------------- 场景道具

def prop_pine(rng):
    img = canvas(64, 64)
    layer = canvas(64, 64)
    drect(layer, 29, 32, 34, 60, (58, 42, 28, 255))
    drect(layer, 29, 32, 31, 60, (80, 58, 38, 255))
    tiers = [(32, 6, 11, 20), (32, 15, 16, 29), (32, 24, 21, 39)]
    for cx, top, halfw, bot in tiers:
        dpoly(layer, [(cx, top), (cx - halfw, bot), (cx + halfw, bot)], (16, 40, 28, 255))
        dpoly(layer, [(cx, top), (cx, bot), (cx + halfw, bot)], (11, 30, 23, 255))
        dpoly(layer, [(cx, top), (cx - halfw + 3, bot - 2), (cx - 2, bot - 2)], (26, 58, 38, 255))
    dpoly(layer, [(32, 1), (36, 10), (28, 10)], (20, 48, 32, 255))
    dline(layer, [(32, 6), (24, 19)], (58, 118, 126, 255), 1)
    dline(layer, [(32, 15), (19, 28)], (44, 92, 104, 255), 1)
    dline(layer, [(32, 24), (14, 38)], (36, 74, 88, 255), 1)
    paste_outlined(img, layer, OUTLINE)
    return img


def prop_lantern(rng):
    img = canvas(48, 64)
    glow = canvas(48, 64)
    drect(glow, 12, 14, 35, 49, (220, 90, 70, 46))
    drect(glow, 16, 18, 31, 45, (235, 120, 80, 54))
    img.paste(glow, (0, 0))
    layer = canvas(48, 64)
    drect(layer, 23, 0, 25, 13, (78, 66, 46, 255))
    drect(layer, 23, 0, 24, 13, (104, 88, 58, 255))
    dpoly(layer, [(15, 16), (32, 16), (29, 12), (18, 12)], (120, 96, 48, 255))
    drect(layer, 14, 16, 33, 20, (150, 120, 60, 255))
    drect(layer, 13, 20, 34, 44, (138, 28, 32, 255))
    drect(layer, 17, 21, 23, 43, (186, 52, 46, 255))
    drect(layer, 17, 21, 19, 43, (214, 78, 62, 255))
    for y in (24, 32, 40):
        drect(layer, 14, y, 33, y, (104, 20, 26, 255))
    drect(layer, 17, 44, 30, 48, (140, 112, 54, 255))
    drect(layer, 22, 48, 25, 58, (150, 32, 36, 255))
    drect(layer, 22, 48, 23, 58, (196, 56, 50, 255))
    paste_outlined(img, layer, OUTLINE)
    return img


def prop_stele(rng):
    img = canvas(64, 64)
    layer = canvas(64, 64)
    dpoly(layer, [(18, 14), (45, 14), (43, 58), (20, 58)], (48, 54, 64, 255))
    dpoly(layer, [(18, 14), (30, 14), (30, 58), (20, 58)], (62, 70, 82, 255))
    drect(layer, 15, 58, 48, 62, (38, 44, 54, 255))
    drect(layer, 14, 11, 49, 15, (70, 78, 90, 255))
    # 刻痕与青光符文
    for i in range(4):
        y = 22 + i * 9
        drect(layer, 26, y, 37, y, (22, 68, 80, 255))
        drect(layer, 31, y + 1, 32, y + 5, (22, 68, 80, 255))
        drect(layer, 28, y + 5, 35, y + 5, (86, 210, 220, 255))
    dline(layer, [(24, 18), (24, 52)], (30, 40, 52, 255), 1)
    paste_outlined(img, layer, OUTLINE)
    return img


def prop_chest(rng):
    img = canvas(48, 48)
    glow = canvas(48, 48)
    drect(glow, 8, 14, 39, 38, (70, 210, 190, 40))
    img.paste(glow, (0, 0))
    layer = canvas(48, 48)
    drect(layer, 8, 22, 39, 38, (70, 42, 28, 255))
    drect(layer, 10, 24, 37, 36, (96, 58, 34, 255))
    dpoly(layer, [(7, 22), (10, 14), (37, 14), (40, 22)], (58, 34, 24, 255))
    drect(layer, 9, 15, 38, 18, (92, 56, 32, 255))
    drect(layer, 6, 21, 41, 24, (146, 112, 54, 255))
    drect(layer, 6, 21, 41, 22, (190, 150, 78, 255))
    drect(layer, 20, 14, 27, 40, (146, 112, 54, 255))
    drect(layer, 21, 14, 26, 22, (190, 150, 78, 255))
    drect(layer, 21, 22, 26, 31, (206, 168, 84, 255))
    drect(layer, 22, 25, 25, 27, (30, 22, 16, 255))
    drect(layer, 8, 36, 39, 39, (44, 26, 18, 255))
    # 灵气缝隙
    drect(layer, 10, 39, 37, 40, (70, 210, 190, 255))
    paste_outlined(img, layer, OUTLINE)
    return img


def prop_altar_torch(rng):
    img = canvas(48, 64)
    glow = canvas(48, 64)
    dellipse(glow, 8, 6, 39, 38, (255, 150, 60, 42))
    dellipse(glow, 13, 11, 34, 33, (255, 190, 100, 46))
    img.paste(glow, (0, 0))
    layer = canvas(48, 64)
    drect(layer, 21, 36, 26, 56, (58, 50, 44, 255))
    drect(layer, 21, 36, 23, 56, (82, 72, 62, 255))
    dpoly(layer, [(14, 56), (33, 56), (29, 62), (18, 62)], (44, 38, 34, 255))
    dpoly(layer, [(10, 28), (37, 28), (33, 40), (14, 40)], (66, 56, 46, 255))
    drect(layer, 9, 26, 38, 30, (96, 82, 66, 255))
    drect(layer, 9, 26, 38, 27, (128, 110, 88, 255))
    # 火焰
    dpoly(layer, [(23, 8), (31, 20), (34, 28), (13, 28), (16, 20)], (176, 56, 32, 255))
    dpoly(layer, [(23, 14), (28, 22), (30, 28), (16, 28), (19, 22)], (236, 132, 44, 255))
    dpoly(layer, [(23, 19), (26, 24), (27, 28), (19, 28), (21, 24)], (252, 226, 160, 255))
    paste_outlined(img, layer, OUTLINE)
    return img


def prop_vine(rng):
    img = canvas(64, 64)
    layer = canvas(64, 64)
    pts = []
    for i in range(11):
        y = 1 + i * 6
        x = 32 + (13 if i % 2 == 0 else -13) + rng.randint(-2, 2)
        pts.append((x, y))
    dline(layer, pts, (16, 44, 28, 255), 5)
    dline(layer, pts, (26, 68, 40, 255), 3)
    for i, (x, y) in enumerate(pts):
        if i % 2:
            continue
        dpoly(layer, [(x - 1, y), (x - 10, y - 7), (x - 1, y - 8)], (20, 56, 34, 255))
        dpoly(layer, [(x + 1, y), (x + 10, y - 6), (x + 1, y - 9)], (30, 78, 44, 255))
        dpoly(layer, [(x + 1, y - 1), (x + 8, y - 6), (x + 2, y - 7)], (44, 112, 56, 255))
        dpoly(layer, [(x - 6, y - 5), (x - 1, y - 2), (x - 3, y - 7)], (54, 134, 66, 255))
    for x, y in pts[1::3]:
        dpoly(layer, [(x, y), (x + 3, y - 5), (x + 5, y - 1)], (122, 152, 92, 255))
    paste_outlined(img, layer, OUTLINE)
    return img


def prop_bone_pile(rng):
    img = canvas(64, 48)
    layer = canvas(64, 48)
    dellipse(layer, 12, 38, 52, 46, (46, 42, 34, 255))
    # 头骨
    dellipse(layer, 21, 8, 39, 26, (188, 180, 154, 255))
    dellipse(layer, 23, 10, 37, 20, (214, 206, 180, 255))
    drect(layer, 26, 15, 29, 18, (24, 20, 16, 255))
    drect(layer, 32, 15, 35, 18, (24, 20, 16, 255))
    drect(layer, 28, 21, 32, 22, (120, 112, 92, 255))
    drect(layer, 27, 24, 32, 25, (150, 142, 118, 255))
    # 肋骨
    for i in range(5):
        x = 6 + i * 12
        y = 30 + (i % 2) * 3
        dline(layer, [(x, y), (x + 9, y - 4)], (146, 138, 116, 255), 4)
        dline(layer, [(x, y - 1), (x + 8, y - 5)], (198, 190, 162, 255), 2)
        drect(layer, x - 1, y - 2, x + 1, y + 1, (198, 190, 162, 255))
        drect(layer, x + 8, y - 6, x + 10, y - 3, (198, 190, 162, 255))
    # 长骨
    dline(layer, [(10, 40), (30, 34)], (176, 168, 142, 255), 3)
    dline(layer, [(10, 39), (29, 33)], (214, 206, 180, 255), 1)
    dline(layer, [(36, 41), (54, 35)], (176, 168, 142, 255), 3)
    dline(layer, [(36, 40), (53, 34)], (214, 206, 180, 255), 1)
    paste_outlined(img, layer, OUTLINE)
    return img


def prop_rune_stone(rng):
    img = canvas(48, 48)
    glow = canvas(48, 48)
    dellipse(glow, 6, 8, 41, 43, (110, 226, 214, 38))
    img.paste(glow, (0, 0))
    layer = canvas(48, 48)
    dpoly(layer, [(10, 40), (13, 14), (21, 9), (30, 11), (37, 16), (39, 40)], (58, 54, 66, 255))
    dpoly(layer, [(13, 14), (21, 9), (26, 11), (18, 38), (10, 40)], (76, 72, 88, 255))
    dpoly(layer, [(10, 40), (39, 40), (37, 44), (12, 44)], (40, 37, 48, 255))
    # 符文
    drect(layer, 21, 16, 22, 34, (86, 220, 208, 255))
    drect(layer, 22, 22, 31, 23, (86, 220, 208, 255))
    drect(layer, 22, 28, 29, 29, (56, 158, 156, 255))
    drect(layer, 26, 16, 27, 34, (140, 246, 232, 255))
    paste_outlined(img, layer, OUTLINE)
    return img


PROPS = [
    ("pine.png", prop_pine),
    ("lantern.png", prop_lantern),
    ("stele.png", prop_stele),
    ("chest.png", prop_chest),
    ("altar_torch.png", prop_altar_torch),
    ("vine.png", prop_vine),
    ("bone_pile.png", prop_bone_pile),
    ("rune_stone.png", prop_rune_stone),
]


# ---------------------------------------------------------------- 图标

ICON_BG_OUTER = (16, 13, 24, 255)
ICON_BG_EDGE = (10, 8, 17, 255)
ICON_BG_INNER = (30, 24, 44, 255)
ICON_BG_DEEP = (23, 18, 34, 255)
ICON_RIM = (62, 50, 86, 255)
ICON_RIM_HOT = (104, 84, 138, 255)


def icon_base(size=48):
    """圆形深色底：外圈 -> 内盘 -> 底部内阴影 -> 上缘高光，保持硬边。"""
    img = canvas(size, size)
    dellipse(img, 1, 1, size - 2, size - 2, ICON_BG_EDGE)
    dellipse(img, 2, 2, size - 3, size - 3, ICON_BG_OUTER)
    dellipse(img, 4, 4, size - 5, size - 5, ICON_BG_INNER)
    dellipse(img, 7, 26, size - 8, size - 7, ICON_BG_DEEP)
    darc(img, 3, 3, size - 4, size - 4, 190, 350, ICON_RIM, 1)
    darc(img, 4, 4, size - 5, size - 5, 200, 300, ICON_RIM_HOT, 1)
    darc(img, 5, 5, size - 6, size - 6, 20, 110, ICON_RIM, 1)
    return img


def draw_icon(img, fn):
    layer = canvas(img.size[0], img.size[1])
    fn(layer)
    paste_outlined(img, layer, (10, 8, 16, 255))
    # 底部一圈淡幽辉，让所有图标共享同一套背景质感
    glow = canvas(img.size[0], img.size[1])
    dellipse(glow, 11, 28, img.size[0] - 12, img.size[1] - 12, (30, 70, 88, 58))
    img.paste(glow, (0, 0), glow)
    return img


CYAN = (72, 210, 226, 255)
CYAN_DIM = (36, 122, 146, 255)
CYAN_HOT = (168, 244, 250, 255)
GOLD = (216, 168, 72, 255)
GOLD_HOT = (246, 214, 132, 255)
RED = (198, 58, 52, 255)
RED_DIM = (118, 26, 30, 255)
GREEN = (150, 200, 92, 255)
GREEN_DIM = (78, 112, 48, 255)
BONE_C = (206, 200, 176, 255)
BONE_D = (128, 122, 102, 255)
STEEL = (168, 178, 196, 255)
STEEL_D = (94, 102, 118, 255)
VIOLET = (166, 116, 226, 255)
VIOLET_DIM = (92, 58, 140, 255)
EMBER = (246, 148, 52, 255)
EMBER_HOT = (252, 226, 150, 255)


def sym_qingzhu(layer):
    dpoly(layer, [(24, 4), (27, 8), (27, 26), (21, 26), (21, 8)], STEEL)
    dpoly(layer, [(24, 4), (26, 9), (26, 26), (24, 26)], CYAN)
    dpoly(layer, [(24, 6), (24, 24)], CYAN_HOT)
    drect(layer, 17, 26, 31, 29, GOLD)
    drect(layer, 18, 27, 30, 28, GOLD_HOT)
    drect(layer, 22, 29, 26, 36, (92, 46, 30, 255))
    drect(layer, 22, 29, 23, 36, (140, 74, 46, 255))
    drect(layer, 21, 36, 27, 39, GOLD)


def sym_taichi(layer):
    darc(layer, 6, 6, 41, 41, 0, 360, CYAN_DIM, 2)
    darc(layer, 10, 10, 37, 37, 0, 360, CYAN, 1)
    for k in range(6):
        a = k * 60
        cx = 24 + 15 * math.cos(math.radians(a))
        cy = 24 + 15 * math.sin(math.radians(a))
        dpoly(layer, [(cx, cy - 6), (cx + 2, cy - 3), (cx + 2, cy + 2), (cx - 2, cy + 2), (cx - 2, cy - 3)], STEEL)
        drect(layer, cx - 1, cy - 6, cx + 1, cy - 4, CYAN_HOT)
    dellipse(layer, 18, 18, 29, 29, CYAN_DIM)
    dellipse(layer, 20, 20, 27, 27, CYAN)
    drect(layer, 23, 21, 25, 26, CYAN_HOT)


def sym_jiutian(layer):
    dpoly(layer, [(26, 4), (14, 24), (22, 24), (16, 44), (34, 20), (25, 20), (32, 4)], (110, 180, 240, 255))
    dpoly(layer, [(25, 8), (17, 23), (23, 23), (19, 39), (31, 21), (24, 21), (29, 8)], (198, 236, 255, 255))
    drect(layer, 12, 40, 36, 42, (60, 110, 160, 255))
    drect(layer, 16, 38, 32, 39, (150, 210, 245, 255))


def sym_taiyi(layer):
    # 悬挂的符箓：顶环 + 符纸 + 朱砂笔画 + 底部印章
    darc(layer, 21, 1, 27, 7, 0, 360, GOLD, 1)
    drect(layer, 18, 7, 29, 40, (132, 112, 74, 255))
    drect(layer, 19, 8, 28, 39, (172, 148, 96, 255))
    drect(layer, 20, 9, 27, 38, (196, 172, 118, 255))
    drect(layer, 18, 7, 19, 40, (98, 82, 54, 255))
    for i in range(3):
        y = 12 + i * 8
        drect(layer, 22, y, 25, y, RED_DIM)
        drect(layer, 23, y + 1, 24, y + 4, RED)
    dpoly(layer, [(24, 33), (27, 36), (24, 39), (21, 36)], RED_DIM)
    dpoly(layer, [(24, 34), (26, 36), (24, 38), (22, 36)], RED)
    drect(layer, 16, 10, 17, 36, (98, 82, 54, 255))
    drect(layer, 30, 10, 31, 36, (98, 82, 54, 255))


def sym_jiuyou(layer):
    for k, cy in enumerate((12, 24, 36)):
        cx = 24 + (0 if k % 2 == 0 else 3)
        darc(layer, cx - 8, cy - 6, cx + 8, cy + 6, 0, 360, GREEN_DIM, 3)
        darc(layer, cx - 8, cy - 6, cx + 8, cy + 6, 0, 360, GREEN, 1)
        darc(layer, cx - 6, cy - 4, cx + 6, cy + 4, 0, 360, (200, 240, 150, 255), 1)
    dpoly(layer, [(20, 42), (28, 42), (24, 47)], GREEN_DIM)
    drect(layer, 21, 43, 26, 44, GREEN)
    dpoly(layer, [(23, 4), (26, 8), (23, 11), (21, 7)], (206, 244, 158, 255))


def sym_relic_boots(layer):
    dpoly(layer, [(17, 10), (28, 10), (28, 25), (34, 27), (35, 33), (15, 33), (15, 16)], STEEL_D)
    dpoly(layer, [(19, 12), (26, 12), (26, 25), (31, 28), (31, 31), (18, 31)], STEEL)
    drect(layer, 19, 14, 25, 16, (196, 206, 222, 255))
    drect(layer, 14, 33, 36, 37, STEEL_D)
    drect(layer, 15, 33, 35, 34, (196, 206, 222, 255))
    darc(layer, 8, 30, 40, 48, 190, 350, CYAN_DIM, 2)
    darc(layer, 10, 34, 38, 48, 200, 340, CYAN, 1)
    darc(layer, 14, 38, 34, 48, 210, 330, CYAN_HOT, 1)


def sym_relic_magnet(layer):
    darc(layer, 12, 10, 36, 40, 180, 360, STEEL_D, 6)
    darc(layer, 12, 10, 36, 40, 180, 360, STEEL, 4)
    drect(layer, 11, 27, 18, 40, STEEL_D)
    drect(layer, 30, 27, 37, 40, STEEL_D)
    drect(layer, 11, 33, 18, 40, RED)
    drect(layer, 30, 33, 37, 40, RED)
    drect(layer, 11, 33, 18, 34, (232, 96, 78, 255))
    drect(layer, 30, 33, 37, 34, (232, 96, 78, 255))
    darc(layer, 16, 6, 32, 22, 200, 340, CYAN, 1)
    drect(layer, 22, 3, 25, 6, CYAN_HOT)


def sym_relic_bone(layer):
    drect(layer, 21, 12, 26, 36, BONE_C)
    drect(layer, 22, 12, 24, 36, (238, 234, 214, 255))
    drect(layer, 21, 14, 26, 16, BONE_D)
    drect(layer, 21, 32, 26, 34, BONE_D)
    dellipse(layer, 14, 8, 24, 18, BONE_C)
    dellipse(layer, 23, 8, 33, 18, BONE_C)
    dellipse(layer, 23, 30, 33, 40, BONE_C)
    dellipse(layer, 14, 30, 24, 40, BONE_C)
    drect(layer, 16, 12, 19, 15, (110, 104, 86, 255))
    drect(layer, 28, 12, 31, 15, (110, 104, 86, 255))
    darc(layer, 8, 6, 39, 43, 200, 340, CYAN, 1)
    drect(layer, 22, 43, 25, 45, CYAN_HOT)


def sym_relic_armor(layer):
    dpoly(layer, [(24, 5), (33, 8), (39, 13), (36, 25), (31, 38), (24, 43), (17, 38), (12, 25), (9, 13), (15, 8)], (132, 94, 34, 255))
    dpoly(layer, [(24, 8), (31, 10), (36, 14), (33, 24), (28, 35), (24, 39), (20, 35), (15, 24), (12, 14), (17, 10)], GOLD)
    dpoly(layer, [(24, 9), (29, 11), (24, 26), (19, 15)], GOLD_HOT)
    drect(layer, 22, 12, 25, 18, (120, 82, 30, 255))
    drect(layer, 22, 24, 25, 33, (120, 82, 30, 255))
    drect(layer, 15, 20, 19, 22, (120, 82, 30, 255))
    drect(layer, 28, 20, 32, 22, (120, 82, 30, 255))
    darc(layer, 6, 6, 41, 41, 200, 340, GOLD_HOT, 1)


def sym_relic_pill(layer):
    dellipse(layer, 13, 13, 34, 34, (92, 26, 30, 255))
    dellipse(layer, 15, 15, 32, 32, RED)
    darc(layer, 13, 13, 34, 34, 210, 330, (238, 120, 108, 255), 1)
    dellipse(layer, 19, 17, 28, 26, (238, 176, 92, 255))
    drect(layer, 22, 20, 25, 24, GOLD_HOT)
    drect(layer, 8, 12, 11, 15, GOLD_HOT)
    drect(layer, 36, 32, 39, 35, GOLD_HOT)
    drect(layer, 35, 10, 38, 13, GOLD)
    drect(layer, 9, 34, 12, 37, GOLD)


def sym_relic_luck(layer):
    dpoly(layer, [(7, 26), (13, 24), (15, 33), (33, 33), (35, 24), (41, 26), (36, 40), (12, 40)], (140, 104, 40, 255))
    dpoly(layer, [(9, 26), (14, 25), (16, 34), (32, 34), (34, 25), (39, 26), (34, 38), (14, 38)], GOLD)
    dpoly(layer, [(14, 27), (18, 28), (24, 36), (30, 28), (34, 27), (30, 33), (18, 33)], GOLD_HOT)
    drect(layer, 22, 10, 26, 13, GOLD)
    drect(layer, 23, 8, 25, 11, GOLD_HOT)
    drect(layer, 6, 16, 9, 19, GOLD)
    drect(layer, 39, 14, 42, 17, GOLD)
    drect(layer, 22, 5, 25, 8, (255, 240, 200, 255))


def sym_relic_insight(layer):
    dpoly(layer, [(24, 10), (38, 24), (24, 38), (10, 24)], VIOLET_DIM)
    dpoly(layer, [(24, 13), (34, 24), (24, 35), (14, 24)], VIOLET)
    dellipse(layer, 19, 19, 29, 29, (24, 18, 36, 255))
    dellipse(layer, 21, 21, 27, 27, CYAN)
    drect(layer, 23, 22, 25, 26, CYAN_HOT)
    drect(layer, 24, 6, 26, 12, GOLD)
    drect(layer, 12, 23, 15, 25, GOLD_HOT)
    drect(layer, 34, 23, 37, 25, GOLD_HOT)


def sym_relic_wind(layer):
    for y in (13, 21, 29):
        darc(layer, 7, y - 8, 39, y + 8, 200, 350, CYAN_DIM, 3)
        darc(layer, 7, y - 8, 39, y + 8, 200, 350, CYAN, 1)
    darc(layer, 11, 4, 39, 28, 190, 330, CYAN_HOT, 1)
    darc(layer, 20, 6, 40, 26, 200, 320, CYAN_DIM, 2)
    dpoly(layer, [(33, 20), (41, 16), (37, 26)], CYAN_HOT)
    drect(layer, 9, 34, 25, 36, CYAN_DIM)
    drect(layer, 11, 37, 20, 38, (24, 84, 106, 255))


ICONS_SKILL = [
    ("icon_qingzhu_sword.png", sym_qingzhu),
    ("icon_taichi_array.png", sym_taichi),
    ("icon_jiutian_thunder.png", sym_jiutian),
    ("icon_taiyi_talisman.png", sym_taiyi),
    ("icon_jiuyou_chain.png", sym_jiuyou),
]

ICONS_RELIC = [
    ("relic_boots.png", sym_relic_boots),
    ("relic_magnet.png", sym_relic_magnet),
    ("relic_bone.png", sym_relic_bone),
    ("relic_armor.png", sym_relic_armor),
    ("relic_pill.png", sym_relic_pill),
    ("relic_luck.png", sym_relic_luck),
    ("relic_insight.png", sym_relic_insight),
    ("relic_wind.png", sym_relic_wind),
]


def make_icon(sym_fn):
    img = icon_base(48)
    return draw_icon(img, sym_fn)


# ---------------------------------------------------------------- 粒子

def particle_spirit_dot():
    img = canvas(32, 32)
    dellipse(img, 6, 6, 25, 25, (28, 96, 124, 46))
    dellipse(img, 8, 8, 23, 23, (40, 132, 158, 74))
    dellipse(img, 10, 10, 21, 21, (72, 200, 220, 130))
    dellipse(img, 13, 13, 18, 18, (150, 236, 246, 200))
    drect(img, 14, 14, 17, 17, (222, 252, 255, 255))
    drect(img, 9, 26, 11, 27, (56, 168, 190, 120))
    return img


def particle_ember():
    img = canvas(32, 32)
    dellipse(img, 8, 8, 23, 23, (140, 48, 24, 52))
    dellipse(img, 9, 9, 22, 22, (176, 68, 30, 84))
    dellipse(img, 12, 12, 19, 19, (226, 108, 40, 180))
    drect(img, 14, 14, 17, 17, (250, 194, 96, 235))
    drect(img, 15, 15, 16, 16, (255, 240, 206, 255))
    # 灰烬
    drect(img, 8, 22, 9, 23, (86, 74, 70, 190))
    drect(img, 21, 10, 22, 11, (96, 82, 76, 170))
    drect(img, 24, 20, 25, 21, (70, 60, 56, 150))
    drect(img, 11, 26, 12, 27, (60, 52, 48, 130))
    return img


def particle_wisp():
    img = canvas(32, 32)
    dpoly(img, [(16, 3), (21, 12), (22, 21), (16, 28), (10, 21), (11, 12)], (24, 84, 112, 96))
    dpoly(img, [(16, 7), (19, 14), (20, 20), (16, 25), (12, 20), (13, 14)], (64, 200, 220, 190))
    dpoly(img, [(16, 11), (18, 16), (18, 20), (16, 23), (14, 20), (14, 16)], (168, 244, 250, 235))
    drect(img, 15, 14, 17, 18, (232, 255, 255, 255))
    drect(img, 11, 29, 13, 30, (52, 140, 170, 140))
    drect(img, 19, 27, 20, 28, (44, 124, 152, 120))
    return img


PARTICLES = [
    ("spirit_dot.png", particle_spirit_dot),
    ("ember.png", particle_ember),
    ("wisp.png", particle_wisp),
]


# ---------------------------------------------------------------- 生成与自检

def save(img, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, "PNG")


def alpha_ratio(img):
    alpha = img.getchannel("A")
    hist = alpha.histogram()
    total = img.size[0] * img.size[1]
    opaque = total - hist[0]
    return opaque / total


def color_count(img):
    seen = set()
    px = img.load()
    for y in range(img.size[1]):
        for x in range(img.size[0]):
            r, g, b, a = px[x, y]
            if a:
                seen.add((r, g, b))
    return len(seen)


def seam_report(img):
    """接缝自检：比较接缝处相邻像素的落差在全部相邻对中的位次。

    位次越靠后说明接缝越不突兀（越接近 1/2 说明它只是随机分布里普通的一对）。
    """
    px = img.load()
    w, h = img.size

    def pair_diffs(horizontal):
        diffs = []
        n = w if horizontal else h
        m = h if horizontal else w
        for i in range(n):
            a = px[i, 0] if horizontal else px[0, i]
            b = px[(i + 1) % n, 0] if horizontal else px[0, (i + 1) % n]
            d = 0
            for k in range(m):
                c = px[i, k] if horizontal else px[k, i]
                e = px[(i + 1) % n, k] if horizontal else px[k, (i + 1) % n]
                d += abs(c[0] - e[0]) + abs(c[1] - e[1]) + abs(c[2] - e[2])
            diffs.append(d / m)
        seam = diffs[-1]
        worse = sum(1 for d in diffs[:-1] if d > seam)
        return seam, worse, len(diffs) - 1

    sh, wh, nh = pair_diffs(True)
    sv, wv, nv = pair_diffs(False)
    return "seam h=%d/%d v=%d/%d" % (wh, nh, wv, nv)


def main():
    parser = argparse.ArgumentParser(description="生成《百宝小道修 (Pocket Daoist)》像素美术素材")
    parser.add_argument("--out", default=os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                        help="项目根目录，素材写入 <out>/assets/…（默认脚本所在仓库根目录）")
    parser.add_argument("--seed", type=int, default=20261109, help="随机种子，默认 20261109")
    args = parser.parse_args()
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

    root = os.path.abspath(args.out)
    assets = os.path.join(root, "assets")
    seed = args.seed
    report = []

    for i, (name, fn, palette) in enumerate(TILES):
        rng = random.Random(seed + i * 17)
        img = canvas(TILE_SIZE, TILE_SIZE)
        fn(img, rng)
        quantize(img, palette)
        path = os.path.join(assets, "terrain", name)
        save(img, path)
        note = seam_report(img)
        report.append(("terrain", name, img.size, alpha_ratio(img), color_count(img), note))

    for i, (name, fn) in enumerate(PROPS):
        rng = random.Random(seed + 1000 + i * 13)
        img = fn(rng)
        limit_palette(img, 10)
        path = os.path.join(assets, "props", name)
        save(img, path)
        report.append(("props", name, img.size, alpha_ratio(img), color_count(img), ""))

    for i, (name, fn) in enumerate(ICONS_SKILL + ICONS_RELIC):
        img = make_icon(fn)
        limit_palette(img, 10)
        path = os.path.join(assets, "icons", name)
        save(img, path)
        report.append(("icons", name, img.size, alpha_ratio(img), color_count(img), ""))

    for i, (name, fn) in enumerate(PARTICLES):
        img = fn()
        limit_palette(img, 8)
        path = os.path.join(assets, "particles", name)
        save(img, path)
        report.append(("particles", name, img.size, alpha_ratio(img), color_count(img), ""))

    print("生成完成 -> %s" % assets)
    print("%-10s %-26s %-9s %-8s %-6s %s" % ("目录", "文件", "尺寸", "alpha覆盖", "色数", "备注"))
    for kind, name, size, ar, cc, note in report:
        print("%-10s %-26s %-9s %-8.2f %-6d %s" % (kind, name, "%dx%d" % size, ar, cc, note))
    print("共 %d 个文件" % len(report))


if __name__ == "__main__":
    main()
