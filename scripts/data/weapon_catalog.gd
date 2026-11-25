class_name WeaponCatalog

const MAX_WEAPON_SLOTS := 4
const MAX_PASSIVE_SLOTS := 6
const MAX_WEAPON_LEVEL := 8
const MAX_PASSIVE_LEVEL := 5

const WEAPONS := {
	"lotus_slash": {
		"id": "lotus_slash",
		"name": "青莲剑气",
		"evo_name": "青莲剑歌",
		"partner_passive": "sword_jade",
		"icon": "res://assets/icons/icon_qingzhu_sword.png",
		"evo_icon": "res://assets/icons/icon_qingzhu_sword.png",
		"tag": "剑诀",
		"evo_desc": "360° 盛放青莲剑浪，暴击爆散青色花瓣剑刃并回复气血！",
		"level_descs": [
			"朝鼠标方向挥出宽阔青玉半月剑气，穿透并击退妖物。",
			"前后双向同时斩出青莲剑气，护住背后。",
			"剑气范围扩大 22%，基础伤害提升至 68。",
			"剑意连段：每次挥斩追加第二道连续剑弧。",
			"挥斩冷却缩短至 0.85 秒，暴击率提升 8%。",
			"剑气化作宽广青玉剑浪，伤害跃升至 106。",
			"四方十字剑气齐发，近中距离无死角清场。",
			"剑气臻至化境：高速三连剑弧（配【剑心玉佩】开箱进化）。",
		],
		"level_stats": [
			{"dmg": 46.0, "cd": 1.08, "rad": 116.0, "kb": 150.0, "waves": 0, "dirs": 1},
			{"dmg": 54.0, "cd": 1.05, "rad": 122.0, "kb": 160.0, "waves": 0, "dirs": 2},
			{"dmg": 68.0, "cd": 1.02, "rad": 148.0, "kb": 170.0, "waves": 0, "dirs": 2},
			{"dmg": 78.0, "cd": 0.98, "rad": 154.0, "kb": 175.0, "waves": 1, "dirs": 2},
			{"dmg": 88.0, "cd": 0.85, "rad": 160.0, "kb": 182.0, "waves": 1, "dirs": 2},
			{"dmg": 106.0, "cd": 0.82, "rad": 172.0, "kb": 190.0, "waves": 1, "dirs": 2},
			{"dmg": 118.0, "cd": 0.78, "rad": 178.0, "kb": 195.0, "waves": 1, "dirs": 4},
			{"dmg": 135.0, "cd": 0.74, "rad": 186.0, "kb": 205.0, "waves": 2, "dirs": 4},
		],
	},
	"flying_sword": {
		"id": "flying_sword",
		"name": "子母飞剑",
		"evo_name": "万剑归宗",
		"partner_passive": "spirit_gourd",
		"icon": "res://assets/sprites/fx_flying_sword.png",
		"evo_icon": "res://assets/sprites/fx_flying_sword.png",
		"tag": "御剑",
		"evo_desc": "近乎无冷却的青金剑雨连绵齐射，命中后高速折射弹跳清屏！",
		"level_descs": [
			"自动锁定最近妖物射出青玉飞剑，穿透 2 名敌人。",
			"每次连射飞剑数量增至 2 柄，飞行速度提升。",
			"飞剑穿透增至 3 名，基础伤害提高至 52。",
			"施放间隔缩短至 0.86 秒，连射增至 3 柄。",
			"飞剑伤害提高至 72，击退力大幅增强。",
			"扇形剑阵齐发 4 柄，穿透增至 4 名。",
			"施放间隔缩至 0.62 秒，剑阵增至 5 柄。",
			"六剑齐发穿云裂石（配【聚灵葫芦】开箱进化）。",
		],
		"level_stats": [
			{"dmg": 38.0, "cd": 1.12, "spd": 610.0, "count": 1, "pierce": 2, "kb": 65.0},
			{"dmg": 44.0, "cd": 1.04, "spd": 650.0, "count": 2, "pierce": 2, "kb": 72.0},
			{"dmg": 52.0, "cd": 0.98, "spd": 680.0, "count": 2, "pierce": 3, "kb": 78.0},
			{"dmg": 58.0, "cd": 0.86, "spd": 710.0, "count": 3, "pierce": 3, "kb": 84.0},
			{"dmg": 72.0, "cd": 0.80, "spd": 740.0, "count": 3, "pierce": 3, "kb": 115.0},
			{"dmg": 84.0, "cd": 0.72, "spd": 770.0, "count": 4, "pierce": 4, "kb": 122.0},
			{"dmg": 96.0, "cd": 0.62, "spd": 810.0, "count": 5, "pierce": 4, "kb": 130.0},
			{"dmg": 112.0, "cd": 0.52, "spd": 850.0, "count": 6, "pierce": 5, "kb": 140.0},
		],
	},
	"taiji_array": {
		"id": "taiji_array",
		"name": "八卦剑阵",
		"evo_name": "两仪太极剑域",
		"partner_passive": "cloud_boots",
		"icon": "res://assets/icons/icon_taichi_array.png",
		"evo_icon": "res://assets/icons/icon_taichi_array.png",
		"tag": "剑阵",
		"evo_desc": "永驻高速旋转的青金太极巨剑阵，外圈剑罡将近身妖物瞬间绞碎！",
		"level_descs": [
			"召唤 2 柄纯阳飞剑环绕周身旋转切割，击退近身妖物。",
			"护体飞剑数量增至 3 柄，旋转半径扩大。",
			"转速提升 25%，剑阵伤害提高至 40。",
			"护体飞剑数量增至 4 柄。",
			"旋转半径扩至 114，击退力增强。",
			"护体飞剑数量增至 5 柄，伤害再提至 66。",
			"转速大幅提升，高频绞杀近身妖群。",
			"六剑成阵护体生罡（配【流云步靴】开箱进化）。",
		],
		"level_stats": [
			{"dmg": 26.0, "count": 2, "rad": 84.0, "rot_speed": 3.2, "kb": 110.0},
			{"dmg": 31.0, "count": 3, "rad": 94.0, "rot_speed": 3.4, "kb": 118.0},
			{"dmg": 40.0, "count": 3, "rad": 98.0, "rot_speed": 4.2, "kb": 124.0},
			{"dmg": 48.0, "count": 4, "rad": 104.0, "rot_speed": 4.4, "kb": 130.0},
			{"dmg": 56.0, "count": 4, "rad": 114.0, "rot_speed": 4.7, "kb": 152.0},
			{"dmg": 66.0, "count": 5, "rad": 120.0, "rot_speed": 5.0, "kb": 160.0},
			{"dmg": 78.0, "count": 5, "rad": 126.0, "rot_speed": 6.1, "kb": 168.0},
			{"dmg": 92.0, "count": 6, "rad": 134.0, "rot_speed": 6.5, "kb": 180.0},
		],
	},
	"thunder_seal": {
		"id": "thunder_seal",
		"name": "九霄引雷符",
		"evo_name": "紫霄神雷劫",
		"partner_passive": "wind_orb",
		"icon": "res://assets/icons/icon_jiutian_thunder.png",
		"evo_icon": "res://assets/icons/icon_jiutian_thunder.png",
		"tag": "雷法",
		"evo_desc": "暴雨般倾泻密集紫金天雷，每道落雷均触发多段连锁电弧！",
		"level_descs": [
			"锁定场上妖物劈落青金天雷，造成范围爆发伤害。",
			"每次施法落雷数增至 2 道。",
			"落雷爆炸范围扩大 25%，伤害提高至 96。",
			"施法冷却缩短至 1.90 秒，落雷数增至 3 道。",
			"雷霆伤害提高至 132。",
			"每次施法落雷数增至 4 道，范围再扩。",
			"施法冷却缩至 1.38 秒，天雷连绵落下。",
			"五雷正法齐轰大地（配【定风珠】开箱进化）。",
		],
		"level_stats": [
			{"dmg": 72.0, "cd": 2.45, "rad": 74.0, "count": 1},
			{"dmg": 82.0, "cd": 2.30, "rad": 80.0, "count": 2},
			{"dmg": 96.0, "cd": 2.20, "rad": 98.0, "count": 2},
			{"dmg": 110.0, "cd": 1.90, "rad": 102.0, "count": 3},
			{"dmg": 132.0, "cd": 1.75, "rad": 106.0, "count": 3},
			{"dmg": 148.0, "cd": 1.62, "rad": 116.0, "count": 4},
			{"dmg": 168.0, "cd": 1.38, "rad": 120.0, "count": 4},
			{"dmg": 192.0, "cd": 1.24, "rad": 128.0, "count": 5},
		],
	},
	"fire_lotus": {
		"id": "fire_lotus",
		"name": "朱砂爆炎符",
		"evo_name": "业火红莲阵",
		"partner_passive": "fire_lamp",
		"icon": "res://assets/icons/icon_taiyi_talisman.png",
		"evo_icon": "res://assets/icons/icon_taiyi_talisman.png",
		"tag": "符箓",
		"evo_desc": "落点绽放巨大旋转红莲火海，妖物在火海中阵亡会触发连锁殉爆！",
		"level_descs": [
			"掷出朱砂灵符炸开一朵爆炎火莲，持续灼烧范围妖物。",
			"每次掷出灵符数量增至 2 枚。",
			"火莲灼烧半径扩大 25%，爆炸伤害提高至 56。",
			"火莲持续时间延长至 4.2 秒。",
			"每次掷出灵符增至 3 枚，伤害提高至 78。",
			"火莲半径再扩至 102，灼烧伤害大增。",
			"冷却缩至 1.80 秒，遍地火莲绽放。",
			"四符齐落焚尽群妖（配【玄火灯】开箱进化）。",
		],
		"level_stats": [
			{"dmg": 40.0, "burn": 12.0, "cd": 2.70, "rad": 70.0, "dur": 3.1, "count": 1},
			{"dmg": 46.0, "burn": 15.0, "cd": 2.55, "rad": 74.0, "dur": 3.3, "count": 2},
			{"dmg": 56.0, "burn": 19.0, "cd": 2.45, "rad": 90.0, "dur": 3.4, "count": 2},
			{"dmg": 64.0, "burn": 22.0, "cd": 2.30, "rad": 92.0, "dur": 4.2, "count": 2},
			{"dmg": 78.0, "burn": 27.0, "cd": 2.15, "rad": 95.0, "dur": 4.3, "count": 3},
			{"dmg": 90.0, "burn": 32.0, "cd": 2.02, "rad": 106.0, "dur": 4.5, "count": 3},
			{"dmg": 104.0, "burn": 37.0, "cd": 1.80, "rad": 110.0, "dur": 4.7, "count": 3},
			{"dmg": 120.0, "burn": 42.0, "cd": 1.66, "rad": 116.0, "dur": 5.0, "count": 4},
		],
	},
	"jade_aura": {
		"id": "jade_aura",
		"name": "净灵护体波",
		"evo_name": "净世莲台",
		"partner_passive": "spirit_pill",
		"icon": "res://assets/sprites/fx_jade_lotus_aura.png",
		"evo_icon": "res://assets/sprites/fx_jade_lotus_aura.png",
		"tag": "灵光",
		"evo_desc": "常驻流光青莲气场，高频震退减速近身妖物，击杀持续回复气血！",
		"level_descs": [
			"周身展开青莲净灵气场，定时震伤并轻推靠近的妖物。",
			"青莲气场范围扩大 22%，伤害提高至 24。",
			"灵波脉动加快至 0.48 秒，击退增强。",
			"气场范围再扩至 134，伤害提高至 36。",
			"附带清心减速效果，靠近的妖物脚步变慢。",
			"灵波脉动加快至 0.38 秒，伤害提升至 46。",
			"气场范围大幅扩展，弱小妖灵难以近身。",
			"净灵青莲圆满无瑕（配【养神丹】开箱进化）。",
		],
		"level_stats": [
			{"dmg": 18.0, "cd": 0.60, "rad": 96.0, "kb": 70.0, "slow": 0.0},
			{"dmg": 24.0, "cd": 0.56, "rad": 116.0, "kb": 78.0, "slow": 0.0},
			{"dmg": 29.0, "cd": 0.48, "rad": 120.0, "kb": 95.0, "slow": 0.0},
			{"dmg": 36.0, "cd": 0.45, "rad": 134.0, "kb": 105.0, "slow": 0.0},
			{"dmg": 41.0, "cd": 0.43, "rad": 142.0, "kb": 112.0, "slow": 0.28},
			{"dmg": 46.0, "cd": 0.38, "rad": 152.0, "kb": 122.0, "slow": 0.30},
			{"dmg": 54.0, "cd": 0.35, "rad": 168.0, "kb": 132.0, "slow": 0.32},
			{"dmg": 64.0, "cd": 0.32, "rad": 178.0, "kb": 145.0, "slow": 0.35},
		],
	},
	"shenji_musket": {
		"id": "shenji_musket",
		"name": "神机火铳·爆炎弹",
		"evo_name": "锦衣神机·天火流星",
		"partner_passive": "fire_lamp",
		"icon": "res://assets/icons/icon_shenji_musket.png",
		"evo_icon": "res://assets/icons/icon_shenji_musket.png",
		"tag": "火器",
		"evo_desc": "神机双铳与肩悬龙首重炮齐鸣，高速倾泻赤金穿甲爆炎弹幕，命中炸裂火海！",
		"level_descs": [
			"平端大明鎏金神机火铳高速点射穿甲火铳弹，穿透 2 名敌人。",
			"装填双联弹丸：每次击发连射 2 发火铳弹，射速提升。",
			"更换赤金爆炎火药：子弹命中时触发小范围火药爆震，伤害提至 54。",
			"神机连发：每次射击扩为 3 发窄扇形弹幕，射击间隔缩至 0.68 秒。",
			"穿甲火药强化：穿透增至 3 名敌人，爆震半径扩大，伤害提至 68。",
			"四联齐射：每次轰出 4 发爆炎弹，击退力与弹速大幅提升。",
			"神机急射：射击间隔缩至 0.48 秒，弹幕增至 5 发。",
			"六发爆炎齐射裂石穿云（配【玄火灯】开箱进化为天火流星）。",
		],
		"level_stats": [
			{"dmg": 42.0, "cd": 0.84, "spd": 880.0, "count": 1, "pierce": 2, "blast": 0.0, "kb": 85.0},
			{"dmg": 48.0, "cd": 0.78, "spd": 910.0, "count": 2, "pierce": 2, "blast": 0.0, "kb": 92.0},
			{"dmg": 54.0, "cd": 0.74, "spd": 940.0, "count": 2, "pierce": 2, "blast": 46.0, "kb": 100.0},
			{"dmg": 60.0, "cd": 0.68, "spd": 970.0, "count": 3, "pierce": 2, "blast": 50.0, "kb": 108.0},
			{"dmg": 68.0, "cd": 0.62, "spd": 1000.0, "count": 3, "pierce": 3, "blast": 58.0, "kb": 118.0},
			{"dmg": 78.0, "cd": 0.56, "spd": 1040.0, "count": 4, "pierce": 3, "blast": 64.0, "kb": 128.0},
			{"dmg": 88.0, "cd": 0.48, "spd": 1080.0, "count": 5, "pierce": 3, "blast": 70.0, "kb": 136.0},
			{"dmg": 102.0, "cd": 0.42, "spd": 1120.0, "count": 6, "pierce": 4, "blast": 78.0, "kb": 148.0},
		],
	},
}

