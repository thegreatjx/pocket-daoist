extends Node2D

var _parent_body: CharacterBody2D = null
var _active_elem: String = ""
var _hit_pop_t: float = 0.0
var _anim_t: float = 0.0

func _ready() -> void:
	if get_parent() is CharacterBody2D:
		_parent_body = get_parent() as CharacterBody2D

func set_active_element(elem: String) -> void:
	if _active_elem != elem:
		_active_elem = elem
		queue_redraw()

func trigger_hit_pop() -> void:
	_hit_pop_t = 0.14

func _process(delta: float) -> void:
	_anim_t += delta
	if _hit_pop_t > 0.0:
		_hit_pop_t = maxf(0.0, _hit_pop_t - delta)
	queue_redraw()

func _draw() -> void:
	var ink := Color(0.14, 0.09, 0.05, 1.0)
	var wood_dark := Color(0.46, 0.28, 0.14, 1.0)
	var wood_mid := Color(0.64, 0.42, 0.22, 1.0)
	var wood_hi := Color(0.80, 0.58, 0.34, 1.0)
	var straw := Color(0.86, 0.74, 0.46, 1.0)
	var straw_hi := Color(0.95, 0.86, 0.60, 1.0)

	var pop := sin(_hit_pop_t / 0.14 * PI) if _hit_pop_t > 0.0 else 0.0
	var sc := Vector2(1.0 + 0.14 * pop, 1.0 - 0.12 * pop)
	var rot := 0.08 * pop

	draw_set_transform(Vector2(0.0, 19.0), 0.0, Vector2(1.0, 0.44))
	draw_circle(Vector2.ZERO, 20.0, Color(0.08, 0.18, 0.14, 0.22))
	draw_set_transform(Vector2(0.0, 17.0), 0.0, Vector2(sc.x, sc.y * 0.48))
	draw_circle(Vector2.ZERO, 16.0, Color(0.28, 0.24, 0.20, 0.95))
	draw_arc(Vector2.ZERO, 16.0, 0.0, TAU, 20, ink, 2.2)

	draw_set_transform(Vector2(0.0, 18.0), rot, sc)
	draw_rect(Rect2(-7.0, -56.0, 14.0, 56.0), wood_mid)
	draw_rect(Rect2(-5.0, -55.0, 4.0, 54.0), wood_hi)
	draw_rect(Rect2(2.0, -55.0, 4.0, 54.0), wood_dark)
	draw_rect(Rect2(-7.0, -56.0, 14.0, 56.0), ink, false, 2.0)

	draw_rect(Rect2(-10.0, -61.0, 20.0, 7.0), wood_hi)
	draw_rect(Rect2(-10.0, -61.0, 20.0, 7.0), ink, false, 2.0)

	draw_rect(Rect2(-24.0, -35.0, 48.0, 8.0), wood_mid)
	draw_rect(Rect2(-22.0, -34.0, 44.0, 3.0), wood_hi)
	draw_rect(Rect2(-24.0, -35.0, 48.0, 8.0), ink, false, 2.0)

	draw_rect(Rect2(-13.0, -45.0, 26.0, 26.0), straw)
	draw_rect(Rect2(-11.0, -43.0, 8.0, 22.0), straw_hi)
	draw_rect(Rect2(-13.0, -45.0, 26.0, 26.0), ink, false, 2.0)

	draw_line(Vector2(-13.0, -41.0), Vector2(13.0, -41.0), wood_dark, 2.4)
	draw_line(Vector2(-13.0, -23.0), Vector2(13.0, -23.0), wood_dark, 2.4)
	draw_circle(Vector2(0.0, -32.0), 8.5, Color(0.84, 0.22, 0.18, 1.0))
	draw_circle(Vector2(0.0, -32.0), 5.0, Color(0.98, 0.88, 0.56, 1.0))
	draw_circle(Vector2(0.0, -32.0), 2.2, Color(0.84, 0.22, 0.18, 1.0))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if _parent_body != null and not bool(_parent_body.get("is_dead")):
		var max_hp := maxf(1.0, float(_parent_body.get("max_health")))
		var cur_hp := clampf(float(_parent_body.get("current_health")), 0.0, max_hp)
		var is_inf := int(_parent_body.get("reset_mode")) == 1
		draw_rect(Rect2(-26.0, -54.0, 52.0, 6.0), Color(0.07, 0.10, 0.09, 0.90))
		draw_rect(Rect2(-25.0, -53.0, 50.0 * (cur_hp / max_hp), 4.0), Color(0.26, 0.90, 0.72, 1.0) if is_inf else Color(0.92, 0.68, 0.22, 1.0))
		draw_rect(Rect2(-26.0, -54.0, 52.0, 6.0), Color(0.88, 0.72, 0.32, 0.85), false, 1.0)
		var font := ThemeDB.fallback_font
		if font != null:
			var dps_val := float(_parent_body.get("dps"))
			var tot_val := float(_parent_body.get("total_damage"))
			if tot_val > 0.0 or is_inf:
				var tag := "DPS %.0f · 总 %.0f" % [dps_val, tot_val] if tot_val > 0.0 else "无限木桩"
				draw_string(font, Vector2(-60.0, -60.0) + Vector2(1.0, 1.0), tag, HORIZONTAL_ALIGNMENT_CENTER, 120.0, 11, Color(0.04, 0.08, 0.07, 0.92))
				draw_string(font, Vector2(-60.0, -60.0), tag, HORIZONTAL_ALIGNMENT_CENTER, 120.0, 11, Color(0.98, 0.92, 0.60, 0.98))

		if _parent_body.has_method("is_burning") and _parent_body.is_burning():
			for bi in range(3):
				var bx := (float(bi) - 1.0) * 10.0 + sin(_anim_t * 14.0 + float(bi) * 2.1) * 2.2
				var fh := 24.0 + 6.0 * sin(_anim_t * 18.0 + float(bi) * 1.7)
				var by := 6.0 - fh * 0.65 - absf(sin(_anim_t * 12.0 + float(bi))) * 4.0
				var f_tex := V2VfxFactory.TEX_FLAME_01 if bi != 1 else V2VfxFactory.TEX_FLAME_05
				draw_texture_rect(f_tex, Rect2(bx - 9.0, by - fh * 0.5, 18.0, fh), false, Color(1.0, 0.44 + 0.14 * float(bi % 2), 0.10, 0.72))

	if not _active_elem.is_empty():
		var ec := _elem_color(_active_elem)
		var pip_pos := Vector2(0.0, -34.0)
		draw_circle(pip_pos, 8.0, Color(0.05, 0.08, 0.09, 0.88))
		draw_arc(pip_pos, 8.0, 0.0, TAU, 16, Color(ec.r, ec.g, ec.b, 0.90), 1.4)
		var glyph := V2VfxFactory.elem_glyph_texture(_active_elem)
		if glyph != null:
			draw_texture_rect(glyph, Rect2(pip_pos - Vector2(6.5, 6.5), Vector2(13.0, 13.0)), false, ec)
		else:
			draw_circle(pip_pos, 4.2, ec)

func _elem_color(elem: String) -> Color:
	match elem:
		"fire": return Color(0.98, 0.45, 0.14)
		"ice": return Color(0.24, 0.80, 0.98)
		"water": return Color(0.10, 0.86, 0.92)
		"thunder": return Color(0.62, 0.56, 0.98)
		"wood": return Color(0.22, 0.86, 0.42)
		"venom": return Color(0.14, 0.84, 0.52)
		"metal": return Color(0.98, 0.78, 0.24)
		_: return Color.WHITE
