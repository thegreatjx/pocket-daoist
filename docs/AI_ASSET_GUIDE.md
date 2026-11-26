# 《百宝小道修 · Pocket Daoist》AI 美术与架构协作速查手册

> 由 `python tools/studio_audit.py` 自动生成（2026-11-26 12:21:59）。派活给 Codex / Claude / Antigravity 前请附带或先读本文件，严禁绕过现有规范另起炉灶。

## 1. 强制工作流
1. **UI 必须走唯一主题**：使用 `scripts/ui/xianxia_ui_theme.gd`（`XianxiaUITheme`），禁止在业务脚本里手写 `StyleBoxFlat.new()`。
2. **美术风格走唯一圣经**：生成或重绘任何图片前必读 `docs/ART_STYLE_BIBLE.md`，遵守 8 条风格边界与黄金参考图锚定，禁止参考漂移/旧像素资产。
3. **生成前先查重**：下表已列出的资源直接引用 `res://...`，不要重复生成第二套按钮、弹窗或同名角色/怪物。
4. **修改后必验**：运行 `python tools/studio_audit.py`（刷新本文件与 HTML 看板）和 `python tools/studio_audit.py --strict`。

## 2. 官方 UI 规范（XianxiaUITheme）
| 令牌常量 | Hex | 用途 |
| :--- | :--- | :--- |
| `COL_PLATE_BG` | `#122924` (`α=0.72`) | 主题色板 |
| `COL_PLATE_DARK` | `#0D1F1C` (`α=0.95`) | 主题色板 |
| `COL_GOLD` | `#E0B24C` (`α=0.96`) | 主题色板 |
| `COL_GOLD_SOFT` | `#C79E47` (`α=0.55`) | 主题色板 |
| `COL_GOLD_BRIGHT` | `#FCDB7A` (`α=1.0`) | 主题色板 |
| `COL_JADE` | `#338F7A` (`α=0.96`) | 主题色板 |
| `COL_PAPER` | `#F5EDD9` (`α=0.98`) | 主题色板 |
| `COL_PAPER_CARD` | `#FCF7E8` (`α=1.0`) | 主题色板 |
| `COL_INK` | `#1A3830` (`α=1.0`) | 主题色板 |
| `COL_INK_MUTED` | `#476157` (`α=1.0`) | 主题色板 |
| `COL_CINNABAR` | `#BD3324` (`α=1.0`) | 主题色板 |
| `COL_HP_FILL` | `#D6302B` (`α=1.0`) | 主题色板 |
| `COL_HP_TRAIL` | `#F5D68F` (`α=0.92`) | 主题色板 |
| `COL_EXP_FILL` | `#2EC294` (`α=1.0`) | 主题色板 |
| `COL_WARM_TEXT` | `#FFF2D1` (`α=1.0`) | 主题色板 |
| `COL_OUTLINE` | `#0A1A14` (`α=0.96`) | 主题色板 |

- **按钮变体（`XianxiaUITheme.style_button(btn, variant)`）**：`primary`（青绿金边主操作）、`cinnabar`（朱砂高危/确认）、`secondary`（宣纸次操作）、`dark_gold`（玄玉暗金）。
- **容器样式**：`make_hud_plate()`（HUD 暗底金框）、`make_scroll_panel()`（宣纸大弹窗 + `attach_ornaments` 回字纹角饰）、`make_card_style()`（商店/升级卡片）。

## 3. 当前明确空缺与断链（AI 待办清单）
| 级别 | 问题 | 涉及文件/目标 |
| :--- | :--- | :--- |
| `ERROR` (BROKEN_DATA_FK) | 道韵 劫火归烬 (arcana_calamity_ember) 引用失效反应 react_molten_forge | `data/v2/arcana_v2.json` |
| `ERROR` (BROKEN_DATA_FK) | 道韵 寒狱碎界 (arcana_glacial_shatter) 引用失效反应 react_shatter | `data/v2/arcana_v2.json` |
| `ERROR` (BROKEN_DATA_FK) | 道韵 雷毒交鸣 (arcana_thunder_venom) 引用失效反应 react_miasma_arc | `data/v2/arcana_v2.json` |
| `GAP` (MISSING_ART_SLOT) | 商店宝物缺少独立图标 (16/16) | `data/v2/items_v2.json` |
| `GAP` (MISSING_ART_SLOT) | 天道道韵缺少独立图标 (8/8) | `data/v2/arcana_v2.json` |
| `GAP` (MISSING_ART_SLOT) | 合体超武复用基础法宝图标 (3/3) | `data/v2/weapons_v2.json` |
| `GAP` (MISSING_ART_SLOT) | 部分怪物原型共用同一套 species 贴图 (2 组撞皮) | `data/v2/enemies_waves_v2.json` |
| `WARNING` (STORY_STAGE_MISMATCH) | 剧情章节数 (6) 与 V2 关卡数 (1) 不一致 | `scripts/story.gd` |
| `WARNING` (ORPHAN_ASSET) | 活跃目录存在 6 个未引用媒体文件（含多版本残留） | `assets/` |
| `WARNING` (UI_THEME_BYPASS) | 6 个 UI 脚本绕过 XianxiaUITheme 私写 34 处 StyleBoxFlat.new() | `scripts/ui/xianxia_ui_theme.gd` |

