extends Node2D

const DUMMY_SCENE: PackedScene = preload("res://scenes/training_dummy.tscn")
const ENEMY_SCENE_PATH := "res://scenes/enemy.tscn"

@onready var player: Player = $Player
@onready var ui = $UI
@onready var background = $Background

var debug_sandbox: V2DebugSandbox = null
var kill_count: int = 0
var _loader: V2DataLoader = null
var _debug_hud_layer: CanvasLayer = null
var _telemetry_lbl: Label = null
var _quick_invincible_btn: Button = null

func _ready() -> void:
	add_to_group("game_manager")
	GameFlow.sync_after_scene_load(GameFlow.State.PLAYING)
	ObjectPools.clear()
	BgmDirector.play_stage(Stats.selected_stage_id)

	_loader = V2DataLoader.new()
	_loader.load_all("res://data/v2")

	if player != null:
		player.health_changed.connect(ui.update_health)
		player.exp_changed.connect(ui.update_exp)
		player.died.connect(_on_player_died)
		player.debug_invincible = true
		if "v2_combat" in player and player.v2_combat != null:
			var v2: V2CombatController = player.v2_combat
			v2.v2_loadout_changed.connect(_refresh_hud_loadout)
			v2.gold_changed.connect(ui.update_gold)
			v2.unlocked_weapon_slots = v2.get_max_weapon_slots()
			if v2.orbit_rig != null:
				v2.orbit_rig.set_unlocked_slots(v2.unlocked_weapon_slots)
			ui.update_gold(v2.run_gold)

	switch_stage(Stats.selected_stage_id)
	_refresh_hud_loadout()

	debug_sandbox = V2DebugSandbox.new()
	debug_sandbox.name = "V2DebugSandbox"
	add_child(debug_sandbox)
	debug_sandbox.setup(self, player, null)
	debug_sandbox.closed.connect(_refresh_quick_bar)

	_build_debug_quick_bar()
	call_deferred("_spawn_initial_dummies")

func _exit_tree() -> void:
	if _loader != null and is_instance_valid(_loader):
		_loader.free()
	_loader = null

func _refresh_hud_loadout() -> void:
	if ui == null or player == null:
		return
	if "v2_combat" in player and player.v2_combat != null and ui.has_method("refresh_v2_loadout"):
		ui.refresh_v2_loadout(player.v2_combat)

func switch_stage(stage_id: int) -> void:
	var chapters := ChapterData.all()
	var idx := clampi(stage_id - 1, 0, maxi(0, chapters.size() - 1))
	var ch: Dictionary = chapters[idx] if not chapters.is_empty() else {}
	BgmDirector.play_stage(stage_id)
	if background != null and background.has_method("apply_chapter") and not ch.is_empty():
		background.apply_chapter(ch)
	var st_name := String(ch.get("name", "演武沙盒"))
	if ui != null and ui.has_method("set_chapter"):
		ui.set_chapter({"id": 1, "name": "实验靶场 · %s" % st_name, "duration": 9999.0})

func _spawn_initial_dummies() -> void:
	spawn_dummies(3, TrainingDummy.ResetMode.INFINITE)
	_refresh_quick_bar()
	if ui != null and ui.has_method("show_banner"):
		ui.show_banner("【演武沙盒】右上实验台实时调参 · F9 收起/展开")

func spawn_dummies(count: int, mode: int = TrainingDummy.ResetMode.INFINITE, hp: float = 5000.0) -> void:
	if player == null or not is_instance_valid(player):
		return
	for i in range(count):
		var spread_ang := 0.0 if count <= 1 else -PI * 0.35 + float(i) / float(count - 1) * PI * 0.70
		var pos := _clamp_to_arena(player.global_position + Vector2(cos(spread_ang), sin(spread_ang)) * 185.0)
		var dummy := DUMMY_SCENE.instantiate() as TrainingDummy
		if dummy == null:
			continue
		dummy.global_position = pos
		add_child(dummy)
		dummy.setup_dummy(hp, mode)

func spawn_specimen(arch_id: String) -> void:
	if player == null or not is_instance_valid(player) or _loader == null:
		return
	if not _loader.enemy_archetypes.has(arch_id):
		return
	var arch: Dictionary = _loader.enemy_archetypes[arch_id]
	var enemy := ObjectPools.acquire(ENEMY_SCENE_PATH, self, 250) as Enemy
	if enemy == null:
		return
	enemy.global_position = _clamp_to_arena(player.global_position + Vector2(220.0, randf_range(-60.0, 60.0)))
	enemy.setup_type(Enemy.Type.MINION, 0.0, int(arch.get("species", 0)))
	enemy.apply_archetype(arch, 1)
	var raw_hp := float(arch.get("base_hp", 40.0))
	enemy.max_health = raw_hp
	enemy.current_health = raw_hp
	enemy.speed = float(arch.get("move_speed", 110.0))
	enemy.contact_damage = float(arch.get("base_dmg", 8.0))

func reset_dummies() -> void:
	for n in get_tree().get_nodes_in_group("enemies"):
		if n is TrainingDummy and is_instance_valid(n):
			(n as TrainingDummy).reset_stats()

func clear_dummies() -> void:
	for n in get_tree().get_nodes_in_group("enemies"):
		if n is TrainingDummy and is_instance_valid(n):
			n.queue_free()

func clear_all_targets() -> void:
	for n in get_tree().get_nodes_in_group("enemies"):
		if n == null or not is_instance_valid(n):
			continue
		if n is TrainingDummy:
			n.queue_free()
		else:
			ObjectPools.release(n)

