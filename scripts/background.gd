extends Node2D

enum MapMode { CLASSIC, REALM }

const DEFAULT_TILE: Texture2D = preload("res://assets/terrain/tile_forest.png")
const TILE_SIZE := 256.0
const CH1_TILE_PATH := "res://assets/v2/map_ch1/tile_grass_512.png"
const CH1_TILE: Texture2D = preload(CH1_TILE_PATH)
const CH1_TILE_SIZE := 512.0
const CH1_FLOOR_TINT := Color(0.72, 0.82, 0.64, 1.0)
const CH1_CENTER_RING: Texture2D = preload("res://assets/v2/map_ch1/prop_center_stone_ring.png")
const CH1_PINE: Texture2D = preload("res://assets/v2/map_ch1/prop_pine_tree.png")
const CH1_CENTER_RING_SCALE := 1.15
const CH1_PINE_SCALE := 0.84
const CH1_LANDMARK_TEXTURES := {
	"spirit_spring": preload("res://assets/v2/map_ch1/poi_mountain_spring.png"),
	"sword_mound": preload("res://assets/v2/map_ch1/poi_demon_stele.png"),
	"peach_brook": preload("res://assets/v2/map_ch1/poi_mossy_well.png"),
	"star_altar": preload("res://assets/v2/map_ch1/poi_incense_brazier.png"),
}

const ARENA_HALF_WIDTH := 1400.0
const ARENA_HALF_HEIGHT := 1000.0
const SPAWN_CENTER := Vector2(640.0, 360.0)
const ARENA_RECT := Rect2(
	SPAWN_CENTER.x - ARENA_HALF_WIDTH,
	SPAWN_CENTER.y - ARENA_HALF_HEIGHT,
	ARENA_HALF_WIDTH * 2.0,
	ARENA_HALF_HEIGHT * 2.0
)

const PILLAR_RADIUS := 26.0
const CORE_PILLAR_OFFSETS := [
	Vector2(-460.0, -290.0),
	Vector2(460.0, -290.0),
	Vector2(-460.0, 290.0),
	Vector2(460.0, 290.0),
	Vector2(0.0, -620.0),
	Vector2(0.0, 620.0),
	Vector2(-1020.0, 0.0),
	Vector2(1020.0, 0.0),
]

const PROP_PATHS := {
	"pine": "res://assets/props/pine.png",
	"lantern": "res://assets/props/lantern.png",
	"rune_stone": "res://assets/props/rune_stone.png",
	"fern": "res://assets/props/fern.png",
	"stele": "res://assets/props/stele.png",
	"moss": "res://assets/props/moss.png",
}

const TERRAIN_TILES := [
	CH1_TILE_PATH,
	"res://assets/terrain/tile_ch2_sunset_blossom_512.png",
	"res://assets/terrain/tile_ch3_nether_altar_512.png",
	"res://assets/terrain/tile_ch4_crimson_wasteland_512.png",
	"res://assets/terrain/tile_ch5_cloud_immortal_512.png",
]

class DecalLayerNode extends Node2D:
	var owner_bg: Node2D = null

	func _draw() -> void:
		if owner_bg != null and owner_bg.has_method("_draw_realm_decals"):
			owner_bg.call("_draw_realm_decals", self)

var _arena_rect: Rect2 = ARENA_RECT
var _boundary_pts: PackedVector2Array = PackedVector2Array()
var _boundary_body: StaticBody2D = null

var _tile_tex: Texture2D = DEFAULT_TILE
var _tile_size: float = TILE_SIZE
var _tile_cache: Dictionary = {}
var _chapter_id: int = 1
var _map_mode: MapMode = MapMode.CLASSIC
var _realm_id: String = "tutorial"
var _realm_cfg: Dictionary = {}
var _realm_floor_tint: Color = Color.WHITE
var _road_decals: Array[Dictionary] = []
var _hazard_sites: Array[Dictionary] = []
var _center_array_tex: Texture2D = null
var _road_decal_tex: Texture2D = null
var _road_cross_tex: Texture2D = null
var _decal_layer: DecalLayerNode = null
var _tutorial_managed_by_arena_map: bool = false

