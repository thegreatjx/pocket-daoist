extends Node
# 动态背景音乐：双播放器平滑交叉淡入淡出（标题 / 常规战斗 / 妖潮激燃 / 首领决战）。

const TRACKS := {
	"title": "res://assets/audio/music_title.ogg",
	"battle": "res://assets/audio/music_battle.ogg",
	"swarm": "res://assets/audio/music_swarm.ogg",
	"boss": "res://assets/audio/music_boss.ogg",
}

var _player: AudioStreamPlayer = null
var _fade_out_player: AudioStreamPlayer = null
var _streams: Dictionary = {}
var current_track: String = ""
var fade_tween: Tween = null
var loop_count: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bus = AudioServer.get_bus_index("Music")
	var bus_name := "Music" if bus >= 0 else "Master"

	_player = AudioStreamPlayer.new()
	_player.bus = bus_name
	_player.finished.connect(_on_track_finished)
	add_child(_player)

	_fade_out_player = AudioStreamPlayer.new()
	_fade_out_player.bus = bus_name
	add_child(_fade_out_player)

	tree_exiting.connect(func():
		current_track = ""
		_player.stop()
		_player.stream = null
		_fade_out_player.stop()
		_fade_out_player.stream = null
	)

	for key in TRACKS.keys():
		var path = TRACKS[key]
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

func _on_track_finished() -> void:
	if current_track == "":
		return
	if not _streams.has(current_track):
		return
	_player.stream = _streams[current_track]
	_player.play()
	loop_count += 1

func play_track(track: String, fade_seconds: float = 0.9) -> void:
	if not _streams.has(track):
		return
	if current_track == track and _player.playing:
		return

	var dest_db := float(Settings.get_float("audio/music_volume_db"))
	var prev_stream := _player.stream
	var prev_pos := _player.get_playback_position() if _player.playing else 0.0
	var prev_was_playing := _player.playing

	current_track = track
	if fade_tween != null and fade_tween.is_valid():
		fade_tween.kill()

	if prev_was_playing and prev_stream != null and fade_seconds > 0.05:
		_fade_out_player.stream = prev_stream
		_fade_out_player.volume_db = _player.volume_db
		_fade_out_player.play(prev_pos)
	else:
		_fade_out_player.stop()
		_fade_out_player.stream = null

	_player.stream = _streams[track]
	if fade_seconds <= 0.05:
		_player.volume_db = dest_db
		_player.play()
		return

	_player.volume_db = -36.0
	_player.play()
	fade_tween = create_tween()
	fade_tween.set_parallel(true)
	fade_tween.tween_property(_player, "volume_db", dest_db, fade_seconds)
	if _fade_out_player.playing:
		fade_tween.tween_property(_fade_out_player, "volume_db", -52.0, fade_seconds)
		fade_tween.chain().tween_callback(func():
			_fade_out_player.stop()
			_fade_out_player.stream = null
		)

func stop_music(fade_seconds: float = 0.6) -> void:
	if current_track == "" and not _player.playing:
		return
	current_track = ""
	if fade_tween != null and fade_tween.is_valid():
		fade_tween.kill()
	_fade_out_player.stop()
	_fade_out_player.stream = null
	if fade_seconds <= 0.0:
		_player.stop()
		return
	fade_tween = create_tween()
	fade_tween.tween_property(_player, "volume_db", -60.0, maxf(0.05, fade_seconds))
	fade_tween.tween_callback(func():
		if current_track == "":
			_player.stop()
			_player.stream = null
	)
