# 怪物美术流水线（概念图拆立绘 → 绿幕视频拆帧 → 入库校验）

> 适用于 `data/v2/enemies_waves_v2.json` 里的小怪、精英与首领。主角走 `docs/HERO_ART_PIPELINE.md`，本文只管怪物。
> 唯一脚本：`tools/build_monster_video_sheets.py`；规格校验已接入 `python tools/quick_check.py` 的资产巡检层。

---

## 1. 五段流程

| 段 | 输入 | 命令 / 动作 | 产物 |
| :--- | :--- | :--- | :--- |
| **S0 拆图规格** | 5×2 网格概念图（绿幕） | 在脚本 `MONSTERS` 里登记 id / 中文名 / tier / 行列 | 角色清单（唯一真相源） |
| **S1 拆立绘** | 概念图 JPG/PNG | 自动边界抠像 + 按行裁掉标签 + 去边缘碎块 | `assets/sprites/enemy_<id>.png`（256²）+ `.tmp/monsters/concept_*_512.png` 预览 |
| **S2 视频抽帧** | 绿幕移动视频（每格一个角色） | 24fps 全片抽帧，逐帧边界抠像，缓存到 `.tmp/monsters/video_clean/` | 240 帧 RGBA |
| **S3 对齐打包** | 干净帧 | 每角色取 8 帧，按视频格统一比例缩放、以中位 bbox 居中、脚底对齐 94% | `assets/sprites/anim_<id>_run.png` |
| **S4 规格校验** | 图集 + JSON + `enemy_visual.gd` | `python tools/build_monster_video_sheets.py --verify` | 失败逐条列出，退出码非 0 |
| **S5 接入与实机** | 图集 | 数据登记 + `enemy_visual.gd` 绘制分支 + 实机截图 | 进池可玩 |

需要由引擎用代码驱动动作、不配绿幕视频的小怪只走 S0+S1，见本文第 6 节。

完整重建：

```bash
python tools/build_monster_video_sheets.py \
  --concept "C:/Users/jiang/Pictures/百宝/Gemini_Generated_Image_jf6lm9jf6lm9jf6l.jpg" \
  --video   "C:/Users/jiang/Pictures/百宝/gemini_generated_video_a59a9892.mp4"
python tools/build_monster_video_sheets.py --verify
```

只校验（资产巡检会自动调用）：

```bash
python tools/build_monster_video_sheets.py --verify
# MONSTER_VERIFY OK problems=0
```

---

## 2. 固定规格

| tier | 帧数 | 单帧高 | 图集尺寸 | 立绘 | 游戏内显示高度 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `minion` 小怪 | 8 | 128 | 1024×128 | 256² | ≈60px |
| `elite` 精英 | 8 | 160 | 1280×160 | 256² | ≈85px |
| `boss` 首领 | 8 | 224 | 1792×224 | 256² | ≈180px |

- 图集必须横排、无 padding、脚底统一落在帧高 94% 处。
- 所有角色按 **视频格统一比例**（帧高 / 360）缩放，保留 BOSS 与小怪的相对体型；禁止每个角色单独缩到满帧。
- 帧间水平/垂直位置用全片 bbox 中位数对齐，保留动作本身的位移，不做逐帧刚性对齐。

---

## 3. 踩过的坑（下次直接绕开）

| 症状 | 原因 | 正确做法 |
| :--- | :--- | :--- |
| 紫蟾蜍、狐妖、纸人身上出现灰白/透明的斑块 | 通用柔边 matte（`video2dsprite clean --matte soft/dominance`）把紫色、浅灰、绿色设计当成 key 吃掉；`dominance` 还完全不透明 | **只用从四边 flood-fill 背景**：颜色接近 key 且与画布边界连通的像素才透明；角色内部被包围的绿色/紫色一律保留 |
| 抠完的图集角色边缘一圈绿 | 绿幕压缩色溢 | 只对紧邻透明区的 1–2px 做 `G = min(G, max(R,B)+8)`，内部 RGB 不动 |
| 概念图拆出来每格底下带半截英文名 | 标签在角色脚底下方 10–30px，一刀切到 655 会把字顶带进来 | 先按行 alpha 统计找到角色最低点，再裁到文字上沿之前（本次第一行 640、第二行 1425；视频 294 / 654） |
| 每帧底部有一条黑线 | 同上，视频标签从 y≈296 开始 | 视频行裁切上限 294（第一行）/ 654（第二行），并用校验脚本的“底部 1.5% 无像素”规则拦住 |
| 所有怪物在游戏里一样大，BOSS 像杂兵 | 每个角色单独缩放到满帧 | 统一 `scale = 单帧高 / 360`，只做居中与脚底对齐 |
| 魔尊剑轮里出现棋盘格 | 绿幕色和剑轮光晕都是绿色，flood-fill 从剑缝钻进去 | 对 `wanjian_mozun` 单独处理：以角色中心为圆心 116px 内、接近 key 的绿色像素清成透明 |
| 狐妖右侧多一块绿色碎片 | 裁切窗口带进邻格特效 | 删除“接触裁切边缘且面积 < 600px”的连通块 |
| contact sheet 看着没问题，实机偏小 | 预览按格子缩放，掩盖了显示尺寸问题 | 必须用 `tests/showcase_new_monsters.tscn` 同款实机截图验收，看 60/85/180px 三档 |
| 蝙蝠格里冒出火鸦的火苗、蜈蚣格里带着穿山甲的尾巴 | 按画布宽度等比五等分切格，相邻角色跨过了等分线 | 列边界用**上下两排投影同时为空的列**（本例 `632 / 1137 / 1660 / 2185`），行带取 `740` |
| 缩小后角色外圈发绿 | 羽化环（alpha 0.55）里留着绿幕色，缩放时的 alpha 除法把它放大成绿边 | 环上再压一道 `G ≤ (R+B)/2 + 4`，缩放改成预乘 alpha 再 LANCZOS |
| 绿幕视频中段动作挥砍跨格串扰 | 10s 视频中段（约 2–7s）部分角色大招特效侵入邻格，全片均匀抽 8 帧会带入残影 | `_pick_clean_loop_window` 按角色遍历 `48/56/64` 帧连续窗口，优先左右边界像素碰撞最低、内部动作流畅且首尾闭环差最小的 8 帧 |
| 1280×720 视频内部封闭绿幕空洞漏掏 | 视频分辨率面积只有概念图的 1/4.6，沿用 `hole_min_area=200` 会漏掉雷鼓/飘带/手臂间的中小空洞 | 用 `label(cand)` 一次完成边界连通域抠像，并按 `hole_dist=45, hole_min_area=8` 将命中的封闭 `cand` 连通域整块并入背景 |