var _redraw_accum: float = 0.0
var _last_cam_center: Vector2 = Vector2.INF
var _ground_color: Color = Color(0.31, 0.36, 0.34, 1.0)
var _accent_color: Color = Color(0.24, 0.82, 0.70, 1.0)
var _gold_color: Color = Color(0.95, 0.80, 0.36, 1.0)
var _anim_time: float = 0.0
var _props: Array[Dictionary] = []
var _landmarks: Array[Dictionary] = []
var _stepping_stones: Array[Dictionary] = []
var _pillars: Array[Dictionary] = []
var _obstacle_body: StaticBody2D = null

func _ready() -> void:
	add_to_group("background")
	z_index = -100
	_decal_layer = DecalLayerNode.new()
	_decal_layer.name = "GroundDecalLayer"
	_decal_layer.z_as_relative = false
	_decal_layer.z_index = -50
	_decal_layer.owner_bg = self
	add_child(_decal_layer)
	_rebuild_boundary_walls()
	_build_landmarks()
	_scatter_props()
	_rebuild_obstacles()
	_apply_camera_limits()

func get_arena_rect() -> Rect2:
	return _arena_rect

func get_pillars() -> Array[Dictionary]:
	return _pillars

func get_landmarks_by_role(role: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for lm in _landmarks:
		if String(lm.get("role", "")) == role:
			out.append(lm)
	return out

func apply_chapter(chapter: Dictionary) -> void:
	_chapter_id = clampi(int(chapter.get("id", 1)), 1, 5)
	var realm_id := MapRealmCatalog.resolve_realm_id(chapter)
	var realm_cfg := MapRealmCatalog.get_realm(realm_id)

	var palette = chapter.get("palette", {})
	if palette is Dictionary:
		var ground = palette.get("ground", null)
		if ground is Color:
			_ground_color = ground
		elif ground is String:
			_ground_color = Color.from_string(String(ground), _ground_color)
		var tint = palette.get("tint", null)
		if tint is Color:
			_accent_color = tint
		elif tint is String:
			_accent_color = Color.from_string(String(tint), _accent_color)

	if String(realm_cfg.get("mode", "classic")) == "realm":
		_apply_realm_chapter(realm_id, realm_cfg)
		return

	_map_mode = MapMode.CLASSIC
	_realm_id = "tutorial"
	_realm_cfg = {}
	_arena_rect = ARENA_RECT
	_road_decals.clear()
	_hazard_sites.clear()
	_center_array_tex = null
	_road_decal_tex = null
	_road_cross_tex = null
	_tile_tex = CH1_TILE
	_tile_size = CH1_TILE_SIZE

	_rebuild_boundary_walls()
	_build_landmarks()
	_scatter_props()
	_rebuild_obstacles()
	_apply_camera_limits()

	var arena_map := _find_arena_map()
	_tutorial_managed_by_arena_map = false
	if arena_map != null and arena_map.has_method("build_tutorial_props"):
		arena_map.call("build_tutorial_props", SPAWN_CENTER, _pillars, _landmarks, CH1_PINE, CH1_LANDMARK_TEXTURES)
		_tutorial_managed_by_arena_map = true
		var extra_pillars: Variant = arena_map.get("cover_pillars_data")
		if extra_pillars is Array:
			for ep in extra_pillars:
				if ep is Dictionary:
					_pillars.append(ep)
	elif arena_map != null and arena_map.has_method("clear_realm"):
		arena_map.call("clear_realm")

	var landmarks := _find_landmarks_controller()
	if landmarks != null and landmarks.has_method("set_classic_mode"):
		landmarks.call("set_classic_mode")

	if _decal_layer != null:
		_decal_layer.queue_redraw()
	queue_redraw()

func _apply_realm_chapter(realm_id: String, realm_cfg: Dictionary) -> void:
	_map_mode = MapMode.REALM
	_realm_id = realm_id
	_realm_cfg = realm_cfg

	var map_sz := float(realm_cfg.get("map_size", 4200.0))
	_arena_rect = Rect2(
		SPAWN_CENTER.x - map_sz * 0.5,
		SPAWN_CENTER.y - map_sz * 0.5,
		map_sz,
		map_sz
	)
	_tile_tex = MapRealmCatalog.load_realm_texture(realm_cfg, "ground_tile")
	if _tile_tex == null:
		_tile_tex = DEFAULT_TILE
	_tile_size = float(_tile_tex.get_width()) if _tile_tex != null else 512.0
	var gt = realm_cfg.get("ground_tint", Color.WHITE)
	_realm_floor_tint = gt if gt is Color else Color.WHITE

	_center_array_tex = MapRealmCatalog.load_realm_texture(realm_cfg, "center_array")
	_road_decal_tex = MapRealmCatalog.load_realm_texture(realm_cfg, "road_decal")
	_road_cross_tex = MapRealmCatalog.load_realm_texture(realm_cfg, "road_cross_decal")
	_tutorial_managed_by_arena_map = false
	_build_realm_roads(map_sz, realm_cfg)
	_build_realm_hazards(realm_id, map_sz, realm_cfg)

	_props.clear()
	_pillars.clear()
	if _obstacle_body != null and is_instance_valid(_obstacle_body):
		_obstacle_body.queue_free()
		_obstacle_body = null

	_rebuild_boundary_walls()
	_apply_camera_limits()

	var arena_map := _find_arena_map()
	if arena_map != null and arena_map.has_method("build_realm"):
		var obs_list: Array = arena_map.call("build_realm", realm_cfg, _arena_rect, SPAWN_CENTER, _hazard_sites)
		for item in obs_list:
			if item is Dictionary:
				_pillars.append(item)
	else:
		_pillars = _compute_fallback_pillars(realm_cfg, _arena_rect, _hazard_sites)

	var landmarks := _find_landmarks_controller()
	if landmarks != null and landmarks.has_method("apply_realm"):
		landmarks.call("apply_realm", realm_id, realm_cfg, SPAWN_CENTER, _hazard_sites)

	if _decal_layer != null:
		_decal_layer.queue_redraw()
	queue_redraw()

func _build_realm_roads(map_sz: float, realm_cfg: Dictionary) -> void:
	_road_decals.clear()
	var arr_size := float(realm_cfg.get("center_array_size", 640.0))
	var start_r := arr_size * 0.50
	var end_r := float(realm_cfg.get("road_end_radius", map_sz * 0.5 - 220.0))
	var tex_w := float(_road_decal_tex.get_width()) if _road_decal_tex != null else 512.0
	var base_sc := 165.0 / maxf(1.0, tex_w)
	var step := tex_w * base_sc * 0.92
	var cross_dist := float(realm_cfg.get("courtyard_ring_dist", 0.0))

	var dirs: Array[Vector2] = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
	for d in dirs:
		var is_vert := absf(d.y) > 0.5
		var base_rot := PI * 0.5 if is_vert else 0.0
		var dist := start_r + step * 0.45
		while dist < end_r:
			var pos: Vector2 = SPAWN_CENTER + d * dist
			var is_cross := cross_dist > 0.0 and _road_cross_tex != null and absf(dist - cross_dist) < step * 0.48
			_road_decals.append({
				"pos": pos,
				"rot": 0.0 if is_cross else base_rot,
				"scale": base_sc,
				"flip_h": false,
				"is_cross": is_cross,
			})
			dist += step

	if cross_dist > 0.0:
		# Four clean courtyard branches leading from the 4 crossroad junctions to the 4 quadrant landmarks
		var branch_specs := [
			{"start": Vector2(0.0, -cross_dist), "dir": Vector2.LEFT},
			{"start": Vector2(0.0, -cross_dist), "dir": Vector2.RIGHT},
			{"start": Vector2(0.0, cross_dist), "dir": Vector2.LEFT},
			{"start": Vector2(0.0, cross_dist), "dir": Vector2.RIGHT},
		]
		for bs in branch_specs:
			var b_start: Vector2 = bs["start"]
			var b_dir: Vector2 = bs["dir"]
			var b_dist := step * 0.85
			while b_dist <= cross_dist - step * 0.4:
				_road_decals.append({
					"pos": SPAWN_CENTER + b_start + b_dir * b_dist,
					"rot": 0.0,
					"scale": base_sc,
					"flip_h": false,
					"is_cross": false,
				})
				b_dist += step

func _build_realm_hazards(_realm_id: String, _map_sz: float, realm_cfg: Dictionary) -> void:
	_hazard_sites.clear()
	var fixed: Array = realm_cfg.get("fixed_landmarks", [])
	for i in range(fixed.size()):
		var item: Dictionary = fixed[i]
		var htype := String(item.get("type", ""))
		var rel_pos: Vector2 = item.get("pos", Vector2.ZERO)
		var tex_path := String(item.get("tex", ""))
		var tex := MapRealmCatalog.load_tex_safe(tex_path)
		_hazard_sites.append({
			"id": "%s_%d" % [htype, i],
			"type": htype,
			"pos": SPAWN_CENTER + rel_pos,
			"radius": float(item.get("radius", 150.0)),
			"height": float(item.get("height", 180.0)),
			"phase_offset": float(item.get("phase_offset", 0.0)),
			"tex_path": tex_path,
			"tex": tex,
		})

func _compute_fallback_pillars(realm_cfg: Dictionary, arena_rect: Rect2, hazard_sites: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var dojo_r := float(realm_cfg.get("center_dojo_radius", 560.0))
	var road_hw := float(realm_cfg.get("road_half_width", 105.0))
	var min_spacing := float(realm_cfg.get("obstacle_min_spacing", 260.0))
	var target_count := clampi(int(realm_cfg.get("obstacle_count", 22)), 18, 26)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(realm_cfg.get("seed", 20261126))
	var inner_rect := arena_rect.grow(-280.0)
	var placed: Array[Vector2] = []
	var attempts := 0
	while placed.size() < target_count and attempts < target_count * 40:
		attempts += 1
		var pos := Vector2(rng.randf_range(inner_rect.position.x, inner_rect.end.x), rng.randf_range(inner_rect.position.y, inner_rect.end.y))
		if pos.distance_to(SPAWN_CENTER) < dojo_r + 70.0:
			continue
		if absf(pos.x - SPAWN_CENTER.x) < road_hw + 95.0 or absf(pos.y - SPAWN_CENTER.y) < road_hw + 95.0:
			continue
		var ok := true
		for h in hazard_sites:
			if pos.distance_to(h["pos"] as Vector2) < 230.0:
				ok = false
				break
		if not ok:
			continue
		for prev in placed:
			if pos.distance_to(prev) < min_spacing:
				ok = false
				break
		if not ok:
			continue
		placed.append(pos)
		out.append({"id": out.size(), "tag": "realm_prop_%d" % out.size(), "pos": pos, "radius": 32.0, "is_core_pillar": false})
	return out

func _find_arena_map() -> Node:
	var parent_n := get_parent()
	if parent_n != null:
		var direct := parent_n.get_node_or_null("ArenaMap")
		if direct != null:
			return direct
	var tree := get_tree()
	return tree.get_first_node_in_group("arena_map") if tree != null else null

func _find_landmarks_controller() -> Node:
	var parent_n := get_parent()
	if parent_n != null:
		var direct := parent_n.get_node_or_null("ArenaLandmarks")
		if direct != null:
			return direct
	var tree := get_tree()
	return tree.get_first_node_in_group("landmarks_controller") if tree != null else null

func _load_prop_tex(key: String) -> Texture2D:
	if key == "ch1_pine":
		return CH1_PINE
	var path: String = str(PROP_PATHS.get(key, ""))
	if path != "" and ResourceLoader.exists(path):
		return load(path)
	return null

func _rebuild_obstacles() -> void:
	_pillars.clear()
	if _obstacle_body != null and is_instance_valid(_obstacle_body):
		_obstacle_body.queue_free()
	_obstacle_body = StaticBody2D.new()
	_obstacle_body.name = "ArenaPillars"
	_obstacle_body.collision_layer = 1 | 4
	_obstacle_body.collision_mask = 0
	add_child(_obstacle_body)

	for i in range(CORE_PILLAR_OFFSETS.size()):
		var p_pos: Vector2 = SPAWN_CENTER + CORE_PILLAR_OFFSETS[i]
		_add_solid_circle(p_pos, PILLAR_RADIUS, "pillar_%d" % i, true)

	for lm in _landmarks:
		var col_r: float = float(lm.get("collider_radius", 0.0))
		if col_r > 0.0:
			var col_off: Vector2 = lm.get("collider_offset", Vector2.ZERO)
			_add_solid_circle((lm["pos"] as Vector2) + col_off, col_r, String(lm.get("id", "lm")), false)

	for p in _props:
		var col_r: float = float(p.get("collider_radius", 0.0))
		if col_r > 0.0:
			var col_off: Vector2 = p.get("collider_offset", Vector2.ZERO)
			_add_solid_circle((p["pos"] as Vector2) + col_off, col_r, "prop", false)

func _add_solid_circle(pos: Vector2, radius: float, tag: String, is_core_pillar: bool) -> void:
	_pillars.append({
		"id": _pillars.size(),
		"tag": tag,
		"pos": pos,
		"radius": radius,
		"is_core_pillar": is_core_pillar,
	})
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = radius
	col.shape = shape
	col.position = pos
	_obstacle_body.add_child(col)

func _build_landmarks() -> void:
	_landmarks.clear()
	_stepping_stones.clear()

	_landmarks = [
		{
			"id": "spirit_spring",
			"role": "spirit_array",
			"name": "西北聚灵泉",
			"pos": SPAWN_CENTER + Vector2(-760.0, -480.0),
			"radius": 145.0,
			"collider_radius": 0.0,
			"collider_offset": Vector2.ZERO,
			"outer_col": Color(0.16, 0.56, 0.52, 0.16),
			"inner_col": Color(0.24, 0.74, 0.66, 0.22),
			"ring_col": Color(0.46, 0.88, 0.78, 0.36),
		},
		{
			"id": "sword_mound",
			"role": "demon_stele",
			"name": "东北镇魔碑",
			"pos": SPAWN_CENTER + Vector2(760.0, -480.0),
			"radius": 145.0,
			"collider_radius": 0.0,
			"collider_offset": Vector2.ZERO,
			"outer_col": Color(0.68, 0.54, 0.28, 0.16),
			"inner_col": Color(0.78, 0.62, 0.32, 0.22),
			"ring_col": Color(0.88, 0.72, 0.38, 0.38),
		},
		{
			"id": "peach_brook",
			"role": "well",
			"name": "西南古井",
			"pos": SPAWN_CENTER + Vector2(-760.0, 480.0),
			"radius": 145.0,
			"collider_radius": 0.0,
			"collider_offset": Vector2.ZERO,
			"outer_col": Color(0.72, 0.42, 0.48, 0.16),
			"inner_col": Color(0.84, 0.52, 0.58, 0.22),
			"ring_col": Color(0.92, 0.64, 0.52, 0.36),
		},
		{
			"id": "star_altar",
			"role": "spirit_array",
			"name": "东南聚灵鼎",
			"pos": SPAWN_CENTER + Vector2(760.0, 480.0),
			"radius": 145.0,
			"collider_radius": 0.0,
			"collider_offset": Vector2.ZERO,
			"outer_col": Color(0.32, 0.48, 0.78, 0.16),
			"inner_col": Color(0.42, 0.66, 0.90, 0.22),
			"ring_col": Color(0.64, 0.78, 0.92, 0.38),
		},
	]

func _scatter_props() -> void:
	_props.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261123

	var foliage_names := ["fern", "moss"]
	for _j in range(28):
		var prop_name: String = foliage_names[rng.randi_range(0, foliage_names.size() - 1)]
		var tex := _load_prop_tex(prop_name)
		if tex == null:
			continue
		var pos := Vector2(
			rng.randf_range(_arena_rect.position.x + 100.0, _arena_rect.end.x - 100.0),
			rng.randf_range(_arena_rect.position.y + 100.0, _arena_rect.end.y - 100.0)
		)
		if pos.distance_to(SPAWN_CENTER) < 240.0:
			continue
		var blocked_zone := false
		for lm in _landmarks:
			if pos.distance_to(lm["pos"] as Vector2) < 155.0:
				blocked_zone = true
				break
		if not blocked_zone:
			for off in CORE_PILLAR_OFFSETS:
				if pos.distance_to(SPAWN_CENTER + off) < 90.0:
					blocked_zone = true
					break
		if blocked_zone:
			continue
		_props.append({
			"pos": pos,
			"tex": tex,
			"scale": rng.randf_range(0.46, 0.72),
			"style": "flat",
			"tint": Color(0.78, 0.84, 0.78, 0.72),
			"collider_radius": 0.0,
		})

	_props.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a["pos"] as Vector2).y < (b["pos"] as Vector2).y
	)

