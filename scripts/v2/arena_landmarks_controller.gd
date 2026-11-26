class_name ArenaLandmarksController
extends Node2D

signal spirit_array_triggered(pos: Vector2)
signal stele_shattered(pos: Vector2)

const CHEST_SCENE := "res://scenes/treasure_chest.tscn"
const ARRAY_TRIGGER_RADIUS := 145.0
const ARRAY_CHARGE_SEC := 2.5
const ARRAY_BUFF_SEC := 8.0

class DemonSealingStele:
	extends Node2D
	signal shattered(pos: Vector2)

	var max_hp: float = 120.0
	var hp: float = 120.0
	var _broken: bool = false
	var _anim_t: float = 0.0

	func _ready() -> void:
		add_to_group("breakables")
		z_index = -1

	func take_damage(amount: float) -> void:
		if _broken:
			return
		hp -= amount
		if hp <= 0.0:
			_broken = true
			shattered.emit(global_position)
			queue_free()

	func _process(delta: float) -> void:
		_anim_t += delta
		queue_redraw()

	func _draw() -> void:
		var pulse: float = 0.65 + 0.25 * sin(_anim_t * 3.5)
		draw_set_transform(Vector2(0.0, 20.0), 0.0, Vector2(1.0, 0.45))
		draw_circle(Vector2.ZERO, 26.0, Color(0.06, 0.05, 0.10, 0.40))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_rect(Rect2(-16.0, -48.0, 32.0, 60.0), Color(0.18, 0.16, 0.24, 1.0))
		draw_rect(Rect2(-16.0, -48.0, 32.0, 60.0), Color(0.86, 0.64, 0.26, pulse), false, 2.2)
		draw_circle(Vector2(0.0, -24.0), 7.0, Color(0.95, 0.28, 0.24, pulse))
		if hp < max_hp:
			var ratio: float = clampf(hp / maxf(1.0, max_hp), 0.0, 1.0)
			draw_rect(Rect2(-20.0, -58.0, 40.0, 5.0), Color(0.1, 0.1, 0.1, 0.85))
			draw_rect(Rect2(-19.0, -57.0, 38.0 * ratio, 3.0), Color(0.92, 0.30, 0.24, 1.0))

var spirit_arrays: Array[Dictionary] = []
var demon_steles: Array[Dictionary] = []
var active_array_index: int = -1
var charge_progress: float = 0.0
var array_consumed: bool = false
var active_stele: DemonSealingStele = null

var _bg: Node = null
var _player: Node2D = null
var _spawner: Node = null
var _anim_t: float = 0.0
var _last_stele_wave: int = 0

func _ready() -> void:
	z_index = -4
	_resolve_refs.call_deferred()

func setup(bg: Node, player_node: Node2D, spawner_node: Node = null) -> void:
	_bg = bg
	_player = player_node
	_spawner = spawner_node
	_sync_from_background()
	activate_wave(1)

func _resolve_refs() -> void:
	var tree := get_tree()
	if tree == null:
		return
	if _bg == null:
		_bg = tree.get_first_node_in_group("background")
	if _player == null:
		_player = tree.get_first_node_in_group("player") as Node2D
	if _spawner == null:
		_spawner = tree.get_first_node_in_group("spawner")
	_sync_from_background()
	if active_array_index == -1 and not spirit_arrays.is_empty():
		activate_wave(1)

func _sync_from_background() -> void:
	if _bg == null or not _bg.has_method("get_landmarks_by_role"):
		return
	spirit_arrays = _bg.get_landmarks_by_role("spirit_array")
	demon_steles = _bg.get_landmarks_by_role("demon_stele")

func activate_wave(wave: int, stele_interval: int = 3) -> void:
	if spirit_arrays.is_empty():
		_sync_from_background()
	if not spirit_arrays.is_empty():
		active_array_index = (wave + randi()) % spirit_arrays.size()
	else:
		active_array_index = -1
	charge_progress = 0.0
	array_consumed = false

	var step := maxi(1, stele_interval)
	if wave >= step and wave % step == 0 and wave != _last_stele_wave:
		_last_stele_wave = wave
		spawn_stele(wave)
	queue_redraw()

func spawn_stele(wave: int = 3) -> DemonSealingStele:
	if demon_steles.is_empty():
		_sync_from_background()
	if demon_steles.is_empty():
		return null
	if active_stele != null and is_instance_valid(active_stele):
		return active_stele

	var idx: int = (wave / 3) % demon_steles.size()
	var pos: Vector2 = demon_steles[idx]["pos"]
	var stele := DemonSealingStele.new()
	stele.max_hp = 100.0 + float(wave) * 20.0
	stele.hp = stele.max_hp
	stele.global_position = pos
	stele.shattered.connect(_on_stele_shattered)
	var parent_node: Node = get_parent() if get_parent() != null else self
	parent_node.add_child(stele)
	active_stele = stele
	return stele

func _process(delta: float) -> void:
	_anim_t += delta
	if _player == null or not is_instance_valid(_player):
		var tree := get_tree()
		if tree != null:
			_player = tree.get_first_node_in_group("player") as Node2D
		return

	if active_array_index >= 0 and active_array_index < spirit_arrays.size() and not array_consumed:
		var arr_pos: Vector2 = spirit_arrays[active_array_index]["pos"]
		if _player.global_position.distance_to(arr_pos) <= ARRAY_TRIGGER_RADIUS:
			charge_progress += delta
			if charge_progress >= ARRAY_CHARGE_SEC:
				_trigger_spirit_array(arr_pos)
		else:
			charge_progress = maxf(0.0, charge_progress - delta * 0.6)
	queue_redraw()

