#!/usr/bin/env python3
"""分层快速检查：按实际改动范围只跑必要校验，输出压缩成几行。

用法：
  python tools/quick_check.py          # 自动按改动选择，通常 6 秒内
  python tools/quick_check.py --full   # 交付前全量：含 60 秒长跑 smoke
  python tools/quick_check.py --list   # 只打印本次会跑哪些检查

分层：
  audit  0.5s  data/ 与 assets/ 改动时跑资产巡检
  v2     5s    任何 .gd/.tscn/.gdshader/project.godot 改动，解析 + 核心系统
  flow   15s   流程、场景、自动加载改动时，全流程集成（跳过长跑 smoke）
"""
import os
import re
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GODOT = os.environ.get("GODOT", "godot")

# 已知的历史告警：arcana 引用了尚未实现的反应 ID。新出现的告警才会让检查失败。
KNOWN_AUDIT_ERRORS = ("react_molten_forge", "react_shatter", "react_miasma_arc")

CODE_EXTS = (".gd", ".tscn", ".tres", ".gdshader")
FLOW_PREFIXES = ("scripts/autoload/", "scenes/", "scripts/ui/")
FLOW_SCRIPTS = {
    "scripts/main.gd", "scripts/player.gd", "scripts/spawner.gd",
    "scripts/stage_director.gd", "scripts/upgrade_manager.gd",
    "scripts/enemy.gd", "scripts/game_over_ui.gd", "scripts/title.gd",
    "scripts/pause_menu.gd", "scripts/chest_ui.gd", "scripts/upgrade_ui.gd",
}


def changed_paths():
    proc = subprocess.run(
        ["git", "-c", "core.quotepath=false", "status", "--porcelain"],
        cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace")
    paths = []
    for line in proc.stdout.splitlines():
        if len(line) < 4:
            continue
        path = line[3:].strip().strip('"')
        if " -> " in path:
            path = path.split(" -> ")[-1].strip().strip('"')
        paths.append(path)
    return paths


def decide(paths):
    stages = []
    if any(p.startswith(("data/", "assets/")) for p in paths):
        stages.append("audit")
    if any(p == "project.godot" or p.endswith(CODE_EXTS) for p in paths):
        stages.append("v2")
    if any(p == "project.godot" or p.startswith(FLOW_PREFIXES) or p in FLOW_SCRIPTS for p in paths):
        stages.append("flow")
    return stages


def run(cmd, timeout):
    started = time.time()
    try:
        proc = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True,
                              encoding="utf-8", errors="replace", timeout=timeout)
    except FileNotFoundError:
        return 1, "", "找不到命令：%s" % cmd[0], time.time() - started
    except subprocess.TimeoutExpired:
        return 1, "", "超时 %ds：%s" % (timeout, " ".join(cmd)), time.time() - started
    return proc.returncode, proc.stdout, proc.stderr, time.time() - started


def stage_audit():
    code, out, err, secs = run([sys.executable, "tools/studio_audit.py"], 120)
    text = out + err
    errors = [line.strip() for line in text.splitlines() if "[ERROR]" in line]
    fresh = [line for line in errors
             if not any(known in line for known in KNOWN_AUDIT_ERRORS)]
    if code != 0 or fresh:
        return False, secs, fresh or [text.strip()[-300:]]
    note = "已知历史告警 %d 条" % len(errors) if errors else "无告警"
    return True, secs, [note]


def stage_v2():
    code, out, err, secs = run(
        [GODOT, "--headless", "--path", ".", "res://tests/v2_systems_test.tscn"], 240)
    text = out + err
    summary = [l.strip() for l in text.splitlines() if "V2_TEST RESULT" in l]
    fails = [l.strip() for l in text.splitlines() if l.strip().startswith("FAIL ")]
    ok = code == 0 and any("fails=0" in s for s in summary)
    return ok, secs, fails[:10] or summary or [text.strip()[-300:]]


def stage_flow(full):
    args = [GODOT, "--headless", "--path", ".", "res://tests/integration.tscn"]
    if not full:
        args.append("--fast")
    code, out, err, secs = run(args, 300)
    text = out + err
    fails = [l.strip() for l in text.splitlines() if l.strip().startswith("FAIL ")]
    summary = [l.strip() for l in text.splitlines() if l.strip().startswith("RESULT ")]
    skipped = [l.strip() for l in text.splitlines() if l.strip().startswith("SKIP ")]
    ok = code == 0 and any("fails=0" in s for s in summary)
    detail = summary + (["跳过：%s" % "、".join(s.split()[1] for s in skipped)] if skipped else [])
    return ok, secs, fails[:10] or detail or [text.strip()[-300:]]


def main():
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, OSError):
        pass
    argv = sys.argv[1:]
    full = "--full" in argv
    list_only = "--list" in argv

    paths = changed_paths()
    stages = decide(paths)
    if full:
        stages = ["audit", "v2", "flow"]
    if not paths and not full:
        print("无改动，跳过检查。交付前可跑 --full 做全量确认。")
        return 0
    if not stages:
        print("改动不涉及校验范围（%d 个文件），跳过。" % len(paths))
        return 0

    labels = {"audit": "资产巡检", "v2": "核心系统", "flow": "流程集成"}
    if list_only:
        print("将执行：" + " → ".join("%s(%s)" % (labels[s], s) for s in stages))
        return 0

    runners = {
        "audit": lambda: stage_audit(),
        "v2": lambda: stage_v2(),
        "flow": lambda: stage_flow(full),
    }

    total = 0.0
    failed = []
    for index, stage in enumerate(stages, 1):
        ok, secs, detail = runners[stage]()
        total += secs
        mark = "OK  " if ok else "FAIL"
        print("[%d/%d] %-6s %-8s %5.1fs  %s" % (
            index, len(stages), mark, labels[stage], secs, "；".join(d for d in detail if d)[:160]))
        if not ok:
            failed.append(stage)

    if failed:
        print("失败环节：" + "、".join(labels[s] for s in failed) + "（共 %.1fs）" % total)
        return 1
    print("全部通过  %.1fs" % total)
    return 0


if __name__ == "__main__":
    sys.exit(main())
