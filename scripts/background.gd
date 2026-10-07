extends Node2D

const TILE_TEX: Texture2D = preload("res://assets/sprites/xianxia_ground_tile.png")
const TILE_SIZE := 256.0

const ARENA_HALF_WIDTH := 1500.0
const ARENA_HALF_HEIGHT := 1500.0
const ARENA_RECT := Rect2(-ARENA_HALF_WIDTH, -ARENA_HALF_HEIGHT, ARENA_HALF_WIDTH * 2.0, ARENA_HALF_HEIGHT * 2.0)

var last_center: Vector2 = Vector2(INF, INF)
var _anim_time: float = 0.0

func _ready() -> void:
	_create_boundary_walls()
	_apply_camera_limits()

func _create_boundary_walls() -> void:
	var sb = StaticBody2D.new()
	sb.name = "ArenaBoundaries"
	sb.collision_layer = 1 | 4  # 阻挡玩家 (layer 1) 与 敌人 (layer 4)
	sb.collision_mask = 0
	add_child(sb)

	var wall_specs = [
		{"pos": Vector2(-ARENA_HALF_WIDTH - 25.0, 0.0), "size": Vector2(50.0, ARENA_HALF_HEIGHT * 2.0 + 100.0)},
		{"pos": Vector2(ARENA_HALF_WIDTH + 25.0, 0.0), "size": Vector2(50.0, ARENA_HALF_HEIGHT * 2.0 + 100.0)},
		{"pos": Vector2(0.0, -ARENA_HALF_HEIGHT - 25.0), "size": Vector2(ARENA_HALF_WIDTH * 2.0 + 100.0, 50.0)},
		{"pos": Vector2(0.0, ARENA_HALF_HEIGHT + 25.0), "size": Vector2(ARENA_HALF_WIDTH * 2.0 + 100.0, 50.0)},
	]

	for spec in wall_specs:
		var col = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = spec["size"]
		col.shape = shape
		col.position = spec["pos"]
		sb.add_child(col)

func _apply_camera_limits() -> void:
	call_deferred("_do_apply_camera_limits")

func _do_apply_camera_limits() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var cam: Camera2D = players[0].get_node_or_null("Camera2D")
		if cam != null:
			cam.limit_left = int(-ARENA_HALF_WIDTH)
			cam.limit_right = int(ARENA_HALF_WIDTH)
			cam.limit_top = int(-ARENA_HALF_HEIGHT)
			cam.limit_bottom = int(ARENA_HALF_HEIGHT)

func _process(delta: float) -> void:
	_anim_time += delta
	var center = _player_center()
	if last_center == Vector2(INF, INF) or center.distance_to(last_center) >= 40.0:
		last_center = center
		queue_redraw()
	else:
		# 结界光芒微动
		queue_redraw()

func _player_center() -> Vector2:
	var p = get_tree().get_nodes_in_group("player")
	if p.size() > 0 and is_instance_valid(p[0]):
		return p[0].global_position
	return Vector2.ZERO

func _draw() -> void:
	var vp = get_viewport_rect().size
	var center = _player_center()
	var margin = Vector2(300, 300)

	var start_x = floor((center.x - vp.x * 0.5 - margin.x) / TILE_SIZE) * TILE_SIZE
	var end_x = ceil((center.x + vp.x * 0.5 + margin.x) / TILE_SIZE) * TILE_SIZE
	var start_y = floor((center.y - vp.y * 0.5 - margin.y) / TILE_SIZE) * TILE_SIZE
	var end_y = ceil((center.y + vp.y * 0.5 + margin.y) / TILE_SIZE) * TILE_SIZE

	# 1. 铺设修仙古石板路与地脉地砖
	var x = start_x
	while x <= end_x:
		var y = start_y
		while y <= end_y:
			var tile_rect = Rect2(x, y, TILE_SIZE, TILE_SIZE)
			# 如果在地界范围内，铺设地砖
			if ARENA_RECT.intersects(tile_rect):
				if TILE_TEX != null:
					draw_texture_rect(TILE_TEX, tile_rect, false)
				else:
					draw_rect(tile_rect, Color(0.12, 0.16, 0.22, 1.0))
			else:
				# 结界外部：无尽虚空黑雾
				draw_rect(tile_rect, Color(0.03, 0.04, 0.06, 1.0))
			y += TILE_SIZE
		x += TILE_SIZE

	# 2. 地图中心：太极阴阳阵纹
	var center_dist = center.length()
	if center_dist < 1200.0:
		_draw_center_array()

	# 3. 边界处：太玄封魔结界光幕
	_draw_boundary_barrier()

func _draw_center_array() -> void:
	# 中心八卦阵外环
	var aura_p = sin(_anim_time * 2.0) * 0.1
	draw_arc(Vector2.ZERO, 380.0, 0.0, TAU, 48, Color(0.2, 0.7, 1.0, 0.35 + aura_p), 3.0)
	draw_arc(Vector2.ZERO, 350.0, 0.0, TAU, 48, Color(0.9, 0.75, 0.3, 0.25 + aura_p), 2.0)
	draw_circle(Vector2.ZERO, 120.0, Color(0.1, 0.5, 0.8, 0.12))
	# 太极两仪微光
	draw_arc(Vector2.ZERO, 120.0, 0.0, TAU, 32, Color(0.3, 0.85, 1.0, 0.5), 2.5)

func _draw_boundary_barrier() -> void:
	var pulse = 0.55 + 0.25 * sin(_anim_time * 3.5)
	var border_color = Color(0.25, 0.85, 1.0, pulse)
	var glow_color = Color(0.9, 0.7, 0.2, pulse * 0.6)

	# 四道九天封魔结界光幕
	var p_tl = Vector2(-ARENA_HALF_WIDTH, -ARENA_HALF_HEIGHT)
	var p_tr = Vector2(ARENA_HALF_WIDTH, -ARENA_HALF_HEIGHT)
	var p_br = Vector2(ARENA_HALF_WIDTH, ARENA_HALF_HEIGHT)
	var p_bl = Vector2(-ARENA_HALF_WIDTH, ARENA_HALF_HEIGHT)

	var pts = PackedVector2Array([p_tl, p_tr, p_br, p_bl, p_tl])
	draw_polyline(pts, glow_color, 8.0)
	draw_polyline(pts, border_color, 4.0)

	# 四角封魔阵桩发光符印
	for p in [p_tl, p_tr, p_br, p_bl]:
		draw_circle(p, 32.0, Color(0.2, 0.7, 1.0, 0.25))
		draw_arc(p, 28.0, 0.0, TAU, 24, Color(1.0, 0.8, 0.3, pulse), 3.0)
