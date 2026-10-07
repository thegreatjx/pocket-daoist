extends CanvasLayer
class_name GameOverUI

signal restart_requested
signal title_requested

@onready var title_label: Label = $PanelContainer/VBox/TitleLabel
@onready var stats_label: Label = $PanelContainer/VBox/StatsLabel
@onready var record_label: Label = $PanelContainer/VBox/RecordLabel
@onready var best_label: Label = $PanelContainer/VBox/BestLabel
@onready var restart_btn: Button = $PanelContainer/VBox/RestartButton
@onready var title_btn: Button = $PanelContainer/VBox/TitleButton

func _ready() -> void:
	visible = false
	restart_btn.pressed.connect(func(): emit_signal("restart_requested"))
	title_btn.pressed.connect(func(): emit_signal("title_requested"))

func show_summary(survive_time: float, level: int, kills: int, is_record: bool = false) -> void:
	if title_label != null:
		title_label.text = "身死道消"
		title_label.modulate = Color.WHITE
	_render_data(survive_time, level, kills, is_record)

func show_victory(survive_time: float, level: int, kills: int, is_record: bool = false) -> void:
	if title_label != null:
		title_label.text = "✦ 斩妖证道·大捷 ✦"
		title_label.modulate = Color(1.0, 0.88, 0.25, 1.0)
	_render_data(survive_time, level, kills, is_record)

func _render_data(survive_time: float, level: int, kills: int, is_record: bool = false) -> void:
	stats_label.text = "修行时长：%s\n最终境界：Lv.%d\n诛灭妖魔：%d" % [Stats.format_time(survive_time), level, kills]
	record_label.visible = is_record
	best_label.text = Stats.summary_text()
	best_label.visible = best_label.text != ""
	visible = true

func hide_panel() -> void:
	visible = false
