class_name BossSwordMasterKit
extends BossKit

const KEEP_DIST := 285.0
const SWORD_SPEED := 345.0
const SWORD_DMG := 22.0
const SWORD_RADIUS := 12.0
const CAGE_RADIUS := 135.0
const CAGE_PILLAR_RADIUS := 52.0
const CAGE_DMG := 20.0
const RAIN_RADIUS := 72.0
const RAIN_DMG := 20.0
const SWORD_COLOR := Color(0.46, 0.86, 1.0, 1.0)


func skill_cooldown() -> float:
	return 0.95 if boss._boss_enraged else 1.40


func update_chase(delta: float, dir: Vector2, dist: float) -> void:
	boss._boss_dashing = false
	boss._boss_strafe_phase += delta * 1.2
	var tangent := Vector2(-dir.y, dir.x) * sin(boss._boss_strafe_phase)
	var move := tangent
	if dist < KEEP_DIST - 40.0:
		move = (-dir + tangent * 0.4).normalized()
	elif dist > KEEP_DIST + 100.0:
		move = (dir + tangent * 0.5).normalized()
	boss.velocity = move * boss.speed * (1.0 - boss._slow_ratio)
	var vis = boss.visual_node
	if vis != null and vis.has_method("set_boss_state"):
		vis.set_boss_state(0.0, boss._boss_enraged)
	boss._boss_skill_cd -= delta
	if boss._boss_skill_cd <= 0.0 and dist <= 760.0:
		boss._begin_boss_skill(dir)


func begin(dir: Vector2) -> void:
	boss._boss_aim_dir = dir
	var count := 3 if boss._boss_enraged else 2
	boss._boss_skill_index = (boss._boss_skill_index + 1) % count
	Sfx.play_boss_or_fallback("boss_charge", "sword_cast", -4.0, 0.85)
	if boss.get_parent() != null:
		V2VfxFactory.spawn_boss_charge_aura(boss.get_parent(), boss.global_position, 72.0, Color(0.42, 0.82, 1.0, 0.85), 0.50)
	match boss._boss_skill_index:
		0:
			boss._boss_active_skill = "sword_fan"
			boss._boss_state_timer = 0.50
			boss._boss_windup_total = 0.50
		1:
			boss._boss_active_skill = "sword_cage"
			boss._boss_state_timer = 0.75
			boss._boss_windup_total = 0.75
		_:
			boss._boss_active_skill = "sword_rain"
			boss._boss_state_timer = 0.85
			boss._boss_windup_total = 0.85


func execute() -> void:
	boss._boss_state = Enemy.BossState.ACTION
	boss._boss_dashing = false
	boss.velocity = Vector2.ZERO
	var vis = boss.visual_node
	if vis != null and vis.has_method("trigger_attack_lunge"):
		vis.trigger_attack_lunge(boss._boss_aim_dir)
	match boss._boss_active_skill:
		"sword_fan":
			boss._boss_state_timer = 0.30
			_cast_fan()
		"sword_cage":
			boss._boss_state_timer = 0.40
			_cast_cage()
		"sword_rain":
			boss._boss_state_timer = 0.55
			_cast_rain()
		_:
			boss._boss_state_timer = 0.24


func finish() -> void:
	boss._boss_dashing = false
	boss._boss_state = Enemy.BossState.RECOVER
	boss._boss_state_timer = 0.18 if boss._boss_enraged else 0.30


func _cast_fan() -> void:
	if boss.target == null or not is_instance_valid(boss.target):
		return
	var aim: Vector2 = (boss.target.global_position - boss.global_position).normalized()
	var base := aim.angle()
	var count := 9 if boss._boss_enraged else 7
	var spread := 1.25
	for i in range(count):
		var ang: float = base + (float(i) - float(count - 1) * 0.5) * (spread / float(maxi(1, count - 1)))
		boss.spawn_boss_projectile(boss.global_position, Vector2.from_angle(ang), SWORD_SPEED, SWORD_DMG, SWORD_RADIUS, SWORD_COLOR, 0.0, 0.0)
	boss.spawn_boss_line_from(boss.global_position, aim, 250.0, 34.0, 0.0)
	Sfx.play_boss_or_fallback("boss_roar", "sword_cast", -3.0, 0.95)
	if boss._boss_enraged and boss.target != null and is_instance_valid(boss.target):
		var side := -1.0 if randf() < 0.5 else 1.0
		var flank_dir := aim.rotated(side * 1.1)
		boss.emit_boss_ghost()
		boss.spawn_boss_line_from(boss.global_position - flank_dir * 150.0, flank_dir, 330.0, 42.0, 0.30)


func _cast_cage() -> void:
	if boss.target == null or not is_instance_valid(boss.target):
		return
	var center: Vector2 = boss.target.global_position
	for i in range(8):
		var ang := TAU * float(i) / 8.0 + 0.2
		var pos: Vector2 = center + Vector2(cos(ang), sin(ang)) * CAGE_RADIUS
		boss._spawn_boss_circle_at(pos, CAGE_PILLAR_RADIUS, 0.85, CAGE_DMG, SWORD_COLOR)
	boss._spawn_boss_circle_at(center, 34.0, 0.95, CAGE_DMG * 0.5, Color(0.86, 0.94, 1.0, 1.0))
	Sfx.play_boss_or_fallback("boss_slam", "thunder", -3.0, 0.95)


func _cast_rain() -> void:
	if boss.target == null or not is_instance_valid(boss.target):
		return
	var center: Vector2 = boss.target.global_position
	for i in range(10):
		var ang := randf() * TAU
		var dist := randf_range(60.0, 520.0)
		var pos := center + Vector2(cos(ang), sin(ang)) * dist
		boss._spawn_boss_circle_at(pos, RAIN_RADIUS, randf_range(0.75, 1.15), RAIN_DMG, SWORD_COLOR)
	boss.emit_boss_ghost()
	if boss.target != null and is_instance_valid(boss.target):
		var aim: Vector2 = (boss.target.global_position - boss.global_position).normalized()
		var flank := aim.rotated(PI)
		boss.spawn_boss_line_from(boss.global_position + flank * 140.0, aim, 420.0, 48.0, 0.55)
	Sfx.play_boss_or_fallback("boss_roar", "sword_cast", -2.0, 0.9)
