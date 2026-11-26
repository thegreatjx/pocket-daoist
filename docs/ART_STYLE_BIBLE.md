# 《百宝小道修 · Pocket Daoist》美术风格圣经（Art Style Bible）

> 本文件是本项目唯一权威的美术控制边界文档。任何 AI 助手或美术协作者在绘制、生成、精修或重绘角色、怪物、法宝、宝物、道韵、地砖、地标及剧情插画前，必须逐条核对以下边界与黄金参考图。

---

## 1. 风格总纲与视觉定位

- **官方风格命名**：**「清雅青绿水彩底 + 粗墨线 2D 赛璐璐 Q 版国风仙侠」**（*Clean Ink-Outlined Chibi Xianxia / Cel-Shaded Donghua Watercolor*）。
- **核心气质**：清亮、通透、灵动、东方国漫修仙志异感。既保留传统青绿山水与宣纸水彩的雅致底蕴，又具备肉鸽割草战斗所需的高辨识度剪影与 Q 弹清爽手感。
- **严禁基调**：暗黑写实魔幻、欧美厚涂肌肉写实、硬锯齿复古像素、现代机甲科幻、血腥恐怖猎奇。

### 四层视觉分工体系

| 视觉层级 | 负责品类 | 核心表现手法 | 锚点风格标杆 |
| :--- | :--- | :--- | :--- |
| **L0 · 封面与剧情过场** | 标题背景、章节插画、结局图 | 青绿设色国漫山水，细墨勾线 + 清透水彩晕染 | `res://assets/art/title_bg.png` |
| **L1 · 战斗地面底砖** | 5 大关卡无限平铺地砖 | 极简低饱和宣纸水彩底，极少浅墨线条点缀，主动让位给弹幕 | `res://assets/v2/map_ch1/tile_grass_512.png` |
| **L2 · 场景地标与掩体** | 松树、石碑、古井、香炉等 | 深墨线勾边 + 轻水彩/平涂质感，明度与饱和度退后一步 | `res://assets/v2/map_ch1/prop_pine_tree.png` |
| **L3 · 前景实体与图标** | 主角、小怪、Boss、法宝、宝物、道韵 | 深墨线外粗内细 + 2~3 阶明快赛璐璐（Cel-Shading） | `hero_sword_qwen.png` / `wpn_jade_sword.png` / `anim_jiangshi_run.png` |
| **UI · 界面框架** | HUD、商店卡片、宣纸卷轴弹窗 | 玄玉墨青 + 鎏金回纹 + 暖宣纸 + 朱砂警示（唯一真相源 `XianxiaUITheme`） | `scripts/ui/xianxia_ui_theme.gd` |

---

## 2. 八大硬性控制边界（验收红线）

### 边界一：视角与构图
1. **战斗实体统一视角**：全部角色、怪物、地标掩体与法宝投射物，采用 **2.5D 俯视 3/4 视角（俯角约 30°~35°）**，能够同时看清头顶饰物、正侧面五官与脚底落地关系。
2. **统一朝向**：默认**面朝右侧**（水平向左由 Godot 运行时翻转 `flip_h` 处理，严禁左右混向）。
3. **居中与底缘锚定**：单帧四周保留 `≥ 8%` 安全留白，角色与地标脚底/底座落在统一底缘基准线上，四肢/法器/飘带严禁裁切出框。
4. **贴图内严禁地面投影**：任何前景精灵、怪物、法宝或地标透明 PNG 内，**绝对禁止自带地面阴影**（地面投影统一由引擎在脚底绘制半透明椭圆影，避免水平翻转和叠层穿帮）。
5. **禁用视角**：除地面地砖与地面法阵外，禁止纯 90° 垂直顶视（Top-Down）、纯平 2D 横版侧视及大广角鱼眼透视。

### 边界二：线稿与描边
1. **线色规范**：禁止使用纯死黑 `#000000` 描边。统一使用**深墨褐 / 深墨青**（`#161B1A` ~ `#241D1A`），随主体冷暖微调。
2. **外粗内细比例**（按目标导出画布尺寸计）：
   - **法宝 / 宝物 / 道韵图标（192~256px）**：外轮廓 `3~5px` 扎实闭合，内结构线 `1.5~2px`，呈现国漫徽章贴纸辨识度。
   - **主角与怪物（256px 基准 / 96px 精灵帧）**：外轮廓 `2~3px` 清晰连贯，面部五官与衣褶内线 `1~1.5px`。
   - **场景地标与掩体（256~384px）**：外轮廓 `3~4px`，线宽与角色处于同一层级，**严禁使用过粗涂鸦黑边压过主角**。
   - **战斗地面地砖（512px）**：**无粗黑线**，仅允许极细低对比浅墨碎笔（`opacity < 45%`）。
