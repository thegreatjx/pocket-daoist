extends CanvasLayer
class_name GameOverUI

signal restart_requested
signal title_requested

@onready var stats_label: Label = $PanelContainer/VBox/StatsLabel
@onready var record_label: Label = $PanelContainer/VBox/RecordLabel
@onready var best_label: Label = $PanelContainer/VBox/BestLabel
@onready var restart_btn: Button = $PanelContainer/VBox/RestartButton
@onready var title_btn: Button = $PanelContainer/VBox/TitleButton

func _ready() -> void:
	visible = false
	restart_btn.pressed.connect(func(): emit_signal("restart_requested"))
	title_btn.pressed.connect(func(): emit_signal("title_requested"))

# 暂停由 GameFlow.game_over() 统一施加，本面板只呈现数据。
# is_record 由 Stats.record_run() 返回：必须在写入战绩前判定，
# 事后比较历史最佳会恒等，无法区分是否刷新纪录。
func show_summary(survive_time: float, level: int, kills: int, is_record: bool = false) -> void:
	stats_label.text = "修行时长：%s\n最终境界：Lv.%d\n诛灭妖魔：%d" % [Stats.format_time(survive_time), level, kills]
	record_label.visible = is_record
	best_label.text = Stats.summary_text()
	best_label.visible = best_label.text != ""
	visible = true

func hide_panel() -> void:
	visible = false
