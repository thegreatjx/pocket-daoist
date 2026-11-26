extends Node

## 单实例守卫：同一台机器同时只允许一个游戏进程。
## 用回环 TCP 端口当锁；后启动的实例会请求已有实例把窗口提到前面，然后自行退出。
## 测试脚本、headless 运行和显式 --allow-multi-instance 不参与占锁，避免打断自动化。
const LOCK_PORT_BASE := 27100
const LOCK_PORT_SPAN := 800
const FLAG_ALLOW_MULTI := "--allow-multi-instance"
const FOCUS_REQUEST := "focus\n"

var _server: TCPServer = null
var _clients: Array[StreamPeerTCP] = []


func _ready() -> void:
	if not _should_enforce():
		return
	var port := _lock_port()
	_server = TCPServer.new()
	if _server.listen(port, "127.0.0.1") == OK:
		return
	_release_server()
	_request_focus(port)
	get_tree().quit()


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


func _lock_port() -> int:
	var project := str(ProjectSettings.get_setting("application/config/name", "godot"))
	return LOCK_PORT_BASE + absi(project.hash()) % LOCK_PORT_SPAN


func _request_focus(port: int) -> void:
	var peer := StreamPeerTCP.new()
	if peer.connect_to_host("127.0.0.1", port) != OK:
		return
	peer.put_data(FOCUS_REQUEST.to_utf8_buffer())


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
		var text := peer.get_utf8_string(available)
		_clients.remove_at(i)
		if text.contains("focus"):
			_raise_window()


func _raise_window() -> void:
	var win := get_window()
	if win == null:
		return
	win.grab_focus()
	DisplayServer.window_move_to_foreground()


func _release_server() -> void:
	if _server != null:
		_server.stop()
		_server = null


func _exit_tree() -> void:
	_release_server()
