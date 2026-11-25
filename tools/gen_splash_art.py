#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""《百宝小道修 (Pocket Daoist)》插画背景生成器。

本机没有运行中的 ComfyUI 出图服务，因此用 Python + Pillow + numpy 程序化
绘制「剪影 + 渐变 + 雾气 + 粒子」的暗黑东方风插画。

所有元素（山脊、枯树、松林、灯笼、牌坊、骨堆、祭坛、巨兽骨骸、剑气）都由
多边形与曲线直接画出，不依赖任何外部素材。固定随机种子可完整复现。

用法:
    python tools/gen_splash_art.py --out assets/art --seed 20241109
    python tools/gen_splash_art.py --out assets/art --only chapter_3
"""

from __future__ import annotations

import argparse
import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

W, H = 1216, 832

# --------------------------------------------------------------------------
# 基础工具
# --------------------------------------------------------------------------


def hexc(s: str):
    s = s.lstrip("#")
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4))


def as_color(c):
    return hexc(c) if isinstance(c, str) else tuple(c)


def vgrad(stops, h: int = H, w: int = W) -> np.ndarray:
    """竖直多段渐变。stops = [(位置0~1, "#rrggbb"), ...]"""
    stops = [(float(p), np.array(hexc(c), dtype=np.float32)) for p, c in stops]
    ys = np.linspace(0.0, 1.0, h)
    col = np.zeros((h, 3), dtype=np.float32)
    for i in range(len(stops) - 1):
        p0, c0 = stops[i]
        p1, c1 = stops[i + 1]
        m = (ys >= p0) & (ys <= p1)
        if not m.any():
            continue
        t = ((ys[m] - p0) / max(1e-6, p1 - p0))[:, None]
        col[m] = c0[None, :] * (1 - t) + c1[None, :] * t
    col[ys < stops[0][0]] = stops[0][1]
    col[ys > stops[-1][0]] = stops[-1][1]
    return np.repeat(col[:, None, :], w, axis=1)


def add_glow(base, cx, cy, radius, color, strength, power=2.2):
    """把一个径向光晕加到画面上（加色）。"""
    color = as_color(color)
    ys, xs = np.mgrid[0:H, 0:W]
    d = np.sqrt((xs - cx) ** 2 + (ys - cy) ** 2) / max(1.0, radius)
    g = np.clip(1.0 - d, 0.0, 1.0) ** power * strength
    base += g[..., None] * np.array(color, dtype=np.float32)


def new_mask() -> Image.Image:
    return Image.new("L", (W, H), 0)


def composite(base, mask, color, haze=0.0, fog=(70, 80, 110), blur=0.0, opacity=1.0):
    """把灰度遮罩按 color 合成到底图；haze 越大越被环境色吞没（空气透视）。"""
    m = mask
    if blur:
        m = m.filter(ImageFilter.GaussianBlur(blur))
    a = np.asarray(m, dtype=np.float32) / 255.0 * opacity
    hz = np.clip(base * 0.72 + np.array(as_color(fog), dtype=np.float32) * 0.28, 0, 255)
    col = np.array(as_color(color), dtype=np.float32)
    c = col[None, None, :] * (1 - haze) + hz * haze
    a3 = a[..., None]
    base *= 1 - a3
    base += c * a3


def mask_to_arr(mask) -> np.ndarray:
    return np.asarray(mask, dtype=np.float32) / 255.0


def soft_light(base, layer_np, color, strength=0.35):
    """把一层光斑加到画面上。"""
    c = np.array(as_color(color), dtype=np.float32)
    base += layer_np[..., None] * c[None, None, :] * strength


def taper_poly(pts, w0, w1):
    """沿折线生成由 w0 渐变到 w1 的锥形多边形顶点。"""
    n = len(pts)
    left, right = [], []
    for i, (x, y) in enumerate(pts):
        if i == 0:
            dx, dy = pts[1][0] - x, pts[1][1] - y
        elif i == n - 1:
            dx, dy = x - pts[-2][0], y - pts[-2][1]
        else:
            dx = pts[i + 1][0] - pts[i - 1][0]
            dy = pts[i + 1][1] - pts[i - 1][1]
        L = math.hypot(dx, dy) or 1.0
        nx, ny = -dy / L, dx / L
        w = w0 + (w1 - w0) * i / (n - 1)
        left.append((x + nx * w, y + ny * w))
        right.append((x - nx * w, y - ny * w))
    return left + right[::-1]


def fractal_ridge(rng, rough=0.58, disp=1.0, iterations=7):
    """中点位移生成起伏山脊，返回 [(x0~1, y), ...]。"""
    pts = [(0.0, 0.0), (1.0, 0.0)]
    amp = disp
    for _ in range(iterations):
        new = []
        for i in range(len(pts) - 1):
            x0, y0 = pts[i]
            x1, y1 = pts[i + 1]
            mx = (x0 + x1) * 0.5
            my = (y0 + y1) * 0.5 + rng.uniform(-1.0, 1.0) * amp
            new.append((x0, y0))
            new.append((mx, my))
        new.append(pts[-1])
        pts = new
        amp *= rough
    return pts


def ridge_mask(rng, base_y, amp, rough=0.58, seed_phase=0.0):
    """一条山脊填充到画布底部。"""
    pts = fractal_ridge(rng, rough=rough, disp=1.0)
    m = new_mask()
    d = ImageDraw.Draw(m)
    xy = [(x * W, base_y + (y - seed_phase) * amp) for x, y in pts]
    d.polygon(xy + [(W, H + 10), (0, H + 10)], fill=255)
    return m


def fog_band(base, y, thickness, color, strength=0.28, blur=26):
    """一条水平的雾气带。"""
    m = new_mask()
    d = ImageDraw.Draw(m)
    d.rectangle([-10, y - thickness * 0.5, W + 10, y + thickness * 0.5], fill=255)
    m = m.filter(ImageFilter.GaussianBlur(blur))
    a = mask_to_arr(m) * strength
    base += a[..., None] * np.array(as_color(color), dtype=np.float32)[None, None, :]


# --------------------------------------------------------------------------
# 剪影元素
# --------------------------------------------------------------------------


def branch_up(d, x, y, ang, length, width, depth, rng, fill=255):
    """向上分叉的枝条（-pi/2 为正上方）。"""
    if depth <= 0 or length < 5:
        return
    x2 = x + math.cos(ang) * length
    y2 = y + math.sin(ang) * length
    d.line([(x, y), (x2, y2)], fill=fill, width=max(1, int(round(width))))
    for i in range(2):
        na = ang + rng.uniform(-0.42, 0.42) + (i - 0.5) * 0.42
        branch_up(d, x2, y2, na, length * rng.uniform(0.62, 0.8), width * 0.62,
                  depth - 1, rng, fill)


def dead_tree(d, x, base_y, height, rng, lean=0.0, fill=255, limbs=5):
    """枯树剪影：弯曲主干 + 向上分叉的枝条。"""
    n = 9
    pts = []
    for i in range(n):
        t = i / (n - 1)
        lx = x + lean * height * t * t + rng.uniform(-1, 1) * height * 0.008
        pts.append((lx, base_y - height * t))
    d.polygon(taper_poly(pts, height * 0.05, height * 0.010), fill=fill)
    for i in range(limbs):
        t = 0.42 + 0.56 * (i / max(1, limbs - 1))
        idx = min(n - 1, int(t * (n - 1)))
        bx, by = pts[idx]
        side = -1 if i % 2 == 0 else 1
        ang = -math.pi / 2 + side * rng.uniform(0.5, 1.0)
        branch_up(d, bx, by, ang, height * rng.uniform(0.16, 0.26),
                  height * 0.018, 4, rng, fill)


def pine(d, x, base_y, h, rng, fill=255):
    """针叶树剪影。"""
    tw = max(2, h * 0.032)
    d.polygon(taper_poly([(x, base_y), (x, base_y - h * 0.18)], tw, tw * 0.6), fill=fill)
    tiers = 9
    for i in range(tiers):
        t = i / float(tiers - 1)
        y = base_y - h * 0.10 - t * h * 0.86
        half = h * 0.21 * (1.0 - t * 0.82) + h * 0.010
        skew = rng.uniform(-0.02, 0.02) * h
        d.polygon([(x + skew * 0.3, y - h * 0.26),
                   (x - half + skew, y),
                   (x + half + skew, y)], fill=fill)


def broadleaf(d, x, base_y, h, rng, fill=255):
    """阔叶树剪影：不规则树冠 + 弯曲树干。"""
    tw = max(2, h * 0.045)
    trunk = [(x, base_y), (x + h * 0.012, base_y - h * 0.4), (x - h * 0.01, base_y - h * 0.6)]
    d.polygon(taper_poly(trunk, tw, tw * 0.45), fill=fill)
    cy = base_y - h * 0.76
    cw = h * 0.21
    for _ in range(46):
        a = rng.uniform(0, 2 * math.pi)
        r = rng.random() ** 0.5
        px = x + math.cos(a) * cw * r
        py = cy + math.sin(a) * h * 0.12 * r
        rr = h * rng.uniform(0.028, 0.05)
        d.ellipse([px - rr, py - rr * 0.85, px + rr, py + rr * 0.85], fill=fill)


def lantern(d, x, y, r, fill=255):
    """灯笼剪影。"""
    d.ellipse([x - r, y - r * 1.15, x + r, y + r * 1.15], fill=fill)
    d.rectangle([x - r * 0.35, y - r * 1.45, x + r * 0.35, y - r * 1.05], fill=fill)
    d.rectangle([x - r * 0.35, y + r * 1.05, x + r * 0.35, y + r * 1.45], fill=fill)


def paifang(d, x, base_y, w, h, rng, fill=255):
    """牌坊剪影：双柱 + 横枋 + 两层飞檐。"""
    cw = w * 0.07
    for s in (-1, 1):
        cx = x + s * w * 0.40
        d.polygon(taper_poly([(cx, base_y), (cx, base_y - h * 0.86)], cw * 0.6, cw * 0.45), fill=fill)
        d.polygon([(cx - cw * 1.1, base_y), (cx + cw * 1.1, base_y),
                   (cx + cw * 0.7, base_y - h * 0.07), (cx - cw * 0.7, base_y - h * 0.07)],
                  fill=fill)
    d.rectangle([x - w * 0.46, base_y - h * 0.70, x + w * 0.46, base_y - h * 0.60], fill=fill)
    for yy, ww in ((base_y - h * 0.88, w * 0.66), (base_y - h * 0.66, w * 0.50)):
        roof = []
        for i in range(25):
            t = i / 24.0
            px = x - ww + 2 * ww * t
            py = yy - h * 0.055 * math.sin(t * math.pi)
            roof.append((px, py))
        d.polygon(roof + [(x + ww, yy + h * 0.035), (x - ww, yy + h * 0.035)], fill=fill)
        d.polygon([(x - ww, yy + h * 0.035), (x - ww * 1.08, yy - h * 0.035),
                   (x - ww * 0.6, yy + h * 0.005), (x - ww * 0.34, yy + h * 0.035)], fill=fill)
        d.polygon([(x + ww, yy + h * 0.035), (x + ww * 1.08, yy - h * 0.035),
                   (x + ww * 0.6, yy + h * 0.005), (x + ww * 0.34, yy + h * 0.035)], fill=fill)


def skull_shape(d, x, y, r, fill=255):
    """头骨轮廓：颅顶 + 下颌。"""
    d.ellipse([x - r, y - r * 1.05, x + r, y + r * 0.55], fill=fill)
    d.polygon([(x - r * 0.7, y + r * 0.25), (x + r * 0.7, y + r * 0.25),
               (x + r * 0.46, y + r * 1.05), (x - r * 0.46, y + r * 1.05)], fill=fill)


def long_bone(d, x0, y0, x1, y1, w, fill=255):
    d.line([(x0, y0), (x1, y1)], fill=fill, width=max(2, int(w)))
    r = w * 0.85
    d.ellipse([x0 - r, y0 - r, x0 + r, y0 + r], fill=fill)
    d.ellipse([x1 - r, y1 - r, x1 + r, y1 + r], fill=fill)


def altar_steps(d, cx, base_y, w, h, rng, fill=255):
    """阶梯祭坛（梯形台基）。"""
    steps = 5
    for i in range(steps):
        t = i / float(steps)
        y = base_y - h * t
        ww = w * (1.0 - 0.16 * i)
        sh = h / steps * 0.92
        d.polygon([(cx - ww * 0.5, y), (cx + ww * 0.5, y),
                   (cx + ww * 0.42, y - sh), (cx - ww * 0.42, y - sh)], fill=fill)
    tw = w * 0.62
    d.polygon([(cx - tw * 0.5, base_y - h), (cx + tw * 0.5, base_y - h),
               (cx + tw * 0.4, base_y - h * 1.16), (cx - tw * 0.4, base_y - h * 1.16)],
              fill=fill)


def pillar(d, x, base_y, h, w, rng, fill=255):
    """铜柱剪影：柱础 + 束腰柱身 + 盘纹 + 柱头。"""
    d.polygon([(x - w * 0.95, base_y), (x + w * 0.95, base_y),
               (x + w * 0.66, base_y - h * 0.07), (x - w * 0.66, base_y - h * 0.07)],
              fill=fill)
    d.polygon(taper_poly([(x, base_y - h * 0.07), (x, base_y - h * 0.84)],
                         w * 0.5, w * 0.36), fill=fill)
    for i in range(4):
        y = base_y - h * (0.16 + 0.17 * i)
        ww = w * (0.56 - 0.03 * i)
        d.rectangle([x - ww, y - h * 0.016, x + ww, y + h * 0.016], fill=fill)
    d.polygon([(x - w * 0.5, base_y - h * 0.84), (x + w * 0.5, base_y - h * 0.84),
               (x + w * 0.66, base_y - h * 0.94), (x - w * 0.66, base_y - h * 0.94)],
              fill=fill)


def beast_skeleton(d, rng, cx, base_y, scale, fill=255):
    """巨兽骨架：脊柱 + 棘刺 + 锥形肋 + 头骨 + 后肢。"""
    spine = []
    n = 26
    for i in range(n + 1):
        t = i / n
        x = cx + (t - 0.5) * scale * 1.55
        y = base_y - scale * (0.52 + 0.30 * math.sin(t * math.pi * 0.95) - 0.16 * t)
        spine.append((x, y))
    d.line(spine, fill=fill, width=max(3, int(scale * 0.035)))
    for i, (x, y) in enumerate(spine):
        if i % 2:
            continue
        d.line([(x, y), (x + rng.uniform(-3, 3), y - scale * 0.075)],
               fill=fill, width=max(2, int(scale * 0.014)))
    # 肋骨
    for i in range(3, len(spine) - 4):
        x, y = spine[i]
        t = i / float(len(spine) - 1)
        rl = scale * (0.44 - 0.24 * abs(t - 0.45))
        pts = []
        for k in range(13):
            a = math.pi * k / 12.0
            pts.append((x - math.cos(a) * rl * 0.62 + rng.uniform(-2, 2),
                        y + math.sin(a) * rl * 0.95))
        d.line(pts, fill=fill, width=max(2, int(scale * 0.017)))
    # 后肢
    for s in (-1, 1):
        hx = cx + s * scale * 0.62
        hy = spine[3 if s < 0 else len(spine) - 4][1]
        d.line([(hx, hy), (hx + s * scale * 0.16, hy + scale * 0.42)],
               fill=fill, width=max(3, int(scale * 0.03)))
        d.line([(hx + s * scale * 0.16, hy + scale * 0.42),
                (hx + s * scale * 0.05, base_y)], fill=fill, width=max(2, int(scale * 0.022)))
    # 头骨
    sx = spine[0][0] - scale * 0.12
    sy = spine[0][1] + scale * 0.04
    d.ellipse([sx - scale * 0.14, sy - scale * 0.10,
               sx + scale * 0.12, sy + scale * 0.10], fill=fill)
    # 下颌
    d.polygon([(sx - scale * 0.12, sy + scale * 0.02), (sx + scale * 0.02, sy + scale * 0.05),
               (sx - scale * 0.03, sy + scale * 0.16), (sx - scale * 0.13, sy + scale * 0.11)],
              fill=fill)
    # 双角（向后上方弯）
    for sgn in (-1, 1):
        horn = []
        for k in range(7):
            t = k / 6.0
            horn.append((sx + sgn * scale * (0.06 + 0.26 * t),
                         sy - scale * (0.04 + 0.26 * t - 0.22 * t * t)))
        d.line(horn, fill=fill, width=max(2, int(scale * 0.022)))
    return spine


# --------------------------------------------------------------------------
# 后期
# --------------------------------------------------------------------------


def vignette(base, strength=0.5, power=1.7):
    ys, xs = np.mgrid[0:H, 0:W]
    nx = (xs - W * 0.5) / (W * 0.5)
    ny = (ys - H * 0.5) / (H * 0.5)
    d = np.sqrt(nx * nx * 0.92 + ny * ny)
    v = np.clip(d / 1.22, 0.0, 1.0) ** power
    base *= 1.0 - strength * v[..., None]


def grain(base, npr, amount=4.5):
    n = npr.normal(0.0, 1.0, (H, W, 1)).astype(np.float32)
    base += n * amount


def banding(base, levels=56, weight=0.35):
    q = np.floor(np.clip(base, 0, 255) / 255.0 * levels + 0.5) / levels * 255.0
    base *= 1.0 - weight
    base += q * weight


def finish(base, npr, vig=0.5, grain_amt=4.5, band_w=0.35):
    vignette(base, vig)
    grain(base, npr, grain_amt)
    banding(base, weight=band_w)
    return Image.fromarray(np.clip(base, 0, 255).astype(np.uint8), "RGB")


def draw_moon(base, cx, cy, r, core, halo, npr, halo_r=None, mottle=0.3,
              glow=0.9, limb=0.0):
    core = as_color(core)
    halo = as_color(halo)
    halo_r = halo_r if halo_r else r * 4.2
    add_glow(base, cx, cy, halo_r, halo, glow * 0.26, power=2.4)
    add_glow(base, cx, cy, r * 1.5, halo, glow * 0.38, power=2.6)

    m = new_mask()
    ImageDraw.Draw(m).ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)
    disc = mask_to_arr(m)

    noise = npr.random((H, W)).astype(np.float32)
    n2 = np.asarray(Image.fromarray((noise * 255).astype(np.uint8)).filter(
        ImageFilter.GaussianBlur(8)), dtype=np.float32) / 255.0

    ys, xs = np.mgrid[0:H, 0:W]
    dn = np.sqrt((xs - cx) ** 2 + (ys - cy) ** 2) / max(1.0, r)
    shade = 1.0 - mottle * (1.0 - n2) * 0.75
    edge = np.clip(1.18 - dn * 0.5, 0.6, 1.0)
    if limb > 0:
        edge = edge * (1.0 - limb * np.clip((dn - 0.35) / 0.65, 0, 1) ** 2)
    col = np.array(core, dtype=np.float32)[None, None, :] * shade[..., None] * edge[..., None]
    a3 = disc[..., None]
    base *= 1.0 - a3
    base += np.clip(col, 0, 255) * a3

    # 月面外一圈很淡的散射
    ring = new_mask()
    ImageDraw.Draw(ring).ellipse([cx - r * 1.18, cy - r * 1.18, cx + r * 1.18, cy + r * 1.18],
                                  outline=255, width=7)
    ra = mask_to_arr(ring.filter(ImageFilter.GaussianBlur(12))) * (1.0 - disc)
    base += ra[..., None] * np.array(halo, dtype=np.float32)[None, None, :] * 0.16


def stars(base, rng, count=260, ymax=0.55, color=(200, 215, 255), maxr=1.6, bright=0.9):
    m = new_mask()
    d = ImageDraw.Draw(m)
    for _ in range(count):
        x = rng.uniform(0, W)
        y = rng.uniform(0, H * ymax)
        r = rng.uniform(0.5, maxr)
        v = rng.uniform(0.25, 1.0)
        d.ellipse([x - r, y - r, x + r, y + r], fill=int(255 * v))
    a = mask_to_arr(m) * bright
    base += a[..., None] * np.array(as_color(color), dtype=np.float32)[None, None, :]


def motes(base, rng, count=140, color=(255, 220, 180), rmin=0.6, rmax=2.2,
          y0=0.0, y1=1.0, strength=0.9, blur=1.2):
    """漂浮光点 / 火星 / 尘埃。"""
    m = new_mask()
    d = ImageDraw.Draw(m)
    for _ in range(count):
        x = rng.uniform(0, W)
        y = rng.uniform(H * y0, H * y1)
        r = rng.uniform(rmin, rmax)
        v = rng.uniform(0.3, 1.0)
        d.ellipse([x - r, y - r, x + r, y + r], fill=int(255 * v))
    m = m.filter(ImageFilter.GaussianBlur(blur))
    a = mask_to_arr(m) * strength
    base += a[..., None] * np.array(as_color(color), dtype=np.float32)[None, None, :]


def reflection(base, water_y, strength=0.4, fade=300, wave=7, ripple=0.28, tint=None):
    """把水面以上的画面镜像倒映到水面，并做波纹与衰减。"""
    if water_y < 10:
        return
    region = base[:water_y].copy()
    refl = region[::-1]
    rows = refl.shape[0]
    shift = (np.sin(np.arange(rows) * 0.28) * wave +
             np.sin(np.arange(rows) * 0.07 + 1.3) * wave * 0.6)
    shifted = np.empty_like(refl)
    for i in range(rows):
        shifted[i] = np.roll(refl[i], int(round(shift[i])), axis=0)
    out_h = int(min(H - water_y, rows))
    if out_h <= 0:
        return
    idx = (np.arange(out_h) / max(1, out_h - 1) * (rows - 1)).astype(np.int32)
    refl = shifted[idx]
    ys = np.arange(out_h)
    alpha = np.clip(1.0 - ys / max(1.0, fade), 0.0, 1.0) * strength
    alpha = alpha * (1.0 - ripple + ripple * (0.5 + 0.5 * np.sin(ys * 0.9)))
    xf = 0.80 + 0.20 * np.sin(np.arange(W) * 0.05)
    alpha = alpha[:, None] * xf[None, :]
    if tint is not None:
        refl = refl * (1 - alpha[:, :, None]) + np.array(as_color(tint), dtype=np.float32)[None, None, :] * alpha[:, :, None]
    base[water_y:water_y + out_h] *= 1 - alpha[:, :, None]
    base[water_y:water_y + out_h] += refl * alpha[:, :, None]


# --------------------------------------------------------------------------
# 场景
# --------------------------------------------------------------------------


def scene_title(rng, npr):
    """标题界面：远山云海 + 巨大血月 + 前景枯树 + 飘浮符纸，冷青紫。"""
    base = vgrad([(0.0, "#0d0a20"), (0.24, "#221640"), (0.46, "#3a2455"),
                  (0.64, "#241a3e"), (0.82, "#141026"), (1.0, "#08060f")])
    stars(base, rng, count=340, ymax=0.40, color=(190, 200, 255), bright=0.8)
    draw_moon(base, W * 0.5, H * 0.29, 132, "#cf4a52", "#ff6a55", npr,
              halo_r=560, mottle=0.42, glow=1.05, limb=0.22)

    # 三层远山：越远越淡，形成纵深
    composite(base, ridge_mask(rng, H * 0.53, 160, rough=0.60), (96, 86, 138),
              haze=0.70, fog=(92, 84, 132))
    composite(base, ridge_mask(rng, H * 0.585, 128, rough=0.64), (56, 48, 92),
              haze=0.50, fog=(70, 60, 106))
    composite(base, ridge_mask(rng, H * 0.645, 100, rough=0.68), (26, 21, 48),
              haze=0.28, fog=(44, 36, 78))

    # 云海
    for i in range(9):
        y = H * (0.60 + 0.032 * i)
        fog_band(base, y, 30 + i * 7, (150, 140, 205), strength=0.11 + 0.02 * i, blur=32)
    fog_band(base, H * 0.72, 120, (110, 100, 165), strength=0.14, blur=48)

    # 前景枯树
    near = new_mask()
    d = ImageDraw.Draw(near)
    dead_tree(d, W * 0.13, H * 1.03, 660, rng, lean=0.03, limbs=6)
    dead_tree(d, W * 0.89, H * 1.03, 580, rng, lean=-0.03, limbs=6)
    dead_tree(d, W * 0.04, H * 1.03, 430, rng, lean=0.02, limbs=4)
    composite(base, near, (9, 8, 17), haze=0.0, fog=(0, 0, 0), opacity=0.97)

    # 飘浮符纸
    tal = new_mask()
    td = ImageDraw.Draw(tal)
    for _ in range(9):
        x = rng.choice([rng.uniform(W * 0.06, W * 0.3), rng.uniform(W * 0.7, W * 0.95),
                        rng.uniform(W * 0.12, W * 0.88)])
        y = rng.uniform(H * 0.26, H * 0.9)
        w = rng.uniform(9, 15)
        h = w * rng.uniform(1.8, 2.4)
        a = rng.uniform(0, math.pi)
        ca, sa = math.cos(a), math.sin(a)
        pts = []
        for dx, dy in ((-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2)):
            pts.append((x + dx * ca - dy * sa, y + dx * sa + dy * ca))
        td.polygon(pts, fill=255)
    glow = Image.fromarray((mask_to_arr(tal) * 255).astype(np.uint8)).filter(
        ImageFilter.GaussianBlur(8))
    base += mask_to_arr(glow)[..., None] * np.array((140, 205, 235), dtype=np.float32) * 0.45
    composite(base, tal, (214, 210, 190), haze=0.0, opacity=0.8)

    motes(base, rng, count=120, color=(160, 210, 240), rmin=0.6, rmax=2.0, strength=0.45)
    return finish(base, npr, vig=0.5, grain_amt=4.0)


def scene_forest(rng, npr):
    """第 1 章 青冥林·薄暮：密林剪影 + 薄雾 + 月光斑驳，雾青墨绿。"""
    base = vgrad([(0.0, "#0d1a1c"), (0.26, "#1b3438"), (0.48, "#2c4f4c"),
                  (0.66, "#20403f"), (0.84, "#152b2c"), (1.0, "#0b1618")])
    stars(base, rng, count=170, ymax=0.30, color=(180, 220, 220), bright=0.55)
    draw_moon(base, W * 0.33, H * 0.23, 88, "#d6ece6", "#a8d8d4", npr,
              halo_r=460, mottle=0.2, glow=0.85)

    # 远景林（雾化）
    far = new_mask()
    fd = ImageDraw.Draw(far)
    for _ in range(52):
        x = rng.uniform(-40, W + 40)
        h = rng.uniform(140, 250)
        (pine if rng.random() < 0.72 else broadleaf)(fd, x, H * 0.70, h, rng)
    composite(base, far, (96, 138, 132), haze=0.72, fog=(84, 122, 120))

    fog_band(base, H * 0.58, 100, (140, 190, 182), strength=0.24, blur=44)
    fog_band(base, H * 0.68, 76, (124, 178, 172), strength=0.20, blur=36)

    # 中景林
    mid = new_mask()
    md = ImageDraw.Draw(mid)
    for _ in range(36):
        x = rng.uniform(-30, W + 30)
        h = rng.uniform(250, 420)
        (pine if rng.random() < 0.6 else broadleaf)(md, x, H * 0.88, h, rng)
    composite(base, mid, (38, 74, 68), haze=0.44, fog=(46, 84, 80))
    fog_band(base, H * 0.80, 64, (112, 166, 158), strength=0.16, blur=32)

    # 月光光柱
    beam = new_mask()
    bd = ImageDraw.Draw(beam)
    for i in range(4):
        x0 = W * 0.33 + (i - 1.5) * 34
        bd.polygon([(x0 - 9, H * 0.18), (x0 + 9, H * 0.18),
                    (x0 + 120, H), (x0 + 40, H)], fill=255)
    beam = beam.filter(ImageFilter.GaussianBlur(30))
    soft_light(base, mask_to_arr(beam), (160, 215, 205), strength=0.26)

    # 近景林
    near = new_mask()
    nd = ImageDraw.Draw(near)
    for _ in range(10):
        x = rng.uniform(-40, W + 40)
        h = rng.uniform(390, 600)
        (pine if rng.random() < 0.55 else broadleaf)(nd, x, H * 1.04, h, rng)
    composite(base, near, (10, 26, 25), haze=0.10, fog=(26, 52, 50))

    # 地表月光斑驳
    spot = new_mask()
    sd = ImageDraw.Draw(spot)
    for _ in range(80):
        x = rng.uniform(0, W)
        y = rng.uniform(H * 0.80, H * 1.0)
        r = rng.uniform(10, 38)
        sd.ellipse([x - r, y - r * 0.36, x + r, y + r * 0.36], fill=int(rng.uniform(80, 210)))
    spot = spot.filter(ImageFilter.GaussianBlur(10))
    soft_light(base, mask_to_arr(spot), (150, 205, 195), strength=0.32)

    motes(base, rng, count=190, color=(160, 225, 215), rmin=0.6, rmax=2.4, strength=0.55)
    return finish(base, npr, vig=0.5, grain_amt=4.5)


def scene_dunes(rng, npr):
    """第 2 章 赤砂荒原·血月：沙丘剪影 + 巨大血月 + 风沙尘幕，沙黄血红。"""
    base = vgrad([(0.0, "#34101a"), (0.26, "#6d2019"), (0.46, "#a83c1e"),
                  (0.62, "#7d3119"), (0.80, "#3d1712"), (1.0, "#180a0a")])
    stars(base, rng, count=100, ymax=0.22, color=(255, 210, 190), bright=0.5)
    draw_moon(base, W * 0.64, H * 0.27, 162, "#e8512f", "#ff6a35", npr,
              halo_r=640, mottle=0.48, glow=1.15, limb=0.28)

    def dune(base_y, amp, freq, phase):
        mask = new_mask()
        dd = ImageDraw.Draw(mask)
        pts = []
        n = 200
        for i in range(n + 1):
            t = i / n
            y = (base_y + math.sin(t * freq + phase) * amp
                 + math.sin(t * freq * 2.3 + phase * 1.7) * amp * 0.32)
            pts.append((t * W, y))
        dd.polygon(pts + [(W, H + 10), (0, H + 10)], fill=255)
        return mask, pts

    m1, p1 = dune(H * 0.50, 24, 5.0, rng.uniform(0, 6))
    composite(base, m1, (176, 108, 64), haze=0.66, fog=(196, 116, 72))
    m2, p2 = dune(H * 0.605, 32, 3.4, rng.uniform(0, 6))
    composite(base, m2, (120, 66, 40), haze=0.46, fog=(168, 94, 60))
    m3, p3 = dune(H * 0.725, 42, 2.2, rng.uniform(0, 6))
    composite(base, m3, (68, 31, 22), haze=0.26, fog=(140, 76, 50))
    m4, p4 = dune(H * 0.885, 38, 4.2, rng.uniform(0, 6))
    composite(base, m4, (26, 12, 10), haze=0.08, fog=(70, 34, 26))

    # 沙丘边缘的高光
    rim = new_mask()
    rd = ImageDraw.Draw(rim)
    for pts in (p1, p2, p3):
        rd.line(pts, fill=255, width=3)
    rim = rim.filter(ImageFilter.GaussianBlur(3))
    soft_light(base, mask_to_arr(rim), (255, 190, 130), strength=0.45)

    # 地平线远山
    composite(base, ridge_mask(rng, H * 0.485, 46, rough=0.55), (168, 96, 66),
              haze=0.78, fog=(196, 116, 72))

    # 风蚀残柱
    ruin = new_mask()
    rd2 = ImageDraw.Draw(ruin)
    for _ in range(10):
        x = rng.uniform(0, W)
        h = rng.uniform(60, 150)
        w = rng.uniform(9, 20)
        y = H * 0.60
        tilt = rng.uniform(-0.12, 0.12)
        rd2.polygon([(x, y - h), (x + w, y - h * 0.86 + tilt * w),
                     (x + w * 0.74, y), (x - w * 0.18, y)], fill=255)
    composite(base, ruin, (58, 24, 18), haze=0.22, fog=(150, 82, 54))

    for i in range(6):
        fog_band(base, H * (0.50 + 0.07 * i), 44, (214, 148, 96), strength=0.13, blur=42)

    motes(base, rng, count=280, color=(240, 182, 126), rmin=0.5, rmax=1.9,
          y0=0.32, y1=1.0, strength=0.55, blur=0.8)
    return finish(base, npr, vig=0.5, grain_amt=5.0)


def scene_ghost_market(rng, npr):
    """第 3 章 幽冥鬼市·忘川：灯笼牌坊 + 河面倒影 + 鬼火，青紫幽蓝。"""
    base = vgrad([(0.0, "#080c1c"), (0.22, "#152144"), (0.42, "#243a63"),
                  (0.58, "#1b2b4a"), (0.70, "#101a30"), (1.0, "#05070f")])
    stars(base, rng, count=240, ymax=0.34, color=(180, 200, 255), bright=0.65)
    draw_moon(base, W * 0.20, H * 0.18, 72, "#dde3ff", "#8fa6ff", npr,
              halo_r=400, mottle=0.16, glow=0.75)

    water_y = int(H * 0.665)

    # 远景鬼市建筑群
    far = new_mask()
    fd = ImageDraw.Draw(far)
    for _ in range(18):
        x = rng.uniform(-20, W + 20)
        w = rng.uniform(44, 120)
        h = rng.uniform(70, 200)
        fd.rectangle([x, water_y - h, x + w, water_y], fill=255)
        fd.polygon([(x - 12, water_y - h), (x + w + 12, water_y - h),
                    (x + w * 0.58, water_y - h - 26), (x + w * 0.42, water_y - h - 26)],
                   fill=255)
    composite(base, far, (54, 70, 118), haze=0.70, fog=(48, 62, 106))

    # 牌坊
    mid = new_mask()
    md = ImageDraw.Draw(mid)
    paifang(md, W * 0.40, water_y, 330, 230, rng)
    paifang(md, W * 0.74, water_y, 230, 170, rng)
    composite(base, mid, (16, 21, 44), haze=0.28, fog=(34, 46, 84))

    # 摊位（布篷 + 支柱）
    stall = new_mask()
    sd = ImageDraw.Draw(stall)
    for x, w2 in ((W * 0.12, 150), (W * 0.58, 130), (W * 0.90, 140)):
        y = water_y - 10
        sd.polygon([(x - w2 * 0.6, y), (x + w2 * 0.6, y),
                    (x + w2 * 0.45, y - 62), (x - w2 * 0.45, y - 62)], fill=255)
        sd.rectangle([x - 6, y - 62, x + 6, y], fill=255)
    composite(base, stall, (12, 16, 36), haze=0.3, fog=(30, 40, 76))

    # 灯笼串
    glow = Image.new("L", (W, H), 0)
    gd = ImageDraw.Draw(glow)
    lantern_mask = new_mask()
    ld = ImageDraw.Draw(lantern_mask)
    inner = new_mask()
    idr = ImageDraw.Draw(inner)
    rows = [(H * 0.30, 15, 10), (H * 0.395, 21, 8)]
    for row, (y0, count, r) in enumerate(rows):
        for i in range(count):
            t = i / float(count - 1)
            x = 30 + t * (W - 60)
            y = y0 + math.sin(t * 8 + row * 1.7) * 20
            lantern(ld, x, y, r)
            gd.ellipse([x - r * 3.4, y - r * 3.4, x + r * 3.4, y + r * 3.4], fill=255)
            idr.ellipse([x - r * 0.48, y - r * 0.6, x + r * 0.48, y + r * 0.6], fill=255)
    composite(base, glow.filter(ImageFilter.GaussianBlur(13)), (255, 150, 90),
              haze=0.0, opacity=0.55)
    composite(base, lantern_mask, (20, 17, 32), haze=0.0)
    composite(base, inner, (255, 190, 128), haze=0.0, opacity=0.95)

    # 鬼影
    ghost = new_mask()
    ghd = ImageDraw.Draw(ghost)
    for _ in range(8):
        x = rng.uniform(0, W)
        h = rng.uniform(74, 126)
        y = water_y + rng.uniform(-3, 3)
        ghd.ellipse([x - h * 0.10, y - h, x + h * 0.10, y - h * 0.78], fill=255)
        ghd.polygon([(x - h * 0.24, y), (x + h * 0.24, y),
                     (x + h * 0.11, y - h * 0.76), (x - h * 0.11, y - h * 0.76)], fill=255)
    composite(base, ghost, (8, 10, 22), haze=0.32, fog=(26, 34, 66))

    # 河面 + 倒影
    river = new_mask()
    ImageDraw.Draw(river).rectangle([0, water_y, W, H], fill=255)
    composite(base, river, (14, 26, 50), haze=0.0, opacity=0.6)
    reflection(base, water_y, strength=0.5, fade=250, wave=6, ripple=0.32, tint=(18, 34, 62))

    # 水面波光
    ripple = new_mask()
    rd = ImageDraw.Draw(ripple)
    for _ in range(150):
        y = rng.uniform(water_y + 6, H)
        x = rng.uniform(0, W)
        w = rng.uniform(18, 90)
        rd.rectangle([x, y, x + w, y + rng.uniform(0.8, 1.6)], fill=int(rng.uniform(40, 150)))
    ripple = ripple.filter(ImageFilter.GaussianBlur(1.4))
    soft_light(base, mask_to_arr(ripple), (140, 190, 245), strength=0.22)

    # 前景河岸
    bank = new_mask()
    bd = ImageDraw.Draw(bank)
    bank_pts = [(0, H + 10)]
    for i in range(21):
        bank_pts.append((i * W / 20.0, H * 0.94 + math.sin(i * 1.3) * 9 + rng.uniform(-5, 5)))
    bank_pts.append((W, H + 10))
    bd.polygon(bank_pts, fill=255)
    for _ in range(26):
        x = rng.uniform(0, W)
        h = rng.uniform(40, 120)
        bd.line([(x, H * 0.97), (x + rng.uniform(-14, 14), H * 0.97 - h)],
                fill=255, width=2)
    composite(base, bank, (6, 9, 18), haze=0.05, fog=(16, 24, 46))

    motes(base, rng, count=100, color=(120, 255, 200), rmin=1.0, rmax=3.0,
          y0=0.25, y1=1.0, strength=0.75, blur=2.2)
    return finish(base, npr, vig=0.5, grain_amt=4.5)


def scene_bones(rng, npr):
    """第 4 章 白骨荒冢·九幽：白骨堆 + 枯树 + 惨绿磷火，灰白惨绿。"""
    base = vgrad([(0.0, "#0e1310"), (0.26, "#1d2620"), (0.46, "#2b372c"),
                  (0.66, "#20291f"), (0.84, "#161c16"), (1.0, "#0b0f0c")])
    stars(base, rng, count=140, ymax=0.30, color=(210, 255, 220), bright=0.55)
    draw_moon(base, W * 0.72, H * 0.22, 84, "#e6eedd", "#9fd08e", npr,
              halo_r=440, mottle=0.2, glow=0.8)

    fog_band(base, H * 0.54, 90, (140, 170, 138), strength=0.18, blur=46)

    # 远景枯树
    far = new_mask()
    fd = ImageDraw.Draw(far)
    for x, hh in ((0.10, 340), (0.27, 250), (0.60, 300), (0.90, 390)):
        dead_tree(fd, W * x, H * 0.78, hh, rng, lean=rng.uniform(-0.02, 0.02), limbs=5)
    composite(base, far, (74, 86, 72), haze=0.58, fog=(66, 80, 66))

    # 地面
    ground = new_mask()
    gd = ImageDraw.Draw(ground)
    gpts = [(0, H + 10)]
    for i in range(25):
        gpts.append((i * W / 24.0, H * 0.885 + math.sin(i * 0.9) * 12 + rng.uniform(-8, 8)))
    gpts.append((W, H + 10))
    gd.polygon(gpts, fill=255)
    composite(base, ground, (12, 16, 12), haze=0.14, fog=(34, 42, 34))

    # 中景：骨堆（暗 mound + 浅色骨头）
    mound = new_mask()
    md = ImageDraw.Draw(mound)
    for cx in range(0, W + 200, 190):
        hgt = rng.uniform(50, 110)
        md.polygon([(cx - 170, H * 0.90), (cx + 170, H * 0.90),
                    (cx + 60, H * 0.90 - hgt), (cx - 60, H * 0.90 - hgt * 0.9)], fill=255)
    composite(base, mound, (16, 20, 16), haze=0.16, fog=(46, 56, 46))

    bones = new_mask()
    bd = ImageDraw.Draw(bones)
    for _ in range(40):
        x = rng.uniform(0, W)
        y = H * rng.uniform(0.76, 0.90)
        skull_shape(bd, x, y, rng.uniform(10, 19))
    for _ in range(30):
        x0 = rng.uniform(0, W)
        y = H * rng.uniform(0.80, 0.93)
        long_bone(bd, x0, y, x0 + rng.uniform(-80, 80), y + rng.uniform(-14, 14),
                  rng.uniform(5, 10))
    composite(base, bones, (108, 114, 99), haze=0.3, fog=(70, 80, 66))

    # 近景枯树 + 大骨堆
    near = new_mask()
    nd = ImageDraw.Draw(near)
    dead_tree(nd, W * 0.19, H * 1.04, 640, rng, lean=0.03, limbs=6)
    dead_tree(nd, W * 0.87, H * 1.04, 520, rng, lean=-0.02, limbs=5)
    composite(base, near, (11, 14, 11), haze=0.0)

    big = new_mask()
    bg = ImageDraw.Draw(big)
    for _ in range(12):
        x = rng.uniform(0, W)
        y = H * rng.uniform(0.94, 1.02)
        skull_shape(bg, x, y, rng.uniform(24, 40))
    for _ in range(9):
        x0 = rng.uniform(0, W)
        y = H * rng.uniform(0.96, 1.06)
        long_bone(bg, x0, y, x0 + rng.uniform(-150, 150), y + rng.uniform(-22, 22),
                  rng.uniform(9, 15))
    composite(base, big, (150, 154, 138), haze=0.08, fog=(42, 50, 42))

    # 头骨眼窝（在骨头上挖出暗洞）
    socket = new_mask()
    sd = ImageDraw.Draw(socket)
    for _ in range(12):
        x = rng.uniform(0, W)
        y = H * rng.uniform(0.94, 1.02)
        r = rng.uniform(24, 40)
        sd.ellipse([x - r * 0.55, y - r * 0.55, x - r * 0.12, y - r * 0.12], fill=255)
        sd.ellipse([x + r * 0.12, y - r * 0.55, x + r * 0.55, y - r * 0.12], fill=255)
    socket = socket.filter(ImageFilter.GaussianBlur(3))
    composite(base, socket, (16, 18, 15), haze=0.0, opacity=0.85)

    motes(base, rng, count=140, color=(130, 255, 140), rmin=1.0, rmax=3.2,
          y0=0.32, y1=1.0, strength=0.8, blur=2.4)
    return finish(base, npr, vig=0.5, grain_amt=5.0)


def scene_altar(rng, npr):
    """第 5 章 玄冥祭坛·血祭：巨大祭坛与铜柱 + 血色天光 + 火星，血红黑金。"""
    base = vgrad([(0.0, "#160508"), (0.22, "#4a0d12"), (0.42, "#8a1a12"),
                  (0.60, "#5a1210"), (0.78, "#2c090c"), (1.0, "#0d0406")])
    stars(base, rng, count=80, ymax=0.18, color=(255, 190, 150), bright=0.45)
    draw_moon(base, W * 0.5, H * 0.155, 104, "#f2dcae", "#ff9a52", npr,
              halo_r=560, mottle=0.26, glow=1.05)

    # 天光
    for i in range(5):
        x0 = W * 0.5 + (i - 2) * 42
        beam = new_mask()
        bd = ImageDraw.Draw(beam)
        bd.polygon([(x0 - 22, 0), (x0 + 22, 0), (x0 + 130, H), (x0 - 130, H)], fill=255)
        beam = beam.filter(ImageFilter.GaussianBlur(32))
        soft_light(base, mask_to_arr(beam), (255, 110, 60), strength=0.2)

    # 远景柱林
    far = new_mask()
    fd = ImageDraw.Draw(far)
    for x, s in ((0.13, 0.42), (0.27, 0.28), (0.73, 0.3), (0.87, 0.44)):
        pillar(fd, W * x, H * 0.72, 165 * s, 30 * s, rng)
    composite(base, far, (96, 34, 26), haze=0.62, fog=(140, 54, 32))

    # 中景：主祭坛 + 四柱
    mid = new_mask()
    md = ImageDraw.Draw(mid)
    for x in (0.07, 0.25, 0.75, 0.93):
        pillar(md, W * x, H * 0.87, 330, 46, rng)
    altar_steps(md, W * 0.5, H * 0.90, 520, 200, rng)
    # 台上的铜鼎
    braziers = []
    for bx in (W * 0.5 - 96, W * 0.5 + 96):
        by = H * 0.90 - 200 * 1.16
        md.rectangle([bx - 26, by - 42, bx + 26, by], fill=255)
        md.rectangle([bx - 36, by - 52, bx + 36, by - 42], fill=255)
        for lx in (-1, 0, 1):
            md.rectangle([bx + lx * 17 - 4, by, bx + lx * 17 + 4, by + 20], fill=255)
        braziers.append((bx, by - 54))
    composite(base, mid, (26, 10, 10), haze=0.22, fog=(88, 30, 22))
    for bx, by in braziers:
        add_glow(base, bx, by, 150, (255, 120, 40), 0.75, power=2.2)
        add_glow(base, bx, by, 44, (255, 200, 120), 0.9, power=2.0)

    # 台阶边缘的黑金纹
    trim = new_mask()
    td = ImageDraw.Draw(trim)
    for i in range(5):
        y = H * 0.90 - 200 * i / 5.0
        ww = 520 * (1.0 - 0.16 * i)
        td.rectangle([W * 0.5 - ww * 0.5, y - 3, W * 0.5 + ww * 0.5, y + 3], fill=255)
    composite(base, trim, (198, 150, 60), haze=0.08, opacity=0.8)

    # 近景巨柱
    near = new_mask()
    nd = ImageDraw.Draw(near)
    pillar(nd, W * 0.02, H * 1.04, 600, 78, rng)
    pillar(nd, W * 0.98, H * 1.04, 540, 70, rng)
    composite(base, near, (11, 4, 5), haze=0.0)

    motes(base, rng, count=300, color=(255, 170, 70), rmin=0.6, rmax=2.6,
          y0=0.12, y1=1.0, strength=0.8, blur=1.4)
    return finish(base, npr, vig=0.52, grain_amt=5.0)


def scene_beast(rng, npr):
    """第 6 章 大荒妖王巢·终章：巨兽骨架 + 血池倒影 + 紫色雷云，紫黑妖红。"""
    base = vgrad([(0.0, "#110a24"), (0.24, "#331a4e"), (0.44, "#512258"),
                  (0.64, "#341739"), (0.82, "#1e0f24"), (1.0, "#0a0510")])
    stars(base, rng, count=160, ymax=0.30, color=(210, 180, 255), bright=0.6)

    cloud = new_mask()
    cd = ImageDraw.Draw(cloud)
    for _ in range(30):
        x = rng.uniform(0, W)
        y = rng.uniform(0, H * 0.42)
        r = rng.uniform(60, 200)
        cd.ellipse([x - r, y - r * 0.42, x + r, y + r * 0.42],
                   fill=int(rng.uniform(50, 140)))
    cloud = cloud.filter(ImageFilter.GaussianBlur(42))
    soft_light(base, mask_to_arr(cloud), (140, 70, 210), strength=0.38)

    draw_moon(base, W * 0.18, H * 0.18, 64, "#d8b8ff", "#8a4dff", npr,
              halo_r=360, mottle=0.2, glow=0.75)

    for _ in range(3):
        x = rng.uniform(W * 0.1, W * 0.9)
        y0 = rng.uniform(0, H * 0.10)
        pts = [(x, y0)]
        yy = y0
        while yy < H * 0.55:
            yy += rng.uniform(26, 56)
            pts.append((pts[-1][0] + rng.uniform(-44, 44), yy))
        lm = new_mask()
        ImageDraw.Draw(lm).line(pts, fill=255, width=3)
        lm = lm.filter(ImageFilter.GaussianBlur(2.2))
        soft_light(base, mask_to_arr(lm), (205, 160, 255), strength=0.9)
        soft_light(base, mask_to_arr(lm.filter(ImageFilter.GaussianBlur(15))),
                   (155, 85, 225), strength=0.5)

    blood_y = int(H * 0.765)

    # 远景骨骸（雾化）
    far = new_mask()
    fd = ImageDraw.Draw(far)
    beast_skeleton(fd, rng, W * 0.5, blood_y + 20, 165)
    composite(base, far, (92, 58, 114), haze=0.80, fog=(86, 48, 106))

    # 中景巨兽骨架
    skel = new_mask()
    sd = ImageDraw.Draw(skel)
    beast_skeleton(sd, rng, W * 0.5, blood_y + 40, 330)
    composite(base, skel, (26, 15, 32), haze=0.2, fog=(70, 34, 82))

    # 血池（不规则边界）
    pool = new_mask()
    pd = ImageDraw.Draw(pool)
    pts = []
    for i in range(49):
        t = i / 48.0
        pts.append((t * W, blood_y + math.sin(t * 11 + rng.random()) * 16 + rng.uniform(-9, 9)))
    pd.polygon(pts + [(W, H), (0, H)], fill=255)
    composite(base, pool, (44, 7, 15), haze=0.0, opacity=0.86)
    reflection(base, blood_y, strength=0.5, fade=210, wave=5, ripple=0.32, tint=(66, 10, 20))
    edge = new_mask()
    ImageDraw.Draw(edge).line(pts, fill=255, width=4)
    edge = edge.filter(ImageFilter.GaussianBlur(6))
    soft_light(base, mask_to_arr(edge), (255, 70, 90), strength=0.45)

    bank = new_mask()
    bd = ImageDraw.Draw(bank)
    bpts = [(0, H + 10)]
    for i in range(21):
        bpts.append((i * W / 20.0, H * 0.955 + math.sin(i * 1.1) * 8 + rng.uniform(-4, 4)))
    bpts.append((W, H + 10))
    bd.polygon(bpts, fill=255)
    composite(base, bank, (10, 3, 8), haze=0.0, opacity=0.9)

    motes(base, rng, count=120, color=(255, 90, 120), rmin=0.6, rmax=2.4,
          y0=blood_y / H, y1=1.0, strength=0.55)
    motes(base, rng, count=160, color=(195, 125, 255), rmin=0.7, rmax=2.8,
          y0=0.08, y1=1.0, strength=0.7, blur=1.8)
    return finish(base, npr, vig=0.52, grain_amt=5.0)


def scene_ending(rng, npr):
    """结局：破碎祭坛 + 一道青色剑气冲天 + 漫天光点，冷青白。"""
    base = vgrad([(0.0, "#5f7b88"), (0.20, "#475f6c"), (0.42, "#365060"),
                  (0.62, "#243a48"), (0.80, "#172733"), (1.0, "#0c1a23")])
    stars(base, rng, count=220, ymax=0.42, color=(255, 255, 255), bright=0.55)

    add_glow(base, W * 0.5, H * 0.08, 520, (235, 255, 255), 0.45, power=2.2)

    # 剑气
    beam = new_mask()
    bd = ImageDraw.Draw(beam)
    bd.polygon([(W * 0.5 - 14, 0), (W * 0.5 + 14, 0),
                (W * 0.5 + 88, H), (W * 0.5 - 88, H)], fill=255)
    beam = beam.filter(ImageFilter.GaussianBlur(16))
    soft_light(base, mask_to_arr(beam), (150, 255, 245), strength=0.70)
    core = new_mask()
    ImageDraw.Draw(core).polygon([(W * 0.5 - 6, 0), (W * 0.5 + 6, 0),
                                   (W * 0.5 + 26, H), (W * 0.5 - 26, H)], fill=255)
    core = core.filter(ImageFilter.GaussianBlur(6))
    soft_light(base, mask_to_arr(core), (215, 255, 255), strength=1.0)

    for s in (-1, 1):
        wing = new_mask()
        wd = ImageDraw.Draw(wing)
        wd.polygon([(W * 0.5 + s * 36, H * 0.04), (W * 0.5 + s * 300, H * 0.60),
                    (W * 0.5 + s * 110, H)], fill=255)
        wing = wing.filter(ImageFilter.GaussianBlur(36))
        soft_light(base, mask_to_arr(wing), (120, 220, 240), strength=0.24)

    # 远景残破山脊
    composite(base, ridge_mask(rng, H * 0.64, 140, rough=0.6), (170, 195, 205),
              haze=0.6, fog=(200, 220, 228))

    # 中景：破碎祭坛石块（倾斜、带裂缝）
    mid = new_mask()
    md = ImageDraw.Draw(mid)
    for _ in range(16):
        x = rng.uniform(-40, W)
        bw = rng.uniform(60, 190)
        bh = rng.uniform(50, 170)
        y = H * rng.uniform(0.80, 0.90)
        lean = rng.uniform(-0.18, 0.18)
        top = []
        for k in range(5):
            tx = x + bw * (0.04 + 0.2 * k)
            top.append((tx, y - bh * (0.86 + rng.uniform(-0.14, 0.14)) - lean * tx * 0.2))
        md.polygon([(x, y), (x + bw, y - lean * bw * 0.3)] + top[::-1], fill=255)
    # 碎石
    for _ in range(40):
        x = rng.uniform(0, W)
        y = H * rng.uniform(0.88, 0.97)
        r = rng.uniform(5, 18)
        md.polygon([(x - r, y), (x - r * 0.4, y - r * 0.8), (x + r * 0.6, y - r * 0.6),
                    (x + r, y)], fill=255)
    composite(base, mid, (96, 128, 146), haze=0.32, fog=(190, 210, 220))

    # 近景崩裂台基
    near = new_mask()
    nd = ImageDraw.Draw(near)
    nd.rectangle([0, H * 0.90, W, H], fill=255)
    for x, w2, h2 in ((W * 0.06, 210, 170), (W * 0.38, 250, 210), (W * 0.76, 220, 150)):
        nd.polygon([(x, H), (x + w2, H), (x + w2 * 0.88, H - h2),
                    (x + w2 * 0.08, H - h2 * 0.88)], fill=255)
    composite(base, near, (38, 60, 74), haze=0.05, fog=(120, 150, 165))

    motes(base, rng, count=420, color=(255, 255, 255), rmin=0.6, rmax=2.8,
          y0=0.0, y1=1.0, strength=0.7, blur=1.5)
    motes(base, rng, count=130, color=(165, 255, 245), rmin=1.0, rmax=3.2,
          y0=0.0, y1=0.9, strength=0.7, blur=2.6)
    return finish(base, npr, vig=0.46, grain_amt=4.0)


SCENES = [
    ("title_bg.png", scene_title),
    ("chapter_1.png", scene_forest),
    ("chapter_2.png", scene_dunes),
    ("chapter_3.png", scene_ghost_market),
    ("chapter_4.png", scene_bones),
    ("chapter_5.png", scene_altar),
    ("chapter_6.png", scene_beast),
    ("ending.png", scene_ending),
]


def stats(img: Image.Image):
    a = np.asarray(img, dtype=np.float32)
    lum = (0.299 * a[..., 0] + 0.587 * a[..., 1] + 0.114 * a[..., 2])
    colors = len(np.unique(a.reshape(-1, 3).astype(np.uint8), axis=0))
    return lum.mean(), lum.max(), colors


def main():
    ap = argparse.ArgumentParser(description="生成《百宝小道修 (Pocket Daoist)》插画背景")
    ap.add_argument("--out", default="assets/art", help="输出目录")
    ap.add_argument("--seed", type=int, default=20241109, help="随机种子")
    ap.add_argument("--only", default=None, help="只生成指定文件（名字含此串即可）")
    args = ap.parse_args()

    os.makedirs(args.out, exist_ok=True)
    for idx, (name, fn) in enumerate(SCENES):
        if args.only and args.only not in name:
            continue
        seed = args.seed + idx * 977
        rng = random.Random(seed)
        npr = np.random.default_rng(seed)
        img = fn(rng, npr)
        if not isinstance(img, Image.Image):
            img = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB")
        path = os.path.join(args.out, name)
        img.convert("RGB").save(path, "PNG")
        m, mx, colors = stats(img)
        print("%-16s %-28s size=%s mean_lum=%6.2f max_lum=%5.1f colors=%d"
              % (name, path, img.size, m, mx, colors))


if __name__ == "__main__":
    main()
