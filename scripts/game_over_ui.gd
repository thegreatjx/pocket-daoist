extends CanvasLayer
class_name GameOverUI

signal restart_requested
signal title_requested
signal next_stage_requested
signal endless_requested

@onready var panel_box: PanelContainer = $PanelContainer
@onready var title_label: Label = $PanelContainer/VBox/TitleLabel
@onready var stats_label: Label = $PanelContainer/VBox/StatsLabel
@onready var record_label: Label = $PanelContainer/VBox/RecordLabel
@onready var best_label: Label = $PanelContainer/VBox/BestLabel
@onready var restart_btn: Button = $PanelContainer/VBox/RestartButton
@onready var title_btn: Button = $PanelContainer/VBox/TitleButton
@onready var ending_art: TextureRect = $EndingArt
@onready var dim: ColorRect = $Dim

var _victory_row: HBoxContainer = null
var _next_stage_btn: Button = null
var _endless_btn: Button = null

func _ready() -> void:
	visible = false
	ending_art.visible = false
	_build_victory_actions()
	_apply_qinglv_theme()
	restart_btn.pressed.connect(func(): emit_signal("restart_requested"))
	title_btn.pressed.connect(func(): emit_signal("title_requested"))

func _build_victory_actions() -> void:
	var vbox := $PanelContainer/VBox as VBoxContainer
	if vbox == null:
		return
	vbox.add_theme_constant_override("separation", 14)

	_victory_row = HBoxContainer.new()
	_victory_row.name = "VictoryActions"
	_victory_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_victory_row.add_theme_constant_override("separation", 14)
	_victory_row.visible = false

	_next_stage_btn = Button.new()
	_next_stage_btn.text = "前往下一秘境"
	_next_stage_btn.custom_minimum_size = Vector2(200, 48)
	_next_stage_btn.add_theme_font_size_override("font_size", 22)
	_next_stage_btn.pressed.connect(func(): emit_signal("next_stage_requested"))
	_victory_row.add_child(_next_stage_btn)

	_endless_btn = Button.new()
	_endless_btn.text = "继续无尽试炼"
	_endless_btn.custom_minimum_size = Vector2(200, 48)
	_endless_btn.add_theme_font_size_override("font_size", 22)
	_endless_btn.pressed.connect(func(): emit_signal("endless_requested"))
	_victory_row.add_child(_endless_btn)

	vbox.add_child(_victory_row)
	vbox.move_child(_victory_row, restart_btn.get_index())

func _apply_qinglv_theme() -> void:
	if panel_box != null:
		panel_box.add_theme_stylebox_override("panel", XianxiaUITheme.make_scroll_panel(XianxiaUITheme.COL_GOLD, 28))
		XianxiaUITheme.attach_ornaments(panel_box, XianxiaUITheme.COL_GOLD, 14.0, 6.0)
	if title_label != null:
		var title_font = load("res://assets/title_font.tres")
		if title_font != null:
			title_label.add_theme_font_override("font", title_font)
		title_label.add_theme_color_override("font_color", XianxiaUITheme.COL_INK)
	if stats_label != null:
		stats_label.add_theme_color_override("font_color", Color(0.14, 0.26, 0.22))
	if record_label != null:
		record_label.add_theme_color_override("font_color", Color(0.76, 0.28, 0.12))
	if best_label != null:
		best_label.modulate = Color.WHITE
		best_label.add_theme_color_override("font_color", Color(0.26, 0.40, 0.36))
	XianxiaUITheme.style_button(restart_btn, "cinnabar")
	XianxiaUITheme.style_button(title_btn, "secondary")
	XianxiaUITheme.style_button(_next_stage_btn, "primary")
	XianxiaUITheme.style_button(_endless_btn, "primary")

func show_summary(survive_time: float, level: int, kills: int, is_record: bool = false, stones_earned: int = 0) -> void:
	if title_label != null:
		title_label.text = "此局暂歇"
		title_label.modulate = Color.WHITE
		title_label.add_theme_color_override("font_color", Color(0.16, 0.32, 0.28))
	ending_art.visible = false
	dim.color = Color(0.05, 0.14, 0.12, 0.56)
	if _victory_row != null:
		_victory_row.visible = false
	_render_data(survive_time, level, kills, is_record, stones_earned)

func show_victory(survive_time: float, level: int, kills: int, is_record: bool = false, stones_earned: int = 0, has_next_stage: bool = false) -> void:
	if title_label != null:
		title_label.text = "✦ 秘境荡平 · 证道大捷 ✦"
		title_label.modulate = Color.WHITE
		title_label.add_theme_color_override("font_color", Color(0.76, 0.28, 0.12))
	ending_art.visible = true
	dim.color = Color(0.06, 0.16, 0.14, 0.30)
	if _victory_row != null:
		_victory_row.visible = true
		if _next_stage_btn != null:
			_next_stage_btn.visible = has_next_stage
	_render_data(survive_time, level, kills, is_record, stones_earned)

func _render_data(survive_time: float, level: int, kills: int, is_record: bool = false, stones_earned: int = 0) -> void:
	var txt := "修行时长：%s\n最终境界：Lv.%d\n诛灭妖魔：%d" % [Stats.format_time(survive_time), level, kills]
	if stones_earned > 0:
		txt += "\n获得灵石：+%d（总计 %d）" % [stones_earned, Stats.spirit_stones]
	stats_label.text = txt
	record_label.visible = is_record
	best_label.text = Stats.summary_text()
	best_label.visible = best_label.text != ""
	visible = true

func hide_panel() -> void:
	visible = false