3. **绝对禁用**：无描边厚涂、油画厚重笔触、硬锯齿像素风、外发光霓虹描边、碎线草稿感。

### 边界三：上色、光影与材质
1. **主光源统一**：默认**左上方柔和天光（约 11 点方向）**，低至中等反差，画面保持清亮通透。
2. **前景赛璐璐规则**：角色、怪物与法宝采用**平光赛璐璐（2~3 阶明暗）**——干净底色 + 1 阶明晰暗部（冷色微偏青紫，暖色微偏赭棕）+ 1 处硬边缘高光；仅允许在玉石、灵珠、脸颊腮红处保留极轻微柔光过渡。
3. **地面与环境材质**：地砖与自然地标保留轻水彩/宣纸晕染肌理；**禁止**写实岩石凹凸噪点、写实砖缝、PBR 金属粗糙度、3D 塑料高光与写实环境光遮蔽（AO 黑脏阴影）。

### 边界四：色彩与四层饱和度金字塔

对齐 `scripts/ui/xianxia_ui_theme.gd` 色板（玄玉底 `#122924`、鎏金 `#E0B24C`、翠玉 `#338F7A`、宣纸 `#F5EDD9`、朱砂 `#BD3324`）及 `docs/Dahuang_V2_Master_Blueprint.md` 五层透明度红线：

| 层级 | 饱和度上限/区间 | 明度与用色原则 | 透明度 / 运行时规则 |
| :--- | :--- | :--- | :--- |
| **L1 · 地面地砖** | `S ≤ 25%` | 柔和灰调水彩，避开纯黑与刺眼纯白 | 100% 不透明底砖 |
| **L2 · 地图地标与掩体** | `S = 20%~45%` | 偏青石、旧铜、松墨等沉稳色，整体亮度压在主角之下 | 100% 不透明（不挡视线轮廓） |
| **L3 · 主角 / 法宝 / 小怪** | `S = 45%~75%` | **敌我分色**：主角与法宝高频使用**玉青、暖金、朱红、月白**；小怪优先**暗紫、橘红、毒翠、苍灰**，避开与主角撞色 | 地面持续法阵 `z = -5` 且 `α = 0.25–0.38`；己方密集弹幕 `α = 0.45–0.65` |
| **L4 · 敌弹与危险预警** | `S ≥ 85%` | 高对比洋红 / 正红 / 炽橙，确保混战一秒识别 | **100% 实色，严禁降透明** |

### 边界五：关卡主题色与地标规划表

配色与地砖对齐 `data/v2/stages_v2.json`。**当前只实装第 1 关**，第 2–5 关在数据里已删除，下表保留为待用美术规划，新增素材不得引用未关联网格。

| 关卡 | 章节名 | 地面主调 (`ground`) | 氛围灵光 (`tint`) | 地砖路径 | 后续地标/掩体题材白名单 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| 第 1 关 | 青冥古林 | `#4f5c57` | `#3dd1b3` | `res://assets/v2/map_ch1/tile_grass_512.png` | 迎客古松、青苔古井、山泉石池、镇魔石碑、青铜香炉（已实装） |
| 第 2 关 | 落霞花溪 | `#5e544f` | `#f5bd52` | `res://assets/terrain/tile_ch2_sunset_blossom_512.png` | 落霞桃树/红枫、溪石灯笼、断桥石栏、花溪丹鼎（待用） |
| 第 3 关 | 幽冥玄坛 | `#474d5c` | `#5cdbeb` | `res://assets/terrain/tile_ch3_nether_altar_512.png` | 冥石阵柱、青灯古炉、符篆残坛、枯柳石碑（待用） |
| 第 4 关 | 赤焰荒原 | `#5c4a47` | `#47e0a3` | `res://assets/terrain/tile_ch4_crimson_wasteland_512.png` | 焦岩炎柱、赤铜炼丹炉、玄纹裂石、焦枯灵木（待用） |
| 第 5 关 | 云巅仙境 | `#545963` | `#facc5c` | `res://assets/terrain/tile_ch5_cloud_immortal_512.png` | 白玉蟠龙柱、祥云香炉、仙鹤石台、聚灵八卦玉坛（待用） |

