extends Node
class_name UpgradeManager

# 升级项定义
# id: 标识  title: 名称  desc: 描述  tag: 类别标签
# max_level: 最大等级  level: 当前等级  weight: 抽取权重
# is_evo/req_id/req_level: 进化神通前置条件 (可选)

var upgrades: Dictionary = {
	"sword_amount": {
		"id": "sword_amount",
		"title": "青竹剑影",
		"desc": "青竹蜂云剑弹道数量 +1，穿透 +1",
		"tag": "【飞剑】",
		"level": 0,
		"max_level": 5,
		"weight": 10
	},
	"sword_speed": {
		"id": "sword_speed",
		"title": "御剑疾风",
		"desc": "飞剑攻击间隔缩减 20%，飞剑飞行速度 +25%",
		"tag": "【飞剑】",
		"level": 0,
		"max_level": 4,
		"weight": 10
	},
	"sword_damage": {
		"id": "sword_damage",
		"title": "青霄剑芒",
		"desc": "飞剑伤害提高 40%",
		"tag": "【飞剑】",
		"level": 0,
		"max_level": 5,
		"weight": 10
	},
	"orbit_count": {
		"id": "orbit_count",
		"title": "太极两仪生四象",
		"desc": "护体飞剑数量 +1，旋转半径略微扩大",
		"tag": "【剑阵】",
		"level": 0,
		"max_level": 4,
		"weight": 9
	},
	"orbit_speed": {
		"id": "orbit_speed",
		"title": "真武剑罡",
		"desc": "护体剑阵旋转速度 +30%，护体剑伤害 +35%",
		"tag": "【剑阵】",
		"level": 0,
		"max_level": 4,
		"weight": 9
	},
	"thunder_power": {
		"id": "thunder_power",
		"title": "霄雷正法",
		"desc": "九天玄雷爆炸伤害 +50%，轰击范围扩大 35%",
		"tag": "【雷法】",
		"level": 0,
		"max_level": 5,
		"weight": 8
	},
	"thunder_freq": {
		"id": "thunder_freq",
		"title": "引雷诀",
		"desc": "天雷施法间隔减少 25%",
		"tag": "【雷法】",
		"level": 0,
		"max_level": 4,
		"weight": 8
	},
	"step_cloud": {
		"id": "step_cloud",
		"title": "凌波踏云步",
		"desc": "人物移动速度 +18%，踏云步闪避冷却减少 0.6 秒",
		"tag": "【身法】",
		"level": 0,
		"max_level": 4,
		"weight": 9
	},
	"immortal_body": {
		"id": "immortal_body",
		"title": "神农九转身",
		"desc": "气血上限 +35，并瞬间恢复 50% 气血",
		"tag": "【心法】",
		"level": 0,
		"max_level": 5,
		"weight": 8
	},
	"spirit_magnet": {
		"id": "spirit_magnet",
		"title": "混元聚灵诀",
		"desc": "神识吸灵范围 +60%，天地灵气经验获取 +25%",
		"tag": "【心法】",
		"level": 0,
		"max_level": 4,
		"weight": 9
	},
	"super_wanjian": {
		"id": "super_wanjian",
		"title": "【神通蜕变】万剑归宗",
		"desc": "青竹剑与养剑真意合一！每次连射 6 柄飞剑，全屏穿透！",
		"tag": "【造化神通】",
		"level": 0,
		"max_level": 1,
		"weight": 15,
		"is_evo": true,
		"req_id": "sword_amount",
		"req_level": 2
	}
}

func get_random_choices(count: int = 3) -> Array:
	var pool: Array = []
	for id in upgrades.keys():
		var u = upgrades[id]
		if u["level"] >= u["max_level"]:
			continue
		# 检查进化超武前置
		if u.get("is_evo", false):
			if upgrades[u["req_id"]]["level"] < u["req_level"]:
				continue
		pool.append(u)

	# 按权重不放回抽取
	var result: Array = []
	while pool.size() > 0 and result.size() < count:
		var total: float = 0.0
		for u in pool:
			total += float(u.get("weight", 10))
		var roll: float = randf() * total
		var acc: float = 0.0
		var pick_index: int = pool.size() - 1
		for i in range(pool.size()):
			acc += float(pool[i].get("weight", 10))
			if roll <= acc:
				pick_index = i
				break
		result.append(pool[pick_index])
		pool.remove_at(pick_index)
	return result

func apply_upgrade(upgrade_id: String, player: Node) -> void:
	if not upgrades.has(upgrade_id):
		return
	var u = upgrades[upgrade_id]
	u["level"] += 1

	match upgrade_id:
		"sword_amount":
			player.sword_count += 1
			player.sword_pierce += 1
		"sword_speed":
			player.sword_interval = maxf(0.25, player.sword_interval * 0.8)
			player.sword_fly_speed *= 1.25
		"sword_damage":
			player.sword_base_damage *= 1.4
		"orbit_count":
			player.orbit_sword_count += 1
			player.orbit_radius += 10.0
			player.refresh_orbit_swords()
		"orbit_speed":
			player.orbit_speed *= 1.3
			player.orbit_damage *= 1.35
			for sw in player.orbit_swords:
				if is_instance_valid(sw):
					sw.damage = player.orbit_damage
		"thunder_power":
			player.thunder_damage *= 1.5
			player.thunder_radius *= 1.35
		"thunder_freq":
			player.thunder_interval = maxf(0.8, player.thunder_interval * 0.75)
		"step_cloud":
			player.speed *= 1.18
			player.dash_cooldown = maxf(0.8, player.dash_cooldown - 0.6)
		"immortal_body":
			player.max_health += 35.0
			player.current_health = minf(player.max_health, player.current_health + player.max_health * 0.5)
			player.emit_signal("health_changed", player.current_health, player.max_health)
		"spirit_magnet":
			player.magnet_radius *= 1.6
			player.exp_multiplier *= 1.25
		"super_wanjian":
			player.is_wanjian_unlocked = true
			player.sword_count += 5
			player.sword_interval = 0.4
			player.sword_pierce += 5
			player.sword_base_damage *= 1.5
