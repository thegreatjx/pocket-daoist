extends Node2D

var _enemy: Node = null
var _t: float = 0.0

func setup(enemy: Node) -> void:
	_enemy = enemy
	z_index = -1
	position = Vector2(0.0, 14.0)
	_t = 0.0
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	queue_redraw()

func _process(delta: float) -> void:
	_t += delta
	if _enemy == null or not is_instance_valid(_enemy) or float(_enemy.get("_freeze_timer")) <= 0.0:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_t * 8.0)
	draw_set_transform(Vector2(0.0, 8.0), 0.0, Vector2(1.0, 0.42))
	draw_circle(Vector2.ZERO, 26.0, Color(0.34, 0.86, 1.0, 0.14 + 0.10 * pulse))
	draw_arc(Vector2.ZERO, 24.0, 0.0, TAU, 32, Color(0.62, 0.96, 1.0, 0.55 + 0.30 * pulse), 2.4)
	draw_arc(Vector2.ZERO, 16.0, _t * 1.2, _t * 1.2 + TAU * 0.72, 24, Color(1.0, 0.88, 0.45, 0.60), 1.8)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_rect(Rect2(-14.0, -54.0, 28.0, 62.0), Color(0.40, 0.88, 1.0, 0.07 + 0.05 * pulse))
	var cage := PackedVector2Array([
		Vector2(0.0, -48.0),
		Vector2(27.0, -26.0),
		Vector2(22.0, 2.0),
		Vector2(0.0, 15.0),
		Vector2(-22.0, 2.0),
		Vector2(-27.0, -26.0),
		Vector2(0.0, -48.0),
	])
	draw_polyline(cage, Color(0.58, 0.95, 1.0, 0.35 + 0.30 * pulse), 2.0)
	for i in range(4):
		var ang := _t * 1.5 + float(i) * TAU / 4.0
		var c := Vector2(cos(ang) * 20.0, sin(ang) * 6.0 - 18.0)
		var s := 6.5 + 2.0 * sin(_t * 6.0 + float(i))
		var pts := PackedVector2Array([
			c + Vector2(0.0, -s * 1.3),
			c + Vector2(s * 0.5, 0.0),
			c + Vector2(0.0, s * 1.3),
			c + Vector2(-s * 0.5, 0.0),
		])
		draw_colored_polygon(pts, Color(0.72, 0.96, 1.0, 0.65))
		var outline := PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]])
		draw_polyline(outline, Color(0.58, 0.94, 1.0, 0.90), 1.2)
	draw_line(Vector2(0.0, -54.0), Vector2(0.0, -36.0), Color(1.0, 0.9, 0.5, 0.55 + 0.35 * pulse), 2.0)
