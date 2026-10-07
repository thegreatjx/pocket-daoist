extends CanvasLayer

@onready var hp_bar: ProgressBar = $HUD/HPBar
@onready var exp_bar: ProgressBar = $HUD/ExpBar
@onready var realm_label: Label = $HUD/RealmLabel
@onready var timer_label: Label = $HUD/TimerLabel
@onready var hint_label: Label = $HUD/HintLabel

# 操作提示停留时长，之后淡出，不干扰战斗视野
const HINT_VISIBLE_SECONDS := 9.0
const HINT_FADE_SECONDS := 2.0
# 启动后这段时间内忽略 ESC：窗口刚获得焦点时若玩家手上正按着 ESC，
# 会被判成退出意图，游戏瞬间关闭。
const ESC_GUARD_SECONDS := 1.0

var game_time: float = 0.0
var kill_count_shown: int = 0
var _esc_held_last_frame: bool = false

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

	_handle_escape()

# 边缘检测：本帧是否出现 ESC 的新按下（松手后再按才算一次）
func _consume_escape_edge(held: bool) -> bool:
	var just_pressed = held and not _esc_held_last_frame
	_esc_held_last_frame = held
	return just_pressed

# ESC 退出判定。拆成无副作用的纯函数便于测试：
# 测试若直接触发 quit()，会把整个测试套件一起关掉。
func _should_quit_on_escape(just_pressed: bool, time_now: float, paused: bool) -> bool:
	if not just_pressed:
		return false
	# 启动保护期内忽略：窗口刚获焦时手上若正按着 ESC，会被误判成退出意图
	if time_now < ESC_GUARD_SECONDS:
		return false
	# 升级面板打开时不退出，避免误触丢进度
	if paused:
		return false
	return true

func _handle_escape() -> void:
	var just_pressed = _consume_escape_edge(Input.is_key_pressed(KEY_ESCAPE))
	if _should_quit_on_escape(just_pressed, game_time, get_tree().paused):
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