func _clamp_to_arena(pos: Vector2) -> Vector2:
	if background != null and background.has_method("get_arena_rect"):
		var arena: Rect2 = (background.get_arena_rect() as Rect2).grow(-56.0)
		return Vector2(clampf(pos.x, arena.position.x, arena.end.x), clampf(pos.y, arena.position.y, arena.end.y))
	return pos

func _build_debug_quick_bar() -> void:
	_debug_hud_layer = CanvasLayer.new()
	_debug_hud_layer.name = "DebugQuickLayer"
	_debug_hud_layer.layer = 20
	add_child(_debug_hud_layer)

	var tele_plate := PanelContainer.new()
	tele_plate.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	tele_plate.offset_left = -450.0
	tele_plate.offset_right = -14.0
	tele_plate.offset_top = -102.0
	tele_plate.offset_bottom = -68.0
	tele_plate.add_theme_stylebox_override("panel", XianxiaUITheme.make_hud_plate(XianxiaUITheme.COL_PLATE_DARK, XianxiaUITheme.COL_GOLD_SOFT, 6, 8))
	_debug_hud_layer.add_child(tele_plate)

	_telemetry_lbl = Label.new()
	_telemetry_lbl.text = "木桩遥测 · 3秒DPS: 0 | 总伤: 0 | 命中: 0 | 反应: 0"
	_telemetry_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_telemetry_lbl.add_theme_font_size_override("font_size", 13)
	_telemetry_lbl.add_theme_color_override("font_color", XianxiaUITheme.COL_WARM_TEXT)
	tele_plate.add_child(_telemetry_lbl)

	var plate := PanelContainer.new()
	plate.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	plate.offset_left = -450.0
	plate.offset_right = -14.0
	plate.offset_top = -60.0
	plate.offset_bottom = -14.0
	plate.add_theme_stylebox_override("panel", XianxiaUITheme.make_hud_plate(XianxiaUITheme.COL_PLATE_BG, XianxiaUITheme.COL_GOLD, 8, 8))
	_debug_hud_layer.add_child(plate)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	plate.add_child(hb)

	var panel_btn := Button.new()
	panel_btn.text = "实验台 (F9)"
	panel_btn.focus_mode = Control.FOCUS_NONE
	panel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	XianxiaUITheme.style_button(panel_btn, "primary")
	panel_btn.pressed.connect(toggle_debug_sandbox)
	hb.add_child(panel_btn)

	var reset_btn := Button.new()
	reset_btn.text = "重置木桩"
	reset_btn.focus_mode = Control.FOCUS_NONE
	reset_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	XianxiaUITheme.style_button(reset_btn, "dark_gold")
	reset_btn.pressed.connect(_on_reset_or_respawn_dummies)
	hb.add_child(reset_btn)

	_quick_invincible_btn = Button.new()
	_quick_invincible_btn.text = "无敌: 开"
	_quick_invincible_btn.focus_mode = Control.FOCUS_NONE
	_quick_invincible_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	XianxiaUITheme.style_button(_quick_invincible_btn, "primary")
	_quick_invincible_btn.pressed.connect(func():
		if player != null:
			player.debug_invincible = not player.debug_invincible
		_refresh_quick_bar()
	)
	hb.add_child(_quick_invincible_btn)

	var exit_btn := Button.new()
	exit_btn.text = "回主菜单"
	exit_btn.focus_mode = Control.FOCUS_NONE
	exit_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	XianxiaUITheme.style_button(exit_btn, "cinnabar")
	exit_btn.pressed.connect(func():
		ObjectPools.clear()
		GameFlow.to_title()
	)
	hb.add_child(exit_btn)

func _on_reset_or_respawn_dummies() -> void:
	for n in get_tree().get_nodes_in_group("enemies"):
		if n is TrainingDummy and is_instance_valid(n):
			reset_dummies()
			return
	spawn_dummies(3, TrainingDummy.ResetMode.INFINITE)

func _refresh_quick_bar() -> void:
	if _quick_invincible_btn != null and player != null:
		_quick_invincible_btn.text = "无敌: %s" % ("开" if player.debug_invincible else "关")
		XianxiaUITheme.style_button(_quick_invincible_btn, "primary" if player.debug_invincible else "secondary")

func _process(_delta: float) -> void:
	if _telemetry_lbl == null:
		return
	var sum_dps := 0.0
	var sum_tot := 0.0
	var sum_hits := 0
	for n in get_tree().get_nodes_in_group("enemies"):
		if n is TrainingDummy and is_instance_valid(n):
			var d := n as TrainingDummy
			sum_dps += d.dps
			sum_tot += d.total_damage
			sum_hits += d.hit_count
	var rx_cnt := 0
	if player != null and "v2_combat" in player and player.v2_combat != null:
		rx_cnt = int(player.v2_combat.reaction_count)
	_telemetry_lbl.text = "木桩遥测 · 3秒DPS: %.0f | 总伤: %.0f | 命中: %d | 反应: %d" % [sum_dps, sum_tot, sum_hits, rx_cnt]

func _input(event: InputEvent) -> void:
	if GameFlow.state != GameFlow.State.PLAYING:
		return
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo and k.keycode == KEY_F9:
			toggle_debug_sandbox()
			get_viewport().set_input_as_handled()

func toggle_debug_sandbox() -> void:
	if debug_sandbox != null and is_instance_valid(debug_sandbox):
		debug_sandbox.toggle_panel()

func open_debug_sandbox() -> void:
	if debug_sandbox != null and is_instance_valid(debug_sandbox):
		debug_sandbox.open_panel()

func _on_player_died() -> void:
	if player != null and is_instance_valid(player):
		player.current_health = player.max_health
		player.invuln_timer = 1.5
		player.emit_signal("health_changed", player.current_health, player.max_health)
	if ui != null and ui.has_method("show_banner"):
		ui.show_banner("【实验模式 · 气血已回满】")
