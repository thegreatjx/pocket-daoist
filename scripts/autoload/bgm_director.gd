extends Node

enum Mode { SILENT, LOBBY, STAGE_NORMAL, MINIBOSS, BOSS_P1, BOSS_P2 }
enum TempoTier { BASE, MID_RUSH, CLIMAX }

const BUS_BGM := &"BGM"
const LOWPASS_EFFECT_IDX := 0
const CUTOFF_CLEAR_HZ := 20500.0
const CUTOFF_MUFFLED_HZ := 950.0

const TEMPO_MID_SEC := 150.0
const TEMPO_CLIMAX_SEC := 315.0
const PITCH_BASE := 1.0
const PITCH_MID := 1.03
const PITCH_CLIMAX := 1.055
const DRUMS_TARGET_DB := -5.5
const SILENT_DB := -48.0

const TRACKS := {
	"lobby": "res://assets/audio/bgm/bgm_lobby.ogg",
	"forest": "res://assets/audio/bgm/bgm_forest.ogg",
	"volcano": "res://assets/audio/bgm/bgm_volcano.ogg",
	"ice": "res://assets/audio/bgm/bgm_ice.ogg",
	"miniboss": "res://assets/audio/bgm/bgm_miniboss.ogg",
	"drums": "res://assets/audio/bgm/loop_tension_drums.ogg",
	"boss_p1": "res://assets/audio/bgm/bgm_boss_p1.ogg",
	"boss_p2": "res://assets/audio/bgm/bgm_boss_p2.ogg",
}

const LEGACY_TRACK_ALIAS := {
	"lobby": "title",
	"forest": "battle",
	"volcano": "battle",
	"ice": "battle",
	"miniboss": "swarm",
	"boss_p1": "boss",
	"boss_p2": "boss",
}

var mode: int = Mode.SILENT
var tempo_tier: int = TempoTier.BASE
var current_track: String = ""
var current_stage_track: String = "forest"
var is_muffled: bool = false

var _streams: Dictionary = {}
var _decks: Array[AudioStreamPlayer] = []
var _active_deck_idx: int = 0
var _drums_player: AudioStreamPlayer = null
var _active_miniboss_ids: Dictionary = {}

var _fade_tween: Tween = null
var _drums_tween: Tween = null
var _muffle_tween: Tween = null
var _pitch_tween: Tween = null
var _bus_idx: int = -1
var _lowpass: AudioEffectLowPassFilter = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_resolve_bgm_bus()
	_setup_players()
	_load_all_streams()

	if GameFlow != null and not GameFlow.state_changed.is_connected(_on_game_flow_state_changed):
		GameFlow.state_changed.connect(_on_game_flow_state_changed)

	tree_exiting.connect(_cleanup_on_exit)


func _cleanup_on_exit() -> void:
	_kill_tween(_fade_tween)
	_kill_tween(_drums_tween)
	_kill_tween(_muffle_tween)
	_kill_tween(_pitch_tween)
	mode = Mode.SILENT
	current_track = ""
	for d in _decks:
		if d != null:
			d.stop()
			d.stream = null
	if _drums_player != null:
		_drums_player.stop()
		_drums_player.stream = null


func _resolve_bgm_bus() -> void:
	_bus_idx = AudioServer.get_bus_index(BUS_BGM)
	if _bus_idx < 0:
		_bus_idx = AudioServer.get_bus_index(&"Music")
	if _bus_idx >= 0 and AudioServer.get_bus_effect_count(_bus_idx) > LOWPASS_EFFECT_IDX:
		var fx := AudioServer.get_bus_effect(_bus_idx, LOWPASS_EFFECT_IDX)
		if fx is AudioEffectLowPassFilter:
			_lowpass = fx as AudioEffectLowPassFilter
			_lowpass.cutoff_hz = CUTOFF_CLEAR_HZ


func _setup_players() -> void:
	var bus_name: StringName = BUS_BGM if AudioServer.get_bus_index(BUS_BGM) >= 0 else &"Master"
	for _i in range(2):
		var p := AudioStreamPlayer.new()
		p.bus = bus_name
		p.volume_db = SILENT_DB
		p.finished.connect(_on_deck_finished.bind(p))
		add_child(p)
		_decks.append(p)

	_drums_player = AudioStreamPlayer.new()
	_drums_player.bus = bus_name
	_drums_player.volume_db = SILENT_DB
	_drums_player.finished.connect(func() -> void:
		if mode == Mode.STAGE_NORMAL and tempo_tier == TempoTier.CLIMAX and _drums_player.stream != null:
			_drums_player.play()
	)
	add_child(_drums_player)


func _load_all_streams() -> void:
	for key in TRACKS.keys():
		var path: String = TRACKS[key]
		if not ResourceLoader.exists(path):
			push_warning("BgmDirector: 曲目文件缺失，跳过 %s (%s)" % [key, path])
			continue
		var s := load(path)
		if s == null:
			push_warning("BgmDirector: 曲目加载失败 %s (%s)" % [key, path])
			continue
		if s is AudioStreamOggVorbis:
			(s as AudioStreamOggVorbis).loop = true
		_streams[key] = s


