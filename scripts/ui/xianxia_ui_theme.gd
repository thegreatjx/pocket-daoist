class_name XianxiaUITheme
extends RefCounted

const COL_PLATE_BG := Color(0.07, 0.16, 0.14, 0.90)
const COL_PLATE_DARK := Color(0.05, 0.12, 0.11, 0.95)
const COL_GOLD := Color(0.88, 0.70, 0.30, 0.96)
const COL_GOLD_SOFT := Color(0.78, 0.62, 0.28, 0.55)
const COL_GOLD_BRIGHT := Color(0.99, 0.86, 0.48, 1.0)
const COL_JADE := Color(0.20, 0.56, 0.48, 0.96)
const COL_PAPER := Color(0.96, 0.93, 0.85, 0.98)
const COL_PAPER_CARD := Color(0.99, 0.97, 0.91, 1.0)
const COL_INK := Color(0.10, 0.22, 0.19, 1.0)
const COL_INK_MUTED := Color(0.28, 0.38, 0.34, 1.0)
const COL_CINNABAR := Color(0.74, 0.20, 0.14, 1.0)
const COL_HP_FILL := Color(0.84, 0.19, 0.17, 1.0)
const COL_HP_TRAIL := Color(0.96, 0.84, 0.56, 0.92)
const COL_EXP_FILL := Color(0.18, 0.76, 0.58, 1.0)
const COL_WARM_TEXT := Color(1.0, 0.95, 0.82, 1.0)
const COL_OUTLINE := Color(0.04, 0.10, 0.08, 0.96)

static func make_hud_plate(bg: Color = COL_PLATE_BG, border: Color = COL_GOLD, radius: int = 8, pad: int = 8) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = bg
	st.border_color = border
	st.set_border_width_all(2)
	st.set_corner_radius_all(radius)
	st.set_content_margin_all(pad)
	st.shadow_color = Color(0.02, 0.06, 0.05, 0.42)
	st.shadow_size = 8
	st.shadow_offset = Vector2(0, 3)
	return st

static func make_scroll_panel(border: Color = COL_GOLD, pad: int = 20) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = COL_PAPER
	st.border_color = border
	st.set_border_width_all(3)
	st.set_corner_radius_all(12)
	st.set_content_margin_all(pad)
	st.shadow_color = Color(0.03, 0.09, 0.08, 0.44)
	st.shadow_size = 20
	st.shadow_offset = Vector2(0, 6)
	return st

static func make_card_style(bg: Color, border: Color, border_w: int = 2, radius: int = 10, pad: int = 10) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = bg
	st.border_color = border
	st.set_border_width_all(border_w)
	st.set_corner_radius_all(radius)
	st.set_content_margin_all(pad)
	st.shadow_color = Color(0.05, 0.14, 0.12, 0.16)
	st.shadow_size = 6
	st.shadow_offset = Vector2(0, 3)
	return st

