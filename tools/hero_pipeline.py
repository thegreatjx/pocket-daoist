"""主角美术流水线：主图 -> 512 透明 master -> Wan i2v -> 抠像对齐 -> atlas 打包。

用法：
  python tools/hero_pipeline.py master --still .tmp/hero/qingyao/still.png
  python tools/hero_pipeline.py run    --id cloud_danxia --action idle
  python tools/hero_pipeline.py run    --id cloud_danxia --action idle --from-raw .tmp/hero/cloud_danxia/raw_idle

产物：assets/v2/hero/anim/hero_<id>_<action>-atlas-00.png 与同名 .json

所有影响产物的参数一律锁在下方 SPEC 里，不提供命令行覆盖；打包后自动按 SPEC 校验，
不符即失败。要改规格只能改 SPEC 这一处，保证每次走的都是同一条流程。
"""
import argparse
import json
import os
import shutil
import subprocess
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from process_ai_spritesheets import _cutout_cell_rgba

SKILL = os.path.join(ROOT, ".agents", "skills", "video2dsprite", "scripts")

# 唯一的规格真相源：改这里才叫改流程，命令行不能覆盖。
SPEC = {
    "master_side": 512,
    "body_fraction": 0.90,
    "feet_y": 484,
    "i2v_canvas": (640, 832),
    "i2v_duration_sec": 2.0,
    "i2v_frames": 49,
    "i2v_steps": 4,
    "matte_key": "auto",
    "despill": "auto",
    "erode": 0,
    "allow_key_residue": False,
    "atlas_fps": 24.0,
    "atlas_schema": "3.0",
    "atlas_body_height_px": 256,
    "atlas_max_side": 320,
    "atlas_loop": True,
    "atlas_formats": "png",
}

CANVAS = SPEC["i2v_canvas"]
MASTER_SIDE = SPEC["master_side"]
BODY_FRACTION = SPEC["body_fraction"]
FEET_Y = SPEC["feet_y"]


def _py(*args: str, log) -> dict:
    cmd = [sys.executable, *args]
    log.write("$ " + " ".join(cmd) + "\n")
    log.flush()
    proc = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace")
    log.write(proc.stdout + proc.stderr + "\n")
    log.flush()
    if proc.returncode != 0:
        raise SystemExit(f"步骤失败（{proc.returncode}）：{os.path.basename(args[0])}\n{proc.stderr.strip()[-800:]}")
    for line in reversed(proc.stdout.strip().splitlines()):
        line = line.strip()
        if line.startswith("{"):
            try:
                return json.loads(line)
            except json.JSONDecodeError:
                continue
    return {}


