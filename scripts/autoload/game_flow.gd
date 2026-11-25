extends Node
# 游戏流程状态机：全项目唯一允许写 get_tree().paused 的模块。
#
# 必要性：标题、暂停菜单、升级选卡、死亡结算都需要冻结游戏。
# 若各界面自行开关 paused，会互相覆盖（例如选卡面板开着时恢复游戏，
# 面板却仍停在屏幕上）。统一由本模块裁决，界面只申请状态变更。
#
# 本模块 process_mode = ALWAYS，因此树暂停后仍能接收 ESC 输入。
# 各界面若自行检测 ESC，暂停后自身已被冻结，按键会无人响应。

enum State { TITLE, PLAYING, PAUSED, UPGRADE, GAME_OVER }

signal state_changed(from_state: int, to_state: int)

const TITLE_SCENE := "res://scenes/title.tscn"
const GAME_SCENE := "res://scenes/main.tscn"
# 启动保护：窗口刚获得焦点时若玩家手上正按着 ESC，会被误判成退出意图
const ESC_GUARD_SECONDS := 0.8

var state: int = State.TITLE
var state_seconds: float = 0.0   # 当前状态已持续时间，用于启动保护
var transition_log: Array = []  # 供测试与调试断言

const EXIT_LOG := "user://exit_log.txt"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 记录退出原因：一闪而过时能直接判断是 ESC、关窗还是崩溃。
	# 注意：Godot 4 的窗口关闭信号是 Window.close_requested（Godot 3 叫 wm_close_request）。
	# 不要调用 set_auto_accept_quit(false)：那会关闭"点 X 自动退出"，
	# 若自身又没接管关窗，游戏将无法用鼠标关闭。
	get_tree().root.close_requested.connect(_on_window_close_requested, CONNECT_ONE_SHOT)

func _on_window_close_requested() -> void:
	log_exit("window_close_button")

func log_exit(reason: String) -> void:
	var f = FileAccess.open(EXIT_LOG, FileAccess.WRITE)
	if f == null:
		return
	f.store_line("reason=%s state=%s uptime=%.1fs transitions=%s" % [
		reason, state_name(), state_seconds, str(transition_log)])
	f.close()

func _process(delta: float) -> void:
	state_seconds += delta

func state_name(s: int = -1) -> String:
	var idx = s if s >= 0 else state
	match idx:
		State.TITLE: return "TITLE"
		State.PLAYING: return "PLAYING"
		State.PAUSED: return "PAUSED"
		State.UPGRADE: return "UPGRADE"
		State.GAME_OVER: return "GAME_OVER"
	return "UNKNOWN"

# ESC 统一入口。用输入事件的 pressed + echo 做边缘检测，
# 比每帧轮询 is_key_pressed 更准确，也天然过滤系统按键重复。
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	if event.keycode != KEY_ESCAPE:
		return
	if not event.pressed or event.echo:
		return
	on_escape()

enum EscapeAction { NONE, QUIT, PAUSE, RESUME }

# ESC 决策：纯函数，无副作用。拆出来是为了可测试 ——
# 若测试直接调 on_escape()，TITLE 态会真的退出进程，把测试套件一起关掉。
func escape_action(current_state: int, seconds_in_state: float) -> int:
	match current_state:
		State.TITLE:
			# 标题界面同样需要启动保护：窗口刚获焦时手上若正按着 ESC，
			# 会被判成退出意图，游戏一闪而过。
			if seconds_in_state < ESC_GUARD_SECONDS:
				return EscapeAction.NONE
			return EscapeAction.QUIT
		State.PLAYING:
			# 启动保护：窗口刚获焦时手上若正按着 ESC，会被误判成退出意图
			if seconds_in_state < ESC_GUARD_SECONDS:
				return EscapeAction.NONE
			return EscapeAction.PAUSE
		State.PAUSED:
			return EscapeAction.RESUME
		State.UPGRADE, State.GAME_OVER:
			# 选卡与结算期间不响应 ESC：防止误触丢进度
			return EscapeAction.NONE
	return EscapeAction.NONE

func on_escape() -> void:
	match escape_action(state, state_seconds):
		EscapeAction.QUIT:
			quit_game("esc_at_" + state_name())
		EscapeAction.PAUSE:
			pause()
		EscapeAction.RESUME:
			resume()

func quit_game(reason: String = "quit_game") -> void:
	log_exit(reason)
	Music.stop_music()
	Sfx.stop_all()
	get_tree().quit()

# ---------- 状态变更 ----------

func _set_state(next: int) -> bool:
	if next == state:
		return false
	var prev = state
	state = next
	state_seconds = 0.0
	# 暂停裁决集中在此处，其它模块一律不得直接写 paused
	get_tree().paused = _state_pauses(next)
	transition_log.append("%s->%s" % [state_name(prev), state_name(next)])
	emit_signal("state_changed", prev, next)
	return true

func _state_pauses(s: int) -> bool:
	return s == State.PAUSED or s == State.UPGRADE or s == State.GAME_OVER

func is_paused_state() -> bool:
	return _state_pauses(state)

# ---------- 对外接口 ----------

func start_game() -> void:
	_enter_run()
	get_tree().change_scene_to_file(GAME_SCENE)

func start_game_packed(packed_scene: PackedScene) -> void:
	if packed_scene == null:
		start_game()
		return
	_enter_run()
	get_tree().change_scene_to_packed(packed_scene)

func restart_run() -> void:
	_enter_run()
	get_tree().reload_current_scene()

func to_title() -> void:
	_enter_title()
	get_tree().change_scene_to_file(TITLE_SCENE)

# 状态迁移与场景切换分离：测试只验证状态迁移，
# 不触发 change_scene / reload_current_scene（那会重载测试场景自身，导致无限循环）。
func _enter_run() -> void:
	# 先解除暂停再切场景：残留的暂停标志会让游戏一进去就是冻结状态
	get_tree().paused = false
	_set_state(State.PLAYING)

func _enter_title() -> void:
	get_tree().paused = false
	_set_state(State.TITLE)

func pause() -> void:
	if state != State.PLAYING:
		return
	_set_state(State.PAUSED)

func resume() -> void:
	if state != State.PAUSED:
		return
	_set_state(State.PLAYING)

# 升级选卡：由 main.gd 在玩家升级时申请
func request_upgrade() -> bool:
	if state != State.PLAYING:
		# 死亡后到达的升级请求必须丢弃，否则会把结算面板顶掉
		return false
	return _set_state(State.UPGRADE)

func finish_upgrade() -> void:
	if state != State.UPGRADE:
		return
	_set_state(State.PLAYING)

func game_over() -> void:
	if state == State.GAME_OVER:
		return
	# 从任意进行中的状态强制进入结算（含选卡中死亡的极端情况）
	_set_state(State.GAME_OVER)

# 场景切换后由 main.gd 校正：防止切场景时残留暂停标志
func sync_after_scene_load(expected: int) -> void:
	if state != expected:
		_set_state(expected)
	get_tree().paused = _state_pauses(state)
