import argparse
import json
import os
import random
import time
import urllib.error
import urllib.request
import numpy as np
from PIL import Image, ImageDraw

CHROMA_KEYS = {
    "green": ("#00FF00", (0, 255, 0), "isolated on a flat uniform solid #00FF00 chroma green key background, no floor shadow, no gradient"),
    "magenta": ("#FF00FF", (255, 0, 255), "isolated on a flat uniform solid #FF00FF chroma magenta key background, no floor shadow, no gradient"),
    "white": ("#FFFFFF", (255, 255, 255), "isolated on a pure solid white background, no floor shadow"),
}


def select_optimal_chroma_key(ref_image_path: str = "", prompt_text: str = "") -> str:
    if ref_image_path and os.path.exists(ref_image_path):
        arr = np.array(Image.open(ref_image_path).convert("RGBA"), dtype=np.float32)
        fg = arr[arr[:, :, 3] > 32][:, :3] if arr.shape[2] == 4 else arr.reshape(-1, 3)
        if len(fg) > 0:
            g_dist = np.min(np.linalg.norm(fg - np.array([0.0, 255.0, 0.0], dtype=np.float32), axis=1))
            m_dist = np.min(np.linalg.norm(fg - np.array([255.0, 0.0, 255.0], dtype=np.float32), axis=1))
            return "magenta" if g_dist < m_dist else "green"
    low = prompt_text.lower()
    if any(w in low for w in ("celadon", "green", "cyan", "jade", "teal")):
        return "magenta"
    return "green"


def generate_layout_guide(width: int, height: int, cols: int, rows: int, out_path: str, bg_rgb: tuple[int, int, int] = (255, 255, 255)) -> str:
    im = Image.new("RGB", (width, height), bg_rgb)
    draw = ImageDraw.Draw(im)
    cell_w = width // max(1, cols)
    cell_h = height // max(1, rows)
    guide_col = (180, 180, 180)
    base_col = (140, 180, 220)
    for r in range(rows):
        for c in range(cols):
            x0, y0 = c * cell_w, r * cell_h
            x1, y1 = x0 + cell_w - 1, y0 + cell_h - 1
            mx = max(8, int(cell_w * 0.08))
            my = max(8, int(cell_h * 0.08))
            draw.rectangle([x0 + mx, y0 + my, x1 - mx, y1 - my], outline=guide_col, width=1)
            by = y0 + int(cell_h * 0.90)
            draw.line([(x0 + mx + 6, by), (x1 - mx - 6, by)], fill=base_col, width=1)
    os.makedirs(os.path.dirname(out_path) or ".", exist_ok=True)
    im.save(out_path, "PNG")
    return out_path


STYLE_GLOBAL_NEGATIVE = (
    "photorealistic, 3d render, octane render, unreal engine, pixel art, 8-bit, oil painting, heavy impasto, "
    "dark gritty horror, western fantasy armor, gothic architecture, sci-fi neon, tactical military gear, "
    "readable chinese characters, kanji, hanzi calligraphy, gibberish text, watermark, signature, "
    "floor shadow, cast shadow, drop shadow, dramatic dark backlighting, ambient occlusion dirt, "
    "cropped, cut off, extra limbs, deformed hands, checkerboard background"
)

