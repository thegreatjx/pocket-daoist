# 主角美术流水线（生图 → 生视频 → 拆解入库）

> 适用于 `data/v2/characters_v2.json` 里每个主角。目标：**一件法宝一个角色**，每个角色都有一套和整体画风同源、能在游戏里 86px 高度下看清的待机动画。
> 上游风格红线见 `docs/ART_STYLE_BIBLE.md`，本文件只规定「怎么做、做成什么样、怎么验收」。

---

## 1. 现状盘点

| 项 | 现状 |
| :--- | :--- |
| 角色 | 4 个可用主角（`characters_v2.json`：沈砚、福宝、张清霄、青瑶） |
| 法宝 | 8 件（`weapons_v2.json`） |
| 已接入 atlas 动画 | 沈砚（待机）、福宝（待机 + 走动，地面行走模式）、张清霄（待机 + 走动）、青瑶（待机） |
| 坐骑绘制 | `hero_motion_rig.gd` 保留 `sword` / `cloud` 悬停绘制；福宝与张清霄均采用 `brotato_bounce` + `mount_type: none` 地面行走 |

**结论**：结构上已经是「一角色一法宝」，缺的是 1:1 对齐 + 一条统一流水线。流水线的关键约束不是「图好看」，而是**主图必须按下游视频和 atlas 的需要去画**，否则到第 3 步才发现不能动，整张图作废。

---

## 2. 六段流水线

| 段 | 输入 | 工具 / 命令 | 产物 | 验收 |
| :--- | :--- | :--- | :--- | :--- |
| **S0 规格锁定** | 角色表 + 法宝表 | 人工 | 本文件第 3 节规格 + 角色提示词卡 | 提示词四段齐全 |
| **S1 生图** | 提示词卡 | `tools/comfyui_gen_asset.py --style hero_humanoid` | `still_v*.png` 1024²，一次 3 张 | 白底、全身、面朝右、脚底留白 |
| **S2 形象闸门** | 3 张候选 | 人工 + 86px 同屏对照图 | 选定 1 张 → `master.png` | **你点头才进 S3**，不许自动往下跑 |
| **S3 生视频** | `master.png` | `prepare_i2v_input.py` → `tools/comfyui_wan_i2v.py` | `raw_idle/frame_*.png` 49 帧 | 无变脸、无转身、无镜头移动、绿底纯净 |
| **S4 抠像对齐** | 原始帧 | `video2dsprite.py clean` → `register_clip.py apply` | `clean_*/` + `reg_*/frames` + `registration.json` | 边缘无绿边、脚底基准线稳定 |
| **S5 打包入库** | 对齐帧 | `engine_export.py package` | `assets/v2/hero/anim/hero_<id>_idle-atlas-00.png` + `.json` | `verify` 通过；**产出必须符合 SPEC（管线自动校验 fps=24 / loop / 单帧高≥256 / ≤320 / schema 3.0，不符即失败）**；`characters_v2.json` 登记路径；`studio_audit.py --strict` 无新增告警 |

### 固定规格（SPEC）

`tools/hero_pipeline.py` 顶部的 `SPEC` 是唯一的规格真相源，命令行**不可覆盖**。改动它才叫改流程，并且会同时影响 master 尺寸、i2v 参数、抠像参数与 atlas 打包；打包后自动按它校验，不符立即失败。当前锁定值：

| 段 | 参数 | 锁定值 |
| :--- | :--- | :--- |
| master | `master_side` / `body_fraction` / `feet_y` | `512` / `0.90` / `484` |
| i2v | `i2v_canvas` / `i2v_duration_sec` / `i2v_frames` / `i2v_steps` | `640×832` / `2.0s` / `49` / `4` |
| 抠像 | `matte_key` / `despill` / `erode` / `allow_key_residue` | `auto` / `auto` / `0` / `false` |
| atlas | `atlas_fps` / `atlas_schema` / `atlas_body_height_px` / `atlas_max_side` / `atlas_loop` / `atlas_formats` | `24` / `3.0` / `256` / `320` / `true` / `png` |

命令行只接受每次确实会变的输入：`--id`、`--action`、`--still`、`--subject`、`--extra`、`--seed`、`--from-raw`、`--workdir`、`--out-dir`、`--server`。
每次运行会在 `.tmp/hero/<id>/spec_<action>.json` 写一份规格快照，便于事后核对产物是用什么参数跑出来的。