func _rebuild_boundary_walls() -> void:
	_boundary_pts = PackedVector2Array([
		_arena_rect.position,
		Vector2(_arena_rect.end.x, _arena_rect.position.y),
		_arena_rect.end,
		Vector2(_arena_rect.position.x, _arena_rect.end.y),
		_arena_rect.position,
	])
	if _boundary_body != null and is_instance_valid(_boundary_body):
		_boundary_body.queue_free()
	_boundary_body = StaticBody2D.new()
	_boundary_body.name = "ArenaBoundaries"
	_boundary_body.collision_layer = 1 | 4 if _map_mode == MapMode.CLASSIC else 1
	_boundary_body.collision_mask = 0
	add_child(_boundary_body)

	var c: Vector2 = _arena_rect.get_center()
	var w: float = _arena_rect.size.x
	var h: float = _arena_rect.size.y
	var wall_specs := [
		{"pos": Vector2(_arena_rect.position.x - 25.0, c.y), "size": Vector2(50.0, h + 100.0)},
		{"pos": Vector2(_arena_rect.end.x + 25.0, c.y), "size": Vector2(50.0, h + 100.0)},
		{"pos": Vector2(c.x, _arena_rect.position.y - 25.0), "size": Vector2(w + 100.0, 50.0)},
		{"pos": Vector2(c.x, _arena_rect.end.y + 25.0), "size": Vector2(w + 100.0, 50.0)},
	]
	for spec in wall_specs:
		var col := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = spec["size"]
		col.shape = shape
		col.position = spec["pos"]
		_boundary_body.add_child(col)

