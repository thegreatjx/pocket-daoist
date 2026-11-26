# 《百宝小道修 (Pocket Daoist)》V2 架构与现状说明书

> 适用仓库：`game` (`D:\AI_workspace\game`，Godot 4.7 GL Compatibility)
> **当前实际实现状态见 [`PROJECT_STATE.md`](PROJECT_STATE.md)**；本文保留架构概览，涉及关卡数量、道韵、超武合体的描述以那份为准。
> 当前定稿范式：《土豆兄弟》4 槽法宝与波次间商店 + 《吸血鬼幸存者》大地图割草/经验聚合/宝箱与多 Boss 调度 + 修仙 7 组五行元素反应

## 1. 当前核心模块与数据清单

- **数据真相源（`data/v2/`）**：
  - `characters_v2.json`：4 位可用角色（沈砚、福宝、张清霄、青瑶），配置立绘、动画图集与移动模式。
  - `weapons_v2.json`：8 件基础法宝 × `Lv.1–Lv.8` 原地淬炼数值，**最多装备 4 件法宝**（当前已禁用双满级法宝合体/超武融合）。
  - `reactions_v2.json`：7 组五行元素反应 + `2.4s` 单怪内置冷却（首领 `1.6s`）。
  - `items_v2.json`：16 件带正负权衡词条的秘宝与商店经济配置。
  - `stages_v2.json` & `enemies_waves_v2.json`：**1 个已实装关卡**（青冥古林，10 波）、9 种杂兵原型与 7 种精英变体。
  - `pickups_v2.json` & `achievements_v2.json`：青瓷罐 6 类掉落物与 24 条成就配置（当前已禁用天道道韵）。
- **核心脚本（`scripts/v2/`）**：
  - `v2_data_loader.gd`：加载并校验 `data/v2/*.json`。
  - `hero_motion_rig.gd` & `hero_frame_anim.gd`：角色悬停/地面行走驱动与逐帧图集播放。
  - `orbit_weapon_rig.gd`：4 槽环绕法宝、Lv.1→Lv.8 原地淬炼与满阶视觉觉醒（合体分支已停用）。
  - `v2_combat_controller.gd` & `reaction_engine.gd`：伤害乘区硬上限、五行反应调度与元素附着冷却。
  - `v2_shop_ui.gd`、`v2_codex_panel.gd`、`v2_detail_drawer.gd`：波次商店、五行法典与实时联动详情抽屉。
  - `enemy_steering_director.gd` & `throttled_audio_manager.gd`：空间哈希群体避障与高频音效限流。

## 2. 工程防坑与视觉规范

1. **经验灵玉聚合防卡顿**：地面超过 120 颗 `ExpGem` 时自动把旧珠 9 合 1 聚合成紫/红大经验珠；经验珠仅提供修为，升级弹窗由 `UpgradeUI` 负责，与 Boss/镇魔碑掉落的 `TreasureChest`（`ChestUI`）相互独立。
2. **波次间天机阁商店**：4 格商店支持锁定、递增重随、原地淬炼与 55% 折价出售法宝。
3. **受击保护**：触发受击提供 `0.45s` 无敌闪烁与法宝小幅弹开保护。
4. **多层透明度保护**：地面持续法阵强制 `z_index = -5`，放大范围时通过 `AlphaFromScale` 自动压低透明度，保证预警线与敌弹清晰可见。
5. **高频音效限流**：`ThrottledAudioManager` 对 `default_hit / hit / crit_hit / reaction / xp_orb` 做最短间隔（ICD）、同声部上限与密度动态降噪。

## 3. 验证命令

- 资产巡检：`python tools/studio_audit.py`
- V2 系统单元测试：`godot --headless --path . res://tests/v2_systems_test.tscn`
- 全量快速回归：`.\run.ps1 -Test -Fast`
