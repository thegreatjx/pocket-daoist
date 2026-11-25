extends Node2D
class_name Talisman

# 朱砂爆炎符 / 超武「业火红莲阵」：
# 符纸飞掷落地后在地面燃起一圈跳动的 2.5D 透视火焰火环（位于角色脚下 z_index=-3），不再悬浮。
const TEX_PAPER: Texture2D = preload("res://assets/sprites/fx_talisman_paper.png")

enum State { IDLE, FLY, FUSE, BURN }

@export var damage: float = 30.0
@export var radius: float = 64.0
@export var burn_damage: float = 10.0
@export var burn_duration: float = 3.2
@export var burn_tick: float = 0.45
@export var fuse: float = 0.18
@export var fly_time: float = 0.16
@export var spawn_min_distance: float = 70.0
@export var spawn_max_distance: float = 190.0

var is_evolved: bool = false
var crit_chance: float = 0.12
var crit_mult: float = 1.65

var _state: int = State.IDLE
var _origin: Vector2 = Vector2.ZERO
var _target: Vector2 = Vector2.ZERO
var _fly_t: float = 0.0
var _fuse_t: float = 0.0
var _burn_left: float = 0.0
var _burn_cd: float = 0.0
var _boom_t: float = 0.0
var _paper_angle: float = 0.0
var _flames: Array[Dictionary] = []
var _embers: Array[Dictionary] = []

func pool_acquire() -> void:
	_state = State.IDLE
	_burn_left = 0.0
	_burn_cd = 0.0
	_boom_t = 0.0
	_fly_t = 0.0
	_fuse_t = 0.0
	is_evolved = false
	_flames.clear()
	_embers.clear()
	visible = true
	modulate = Color.WHITE
	queue_redraw()

func setup(player_pos: Vector2, dmg: float, rad: float, burn_dmg: float, burn_time: float, evolved: bool = false, target_override: Vector2 = Vector2.INF, crit_c: float = 0.12, crit_m: float = 1.65) -> void:
	damage = dmg
	radius = rad
	burn_damage = burn_dmg
	burn_duration = burn_time
	is_evolved = evolved
	crit_chance = crit_c
	crit_mult = crit_m
	_state = State.FLY
	_origin = player_pos
	global_position = player_pos
	if target_override != Vector2.INF:
		_target = target_override
	else:
		var ang := randf() * TAU
		var dist := randf_range(spawn_min_distance, spawn_max_distance)
		_target = player_pos + Vector2(cos(ang), sin(ang)) * dist
	_fly_t = 0.0
	_paper_angle = randf() * TAU
	_build_flames()
	queue_redraw()

func _build_flames() -> void:
	_flames.clear()
	_embers.clear()
	var count := 18 if is_evolved else 14
	for i in range(count):
		var ang := (float(i) / float(count)) * TAU + randf_range(-0.07, 0.07)
		_flames.append({
			"ang": ang,
			"r_fac": randf_range(0.86, 1.00),
			"h": randf_range(26.0, 42.0) if is_evolved else randf_range(20.0, 34.0),
			"w": randf_range(13.0, 19.0) if is_evolved else randf_range(11.0, 16.0),
			"phase": randf_range(0.0, TAU),
			"spd": randf_range(7.5, 12.5),
			"lean": randf_range(-0.35, 0.35),
		})
	if is_evolved:
		for i in range(8):
			var ang := (float(i) / 14.0) * TAU + 0.18
			_flames.append({
				"ang": ang,
				"r_fac": randf_range(0.46, 0.60),
				"h": randf_range(22.0, 32.0),
				"w": randf_range(11.0, 16.0),
				"phase": randf_range(0.0, TAU),
				"spd": randf_range(8.5, 13.5),
				"lean": randf_range(-0.3, 0.3),
			})
	_flames.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return sin(float(a["ang"])) * float(a["r_fac"]) < sin(float(b["ang"])) * float(b["r_fac"])
	)
	for i in range(10 if is_evolved else 7):
		_embers.append({
			"ang": randf_range(0.0, TAU),
			"r_fac": randf_range(0.75, 1.08),
			"spd": randf_range(28.0, 56.0),
			"phase": randf_range(0.0, 1.0),
			"sz": randf_range(2.0, 3.6),
		})