func _apply_camera_limits() -> void:
	call_deferred("_do_apply_camera_limits")

func _do_apply_camera_limits() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var players := tree.get_nodes_in_group("player")
	if players.size() > 0:
		var cam: Camera2D = players[0].get_node_or_null("Camera2D")
		if cam != null:
			cam.limit_left = int(_arena_rect.position.x)
			cam.limit_right = int(_arena_rect.end.x)
			cam.limit_top = int(_arena_rect.position.y)
			cam.limit_bottom = int(_arena_rect.end.y)

func _process(delta: float) -> void:
	_anim_time += delta
	_redraw_accum += delta
	var center := _visible_world_rect().get_center()
	if _redraw_accum >= 0.033 or _last_cam_center.distance_squared_to(center) >= 9216.0:
		_redraw_accum = 0.0
		_last_cam_center = center
		queue_redraw()

func _visible_world_rect() -> Rect2:
	var vp := get_viewport()
	if vp == null:
		return Rect2(-800, -500, 1600, 1000)
	var vp_size := vp.get_visible_rect().size
	var inv := vp.get_canvas_transform().affine_inverse()
	var tl := inv * Vector2.ZERO
	var br := inv * vp_size
	return Rect2(tl, br - tl).abs()

func _draw() -> void:
	var vis := _visible_world_rect()
	var margin := Vector2(_tile_size * 1.5, _tile_size * 1.5)

	var start_x := floorf((vis.position.x - margin.x) / _tile_size) * _tile_size
	var end_x := ceilf((vis.end.x + margin.x) / _tile_size) * _tile_size
	var start_y := floorf((vis.position.y - margin.y) / _tile_size) * _tile_size
	var end_y := ceilf((vis.end.y + margin.y) / _tile_size) * _tile_size

	var biome_tint: Color = _realm_floor_tint if _map_mode == MapMode.REALM else CH1_FLOOR_TINT
	var x := start_x
	while x <= end_x:
		var y := start_y
		while y <= end_y:
			var tile_rect := Rect2(x, y, _tile_size, _tile_size)
			if _arena_rect.intersects(tile_rect):
				draw_texture_rect(_tile_tex, tile_rect, false, biome_tint)
			else:
				draw_texture_rect(_tile_tex, tile_rect, false, biome_tint * Color(0.62, 0.65, 0.68, 1.0))
			y += _tile_size
		x += _tile_size

	if _map_mode == MapMode.CLASSIC:
		_draw_roads_and_landmarks(vis)
		if not _tutorial_managed_by_arena_map:
			_draw_pillars(vis)
		_draw_props(vis)
	_draw_boundary_barrier()