static func style_button(btn: Button, variant: String = "primary") -> void:
	if btn == null:
		return
	var bg := Color(0.11, 0.37, 0.31, 0.96)
	var border := COL_GOLD
	var font_col := Color(1.0, 0.96, 0.85)
	var hover_font := Color(1.0, 0.99, 0.92)
	match variant:
		"cinnabar":
			bg = Color(0.68, 0.21, 0.14, 0.98)
			border = COL_GOLD_BRIGHT
			font_col = Color(1.0, 0.96, 0.86)
		"secondary":
			bg = COL_PAPER_CARD
			border = COL_JADE
			font_col = COL_INK
			hover_font = Color(0.06, 0.18, 0.15)
		"dark_gold":
			bg = Color(0.09, 0.24, 0.21, 0.94)
			border = COL_GOLD
			font_col = COL_WARM_TEXT
	var normal := StyleBoxFlat.new()
	normal.bg_color = bg
	normal.border_color = border
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(8)
	normal.shadow_color = Color(0.03, 0.09, 0.08, 0.28)
	normal.shadow_size = 5
	normal.shadow_offset = Vector2(0, 2)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.93, 0.95, 0.88, 1.0) if variant == "secondary" else bg.lightened(0.14)
	hover.border_color = COL_GOLD_BRIGHT

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = bg.darkened(0.12)
	pressed.shadow_offset = Vector2(0, 1)

	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(bg.r * 0.55 + 0.14, bg.g * 0.55 + 0.14, bg.b * 0.55 + 0.14, 0.65)
	disabled.border_color = Color(border.r, border.g, border.b, 0.35)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("focus", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_color", font_col)
	btn.add_theme_color_override("font_hover_color", hover_font)
	btn.add_theme_color_override("font_pressed_color", font_col)
	btn.add_theme_color_override("font_disabled_color", Color(font_col.r, font_col.g, font_col.b, 0.45))

static func style_progress_bar(bar: ProgressBar, bg_color: Color, fill_color: Color, border_color: Color = COL_GOLD, radius: int = 4) -> void:
	if bar == null:
		return
	var bg := StyleBoxFlat.new()
	bg.bg_color = bg_color
	bg.border_color = border_color
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(radius)
	bar.add_theme_stylebox_override("background", bg)

	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(maxi(1, radius - 1))
	bar.add_theme_stylebox_override("fill", fill)

static func apply_text_outline(lbl: Label, size: int = 4, col: Color = COL_OUTLINE) -> void:
	if lbl == null:
		return
	lbl.add_theme_color_override("font_outline_color", col)
	lbl.add_theme_constant_override("outline_size", size)

static func attach_ornaments(parent: Control, col: Color = COL_GOLD, arm: float = 12.0, inset: float = 5.0) -> void:
	if parent == null:
		return
	var existing := parent.get_node_or_null("XianxiaOrnaments")
	if existing != null:
		existing.queue_free()
	var orn := CornerOrnament.new()
	orn.name = "XianxiaOrnaments"
	orn.accent_color = col
	orn.arm_length = arm
	orn.inset = inset
	orn.clip_contents = false
	orn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	orn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	orn.z_index = 2
	parent.add_child(orn)

class CornerOrnament extends Control:
	var accent_color: Color = COL_GOLD
	var arm_length: float = 12.0
	var inset: float = 5.0

	func _ready() -> void:
		var p := get_parent() as Control
		if p != null and not p.resized.is_connected(queue_redraw):
			p.resized.connect(queue_redraw)

	func _draw() -> void:
		var p := get_parent() as Control
		var origin := -position if p != null else Vector2.ZERO
		var sz := p.size if p != null else size
		if sz.x < inset * 2.0 + 16.0 or sz.y < inset * 2.0 + 16.0:
			return
		var l := origin.x + inset
		var t := origin.y + inset
		var r := origin.x + sz.x - inset
		var b := origin.y + sz.y - inset
		var inner_col := Color(accent_color.r, accent_color.g, accent_color.b, accent_color.a * 0.42)
		draw_rect(Rect2(l, t, r - l, b - t), inner_col, false, 1.0)

		var a := minf(arm_length, minf((r - l) * 0.28, (b - t) * 0.28))
		var step := maxf(3.0, a * 0.38)
		_draw_fret_corner(Vector2(l, t), Vector2(1.0, 1.0), a, step)
		_draw_fret_corner(Vector2(r, t), Vector2(-1.0, 1.0), a, step)
		_draw_fret_corner(Vector2(l, b), Vector2(1.0, -1.0), a, step)
		_draw_fret_corner(Vector2(r, b), Vector2(-1.0, -1.0), a, step)

	func _draw_fret_corner(p: Vector2, dir: Vector2, a: float, step: float) -> void:
		var pts := PackedVector2Array([
			p + Vector2(dir.x * a, 0.0),
			p,
			p + Vector2(0.0, dir.y * a),
		])
		draw_polyline(pts, accent_color, 2.0, true)
		var inner := p + Vector2(dir.x * step, dir.y * step)
		var hook := PackedVector2Array([
			p + Vector2(dir.x * a, dir.y * step),
			inner,
			p + Vector2(dir.x * step, dir.y * a),
		])
		draw_polyline(hook, Color(accent_color.r, accent_color.g, accent_color.b, accent_color.a * 0.72), 1.3, true)
