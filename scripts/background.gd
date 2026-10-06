extends Node2D

const TILE_SIZE := 80.0

var last_center: Vector2 = Vector2(INF, INF)

func _process(_delta: float) -> void:
	var center = _player_center()
	# 只在玩家移动超过一格时重绘（旧版每帧重画 5000x5000 范围网格，CPU 开销大）
	if last_center == Vector2(INF, INF) or center.distance_to(last_center) >= TILE_SIZE:
		last_center = center
		queue_redraw()

func _player_center() -> Vector2:
	var p = get_tree().get_nodes_in_group("player")
	if p.size() > 0 and is_instance_valid(p[0]):
		return p[0].global_position
	return Vector2.ZERO

func _draw() -> void:
	# 只绘制视口范围内的深渊古地地砖网格
	var vp = get_viewport_rect().size
	var center = _player_center()
	var margin = Vector2(160, 160)
	var start_x = floor((center.x - vp.x * 0.5 - margin.x) / TILE_SIZE) * TILE_SIZE
	var end_x = ceil((center.x + vp.x * 0.5 + margin.x) / TILE_SIZE) * TILE_SIZE
	var start_y = floor((center.y - vp.y * 0.5 - margin.y) / TILE_SIZE) * TILE_SIZE
	var end_y = ceil((center.y + vp.y * 0.5 + margin.y) / TILE_SIZE) * TILE_SIZE

	var x = start_x
	while x <= end_x:
		draw_line(Vector2(x, start_y), Vector2(x, end_y), Color(0.12, 0.14, 0.2, 0.4), 1.0)
		x += TILE_SIZE

	var y = start_y
	while y <= end_y:
		draw_line(Vector2(start_x, y), Vector2(end_x, y), Color(0.12, 0.14, 0.2, 0.4), 1.0)
		y += TILE_SIZE
