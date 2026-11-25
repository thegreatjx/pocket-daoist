import argparse
import json
import math
import os
import random
import time
import urllib.error
import urllib.request
from PIL import Image


def upload_image(server_url: str, local_path: str) -> str:
    boundary = f"----ComfyWanBoundary{random.randint(100000, 999999)}"
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


def build_wan_i2v_workflow(
    prompt: str,
    negative: str,
    input_image_name: str,
    width: int,
    height: int,
    length: int,
    seed: int,
    steps: int,
    cfg: float,
    shift: float,
    prefix: str,
) -> dict:
    return {
        "1": {
            "class_type": "UnetLoaderGGUF",
            "inputs": {"unet_name": "Wan2.2-TI2V-5B-Q4_K_M.gguf"},
        },
        "2": {
            "class_type": "LoraLoaderModelOnly",
            "inputs": {
                "model": ["1", 0],
                "lora_name": "Wan22_TI2V_5B_Turbo_lora_rank_64_fp16.safetensors",
                "strength_model": 1.0,
            },
        },
        "3": {
            "class_type": "ModelSamplingSD3",
            "inputs": {"model": ["2", 0], "shift": shift},
        },
        "4": {
            "class_type": "CLIPLoader",
            "inputs": {
                "clip_name": "umt5_xxl_fp8_e4m3fn_scaled.safetensors",
                "type": "wan",
                "device": "default",
            },
        },
        "5": {
            "class_type": "CLIPTextEncode",
            "inputs": {"clip": ["4", 0], "text": prompt},
        },
        "6": {
            "class_type": "CLIPTextEncode",
            "inputs": {"clip": ["4", 0], "text": negative},
        },
        "7": {
            "class_type": "VAELoader",
            "inputs": {"vae_name": "wan2.2_vae.safetensors"},
        },
        "8": {
            "class_type": "LoadImage",
            "inputs": {"image": input_image_name},
        },
        "9": {
            "class_type": "Wan22ImageToVideoLatent",
            "inputs": {
                "vae": ["7", 0],
                "width": width,
                "height": height,
                "length": length,
                "batch_size": 1,
                "start_image": ["8", 0],
            },
        },
        "10": {
            "class_type": "KSampler",
            "inputs": {
                "model": ["3", 0],
                "seed": seed,
                "steps": steps,
                "cfg": cfg,
                "sampler_name": "uni_pc",
                "scheduler": "simple",
                "positive": ["5", 0],
                "negative": ["6", 0],
                "latent_image": ["9", 0],
                "denoise": 1.0,
            },
        },
        "11": {
            "class_type": "VAEDecode",
            "inputs": {"samples": ["10", 0], "vae": ["7", 0]},
        },
        "12": {
            "class_type": "SaveImage",
            "inputs": {
                "images": ["11", 0],
                "filename_prefix": f"wan_sprite/{prefix}",
            },
        },
    }


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


def wait_and_download_frames(
    server_url: str,
    prompt_id: str,
    out_dir: str,
    timeout_s: int = 600,
) -> list[str]:
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
            saved_paths: list[str] = []
            os.makedirs(out_dir, exist_ok=True)
            idx = 0
            for node_out in outputs.values():
                for img in node_out.get("images", []):
                    fname = img["filename"]
                    sub = img.get("subfolder", "")
                    ftype = img.get("type", "output")
                    url = f"{base}/view?filename={fname}&subfolder={sub}&type={ftype}"
                    dst = os.path.join(out_dir, f"frame_{idx:06d}.png")
                    urllib.request.urlretrieve(url, dst)
                    saved_paths.append(dst)
                    idx += 1
            if saved_paths:
                return saved_paths
        time.sleep(2.0)
    raise TimeoutError(f"Timed out waiting for ComfyUI prompt {prompt_id}")


def build_contact_sheet(frame_paths: list[str], out_path: str, thumb_w: int = 160) -> str:
    n = len(frame_paths)
    cols = max(1, math.ceil(math.sqrt(n)))
    rows = max(1, math.ceil(n / cols))
    with Image.open(frame_paths[0]) as first:
        w0, h0 = first.size
    thumb_h = max(1, round(thumb_w * h0 / max(1, w0)))
    sheet = Image.new("RGB", (cols * thumb_w, rows * thumb_h), (24, 24, 24))
    for i, path in enumerate(frame_paths):
        r, c = divmod(i, cols)
        with Image.open(path) as im:
            thumb = im.convert("RGB").resize((thumb_w, thumb_h), Image.Resampling.LANCZOS)
            sheet.paste(thumb, (c * thumb_w, r * thumb_h))
    sheet.save(out_path, "PNG")
    return out_path


def main() -> None:
    ap = argparse.ArgumentParser(description="Generate I2V frames via local ComfyUI Wan 2.2 TI2V 5B.")
    ap.add_argument("--server", default="http://127.0.0.1:8188")
    ap.add_argument("--input-image", required=True)
    ap.add_argument("--prompt", default="")
    ap.add_argument("--prompt-file", default="")
    ap.add_argument(
        "--negative",
        default=(
            "blurry, low quality, jpeg artifacts, text, watermark, extra limbs, deformed hands, "
            "deformed face, camera movement, zoom, pan, background scenery, floor, shadow, "
            "gradient background, 3d render, realistic"
        ),
    )
    ap.add_argument("--width", type=int, default=640)
    ap.add_argument("--height", type=int, default=832)
    ap.add_argument("--length", type=int, default=49)
    ap.add_argument("--steps", type=int, default=4)
    ap.add_argument("--cfg", type=float, default=1.0)
    ap.add_argument("--shift", type=float, default=8.0)
    ap.add_argument("--seed", type=int, default=-1)
    ap.add_argument("--prefix", default="wan_clip")
    ap.add_argument("--out-dir", required=True)
    args = ap.parse_args()

    prompt = args.prompt
    if args.prompt_file:
        with open(args.prompt_file, "r", encoding="utf-8") as fp:
            prompt = fp.read().strip()
    if not prompt:
        ap.error("Either --prompt or --prompt-file is required.")

    seed = args.seed if args.seed >= 0 else random.randint(1, 2**31 - 1)
    uploaded_name = upload_image(args.server, args.input_image)
    wf = build_wan_i2v_workflow(
        prompt=prompt,
        negative=args.negative,
        input_image_name=uploaded_name,
        width=args.width,
        height=args.height,
        length=args.length,
        seed=seed,
        steps=args.steps,
        cfg=args.cfg,
        shift=args.shift,
        prefix=args.prefix,
    )
    pid = submit_prompt(args.server, wf)
    frames = wait_and_download_frames(args.server, pid, args.out_dir)
    sheet_path = os.path.join(args.out_dir, "contact_sheet.png")
    build_contact_sheet(frames, sheet_path)
    print(json.dumps({
        "status": "ok",
        "prompt_id": pid,
        "seed": seed,
        "frames": len(frames),
        "out_dir": args.out_dir,
        "contact_sheet": sheet_path,
    }))


if __name__ == "__main__":
    main()
