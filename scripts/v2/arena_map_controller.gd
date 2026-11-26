class_name ArenaMapController
extends Node2D

var arena_half_size := Vector2(1400.0, 1000.0)
var cover_pillars_data: Array[Dictionary] = []

var _floor_sprite: Sprite2D
var _center_sprite: Sprite2D
var _ysort_root: Node2D
var _walls_body: StaticBody2D
var _realm_nodes: Array[Node] = []
var _ambient_layer: Node2D = null

func _ready() -> void:
	add_to_group("arena_map")
	y_sort_enabled = true

func _process(_delta: float) -> void:
	if _ambient_layer == null or not is_instance_valid(_ambient_layer):
		return
	var tree := get_tree()
	if tree == null:
		return
	var vp := get_viewport()
	if vp != null:
		var cam := vp.get_camera_2d()
		if cam != null:
			_ambient_layer.global_position = cam.get_screen_center_position()
			return
	var p := tree.get_first_node_in_group("player") as Node2D
	if p != null and is_instance_valid(p):
		_ambient_layer.global_position = p.global_position

func clear_realm() -> void:
	for n in _realm_nodes:
		if n != null and is_instance_valid(n):
			n.queue_free()
	_realm_nodes.clear()
	if _ambient_layer != null and is_instance_valid(_ambient_layer):
		_ambient_layer.queue_free()
	_ambient_layer = null
	cover_pillars_data.clear()

func build_tutorial_props(center: Vector2, pillars: Array, landmarks: Array, pine_tex: Texture2D, lm_textures: Dictionary) -> void:
	clear_realm()
	for p in pillars:
		if not bool(p.get("is_core_pillar", false)):
			continue
		if pine_tex != null:
			var obs := MapPropObstacle.new()
			obs.position = p["pos"] as Vector2
			add_child(obs)
			obs.setup_from_spec(pine_tex, {
				"foot_y_norm": 0.92,
				"shape": "circle",
				"coll_rx": 0.14,
				"shadow_rx": 0.24,
				"shadow_ry": 0.10,
				"occlude": true,
			}, 250.0, false, 0.0)
			_realm_nodes.append(obs)
	for lm in landmarks:
		var lm_id := String(lm.get("id", ""))
		var tex: Texture2D = lm_textures.get(lm_id, null) as Texture2D
		if tex == null:
			continue
		var obs := MapPropObstacle.new()
		obs.position = lm["pos"] as Vector2
		add_child(obs)
		var is_solid := (lm_id == "sword_mound" or lm_id == "peach_brook")
		var spec := {
			"foot_y_norm": 0.90 if lm_id == "sword_mound" else 0.86,
			"shape": "capsule",
			"coll_rx": 0.30,
			"coll_ry": 0.15,
			"shadow_rx": 0.36,
			"shadow_ry": 0.16,
			"occlude": lm_id != "spirit_spring",
		}
		var h_px := 180.0 if lm_id == "sword_mound" else (140.0 if lm_id == "peach_brook" else 165.0)
		obs.setup_from_spec(tex, spec, h_px, false, -1.0 if is_solid else 0.0)
		_realm_nodes.append(obs)
		if is_solid:
			cover_pillars_data.append({
				"id": cover_pillars_data.size(),
				"tag": lm_id,
				"pos": obs.position,
				"radius": obs.collider_radius,
				"is_core_pillar": false,
			})

