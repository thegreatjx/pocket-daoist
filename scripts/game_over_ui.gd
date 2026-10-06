extends CanvasLayer
class_name GameOverUI

signal restart_requested

@onready var stats_label: Label = $PanelContainer/VBox/StatsLabel
@onready var restart_btn: Button = $PanelContainer/VBox/RestartButton

func _ready() -> void:
	visible = false
	restart_btn.pressed.connect(_on_restart_pressed)

func _on_restart_pressed() -> void:
	emit_signal("restart_requested")

func show_summary(survive_time: float, level: int, kills: int) -> void:
	var minutes = int(survive_time) / 60
	var seconds = int(survive_time) % 60
	stats_label.text = "修行时长：%02d:%02d\n最终境界：Lv.%d\n诛灭妖魔：%d" % [minutes, seconds, level, kills]
	visible = true
	get_tree().paused = true

func hide_and_unpause() -> void:
	visible = false
	get_tree().paused = false