STYLE_TEMPLATES = {
    "hero_humanoid": {
        "width": 1024,
        "height": 1024,
        "prefix": (
            "Anime cel-shaded 2D Donghua Xianxia game character art, clean ink-outlined style, "
            "3-head stylized chibi proportions, three-quarter top-down 35-degree view facing right, "
            "bright expressive eyes, soft top-left studio daylight, flat 2-tier cel shading, "
            "deep dark-ink outline (2-3px), refined jade cyan, warm gold and crimson palette, "
        ),
        "suffix": ", full body centered with generous margin, pure solid white background, no floor shadow, no text.",
        "negative": "multiple views, grid, chibi blob, realistic 7-head proportions",
    },
    "hero_dango": {
        "width": 1024,
        "height": 1024,
        "prefix": (
            "Cute Brotato-inspired 2D Donghua Xianxia chibi mascot character art, "
            "1.5-head round squishy mochi proportions, three-quarter top-down 35-degree view facing right, "
            "clean deep dark-ink outline (2-3px), bright expressive anime eyes, flat 2-tier cel shading, "
            "soft top-left daylight, "
        ),
        "suffix": ", centered with generous margin, pure solid white background, no floor shadow, no text.",
        "negative": "tall human, realistic anatomy, multiple views, grid",
    },
    "monster_chibi": {
        "width": 1024,
        "height": 1024,
        "prefix": (
            "Anime cel-shaded 2D Donghua Xianxia chibi monster sprite art, cute-fierce stylized 1.8-head proportions, "
            "three-quarter top-down 35-degree view facing right, clean deep dark-ink outline (2-3px), "
            "flat 2-tier cel shading, soft top-left lighting, clear readable silhouette, "
        ),
        "suffix": ", full body centered with wide margin, pure solid white background, no floor shadow, no realistic anatomy, no text.",
        "negative": "realistic dog, realistic beast anatomy, dark horror gore, multiple views, grid",
    },
    "icon_fabao": {
        "width": 1024,
        "height": 1024,
        "prefix": (
            "2D Chinese Xianxia game item icon sticker art, cel-shaded anime style with bold clean deep dark-ink outer outline (4px) "
            "and crisp inner lines (1.5px), 45-degree diagonal presentation, 2-tier cel shading with crisp specular highlight, "
            "vibrant jade, gold and cinnabar tones, "
        ),
        "suffix": ", single isolated object centered with clean margin, pure solid white background, no floor shadow, no readable text.",
        "negative": "multiple items, hand holding object, UI frame, box border, blurry",
    },
    "map_prop": {
        "width": 1024,
        "height": 1024,
        "prefix": (
            "2D Chinese Xianxia arena prop and landmark illustration, three-quarter top-down 35-degree view, "
            "clean medium dark-ink outline (3px) with gentle watercolor wash fill, "
            "muted low-to-medium saturation mineral colors, soft top-left daylight, "
        ),
        "suffix": ", single object centered with bottom margin, pure solid white background, no floor shadow, no readable chinese text or gibberish glyphs.",
        "negative": "thick marker outline, modern object, ground tile background, multiple props",
    },
    "terrain_tile": {
        "width": 512,
        "height": 512,
        "prefix": (
            "Seamless tileable 2D top-down game ground texture, soft Chinese watercolor wash on warm rice-paper base, "
            "ultra low saturation, subtle sparse fine ink grass and pebble accents, flat even illumination, "
        ),
        "suffix": ", seamless edges on all four sides, no thick dark outlines, no shadows, no large rocks, no text.",
        "negative": "characters, props, thick black lines, high contrast, perspective horizon, vignette",
    },
    "story_keyart": {
        "width": 1280,
        "height": 720,
        "prefix": (
            "Traditional Chinese blue-green landscape (Qinglv Shanshui) Donghua illustration, "
            "delicate clean ink linework with luminous watercolor gradients, ethereal golden clouds, "
            "mist-veiled peaks, serene Xianxia atmosphere, "
        ),
        "suffix": ", widescreen 16:9 composition with breathing room for UI overlay, no text, no watermark, no frame.",
        "negative": "dark silhouette flat vector, night horror, modern buildings, UI buttons, frame border",
    },
}


def merge_negative_clauses(*clauses: str) -> str:
    seen: set[str] = set()
    merged: list[str] = []
    for clause in clauses:
        for part in clause.split(","):
            item = part.strip()
            if not item:
                continue
            key = item.lower()
            if key not in seen:
                seen.add(key)
                merged.append(item)
    return ", ".join(merged)


