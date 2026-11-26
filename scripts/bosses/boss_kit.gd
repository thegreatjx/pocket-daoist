class_name BossKit
extends RefCounted

var boss: Node


func setup(owner_boss: Node) -> void:
	boss = owner_boss


func on_phase2() -> void:
	pass


func on_hurt() -> void:
	pass


func update_chase(delta: float, dir: Vector2, dist: float) -> void:
	boss._boss_dashing = false
	boss._boss_strafe_phase += delta * 2.4
	var perp := Vector2(-dir.y, dir.x) * sin(boss._boss_strafe_phase) * 0.28
	boss.velocity = (dir + perp).normalized() * boss.speed * (1.0 - boss._slow_ratio)
	boss._boss_skill_cd -= delta
	var vis = boss.visual_node
	if vis != null and vis.has_method("set_boss_state"):
		vis.set_boss_state(0.0, boss._boss_enraged)
	if boss._boss_skill_cd <= 0.0 and dist <= 650.0:
		boss._begin_boss_skill(dir)


func update_action(_delta: float) -> void:
	pass


func begin(dir: Vector2) -> void:
	boss._boss_state = Enemy.BossState.WINDUP
	boss._boss_aim_dir = dir
	boss._boss_skill_index = (boss._boss_skill_index + 1) % 3
	Sfx.play_boss_or_fallback("boss_charge", "dash", -4.0, 0.85)
	if boss.get_parent() != null:
		V2VfxFactory.spawn_boss_charge_aura(boss.get_parent(), boss.global_position, 64.0, Color(1.0, 0.36, 0.24, 0.85), 0.50)
	if boss.species == 1:
		match boss._boss_skill_index:
			0:
				boss._boss_active_skill = "talisman_ring"
				boss._boss_state_timer = 0.48
				boss._boss_windup_total = 0.48
				boss._spawn_boss_circles(5 if boss._boss_enraged else 3, 82.0, 0.72, 22.0)
			1:
				boss._boss_active_skill = "volley"
				boss._boss_state_timer = 0.46
				boss._boss_windup_total = 0.46
			_:
				boss._boss_active_skill = "slam"
				boss._boss_state_timer = 0.58
				boss._boss_windup_total = 0.58
				boss._spawn_boss_circles(2 if boss._boss_enraged else 1, 124.0, 0.68, 25.0)
	elif boss.species == 2:
		match boss._boss_skill_index:
			0:
				boss._boss_active_skill = "slam"
				boss._boss_state_timer = 0.60
				boss._boss_windup_total = 0.60
				boss._spawn_boss_circles(2 if boss._boss_enraged else 1, 134.0 if boss._boss_enraged else 115.0, 0.68, 28.0)
			1:
				boss._boss_active_skill = "dash"
				boss._boss_state_timer = 0.54
				boss._boss_windup_total = 0.54
				boss._spawn_boss_dash_corridor(450.0, 74.0, 0.54)
			_:
				boss._boss_active_skill = "volley"
				boss._boss_state_timer = 0.48
				boss._boss_windup_total = 0.48
	else:
		match boss._boss_skill_index:
			0:
				boss._boss_active_skill = "dash"
				boss._boss_state_timer = 0.54
				boss._boss_windup_total = 0.54
				boss._spawn_boss_dash_corridor(480.0 if boss._boss_enraged else 420.0, 68.0, 0.54)
			1:
				boss._boss_active_skill = "volley"
				boss._boss_state_timer = 0.48
				boss._boss_windup_total = 0.48
			_:
				boss._boss_active_skill = "summon_pack"
				boss._boss_state_timer = 0.52
				boss._boss_windup_total = 0.52


func execute() -> void:
	boss._boss_state = Enemy.BossState.ACTION
	boss._boss_dash_ghost_cd = 0.0
	var vis = boss.visual_node
	if vis != null and vis.has_method("trigger_attack_lunge"):
		vis.trigger_attack_lunge(boss._boss_aim_dir)
	match boss._boss_active_skill:
		"dash":
			boss._boss_state_timer = 0.36
			Sfx.play_boss_or_fallback("boss_dash", "dash", -2.0, 0.78)
		"slam":
			boss._boss_state_timer = 0.28
			if vis != null and vis.has_method("trigger_land_impact"):
				vis.trigger_land_impact(1.6)
		"talisman_ring":
			boss._boss_state_timer = 0.28
			Sfx.play_boss_or_fallback("boss_roar", "thunder", -4.0, 1.15)
		"volley":
			boss._boss_state_timer = 0.32
			boss._fire_boss_volley()
		"summon_pack":
			boss._boss_state_timer = 0.36
			boss._summon_wolf_pack()
		_:
			boss._boss_state_timer = 0.24


func finish() -> void:
	boss._boss_dashing = false
	if boss._boss_active_skill == "dash":
		var vis = boss.visual_node
		if vis != null and vis.has_method("trigger_land_impact"):
			vis.trigger_land_impact(1.35)
		if boss.get_parent() != null:
			V2VfxFactory.spawn_boss_shockwave(boss.get_parent(), boss.global_position, 92.0, Color(0.98, 0.32, 0.22, 0.9), Color(1.0, 0.85, 0.35, 1.0), 0.34)
	boss._boss_state = Enemy.BossState.RECOVER
	boss._boss_state_timer = 0.20 if boss._boss_enraged else 0.32