func _draw_realm_decals(canvas: Node2D) -> void:
	if _map_mode != MapMode.REALM:
		return
	if _road_decal_tex != null:
		for stamp in _road_decals:
			var use_cross := bool(stamp.get("is_cross", false)) and _road_cross_tex != null
			var r_tex := _road_cross_tex if use_cross else _road_decal_tex
			var r_sz := Vector2(r_tex.get_width(), r_tex.get_height())
			var pos: Vector2 = stamp["pos"]
			var sc: float = float(stamp["scale"])
			var rot: float = float(stamp["rot"])
			var flip_x := bool(stamp.get("flip_h", false))
			var sz := r_sz * sc
			canvas.draw_set_transform(pos, rot, Vector2(-1.0 if flip_x else 1.0, 1.0))
			canvas.draw_texture_rect(r_tex, Rect2(-sz * 0.5, sz), false, Color(0.95, 0.95, 0.95, 0.92))
		canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if _center_array_tex != null:
		var arr_sz_px := float(_realm_cfg.get("center_array_size", 640.0))
		var arr_sz := Vector2(arr_sz_px, arr_sz_px)
		canvas.draw_texture_rect(_center_array_tex, Rect2(SPAWN_CENTER - arr_sz * 0.5, arr_sz), false, Color(1.0, 1.0, 1.0, 0.90))

	for h in _hazard_sites:
		var ht := String(h.get("type", ""))
		if ht == "sword_stele" or ht == "prop_anchor":
			continue
		var tex: Texture2D = h.get("tex", null) as Texture2D
		if tex == null:
			continue
		var rad := float(h.get("radius", 155.0))
		var h_sz := Vector2(rad * 2.35, rad * 2.35)
		canvas.draw_texture_rect(tex, Rect2((h["pos"] as Vector2) - h_sz * 0.5, h_sz), false, Color(1.0, 1.0, 1.0, 0.94))

