extends Node2D

var _enemy: Node2D = null
var _t: float = 0.0
var _block_scale: float = 1.0
var _shattering: bool = false
var _shatter_heavy: bool = false
var _shatter_t: float = 0.0
var _shatter_dur: float = 0.42
var _shards: Array[Dictionary] = []

func setup(enemy: Node) -> void:
	_enemy = enemy as Node2D
	_t = 0.0
	_shattering = false
	_shatter_heavy = false
	_shatter_t = 0.0
	_shards.clear()
	z_index = 4
	material = null
	position = Vector2(0.0, 12.0)

	_block_scale = _infer_enemy_scale(_enemy)
	queue_redraw()

func _infer_enemy_scale(e: Node2D) -> float:
	if e == null or not is_instance_valid(e):
		return 1.0
	var e_type: int = int(e.get("enemy_type")) if "enemy_type" in e else 0
	var is_mini: bool = bool(e.get("is_mini_boss")) if "is_mini_boss" in e else false
	if e_type == 2:
		return 2.25
	if e_type == 1:
		return 1.85 if is_mini else 1.45
	return 1.0

func shatter_and_detach(heavy: bool = false) -> void:
	if _shattering:
		return
	_shattering = true
	_shatter_heavy = heavy
	_shatter_t = 0.0
	_shatter_dur = 0.50 if heavy else 0.40

	var world_pos: Vector2 = global_position
	var world_parent: Node = null
	if _enemy != null and is_instance_valid(_enemy):
		world_parent = _enemy.get_parent()
	_enemy = null

	top_level = true
	global_position = world_pos
	if world_parent != null and is_instance_valid(world_parent) and world_parent != get_parent():
		reparent.call_deferred(world_parent, true)

	_spawn_shards(14 if heavy else 8)
	queue_redraw()

func _spawn_shards(count: int) -> void:
	_shards.clear()
	var sc: float = _block_scale * (1.22 if _shatter_heavy else 1.0)
	for i in range(count):
		var ang: float = randf_range(-PI * 0.92, -PI * 0.08) + randf_range(-0.35, 0.35)
		var spd: float = randf_range(120.0, 270.0) * (1.35 if _shatter_heavy else 1.0)
		var sz: float = randf_range(5.5, 11.5) * sc
		_shards.append({
			"pos": Vector2(randf_range(-16.0, 16.0) * _block_scale, randf_range(-42.0, -6.0) * _block_scale),
			"vel": Vector2(cos(ang) * spd, sin(ang) * spd - randf_range(35.0, 95.0)),
			"rot": randf_range(0.0, TAU),
			"vrot": randf_range(-11.0, 11.0),
			"sz": sz,
			"bright": (i % 2 == 0),
		})

func _process(delta: float) -> void:
	if _shattering:
		_shatter_t += delta
		for sh in _shards:
			var vel: Vector2 = sh["vel"]
			vel.y += 620.0 * delta
			sh["vel"] = vel
			sh["pos"] = (sh["pos"] as Vector2) + vel * delta
			sh["rot"] = float(sh["rot"]) + float(sh["vrot"]) * delta
		if _shatter_t >= _shatter_dur:
			queue_free()
			return
		queue_redraw()
		return

	_t += delta
	if _enemy == null or not is_instance_valid(_enemy) or bool(_enemy.get("is_dead")) or float(_enemy.get("_freeze_timer")) <= 0.0:
		shatter_and_detach(false)
		return
	queue_redraw()

func _draw() -> void:
	if _shattering:
		_draw_shatter_burst()
		return
	_draw_ice_block()