func _trigger_spirit_array(arr_pos: Vector2) -> void:
	array_consumed = true
	charge_progress = ARRAY_CHARGE_SEC
	if _player.has_method("apply_temp_buff"):
		_player.apply_temp_buff(6.0, 0.25, ARRAY_BUFF_SEC)
	if _player.has_method("heal"):
		var max_hp: float = float(_player.get("max_health")) if "max_health" in _player else 100.0
		_player.heal(max_hp * 0.15)
	if has_node("/root/Sfx"):
		get_node("/root/Sfx").call("play", "level_up", -4.0)
	var tree := get_tree()
	if tree != null:
		tree.call_group("ui", "show_banner", "【聚灵阵共鸣】回血 15% · 伤害 +25% · 攻速 +30%（持续 8 秒）")
	spirit_array_triggered.emit(arr_pos)

func _on_stele_shattered(pos: Vector2) -> void:
	active_stele = null
	var parent_node: Node = get_parent() if get_parent() != null else self
	if ResourceLoader.exists(CHEST_SCENE):
		var chest_scene := load(CHEST_SCENE) as PackedScene
		if chest_scene != null:
			var chest := chest_scene.instantiate() as Node2D
			chest.global_position = pos + Vector2(0.0, 68.0)
			parent_node.call_deferred("add_child", chest)
	if has_node("/root/Stats"):
		get_node("/root/Stats").call("add_spirit_stones", 15)
	for i in range(3):
		var ang: float = TAU * float(i) / 3.0
		var e_type := Enemy.Type.ELITE if i == 0 else Enemy.Type.MINION
		var dist := 260.0 if i == 0 else 200.0
		var delay := 1.25 if i == 0 else 0.95
		var raid_pos: Vector2 = pos + Vector2(cos(ang), sin(ang)) * dist
		if _spawner != null and _spawner.has_method("spawn_telegraphed_enemy"):
			_spawner.spawn_telegraphed_enemy(raid_pos, e_type, delay)
		else:
			var tele := SpawnTelegraph.new()
			tele.setup(raid_pos, delay, 42.0 if e_type == Enemy.Type.ELITE else 30.0, Callable())
			parent_node.add_child(tele)
	var tree := get_tree()
	if tree != null:
		tree.call_group("ui", "show_banner", "【镇魔碑碎裂 · 天机宝箱降世！】")
	stele_shattered.emit(pos)

func _draw() -> void:
	if active_array_index < 0 or active_array_index >= spirit_arrays.size() or array_consumed:
		return
	var pos: Vector2 = spirit_arrays[active_array_index]["pos"]
	var pulse: float = 0.65 + 0.35 * sin(_anim_t * 4.0)
	draw_circle(pos, ARRAY_TRIGGER_RADIUS, Color(0.18, 0.88, 0.72, 0.14 * pulse))
	draw_arc(pos, ARRAY_TRIGGER_RADIUS, 0.0, TAU, 48, Color(0.28, 0.96, 0.80, 0.55 * pulse), 2.8)
	if charge_progress > 0.0:
		var ratio: float = clampf(charge_progress / ARRAY_CHARGE_SEC, 0.0, 1.0)
		draw_arc(pos, ARRAY_TRIGGER_RADIUS * 0.78, -PI * 0.5, -PI * 0.5 + TAU * ratio, 48, Color(0.98, 0.86, 0.36, 0.88), 4.5)
	var font := ThemeDB.fallback_font
	if font != null:
		var main_txt := "聚灵充能中 %.1fs" % maxf(0.0, ARRAY_CHARGE_SEC - charge_progress) if charge_progress > 0.0 else "聚灵阵（站入 2.5 秒触发）"
		var sub_txt := "回血15% · 伤害+25% · 攻速+30%"
		var vp := get_viewport()
		var view_tl := Vector2.ZERO
		var view_br := Vector2(1280.0, 720.0)
		if vp != null:
			var inv := vp.get_canvas_transform().affine_inverse()
			view_tl = inv * Vector2.ZERO
			view_br = inv * vp.get_visible_rect().size
		var text_x := clampf(pos.x - 130.0, view_tl.x + 8.0, maxf(view_tl.x + 8.0, view_br.x - 268.0))
		var text_top := clampf(pos.y - ARRAY_TRIGGER_RADIUS - 44.0, view_tl.y + 8.0, maxf(view_tl.y + 8.0, view_br.y - 52.0))
		var main_pos := Vector2(text_x, text_top + 18.0)
		var sub_pos := Vector2(text_x, text_top + 36.0)
		draw_string(font, main_pos + Vector2(1.0, 1.0), main_txt, HORIZONTAL_ALIGNMENT_CENTER, 260.0, 16, Color(0.04, 0.10, 0.09, 0.92))
		draw_string(font, main_pos, main_txt, HORIZONTAL_ALIGNMENT_CENTER, 260.0, 16, Color(0.98, 0.92, 0.45, 0.98))
		draw_string(font, sub_pos + Vector2(1.0, 1.0), sub_txt, HORIZONTAL_ALIGNMENT_CENTER, 260.0, 13, Color(0.04, 0.10, 0.09, 0.92))
		draw_string(font, sub_pos, sub_txt, HORIZONTAL_ALIGNMENT_CENTER, 260.0, 13, Color(0.42, 0.98, 0.84, 0.96))
