extends CanvasLayer

@onready var hp_bar: ProgressBar = $HUD/HPBar
@onready var exp_bar: ProgressBar = $HUD/ExpBar
@onready var realm_label: Label = $HUD/RealmLabel
@onready var timer_label: Label = $HUD/TimerLabel
@onready var hint_label: Label = $HUD/HintLabel
@onready var kill_label: Label = $HUD/KillLabel

# 操作提示停留时长，之后淡出，不干扰战斗视野
const HINT_VISIBLE_SECONDS := 9.0
const HINT_FADE_SECONDS := 2.0

var game_time: float = 0.0
var kill_count_shown: int = -1

func _ready() -> void:
	# ESC 已由 GameFlow 统一处理（本节点在树暂停时会被冻结，无法自行响应按键）。
	# 这里只负责计时、状态显示与提示淡出。
	_setup_hint()

func _setup_hint() -> void:
	if hint_label == null:
		return
	if not Settings.get_bool("ui/hint_enabled"):
		hint_label.visible = false
		return
	var t = create_tween()
	t.tween_interval(HINT_VISIBLE_SECONDS)
	t.tween_property(hint_label, "modulate:a", 0.0, HINT_FADE_SECONDS)

func _process(delta: float) -> void:
	game_time += delta
	var minutes = int(game_time) / 60
	var seconds = int(game_time) % 60
	timer_label.text = "%02d:%02d" % [minutes, seconds]
	_update_kill_count()

func _update_kill_count() -> void:
	if kill_label == null:
		return
	# 向 game_manager 拉取击杀数，变化时才更新文本，避免每帧重排 Label
	var mgrs = get_tree().get_nodes_in_group("game_manager")
	if mgrs.size() == 0:
		return
	var kills = mgrs[0].kill_count
	if kills != kill_count_shown:
		kill_count_shown = kills
		kill_label.text = "诛魔 %d" % kills

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