### 具体命令
```bash
# S1 生图（每次 3 张，seed 递增）
python tools/comfyui_gen_asset.py --style hero_humanoid \
  --prompt "$(cat .tmp/hero/<id>/prompt.txt)" --negative "$(cat .tmp/hero/<id>/negative.txt)" \
  --count 3 --steps 20 --seed 7301 --out .tmp/hero/<id>/still.png

# S3 生成 i2v 参考画布与提示词（自动算 root、工作区、绿幕）
python .agents/skills/video2dsprite/scripts/prepare_i2v_input.py \
  --master .tmp/hero/<id>/master.png --action idle --output-dir .tmp/hero/<id>/job_idle
python tools/comfyui_wan_i2v.py --input-image .tmp/hero/<id>/job_idle/input.png \
  --prompt-file .tmp/hero/<id>/job_idle/prompt.txt --out-dir .tmp/hero/<id>/raw_idle \
  --width 640 --height 832 --length 49 --steps 4

# S4 抠像 + 固定变换对齐
python .agents/skills/video2dsprite/scripts/video2dsprite.py clean \
  --raw-dir .tmp/hero/<id>/raw_idle --output-dir .tmp/hero/<id>/clean_idle --key green
python .agents/skills/video2dsprite/scripts/register_clip.py apply \
  --job .tmp/hero/<id>/job_idle/registration_job.json \
  --frames .tmp/hero/<id>/clean_idle --output-dir .tmp/hero/<id>/reg_idle

# S5 打包 atlas（参数与沈砚成品对齐：单帧高 256、fps 24、循环、8 列）
python .agents/skills/video2dsprite/scripts/engine_export.py package \
  --clean-dir .tmp/hero/<id>/reg_idle/frames \
  --registration .tmp/hero/<id>/reg_idle/registration.json \
  --output-dir assets/v2/hero/anim --name hero_<id>_idle \
  --fps 24 --loop --formats png --body-height-px 256 --max-side 320
```

---

## 3. 图片规格（硬性）

| 阶段 | 尺寸 / 格式 | 硬性约束 |
| :--- | :--- | :--- |
| **S1 主图** | `1024×1024` PNG（白底，RGB） | 人物占画面高 `88~92%`；脚底距下沿 `3~5%`；四周 ≥8% 安全留白；面朝右；**不画坐骑、不画法宝**；无地面影 |
| **S1 透明主图** | `512×512` PNG RGBA | 白底 flood-fill 去背 + 边缘去白，透明边无白边残留 |
| **S2 同屏预览** | `86px`（游戏内实际高度）+ `150px` 两档 | 叠在 `tile_grass_512.png` 上，紧挨沈砚对照 |
| **S3 i2v 输入** | `640×832` PNG（纯绿 `#00FF00`） | 由 `prepare_i2v_input.py` 自动生成：root `(320,716)`，工作区 `x=20..620 / y=42..755`，禁止手改 |
| **S4 视频帧** | `640×832 × 49 帧 @ 24fps` | Wan2.2 TI2V 5B Q4_K_M + Turbo LoRA，`steps 4 / cfg 1.0 / shift 8.0 / uni_pc+simple` |
| **S5 atlas** | 单帧 `≈122×258`（高度 = 显示高度 ×3），8 列横排 PNG + `animation.json` 3.0 | `fps 24`、`loop`、`reviewStatus` 先 `needs-visual-review`，看过 sheet 后 `accept` |

为什么是 3 倍：`hero_motion_rig.gd` 里 `_anim_scale = draw_height / cell.y`，86px 显示高度配 258px 单帧，正好 1/3 缩放，既有细节又不会在 1080p 下糊。

---

## 4. 提示词结构（四段式）

`comfyui_gen_asset.py --style hero_humanoid` 会自动注入风格前缀和全局负面，**只写中间四段**：

| 段 | 写什么 | 反面例子（会翻车） |
| :--- | :--- | :--- |
| **A 风格锁** | 模板自动注入，禁止改写 | 手改前缀 → 线宽、饱和度漂移 |
| **B 身份块** | 性别/年龄感 + 头身比 + **视角与头眼朝向** + 发型头饰 + 服饰三层色块 + 手持物 + 鞋 | 只写「facing right」→ 出来是正面站桩 |
| **C 姿势块** | 站/浮空、双手位置、双脚位置、整体留白 | 写「动感」「奔跑」→ 主图阶段就要废 |
| **D 下游约束** | 纯白底、无影、无坐骑、无文字、剪影可读 | 漏写「no cloud」→ 坐骑画进图，和引擎的双份 |

### 本会话踩出来的五条硬规则