## 4. 已有核心资产速查表（直接复用，勿重复生成）
### 英雄（8 名 · 统一存放 `assets/v2/heroes/`）
- `sword_immortal` (沈砚 / 御剑道君) -> `res://assets/v2/heroes/hero_sword_qwen.png` | 初始法宝 `wpn_jade_sword`
- `gourd_daoist` (福宝 / 火葫小道童) -> `res://assets/v2/heroes/hero_gourd_daoist.png` | 初始法宝 `wpn_fire_gourd`
- `thunder_daoist` (张清霄 / 雷符天师) -> `res://assets/v2/heroes/hero_thunder_daoist.png` | 初始法宝 `wpn_thunder_talisman`
- `cloud_danxia` (青瑶 / 踏云仙姑) -> `res://assets/v2/heroes/hero_cloud_danxia.png` | 初始法宝 `wpn_jade_vase`

### 法宝与合体超武（8+3 · 统一存放 `assets/v2/weapons/`）
- `wpn_jade_sword` (青霜飞剑, metal) -> `res://assets/v2/weapons/wpn_jade_sword.png`
- `wpn_fire_gourd` (离火葫芦, fire) -> `res://assets/v2/weapons/wpn_fire_gourd.png`
- `wpn_thunder_talisman` (天雷符, thunder) -> `res://assets/v2/weapons/wpn_thunder_talisman.png`
- `wpn_ice_mirror` (玄冰八卦镜, ice) -> `res://assets/v2/weapons/wpn_ice_mirror.png`
- `wpn_venom_banner` (万毒幡, wood) -> `res://assets/v2/weapons/wpn_venom_banner.png`
- `wpn_gold_bell` (玄金古钟, metal) -> `res://assets/v2/weapons/wpn_gold_bell.png`
- `wpn_jade_vase` (甘露玉净瓶, water) -> `res://assets/v2/weapons/wpn_jade_vase.png`
- `wpn_spirit_vine` (青藤灵鞭, wood) -> `res://assets/v2/weapons/wpn_spirit_vine.png`
- `fusion_flame_sword_array` (诛仙烈焰剑阵, 合体) -> 当前复用 `res://assets/v2/weapons/wpn_jade_sword.png`
- `fusion_thunder_frost_domain` (九霄雷冰天域, 合体) -> 当前复用 `res://assets/v2/weapons/wpn_thunder_talisman.png`
- `fusion_venom_zen_bell` (镇岳枯荣梵钟, 合体) -> 当前复用 `res://assets/v2/weapons/wpn_gold_bell.png`

### 推图关卡与地砖（1 关）
- 第 1 关 `青冥古林` | Boss `苍鬃狼王` (`wolf`) | 地砖 `res://assets/v2/map_ch1/tile_grass_512.png` | 已配地标

### 怪物与精英精灵表（`scripts/enemy_visual.gd`）
- `enemy_swarm_imp` (幽冥小鬼, species=1) -> `res://assets/sprites/anim_paper_doll_float.png`
- `enemy_skitter_shenjing` (地灵参精, species=5) -> `res://assets/sprites/anim_shenjing_run.png`
- `enemy_hopper_jiangshi` (符箓小僵, species=3) -> `res://assets/sprites/anim_jiangshi_run.png`
- `enemy_kiter_fox` (赤尾妖狐, species=0) -> `res://assets/sprites/anim_fox_run.png`
- `enemy_bomber_wisp` (阴火毒灯, species=1) -> `res://assets/sprites/anim_paper_doll_float.png`
- `enemy_charger_boar` (狂鬃山魈, species=2) -> `res://assets/sprites/anim_shanxiao_run.png`
- `enemy_charger_huodou` (炎煞祸斗, species=6) -> `res://assets/sprites/anim_huodou_run.png`
- `enemy_bulwark_golem` (青石镇傀, species=2) -> `res://assets/sprites/anim_shanxiao_run.png`
- `enemy_bulwark_jinchan` (三足金蟾, species=4) -> `res://assets/sprites/anim_jinchan_run.png`

### 音频与特效白名单
- 已接入音频：`res://assets/audio/boss_charge.wav`, `res://assets/audio/boss_dash.wav`, `res://assets/audio/boss_roar.wav`, `res://assets/audio/boss_slam.wav`, `res://assets/audio/cannon_blast.wav`, `res://assets/audio/chest_open.wav`, `res://assets/audio/dash.wav`, `res://assets/audio/enemy_die.wav`, `res://assets/audio/fire_gourd_burn.wav`, `res://assets/audio/gem_pickup.wav`, `res://assets/audio/gun_shot.wav`, `res://assets/audio/jar_break.wav`, `res://assets/audio/level_up.wav`, `res://assets/audio/music_battle.ogg`, `res://assets/audio/music_boss.ogg`, `res://assets/audio/music_swarm.ogg`, `res://assets/audio/music_title.ogg`, `res://assets/audio/player_hurt.wav`, `res://assets/audio/swarm_horn.wav`, `res://assets/audio/sword_cast.wav`, `res://assets/audio/sword_hit.wav`, `res://assets/audio/thunder.wav`, `res://assets/audio/thunder_arc_snap.wav`, `res://assets/audio/water_ripple_splash.wav`
- 归档区 `assets/_legacy_unused/` 共有 49 个历史弃用文件，禁止新代码引用。
