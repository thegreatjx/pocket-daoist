class_name BossCorpseKingKit
extends BossKit

const SLAM_RADIUS := 128.0
const SLAM_DMG := 30.0
const SLAM_WINDUP := 0.30
const JUMP_GAP := 0.40
const JUMP_DIST := 120.0

var _jumps_left := 0
var _jump_timer := 0.0


func skill_cooldown() -> float:
	return 1.0 if boss._boss_enraged else 1.45


func on_phase2() -> void:
	boss.knockback_resistance = 1.0


func update_chase(delta: float, dir: Vector2, dist: float) -> void:
	boss._boss_dashing = false
	boss.velocity = dir * boss.speed * (1.0 - boss._slow_ratio)
	var vis = boss.visual_node
	if vis != null and vis.has_method("set_boss_state"):
		vis.set_boss_state(0.0, boss._boss_enraged)
	boss._boss_skill_cd -= delta
	if boss._boss_skill_cd <= 0.0 and dist <= 520.0:
		boss._begin_boss_skill(dir)


func begin(dir: Vector2) -> void:
	boss._boss_aim_dir = dir
	boss._boss_skill_index = 0
	boss._boss_active_skill = "triple_slam"
	boss._boss_state_timer = 0.55
	boss._boss_windup_total = 0.55
	_jumps_left = 3
	_jump_timer = 0.0
	Sfx.play_boss_or_fallback("boss_charge", "thunder", -4.0, 0.85)
	if boss.get_parent() != null:
		V2VfxFactory.spawn_boss_charge_aura(boss.get_parent(), boss.global_position, 78.0, Color(0.42, 0.16, 0.62, 0.85), 0.55)


func execute() -> void:
	boss._boss_state = Enemy.BossState.ACTION
	boss._boss_state_timer = 1.40
	boss._boss_dashing = false
	boss.velocity = Vector2.ZERO
	_jump_timer = 0.0
	_do_jump()


func update_action(delta: float) -> void:
	_jump_timer -= delta
	if _jump_timer <= 0.0 and _jumps_left > 0:
		_do_jump()


func _do_jump() -> void:
	if _jumps_left <= 0:
		return
	_jumps_left -= 1
	_jump_timer = JUMP_GAP
	var dir: Vector2 = boss._boss_aim_dir
	if boss.target != null and is_instance_valid(boss.target):
		dir = (boss.target.global_position - boss.global_position).normalized()
	var land: Vector2 = boss.global_position + dir * JUMP_DIST
	boss.boss_teleport(land)
	boss._spawn_boss_circle_at(land, SLAM_RADIUS, SLAM_WINDUP, SLAM_DMG, Color(0.48, 0.18, 0.72, 1.0))
	if boss.get_parent() != null:
		V2VfxFactory.spawn_boss_shockwave(boss.get_parent(), land, SLAM_RADIUS * 0.95, Color(0.52, 0.20, 0.78, 0.95), Color(0.92, 0.82, 0.42, 1.0), 0.36)
		V2VfxFactory.spawn_slam_explosion(boss.get_parent(), land, SLAM_RADIUS * 0.55, Color(0.36, 0.14, 0.52, 0.9), Color(0.86, 0.76, 0.40, 0.9))
	var vis = boss.visual_node
	if vis != null and vis.has_method("trigger_land_impact"):
		vis.trigger_land_impact(1.8)
	if boss.target != null and is_instance_valid(boss.target) and boss.target.has_method("shake_camera"):
		boss.target.shake_camera(8.5)
	Sfx.play_boss_or_fallback("boss_slam", "thunder", -2.0)


func finish() -> void:
	boss._boss_dashing = false
	boss._boss_state = Enemy.BossState.RECOVER
	boss._boss_state_timer = 0.22 if boss._boss_enraged else 0.34
