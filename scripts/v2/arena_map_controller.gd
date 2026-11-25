class_name ArenaMapController
extends Node2D

## Data-driven 2.5-screen bounded arena builder for Chapter 1 (Meadow) and later Han chapters.
## Loads layout from res://data/v2/map_arena_v2.json, creates seamless repeating floor,
## Y-sorted trees with automatic canopy fade-out, and exposes circular cover pillars for steering.

var arena_half_size := Vector2(1400.0, 1000.0)
var cover_pillars_data: Array[Dictionary] = [] # [{pos: Vector2, radius: float}]

var _floor_sprite: Sprite2D
var _center_sprite: Sprite2D
var _ysort_root: Node2D
var _walls_body: StaticBody2D

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
	cover_pillars_data.clear()

	# 1. Seamless repeating floor
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

	# 2. Center anchor ring
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

	# 3. Y-Sorted layer for trees & POIs
	_ysort_root = Node2D.new()
	_ysort_root.y_sort_enabled = true
	add_child(_ysort_root)

	for p in ch.get("cover_pillars", []):
		_spawn_cover_tree(p)
	for poi in ch.get("landmarks", []):
		_spawn_landmark(poi)

	# 4. Bounded 4-segment arena walls
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
	sp.offset = Vector2(0, -85) # Anchor at trunk base for accurate Y-Sort
	sp.scale = Vector2(0.75, 0.75)
	body.add_child(sp)

	# Canopy fade Area2D when player walks behind tree
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
	## Add to EnemySteeringDirector velocity so 200+ enemies slide smoothly around round trees/pillars.
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