PRESETS = {
    "hero_apose": {
        "width": 832,
        "height": 1216,
        "prompt": (
            "Anime cel-shaded 3D game character concept art, full body standing straight in a symmetrical front-view A-pose, "
            "one solo young Chinese Xianxia male sword cultivator, clean 3.5-head stylized game proportions, "
            "bright expressive eyes, black hair tied in a high topknot with a cyan jade hair crown, "
            "wearing a crisp white and celadon-green Taoist robe with subtle cloud patterns, small golden shoulder pauldrons, "
            "red waist sash with twin flowing crimson ribbons, dark brown boots slightly apart. "
            "Both arms relaxed downward at a 35-degree A-pose away from the torso, open empty hands with fingers separated, no weapon held. "
            "Centered in frame with head and boots completely visible, isolated on a solid pure white background, "
            "flat even studio lighting, no floor shadow, sharp clean edges, high quality game asset reference."
        ),
        "negative": (
            "cropped, cut off feet, cut off head, close-up, multiple views, character sheet grid, text, watermark, "
            "weapon, holding sword, background scenery, floor shadow, dramatic dark shadow, blurry, deformed hands, extra fingers, low quality"
        ),
    },
    "wolf_boss_ref": {
        "width": 1024,
        "height": 1024,
        "prompt": (
            "Anime cel-shaded 3D game monster concept art, full body 3/4 side-front view of a fierce Xianxia silver-furred spirit wolf boss, "
            "sharp wolf ears, glowing cyan spirit eyes, thick azure and cyan flame-like mane around neck and shoulders, "
            "flowing blue flame tail, floating sacred golden ring halo hovering above its back, "
            "sturdy four-legged stance with turquoise spirit flames around ankles, isolated on a solid pure white background, "
            "flat even studio lighting, no floor shadow, clean silhouette, high quality game boss reference."
        ),
        "negative": (
            "cropped, human, humanoid, werewolf standing on two legs, text, watermark, multiple views, grid, "
            "background scenery, floor shadow, blurry, deformed legs, low quality"
        ),
    },
    "hero_sword_floating": {
        "width": 1024,
        "height": 1024,
        "prompt": (
            "Anime cel-shaded 2D game character concept art, one solo young Chinese Xianxia male sword cultivator, clean 3.5-head stylized game proportions, "
            "full body three-quarter top-down side view facing RIGHT, calm confident expression, black hair in a high topknot with a cyan jade hair crown, "
            "white and celadon-green Taoist robe with gold shoulder trim, red waist sash with twin flowing crimson ribbons, dark brown boots. "
            "Both hands are completely empty: his right hand holds a graceful two-finger Taoist sword seal in front of his chest, left arm relaxed at his side. "
            "One glowing cyan jade flying sword floats horizontally behind his shoulders at a slight diagonal angle, completely detached from his body and hands. "
            "Full body from topknot to boots centered in frame with generous margin, pure solid white background, flat even studio lighting, clean dark outline, no floor shadow, no text."
        ),
        "negative": (
            "holding sword, sword in hand, gripping weapon, cropped, cut off feet, multiple characters, grid, text, watermark, "
            "background scenery, floor shadow, blurry, 3d render, extra limbs, deformed hands, checkerboard background"
        ),
    },
    "hero_jinyiwei_gunner": {
        "width": 1024,
        "height": 1024,
        "prompt": (
            "Anime cel-shaded 2D game character concept art, one solo cold-faced Ming Dynasty Jinyiwei imperial gunner warrior, clean 3.5-head stylized game proportions, "
            "full body three-quarter top-down side view facing RIGHT. Sharp stern eyes, black hair tied with a dark iron headband, "
            "wearing an ornate crimson and obsidian-black Ming Feiyufu flying-fish robe with gold cloud embroidery, bronze pauldrons, "
            "leather belt with golden ammunition pouches, split robe skirt showing dark tall boots. "
            "Calmly aiming forward to the right with an ornate Ming bronze-and-gold matchlock flintlock musket held steady at chest height, barrel pointing straight right with faint cyan spirit-fire runes. "
            "A compact carved dragon-head hand cannon pod floats or straps neatly behind his shoulders. "
            "Full body centered with wide margin, pure solid white background, flat studio lighting, crisp dark outline, no floor shadow, no text."
        ),
        "negative": (
            "modern tactical vest, sci-fi armor, smiling, goofy face, cropped, cut off boots, multiple views, grid, text, watermark, "
            "background scenery, floor shadow, blurry, 3d render, deformed gun, bent barrel, checkerboard background"
        ),
    },
    "character_parts_sheet": {
        "width": 1280,
        "height": 768,
        "prompt": (
            "2D skeletal animation character parts sprite sheet of the exact same character from the reference image. "
            "Strictly preserve the original character design, proportions, colors, markings, clothing or fur patterns, lighting, perspective, and crisp cel-shaded line weight. "
            "Decompose the character into complete, cleanly separated, non-overlapping modular rigging parts spaced widely apart on a pure solid white background: "
            "(1) Head + Torso main body core with shoulder/hip sockets neatly closed, (2) Tail or floating back weapon/cloak separated cleanly at the root, "
            "(3) Near-side Front Leg / Front Arm separated with generous rounded shoulder overlap joint, "
            "(4) Far-side Front Leg / Far Arm separated cleanly for rendering behind torso, "
            "(5) Near-side Hind Leg / Near Leg separated with rounded hip overlap joint, "
            "(6) Far-side Hind Leg / Far Leg separated cleanly for rendering behind torso, "
            "(7) Optional Ears or small accessories separated cleanly. "
            "Every limb must stay fully visible and uncropped (avoid fixed cramped bent knees that cannot straighten), with clean rounded overlap caps at every joint pivot so parts can reassemble seamlessly in Godot 2D. "
            "Same scale and line thickness across all pieces, generous whitespace between every part, isolated on a pure solid white background, no text, no labels, no boxes, no grid lines, no floor shadows, no multiple poses."
        ),
        "negative": (
            "multiple poses, walk cycle frames, action showcase, overlapping parts, cut off limbs, missing paws, text, labels, annotations, numbers, arrows, boxes, grid lines, "
            "checkerboard pattern, floor shadows, drop shadow, redesign, inconsistent colors, blurry, low resolution"
        ),
    },
}


