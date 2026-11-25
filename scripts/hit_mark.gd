extends Node2D
class_name HitMark

var _age := 0.0
var _life := 0.09
var _color := Color(1.0, 0.95, 0.82, 1.0)
var _heavy := false
var _kill := false

func pool_acquire() -> void:
	_age = 0.0
	visible = true
	modulate = Color.WHITE
	scale = Vector2.ONE
	set_process(true)
	queue_redraw()

func setup(dir: Vector2, col: Color, heavy: bool, kill: bool) -> void:
	_color = col
	_heavy = heavy
	_kill = kill
	_life = 0.13 if kill else (0.10 if heavy else 0.09)
	rotation = dir.angle() + randf_range(-0.28, 0.28) if dir.length_squared() > 0.001 else randf() * TAU
	queue_redraw()

func _process(delta: float) -> void:
	_age += delta
	if _age >= _life:
		set_process(false)
		visible = false
		call_deferred("_release")
		return
	queue_redraw()

func _release() -> void:
	ObjectPools.release(self)

func _draw() -> void:
	var t := clampf(_age / _life, 0.0, 1.0)
	var fade := pow(1.0 - t, 1.5)
	var grow := 0.62 + 0.38 * (1.0 - pow(1.0 - t, 3.0))
	var size_m := (1.6 if _kill else (1.2 if _heavy else 1.0)) * grow
	var long := 27.0 * size_m
	var short := 8.5 * size_m

	var horizontal := _diamond(long, short)
	var vertical := _diamond(short * 0.78, long * 0.86)
	var ink := Color(0.03, 0.04, 0.06, 0.72 * fade)
	var edge := Color(_color.r * 0.55, _color.g * 0.55, _color.b * 0.55, 0.92 * fade)
	var core := Color(_color.r, _color.g, _color.b, 0.94 * fade)
	var white := Color(1.0, 0.99, 0.92, 0.96 * fade)

	var ink_offset := Vector2(1.6, 1.8)
	draw_colored_polygon(_offset_poly(horizontal, ink_offset, 1.14), ink)
	draw_colored_polygon(_offset_poly(vertical, ink_offset, 1.14), ink)
	draw_colored_polygon(horizontal, edge)
	draw_colored_polygon(vertical, edge)
	draw_colored_polygon(_scaled_poly(horizontal, 0.72), core)
	draw_colored_polygon(_scaled_poly(vertical, 0.72), core)
	draw_colored_polygon(_scaled_poly(horizontal, 0.34), white)
	draw_colored_polygon(_scaled_poly(vertical, 0.34), white)

	var streak := long * 0.95
	draw_line(Vector2(-streak, 0.0), Vector2(streak, 0.0), Color(white.r, white.g, white.b, 0.85 * fade), 2.4 * size_m)
	draw_line(Vector2(-long * 1.25, 0.0), Vector2(long * 1.25, 0.0), Color(edge.r, edge.g, edge.b, 0.40 * fade), 1.1 * size_m)
	draw_line(Vector2(0.0, -long * 1.15), Vector2(0.0, long * 1.15), Color(white.r, white.g, white.b, 0.55 * fade), 1.4 * size_m)

	var ring_r := long * (0.55 + 0.85 * t)
	draw_arc(Vector2.ZERO, ring_r, 0.0, TAU, 28, Color(edge.r, edge.g, edge.b, 0.55 * fade), 2.0 * size_m)
	if _kill:
		draw_arc(Vector2.ZERO, ring_r * 1.45, 0.0, TAU, 32, Color(white.r, white.g, white.b, 0.28 * fade), 1.2 * size_m)

func _diamond(w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(w, 0.0),
		Vector2(0.0, h),
		Vector2(-w, 0.0),
		Vector2(0.0, -h),
	])

func _offset_poly(src: PackedVector2Array, offset: Vector2, factor: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in src:
		out.append(p * factor + offset)
	return out

func _scaled_poly(src: PackedVector2Array, factor: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in src:
		out.append(p * factor)
	return out
