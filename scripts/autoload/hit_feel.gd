extends Node

const HIT_MARK_SCENE := "res://scenes/hit_mark.tscn"
const MAX_HIT_MARKS := 40

const STOP_BY_TIER := [0.0, 0.045, 0.060]
const KILL_STOP_BY_TIER := [0.0, 0.065, 0.160]
const REACTION_STOP_SEC := 0.035
const SLOWMO_TIME_SCALE := 0.08
const CRIT_STOP_BONUS := 0.0
const STOP_MIN_INTERVAL_MS := 140.0
const STOP_MAX_MS := 220.0
const STOP_BUDGET_MAX_MS := 90.0
const STOP_BUDGET_REFILL_MS_PER_SEC := 90.0
const STOP_BUDGET_EXEMPT_MS := 80.0

const SHAKE_BY_TIER := [0.0, 2.5, 4.0]
const KILL_SHAKE_BY_TIER := [0.8, 3.5, 6.0]
const CRIT_SHAKE_BONUS := 0.6
const SHAKE_MIN_INTERVAL_MS := 110.0

var _stop_until_ms := 0.0
var _next_stop_ms := 0.0
var _next_shake_ms := 0.0
var _stop_token := 0
var _stop_budget_ms := STOP_BUDGET_MAX_MS
var _budget_ref_ms := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameFlow.state_changed.connect(_on_state_changed)

func _process(_delta: float) -> void:
	var now := float(Time.get_ticks_msec())
	if now > _budget_ref_ms:
		_stop_budget_ms = minf(STOP_BUDGET_MAX_MS, _stop_budget_ms + (now - _budget_ref_ms) * STOP_BUDGET_REFILL_MS_PER_SEC * 0.001)
		_budget_ref_ms = now
	if Engine.time_scale == 1.0:
		return
	if now >= _stop_until_ms:
		Engine.time_scale = 1.0

func _on_state_changed(_from_state: int, to_state: int) -> void:
	if to_state != GameFlow.State.PLAYING:
		_reset_stop()

func _reset_stop() -> void:
	_stop_until_ms = 0.0
	_stop_token += 1
	Engine.time_scale = 1.0

func on_hit(world_pos: Vector2, dir: Vector2, element: String, is_crit: bool, tier: int, lethal: bool, parent: Node) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var safe_tier := clampi(tier, 0, 2)
	_try_stop(lethal, is_crit, safe_tier)
	_try_shake(lethal, is_crit, safe_tier, dir)
	if lethal or is_crit or safe_tier > 0:
		_spawn_mark(world_pos, dir, element, is_crit, safe_tier, lethal, parent)

func on_reaction(is_major: bool = true) -> void:
	if not is_major:
		return
	_apply_time_stop(REACTION_STOP_SEC, SLOWMO_TIME_SCALE)

func _try_stop(lethal: bool, is_crit: bool, tier: int) -> void:
	var duration: float = (KILL_STOP_BY_TIER[tier] if lethal else STOP_BY_TIER[tier]) + (CRIT_STOP_BONUS if is_crit else 0.0)
	if duration <= 0.0:
		return
	var target_scale := 0.0 if (lethal and tier >= 2) else SLOWMO_TIME_SCALE
	_apply_time_stop(duration, target_scale)

func _apply_time_stop(duration: float, target_scale: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if not Settings.get_bool("video/hitstop"):
		return
	if get_tree().paused or GameFlow.state != GameFlow.State.PLAYING:
		return
	var now := float(Time.get_ticks_msec())
	if now < _next_stop_ms:
		return
	var ms := minf(duration * 1000.0, STOP_MAX_MS)
	if ms <= STOP_BUDGET_EXEMPT_MS:
		if ms > _stop_budget_ms:
			return
		_stop_budget_ms -= ms
	_stop_until_ms = maxf(_stop_until_ms, now + ms)
	_next_stop_ms = now + STOP_MIN_INTERVAL_MS
	Engine.time_scale = target_scale
	_stop_token += 1
	var token := _stop_token
	get_tree().create_timer(ms / 1000.0, true, false, true).timeout.connect(func() -> void:
		if token == _stop_token:
			_stop_until_ms = 0.0
			Engine.time_scale = 1.0
	)

func _try_shake(lethal: bool, is_crit: bool, tier: int, dir: Vector2) -> void:
	if get_tree().paused:
		return
	var now := float(Time.get_ticks_msec())
	if now < _next_shake_ms:
		return
	var amount: float = KILL_SHAKE_BY_TIER[tier] if lethal else SHAKE_BY_TIER[tier]
	if is_crit:
		amount += CRIT_SHAKE_BONUS
	if amount <= 0.0:
		return
	_next_shake_ms = now + SHAKE_MIN_INTERVAL_MS
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("shake_camera_dir"):
		player.shake_camera_dir(amount, dir)

func _spawn_mark(world_pos: Vector2, dir: Vector2, element: String, is_crit: bool, tier: int, lethal: bool, parent: Node) -> void:
	var mark := ObjectPools.acquire(HIT_MARK_SCENE, parent, MAX_HIT_MARKS)
	if mark == null or not mark.has_method("setup"):
		return
	var spec := V2VfxFactory.get_hit_vfx_spec(element)
	var col: Color = spec.get("base_color", Color(1.0, 0.95, 0.82, 1.0))
	if is_crit:
		col = col.lerp(Color(1.0, 0.86, 0.42, 1.0), 0.55)
	mark.global_position = world_pos
	mark.setup(dir, col, tier > 0 or is_crit, lethal)
