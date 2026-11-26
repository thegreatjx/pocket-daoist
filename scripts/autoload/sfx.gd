extends Node
# 音效管理：固定数量的 AudioStreamPlayer 轮转复用。
# 割草游戏同帧可能触发大量音效，轮转比每次新建更稳定，也天然形成上限。

const PLAYER_COUNT := 24
const DENSITY_WINDOW_MS := 500
const LPF_MIN_HZ := 5500.0
const LPF_MAX_HZ := 20000.0

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
	"water_ripple_splash": "res://assets/audio/water_ripple_splash.wav",
	"fire_gourd_burn": "res://assets/audio/fire_gourd_burn.wav",
}

const PENTATONIC_PITCHES := [1.0, 1.1225, 1.2599, 1.4983, 1.6818, 2.0, 2.2449]
const CUE_RULES := {
	"default_hit": {"icd_ms": 60, "max_voices": 3, "base_db": -6.0, "jitter": 0.06, "priority": 1},
	"hit":         {"icd_ms": 42, "max_voices": 4, "base_db": -5.0, "jitter": 0.09, "priority": 2, "atten_scale": 0.55},
	"crit_hit":    {"icd_ms": 95, "max_voices": 2, "base_db": -3.5, "jitter": 0.08, "priority": 2},
	"reaction":    {"icd_ms": 110, "max_voices": 4, "base_db": -2.0, "jitter": 0.04, "priority": 3},
	"xp_orb":      {"icd_ms": 45, "max_voices": 3, "base_db": -9.0, "jitter": 0.0, "priority": 2},
	"enemy_die":   {"icd_ms": 55, "max_voices": 3, "base_db": -6.0, "jitter": 0.08, "priority": 1, "atten_scale": 0.70},
	"jar_break":   {"icd_ms": 65, "max_voices": 3, "base_db": -6.0, "jitter": 0.08, "priority": 2},
	"player_action": {"icd_ms": 40, "max_voices": 3, "base_db": -6.0, "jitter": 0.04, "priority": 4},
	"boss":        {"icd_ms": 80, "max_voices": 3, "base_db": -2.0, "jitter": 0.04, "priority": 4},
	"ui_event":    {"icd_ms": 20, "max_voices": 2, "base_db": -1.0, "jitter": 0.0, "priority": 5},
}

var _gem_combo: int = 0
var _last_gem_msec: int = 0
var _last_thunder_msec: int = -1000
var _last_gun_msec: int = -1000

var _streams: Dictionary = {}
var _players: Array = []
var _last_play_ms: Dictionary = {}
var _recent_hits: Dictionary = {}
var _global_hits: Array[int] = []
var _lpf_effect: AudioEffectLowPassFilter = null
var _current_lpf_hz: float = LPF_MAX_HZ
var play_count: int = 0   # 供测试断言

func _ready() -> void:
	# 退出前停止所有播放器：正在播放的 AudioStreamPlayback 会持有 WAV 资源引用，
	# 不停止就在进程退出时报 AudioStreamWAV / AudioStreamPlaybackWAV 泄漏。
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	if bus >= 0:
		for i in range(AudioServer.get_bus_effect_count(bus)):
			var fx: AudioEffect = AudioServer.get_bus_effect(bus, i)
			if fx is AudioEffectLowPassFilter:
				_lpf_effect = fx as AudioEffectLowPassFilter
				_lpf_effect.cutoff_hz = _current_lpf_hz
				break
	for i in range(PLAYER_COUNT):
		var p = AudioStreamPlayer.new()
		p.bus = bus_name
		# 播放结束即释放 stream，空闲播放器不持有 WAV 资源引用，
		# 避免进程退出时音频服务器报 AudioStreamWAV 泄漏（实测可降到接近 0）。
		p.finished.connect(_on_player_finished.bind(p))
		add_child(p)
		_players.append(p)

func _process(delta: float) -> void:
	var now: int = Time.get_ticks_msec()
	_prune_global_hits(now)
	var target_hz: float = _compute_target_lpf_hz()
	var blend: float = 1.0 - exp(-6.0 * maxf(0.0, delta))
	_current_lpf_hz = lerpf(_current_lpf_hz, target_hz, blend)
	if _lpf_effect != null:
		_lpf_effect.cutoff_hz = _current_lpf_hz

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

func _category_for_sound(sound_name: String) -> String:
	match sound_name:
		"enemy_die":
			return "enemy_die"
		"jar_break":
			return "jar_break"
		"gem_pickup":
			return "xp_orb"
		"level_up", "chest_open":
			return "ui_event"
		"player_hurt", "dash":
			return "player_action"
		"boss_roar", "boss_charge", "boss_slam", "boss_dash", "swarm_horn":
			return "boss"
		_:
			return "hit"