func build_realm(
	realm_cfg: Dictionary,
	arena_rect: Rect2,
	center: Vector2,
	hazard_sites: Array[Dictionary]
) -> Array[Dictionary]:
	clear_realm()
	if String(realm_cfg.get("mode", "classic")) != "realm":
		return []

	arena_half_size = arena_rect.size * 0.5
	var dojo_r := float(realm_cfg.get("center_dojo_radius", 560.0))
	var road_hw := float(realm_cfg.get("road_half_width", 85.0))
	var min_spacing := float(realm_cfg.get("obstacle_min_spacing", 280.0))
	var target_count := clampi(int(realm_cfg.get("obstacle_count", 20)), 18, 26)
	var prop_pool: Array = realm_cfg.get("prop_pool", [])
	var landmark_spec: Dictionary = realm_cfg.get("landmark_prop_spec", {})

	var rng := RandomNumberGenerator.new()
	rng.seed = int(realm_cfg.get("seed", 20261126))

	var forbidden: Array[Dictionary] = []
	var anchor_idx := 0
	for h in hazard_sites:
		var htype := String(h.get("type", ""))
		var hpos: Vector2 = h["pos"]
		if htype == "prop_anchor" or htype == "sword_stele":
			var tex := h.get("tex", null) as Texture2D
			if tex == null:
				tex = MapRealmCatalog.load_tex_safe(String(h.get("tex_path", "")))
			if tex != null:
				var obs := MapPropObstacle.new()
				obs.position = hpos
				add_child(obs)
				obs.setup_from_spec(tex, landmark_spec, float(h.get("height", 180.0)), false, -1.0)
				_realm_nodes.append(obs)
				var tag := "sword_stele" if htype == "sword_stele" else "landmark_anchor_%d" % anchor_idx
				anchor_idx += 1
				cover_pillars_data.append({
					"id": cover_pillars_data.size(),
					"tag": tag,
					"pos": hpos,
					"radius": obs.collider_radius,
					"is_core_pillar": false,
				})
			forbidden.append({"pos": hpos, "r": 240.0 if htype == "prop_anchor" else float(h.get("radius", 135.0)) + 140.0})
		else:
			forbidden.append({"pos": hpos, "r": float(h.get("radius", 155.0)) + 140.0})

	var placed_positions: Array[Vector2] = []
	var layout_props: Array = realm_cfg.get("layout_props", [])
	for lp in layout_props:
		if placed_positions.size() >= target_count or prop_pool.is_empty():
			break
		if not (lp is Dictionary):
			continue
		var rel: Vector2 = (lp as Dictionary).get("pos", Vector2.ZERO)
		var pos := center + rel
		var p_idx := clampi(int((lp as Dictionary).get("pool_idx", 0)), 0, prop_pool.size() - 1)
		var spec: Dictionary = prop_pool[p_idx] as Dictionary
		var tex := MapRealmCatalog.load_tex_safe(String(spec.get("tex", "")))
		if tex != null:
			var h_px := float((lp as Dictionary).get("height", spec.get("height", 190.0)))
			var flip_h := bool((lp as Dictionary).get("flip_h", false))
			var obs := MapPropObstacle.new()
			obs.position = pos
			add_child(obs)
			obs.setup_from_spec(tex, spec, h_px, flip_h)
			_realm_nodes.append(obs)
			placed_positions.append(pos)
			cover_pillars_data.append({
				"id": cover_pillars_data.size(),
				"tag": "realm_prop_%d" % placed_positions.size(),
				"pos": pos,
				"radius": obs.collider_radius,
				"is_core_pillar": false,
			})

	var inner_rect := arena_rect.grow(-300.0)
	var attempts := 0
	while placed_positions.size() < target_count and attempts < target_count * 40:
		attempts += 1
		var pos := Vector2(
			rng.randf_range(inner_rect.position.x, inner_rect.end.x),
			rng.randf_range(inner_rect.position.y, inner_rect.end.y)
		)
		if pos.distance_to(center) < dojo_r + 80.0:
			continue
		if absf(pos.x - center.x) < road_hw + 90.0 or absf(pos.y - center.y) < road_hw + 90.0:
			continue
		var valid := true
		for fz in forbidden:
			if pos.distance_to(fz["pos"] as Vector2) < float(fz["r"]):
				valid = false
				break
		if not valid:
			continue
		for prev in placed_positions:
			if pos.distance_to(prev) < min_spacing:
				valid = false
				break
		if not valid:
			continue

		placed_positions.append(pos)
		if not prop_pool.is_empty():
			var spec := _pick_weighted_prop(prop_pool, rng)
			var tex := MapRealmCatalog.load_tex_safe(String(spec.get("tex", "")))
			if tex != null:
				var h_px := float(spec.get("height", 190.0)) * rng.randf_range(0.90, 1.12)
				var obs := MapPropObstacle.new()
				obs.position = pos
				add_child(obs)
				obs.setup_from_spec(tex, spec, h_px, rng.randf() < 0.5)
				_realm_nodes.append(obs)
				cover_pillars_data.append({
					"id": cover_pillars_data.size(),
					"tag": "realm_prop_%d" % placed_positions.size(),
					"pos": pos,
					"radius": obs.collider_radius,
					"is_core_pillar": false,
				})

	_spawn_border_cliffs(realm_cfg, arena_rect, rng)
	_spawn_ambient_particles(String(realm_cfg.get("particles", "")))
	return cover_pillars_data.duplicate(true)

