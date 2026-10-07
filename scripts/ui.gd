extends CanvasLayer

@onready var hp_bar: ProgressBar = $HUD/HPBar
@onready var exp_bar: ProgressBar = $HUD/ExpBar
@onready var realm_label: Label = $HUD/RealmLabel
@onready var timer_label: Label = $HUD/TimerLabel
@onready var hint_label: Label = $HUD/HintLabel

# 操作提示停留时长，之后淡出，不干扰战斗视野
const HINT_VISIBLE_SECONDS := 9.0
const HINT_FADE_SECONDS := 2.0

var game_time: float = 0.0
var kill_count_shown: int = 0

func _ready() -> void:
	_schedule_hint_fade()

func _schedule_hint_fade() -> void:
	if hint_label == null:
		return
	var t = create_tween()
	t.tween_interval(HINT_VISIBLE_SECONDS)
	t.tween_property(hint_label, "modulate:a", 0.0, HINT_FADE_SECONDS)

func _process(delta: float) -> void:
	game_time += delta
	var minutes = int(game_time) / 60
	var seconds = int(game_time) % 60
	timer_label.text = "%02d:%02d" % [minutes, seconds]

	# ESC 退出：窗口模式下的常规预期操作
	if Input.is_key_pressed(KEY_ESCAPE):
		# 升级面板打开时 ESC 不做退出，避免误触丢进度
		if not get_tree().paused:
			Sfx.stop_all()
			get_tree().quit()

func update_health(curr: float, max_h: float) -> void:
	hp_bar.max_value = max_h
	hp_bar.value = curr

func update_exp(curr: float, max_e: float, level: int) -> void:
	exp_bar.max_value = max_e
	exp_bar.value = curr
	var realms = [
		"炼气前期", "炼气中期", "炼气后期",
		"筑基前期", "筑基中期", "筑基后期",
		"金丹前期", "金丹中期", "金丹后期",
		"元婴大能"
	]
	var idx = clamp(level - 1, 0, realms.size() - 1)
	realm_label.text = "【境界】%s (Lv.%d)" % [realms[idx], level]
