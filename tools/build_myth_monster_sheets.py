import math
import os
import sys
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_animated_sheets as bas

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPRITES_DIR = os.path.join(PROJECT_ROOT, "assets", "sprites")
ARTIFACT_DIR = r"C:\Users\jiang\.gemini\antigravity\brain\8a3fb7cb-53d3-4aeb-a29a-18c5859c23dc"
CUTOUTS_DIR = os.path.join(ARTIFACT_DIR, "cutouts")


def load_cutout_rgba(name: str) -> np.ndarray:
    p = os.path.join(CUTOUTS_DIR, f"{name}_cutout.png")
    im = Image.open(p).convert("RGBA")
    return np.array(im, dtype=np.float32)


def build_jiangshi_sheet() -> None:
    rgba = load_cutout_rgba("jiangshi")
    h, w, _ = rgba.shape
    yy0, xx0 = np.mgrid[0:h, 0:w].astype(np.float32)
    xx0 /= float(w)
    yy0 /= float(h)

    # Talisman mask on forehead: roughly x in [0.42, 0.58], y in [0.18, 0.38]
    talisman_mask = bas.rect_mask(xx0, yy0, 0.40, 0.60, 0.16, 0.36, feather=0.015)
    # Robe hem mask: y in [0.70, 0.95]
    robe_mask = np.clip((yy0 - 0.70) / 0.15, 0.0, 1.0) * np.clip((xx0 - 0.30) / 0.10, 0.0, 1.0) * np.clip((0.74 - xx0) / 0.10, 0.0, 1.0)

    def jiangshi_hop(xx, yy, idx, total):
        p = (float(idx) / float(total)) * 2.0 * math.pi
        s = math.sin(p)
        c = math.cos(p)

        # Hopping arc: rapid leap upward, brief hangtime, crisp landing
        hop_y = -abs(math.sin(p)) * 0.055
        squash_y = 0.020 * max(0.0, -c)  # squash right around landing

        # Body bones
        bones = [
            # Head + Cap (steady forward gaze with tiny hop inertia)
            bas.bone_field(xx, yy, (0.52, 0.25), (0.52, 0.25), (0.22, 0.18), c * 0.03, (0.0, hop_y * 1.0)),
            # Outstretched arms (held horizontally forward, slight rhythmic bounce)
            bas.bone_field(xx, yy, (0.52, 0.45), (0.52, 0.45), (0.24, 0.15), -s * 0.05, (s * 0.012, hop_y * 0.95)),
            # Legs & Boots tucked during air, extending for landing
            bas.bone_field(xx, yy, (0.52, 0.80), (0.52, 0.82), (0.18, 0.15), 0.0, (0.0, hop_y * 0.85 + squash_y)),
        ]
        dx, dy = bas.blend_bones(xx, yy, bones, base_shift=(0.0, hop_y), base_angle=0.0, base_weight=0.70)

        # Dynamic secondary motion: fluttering yellow talisman paper
        dy += talisman_mask * math.sin(p - 1.2) * 0.032
        dx += talisman_mask * math.cos(p - 1.2) * 0.018

        # Robe hem trailing motion
        dy += robe_mask * math.sin(p - 0.7) * 0.018

        return bas.warp_rgba(rgba, dx, dy)

    bas.render_sheet(rgba, jiangshi_hop, num_frames=8, target_size=96, out_name="anim_jiangshi_run.png")


def build_jinchan_sheet() -> None:
    rgba = load_cutout_rgba("jinchan")
    h, w, _ = rgba.shape
    yy0, xx0 = np.mgrid[0:h, 0:w].astype(np.float32)
    xx0 /= float(w)
    yy0 /= float(h)

    # Throat poison sac mask
    throat_mask = bas.rect_mask(xx0, yy0, 0.35, 0.65, 0.40, 0.68, feather=0.03)

    def jinchan_hop(xx, yy, idx, total):
        p = (float(idx) / float(total)) * 2.0 * math.pi
        s = math.sin(p)
        c = math.cos(p)

        # Heavy toad crouch & hop
        hop_y = -abs(math.sin(p)) * 0.042
        crouch = max(0.0, -c) * 0.025

        # Limb stride
        bones = [
            # Solid armored back & head
            bas.bone_field(xx, yy, (0.50, 0.40), (0.50, 0.40), (0.30, 0.22), 0.0, (0.0, hop_y)),
            # Front left leg
            bas.bone_field(xx, yy, (0.24, 0.66), (0.22, 0.74), (0.16, 0.14), -s * 0.28, (-s * 0.022, crouch)),
            # Front right leg
            bas.bone_field(xx, yy, (0.76, 0.66), (0.78, 0.74), (0.16, 0.14), s * 0.28, (s * 0.022, crouch)),
            # Rear center leg
            bas.bone_field(xx, yy, (0.50, 0.72), (0.50, 0.80), (0.15, 0.12), 0.0, (0.0, hop_y * 0.6 + crouch)),
        ]
        dx, dy = bas.blend_bones(xx, yy, bones, base_shift=(0.0, hop_y), base_angle=c * 0.03, base_weight=0.75)

        # Swelling throat sac respiration
        breath = math.sin(p * 2.0) * 0.018
        dx += throat_mask * (xx - 0.50) * breath * 1.5
        dy += throat_mask * breath

        return bas.warp_rgba(rgba, dx, dy)

    bas.render_sheet(rgba, jinchan_hop, num_frames=8, target_size=96, out_name="anim_jinchan_run.png")