### 边界六：比例与体型规范
1. **主角双谱系（同质化画风约束）**：
   - **仙修人型系**（如御剑道君、锦衣卫神机枪炮师、踏云仙姑）：固定 **2.8~3.2 头身** Q 版修长比例，眉眼明朗、服饰有云纹/滚边细节。
   - **灵物团子系**（如太极小道童、青丘幼狐、灵葫小仙）：固定 **1.3~1.8 头身** 土豆兄弟式 Q 弹圆润比例，适配挤压拉伸动画。
   - **强制统一项**：两系主角必须共用完全相同的**深墨线宽、2~3 阶赛璐璐明暗、柔和天光及大眼五官清亮画法**。
2. **怪物与妖兽比例**：
   - **普通杂兵**：统一 **1.5~2.2 头身** Q 版妖灵比例；四足妖兽同样保持大头、圆耳、短肢与蓬松轮廓，追求“讨喜但有妖气”。
   - **精英与关底 Boss**：通过 **1.8~2.5× 体型放大**、火焰鬃毛、背后光环、头角冠饰和武器尺寸建立压迫感；**绝对禁止**通过改成写实野兽或写实暗黑比例来体现强敌感。
3. **禁用比例**：严禁 6~8 头身写实人类、写实肌肉猛兽解剖、细长写实四足犬狼体态。

### 边界七：文化符号白名单与绝对负面清单
- **白名单元素**：青铜鼎炉、道家云纹/回字纹、八卦太极、玉佩流苏、朱砂符箓、松竹桃花、仙鹤祥云、山海经异兽、明代飞鱼服与神机火器（保留东方仙侠奇巧机关韵味）。
- **黑名单元素**：
  1. 西幻板甲、欧式哥特教堂、恶魔蝙蝠翼、现代战术背心、科幻激光霓虹。
  2. **AI 乱码汉字禁令（死红线）**：**绝对禁止让生图模型直接绘制可读汉字**（石碑碑文、符纸文字、旗幡匾额一律改用抽象朱砂云篆/符纹图案；确实需要可读汉字时，必须留白并由 Godot 字体层程序叠加）。
  3. 写实骨骼肌肉、血迹内脏、脏乱破败废土风。

### 边界八：资产交付规格表

| 资产类别 | 存放目录 | 文件格式 | 目标尺寸 / 规格 | 附加要求 |
| :--- | :--- | :--- | :--- | :--- |
| 主角立绘 | `assets/v2/heroes/` | `PNG (RGBA)` | `256×256`（或 `512×512` 透明底） | 人物底缘锚定 `y ≈ 248`（占高约 90%），面向右 |
| 法宝 / 宝物 / 道韵图标 | `assets/v2/weapons/`、`assets/v2/items/`、`assets/v2/arcana/` | `PNG (RGBA)` | 最长边 `192~256px` | 45° 斜置或端正居中，透明底，外描边饱满 |
| 怪物精灵表 | `assets/sprites/` | `PNG (RGBA)` | 单帧 `96×96` 横条（`576×96` 6 帧或 `768×96` 8 帧） | 帧间对齐脚底基准线，无地面影，面向右 |
| 战斗无缝地砖 | `assets/v2/map_ch*/`、`assets/terrain/` | `PNG (RGB)` | `512×512` | 无缝四方连续（Seamless），低对比无明显接缝 |
| 地图地标 / 掩体 | `assets/v2/map_ch*/` | `PNG (RGBA)` | `256~384px` | 透明底，底部留出锚点空间，无投影 |
| 封面 / 章节剧情图 | `assets/art/` | `PNG (RGB)` | `1280×720`（16:9） | 无文字无边框，左右留出 UI 排版呼吸区 |

---

## 3. 分品类「黄金参考图（Style Anchor）」

生成或重绘任何同品类资产时，优先将以下仓库现存样板图作为视觉锚点（`--ref-image` 或人工同屏对照）：