func _process(delta: float) -> void:
	match _state:
		State.FLY:
			_fly_t += delta
			var t := clampf(_fly_t / maxf(0.01, fly_time), 0.0, 1.0)
			global_position = _origin.lerp(_target, 1.0 - pow(1.0 - t, 3.0))
			_paper_angle += delta * 14.0
			if t >= 1.0:
				_state = State.FUSE
				_fuse_t = 0.0
		State.FUSE:
			_fuse_t += delta
			_paper_angle += delta * 5.0
			if _fuse_t >= fuse:
				_explode()
		State.BURN:
			_boom_t += delta
			_burn_left -= delta
			_burn_cd -= delta
			if _burn_cd <= 0.0:
				_burn_cd = burn_tick
				_tick_burn()
			if _burn_left <= 0.0:
				_release()
	queue_redraw()

func _roll_dmg(base_d: float) -> float:
	if randf() < crit_chance:
		return base_d * crit_mult
	return base_d

func _explode() -> void:
	_state = State.BURN
	_burn_left = burn_duration
	_burn_cd = burn_tick
	_boom_t = 0.0
	Sfx.play_varied("sword_hit", -9.0)
	var nearby := CombatGrid.query(global_position, radius + 36.0)
	var candidates: Array = nearby if not nearby.is_empty() else get_tree().get_nodes_in_group("enemies")
	for e in candidates:
		if not is_instance_valid(e) or e.is_dead:
			continue
		if global_position.distance_to(e.global_position) <= radius:
			e.take_damage(_roll_dmg(damage))
			if is_evolved and e.is_dead:
				_chain_detonate(e.global_position)
	for jar in get_tree().get_nodes_in_group("breakables"):
		if is_instance_valid(jar) and jar.has_method("take_damage"):
			if global_position.distance_to(jar.global_position) <= radius:
				jar.take_damage(damage)

func _tick_burn() -> void:
	var nearby := CombatGrid.query(global_position, radius + 36.0)
	var candidates: Array = nearby if not nearby.is_empty() else get_tree().get_nodes_in_group("enemies")
	for e in candidates:
		if not is_instance_valid(e) or e.is_dead:
			continue
		if global_position.distance_to(e.global_position) <= radius:
			e.take_damage(_roll_dmg(burn_damage))
			if is_evolved and e.is_dead:
				_chain_detonate(e.global_position)

func _chain_detonate(at_pos: Vector2) -> void:
	var blast_r := radius * 0.72
	var nearby := CombatGrid.query(at_pos, blast_r + 32.0)
	var candidates: Array = nearby if not nearby.is_empty() else get_tree().get_nodes_in_group("enemies")
	for other in candidates:
		if is_instance_valid(other) and not other.is_dead:
			if at_pos.distance_to(other.global_position) <= blast_r:
				other.take_damage(damage * 0.65)

func _release() -> void:
	_state = State.IDLE
	ObjectPools.release(self)

func _draw() -> void:
	match _state:
		State.FLY, State.FUSE:
			var sc := 1.0 + (0.22 * sin(_fuse_t * 28.0) if _state == State.FUSE else 0.0)
			draw_set_transform(Vector2.ZERO, _paper_angle, Vector2(sc, sc))
			if TEX_PAPER != null:
				draw_texture_rect(TEX_PAPER, Rect2(-20.0, -20.0, 40.0, 40.0), false)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		State.BURN:
			_draw_ground_fire_ring()

