extends Node2D
class_name Thunder

var damage: float = 65.0
var radius: float = 72.0
var chain_count: int = 0
var is_evolved: bool = false
var timer: float = 0.38
var duration: float = 0.38
var damaged: bool = false
var shake_amount: float = 1.6
var is_chain_bolt: bool = false
var _bolt_pts: PackedVector2Array = PackedVector2Array()

func pool_acquire() -> void:
	timer = duration
	damaged = false
	chain_count = 0
	is_evolved = false
	is_chain_bolt = false
	visible = true
	_build_bolt()
	queue_redraw()

func _build_bolt() -> void:
	var pts := PackedVector2Array()
	var steps := 9
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var y := lerpf(-580.0, 0.0, t)
		var x := 0.0 if (i == 0 or i == steps) else randf_range(-24.0, 24.0)
		pts.append(Vector2(x, y))
	_bolt_pts = pts

func _physics_process(delta: float) -> void:
	if not damaged:
		damaged = true
		_deal_aoe_damage()
	timer -= delta
	queue_redraw()
	if timer <= 0:
		ObjectPools.release(self)

func _deal_aoe_damage() -> void:
	Sfx.play("thunder", -13.5, randf_range(0.92, 1.04))
	var hit_any = false
	var nearby := CombatGrid.query(global_position, radius + 40.0)
	var candidates: Array = nearby if not nearby.is_empty() else get_tree().get_nodes_in_group("enemies")
	for e in candidates:
		if is_instance_valid(e) and not e.is_dead:
			if global_position.distance_to(e.global_position) <= radius:
				e.take_damage(damage)
				if e.has_method("apply_knockback"):
					var push = (e.global_position - global_position).normalized()
					e.apply_knockback(push * (140.0 if is_evolved else 90.0))
				hit_any = true
	for jar in get_tree().get_nodes_in_group("breakables"):
		if is_instance_valid(jar) and jar.has_method("take_damage"):
			if global_position.distance_to(jar.global_position) <= radius:
				jar.take_damage(damage)
	if hit_any and not is_chain_bolt:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0 and players[0].has_method("shake_camera"):
			players[0].shake_camera(shake_amount)
	if chain_count > 0:
		_chain_strike()

func _chain_strike() -> void:
	var remaining := chain_count
	var origin := global_position
	var visited := {}
	for i in range(remaining):
		var best: Node2D = null
		var best_d := radius + 240.0
		var chain_near := CombatGrid.query(origin, best_d)
		var chain_src: Array = chain_near if not chain_near.is_empty() else get_tree().get_nodes_in_group("enemies")
		for e in chain_src:
			if not is_instance_valid(e) or e.is_dead:
				continue
			if visited.has(e.get_instance_id()):
				continue
			var d := origin.distance_to(e.global_position)
			if d < best_d:
				best_d = d
				best = e
		if best == null:
			return
		visited[best.get_instance_id()] = true
		origin = best.global_position
		var th = ObjectPools.acquire("res://scenes/thunder.tscn", get_parent(), 48)
		if th == null:
			return
		th.damage = damage * 0.72
		th.radius = radius * 0.82
		th.chain_count = 0
		th.is_evolved = is_evolved
		th.is_chain_bolt = true
		th.global_position = origin

func _draw() -> void:
	var a := clampf(timer / duration, 0.0, 1.0)
	var expand := 1.18 - a * 0.35
	var outer_col := Color(0.76, 0.42, 1.0, a * 0.34) if is_evolved else Color(0.28, 0.86, 0.96, a * 0.28)
	var ring_col := Color(1.0, 0.86, 0.38, a * 0.92)
	draw_circle(Vector2.ZERO, radius * expand, outer_col)
	draw_arc(Vector2.ZERO, radius * expand, 0.0, TAU, 32, ring_col, 3.5)
	draw_circle(Vector2.ZERO, radius * 0.42, Color(0.98, 1.0, 0.94, a * 0.72))
	if _bolt_pts.size() >= 2:
		var halo_col := Color(0.74, 0.42, 1.0, a * 0.62) if is_evolved else Color(0.32, 0.84, 1.0, a * 0.56)
		draw_polyline(_bolt_pts, halo_col, 16.0 if is_evolved else 13.0)
		draw_polyline(_bolt_pts, Color(1.0, 0.96, 0.76, a * 0.98), 5.5)