| 品类 | 黄金参考图（可放心对齐） | 关键参考点 |
| :--- | :--- | :--- |
| 封面 / 剧情图 | `res://assets/art/title_bg.png` | 青绿设色山峦、暖金云霞、柔粉桃花、清雅细墨线 |
| 法宝 / 宝物 / 道韵图标 | `res://assets/v2/weapons/wpn_jade_sword.png`<br>`res://assets/v2/weapons/wpn_fire_gourd.png`<br>`res://assets/v2/weapons/wpn_thunder_talisman.png` | 3~5px 深墨外框、明快 2 阶高光、45° 动态斜置构图 |
| 仙修人型主角 | `res://assets/v2/heroes/hero_sword_qwen.png`<br>`res://assets/v2/heroes/hero_jinyiwei_v2.png`<br>`res://assets/v2/heroes/hero_cloud_fairy.png` | 3 头身比例、干净发丝与衣纹、玉青/朱红/鎏金配色 |
| 灵物团子主角 | `res://assets/v2/heroes/hero_mochi_daoist.png`<br>`res://assets/v2/heroes/hero_fox_dango.png`<br>`res://assets/v2/heroes/hero_gourd_blob.png` | 1.5 头身圆润团子、清亮大眼、同源赛璐璐质感 |
| Q 版怪物与妖兽 | `res://assets/sprites/anim_jiangshi_run.png`<br>`res://assets/sprites/anim_fox_run.png`<br>`res://assets/sprites/anim_shenjing_run.png` | Q 版妖灵比例、明快配色、统一 96px 精灵帧清晰度 |
| 无缝战斗地砖 | `res://assets/v2/map_ch1/tile_grass_512.png`<br>`res://assets/terrain/tile_ch2_sunset_blossom_512.png` | 柔和宣纸水彩晕染、低饱和、零黑边压迫感 |
| 地图地标掩体 | `res://assets/v2/map_ch1/prop_pine_tree.png` | 2.5D 俯视角度与水彩填充（新图外轮廓需再收细约 20%） |

---

## 4. 风格漂移与历史遗留待重绘清单（禁止参考）

下列文件属于早期像素版或不同阶段画风漂移产物，**严禁在生图或修图时作为风格参考**，后续按优先级逐步替换并将旧图移入 `assets/_legacy_unused/`：

| 优先级 | 涉及资产 | 漂移原因 | 后续重绘方向 |
| :--- | :--- | :--- | :--- |
| **P0 · 跨次元像素** | `assets/creatures/wolf_boss.png`、`wolf_elite.png`、`wolf_minion.png`（旧图已从仓库清理，后续按圣经新绘）；`assets/icons/relic_*.png` | 早期硬锯齿像素风，与 V2 高清墨线赛璐璐格格不入 | 按 `anim_fox_run.png` / `wpn_fire_gourd.png` 风格重绘为高清 RGBA 精灵与图标 |
| **P0 · 写实真兽比例** | `assets/sprites/anim_huodou_run.png` | 写实猛犬解剖与暗黑火焰肌理，完全脱离 Q 版世界观 | 重绘为大头短腿 Q 版灵犬祸斗（对齐 `anim_fox_run.png` 比例） |
| **P1 · 重厚涂偏欧美** | `assets/sprites/anim_jinchan_run.png`、`assets/sprites/anim_shanxiao_run.png` | 体积光影与肌肉厚涂过重，和纸人/小僵不同源 | 减薄厚涂体积，收拢为 2~3 阶赛璐璐 + 清晰深墨外框 |
| **P1 · 插画语言割裂** | `assets/art/chapter_1.png`~`chapter_6.png`（旧图已从仓库清理，后续按圣经新绘） | 暗夜纯色矢量剪影，与 `title_bg.png` 青绿山水脱节 | 统一重绘为青绿水彩国漫山水构图 |
| **P2 · 局部细节修整** | `assets/v2/map_ch1/poi_demon_stele.png`、`poi_incense_brazier.png`、`assets/v2/heroes/hero_deer_spirit.png` | 镇魔碑含 AI 乱码汉字且描边过粗；香炉外线过粗；青木鹿灵描边偏彩色厚涂 | 去除碑面伪汉字改用抽象云篆，统一 3px 深墨线收口 |

---

## 5. 可直接复用的生图风格锁模板

> 已同步内置于 `tools/comfyui_gen_asset.py`（可通过 `--style <模板名>` 自动注入）。

### 全局负面清单（`STYLE_GLOBAL_NEGATIVE`）
```text
photorealistic, 3d render, octane render, unreal engine, pixel art, 8-bit, oil painting, heavy impasto, dark gritty horror, western fantasy armor, gothic architecture, sci-fi neon, tactical military gear, readable chinese characters, kanji, hanzi calligraphy, gibberish text, watermark, signature, floor shadow, cast shadow, drop shadow, dramatic dark backlighting, ambient occlusion dirt, cropped, cut off, extra limbs, deformed hands, checkerboard background
```

