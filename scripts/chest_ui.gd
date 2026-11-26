extends CanvasLayer
class_name ChestUI

signal closed

const TEX_CHEST: Texture2D = preload("res://assets/props/treasure_chest.png")
const INPUT_GRACE_MSEC := 350

var is_showing: bool = false
var _opened_msec: int = 0
var _open_tween: Tween = null

@onready var panel: Panel = $Panel
@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var subtitle_label: Label = $Panel/VBox/SubtitleLabel
@onready var chest_icon: TextureRect = $Panel/VBox/ChestHolder/ChestIcon
@onready var reward_box: HBoxContainer = $Panel/VBox/RewardBox
@onready var confirm_btn: Button = $Panel/VBox/ConfirmHolder/ConfirmButton

func _ready() -> void:
	visible = false
	panel.add_theme_stylebox_override("panel", XianxiaUITheme.make_scroll_panel(XianxiaUITheme.COL_GOLD, 0))
	XianxiaUITheme.attach_ornaments(panel, XianxiaUITheme.COL_GOLD, 16.0, 7.0)

	var title_font = load("res://assets/title_font.tres")
	if title_font != null and title_label != null:
		title_label.add_theme_font_override("font", title_font)
	if title_label != null:
		title_label.add_theme_color_override("font_color", Color(0.76, 0.24, 0.12))
	if subtitle_label != null:
		subtitle_label.add_theme_color_override("font_color", Color(0.14, 0.36, 0.30))
	if chest_icon != null:
		chest_icon.texture = TEX_CHEST

	XianxiaUITheme.style_button(confirm_btn, "cinnabar")
	confirm_btn.focus_mode = Control.FOCUS_NONE
	confirm_btn.pressed.connect(_on_confirm)