func has_track(key: String) -> bool:
	return _streams.has(key)


func play_lobby(fade_sec: float = 0.9) -> void:
	_active_miniboss_ids.clear()
	tempo_tier = TempoTier.BASE
	_transition_mode(Mode.LOBBY, "lobby", fade_sec)


func play_stage(stage_id: int, fade_sec: float = 0.9) -> void:
	var track_key := _stage_track_for_id(stage_id)
	current_stage_track = track_key
	_active_miniboss_ids.clear()
	tempo_tier = TempoTier.BASE
	_transition_mode(Mode.STAGE_NORMAL, track_key, fade_sec)


func start_stage_from_chapter(chapter: Dictionary, fade_sec: float = 0.9) -> void:
	var track_key := String(chapter.get("bgm_track", ""))
	if track_key.is_empty() or not _streams.has(track_key):
		track_key = _stage_track_for_id(int(chapter.get("id", 1)))
	current_stage_track = track_key
	_active_miniboss_ids.clear()
	tempo_tier = TempoTier.BASE
	_transition_mode(Mode.STAGE_NORMAL, track_key, fade_sec)


func resume_stage_bgm(fade_sec: float = 0.9) -> void:
	_active_miniboss_ids.clear()
	_transition_mode(Mode.STAGE_NORMAL, current_stage_track, fade_sec)


func update_battle_time(elapsed_sec: float) -> void:
	var next_tier := TempoTier.BASE
	if elapsed_sec >= TEMPO_CLIMAX_SEC:
		next_tier = TempoTier.CLIMAX
	elif elapsed_sec >= TEMPO_MID_SEC:
		next_tier = TempoTier.MID_RUSH
	if next_tier == tempo_tier:
		return
	tempo_tier = next_tier
	if mode == Mode.STAGE_NORMAL:
		_apply_tempo_state(1.2)


func on_miniboss_spawned(enemy_id: int = 0, fade_sec: float = 0.6) -> void:
	if enemy_id != 0:
		_active_miniboss_ids[enemy_id] = true
	if mode == Mode.BOSS_P1 or mode == Mode.BOSS_P2:
		return
	_transition_mode(Mode.MINIBOSS, "miniboss", fade_sec)


func on_miniboss_killed(enemy_id: int = 0, fade_sec: float = 0.9) -> void:
	if enemy_id != 0:
		if not _active_miniboss_ids.has(enemy_id):
			return
		_active_miniboss_ids.erase(enemy_id)
	if not _active_miniboss_ids.is_empty():
		return
	if mode == Mode.MINIBOSS:
		_transition_mode(Mode.STAGE_NORMAL, current_stage_track, fade_sec)


func enter_boss_p1(fade_sec: float = 0.6) -> void:
	_active_miniboss_ids.clear()
	_transition_mode(Mode.BOSS_P1, "boss_p1", fade_sec)


func enter_boss_p2(fade_sec: float = 0.8) -> void:
	_active_miniboss_ids.clear()
	_transition_mode(Mode.BOSS_P2, "boss_p2", fade_sec)


func set_muffled(muffled: bool, duration: float = 0.28) -> void:
	if is_muffled == muffled and _muffle_tween == null:
		return
	is_muffled = muffled
	if _lowpass == null:
		_resolve_bgm_bus()
	if _lowpass == null:
		return
	var target_hz := CUTOFF_MUFFLED_HZ if muffled else CUTOFF_CLEAR_HZ
	_kill_tween(_muffle_tween)
	if duration <= 0.02:
		_lowpass.cutoff_hz = target_hz
		return
	_muffle_tween = create_tween()
	_muffle_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_muffle_tween.tween_property(_lowpass, "cutoff_hz", target_hz, duration).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT if muffled else Tween.EASE_IN_OUT)
	_muffle_tween.tween_callback(func() -> void: _muffle_tween = null)


func stop_all(fade_sec: float = 0.5) -> void:
	_active_miniboss_ids.clear()
	mode = Mode.SILENT
	tempo_tier = TempoTier.BASE
	current_track = ""
	_kill_tween(_fade_tween)
	_kill_tween(_drums_tween)
	_kill_tween(_pitch_tween)
	if fade_sec <= 0.03:
		for d in _decks:
			d.stop()
			d.stream = null
			d.pitch_scale = 1.0
		if _drums_player != null:
			_drums_player.stop()
			_drums_player.stream = null
		return
	_fade_tween = create_tween()
	_fade_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_fade_tween.set_parallel(true)
	for d in _decks:
		if d.playing:
			_fade_tween.tween_property(d, "volume_db", SILENT_DB, fade_sec)
	if _drums_player != null and _drums_player.playing:
		_fade_tween.tween_property(_drums_player, "volume_db", SILENT_DB, fade_sec)
	_fade_tween.chain().tween_callback(func() -> void:
		if mode == Mode.SILENT:
			for d in _decks:
				d.stop()
				d.stream = null
			if _drums_player != null:
				_drums_player.stop()
				_drums_player.stream = null
	)


