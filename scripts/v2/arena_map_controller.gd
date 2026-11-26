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
	var road_hw := float(realm_cfg.get("road_half_width", 105.0))
	var min_spacing := float(realm_cfg.get("obstacle_min_spacing", 260.0))
	var target_count := clampi(int(realm_cfg.get("obstacle_count", 22)), 18, 26)
	var prop_scales: Array = realm_cfg.get("prop_scales", [])

	var prop_textures: Array[Texture2D] = []
	var prop_base_scales: Array[float] = []
	var raw_props: Array = realm_cfg.get("props", realm_cfg.get("prop_files", []))
	for i in range(raw_props.size()):
		var tex := MapRealmCatalog.load_realm_texture(realm_cfg, "prop", i)
		if tex != null:
			prop_textures.append(tex)
			prop_base_scales.append(float(prop_scales[i]) if i < prop_scales.size() else 0.36)

	var rng := RandomNumberGenerator.new()
	rng.seed = int(realm_cfg.get("seed", 20261126))

	var placed_positions: Array[Vector2] = []
	var inner_rect := arena_rect.grow(-280.0)
	var attempts := 0
	while placed_positions.size() < target_count and attempts < target_count * 40:
		attempts += 1
		var pos := Vector2(
			rng.randf_range(inner_rect.position.x, inner_rect.end.x),
			rng.randf_range(inner_rect.position.y, inner_rect.end.y)
		)
		if pos.distance_to(center) < dojo_r + 70.0:
			continue
		if absf(pos.x - center.x) < road_hw + 95.0 or absf(pos.y - center.y) < road_hw + 95.0:
			continue
		var valid := true
		for h in hazard_sites:
			if pos.distance_to(h["pos"] as Vector2) < 230.0:
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
		if not prop_textures.is_empty():
			var idx := rng.randi_range(0, prop_textures.size() - 1)
			var sc := prop_base_scales[idx] * rng.randf_range(0.90, 1.12)
			var obs := MapPropObstacle.new()
			obs.position = pos
			add_child(obs)
			obs.setup(prop_textures[idx], sc, rng.randf() < 0.5)
			_realm_nodes.append(obs)
			cover_pillars_data.append({
				"id": cover_pillars_data.size(),
				"tag": "realm_prop_%d" % cover_pillars_data.size(),
				"pos": pos,
				"radius": obs.collider_radius,
				"is_core_pillar": false,
			})

	for h in hazard_sites:
		if String(h.get("type", "")) != "sword_stele":
			continue
		var stele_tex := MapRealmCatalog.load_realm_texture(realm_cfg, "hazard", 0, "sword_stele")
		if stele_tex != null:
			var spos: Vector2 = h["pos"]
			var obs := MapPropObstacle.new()
			obs.position = spos
			add_child(obs)
			obs.setup(stele_tex, 0.36, false, 34.0)
			_realm_nodes.append(obs)
			cover_pillars_data.append({
				"id": cover_pillars_data.size(),
				"tag": "sword_stele",
				"pos": spos,
				"radius": obs.collider_radius,
				"is_core_pillar": false,
			})

	_spawn_border_cliffs(realm_cfg, arena_rect, rng)
	_spawn_ambient_particles(String(realm_cfg.get("particles", "")))
	return cover_pillars_data.duplicate(true)

func _spawn_border_cliffs(realm_cfg: Dictionary, arena_rect: Rect2, rng: RandomNumberGenerator) -> void:
	var border_tex := MapRealmCatalog.load_realm_texture(realm_cfg, "border")
	if border_tex == null:
		return
	var step := 230.0
	var bw := float(border_tex.get_width())
	var bh := float(border_tex.get_height())
	var base_sc := 290.0 / maxf(1.0, bw)

	var edges := [
		{"a": arena_rect.position, "b": Vector2(arena_rect.end.x, arena_rect.position.y), "out": Vector2(0.0, -34.0)},
		{"a": Vector2(arena_rect.position.x, arena_rect.end.y), "b": arena_rect.end, "out": Vector2(0.0, 56.0)},
		{"a": arena_rect.position, "b": Vector2(arena_rect.position.x, arena_rect.end.y), "out": Vector2(-42.0, 0.0)},
		{"a": Vector2(arena_rect.end.x, arena_rect.position.y), "b": arena_rect.end, "out": Vector2(42.0, 0.0)},
	]
	for edge_idx in range(edges.size()):
		var a: Vector2 = edges[edge_idx]["a"]
		var b: Vector2 = edges[edge_idx]["b"]
		var out_off: Vector2 = edges[edge_idx]["out"]
		var dist := a.distance_to(b)
		var count := maxi(2, int(round(dist / step)))
		for i in range(count + 1):
			var t := float(i) / float(count)
			var pos := a.lerp(b, t) + out_off + Vector2(rng.randf_range(-16.0, 16.0), rng.randf_range(-12.0, 12.0))
			var sp := Sprite2D.new()
			sp.texture = border_tex
			sp.flip_h = ((i + edge_idx) % 2) == 1
			var sc := base_sc * rng.randf_range(0.92, 1.14)
			sp.scale = Vector2(sc, sc)
			sp.offset = Vector2(0.0, -bh * 0.25)
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

	var p := GPUParticles2D.new()
	p.amount = 28 if kind == "petals_fireflies" else 34
	p.lifetime = 4.2
	p.preprocess = 2.0

	var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	for y in range(12):
		for x in range(12):
			var d := Vector2(float(x) - 5.5, float(y) - 5.5).length() / 5.5
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a * a))
	p.texture = ImageTexture.create_from_image(img)

	var proc := ParticleProcessMaterial.new()
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	proc.emission_box_extents = Vector3(760.0, 460.0, 0.0)
	match kind:
		"petals_fireflies":
			proc.direction = Vector3(0.4, 0.8, 0.0)
			proc.gravity = Vector3(6.0, 12.0, 0.0)
			proc.initial_velocity_min = 12.0
			proc.initial_velocity_max = 28.0
			proc.scale_min = 0.45
			proc.scale_max = 0.95
			proc.color = Color(0.98, 0.84, 0.88, 0.65)
		"embers":
			proc.direction = Vector3(0.2, -1.0, 0.0)
			proc.gravity = Vector3(4.0, -18.0, 0.0)
			proc.initial_velocity_min = 24.0
			proc.initial_velocity_max = 52.0
			proc.scale_min = 0.35
			proc.scale_max = 0.85
			proc.color = Color(1.0, 0.56, 0.22, 0.72)
		_:
			proc.direction = Vector3(-0.35, 1.0, 0.0)
			proc.gravity = Vector3(-10.0, 22.0, 0.0)
			proc.initial_velocity_min = 18.0
			proc.initial_velocity_max = 40.0
			proc.scale_min = 0.40
			proc.scale_max = 0.90
			proc.color = Color(0.84, 0.95, 1.0, 0.70)
	p.process_material = proc
	_ambient_layer.add_child(p)

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
