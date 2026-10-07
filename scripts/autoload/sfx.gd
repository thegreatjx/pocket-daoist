extends Node
# 音效管理：固定数量的 AudioStreamPlayer 轮转复用。
# 割草游戏同帧可能触发大量音效，轮转比每次新建更稳定，也天然形成上限。

const PLAYER_COUNT := 24

const SOUNDS := {
	"sword_cast": "res://assets/audio/sword_cast.wav",
	"sword_hit": "res://assets/audio/sword_hit.wav",
	"enemy_die": "res://assets/audio/enemy_die.wav",
	"gem_pickup": "res://assets/audio/gem_pickup.wav",
	"level_up": "res://assets/audio/level_up.wav",
	"thunder": "res://assets/audio/thunder.wav",
	"player_hurt": "res://assets/audio/player_hurt.wav",
	"dash": "res://assets/audio/dash.wav",
}

var _streams: Dictionary = {}
var _players: Array = []
var _cursor: int = 0
var play_count: int = 0   # 供测试断言

func _ready() -> void:
	# 退出前停止所有播放器：正在播放的 AudioStreamPlayback 会持有 WAV 资源引用，
	# 不停止就在进程退出时报 AudioStreamWAV / AudioStreamPlaybackWAV 泄漏。
	tree_exiting.connect(_on_tree_exiting)
	for key in SOUNDS.keys():
		var s = load(SOUNDS[key])
		if s != null:
			_streams[key] = s
		else:
			push_error("Sfx: 音效加载失败 %s" % SOUNDS[key])
	for i in range(PLAYER_COUNT):
		var p = AudioStreamPlayer.new()
		# 播放结束即释放 stream，空闲播放器不持有 WAV 资源引用，
		# 避免进程退出时音频服务器报 AudioStreamWAV 泄漏（实测可降到接近 0）。
		p.finished.connect(_on_player_finished.bind(p))
		add_child(p)
		_players.append(p)

func _on_player_finished(p: AudioStreamPlayer) -> void:
	if p != null and is_instance_valid(p):
		p.stream = null

# 停止全部播放并释放 stream 引用。场景切换 / 退出前调用可避免资源占用残留。
func stop_all() -> void:
	for p in _players:
		if p != null and is_instance_valid(p):
			p.stop()
			p.stream = null

func _on_tree_exiting() -> void:
	stop_all()

func has_sound(sound_name: String) -> bool:
	return _streams.has(sound_name)

func play(sound_name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not _streams.has(sound_name) or _players.is_empty():
		return
	var p = _players[_cursor]
	_cursor = (_cursor + 1) % _players.size()
	if p.playing:
		p.stop()
	p.stream = _streams[sound_name]
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()
	play_count += 1

# 命中类音效加轻微随机音高，避免连续播放时的机械感
func play_varied(sound_name: String, volume_db: float = 0.0) -> void:
	play(sound_name, volume_db, randf_range(0.92, 1.10))
