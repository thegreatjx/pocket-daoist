class_name ThrottledAudioManager
extends Node

@export var sfx_bus_name: String = "SFX"
@export var pool_size: int = 16
@export var density_window_ms: int = 500
@export var lpf_min_hz: float = 3800.0
@export var lpf_max_hz: float = 20000.0

var _players: Array[AudioStreamPlayer] = []
var _last_play_ms: Dictionary = {}
var _recent_hits: Dictionary = {}
var _global_hits: Array[int] = []
var _xp_step: int = 0
var _xp_last_ms: int = 0
var _lpf_effect: AudioEffectLowPassFilter = null
var _current_lpf_hz: float = 20000.0

const PENTATONIC: Array[float] = [1.0, 1.122, 1.260, 1.498, 1.682, 2.0, 2.245, 2.520]

var cue_rules: Dictionary = {
	"default_hit": {"icd_ms": 60, "max_voices": 3, "base_db": -6.0, "jitter": 0.06, "priority": 1},
	"reaction":    {"icd_ms": 110, "max_voices": 4, "base_db": -2.0, "jitter": 0.04, "priority": 3},
	"xp_orb":      {"icd_ms": 45, "max_voices": 3, "base_db": -9.0, "jitter": 0.0, "priority": 2},
	"ui_event":    {"icd_ms": 20, "max_voices": 2, "base_db": -1.0, "jitter": 0.0, "priority": 4}
}

func _ready() -> void:
	tree_exiting.connect(stop_all)
	_current_lpf_hz = lpf_max_hz
	var bus_idx: int = AudioServer.get_bus_index(sfx_bus_name)
	var target_bus: String = sfx_bus_name if bus_idx != -1 else "Master"
	if bus_idx != -1:
		for i in range(AudioServer.get_bus_effect_count(bus_idx)):
			var fx: AudioEffect = AudioServer.get_bus_effect(bus_idx, i)
			if fx is AudioEffectLowPassFilter:
				_lpf_effect = fx as AudioEffectLowPassFilter
				_lpf_effect.cutoff_hz = _current_lpf_hz
				break

	for i in range(pool_size):
		var p := AudioStreamPlayer.new()
		p.bus = target_bus
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

func get_current_lpf_cutoff_hz() -> float:
	return _current_lpf_hz

func stop_all() -> void:
	for p in _players:
		if p != null and is_instance_valid(p):
			p.stop()
			p.stream = null

func _on_player_finished(p: AudioStreamPlayer) -> void:
	if p != null and is_instance_valid(p):
		p.stream = null

func play_cue(cue_id: String, stream: AudioStream, category: String = "default_hit") -> void:
	if stream == null:
		return
	var rule: Dictionary = cue_rules.get(category, cue_rules["default_hit"])
	var now: int = Time.get_ticks_msec()
	var last: int = int(_last_play_ms.get(cue_id, -9999))
	if now - last < int(rule["icd_ms"]):
		return

	var hist: Array = _recent_hits.get(cue_id, [])
	var pruned: Array = []
	for t in hist:
		if now - int(t) <= density_window_ms:
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
		return

	var density: float = float(maxi(1, pruned.size()))
	var atten_db: float = -6.0 * (log(density) / log(2.0))
	player.volume_db = clampf(float(rule["base_db"]) + atten_db, -28.0, 0.0)

	if category == "xp_orb":
		if now - _xp_last_ms > 900:
			_xp_step = 0
		else:
			_xp_step = (_xp_step + 1) % PENTATONIC.size()
		_xp_last_ms = now
		player.pitch_scale = PENTATONIC[_xp_step]
	else:
		var j: float = float(rule["jitter"])
		player.pitch_scale = 1.0 + randf_range(-j, j)

	player.set_meta("cue_id", cue_id)
	player.set_meta("priority", priority)
	player.set_meta("started_ms", now)
	player.stream = stream
	player.play()

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
		if now - _global_hits[i] <= density_window_ms:
			_global_hits[write_idx] = _global_hits[i]
			write_idx += 1
	_global_hits.resize(write_idx)

func _compute_target_lpf_hz() -> float:
	var t: float = clampf(float(_global_hits.size() - 4) / 20.0, 0.0, 1.0)
	return lerpf(lpf_max_hz, lpf_min_hz, t)