func _pick_weighted_prop(pool: Array, rng: RandomNumberGenerator) -> Dictionary:
	var total := 0.0
	for s in pool:
		total += float((s as Dictionary).get("weight", 1.0))
	var r := rng.randf() * maxf(0.01, total)
	for s in pool:
		r -= float((s as Dictionary).get("weight", 1.0))
		if r <= 0.0:
			return s as Dictionary
	return pool[0] as Dictionary

func _spawn_border_cliffs(realm_cfg: Dictionary, arena_rect: Rect2, rng: RandomNumberGenerator) -> void:
	var border_tex := MapRealmCatalog.load_realm_texture(realm_cfg, "border")
	if border_tex == null:
		return
	var step := float(realm_cfg.get("border_step", 225.0))
	var bw := float(border_tex.get_width())
	var bh := float(border_tex.get_height())
	var base_sc := (512.0 * float(realm_cfg.get("border_scale", 0.72))) / maxf(1.0, bw)
	var foot_y_norm := clampf(float(realm_cfg.get("border_foot_y", 0.85)), 0.5, 0.99)
	var foot_off_y := (0.5 - foot_y_norm) * bh
	var inset := float(realm_cfg.get("border_wall_inset", 50.0))

	# Solid physical colliders aligned 1:1 with the visible mountain foothills
	var cliff_body := StaticBody2D.new()
	cliff_body.name = "BorderCliffColliders"
	cliff_body.collision_layer = 1
	cliff_body.collision_mask = 0
	var c := arena_rect.get_center()
	var w := arena_rect.size.x
	var h := arena_rect.size.y
	var wall_thickness := 140.0
	var wall_specs := [
		{"pos": Vector2(c.x, arena_rect.position.y - wall_thickness * 0.5 + inset), "size": Vector2(w + 300.0, wall_thickness)},
		{"pos": Vector2(c.x, arena_rect.end.y + wall_thickness * 0.5 - inset * 0.5), "size": Vector2(w + 300.0, wall_thickness)},
		{"pos": Vector2(arena_rect.position.x - wall_thickness * 0.5 + inset, c.y), "size": Vector2(wall_thickness, h + 300.0)},
		{"pos": Vector2(arena_rect.end.x + wall_thickness * 0.5 - inset, c.y), "size": Vector2(wall_thickness, h + 300.0)},
	]
	for ws in wall_specs:
		var col := CollisionShape2D.new()
		var rect_shape := RectangleShape2D.new()
		rect_shape.size = ws["size"]
		col.shape = rect_shape
		col.position = ws["pos"]
		cliff_body.add_child(col)
	add_child(cliff_body)
	_realm_nodes.append(cliff_body)

	var edges := [
		{"a": arena_rect.position, "b": Vector2(arena_rect.end.x, arena_rect.position.y), "out": Vector2(0.0, inset * 0.85)},
		{"a": Vector2(arena_rect.position.x, arena_rect.end.y), "b": arena_rect.end, "out": Vector2(0.0, 26.0)},
		{"a": arena_rect.position, "b": Vector2(arena_rect.position.x, arena_rect.end.y), "out": Vector2(-18.0, 0.0)},
		{"a": arena_rect.end.x * Vector2.RIGHT + arena_rect.position.y * Vector2.DOWN, "b": arena_rect.end, "out": Vector2(18.0, 0.0)},
	]
	for edge_idx in range(edges.size()):
		var a: Vector2 = edges[edge_idx]["a"]
		var b: Vector2 = edges[edge_idx]["b"]
		var out_off: Vector2 = edges[edge_idx]["out"]
		var dist := a.distance_to(b)
		var count := maxi(2, int(round(dist / step)))
		for i in range(count + 1):
			var t := float(i) / float(count)
			var pos := a.lerp(b, t) + out_off + Vector2(rng.randf_range(-10.0, 10.0), rng.randf_range(-6.0, 6.0))
			var sp := Sprite2D.new()
			sp.texture = border_tex
			sp.flip_h = ((i + edge_idx) % 2) == 1
			var sc := base_sc * rng.randf_range(0.95, 1.08)
			sp.scale = Vector2(sc, sc)
			sp.offset = Vector2(0.0, foot_off_y)
			sp.position = pos
			add_child(sp)
			_realm_nodes.append(sp)

