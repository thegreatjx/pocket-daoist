class_name BossCauldronKit
extends BossKit

const KEEP_DIST := 250.0
const METEOR_DMG := 24.0
const METEOR_RADIUS := 74.0
const METEOR_WINDUP := 0.82
const SUMMON_SPECIES := 8


func skill_cooldown() -> float:
	return 1.05 if boss._boss_enraged else 1.55


func update_chase(delta: float, dir: Vector2, dist: float) -> void:
	boss._boss_dashing = false
	boss._boss_strafe_phase += delta * 0.9
	var tangent := Vector2(-dir.y, dir.x) * (1.0 if sin(boss._boss_strafe_phase) >= 0.0 else -1.0)
	var move := tangent
	if dist < KEEP_DIST - 40.0:
		move = (-dir * 1.2 + tangent * 0.7).normalized()
	elif dist > KEEP_DIST + 90.0:
		move = (dir + tangent * 0.5).normalized()
	boss.velocity = move * boss.speed * (1.0 - boss._slow_ratio)
	var vis = boss.visual_node
	if vis != null and vis.has_method("set_boss_state"):
		vis.set_boss_state(0.0, boss._boss_enraged)
	boss._boss_skill_cd -= delta
	if boss._boss_skill_cd <= 0.0 and dist <= 720.0:
		boss._begin_boss_skill(dir)


func begin(dir: Vector2) -> void:
	boss._boss_aim_dir = dir
	boss._boss_skill_index = (boss._boss_skill_index + 1) % 2
	Sfx.play_boss_or_fallback("boss_charge", "dash", -4.0, 0.85)
	if boss.get_parent() != null:
		V2VfxFactory.spawn_boss_charge_aura(boss.get_parent(), boss.global_position, 70.0, Color(0.70, 0.30, 0.96, 0.85), 0.55)
	if boss._boss_skill_index == 0:
		boss._boss_active_skill = "meteor"
		boss._boss_state_timer = 0.70
		boss._boss_windup_total = 0.70
	else:
		boss._boss_active_skill = "summon_danling"
		boss._boss_state_timer = 0.52
		boss._boss_windup_total = 0.52


func execute() -> void:
	boss._boss_state = Enemy.BossState.ACTION
	boss._boss_dashing = false
	boss.velocity = Vector2.ZERO
	var vis = boss.visual_node
	if vis != null and vis.has_method("trigger_attack_lunge"):
		vis.trigger_attack_lunge(boss._boss_aim_dir)
	match boss._boss_active_skill:
		"meteor":
			boss._boss_state_timer = 0.34
			_cast_meteors()
		"summon_danling":
			boss._boss_state_timer = 0.42
			boss.summon_boss_minions(SUMMON_SPECIES, 3 if boss._boss_enraged else 2)
			Sfx.play_boss_or_fallback("boss_roar", "thunder", -3.0, 1.05)
		_:
			boss._boss_state_timer = 0.24


func _cast_meteors() -> void:
	if boss.target == null or not is_instance_valid(boss.target):
		return
	var count := 5 if boss._boss_enraged else 3
	var origin: Vector2 = boss.target.global_position
	boss._spawn_boss_circle_at(origin, METEOR_RADIUS, METEOR_WINDUP, METEOR_DMG, Color(0.72, 0.26, 0.98, 1.0))
	for i in range(1, count):
		var ang := (float(i - 1) / float(maxi(1, count - 1))) * TAU + randf_range(-0.25, 0.25)
		var pos := origin + Vector2(cos(ang), sin(ang)) * randf_range(90.0, 165.0)
		boss._spawn_boss_circle_at(pos, METEOR_RADIUS, METEOR_WINDUP + float(i) * 0.14, METEOR_DMG, Color(0.72, 0.26, 0.98, 1.0))
	Sfx.play_boss_or_fallback("boss_slam", "fire", -3.0, 0.9)
	if boss.visual_node != null and boss.visual_node.has_method("trigger_attack_lunge"):
		boss.visual_node.trigger_attack_lunge(boss._boss_aim_dir)