func show_rewards(rewards: Array) -> void:
	var shown: Array = []
	for item in rewards:
		if item is Dictionary:
			shown.append(item)
	if shown.is_empty():
		shown.append({
			"is_evo": false,
			"title": "天机余韵",
			"subtitle": "机缘现世 · 灵气入怀",
			"desc": "宝箱灵气已尽数收入囊中，道行又深一分。",
			"icon": "res://assets/props/treasure_chest.png",
		})

	for c in reward_box.get_children():
		reward_box.remove_child(c)
		c.queue_free()

	if _open_tween != null and _open_tween.is_valid():
		_open_tween.kill()

	var is_evo := bool(shown[0].get("is_evo", false))
	if is_evo:
		title_label.text = "天机宝箱 · 法宝蜕变！"
		subtitle_label.text = "天机灵韵加持，法宝威能大盛！"
	elif shown.size() >= 5:
		title_label.text = "天机宝箱 · 五福临门！"
		subtitle_label.text = "鸿运冲天，一举斩获 5 重造化！"
	elif shown.size() >= 3:
		title_label.text = "天机宝箱 · 三星报喜！"
		subtitle_label.text = "灵光大盛，连获 3 重强化！"
	else:
		title_label.text = "天机宝箱 · 机缘现世"
		subtitle_label.text = "斩妖除魔所得奇珍"

	for item in shown:
		var card := _make_reward_card(item, shown.size())
		card.visible = true
		card.modulate = Color.WHITE
		reward_box.add_child(card)

	Sfx.play("chest_open", -2.0)
	visible = true
	is_showing = true
	panel.visible = true
	panel.modulate = Color.WHITE
	reward_box.visible = true
	reward_box.modulate = Color.WHITE
	_opened_msec = Time.get_ticks_msec()
	panel.scale = Vector2(0.86, 0.86)
	panel.pivot_offset = panel.size * 0.5
	_open_tween = create_tween()
	_open_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_open_tween.tween_property(panel, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _make_reward_card(item: Dictionary, total_count: int) -> Control:
	var is_evo: bool = bool(item.get("is_evo", false))
	var card := PanelContainer.new()
	card.clip_contents = true
	var w := 420.0 if is_evo else (155.0 if total_count >= 5 else (230.0 if total_count >= 3 else 360.0))
	card.custom_minimum_size = Vector2(w, 210)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(1.0, 0.96, 0.86, 1.0) if is_evo else Color(0.99, 0.98, 0.94, 1.0)
	st.border_width_left = 2
	st.border_width_top = 2
	st.border_width_right = 2
	st.border_width_bottom = 2
	st.border_color = Color(0.88, 0.34, 0.18, 1.0) if is_evo else Color(0.22, 0.62, 0.54, 0.95)
	st.corner_radius_top_left = 10
	st.corner_radius_top_right = 10
	st.corner_radius_bottom_left = 10
	st.corner_radius_bottom_right = 10
	st.content_margin_left = 12
	st.content_margin_right = 12
	st.content_margin_top = 12
	st.content_margin_bottom = 12
	card.add_theme_stylebox_override("panel", st)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 6)
	card.add_child(vb)

	var icon_path := str(item.get("icon", ""))
	if icon_path != "" and ResourceLoader.exists(icon_path):
		var holder := CenterContainer.new()
		var badge := PanelContainer.new()
		var bst := StyleBoxFlat.new()
		bst.bg_color = Color(0.10, 0.24, 0.22, 0.92)
		bst.border_width_left = 2
		bst.border_width_top = 2
		bst.border_width_right = 2
		bst.border_width_bottom = 2
		bst.border_color = Color(0.94, 0.72, 0.24, 1.0) if is_evo else Color(0.24, 0.72, 0.62, 0.95)
		bst.corner_radius_top_left = 8
		bst.corner_radius_top_right = 8
		bst.corner_radius_bottom_left = 8
		bst.corner_radius_bottom_right = 8
		bst.content_margin_left = 5
		bst.content_margin_right = 5
		bst.content_margin_top = 5
		bst.content_margin_bottom = 5
		badge.add_theme_stylebox_override("panel", bst)
		var tr := TextureRect.new()
		tr.texture = load(icon_path)
		tr.custom_minimum_size = Vector2(48, 48)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		badge.add_child(tr)
		holder.add_child(badge)
		vb.add_child(holder)

	var name_lbl := Label.new()
	name_lbl.text = str(item.get("title", ""))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.custom_minimum_size = Vector2(10, 0)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.add_theme_font_size_override("font_size", 22 if is_evo else 18)
	name_lbl.add_theme_color_override("font_color", Color(0.76, 0.22, 0.12) if is_evo else Color(0.10, 0.24, 0.20))
	vb.add_child(name_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = str(item.get("subtitle", ""))
	sub_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub_lbl.custom_minimum_size = Vector2(10, 0)
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub_lbl.add_theme_font_size_override("font_size", 15)
	sub_lbl.add_theme_color_override("font_color", Color(0.68, 0.44, 0.10))
	vb.add_child(sub_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = str(item.get("desc", ""))
	desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_lbl.custom_minimum_size = Vector2(10, 0)
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 15 if total_count >= 5 else 17)
	desc_lbl.add_theme_color_override("font_color", Color(0.18, 0.28, 0.25))
	vb.add_child(desc_lbl)

	return card

func _input(event: InputEvent) -> void:
	if not is_showing or not visible:
		return
	if not (event is InputEventKey):
		return
	var ke := event as InputEventKey
	if not ke.pressed or ke.echo:
		return
	if Time.get_ticks_msec() - _opened_msec < INPUT_GRACE_MSEC:
		return
	if ke.keycode == KEY_SPACE or ke.keycode == KEY_ENTER or ke.keycode == KEY_KP_ENTER:
		get_viewport().set_input_as_handled()
		_on_confirm()

func _on_confirm() -> void:
	if not is_showing:
		return
	hide_panel()
	emit_signal("closed")

func hide_panel() -> void:
	visible = false
	is_showing = false
