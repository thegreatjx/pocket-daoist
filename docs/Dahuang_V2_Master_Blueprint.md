# 《百宝小道修 (Pocket Daoist)》V2 总控架构与实施说明书

> 适用仓库：`game` (`D:\AI_workspace\game`，Godot 4.7 GL Compatibility)
> 设计范式：《土豆兄弟》6 槽位自由法宝 + 《吸血鬼幸存者》大地图割草/包围圈波次 + 修仙五行灵气反应

## 1. 交付资产与代码清单

- **透明 PNG 资产包（`dahuang_v2_assets.zip`）**：
  - `assets/v2/hero/`：通用空手穿裤子 Q 版主角 9 张透明 RGBA PNG（含头、朱红飘带、躯干、左臂、右臂、完整下装、独立左腿、独立右腿、完整立绘参考）。
  - `assets/v2/weapons/`：6 件同画风国风法宝透明 PNG（青霜剑、离火葫芦、天雷符、玄冰镜、万毒幡、玄金钟）。
- **零硬编码数据与代码包（`dahuang_v2_code_data_pack.zip`）**：
  - `data/v2/weapons_v2.json`：6 基础法宝 × 4 阶数值 + 3 件异武器合体超武配方。
  - `data/v2/reactions_v2.json`：5 灵气 × 10 组完整五行元素反应 + `0.35s` 单怪 ICD 防无限递归。
  - `data/v2/items_v2.json`：12 件带正负权衡词条的道具 + 商店重随/锁定经济配置。
  - `data/v2/enemies_waves_v2.json`：5 类怪物 AI 原型 + 20 波次导演公式与刷怪事件。
  - `scripts/v2/`：5 个强类型 Godot 4.7 模块（`v2_data_loader.gd`, `hero_cutout_rig.gd`, `orbit_weapon_rig.gd`, `reaction_engine.gd`, `enemy_steering_director.gd`, `throttled_audio_manager.gd`）。

## 2. 额外补充的 5 个高留存与工程防坑设计（强烈建议同步落地）

1. **经验灵珠“聚合防卡顿”机制（源自《吸血鬼幸存者》）：**
   - 当地面经验珠超过 `max_active_xp_orbs = 120` 时，自动把屏幕外最老的 10 颗低阶绿珠合并为 1 颗高阶金/红灵珠（总经验 100% 保留），保证 15 分钟后期零卡顿且吸珠极解压。
2. **波次间商店“锁定 + 递增重随 + 出售返还”（源自《土豆兄弟》）：**
   - 商店 4 格支持点击**锁定**留到下一波；重随费用按 `4 + wave * 2 + reroll_count * 3` 递增；出售旧法宝返还 55% 灵石，让构筑转型有明确决策乐趣。
3. **受击 0.45s 无敌帧 + 局部击退保护（防止“一帧暴毙”）：**
   - 玩家被怪潮贴脸时绝不能每帧扣血；触发受击时立刻给 `0.45s` 无敌闪烁（`HeroCutoutRig.trigger_hurt_feedback`）+ 周围 80px 怪物小幅弹开，避免极差体验。
4. **“先保清晰度，再谈华丽”的五层透明度硬红线：**
   - 地面持续法阵（火圈/毒圈/剑阵）强制 `z_index = -5` 且 `α = 0.25–0.38`；普通弹幕走 `MultiMeshInstance2D` 单次 Draw Call，且数量多时自动降透明到 `0.45–0.65`；敌方子弹永远保持高对比洋红/正红 100% 实色。
5. **高频音效三段式克制（防 30 APS 刺耳爆音）：**
   - 接入 `ThrottledAudioManager` 后，务必在 Godot `default_bus_layout.tres` 的 `SFX` 总线上挂载 `AudioEffectCompressor` + `AudioEffectLimiter (-1.0 dB)`；经验珠使用五声音阶递升，普通命中按 `-6 * log2(N)` 衰减并加 `±6%` 音高微扰。

## 3. 给本地 Agent 的安全集成指南（严禁破坏现有测试）

1. 解压 `dahuang_v2_assets.zip` 与 `dahuang_v2_code_data_pack.zip` 到项目根目录（仅新增 `assets/v2/`、`data/v2/`、`scripts/v2/`，**不要覆盖或破坏** `scripts/spawner.gd` 和 `tests/run_flow.tscn`）。
2. 新增独立单元测试场景 `tests/v2_systems_test.tscn` 与脚本 `tests/v2_systems_test.gd`，验证：
   - `V2DataLoader.load_all()` 成功加载 6 武器、3 合体、10 反应、12 道具、5 怪物原型；
   - `OrbitWeaponRig` 同级 2 合 1 升阶与 Tier-4 异武器合体腾槽逻辑通过；
   - `ReactionEngine` 10 组反应查表与 `0.35s` ICD 防重入通过；
   - `EnemySteeringDirector` 空间哈希分离计算返回有限非 NaN 向量；
   - `HeroCutoutRig` 与 `ThrottledAudioManager` 实例化与运行零报错。
3. 执行验收命令：`godot --headless --path . res://tests/v2_systems_test.tscn && godot --headless --path . res://tests/integration.tscn`。
