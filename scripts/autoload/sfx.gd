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
	"chest_open": "res://assets/audio/chest_open.wav",
	"thunder": "res://assets/audio/thunder.wav",
	"player_hurt": "res://assets/audio/player_hurt.wav",
	"dash": "res://assets/audio/dash.wav",
	"jar_break": "res://assets/audio/jar_break.wav",
	"gun_shot": "res://assets/audio/gun_shot.wav",
	"cannon_blast": "res://assets/audio/cannon_blast.wav",
}

const OPTIONAL_SOUNDS := {
	"swarm_horn": "res://assets/audio/swarm_horn.wav",
	"boss_roar": "res://assets/audio/boss_roar.wav",
	"boss_charge": "res://assets/audio/boss_charge.wav",
	"boss_slam": "res://assets/audio/boss_slam.wav",
	"boss_dash": "res://assets/audio/boss_dash.wav",
	"thunder_arc_snap": "res://assets/audio/thunder_arc_snap.wav",
}

const PENTATONIC_PITCHES := [1.0, 1.1225, 1.2599, 1.4983, 1.6818, 2.0, 2.2449]
var _gem_combo: int = 0
var _last_gem_msec: int = 0
var _last_thunder_msec: int = -1000
var _last_gun_msec: int = -1000

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
	for key in OPTIONAL_SOUNDS.keys():
		var path: String = OPTIONAL_SOUNDS[key]
		if ResourceLoader.exists(path):
			var s = load(path)
			if s != null:
				_streams[key] = s
	# 路由到 SFX 总线，与背景音乐分开调节音量
	var bus = AudioServer.get_bus_index("SFX")
	var bus_name = "SFX" if bus >= 0 else "Master"
	for i in range(PLAYER_COUNT):
		var p = AudioStreamPlayer.new()
		p.bus = bus_name
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
	if sound_name == "thunder":
		var now := Time.get_ticks_msec()
		if now - _last_thunder_msec < 110:
			play_count += 1
			return
		_last_thunder_msec = now
	elif sound_name == "gun_shot":
		var now_g := Time.get_ticks_msec()
		if now_g - _last_gun_msec < 55:
			play_count += 1
			return
		_last_gun_msec = now_g
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

# 连续吃灵气珠：按中国五声音阶（宫商角徵羽）逐颗升高音高
func play_gem_pickup() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_gem_msec > 520:
		_gem_combo = 0
	else:
		_gem_combo = mini(_gem_combo + 1, PENTATONIC_PITCHES.size() - 1)
	_last_gem_msec = now
	play("gem_pickup", -10.0, PENTATONIC_PITCHES[_gem_combo])
# Boss / 兽潮专属音效播放：新音频文件尚未烘焙时安全回退到已有音效，绝不报错
func play_boss_or_fallback(sound_name: String, fallback_name: String, volume_db: float = -3.0, pitch: float = 1.0) -> void:
	if _streams.has(sound_name):
		play(sound_name, volume_db, pitch)
	elif _streams.has(fallback_name):
		play(fallback_name, volume_db, pitch)