def build_qwen_workflow(
    prompt: str,
    negative: str,
    width: int,
    height: int,
    seed: int,
    steps: int,
    use_anime_lora: bool,
    lora_strength: float,
    ref_image_name: str = "",
) -> dict:
    wf = {
        "1": {
            "inputs": {"unet_name": "qwen-image-2.1-Q4_K_M.gguf"},
            "class_type": "UnetLoaderGGUF",
        },
        "2": {
            "inputs": {"clip_name": "qwen3vl_8b_w4a8.safetensors", "type": "qwen_image"},
            "class_type": "CLIPLoader",
        },
        "3": {
            "inputs": {"vae_name": "qwen_image_2.1_vae_bf16.safetensors"},
            "class_type": "VAELoader",
        },
        "4": {
            "inputs": {
                "clip": ["2", 0],
                "prompt": prompt,
                "negative_prompt": negative,
                "resolution": 1024,
            },
            "class_type": "TextEncodeQwenImage21",
        },
        "6": {
            "inputs": {"width": width, "height": height, "batch_size": 1},
            "class_type": "EmptyLatentImage",
        },
        "7": {
            "inputs": {
                "seed": seed,
                "steps": steps,
                "cfg": 1.0,
                "sampler_name": "euler",
                "scheduler": "simple",
                "denoise": 1.0,
                "model": ["1", 0],
                "positive": ["4", 0],
                "negative": ["4", 1],
                "latent_image": ["6", 0],
            },
            "class_type": "KSampler",
        },
        "8": {
            "inputs": {"samples": ["7", 0], "vae": ["3", 0]},
            "class_type": "VAEDecode",
        },
        "9": {
            "inputs": {"filename_prefix": "game_asset", "images": ["8", 0]},
            "class_type": "SaveImage",
        },
    }
    if ref_image_name:
        wf["12"] = {
            "inputs": {"image": ref_image_name},
            "class_type": "LoadImage",
        }
        wf["4"]["inputs"]["vae"] = ["3", 0]
        wf["4"]["inputs"]["images.image_1"] = ["12", 0]
    if use_anime_lora:
        wf["11"] = {
            "inputs": {
                "model": ["1", 0],
                "lora_name": "qwen-image2.1-lora-Anime.safetensors",
                "strength_model": lora_strength,
            },
            "class_type": "LoraLoaderModelOnly",
        }
        wf["7"]["inputs"]["model"] = ["11", 0]
    return wf