func _draw_ice_block() -> void:
	var rem: float = float(_enemy.get("_freeze_timer")) if (_enemy != null and is_instance_valid(_enemy)) else 0.0
	var pop_u: float = clampf(_t / 0.11, 0.0, 1.0)
	var sy: float = lerpf(0.18, 1.08, pop_u) if pop_u < 0.78 else lerpf(1.08, 1.0, (pop_u - 0.78) / 0.22)
	var sx: float = lerpf(1.16, 1.0, pop_u)

	var cracking: bool = rem > 0.0 and rem <= 0.38
	var shake_x: float = sin(_t * 68.0) * 2.6 * _block_scale if cracking else 0.0

	draw_set_transform(Vector2(shake_x, 4.0 * _block_scale), 0.0, Vector2(sx * _block_scale, 0.38 * _block_scale))
	draw_circle(Vector2.ZERO, 28.0, Color(0.55, 0.90, 1.0, 0.34))
	draw_arc(Vector2.ZERO, 27.0, 0.0, TAU, 24, Color(0.88, 0.98, 1.0, 0.62), 1.8)
	draw_set_transform(Vector2(shake_x, 0.0), 0.0, Vector2(sx * _block_scale, sy * _block_scale))

	var body := PackedVector2Array([
		Vector2(-15.0, -56.0),
		Vector2(6.0, -62.0),
		Vector2(21.0, -46.0),
		Vector2(26.0, -14.0),
		Vector2(20.0, 5.0),
		Vector2(-19.0, 6.0),
		Vector2(-26.0, -16.0),
		Vector2(-22.0, -44.0),
	])
	draw_colored_polygon(body, Color(0.36, 0.82, 0.98, 0.50))

	var dark_facet := PackedVector2Array([
		Vector2(5.0, -61.0),
		Vector2(21.0, -46.0),
		Vector2(26.0, -14.0),
		Vector2(20.0, 5.0),
		Vector2(4.0, 5.0),
		Vector2(10.0, -24.0),
	])
	draw_colored_polygon(dark_facet, Color(0.14, 0.50, 0.78, 0.42))

	var light_facet := PackedVector2Array([
		Vector2(-15.0, -56.0),
		Vector2(5.0, -61.0),
		Vector2(2.0, -34.0),
		Vector2(-18.0, -28.0),
		Vector2(-22.0, -44.0),
	])
	draw_colored_polygon(light_facet, Color(0.84, 0.97, 1.0, 0.42))

	var sheen := PackedVector2Array([
		Vector2(-13.0, -46.0),
		Vector2(-4.0, -52.0),
		Vector2(14.0, -20.0),
		Vector2(6.0, -14.0),
	])
	draw_colored_polygon(sheen, Color(0.96, 1.0, 1.0, 0.48))

	var spike_l := PackedVector2Array([Vector2(-25.0, 4.0), Vector2(-31.0, -11.0), Vector2(-17.0, 5.0)])
	var spike_r := PackedVector2Array([Vector2(16.0, 5.0), Vector2(31.0, -8.0), Vector2(24.0, 5.0)])
	draw_colored_polygon(spike_l, Color(0.66, 0.93, 1.0, 0.76))
	draw_colored_polygon(spike_r, Color(0.42, 0.84, 0.98, 0.76))

	var rim := PackedVector2Array()
	rim.append_array(body)
	rim.append(body[0])
	draw_polyline(rim, Color(0.86, 0.98, 1.0, 0.92), 2.0, true)
	draw_line(Vector2(5.0, -61.0), Vector2(10.0, -24.0), Color(0.88, 0.98, 1.0, 0.60), 1.4, true)
	draw_line(Vector2(10.0, -24.0), Vector2(4.0, 5.0), Color(0.76, 0.95, 1.0, 0.55), 1.3, true)

	if cracking:
		var c_alpha: float = clampf(1.0 - rem / 0.38, 0.35, 1.0)
		var crack_col := Color(0.98, 1.0, 1.0, c_alpha)
		draw_polyline(PackedVector2Array([
			Vector2(-12.0, -48.0), Vector2(-2.0, -34.0), Vector2(-7.0, -22.0), Vector2(5.0, -6.0)
		]), crack_col, 2.2, true)
		draw_polyline(PackedVector2Array([
			Vector2(16.0, -38.0), Vector2(6.0, -26.0), Vector2(13.0, -12.0)
		]), crack_col, 1.9, true)
		draw_polyline(PackedVector2Array([
			Vector2(-2.0, -34.0), Vector2(11.0, -32.0)
		]), crack_col, 1.6, true)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_shatter_burst() -> void:
	var u: float = clampf(_shatter_t / maxf(0.01, _shatter_dur), 0.0, 1.0)
	var alpha: float = 1.0 - u * u

	if u < 0.55:
		var ring_u: float = u / 0.55
		var ring_r: float = lerpf(16.0, 56.0 if _shatter_heavy else 38.0, ring_u) * _block_scale
		draw_arc(Vector2(0.0, -20.0 * _block_scale), ring_r, 0.0, TAU, 24, Color(0.82, 0.97, 1.0, (1.0 - ring_u) * 0.72), 3.0 if _shatter_heavy else 2.0)

	for sh in _shards:
		var p: Vector2 = sh["pos"]
		var rot: float = float(sh["rot"])
		var s: float = float(sh["sz"]) * lerpf(1.0, 0.45, u)
		var bright: bool = bool(sh["bright"])
		draw_set_transform(p, rot, Vector2.ONE)
		var poly := PackedVector2Array([
			Vector2(0.0, -s),
			Vector2(s * 0.65, -s * 0.1),
			Vector2(s * 0.25, s * 0.85),
			Vector2(-s * 0.55, s * 0.35),
		])
		var fill_c := Color(0.88, 0.98, 1.0, alpha * 0.92) if bright else Color(0.42, 0.86, 1.0, alpha * 0.86)
		draw_colored_polygon(poly, fill_c)
		draw_polyline(PackedVector2Array([poly[0], poly[1], poly[2], poly[3], poly[0]]), Color(1.0, 1.0, 1.0, alpha * 0.95), 1.2)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