func play(sound_name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not _streams.has(sound_name) or _players.is_empty():
		return
	var now := Time.get_ticks_msec()
	if sound_name == "thunder":
		if now - _last_thunder_msec < 110:
			play_count += 1
			return
		_last_thunder_msec = now
	elif sound_name == "gun_shot":
		if now - _last_gun_msec < 55:
			play_count += 1
			return
		_last_gun_msec = now
	_play_managed(sound_name, _streams[sound_name] as AudioStream, _category_for_sound(sound_name), pitch, volume_db, false)
	play_count += 1

func play_cue(cue_id: String, stream: AudioStream, category: String = "default_hit", pitch: float = 1.0) -> void:
	if stream == null or _players.is_empty():
		return
	if _play_managed(cue_id, stream, category, pitch, NAN, true):
		play_count += 1

func _play_managed(cue_id: String, stream: AudioStream, category: String, pitch: float, volume_override_db: float, apply_jitter: bool) -> bool:
	if stream == null:
		return false
	var rule: Dictionary = CUE_RULES.get(category, CUE_RULES["default_hit"])
	var now: int = Time.get_ticks_msec()
	var last: int = int(_last_play_ms.get(cue_id, -9999))
	if now - last < int(rule["icd_ms"]):
		return false

	var hist: Array = _recent_hits.get(cue_id, [])
	var pruned: Array = []
	for t in hist:
		if now - int(t) <= DENSITY_WINDOW_MS:
			pruned.append(t)
	pruned.append(now)
	_recent_hits[cue_id] = pruned
	_last_play_ms[cue_id] = now

	_prune_global_hits(now)
	_global_hits.append(now)
	var target_hz: float = _compute_target_lpf_hz()
	if target_hz < _current_lpf_hz:
		_current_lpf_hz = target_hz
		if _lpf_effect != null:
			_lpf_effect.cutoff_hz = _current_lpf_hz

	var priority: int = int(rule["priority"])
	var player: AudioStreamPlayer = _acquire_player(cue_id, int(rule["max_voices"]), priority)
	if player == null:
		return false

	var density: float = float(maxi(1, pruned.size()))
	var atten_scale: float = float(rule.get("atten_scale", 1.0))
	var atten_db: float = -6.0 * atten_scale * (log(density) / log(2.0))
	var base_db: float = float(rule["base_db"]) if is_nan(volume_override_db) else volume_override_db
	player.volume_db = clampf(base_db + atten_db, -28.0, 0.0)

	if category == "xp_orb":
		if is_nan(volume_override_db):
			if now - _last_gem_msec > 900:
				_gem_combo = 0
			else:
				_gem_combo = (_gem_combo + 1) % PENTATONIC_PITCHES.size()
			_last_gem_msec = now
			player.pitch_scale = PENTATONIC_PITCHES[_gem_combo]
		else:
			player.pitch_scale = pitch
	elif apply_jitter:
		var j: float = float(rule["jitter"])
		player.pitch_scale = pitch * (1.0 + randf_range(-j, j))
	else:
		player.pitch_scale = pitch

	player.set_meta("cue_id", cue_id)
	player.set_meta("priority", priority)
	player.set_meta("started_ms", now)
	player.stream = stream
	player.play()
	return true

func _acquire_player(cue_id: String, max_voices: int, incoming_priority: int) -> AudioStreamPlayer:
	var active_same: int = 0
	var free_p: AudioStreamPlayer = null
	var steal_candidate: AudioStreamPlayer = null
	var steal_prio: int = incoming_priority
	var steal_time: int = 2147483647

	for p in _players:
		if p.playing:
			if String(p.get_meta("cue_id", "")) == cue_id:
				active_same += 1
			var p_prio: int = int(p.get_meta("priority", 0))
			var p_time: int = int(p.get_meta("started_ms", 0))
			if p_prio < steal_prio or (p_prio == steal_prio and steal_candidate != null and p_prio < incoming_priority and p_time < steal_time):
				steal_candidate = p
				steal_prio = p_prio
				steal_time = p_time
		elif free_p == null:
			free_p = p

	if active_same >= max_voices:
		return null
	if free_p != null:
		return free_p
	if steal_candidate != null:
		steal_candidate.stop()
		steal_candidate.stream = null
		return steal_candidate
	return null

func _prune_global_hits(now: int) -> void:
	var write_idx: int = 0
	for i in range(_global_hits.size()):
		if now - _global_hits[i] <= DENSITY_WINDOW_MS:
			_global_hits[write_idx] = _global_hits[i]
			write_idx += 1
	_global_hits.resize(write_idx)

func _compute_target_lpf_hz() -> float:
	var t: float = clampf(float(_global_hits.size() - 4) / 20.0, 0.0, 1.0)
	return lerpf(LPF_MAX_HZ, LPF_MIN_HZ, t)

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