def upload_image(server_url: str, local_path: str) -> str:
    boundary = f"----ComfyBoundary{random.randint(100000, 999999)}"
    fname = os.path.basename(local_path)
    with open(local_path, "rb") as fp:
        raw = fp.read()
    body = b"".join([
        f"--{boundary}\r\n".encode("utf-8"),
        f'Content-Disposition: form-data; name="image"; filename="{fname}"\r\n'.encode("utf-8"),
        b"Content-Type: image/png\r\n\r\n",
        raw,
        b"\r\n",
        f"--{boundary}\r\n".encode("utf-8"),
        b'Content-Disposition: form-data; name="overwrite"\r\n\r\ntrue\r\n',
        f"--{boundary}--\r\n".encode("utf-8"),
    ])
    req = urllib.request.Request(
        f"{server_url.rstrip('/')}/upload/image",
        data=body,
        headers={"Content-Type": f"multipart/form-data; boundary={boundary}"},
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        data = json.loads(resp.read().decode("utf-8"))
        return str(data["name"])


def submit_prompt(server_url: str, workflow: dict) -> str:
    payload = json.dumps({"prompt": workflow}).encode("utf-8")
    req = urllib.request.Request(
        f"{server_url.rstrip('/')}/prompt",
        data=payload,
        headers={"Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            return str(data["prompt_id"])
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        print(f"ComfyUI HTTP {e.code} error: {body}")
        raise


def wait_for_output(server_url: str, prompt_id: str, out_path: str, timeout_s: int = 360) -> str:
    deadline = time.time() + timeout_s
    base = server_url.rstrip("/")
    while time.time() < deadline:
        with urllib.request.urlopen(f"{base}/history/{prompt_id}", timeout=15) as resp:
            hist = json.loads(resp.read().decode("utf-8"))
        if prompt_id in hist:
            status = hist[prompt_id].get("status", {})
            if status.get("status_str") == "error":
                raise RuntimeError(f"ComfyUI execution error: {json.dumps(status, ensure_ascii=False)}")
            outputs = hist[prompt_id].get("outputs", {})
            for node_out in outputs.values():
                for img in node_out.get("images", []):
                    fname = img["filename"]
                    sub = img.get("subfolder", "")
                    ftype = img.get("type", "output")
                    url = f"{base}/view?filename={fname}&subfolder={sub}&type={ftype}"
                    os.makedirs(os.path.dirname(out_path) or ".", exist_ok=True)
                    urllib.request.urlretrieve(url, out_path)
                    return out_path
        time.sleep(1.5)
    raise TimeoutError(f"Timed out waiting for ComfyUI prompt {prompt_id}")


def _numbered_out(out_path: str, idx: int, total: int) -> str:
    if total <= 1:
        return out_path
    stem, ext = os.path.splitext(out_path)
    return f"{stem}_{idx}{ext or '.png'}"


def main() -> None:
    ap = argparse.ArgumentParser(description="Submit concept-art prompts to local WSL ComfyUI API.")
    ap.add_argument("--server", default="http://127.0.0.1:8188")
    ap.add_argument("--preset", choices=sorted(PRESETS.keys()), default="")
    ap.add_argument("--style", choices=sorted(STYLE_TEMPLATES.keys()), default="")
    ap.add_argument("--prompt", default="")
    ap.add_argument("--negative", default="")
    ap.add_argument("--width", type=int, default=0)
    ap.add_argument("--height", type=int, default=0)
    ap.add_argument("--steps", type=int, default=20)
    ap.add_argument("--seed", type=int, default=-1)
    ap.add_argument("--count", type=int, default=1)
    ap.add_argument("--lora-strength", type=float, default=0.85)
    ap.add_argument("--no-anime-lora", action="store_true")
    ap.add_argument("--ref-image", default="", help="Optional local reference image uploaded to ComfyUI")
    ap.add_argument("--chroma-key", choices=["auto", "green", "magenta", "white", "none"], default="none")
    ap.add_argument("--layout-guide", default="", help="Optional COLSxROWS layout guide grid, e.g. 3x2 or 6x1")
    ap.add_argument("--workflow-json", default="")
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    preset = PRESETS.get(args.preset, {})
    style_tpl = STYLE_TEMPLATES.get(args.style, {})
    prompt = args.prompt or preset.get("prompt", "")
    if not prompt and not args.workflow_json:
        ap.error("Either --preset, --prompt, or --workflow-json is required.")
    if style_tpl and prompt:
        prompt = f"{style_tpl['prefix']}{prompt.strip().rstrip('.')}{style_tpl['suffix']}"
    if style_tpl:
        negative = merge_negative_clauses(
            STYLE_GLOBAL_NEGATIVE,
            style_tpl.get("negative", ""),
            preset.get("negative", ""),
            args.negative,
        )
    else:
        negative = args.negative or preset.get("negative", "blurry, text, watermark, grid, frame, low quality")
    width = args.width or int(preset.get("width") or style_tpl.get("width") or 1024)
    height = args.height or int(preset.get("height") or style_tpl.get("height") or 1024)

    chosen_key = args.chroma_key
    if chosen_key == "auto":
        chosen_key = select_optimal_chroma_key(args.ref_image, prompt)
    if chosen_key in CHROMA_KEYS:
        _, _, key_clause = CHROMA_KEYS[chosen_key]
        prompt = prompt.replace("pure solid white background", key_clause).replace("solid pure white background", key_clause)
        if key_clause not in prompt:
            prompt = f"{prompt.rstrip('. ')}. {key_clause}."

    if args.layout_guide and "x" in args.layout_guide.lower():
        parts = args.layout_guide.lower().split("x", 1)
        cols, rows = int(parts[0]), int(parts[1])
        guide_path = os.path.splitext(args.out)[0] + "_layout_guide.png"
        generate_layout_guide(width, height, cols, rows, guide_path)
        print(f"Generated layout guide ({cols}x{rows}) -> {guide_path}")

    ref_name = upload_image(args.server, args.ref_image) if args.ref_image else ""

    for idx in range(1, max(1, args.count) + 1):
        seed = (args.seed + idx - 1) if args.seed >= 0 else random.randint(1, 2**31 - 1)
        if args.workflow_json:
            with open(args.workflow_json, "r", encoding="utf-8") as fp:
                wf = json.load(fp)
        else:
            wf = build_qwen_workflow(
                prompt=prompt,
                negative=negative,
                width=width,
                height=height,
                seed=seed,
                steps=args.steps,
                use_anime_lora=not args.no_anime_lora,
                lora_strength=args.lora_strength,
                ref_image_name=ref_name,
            )
        pid = submit_prompt(args.server, wf)
        target = _numbered_out(args.out, idx, args.count)
        saved = wait_for_output(args.server, pid, target)
        print(f"Saved ComfyUI output ({width}x{height}, seed={seed}) -> {saved}")


if __name__ == "__main__":
    main()
