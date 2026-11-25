class_name Story
## 全局剧情文本库：开场引子、六章首尾、胜负结语。
## 文本只在这里维护，chapters.gd 通过静态函数取用，避免同一段话写两遍。

## 标题界面副标题
const TITLE_SUBTITLE: String = "循玉简入大荒 · 修仙割草肉鸽"

## 标题进游戏时播放的开场引子
const OPENING: Array = [
	"三月前，师妹阿箬留下一枚残缺玉简，只写了四个字：速离青冥林。",
	"她没写理由。玉简背面却多了一道血痕，像被人仓促抹去。",
]

## 每章开头两行引子
const CHAPTER_INTRO: Dictionary = {
	1: [
		"林雾压得极低，像一层没散干净的旧灰。",
		"阿箬的玉简在这里第一次发烫，指向林心深处。",
	],
	2: [
		"赤砂上没有风，沙子却一直在动。",
		"血月当空，沙下埋着的不是尸骨，是还没凉透的念想。",
	],
	3: [
		"忘川两岸挂满灯笼，灯里燃的是记忆。",
		"这里的鬼市专收失散修士的魂，价钱面议，货到付命。",
	],
	4: [
		"九幽之下没有土，骨头就是地。",
		"每一根肋骨都刻着功法，刻法与阿箬的师尊一模一样。",
	],
	5: [
		"祭坛上摆着七十二个空位，缺口正一盏盏亮起血光。",
		"血月教在拿活人炼妖，今夜轮到第九批。",
	],
	6: [
		"妖巢之下，全是人的脸。",
		"玉简在掌心烧起来，最后一行字浮出：阿箬，别回头。",
	],
}

## 每章结尾一行结语
const CHAPTER_OUTRO: Dictionary = {
	1: "苍鬃狼王倒下时，玉简上的血痕却淡了一分。有人不想你看到她看见了什么。",
	2: "赤煞狼王散作一地黄沙。沙里露出半截白骨，指骨上刻着阿箬的名字。",
	3: "渡魂使者沉入忘川。玉简亮起一行新字：别信带血的月亮。",
	4: "白骨魔将碎成齑粉。你在它的头盔里摸到一枚血月教的令牌。",
	5: "血祭妖帅散作黑雾。坛底露出阿箬的背影——她站在祭阵中央，没有回头。",
	6: "啸月妖王的两颗头都落了下来，大荒忽然安静了。",
}

const VICTORY_TEXT: String = "血月教的祭坛塌了，那些被炼成妖的残魂一个个松开手，变回原来的名字。阿箬的名字排在第七十二位。你合上玉简：道途未竟，但她还在。"

const DEFEAT_TEXT: String = "道途未竟。你倒在雾里，玉简从怀里滑出去，那半枚玉简仍朝着阿箬的方向亮着。"

## 标题与结局插画路径（缺失时由调用方走程序化兜底）
const TITLE_ART_PATH: String = "res://assets/art/title_bg.png"
const ENDING_ART_PATH: String = "res://assets/art/ending.png"


## 标题界面播的开场引子
static func opening_lines() -> Array[String]:
	return _to_string_array(OPENING)


## 第 chapter_id 章的开场引子（两行）
static func chapter_intro(chapter_id: int) -> Array[String]:
	return _to_string_array(CHAPTER_INTRO.get(chapter_id, []))


## 第 chapter_id 章的章末结语（一行）
static func chapter_outro(chapter_id: int) -> String:
	return String(CHAPTER_OUTRO.get(chapter_id, ""))


## 通关结局文本
static func victory_text() -> String:
	return VICTORY_TEXT


## 失败结语
static func defeat_text() -> String:
	return DEFEAT_TEXT


static func _to_string_array(source: Array) -> Array[String]:
	var out: Array[String] = []
	for item in source:
		out.append(String(item))
	return out