func _draw_ground_fire_ring() -> void:
	var fade := clampf(_burn_left / 0.55, 0.0, 1.0)
	var bloom := clampf(_boom_t / 0.14, 0.25, 1.0)
	var r := radius * bloom
	var persp_y := 0.72

	# 1. 贴地暖光火环（柔和半透赤橙光带，透出青绿草地不发暗发脏）
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, persp_y))
	draw_circle(Vector2.ZERO, r * 0.92, Color(1.0, 0.48, 0.16, fade * 0.11))
	draw_arc(Vector2.ZERO, r * 0.95, 0.0, TAU, 48, Color(0.96, 0.26, 0.10, fade * 0.30), 22.0 if is_evolved else 17.0, true)
	draw_arc(Vector2.ZERO, r * 0.93, 0.0, TAU, 48, Color(1.0, 0.48, 0.14, fade * 0.58), 11.0 if is_evolved else 8.5, true)
	draw_arc(Vector2.ZERO, r * 0.91, 0.0, TAU, 48, Color(1.0, 0.84, 0.34, fade * 0.72), 3.2, true)
	if is_evolved:
		draw_arc(Vector2.ZERO, r * 0.53, 0.0, TAU, 36, Color(1.0, 0.42, 0.14, fade * 0.45), 9.0, true)
		draw_arc(Vector2.ZERO, r * 0.53, 0.0, TAU, 36, Color(1.0, 0.86, 0.38, fade * 0.65), 2.5, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 2. 沿地环连绵跃动的柔弧水滴火舌（按前后深度排序）
	for fl in _flames:
		var ang: float = fl["ang"]
		var rf: float = fl["r_fac"]
		var base_pos := Vector2(cos(ang) * r * rf, sin(ang) * r * rf * persp_y)
		var ph: float = fl["phase"]
		var spd: float = fl["spd"]
		var wave := sin(_boom_t * spd + ph)
		var sway := (cos(_boom_t * (spd * 0.62) + ph) * 5.5) + float(fl["lean"]) * 8.0
		var fh: float = float(fl["h"]) * bloom * (0.84 + 0.24 * wave)
		var fw: float = float(fl["w"]) * bloom

		# 贴地火根柔晕
		draw_circle(base_pos + Vector2(0.0, -3.0), fw * 0.78, Color(0.98, 0.34, 0.10, fade * 0.28))

		# 外层朱砂流焰（圆润水滴 + S形飘尾）
		_draw_flame_wisp(base_pos, fw, fh, sway, Color(0.95, 0.25, 0.10, fade * 0.78))
		# 内层暖金焰芯
		_draw_flame_wisp(base_pos + Vector2(0.0, -2.0), fw * 0.36, fh * 0.44, sway * 0.45, Color(1.0, 0.94, 0.58, fade * 0.92))

	# 3. 随热浪升腾的金色火星
	for em in _embers:
		var cycle := fmod(_boom_t * 1.05 + float(em["phase"]), 1.0)
		var ang: float = em["ang"]
		var rf: float = em["r_fac"]
		var start_p := Vector2(cos(ang) * r * rf, sin(ang) * r * rf * persp_y)
		var e_pos := start_p + Vector2(sin(_boom_t * 5.5 + ang) * 6.0, -cycle * float(em["spd"]))
		var e_a := fade * (1.0 - cycle) * 0.92
		var e_r: float = float(em["sz"]) * (1.0 - cycle * 0.35)
		draw_circle(e_pos, e_r * 1.8, Color(1.0, 0.52, 0.14, e_a * 0.35))
		draw_circle(e_pos, e_r, Color(1.0, 0.92, 0.46, e_a))

func _draw_flame_wisp(base_pos: Vector2, fw: float, fh: float, sway: float, col: Color) -> void:
	var pts := PackedVector2Array([
		base_pos + Vector2(0.0, fw * 0.26),
		base_pos + Vector2(-fw * 0.52, fw * 0.14),
		base_pos + Vector2(-fw * 0.66, -fh * 0.22),
		base_pos + Vector2(-fw * 0.42 + sway * 0.35, -fh * 0.58),
		base_pos + Vector2(-fw * 0.12 + sway * 0.75, -fh * 0.84),
		base_pos + Vector2(sway, -fh),
		base_pos + Vector2(fw * 0.18 + sway * 0.65, -fh * 0.80),
		base_pos + Vector2(fw * 0.46 + sway * 0.28, -fh * 0.52),
		base_pos + Vector2(fw * 0.66, -fh * 0.20),
		base_pos + Vector2(fw * 0.52, fw * 0.14),
	])
	draw_colored_polygon(pts, col)
