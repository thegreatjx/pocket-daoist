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

## 4. 状态必须显式（禁止隐式状态机）
- 流程、界面、战斗阶段必须有单一显式状态字段（enum 或专用状态变量）。禁止用多个 bool、计数器、计时器互相推断“现在处于哪一步”，例如靠 `pending_level_ups`、`pending_chests`、`pending_shop_wave`、`is_game_over` 拼出“该弹哪个面板”。
- 同一状态只允许一个写入点，其余代码只读。状态迁移集中在一个函数或一处 `match`，禁止散落在多个信号回调里各改一半。
- 新增流程分支时先加状态值再写逻辑；改动已有流程时若发现隐式状态，先收敛成显式状态，再改功能，不顺手留“以后再理”的补丁。

## 5. 改完必巡检与测试
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

## 6. 每次改动自动提交（Git Commit）
- 每次任务改动完成并通过第 5 节巡检与测试后，自动执行 `git add` 与 `git commit`，不再等待额外口头催促。
- 只暂存并提交本次任务涉及的改动文件及配套产物（如 `.import`、由本次改动触发更新的台账/看板文件）；若工作区已有与本次任务无关的未提交改动，必须保留在工作区，禁止混入同一次提交或擅自回滚。
- 提交信息沿用仓库约定（`<type>(<scope>): <简体中文说明>`，如 `feat(art): ...`、`fix(v2): ...`、`docs: ...`）；除非用户明确要求，不自动执行 `git push`。
