extends Node2D
class_name SwordSlash

const TEX_SLASH: Texture2D = preload("res://assets/sprites/fx_sword_slash.png")

var direction: Vector2 = Vector2.RIGHT
var damage: float = 42.0
var radius: float = 115.0
var arc_half_angle: float = 1.18
var knockback: float = 150.0
var crit_chance: float = 0.12
var crit_mult: float = 1.65
var is_evolved: bool = false
var owner_player: Node = null

var _timer: float = 0.0
var _duration: float = 0.24
var _damaged: bool = false
var _petals: Array[Dictionary] = []

func pool_acquire() -> void:
	_timer = 0.0
	_duration = 0.24
	_damaged = false
	is_evolved = false
	owner_player = null
	_petals.clear()
	visible = true
	modulate = Color.WHITE

func setup(dir: Vector2, dmg: float, rad: float, kb: float, crit_c: float, crit_m: float, evolved: bool = false, player: Node = null) -> void:
	direction = dir.normalized() if dir.length_squared() > 0.001 else Vector2.RIGHT
	damage = dmg
	radius = rad
	knockback = kb
	crit_chance = crit_c
	crit_mult = crit_m
	is_evolved = evolved
	owner_player = player
	arc_half_angle = PI if evolved else 1.18
	_duration = 0.30 if evolved else 0.22
	rotation = direction.angle()
	_petals.clear()
	var petal_cnt := 14 if evolved else 6
	for i in range(petal_cnt):
		var ang := randf_range(-arc_half_angle * 0.85, arc_half_angle * 0.85)
		_petals.append({
			"ang": ang,
			"r0": randf_range(radius * 0.35, radius * 0.72),
			"r1": randf_range(radius * 0.85, radius * 1.25),
			"sz": randf_range(3.5, 7.0),
			"gold": randf() < (0.55 if evolved else 0.30),
		})
	queue_redraw()

func _physics_process(delta: float) -> void:
	if not _damaged:
		_damaged = true
		_deal_slash_damage()
	_timer += delta
	queue_redraw()
	if _timer >= _duration:
		ObjectPools.release(self)

func _deal_slash_damage() -> void:
	Sfx.play_varied("sword_cast", -9.0)
	var healed := false
	var nearby := CombatGrid.query(global_position, radius + 48.0)
	var candidates: Array = nearby if not nearby.is_empty() else get_tree().get_nodes_in_group("enemies")
	for e in candidates:
		if not is_instance_valid(e) or e.is_dead:
			continue
		var delta_v: Vector2 = e.global_position - global_position
		var dist := delta_v.length()
		if dist > radius + 18.0:
			continue
		if not is_evolved and dist > 26.0:
			var ang_diff := absf(direction.angle_to(delta_v))
			if ang_diff > arc_half_angle:
				continue
		var is_crit := randf() < crit_chance
		var final_dmg := damage * (crit_mult if is_crit else 1.0)
		e.take_damage(final_dmg)
		Sfx.play_varied("sword_hit", -12.0)
		if e.has_method("apply_knockback"):
			var push := delta_v.normalized() if dist > 1.0 else direction
			e.apply_knockback(push * knockback)
		if is_evolved and is_crit and not healed and owner_player != null and is_instance_valid(owner_player):
			healed = true
			if owner_player.has_method("heal"):
				owner_player.heal(2.5)

	# 剑气也能斩碎沿途青瓷灵罐
	for jar in get_tree().get_nodes_in_group("breakables"):
		if is_instance_valid(jar) and jar.has_method("take_damage"):
			if global_position.distance_to(jar.global_position) <= radius + 16.0:
				jar.take_damage(damage)

func _draw() -> void:
	var t := clampf(_timer / maxf(0.01, _duration), 0.0, 1.0)
	var ease_out := 1.0 - pow(1.0 - t, 3.0)
	var alpha := (1.0 - t * t) * 0.96
	var sc := lerpf(0.70, 1.15, ease_out)
	var draw_size := radius * 2.05 * sc

	if TEX_SLASH != null:
		if is_evolved:
			# 超武「青莲剑歌」：前后双青金剑浪 360° 盛放
			var col1 := Color(0.75, 1.0, 0.92, alpha)
			var col2 := Color(1.0, 0.90, 0.56, alpha * 0.85)
			draw_texture_rect(TEX_SLASH, Rect2(-draw_size * 0.34, -draw_size * 0.5, draw_size, draw_size), false, col1)
			draw_set_transform(Vector2.ZERO, PI, Vector2.ONE)
			draw_texture_rect(TEX_SLASH, Rect2(-draw_size * 0.34, -draw_size * 0.5, draw_size, draw_size), false, col2)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			draw_texture_rect(TEX_SLASH, Rect2(-draw_size * 0.30, -draw_size * 0.5, draw_size, draw_size), false, Color(1.0, 1.0, 1.0, alpha))

	# 飘散青莲花瓣与金墨星点
	for p in _petals:
		var rr := lerpf(float(p["r0"]), float(p["r1"]), ease_out)
		var ang := float(p["ang"])
		var pos := Vector2(cos(ang), sin(ang)) * rr
		var c := Color(1.0, 0.86, 0.36, alpha) if bool(p["gold"]) else Color(0.45, 0.98, 0.86, alpha)
		draw_circle(pos, float(p["sz"]) * (1.0 - t * 0.4), c)
