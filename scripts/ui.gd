extends CanvasLayer

@onready var hp_bar: ProgressBar = $HUD/HPBar
@onready var exp_bar: ProgressBar = $HUD/ExpBar
@onready var realm_label: Label = $HUD/RealmLabel
@onready var timer_label: Label = $HUD/TimerLabel

var game_time: float = 0.0

func _process(delta: float) -> void:
	game_time += delta
	var minutes = int(game_time) / 60
	var seconds = int(game_time) % 60
	timer_label.text = "%02d:%02d" % [minutes, seconds]

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