def build_master(still: str, out: str) -> str:
    rgb = np.array(Image.open(still).convert("RGB"), dtype=np.uint8)
    cut = Image.fromarray(_cutout_cell_rgba(rgb), "RGBA")
    cut = cut.crop(cut.getbbox())
    body_h = int(round(MASTER_SIDE * BODY_FRACTION))
    scale = body_h / cut.height
    cut = cut.resize((max(1, int(round(cut.width * scale))), body_h), Image.LANCZOS)
    canvas = Image.new("RGBA", (MASTER_SIDE, MASTER_SIDE), (0, 0, 0, 0))
    canvas.alpha_composite(cut, (MASTER_SIDE // 2 - cut.width // 2, FEET_Y - body_h))
    os.makedirs(os.path.dirname(out) or ".", exist_ok=True)
    canvas.save(out, "PNG")
    return out


def verify_against_spec(pkg: str, name: str, meta: dict) -> None:
    """打包后按 SPEC 校验产物，不符则直接失败，防止规格静默漂移。"""
    problems = []
    if abs(float(meta.get("fps", 0.0)) - SPEC["atlas_fps"]) > 1e-6:
        problems.append(f"fps={meta.get('fps')}，应为 {SPEC['atlas_fps']}")
    if bool(meta.get("loop")) != SPEC["atlas_loop"]:
        problems.append(f"loop={meta.get('loop')}，应为 {SPEC['atlas_loop']}")
    if str(meta.get("schemaVersion")) != SPEC["atlas_schema"]:
        problems.append(f"schemaVersion={meta.get('schemaVersion')}，应为 {SPEC['atlas_schema']}")
    pages = (meta.get("fallback") or {}).get("pages") or []
    if not pages:
        problems.append("manifest 缺少 fallback.pages")
    cell_size = (meta.get("fallback") or {}).get("cellSize") or [0, 0]
    cell_w, cell_h = int(cell_size[0]), int(cell_size[1])
    if cell_h < SPEC["atlas_body_height_px"]:
        problems.append(f"单帧高 {cell_h} < 主体高度 {SPEC['atlas_body_height_px']}")
    if max(cell_w, cell_h) > SPEC["atlas_max_side"]:
        problems.append(f"单帧 {cell_w}x{cell_h} 超出 max-side {SPEC['atlas_max_side']}")
    for page in pages:
        atlas = os.path.join(pkg, str(page.get("file", "")))
        if not os.path.exists(atlas):
            problems.append(f"图集文件缺失：{page.get('file')}")
    if problems:
        raise SystemExit("hero_pipeline: 产出不符合 SPEC：\n  - " + "\n  - ".join(problems))


def main() -> None:
    ap = argparse.ArgumentParser(description="Hero still -> idle atlas pipeline.")
    ap.add_argument("command", choices=["master", "run"])
    ap.add_argument("--still", default="", help="1024 主图（白底）")
    ap.add_argument("--id", default="", help="角色 id，例如 cloud_danxia")
    ap.add_argument("--action", default="idle")
    ap.add_argument("--workdir", default="")
    ap.add_argument("--subject", default="", help="给 i2v 提示词的英文角色描述")
    ap.add_argument("--extra", default="", help="追加到 i2v 动作提示词的英文补充指令")
    ap.add_argument("--seed", type=int, default=-1)
    ap.add_argument("--from-raw", default="", help="跳过生视频，直接用已有的 Wan 原始帧目录")
    ap.add_argument("--server", default="http://127.0.0.1:8188")
    ap.add_argument("--out-dir", default=os.path.join("assets", "v2", "hero", "anim"))
    args = ap.parse_args()

    if not args.id:
        ap.error("--id 必填")
    work = args.workdir or os.path.join(".tmp", "hero", args.id)
    os.makedirs(work, exist_ok=True)

    if args.command == "master":
        if not args.still:
            ap.error("master 需要 --still")
        print(json.dumps({"master": build_master(args.still, os.path.join(work, "master.png"))}, ensure_ascii=False))
        return

    log_path = os.path.join(work, f"run_{args.action}.log")
    with open(log_path, "w", encoding="utf-8") as log:
        master = os.path.join(work, "master.png")
        if not os.path.exists(master):
            if not args.still:
                ap.error("没有 master.png，先跑 master 子命令或给 --still")
            build_master(args.still, master)
            log.write(f"built master {master}\n")

        job = os.path.join(work, f"job_{args.action}")
        if not os.path.exists(os.path.join(job, "registration_job.json")):
            prep = ["--master", master, "--action", args.action,
                    "--canvas", f"{CANVAS[0]},{CANVAS[1]}",
                    "--duration", str(SPEC["i2v_duration_sec"]),
                    "--output-dir", job]
            if args.subject:
                prep += ["--subject", args.subject]
            if args.extra:
                prep += ["--extra", args.extra]
            _py(os.path.join(SKILL, "prepare_i2v_input.py"), "prepare", *prep, log=log)

        raw = args.from_raw or os.path.join(work, f"raw_{args.action}")
        if not args.from_raw:
            wan = [os.path.join(ROOT, "tools", "comfyui_wan_i2v.py"),
                   "--server", args.server,
                   "--input-image", os.path.join(job, "input.png"),
                   "--prompt-file", os.path.join(job, "prompt.txt"),
                   "--out-dir", raw,
                   "--width", str(CANVAS[0]), "--height", str(CANVAS[1]),
                   "--length", str(SPEC["i2v_frames"]), "--steps", str(SPEC["i2v_steps"])]
            if args.seed >= 0:
                wan += ["--seed", str(args.seed)]
            _py(*wan, log=log)

        clean = os.path.join(work, f"clean_{args.action}")
        shutil.rmtree(clean, ignore_errors=True)
        clean_args = ["--raw-dir", raw, "--output-dir", clean, "--key", SPEC["matte_key"],
                      "--despill-mode", SPEC["despill"]]
        if SPEC["erode"]:
            clean_args += ["--erode", str(SPEC["erode"])]
        _py(os.path.join(SKILL, "video2dsprite.py"), "clean", *clean_args, log=log)

        reg = os.path.join(work, f"reg_{args.action}")
        shutil.rmtree(reg, ignore_errors=True)
        _py(os.path.join(SKILL, "register_clip.py"), "apply",
            "--job", os.path.join(job, "registration_job.json"),
            "--frames", clean, "--output-dir", reg, "--lock", "feet", log=log)

        name = f"hero_{args.id}_{args.action}"
        pkg = os.path.join(work, f"pkg_{args.action}")
        shutil.rmtree(pkg, ignore_errors=True)
        pkg_args = [os.path.join(SKILL, "engine_export.py"), "package",
                    "--clean-dir", os.path.join(reg, "frames"),
                    "--registration", os.path.join(reg, "registration.json"),
                    "--output-dir", pkg, "--name", name,
                    "--fps", str(SPEC["atlas_fps"]), "--loop",
                    "--formats", SPEC["atlas_formats"],
                    "--body-height-px", str(SPEC["atlas_body_height_px"]),
                    "--max-side", str(SPEC["atlas_max_side"]), "--crop-union"]
        if SPEC["allow_key_residue"]:
            pkg_args.append("--allow-key-residue")
        _py(*pkg_args, log=log)
        os.makedirs(os.path.join(ROOT, args.out_dir), exist_ok=True)
        pairs = ((os.path.join(pkg, "animation.json"), f"{name}.json"),
                 (os.path.join(pkg, f"{name}-atlas-00.png"), f"{name}-atlas-00.png"))
        for src, dst in pairs:
            shutil.copyfile(src, os.path.join(ROOT, args.out_dir, dst))
        pkg = os.path.join(ROOT, args.out_dir)

    meta = json.load(open(os.path.join(pkg, f"{name}.json"), encoding="utf-8"))
    verify_against_spec(pkg, name, meta)
    report = {
        "spec": SPEC,
        "manifest": {
            "fps": meta.get("fps"),
            "frameCount": meta.get("frameCount"),
            "cell": meta.get("fallback", {}).get("cellSize"),
            "loop": meta.get("loop"),
            "schemaVersion": meta.get("schemaVersion"),
        },
        "identity": {"id": args.id, "action": args.action, "from_raw": bool(args.from_raw)},
    }
    with open(os.path.join(work, f"spec_{args.action}.json"), "w", encoding="utf-8") as f:
        json.dump(report, f, ensure_ascii=False, indent=2)
    print(json.dumps({
        "atlas": os.path.join(pkg, meta["fallback"]["pages"][0]["file"]),
        "meta": os.path.join(pkg, f"{name}.json"),
        "frames": meta["frameCount"],
        "cell": meta["fallback"]["cellSize"],
        "fps": meta["fps"],
        "reviewStatus": meta.get("reviewStatus"),
        "log": log_path,
    }, ensure_ascii=False))


if __name__ == "__main__":
    main()