func _spawn_ambient_particles(kind: String) -> void:
	if kind.is_empty():
		return
	_ambient_layer = Node2D.new()
	_ambient_layer.name = "RealmAmbientParticles"
	_ambient_layer.z_as_relative = false
	_ambient_layer.z_index = 80
	add_child(_ambient_layer)

	var dot_tex := _make_soft_dot_tex()
	match kind:
		"forest", "petals_fireflies":
			_ambient_layer.add_child(_make_ambient_emitter(dot_tex, 24, 6.0, Vector3(-18.0, 26.0, 0.0), Color("#F6B8C8", 0.72), 0.40, 0.75))
			_ambient_layer.add_child(_make_ambient_emitter(dot_tex, 16, 4.5, Vector3(0.0, -10.0, 0.0), Color("#B8F2C6", 0.55), 0.25, 0.45))
		"volcano", "embers":
			_ambient_layer.add_child(_make_ambient_emitter(dot_tex, 30, 4.2, Vector3(12.0, -42.0, 0.0), Color("#FF9C4A", 0.65), 0.22, 0.50))
		_:
			_ambient_layer.add_child(_make_ambient_emitter(dot_tex, 36, 5.5, Vector3(-28.0, 46.0, 0.0), Color("#D8EEFA", 0.68), 0.22, 0.45))
			_ambient_layer.add_child(_make_ambient_emitter(dot_tex, 6, 9.0, Vector3(-20.0, 4.0, 0.0), Color("#CFE6F2", 0.09), 5.0, 8.5))

func _make_ambient_emitter(tex: Texture2D, amount: int, life: float, gravity_vec: Vector3, col: Color, s_min: float, s_max: float) -> GPUParticles2D:
	var p := GPUParticles2D.new()
	p.amount = amount
	p.lifetime = life
	p.preprocess = minf(2.0, life)
	p.texture = tex
	var proc := ParticleProcessMaterial.new()
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	proc.emission_box_extents = Vector3(780.0, 460.0, 0.0)
	proc.direction = gravity_vec.normalized() if gravity_vec.length_squared() > 0.01 else Vector3(0.0, 1.0, 0.0)
	proc.gravity = gravity_vec
	proc.initial_velocity_min = 4.0
	proc.initial_velocity_max = 18.0
	proc.scale_min = s_min
	proc.scale_max = s_max
	proc.color = col
	p.process_material = proc
	return p

func _make_soft_dot_tex() -> Texture2D:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in range(16):
		for x in range(16):
			var d := Vector2(float(x) - 7.5, float(y) - 7.5).length() / 7.5
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a * a))
	return ImageTexture.create_from_image(img)

func load_chapter(chapter_index: int = 0, json_path: String = "res://data/v2/map_arena_v2.json") -> bool:
	if not FileAccess.file_exists(json_path):
		push_error("ArenaMapController: Missing %s" % json_path)
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	if not (parsed is Dictionary):
		return false
	var cfg: Dictionary = parsed
	var sz: Dictionary = cfg.get("arena_size", {"width": 2800, "height": 2000})
	arena_half_size = Vector2(float(sz["width"]) * 0.5, float(sz["height"]) * 0.5)
	var chapters: Array = cfg.get("chapters", [])
	if chapters.is_empty():
		return false
	var ch: Dictionary = chapters[clampi(chapter_index, 0, chapters.size() - 1)]
	_rebuild_scene(ch)
	return true

func _rebuild_scene(ch: Dictionary) -> void:
	for c in get_children():
		c.queue_free()
	_realm_nodes.clear()
	_ambient_layer = null
	cover_pillars_data.clear()

	_floor_sprite = Sprite2D.new()
	_floor_sprite.z_index = -20
	_floor_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_floor_sprite.region_enabled = true
	_floor_sprite.region_rect = Rect2(-arena_half_size, arena_half_size * 2.0)
	var floor_path: String = String(ch.get("floor_tile", ""))
	if ResourceLoader.exists(floor_path):
		_floor_sprite.texture = load(floor_path)
	_floor_sprite.modulate = Color(String(ch.get("floor_tint", "#FFFFFF")))
	add_child(_floor_sprite)

	var center_cfg: Dictionary = ch.get("center_anchor", {})
	_center_sprite = Sprite2D.new()
	_center_sprite.z_index = -10
	var c_path: String = String(center_cfg.get("texture", ""))
	if ResourceLoader.exists(c_path):
		_center_sprite.texture = load(c_path)
	var c_pos: Array = center_cfg.get("pos", [0, 0])
	_center_sprite.position = Vector2(float(c_pos[0]), float(c_pos[1]))
	var c_sc: float = float(center_cfg.get("scale", 1.0))
	_center_sprite.scale = Vector2(c_sc, c_sc)
	add_child(_center_sprite)

	_ysort_root = Node2D.new()
	_ysort_root.y_sort_enabled = true
	add_child(_ysort_root)

	for p in ch.get("cover_pillars", []):
		_spawn_cover_tree(p)
	for poi in ch.get("landmarks", []):
		_spawn_landmark(poi)

	_build_walls()

