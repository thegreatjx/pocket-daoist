# 百宝小道修 · Pocket Daoist

修仙题材的割草生存肉鸽：《吸血鬼幸存者》的大地图走位/经验聚合/宝箱与首领战 + 《土豆兄弟》的波次间商店 + 五行元素反应。Godot 4.7，2D，1280×720，GL Compatibility。

> **当前状态（2026-11-26）**：游戏只有 **第一关「青冥古林」** 是完整可玩的。第 2–5 关、天道道韵、双法宝合体（超武融合）都属于早期设计，**已停用或未实现**。仓库里 `docs/` 下有几篇早期规划文档仍然写着"5 关 10 波"，那是历史设计，不是现状——**以 [`docs/PROJECT_STATE.md`](docs/PROJECT_STATE.md) 为准**。

## 现在真正能玩到的内容

| 模块 | 现状 |
|---|---|
| 关卡 | 1 关「青冥古林」，480 秒 / 10 波 / 定时首领「苍鬃狼王」，通关后可继续无尽模式 |
| 角色 | 4 位：沈砚（御剑）、福宝（离火葫芦）、张清霄（天雷符）、青瑶（甘露玉净瓶），各有本命元素亲和 |
| 法宝 | 8 件基础法宝，最多装 4 槽，Lv.1→Lv.8 原地淬炼，满阶触发形态质变 |
| 秘宝 / 商店 | 16 件带正负权衡的秘宝，波次间「天机阁」支持锁定、重随、折价出售法宝 |
| 元素反应 | 7 组五行反应（金/木/水/火/雷/冰），单怪 ICD 2.4 秒、首领 1.6 秒 |
| 掉落 | 青瓷罐滚动掉落 6 类道具；首领与镇魔碑掉落天机宝箱 |
| 成就 | 24 条，解锁角色与灵石成长 |

## 运行与验证

```powershell
.\run.ps1                 # 启动游戏（title.tscn）
.\run.ps1 -Test -Fast     # 跑测试
python tools/quick_check.py        # 分层快检：资产巡检 + 核心系统 + 流程集成
python tools/quick_check.py --full # 交付前全量（含 60 秒 smoke）
```

## 目录导航

| 路径 | 内容 |
|---|---|
| `data/v2/*.json` | **数值与配置唯一真相源**：角色、法宝、秘宝、反应、关卡、怪物池、掉落、成就 |
| `scripts/` | 主场景与战斗脚本；`scripts/v2/` 是 V2 玩法核心（法宝环绕、反应引擎、怪物导演、商店 UI） |
| `scripts/ui/xianxia_ui_theme.gd` | 全部 UI 样式的唯一主题，禁止在业务脚本里手写 StyleBox |
| `scenes/` | `title.tscn` 首页、`main.tscn` 局内、各类 UI 与特效场景 |
| `assets/v2/` | 主角立绘与动画图集、地图、特效贴图、UI 素材 |
| `tests/` | `v2_systems_test.tscn`（数据与系统）与 `integration.tscn`（流程集成） |
| `tools/` | 资产巡检 `studio_audit.py`、分层快检 `quick_check.py`、主角美术流水线 `hero_pipeline.py` |
| `docs/` | 设计、美术与资产文档，见下 |

## 文档

**现行有效**

- [`docs/PROJECT_STATE.md`](docs/PROJECT_STATE.md) — 项目现状快照，与代码同步维护，**判断"现在有什么"先看这里**
- [`docs/游戏设计规划.md`](docs/游戏设计规划.md) — 玩法设计定稿
- [`docs/ART_STYLE_BIBLE.md`](docs/ART_STYLE_BIBLE.md) — 美术风格圣经，画任何新素材前的红线
- [`docs/HERO_ART_PIPELINE.md`](docs/HERO_ART_PIPELINE.md) — 主角立绘 → 动画图集的生成与验收流程
- [`docs/AI_ASSET_GUIDE.md`](docs/AI_ASSET_GUIDE.md) — 由 `python tools/studio_audit.py` 自动生成的资产台账

**历史归档（描述的是早期规划，与当前实现不一致）**

- [`docs/Dahuang_V2_Master_Blueprint.md`](docs/Dahuang_V2_Master_Blueprint.md) — V2 架构说明，关卡数量已过时
- [`docs/大荒诛魔录-VSxBrotato融合总纲.md`](docs/大荒诛魔录-VSxBrotato融合总纲.md) — V2 早期融合总纲
- [`docs/VS对标与大荒诛魔录设计报告.md`](docs/VS对标与大荒诛魔录设计报告.md) — VS 深度对标与改造方案
- [`docs/剧情脚本.md`](docs/剧情脚本.md) — 剧情文本，`scripts/story.gd` 目前未被任何运行时代码调用

## 已知的哑火部分

- **天道道韵（`data/v2/arcana_v2.json`）**：数据还在，但 `has_arcana()` / `add_arcana()` 恒返回 false、选卡池返回空，局内拿不到，相关反应加成为空。
- **双法宝合体（`weapons_v2.json` 的 `fusion_recipes`）**：3 条配方存在但玩法入口已关闭。
- **第 2–5 关**：`data/v2/stages_v2.json` 已只保留第 1 关；仓库里第 2–5 关的地砖素材仍在 `assets/terrain/`，但没有关卡数据引用它们。
- **剧情**：`scripts/story.gd` 有 6 章文案，没有被任何代码调用。

改数值、加关卡、加法宝请直接改 `data/v2/*.json`，不要在脚本里写第二套列表。
