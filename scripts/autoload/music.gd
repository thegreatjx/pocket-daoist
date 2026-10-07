extends Node
# 背景音乐：单播放器循环。音量由 Settings 的 Music 总线统一控制，
# 本模块只负责选曲、播放、停止与淡入淡出。

const TRACKS := {
	"title": "res://assets/audio/music_title.wav",
	"battle": "res://assets/audio/music_battle.wav",
}

var _player: AudioStreamPlayer = null
var _streams: Dictionary = {}
var current_track: String = ""
var fade_tween: Tween = null
var loop_count: int = 0     # 供测试断言循环确实发生

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	# 路由到 Music 总线，与音效分开调节
	var bus = AudioServer.get_bus_index("Music")
	if bus >= 0:
		_player.bus = "Music"
	# 循环不依赖 WAV 导入设置（loop_mode 会被重新导入重置为 0），
	# 由播放结束信号驱动重播，与导入管线解耦。
	_player.finished.connect(_on_track_finished)
	# 退出前停止播放并释放 stream，避免退出瞬间音频资源被报为泄漏
	tree_exiting.connect(func():
		current_track = ""
		_player.stop()
		_player.stream = null
	)
	add_child(_player)
	for key in TRACKS.keys():
		var path = TRACKS[key]
		# 先查存在再 load：直接 load 不存在的资源会打印 ERROR，污染启动日志
		if not ResourceLoader.exists(path):
			push_warning("Music: 曲目文件缺失，跳过 %s (%s)" % [key, path])
			continue
		var s = load(path)
		if s != null:
			_streams[key] = s
		else:
			push_warning("Music: 曲目加载失败 %s (%s)" % [key, path])

func has_track(track: String) -> bool:
	return _streams.has(track)

# 播放自然结束后重播，实现无缝循环。
# 淡出停止时 current_track 已清空，不会误触发循环。
func _on_track_finished() -> void:
	if current_track == "":
		return
	if not _streams.has(current_track):
		return
	_player.stream = _streams[current_track]
	_player.play()
	loop_count += 1

# 切换曲目。同曲重复调用不打断，避免场景内多次触发导致重头播放。
func play_track(track: String, fade_seconds: float = 1.2) -> void:
	if not _streams.has(track):
		return
	if current_track == track and _player.playing:
		return
	current_track = track
	_player.stream = _streams[track]
	_player.volume_db = -60.0
	_player.play()
	_fade_to(0.0, fade_seconds)

func stop_music(fade_seconds: float = 0.6) -> void:
	if current_track == "" and not _player.playing:
		return
	current_track = ""
	if fade_seconds <= 0.0:
		_player.stop()
		return
	_fade_to(-60.0, fade_seconds, false)
	# 淡出结束后真正停止，释放资源引用
	var t = create_tween()
	t.tween_interval(fade_seconds)
	t.tween_callback(func():
		if current_track == "":
			_player.stop()
			_player.stream = null
	)

# 淡入淡出。fade_in=true 时目标为 Settings 中的音乐音量，否则淡到静音。
func _fade_to(_target_db: float, seconds: float, fade_in: bool = true) -> void:
	if fade_tween != null and fade_tween.is_valid():
		fade_tween.kill()
	fade_tween = create_tween()
	var dest = float(Settings.get_float("audio/music_volume_db")) if fade_in else -60.0
	fade_tween.tween_property(_player, "volume_db", dest, maxf(0.05, seconds))