const PASSIVES := {
	"sword_jade": {
		"id": "sword_jade",
		"name": "剑心玉佩",
		"icon": "res://assets/icons/relic_insight.png",
		"tag": "法宝",
		"evolves_weapon": "lotus_slash",
		"max_level": MAX_PASSIVE_LEVEL,
		"desc": "所有神通暴击率 +7%，暴击伤害 +15%。",
	},
	"spirit_gourd": {
		"id": "spirit_gourd",
		"name": "聚灵葫芦",
		"icon": "res://assets/icons/relic_wind.png",
		"tag": "法宝",
		"evolves_weapon": "flying_sword",
		"max_level": MAX_PASSIVE_LEVEL,
		"desc": "所有神通冷却缩减 8%，拾取范围 +18%。",
	},
	"cloud_boots": {
		"id": "cloud_boots",
		"name": "流云步靴",
		"icon": "res://assets/icons/relic_boots.png",
		"tag": "法宝",
		"evolves_weapon": "taiji_array",
		"max_level": MAX_PASSIVE_LEVEL,
		"desc": "移动速度 +10%，踏云瞬斩冷却缩减 12%。",
	},
	"wind_orb": {
		"id": "wind_orb",
		"name": "定风珠",
		"icon": "res://assets/icons/relic_luck.png",
		"tag": "法宝",
		"evolves_weapon": "thunder_seal",
		"max_level": 3,
		"desc": "所有神通弹道/目标数量 +1（高阶珍宝，最多 3 级）。",
	},
	"fire_lamp": {
		"id": "fire_lamp",
		"name": "玄火灯",
		"icon": "res://assets/icons/relic_armor.png",
		"tag": "法宝",
		"evolves_weapon": "fire_lotus",
		"max_level": MAX_PASSIVE_LEVEL,
		"desc": "所有神通攻击范围与尺寸 +12%，伤害 +8%。",
	},
	"spirit_pill": {
		"id": "spirit_pill",
		"name": "养神丹",
		"icon": "res://assets/icons/relic_pill.png",
		"tag": "法宝",
		"evolves_weapon": "jade_aura",
		"max_level": MAX_PASSIVE_LEVEL,
		"desc": "气血上限 +25，每秒自动回血 +0.8，立即恢复 25 点气血。",
	},
}