func _draw_roads_and_landmarks(vis: Rect2) -> void:
	var padded := vis.grow(280.0)
	if padded.has_point(SPAWN_CENTER):
		var ring_size := Vector2(CH1_CENTER_RING.get_width(), CH1_CENTER_RING.get_height()) * CH1_CENTER_RING_SCALE
		draw_texture_rect(CH1_CENTER_RING, Rect2(SPAWN_CENTER - ring_size * 0.5, ring_size), false, Color.WHITE)

	if not _tutorial_managed_by_arena_map:
		for lm in _landmarks:
			var lp: Vector2 = lm["pos"]
			if not padded.has_point(lp):
				continue
			var rad: float = float(lm["radius"])
			var poi_tex: Texture2D = CH1_LANDMARK_TEXTURES.get(String(lm["id"]), null)
			if poi_tex != null:
				var poi_scale := clampf(rad * 1.55 / float(maxi(poi_tex.get_width(), poi_tex.get_height())), 0.52, 0.88)
				var poi_size := Vector2(poi_tex.get_width(), poi_tex.get_height()) * poi_scale
				draw_set_transform(lp + Vector2(0.0, 14.0), 0.0, Vector2(1.12, 0.44))
				draw_circle(Vector2.ZERO, poi_size.x * 0.34, Color(0.04, 0.09, 0.06, 0.22))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				draw_texture_rect(poi_tex, Rect2(lp - poi_size * 0.5, poi_size), false, Color.WHITE)

