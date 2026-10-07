extends Control
# 标题界面：入口、设置、退出、历史战绩。
# 场景切换由 GameFlow 负责，本脚本只发起请求。

@onready var best_label: Label = $Center/VBox/BestLabel
@onready var start_btn: Button = $Center/VBox/StartButton
@onready var settings_btn: Button = $Center/VBox/SettingsButton
@onready var quit_btn: Button = $Center/VBox/QuitButton

var settings_panel: SettingsPanel = null

func _ready() -> void:
	# 校正状态：从其它场景切回标题时，可能残留 PLAYING 状态与暂停标志
	GameFlow.sync_after_scene_load(GameFlow.State.TITLE)
	Music.play_track("title")
	_refresh_best()
	start_btn.pressed.connect(_on_start_pressed)
	settings_btn.pressed.connect(_on_settings_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)

func _refresh_best() -> void:
	best_label.text = Stats.summary_text()
	best_label.visible = Stats.has_history()

func _on_start_pressed() -> void:
	_close_settings()
	Music.play_track("battle")
	GameFlow.start_game()

func _on_quit_pressed() -> void:
	GameFlow.quit_game()

func _on_settings_pressed() -> void:
	if settings_panel != null and is_instance_valid(settings_panel):
		_close_settings()
		return
	settings_panel = SettingsPanel.new()
	settings_panel.closed.connect(_close_settings)
	$SettingsLayer.add_child(settings_panel)
	settings_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)

func _close_settings() -> void:
	if settings_panel != null and is_instance_valid(settings_panel):
		settings_panel.queue_free()
	settings_panel = null