static func weapon_ids() -> Array[String]:
	var out: Array[String] = []
	for k in WEAPONS.keys():
		out.append(str(k))
	return out

static func passive_ids() -> Array[String]:
	var out: Array[String] = []
	for k in PASSIVES.keys():
		out.append(str(k))
	return out

static func get_weapon(id: String) -> Dictionary:
	return WEAPONS.get(id, {})

static func get_passive(id: String) -> Dictionary:
	return PASSIVES.get(id, {})

static func weapon_stat(id: String, lv: int) -> Dictionary:
	var w := get_weapon(id)
	var arr: Array = w.get("level_stats", [])
	if arr.is_empty():
		return {}
	return arr[clampi(lv - 1, 0, arr.size() - 1)]

static func weapon_level_desc(id: String, next_level: int) -> String:
	var w := get_weapon(id)
	if w.is_empty():
		return ""
	var descs: Array = w.get("level_descs", [])
	var idx := clampi(next_level - 1, 0, descs.size() - 1)
	return str(descs[idx])

static func evolution_hint_for_weapon(weapon_id: String) -> String:
	var w := get_weapon(weapon_id)
	if w.is_empty():
		return ""
	var pid := str(w.get("partner_passive", ""))
	var p := get_passive(pid)
	if p.is_empty():
		return ""
	return "✦ 满级 +【%s】→ 超武【%s】" % [str(p["name"]), str(w["evo_name"])]

static func evolution_hint_for_passive(passive_id: String) -> String:
	var p := get_passive(passive_id)
	if p.is_empty():
		return ""
	var wid := str(p.get("evolves_weapon", ""))
	var w := get_weapon(wid)
	if w.is_empty():
		return ""
	return "✦ 可助【%s】进化为【%s】" % [str(w["name"]), str(w["evo_name"])]