### 7 套品类正向风格锁骨架

1. **`hero_humanoid`（仙修人型主角 · 1024×1024）**
   - 前缀：`Anime cel-shaded 2D Donghua Xianxia game character art, clean ink-outlined style, 3-head stylized chibi proportions, three-quarter top-down 35-degree view facing right, bright expressive eyes, soft top-left studio daylight, flat 2-tier cel shading, deep dark-ink outline (2-3px), refined jade cyan, warm gold and crimson palette, `
   - 后缀：`, full body centered with generous margin, pure solid white background, no floor shadow, no text.`
2. **`hero_dango`（灵物团子主角 · 1024×1024）**
   - 前缀：`Cute Brotato-inspired 2D Donghua Xianxia chibi mascot character art, 1.5-head round squishy mochi proportions, three-quarter top-down 35-degree view facing right, clean deep dark-ink outline (2-3px), bright expressive anime eyes, flat 2-tier cel shading, soft top-left daylight, `
   - 后缀：`, centered with generous margin, pure solid white background, no floor shadow, no text.`
3. **`monster_chibi`（Q 版妖灵怪物 · 1024×1024）**
   - 前缀：`Anime cel-shaded 2D Donghua Xianxia chibi monster sprite art, cute-fierce stylized 1.8-head proportions, three-quarter top-down 35-degree view facing right, clean deep dark-ink outline (2-3px), flat 2-tier cel shading, soft top-left lighting, clear readable silhouette, `
   - 后缀：`, full body centered with wide margin, pure solid white background, no floor shadow, no realistic anatomy, no text.`
4. **`icon_fabao`（法宝 / 宝物 / 道韵图标 · 1024×1024）**
   - 前缀：`2D Chinese Xianxia game item icon sticker art, cel-shaded anime style with bold clean deep dark-ink outer outline (4px) and crisp inner lines (1.5px), 45-degree diagonal presentation, 2-tier cel shading with crisp specular highlight, vibrant jade, gold and cinnabar tones, `
   - 后缀：`, single isolated object centered with clean margin, pure solid white background, no floor shadow, no readable text.`
5. **`map_prop`（地图地标与掩体 · 1024×1024）**
   - 前缀：`2D Chinese Xianxia arena prop and landmark illustration, three-quarter top-down 35-degree view, clean medium dark-ink outline (3px) with gentle watercolor wash fill, muted low-to-medium saturation mineral colors, soft top-left daylight, `
   - 后缀：`, single object centered with bottom margin, pure solid white background, no floor shadow, no readable chinese text or gibberish glyphs.`
6. **`terrain_tile`（战斗无缝地面地砖 · 512×512）**
   - 前缀：`Seamless tileable 2D top-down game ground texture, soft Chinese watercolor wash on warm rice-paper base, ultra low saturation, subtle sparse fine ink grass and pebble accents, flat even illumination, `
   - 后缀：`, seamless edges on all four sides, no thick dark outlines, no shadows, no large rocks, no text.`
7. **`story_keyart`（封面 / 章节山水插画 · 1280×720）**
   - 前缀：`Traditional Chinese blue-green landscape (Qinglv Shanshui) Donghua illustration, delicate clean ink linework with luminous watercolor gradients, ethereal golden clouds, mist-veiled peaks, serene Xianxia atmosphere, `
   - 后缀：`, widescreen 16:9 composition with breathing room for UI overlay, no text, no watermark, no frame.`

---

## 6. 入库前 5 步同屏视觉验收闸门

任何新资源写入 `data/v2/*.json` 前，必须通过以下 5 项检查：
1. **实际像素同屏贴合**：把新图缩放到游戏内实际显示像素（角色/怪物约 `64~96px`，图标约 `48~64px`），直接叠放在 `tile_grass_512.png` 上，紧挨着对应品类的黄金参考图目视对比 5 秒——线条粗细、明暗反差、饱和度都不能“跳出画面”。
2. **投影与边缘清理**：检查透明底边缘无白边/绿边残留（Halo），图内无自带脚底阴影。
3. **文字安全检查**：碑文、符纸、幡面、卷轴上不能出现扭曲伪汉字。
4. **SSOT 路径登记**：在 `data/v2/*.json` 登记 `res://...` 完整路径；旧版本文件移入 `assets/_legacy_unused/`。
5. **巡检闭环**：运行 `python tools/studio_audit.py` 与 `python tools/studio_audit.py --strict`，确认无新增断链或孤立资源告警。
