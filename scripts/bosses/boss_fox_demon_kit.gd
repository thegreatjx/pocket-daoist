class_name BossFoxDemonKit
extends BossKit

const KEEP_DIST := 235.0
const PETAL_SPEED := 215.0
const PETAL_DMG := 16.0
const PETAL_RADIUS := 15.0
const PETAL_SLOW := 0.35
const PETAL_SLOW_SEC := 2.0
const BLINK_ANGLE := 2.1
const BLINK_DIST := 175.0
const HURT_BLINK_CD := 4.0

var _blink_cd := 0.0
var _second_fan := 0.0


func skill_cooldown() -> float:
	return 0.95 if boss._boss_enraged else 1.35


func update_chase(delta: float, dir: Vector2, dist: float) -> void:
	boss._boss_dashing = false
	_blink_cd = maxf(0.0, _blink_cd - delta)
	boss._boss_strafe_phase += delta * 1.6
	var tangent := Vector2(-dir.y, dir.x) * sin(boss._boss_strafe_phase)
	var move := tangent * 0.85
	if dist < KEEP_DIST - 30.0:
		move = (-dir + tangent * 0.5).normalized()
	elif dist > KEEP_DIST + 80.0:
		move = (dir + tangent * 0.3).normalized()
	boss.velocity = move * boss.speed * (1.0 - boss._slow_ratio)
	var vis = boss.visual_node
	if vis != null and vis.has_method("set_boss_state"):
		vis.set_boss_state(0.0, boss._boss_enraged)
	boss._boss_skill_cd -= delta
	if boss._boss_skill_cd <= 0.0 and dist <= 620.0:
		boss._begin_boss_skill(dir)


func on_hurt() -> void:
	if _blink_cd > 0.0 or boss.is_dead:
		return
	if boss.target == null or not is_instance_valid(boss.target):
		return
	_blink_cd = HURT_BLINK_CD
	_blink_to_side()
	if boss.get_parent() != null:
		V2VfxFactory.spawn_boss_shockwave(boss.get_parent(), boss.global_position, 46.0, Color(0.94, 0.52, 0.82, 0.75), Color(1.0, 0.86, 0.94, 0.9), 0.24)


func begin(dir: Vector2) -> void:
	boss._boss_aim_dir = dir
	boss._boss_skill_index = (boss._boss_skill_index + 1) % 2
	boss._boss_active_skill = "petal_fan"
	boss._boss_windup_total = 0.34
	boss._boss_state_timer = 0.34
	_second_fan = 0.0
	Sfx.play_boss_or_fallback("boss_charge", "water_ripple_splash", -3.0, 0.95)
	if boss.get_parent() != null:
		V2VfxFactory.spawn_boss_charge_aura(boss.get_parent(), boss.global_position, 58.0, Color(0.96, 0.56, 0.86, 0.85), 0.34)


func execute() -> void:
	boss._boss_state = Enemy.BossState.ACTION
	boss._boss_dashing = false
	boss.velocity = Vector2.ZERO
	boss._boss_state_timer = 0.55 if boss._boss_enraged else 0.34
	_blink_to_side()
	_fire_fan()
	if boss._boss_enraged:
		_second_fan = 0.16


func update_action(delta: float) -> void:
	var before := _second_fan
	_second_fan -= delta
	if before > 0.0 and _second_fan <= 0.0:
		_fire_fan()


func finish() -> void:
	boss._boss_dashing = false
	boss._boss_state = Enemy.BossState.RECOVER
	boss._boss_state_timer = 0.18 if boss._boss_enraged else 0.28


func _blink_to_side() -> void:
	if boss.target == null or not is_instance_valid(boss.target):
		return
	var to_boss: Vector2 = boss.global_position - boss.target.global_position
	var base: float = to_boss.angle() if to_boss.length_squared() > 1.0 else boss._boss_aim_dir.angle() + PI
	var side := 1.0 if randf() < 0.5 else -1.0
	var dest: Vector2 = boss.target.global_position + Vector2.from_angle(base + side * BLINK_ANGLE * 0.5) * BLINK_DIST
	if boss.get_parent() != null:
		V2VfxFactory.spawn_slam_explosion(boss.get_parent(), boss.global_position, 48.0, Color(0.96, 0.58, 0.88, 0.85), Color(1.0, 0.86, 0.94, 0.9))
	boss.boss_teleport(dest)
	if boss.get_parent() != null:
		V2VfxFactory.spawn_slam_explosion(boss.get_parent(), boss.global_position, 52.0, Color(0.96, 0.58, 0.88, 0.85), Color(1.0, 0.90, 0.96, 0.95))


func _fire_fan() -> void:
	if boss.target == null or not is_instance_valid(boss.target):
		return
	var aim: Vector2 = (boss.target.global_position - boss.global_position).normalized()
	var base := aim.angle()
	var count := 7 if boss._boss_enraged else 5
	var spread := 1.0
	for i in range(count):
		var ang: float = base + (float(i) - float(count - 1) * 0.5) * (spread / float(maxi(1, count - 1)))
		boss.spawn_boss_projectile(boss.global_position, Vector2.from_angle(ang), PETAL_SPEED, PETAL_DMG, PETAL_RADIUS, Color(0.96, 0.52, 0.86, 1.0), PETAL_SLOW, PETAL_SLOW_SEC)
	Sfx.play_boss_or_fallback("boss_roar", "water_ripple_splash", -3.0, 1.1)
	if boss.visual_node != null and boss.visual_node.has_method("trigger_attack_lunge"):
		boss.visual_node.trigger_attack_lunge(aim)