---

## 4. 工程接入槽位

| 类型 | 数据槽 | 代码 |
| :--- | :--- | :--- |
| 小怪 | `enemy_archetypes`，`species` 7–10；`stages_v2.json` 各波 `pool` 追加低权重条目 | `enemy_visual.gd` 普通怪 `match species`，绘制 rect 112 |
| 精英 | `elite_variants["11"/"12"]`，对应 `species` 11/12 的独立精英；`spawner._pick_elite_species()` 概率抽出 | 精英 `match species`，绘制 rect 132、单帧 160 |
| 首领 | `boss_variants` 数组（含 `id/type/name/hp/sprite/sheet`） | `spawner._boss_species()` 把 `type` 映射到 species 3–6；`stage_director._build_boss_plan()` 按 `Stats.total_runs` 轮换关底 |

- `species` 7–10 同时写进 `spawner._scale_to_chapter()` 的基础 HP 表，避免走默认 32。
- 新图集、立绘路径必须同时出现在 `enemies_waves_v2.json` 与 `enemy_visual.gd` 的 `preload` 里，校验脚本会查。
- 每局关底按 `Stats.total_runs % （1 + boss_variants 数）` 顺序轮换：狼王 → 八卦丹炉 → 铜甲尸王 → 画皮狐妖 → 万剑魔尊。

---

## 5. 验收清单

1. `python tools/build_monster_video_sheets.py --verify` → `MONSTER_VERIFY OK`
2. `python tools/quick_check.py` → 资产巡检含“怪物图集规格 OK”
3. `godot --headless --path . res://tests/v2_systems_test.tscn` → `fails=0`
4. 实机截图：小怪约 60px、精英约 85px、BOSS 约 180px，脚底与地面光环对齐
5. `python tools/studio_audit.py` → 无新增 orphan（新资产都被 JSON/代码引用）

---

## 6. 静态单张分支（引擎驱动动作）

不给每个小怪出绿幕视频、改由 Godot 代码做呼吸/飘浮/摆动时，只跑 S0+S1，产物是单张立绘：

```bash
python tools/build_monster_video_sheets.py --stills
python tools/build_monster_video_sheets.py --verify   # 资产巡检会顺带跑
```

- 角色清单在脚本的 `STILL_MONSTERS`（id / 中文名 / col / row），与视频 pipeline 的 `MONSTERS` 分开，避免 `--verify` 缺少图集时误报。
- 切格不用等比五等分：列边界写在 `STILL_COL_SPLITS`，取上下两排像素投影同时为空的列；行带写在 `STILL_ROW_BANDS`（本例 `740`），概念图无标签文字时不需要给文字留白。
- 产物：`assets/sprites/enemy_<id>.png`（256²，脚底落在 96%），预览见 `.tmp/monsters/contact_stills.png`。
- 只校验尺寸、底部残留、低透明碎片与绿边；进池时仍需在 `enemies_waves_v2.json` 与 `enemy_visual.gd` 登记，才不会再报 orphan。

---

## 7. 第二批首领/小Boss/精英（`--boss-batch2`）

整套 10 只（幽冥紫虎、九霄雷君、沧溟龙将、四臂骨魔、桃花魅姬、六臂蝎魔、吞星巨蟾、金甲神将、金焰九尾、千手魔佛）统一按 `boss` 规格导出，方便后续按需分配为关底大 Boss、小 Boss 或精英怪：

```bash
python tools/build_monster_video_sheets.py --boss-batch2
python tools/build_monster_video_sheets.py --verify
```

- 角色清单：`BOSS_BATCH2_MONSTERS`，按行使用非均匀列边界（`BOSS_BATCH2_CONCEPT_COLS` / `BOSS_BATCH2_VIDEO_COLS`）切格，并对 `liubi_xiemo` 右界微扩以完整保留刀尖。
- 产物：`assets/sprites/enemy_<id>.png`（256²）与 `assets/sprites/anim_<id>_run.png`（1792×224，8 帧横排）；预览见 `.tmp/monsters/contact_concept_boss_batch2.png` 与 `.tmp/monsters/contact_video_boss_batch2.png`。
- 校验只检查立绘与图集文件规格与质量，不强制要求预先写入 `enemies_waves_v2.json` 与 `enemy_visual.gd`。
