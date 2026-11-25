class_name EnemySteeringDirector
extends RefCounted

const GOLDEN_ANGLE: float = 2.399963229728653

var cell_size: float = 72.0
var separation_weight: float = 1.35
var pillars: Array[Dictionary] = []
var _grid: Dictionary = {}
var _active_cells: Array[Vector2i] = []

func configure(global_limits: Dictionary) -> void:
	cell_size = maxf(8.0, float(global_limits.get("spatial_hash_cell_size", 72.0)))
	separation_weight = float(global_limits.get("separation_weight", 1.35))

func set_pillars(list: Array) -> void:
	pillars.clear()
	for p in list:
		if p is Dictionary and p.has("pos") and p.has("radius"):
			pillars.append({"pos": p["pos"] as Vector2, "radius": float(p["radius"])})

func rebuild_grid(enemy_states: Array) -> void:
	for c in _active_cells:
		(_grid[c] as Array).clear()
	_active_cells.clear()

	for st in enemy_states:
		var pos: Vector2 = st["pos"]
		var cell := Vector2i(int(floor(pos.x / cell_size)), int(floor(pos.y / cell_size)))
		if not _grid.has(cell):
			_grid[cell] = []
		var bucket: Array = _grid[cell]
		if bucket.is_empty():
			_active_cells.append(cell)
		bucket.append(st)

func compute_velocity(st: Dictionary, player_pos: Vector2, arch: Dictionary) -> Vector2:
	var pos: Vector2 = st["pos"]
	var to_player: Vector2 = player_pos - pos
	var dist: float = to_player.length()
	var dir: Vector2 = to_player / maxf(0.001, dist)
	var speed: float = float(arch.get("move_speed", 100.0))
	var behavior: String = String(arch.get("ai_behavior", "swarm_chaser"))

	var desired: Vector2 = dir * speed
	match behavior:
		"kiter_shooter":
			var d_min: float = float(arch.get("preferred_dist_min", 210.0))
			var d_max: float = float(arch.get("preferred_dist_max", 320.0))
			if dist < d_min:
				desired = -dir * speed * 0.9
			elif dist <= d_max:
				var strafe_sign: float = float(st.get("strafe_sign", 1.0))
				desired = Vector2(-dir.y, dir.x) * speed * 0.65 * strafe_sign
		"charger_telegraph":
			var mode: String = String(st.get("charge_state", "chase"))
			if mode == "telegraph":
				return Vector2.ZERO
			elif mode == "charge":
				var c_dir: Vector2 = st.get("charge_dir", dir) as Vector2
				return c_dir * float(arch.get("charge_speed", 310.0))
		"shield_bulwark":
			desired = dir * speed * 0.92
		"splitter_bomber":
			desired = dir * speed * 1.12

	var sep: Vector2 = _compute_separation(st)
	var slide: Vector2 = compute_pillar_slide(pos, float(st.get("radius", 20.0)), dir, speed, pillars, int(st["id"]))
	var final_v: Vector2 = desired + sep * speed * separation_weight + slide
	return final_v.limit_length(speed * 1.25)

static func compute_pillar_slide(
	pos: Vector2,
	radius: float,
	desired_dir: Vector2,
	speed: float,
	pillar_list: Array,
	entity_id: int = 0
) -> Vector2:
	var slide := Vector2.ZERO
	if pillar_list.is_empty():
		return slide
	for p in pillar_list:
		var p_pos: Vector2 = p["pos"]
		var p_r: float = float(p["radius"])
		var to_e: Vector2 = pos - p_pos
		var d: float = to_e.length()
		var trigger_r: float = p_r + radius + 16.0
		if d < trigger_r:
			var n: Vector2 = to_e / d if d > 0.001 else Vector2.from_angle(float(entity_id & 1023) * GOLDEN_ANGLE)
			var t1 := Vector2(-n.y, n.x)
			var t2 := Vector2(n.y, -n.x)
			var dot1: float = t1.dot(desired_dir)
			var dot2: float = t2.dot(desired_dir)
			var chosen: Vector2
			if dot1 > dot2 + 0.001:
				chosen = t1
			elif dot2 > dot1 + 0.001:
				chosen = t2
			else:
				chosen = t1 if (entity_id & 1) == 0 else t2
			slide += chosen * speed * 0.8
			if d < p_r + radius:
				slide += n * speed * 0.6
	return slide

static func check_pillar_collision(pos: Vector2, radius: float, pillar_list: Array, margin: float = 0.0) -> bool:
	for p in pillar_list:
		var p_pos: Vector2 = p["pos"]
		var r_sum: float = float(p["radius"]) + radius + margin
		if pos.distance_squared_to(p_pos) <= r_sum * r_sum:
			return true
	return false

func _compute_separation(st: Dictionary) -> Vector2:
	var pos: Vector2 = st["pos"]
	var r_self: float = float(st.get("radius", 20.0))
	var self_id: int = int(st["id"])
	var cell := Vector2i(int(floor(pos.x / cell_size)), int(floor(pos.y / cell_size)))
	var push := Vector2.ZERO
	var neighbors: int = 0
	for ox in range(-1, 2):
		for oy in range(-1, 2):
			var key := Vector2i(cell.x + ox, cell.y + oy)
			if not _grid.has(key):
				continue
			var bucket: Array = _grid[key]
			if bucket.is_empty():
				continue
			for other in bucket:
				var other_id: int = int(other["id"])
				if other_id == self_id:
					continue
				var delta_v: Vector2 = pos - (other["pos"] as Vector2)
				var min_d: float = r_self + float(other.get("radius", 20.0))
				var d2: float = delta_v.length_squared()
				if d2 < min_d * min_d:
					if d2 > 0.001:
						var d: float = sqrt(d2)
						push += (delta_v / d) * ((min_d - d) / min_d)
					else:
						var lo: int = mini(self_id, other_id)
						var hi: int = maxi(self_id, other_id)
						var angle: float = float((lo * 31 + hi * 17) & 1023) * GOLDEN_ANGLE
						var sign_dir: float = 1.0 if self_id < other_id else -1.0
						push += Vector2(cos(angle), sin(angle)) * sign_dir
					neighbors += 1
					if neighbors >= 8:
						return push
	return push