def build_shenjing_sheet() -> None:
    rgba = load_cutout_rgba("shenjing")
    h, w, _ = rgba.shape
    yy0, xx0 = np.mgrid[0:h, 0:w].astype(np.float32)
    xx0 /= float(w)
    yy0 /= float(h)

    # Leaf sprout & berries mask at top of head
    sprout_mask = bas.rect_mask(xx0, yy0, 0.32, 0.68, 0.06, 0.30, feather=0.02)
    # Left root leg vs right root leg
    m_leg_l = bas.rect_mask(xx0, yy0, 0.25, 0.50, 0.68, 0.96, feather=0.015)
    m_leg_r = bas.rect_mask(xx0, yy0, 0.50, 0.75, 0.68, 0.96, feather=0.015)

    def shenjing_run(xx, yy, idx, total):
        p = (float(idx) / float(total)) * 2.0 * math.pi
        s = math.sin(p)
        c = math.cos(p)
        bob = -abs(s) * 0.016

        # Swift little root child run
        bones = [
            # Head and chubby body with slight tilt/waddle
            bas.bone_field(xx, yy, (0.50, 0.45), (0.50, 0.45), (0.22, 0.22), c * 0.06, (0.0, bob)),
            # Left root leg
            bas.bone_field(xx, yy, (0.38, 0.70), (0.36, 0.82), (0.13, 0.14), -s * 0.42, (s * 0.032, -max(0.0, c) * 0.028)),
            # Right root leg
            bas.bone_field(xx, yy, (0.62, 0.70), (0.64, 0.82), (0.13, 0.14), s * 0.42, (-s * 0.032, -max(0.0, -c) * 0.028)),
        ]
        dx, dy = bas.blend_bones(xx, yy, bones, base_shift=(0.0, bob), base_angle=c * 0.04, base_weight=0.70)

        # Herbal sprout & berries waving in the wind
        dx += sprout_mask * math.sin(p - 0.9) * 0.035
        dy += sprout_mask * math.cos(p - 0.9) * 0.015

        return bas.warp_rgba(rgba, dx, dy)

    bas.render_sheet(rgba, shenjing_run, num_frames=8, target_size=96, out_name="anim_shenjing_run.png")


def build_huodou_sheet() -> None:
    rgba = load_cutout_rgba("huodou")
    h, w, _ = rgba.shape
    yy0, xx0 = np.mgrid[0:h, 0:w].astype(np.float32)
    xx0 /= float(w)
    yy0 /= float(h)

    # Tail plume mask
    tail_mask = bas.rect_mask(xx0, yy0, 0.06, 0.38, 0.16, 0.58, feather=0.03)

    def huodou_run(xx, yy, idx, total):
        p = (float(idx) / float(total)) * 2.0 * math.pi
        s = math.sin(p)
        c = math.cos(p)
        bob = -abs(s) * 0.015

        # Fierce quad gallop
        bones = [
            # Head and fiery neck
            bas.bone_field(xx, yy, (0.70, 0.36), (0.74, 0.36), (0.22, 0.20), -c * 0.06, (0.0, bob)),
            # Front paws
            bas.bone_field(xx, yy, (0.72, 0.65), (0.76, 0.78), (0.16, 0.15), s * 0.44, (-s * 0.032, -max(0.0, -c) * 0.026)),
            # Hind paws
            bas.bone_field(xx, yy, (0.38, 0.65), (0.35, 0.78), (0.16, 0.15), -s * 0.44, (s * 0.032, -max(0.0, c) * 0.026)),
        ]
        dx, dy = bas.blend_bones(xx, yy, bones, base_shift=(0.0, bob), base_angle=c * 0.03, base_weight=0.65)

        # Dynamic flaming tail undulation
        dy += tail_mask * np.sin(p - xx * 12.0) * 0.036
        dx += tail_mask * np.cos(p - xx * 9.0) * 0.016

        return bas.warp_rgba(rgba, dx, dy)

    bas.render_sheet(rgba, huodou_run, num_frames=8, target_size=96, out_name="anim_huodou_run.png")


def make_preview() -> None:
    sheets = [
        ("anim_jiangshi_run.png", "符箓小僵 (Hop Jiangshi - 清代志怪跳僵)"),
        ("anim_jinchan_run.png", "三足金蟾 (Jin Chan - 山海经/民间神话财毒蟾)"),
        ("anim_shenjing_run.png", "参精童子 (Shen Jing - 志怪灵草地灵参精)"),
        ("anim_huodou_run.png", "祸斗神兽 (Huo Dou - 山海经食火凶犬)"),
    ]
    canvas = Image.new("RGBA", (800, 480), (32, 42, 38, 255))
    from PIL import ImageDraw
    draw = ImageDraw.Draw(canvas)

    y = 16
    for fname, desc in sheets:
        p = os.path.join(SPRITES_DIR, fname)
        if not os.path.exists(p):
            continue
        im = Image.open(p).convert("RGBA")
        draw.text((16, y), desc, fill=(230, 220, 180, 255))
        canvas.paste(im, (16, y + 20), im)
        y += 96 + 28

    out_p = os.path.join(SPRITES_DIR, "preview_myth_monsters.png")
    canvas.save(out_p)
    print(f"Saved preview contact sheet -> {out_p}")


def main() -> None:
    print("Building myth monster animated sheets...")
    build_jiangshi_sheet()
    build_jinchan_sheet()
    build_shenjing_sheet()
    build_huodou_sheet()
    make_preview()
    print("All myth monster sheets built successfully!")


if __name__ == "__main__":
    main()
