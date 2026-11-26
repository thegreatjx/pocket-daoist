extends Node

## 单实例守卫：同一台机器同时只允许一个游戏进程。
## 锁文件记录持有者 PID、回环端口与一次性令牌；后启动的实例连上去握手，
## 令牌对得上才算「已有实例在跑」——那样就把它的窗口提到前面，自己退出。
## 令牌对不上或连不上就当锁已失效，直接接管，避免僵尸锁把用户挡在门外。
## 测试脚本、headless 运行和显式 --allow-multi-instance 不参与占锁。
const LOCK_PATH := "user://single_instance.json"
const PORT_BASE := 27100
const PORT_CANDIDATES := 32
const FLAG_ALLOW_MULTI := "--allow-multi-instance"
const HANDSHAKE_MS := 300

var _server: TCPServer = null
var _port: int = 0
var _token: String = ""
var _clients: Array[StreamPeerTCP] = []


func _ready() -> void:
	if not _should_enforce():
		return
	var existing := _read_lock()
	if not existing.is_empty() and _probe_existing(existing):
		_ask_focus(existing)
		get_tree().quit()
		return
	_acquire_lock()


func _should_enforce() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	var args := OS.get_cmdline_args()
	if args.has(FLAG_ALLOW_MULTI) or args.has("-s") or args.has("--script"):
		return false
	for arg in args:
		if arg.begins_with("res://tests/"):
			return false
	return true


func _read_lock() -> Dictionary:
	if not FileAccess.file_exists(LOCK_PATH):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(LOCK_PATH))
	if not parsed is Dictionary:
		return {}
	var data: Dictionary = parsed
	if int(data.get("port", 0)) <= 0 or String(data.get("token", "")).is_empty():
		return {}
	return data


func _write_lock() -> void:
	var file := FileAccess.open(LOCK_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"pid": OS.get_process_id(),
		"port": _port,
		"token": _token,
		"started": Time.get_unix_time_from_system(),
	}))
	file.close()


func _acquire_lock() -> void:
	_token = "%d-%d" % [OS.get_process_id(), randi()]
	for offset in range(PORT_CANDIDATES):
		var candidate := PORT_BASE + offset
		var server := TCPServer.new()
		if server.listen(candidate, "127.0.0.1") != OK:
			continue
		_server = server
		_port = candidate
		_write_lock()
		# 两个进程同时抢锁时以文件里最后一个写入者为准，落败方自行退出
		if String(_read_lock().get("token", "")) != _token:
			_release_lock()
			get_tree().quit()
		return
	push_warning("single_instance: 无可用锁端口，本次不启用单实例限制")


func _probe_existing(lock: Dictionary) -> bool:
	var reply := _handshake(int(lock["port"]), "ping")
	return not reply.is_empty() and reply == String(lock.get("token", ""))


func _ask_focus(lock: Dictionary) -> void:
	_handshake(int(lock.get("port", 0)), "focus")


func _handshake(port: int, message: String) -> String:
	var peer := StreamPeerTCP.new()
	if peer.connect_to_host("127.0.0.1", port) != OK:
		return ""
	var deadline := Time.get_ticks_msec() + HANDSHAKE_MS
	while Time.get_ticks_msec() < deadline:
		peer.poll()
		if peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			break
		if peer.get_status() == StreamPeerTCP.STATUS_ERROR:
			return ""
		OS.delay_msec(5)
	peer.put_data((message + "\n").to_utf8_buffer())
	deadline = Time.get_ticks_msec() + HANDSHAKE_MS
	while Time.get_ticks_msec() < deadline:
		peer.poll()
		if peer.get_available_bytes() > 0:
			return peer.get_utf8_string(peer.get_available_bytes()).strip_edges()
		if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			return ""
		OS.delay_msec(5)
	return ""


func _process(_delta: float) -> void:
	if _server == null:
		return
	while _server.is_connection_available():
		var peer := _server.take_connection()
		if peer != null:
			_clients.append(peer)
	for i in range(_clients.size() - 1, -1, -1):
		var peer: StreamPeerTCP = _clients[i]
		peer.poll()
		if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			_clients.remove_at(i)
			continue
		var available := peer.get_available_bytes()
		if available <= 0:
			continue
		var text := peer.get_utf8_string(available).strip_edges()
		peer.put_data((_token + "\n").to_utf8_buffer())
		_clients.remove_at(i)
		if text == "focus":
			_raise_window()


func _raise_window() -> void:
	var win := get_window()
	if win == null:
		return
	win.grab_focus()
	DisplayServer.window_move_to_foreground()


func _release_lock() -> void:
	if _server != null:
		_server.stop()
		_server = null
	if not FileAccess.file_exists(LOCK_PATH):
		return
	if String(_read_lock().get("token", "")) == _token:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(LOCK_PATH))


func _exit_tree() -> void:
	_release_lock()
