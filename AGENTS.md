# 《百宝小道修 · Pocket Daoist》AI 协同工作约定

本仓库所有 AI 助手（Claude Code、Codex、Antigravity 等）在开发界面、调整配置或生成美术/音频资源前，必须遵守以下约定：

## 1. 动工前先查台账（禁止盲生成）
- **先读 `docs/AI_ASSET_GUIDE.md`**：查清现有英雄、法宝、怪物、地图、图标、音频和 UI 令牌，优先复用已有资源，禁止重复生成第二套按钮、弹窗或同题材贴图。
- **动笔/生图前必读 `docs/ART_STYLE_BIBLE.md`**：所有新增或重绘的英雄、怪物、法宝/宝物/道韵图标、地图地标、地砖与剧情图，必须严格遵守圣经中的视角、线宽、赛璐璐/水彩分层、饱和度金字塔与无乱码汉字红线，并绑定对应黄金参考图；严禁参考漂移/遗留清单中的旧图。
- **人类可视看板**：`tools/studio_hub/index.html`（或运行 `.\studio.ps1 -Serve`）展示全量资产、雪碧图帧动画、推图矩阵与架构图。

## 2. 单一真相源（SSOT）
- 数值、关卡、怪物、角色、法宝、道韵、掉落与资源路径统一维护在 `data/v2/*.json` 和 `scripts/story.gd`。
- 新增道具/道韵/超武/关卡地标时，同步在对应 JSON 中登记完整路径（`res://assets/...`）和元数据，不要在业务脚本里硬编码第二套列表或写死数量标签。
- 被替代或废弃的旧美术资源统一移入 `assets/_legacy_unused/`（已配置 `.gdignore`，不进导出包），避免污染活跃目录。

## 3. UI 主题红线
- 全部界面样式必须通过 `scripts/ui/xianxia_ui_theme.gd`（`XianxiaUITheme`）创建或扩展（`make_hud_plate`、`make_scroll_panel`、`make_card_style`、`style_button`、`style_progress_bar`）。
- 禁止在业务 UI 脚本里直接手写新的 `StyleBoxFlat.new()` 配色和圆角，确需新变体时先沉淀到 `XianxiaUITheme`。

## 4. 改完必巡检与测试
- 修改 `data/v2/*.json`、`assets/`、`scripts/story.gd` 或 UI 脚本后，执行：
  ```powershell
  python tools/studio_audit.py
  python tools/studio_audit.py --strict
  ```
- 修改游戏逻辑或场景后，执行既有 Godot 测试确认无回归：
  ```powershell
  godot --headless --path . res://tests/v2_systems_test.tscn
  .\run.ps1 -Test -Fast
  ```