func _spawn_cover_tree(p: Dictionary) -> void:
	var pos_arr: Array = p.get("pos", [0, 0])
	var pos := Vector2(float(pos_arr[0]), float(pos_arr[1]))
	var r: float = float(p.get("trunk_radius", 20.0))
	cover_pillars_data.append({"pos": pos, "radius": r})

	var body := StaticBody2D.new()
	body.position = pos
	body.collision_layer = 1 | 4
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = r
	col.shape = shape
	body.add_child(col)

	var sp := Sprite2D.new()
	var t_path: String = String(p.get("texture", ""))
	if ResourceLoader.exists(t_path):
		sp.texture = load(t_path)
	sp.offset = Vector2(0, -85)
	sp.scale = Vector2(0.75, 0.75)
	body.add_child(sp)

	var area := Area2D.new()
	area.collision_mask = 1 | 8
	var a_col := CollisionShape2D.new()
	var a_shape := CircleShape2D.new()
	a_shape.radius = 68.0
	a_col.shape = a_shape
	a_col.position = Vector2(0, -78)
	area.add_child(a_col)
	var fade_a: float = float(p.get("canopy_fade_alpha", 0.42))
	area.body_entered.connect(func(b: Node2D) -> void:
		if b.is_in_group("player"):
			create_tween().tween_property(sp, "modulate:a", fade_a, 0.14)
	)
	area.body_exited.connect(func(b: Node2D) -> void:
		if b.is_in_group("player"):
			create_tween().tween_property(sp, "modulate:a", 1.0, 0.14)
	)
	body.add_child(area)
	_ysort_root.add_child(body)

func _spawn_landmark(poi: Dictionary) -> void:
	var pos_arr: Array = poi.get("pos", [0, 0])
	var node := Node2D.new()
	node.name = String(poi.get("id", "poi"))
	node.position = Vector2(float(pos_arr[0]), float(pos_arr[1]))
	var sp := Sprite2D.new()
	var t_path: String = String(poi.get("texture", ""))
	if ResourceLoader.exists(t_path):
		sp.texture = load(t_path)
	sp.scale = Vector2(0.72, 0.72)
	node.add_child(sp)
	_ysort_root.add_child(node)

func _build_walls() -> void:
	_walls_body = StaticBody2D.new()
	_walls_body.collision_layer = 1 | 4
	var hw: float = arena_half_size.x
	var hh: float = arena_half_size.y
	var segs: Array = [
		[Vector2(-hw, -hh), Vector2(hw, -hh)],
		[Vector2(hw, -hh), Vector2(hw, hh)],
		[Vector2(hw, hh), Vector2(-hw, hh)],
		[Vector2(-hw, hh), Vector2(-hw, -hh)]
	]
	for s in segs:
		var col := CollisionShape2D.new()
		var seg := SegmentShape2D.new()
		seg.a = s[0]
		seg.b = s[1]
		col.shape = seg
		_walls_body.add_child(col)
	add_child(_walls_body)

func compute_pillar_tangent_avoidance(enemy_pos: Vector2, enemy_radius: float, move_speed: float) -> Vector2:
	var push := Vector2.ZERO
	for p in cover_pillars_data:
		var c: Vector2 = p["pos"]
		var min_d: float = float(p["radius"]) + enemy_radius + 18.0
		var d_vec: Vector2 = enemy_pos - c
		var d2: float = d_vec.length_squared()
		if d2 > 0.001 and d2 < min_d * min_d:
			var d: float = sqrt(d2)
			var n: Vector2 = d_vec / d
			var tangent := Vector2(-n.y, n.x)
			push += (n * 0.6 + tangent * 0.8) * move_speed * ((min_d - d) / min_d)
	return push