1. **必须给一个深色大色块**（占身高 35% 以上，如沈砚的藏青外袍）。只写「月白、清透、淡青」→ 86px 下糊成一个白团，和背景分不开。
2. **朝向写两遍**：视角句写 `three-quarter view turned to face screen-RIGHT`，头眼再写 `head and gaze pointing right`，负面加 `front-facing symmetric pose`。
3. **坐骑和法宝都不进主图**：云、剑、火轮由 `hero_motion_rig.gd` 画，武器是独立 sprite。主图画了就是双份。
4. **手要单独交代**：`clean well-drawn five-finger hands` + 负面 `clawed hand, deformed fingers`。
5. **别写 pastel / delicate / soft / pale**：会把对比度和描边一起拉低，画风从「赛璐璐游戏精灵」滑向「淡彩插画」。

### 负面清单分三层

```text
# 全局（脚本自动拼）
STYLE_GLOBAL_NEGATIVE
# 品类（hero_humanoid 自带）
multiple views, grid, chibi blob, realistic 7-head proportions
# 本角色
cloud under feet, cloud mount, sword, weapon in hand, lotus lantern,
pastel, pale washed-out colours, low contrast, soft watercolor blur, thin faint lineart,
clawed hand, deformed fingers, extra fingers, second character, group,
front-facing symmetric pose, scenery, watermark
```

---

## 5. 角色 × 法宝 对照表（8 宫格）

| # | id | 角色 | 本命法宝 | 元素 | 主色块（深→浅） | 剪影关键词 | 坐骑 | 状态 |
| :-- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 1 | `sword_immortal` | 沈砚 · 御剑道君 | 青霜飞剑 | metal | 玄墨藏青 → 月白 → 鎏金 / 朱红腰带 | 高马尾 + 剑冠 + 双飘带 | sword | ✅ 已有动画 |
| 2 | `cloud_danxia` | 青瑶 · 踏云仙姑 | 甘露玉净瓶 | water | 深青碧 → 月白 → 鎏金 / 青蓝飘带 | 侧髻 + 玉莲簪 + 宽水袖 | cloud | 🔄 主图候选已出，待定稿 |
| 3 | `gourd_daoist` | 福宝 · 乘葫小道士 | 离火葫芦 | fire | 赭红 → 暖橘 → 铜金 | 圆胖 + 大葫芦 | gourd | ⬜ 坐骑需引擎补或烘焙 |
| 4 | `jinyiwei_gunner` | 陆昭 · 锦衣卫枪炮师 | 玄冰八卦镜（建议改派） | ice | 玄黑飞鱼服 → 冰蓝 → 铜金 | 官帽 + 长铳 + 镜轮 | fire_wheel | ⬜ 元素/法宝待你确认 |
| 5 | `gourd_spirit` | 阿葫 · 灵葫小仙 | 万毒幡 | wood | 毒翠 → 暗紫 → 骨白 | 葫芦团子 + 毒幡 | none | ⬜ |
| 6 | `daoist_mochi` | 圆圆 · 太极小道童 | 玄金古钟 | metal | 墨黑/宣白太极 → 鎏金 | 团子 + 铜钟 | none | ⬜ |
| 7 | `fox_dango` | 白团 · 青丘幼狐 | 天雷符 | thunder | 月白 → 紫电 → 朱砂 | 狐耳 + 大尾 + 符纸 | none | ⬜ |
| 8 | `wood_deer_spirit` | 茸茸 · 青木鹿灵 | 青藤灵鞭 | wood | 青木 → 嫩芽绿 → 木棕 | 鹿角 + 藤鞭 | none | ⬜ |

---

## 6. 顺序与成本

- **先跑通青瑶一个完整闭环**（S1→S5 全绿），把命令、参数、验收固化成可复用脚本，再批量做 3~8。理由：现在真正没验证过的是 S3→S5 这一段（沈砚那次是摸索出来的，参数还没回写）。
- 每个角色：主图 3 张 ≈ **5 分钟**（实测 1024²/20 步 ≈ 100~110 秒/张，RTX 3060 Ti 8G）；i2v 一条 49 帧待实测；抠像/对齐/打包 < 2 分钟。
- 建议每个角色只做 **idle**（待机循环）+ 后续按需补 attack。idle 覆盖 90% 的在场时间，attack 有独立特效层，优先级低。

---

## 7. 待确认（3 项）

1. **陆昭的法宝**：改派「玄冰八卦镜」并把元素改成 ice（不新增内容），还是新增一件火系法宝？
2. **福宝的葫芦坐骑**：给 `hero_motion_rig.gd` 补 `gourd` 绘制分支，还是把葫芦直接烘焙进主图？
3. **青瑶定稿**：候选 1~4 里选一张（我推荐候选 3，`still_v3_2`），还是按新规则再抽一轮？
