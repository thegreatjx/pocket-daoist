extends Node2D

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

var _boundary_pts: PackedVector2Array = PackedVector2Array([
	ARENA_RECT.position,
	Vector2(ARENA_RECT.end.x, ARENA_RECT.position.y),
	ARENA_RECT.end,
	Vector2(ARENA_RECT.position.x, ARENA_RECT.end.y),
	ARENA_RECT.position,
])

var _tile_tex: Texture2D = DEFAULT_TILE
var _tile_size: float = TILE_SIZE
var _tile_cache: Dictionary = {}
var _chapter_id: int = 1
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
	_create_boundary_walls()
	_build_landmarks()
	_scatter_props()
	_rebuild_obstacles()
	_apply_camera_limits()

func get_arena_rect() -> Rect2:
	return ARENA_RECT

func get_pillars() -> Array[Dictionary]:
	return _pillars

func get_landmarks_by_role(role: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for lm in _landmarks:
		if String(lm.get("role", "")) == role:
			out.append(lm)
	return out

func apply_chapter(chapter: Dictionary) -> void:
	var prev_id := _chapter_id
	_chapter_id = clampi(int(chapter.get("id", 1)), 1, 5)
	var tile_idx := clampi(_chapter_id - 1, 0, TERRAIN_TILES.size() - 1)
	var tile_path: String = TERRAIN_TILES[tile_idx]
	if _chapter_id == 1:
		_tile_tex = CH1_TILE
	elif _tile_cache.has(tile_path):
		_tile_tex = _tile_cache[tile_path]
	elif ResourceLoader.exists(tile_path):
		var loaded := load(tile_path) as Texture2D
		if loaded != null:
			_tile_cache[tile_path] = loaded
			_tile_tex = loaded
	else:
		_tile_tex = DEFAULT_TILE
	_tile_size = CH1_TILE_SIZE if _tile_tex == CH1_TILE else TILE_SIZE
	var palette = chapter.get("palette", {})
	if palette is Dictionary:
		var ground = palette.get("ground", null)
		if ground is Color:
			_ground_color = ground
		var tint = palette.get("tint", null)
		if tint is Color:
			_accent_color = tint
	if prev_id != _chapter_id:
		_scatter_props()
		_rebuild_obstacles()
	queue_redraw()

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

	var solid_positions: Array[Vector2] = []
	for off in CORE_PILLAR_OFFSETS:
		solid_positions.append(SPAWN_CENTER + off)
	for lm in _landmarks:
		solid_positions.append(lm["pos"] as Vector2)

	if _chapter_id != 1:
		var solid_names := ["pine", "pine", "stele", "rune_stone"]
		for _i in range(18):
			var prop_name: String = solid_names[rng.randi_range(0, solid_names.size() - 1)]
			var tex := _load_prop_tex(prop_name)
			if tex == null:
				continue
			var pos := Vector2(
				rng.randf_range(ARENA_RECT.position.x + 150.0, ARENA_RECT.end.x - 150.0),
				rng.randf_range(ARENA_RECT.position.y + 150.0, ARENA_RECT.end.y - 150.0)
			)
			if pos.distance_to(SPAWN_CENTER) < 320.0:
				continue
			var too_close := false
			for sp in solid_positions:
				if pos.distance_to(sp) < 230.0:
					too_close = true
					break
			if too_close:
				continue
			solid_positions.append(pos)
			var is_tree := (prop_name == "pine")
			var s := rng.randf_range(0.76, 0.96) if is_tree else rng.randf_range(0.64, 0.80)
			_props.append({
				"pos": pos,
				"tex": tex,
				"scale": s,
				"style": "ground",
				"tint": Color(0.82, 0.84, 0.86, 0.94),
				"collider_radius": 0.0,
				"collider_offset": Vector2.ZERO,
			})

	var foliage_names := ["fern", "moss"]
	for _j in range(28):
		var prop_name: String = foliage_names[rng.randi_range(0, foliage_names.size() - 1)]
		var tex := _load_prop_tex(prop_name)
		if tex == null:
			continue
		var pos := Vector2(
			rng.randf_range(ARENA_RECT.position.x + 100.0, ARENA_RECT.end.x - 100.0),
			rng.randf_range(ARENA_RECT.position.y + 100.0, ARENA_RECT.end.y - 100.0)
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

func _create_boundary_walls() -> void:
	var sb := StaticBody2D.new()
	sb.name = "ArenaBoundaries"
	sb.collision_layer = 1 | 4
	sb.collision_mask = 0
	add_child(sb)

	var c: Vector2 = ARENA_RECT.get_center()
	var w: float = ARENA_RECT.size.x
	var h: float = ARENA_RECT.size.y
	var wall_specs := [
		{"pos": Vector2(ARENA_RECT.position.x - 25.0, c.y), "size": Vector2(50.0, h + 100.0)},
		{"pos": Vector2(ARENA_RECT.end.x + 25.0, c.y), "size": Vector2(50.0, h + 100.0)},
		{"pos": Vector2(c.x, ARENA_RECT.position.y - 25.0), "size": Vector2(w + 100.0, 50.0)},
		{"pos": Vector2(c.x, ARENA_RECT.end.y + 25.0), "size": Vector2(w + 100.0, 50.0)},
	]
	for spec in wall_specs:
		var col := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = spec["size"]
		col.shape = shape
		col.position = spec["pos"]
		sb.add_child(col)

func _apply_camera_limits() -> void:
	call_deferred("_do_apply_camera_limits")

func _do_apply_camera_limits() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var cam: Camera2D = players[0].get_node_or_null("Camera2D")
		if cam != null:
			cam.limit_left = int(ARENA_RECT.position.x)
			cam.limit_right = int(ARENA_RECT.end.x)
			cam.limit_top = int(ARENA_RECT.position.y)
			cam.limit_bottom = int(ARENA_RECT.end.y)

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

	var x := start_x
	while x <= end_x:
		var y := start_y
		while y <= end_y:
			var tile_rect := Rect2(x, y, _tile_size, _tile_size)
			var gx := int(floor(x / _tile_size))
			var gy := int(floor(y / _tile_size))
			var h := int(absi(gx * 73856093)) ^ int(absi(gy * 19349663))
			var macro_wave := sin(float(gx) * 0.45 + float(gy) * 0.35) * 0.025
			var jitter := 0.96 + float(h % 7) * 0.006 + macro_wave
			var biome_tint: Color
			if _chapter_id == 1:
				biome_tint = Color(
					clampf(CH1_FLOOR_TINT.r * jitter, 0.0, 1.0),
					clampf(CH1_FLOOR_TINT.g * (jitter + macro_wave * 0.35), 0.0, 1.0),
					clampf(CH1_FLOOR_TINT.b * (jitter - macro_wave * 0.25), 0.0, 1.0),
					1.0
				)
			else:
				biome_tint = Color(
					clampf(_ground_color.r * jitter, 0.22, 0.44),
					clampf(_ground_color.g * (jitter + macro_wave * 0.35), 0.22, 0.44),
					clampf(_ground_color.b * (jitter - macro_wave * 0.25), 0.22, 0.44),
					1.0
				)
			if ARENA_RECT.intersects(tile_rect):
				draw_texture_rect(_tile_tex, tile_rect, false, biome_tint)
			else:
				draw_texture_rect(_tile_tex, tile_rect, false, biome_tint * Color(0.62, 0.65, 0.68, 1.0))
			y += _tile_size
		x += _tile_size

	_draw_roads_and_landmarks(vis)
	_draw_pillars(vis)
	_draw_props(vis)
	_draw_boundary_barrier()

func _draw_roads_and_landmarks(vis: Rect2) -> void:
	var padded := vis.grow(280.0)

	if padded.has_point(SPAWN_CENTER) and _chapter_id == 1:
		var ring_size := Vector2(CH1_CENTER_RING.get_width(), CH1_CENTER_RING.get_height()) * CH1_CENTER_RING_SCALE
		draw_texture_rect(CH1_CENTER_RING, Rect2(SPAWN_CENTER - ring_size * 0.5, ring_size), false, Color.WHITE)

	for lm in _landmarks:
		var lp: Vector2 = lm["pos"]
		if not padded.has_point(lp):
			continue
		var rad: float = float(lm["radius"])
		if _chapter_id != 1:
			var o_col: Color = lm["outer_col"]
			var i_col: Color = lm["inner_col"]
			var r_col: Color = lm["ring_col"]
			draw_circle(lp, rad, o_col)
			draw_circle(lp, rad * 0.62, i_col)
			draw_arc(lp, rad, 0.0, TAU, 48, r_col, 2.5)
			draw_arc(lp, rad * 0.45, 0.0, TAU, 36, r_col, 1.8)
			var to_center := (SPAWN_CENTER - lp).normalized()
			draw_line(lp + to_center * rad, lp + to_center * (rad + 120.0), Color(r_col.r, r_col.g, r_col.b, 0.20), 2.4)
			continue
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
		if _chapter_id == 1:
			draw_set_transform(pos + Vector2(0.0, 6.0), 0.0, Vector2(0.95, 0.42))
			draw_circle(Vector2.ZERO, PILLAR_RADIUS + 4.0, Color(0.04, 0.08, 0.05, 0.38))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			draw_texture_rect(CH1_PINE, Rect2(pos - Vector2(tree_size.x * 0.5, tree_size.y * 0.88), tree_size), false, Color.WHITE)
			continue
		var r: float = float(p["radius"])
		draw_set_transform(pos + Vector2(0.0, 12.0), 0.0, Vector2(1.12, 0.68))
		draw_circle(Vector2.ZERO, r + 6.0, Color(0.05, 0.07, 0.09, 0.45))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_circle(pos, r, Color(0.24, 0.28, 0.32, 1.0))
		draw_circle(pos + Vector2(0.0, -6.0), r * 0.86, Color(0.35, 0.40, 0.44, 1.0))
		draw_arc(pos, r, 0.0, TAU, 36, Color(0.10, 0.13, 0.16, 0.95), 3.0)
		draw_arc(pos + Vector2(0.0, -6.0), r * 0.62, 0.0, TAU, 24, Color(_accent_color.r, _accent_color.g, _accent_color.b, 0.36), 2.0)

func _draw_props(vis: Rect2) -> void:
	var padded := vis.grow(180.0)
	for p in _props:
		var pos: Vector2 = p["pos"]
		if not padded.has_point(pos):
			continue
		var tex: Texture2D = p["tex"]
		var s: float = p["scale"]
		var size := Vector2(tex.get_width(), tex.get_height()) * s
		var style: String = str(p["style"])
		if style != "flat":
			draw_set_transform(Vector2(pos.x, pos.y - 3.0), 0.0, Vector2(1.0, 0.42))
			draw_circle(Vector2.ZERO, size.x * 0.28, Color(0.06, 0.12, 0.10, 0.24))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var rect: Rect2
		match style:
			"flat":
				rect = Rect2(pos - Vector2(size.x * 0.5, size.y * 0.72), size)
			"hang":
				var hang_pos := pos - Vector2(0.0, 22.0)
				var post_x := pos.x - size.x * 0.34
				var hook_y := hang_pos.y - size.y * 0.86
				draw_circle(Vector2(post_x, pos.y - 2.0), 4.0, Color(0.18, 0.26, 0.23, 0.65))
				draw_line(Vector2(post_x, pos.y - 2.0), Vector2(post_x, hook_y), Color(0.22, 0.17, 0.13, 0.90), 3.0)
				draw_line(Vector2(post_x, hook_y), Vector2(hang_pos.x, hook_y), Color(0.22, 0.17, 0.13, 0.90), 2.6)
				var glow_r := size.x * (0.45 + 0.04 * sin(_anim_time * 3.5 + pos.x * 0.02))
				draw_circle(hang_pos - Vector2(0.0, size.y * 0.48), glow_r, Color(1.0, 0.78, 0.38, 0.12))
				rect = Rect2(hang_pos - Vector2(size.x * 0.5, size.y), size)
			_:
				rect = Rect2(pos - Vector2(size.x * 0.5, size.y), size)
		var tint: Color = p.get("tint", Color(0.76, 0.78, 0.80, 0.92))
		draw_texture_rect(tex, rect, false, tint)

func _draw_boundary_barrier() -> void:
	var pulse := 0.55 + 0.20 * sin(_anim_time * 3.0)
	draw_polyline(_boundary_pts, Color(_gold_color.r, _gold_color.g, _gold_color.b, pulse * 0.55), 8.0)
	draw_polyline(_boundary_pts, Color(_accent_color.r, _accent_color.g, _accent_color.b, pulse * 0.85), 3.5)
