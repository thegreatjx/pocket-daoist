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
		"师门试炼场外，阿箬留下的玉简第一次微微发烫。",
	],
	2: [
		"古松蔽日，石灯幽明，林间灵泉仍泛着清冽微光。",
		"玉简指向古林深处，苍鬃妖影已在雾里踱步。",
	],
	3: [
		"玄武岩地脉滚烫，残鼎与丹霞柱间不时喷出赤炎。",
		"八卦丹炉自燃不熄，谁在拿整座丹谷炼一炉煞气？",
	],
	4: [
		"风雪落满千柄断剑，寒潭薄冰下封着上古剑意。",
		"无主古剑碑尚有余温，万剑魔尊的气息就在剑冢尽头。",
	],
}

## 每章结尾一行结语
const CHAPTER_OUTRO: Dictionary = {
	1: "苍鬃狼王倒下时，玉简上的血痕却淡了一分，秘境真正的入口在林雾之外显形。",
	2: "青冥古林的妖雾散去，灵泉倒影里浮出赤炎丹谷的火光。",
	3: "八卦丹炉轰然倾覆，炉灰底下压着一枚指向北方剑冢的寒铁剑穗。",
	4: "万剑魔尊散作霜雪，千柄断剑齐鸣归鞘，玉简终于亮出下一程的方位。",
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