func _draw_pillars(vis: Rect2) -> void:
	var padded := vis.grow(140.0)
	var tree_size := Vector2(CH1_PINE.get_width(), CH1_PINE.get_height()) * CH1_PINE_SCALE
	for p in _pillars:
		if not bool(p.get("is_core_pillar", false)):
			continue
		var pos: Vector2 = p["pos"]
		if not padded.has_point(pos):
			continue
		draw_set_transform(pos + Vector2(0.0, 6.0), 0.0, Vector2(0.95, 0.42))
		draw_circle(Vector2.ZERO, PILLAR_RADIUS + 4.0, Color(0.04, 0.08, 0.05, 0.38))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_texture_rect(CH1_PINE, Rect2(pos - Vector2(tree_size.x * 0.5, tree_size.y * 0.88), tree_size), false, Color.WHITE)

func _draw_props(vis: Rect2) -> void:
	var padded := vis.grow(180.0)
	for p in _props:
		var pos: Vector2 = p["pos"]
		if not padded.has_point(pos):
			continue
		var tex: Texture2D = p["tex"]
		var s: float = p["scale"]
		var size := Vector2(tex.get_width(), tex.get_height()) * s
		var rect := Rect2(pos - Vector2(size.x * 0.5, size.y * 0.72), size)
		var tint: Color = p.get("tint", Color(0.76, 0.78, 0.80, 0.92))
		draw_texture_rect(tex, rect, false, tint)

func _draw_boundary_barrier() -> void:
	if _map_mode == MapMode.REALM:
		draw_polyline(_boundary_pts, Color(0.06, 0.10, 0.09, 0.26), 12.0)
		return
	var pulse := 0.55 + 0.20 * sin(_anim_time * 3.0)
	draw_polyline(_boundary_pts, Color(_gold_color.r, _gold_color.g, _gold_color.b, pulse * 0.55), 8.0)
	draw_polyline(_boundary_pts, Color(_accent_color.r, _accent_color.g, _accent_color.b, pulse * 0.85), 3.5)