func _transition_mode(next_mode: int, track_key: String, fade_sec: float) -> void:
	mode = next_mode
	_crossfade_to(track_key, fade_sec)
	_apply_tempo_state(fade_sec)
	if Music != null and Music.has_method("sync_external_track"):
		Music.sync_external_track(String(LEGACY_TRACK_ALIAS.get(track_key, "battle")))


func _crossfade_to(track_key: String, fade_sec: float) -> void:
	if not _streams.has(track_key):
		return
	var cur_deck := _decks[_active_deck_idx]
	if current_track == track_key and cur_deck.playing:
		return

	var next_idx := 1 - _active_deck_idx
	var next_deck := _decks[next_idx]
	_active_deck_idx = next_idx
	current_track = track_key

	_kill_tween(_fade_tween)

	next_deck.stream = _streams[track_key]
	next_deck.pitch_scale = _desired_pitch()

	if fade_sec <= 0.05:
		cur_deck.stop()
		cur_deck.stream = null
		next_deck.volume_db = 0.0
		next_deck.play()
		return

	next_deck.volume_db = SILENT_DB
	next_deck.play()

	_fade_tween = create_tween()
	_fade_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_fade_tween.set_parallel(true)
	_fade_tween.tween_property(next_deck, "volume_db", 0.0, fade_sec).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if cur_deck.playing:
		_fade_tween.tween_property(cur_deck, "volume_db", SILENT_DB, fade_sec).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		_fade_tween.chain().tween_callback(func() -> void:
			cur_deck.stop()
			cur_deck.stream = null
		)


func _apply_tempo_state(fade_sec: float) -> void:
	var target_pitch := _desired_pitch()
	var active_deck := _decks[_active_deck_idx]
	_kill_tween(_pitch_tween)
	if fade_sec <= 0.05:
		active_deck.pitch_scale = target_pitch
		if _drums_player != null:
			_drums_player.pitch_scale = target_pitch
	else:
		_pitch_tween = create_tween()
		_pitch_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_pitch_tween.set_parallel(true)
		_pitch_tween.tween_property(active_deck, "pitch_scale", target_pitch, fade_sec)
		if _drums_player != null:
			_pitch_tween.tween_property(_drums_player, "pitch_scale", target_pitch, fade_sec)

	var want_drums := (mode == Mode.STAGE_NORMAL and tempo_tier == TempoTier.CLIMAX and _streams.has("drums"))
	if _drums_player == null:
		return
	_kill_tween(_drums_tween)
	if want_drums:
		if _drums_player.stream != _streams["drums"]:
			_drums_player.stream = _streams["drums"]
		_drums_player.pitch_scale = target_pitch
		if not _drums_player.playing:
			_drums_player.volume_db = SILENT_DB
			_drums_player.play()
		if fade_sec <= 0.05:
			_drums_player.volume_db = DRUMS_TARGET_DB
		else:
			_drums_tween = create_tween()
			_drums_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			_drums_tween.tween_property(_drums_player, "volume_db", DRUMS_TARGET_DB, fade_sec)
	else:
		if _drums_player.playing:
			if fade_sec <= 0.05:
				_drums_player.stop()
			else:
				_drums_tween = create_tween()
				_drums_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
				_drums_tween.tween_property(_drums_player, "volume_db", SILENT_DB, fade_sec)
				_drums_tween.tween_callback(func() -> void:
					if mode != Mode.STAGE_NORMAL or tempo_tier != TempoTier.CLIMAX:
						_drums_player.stop()
				)


func _desired_pitch() -> float:
	if mode != Mode.STAGE_NORMAL:
		return PITCH_BASE
	match tempo_tier:
		TempoTier.MID_RUSH:
			return PITCH_MID
		TempoTier.CLIMAX:
			return PITCH_CLIMAX
		_:
			return PITCH_BASE


func _stage_track_for_id(stage_id: int) -> String:
	match stage_id:
		3:
			return "volcano"
		4:
			return "ice"
		_:
			return "forest"


func _on_deck_finished(deck: AudioStreamPlayer) -> void:
	if mode == Mode.SILENT or current_track.is_empty():
		return
	if _decks[_active_deck_idx] == deck and _streams.has(current_track):
		deck.stream = _streams[current_track]
		deck.play()


func _on_game_flow_state_changed(_from_state: int, to_state: int) -> void:
	var should_muffle := (to_state == GameFlow.State.PAUSED or to_state == GameFlow.State.UPGRADE)
	set_muffled(should_muffle)


func _kill_tween(tw: Tween) -> void:
	if tw != null and tw.is_valid():
		tw.kill()
