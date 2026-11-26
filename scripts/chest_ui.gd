extends CanvasLayer
class_name ChestUI

signal closed

enum AnimState {
	HIDDEN,
	SHAKE,
	FOUNTAIN,
	REVEAL,
	READY,
}

const TEX_CHEST: Texture2D = preload("res://assets/props/treasure_chest.png")
const TEX_POUCH: Texture2D = preload("res://assets/sprites/pickup_spirit_pouch.png")
const TEX_STAR: Texture2D = preload("res://addons/kenney_particle_pack/star_06.png")
const TEX_LIGHT: Texture2D = preload("res://addons/kenney_particle_pack/light_01.png")

const SHAKE_DURATION := 0.36
const REVEAL_STEP_SEC := 0.28
const SKIP_GRACE_MSEC := 180
const CONFIRM_GRACE_MSEC := 220

var is_showing: bool = false
var anim_state: AnimState = AnimState.HIDDEN

var _opened_msec: int = 0
var _ready_msec: int = 0
var _state_elapsed: float = 0.0
var _fountain_duration: float = 0.85
var _fountain_emit_accum: float = 0.0
var _fountain_sfx_accum: float = 0.0
var _stones_target: int = 0
var _stones_shown: int = 0
var _chest_tier: int = 1
var _revealed_count: int = 0
var _cards: Array[Control] = []
var _card_tweens: Array[Tween] = []
var _panel_tween: Tween = null
var _chest_base_pos: Vector2 = Vector2.ZERO
var _has_chest_base_pos: bool = false

var _stone_banner: CenterContainer = null
var _stone_pill: PanelContainer = null
var _stone_label: Label = null
var _glow_layer: ChestGlowLayer = null
var _fx_layer: ChestFxLayer = null

@onready var dim: ColorRect = $Dim
@onready var panel: Panel = $Panel
@onready var vbox: VBoxContainer = $Panel/VBox
@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var subtitle_label: Label = $Panel/VBox/SubtitleLabel
@onready var chest_icon: TextureRect = $Panel/VBox/ChestHolder/ChestIcon
@onready var reward_box: HBoxContainer = $Panel/VBox/RewardBox
@onready var confirm_btn: Button = $Panel/VBox/ConfirmHolder/ConfirmButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_set_anim_state(AnimState.HIDDEN)

	panel.offset_top = -286.0
	panel.offset_bottom = 286.0
	panel.add_theme_stylebox_override("panel", XianxiaUITheme.make_scroll_panel(XianxiaUITheme.COL_GOLD, 0))
	XianxiaUITheme.attach_ornaments(panel, XianxiaUITheme.COL_GOLD, 16.0, 7.0)

	var title_font = load("res://assets/title_font.tres")
	if title_font != null and title_label != null:
		title_label.add_theme_font_override("font", title_font)
	if title_label != null:
		title_label.add_theme_color_override("font_color", Color(0.76, 0.24, 0.12))
	if subtitle_label != null:
		subtitle_label.add_theme_color_override("font_color", Color(0.14, 0.36, 0.30))
	if chest_icon != null:
		chest_icon.texture = TEX_CHEST

	_setup_stone_banner()
	_setup_fx_layers()

	XianxiaUITheme.style_button(confirm_btn, "cinnabar")
	confirm_btn.focus_mode = Control.FOCUS_NONE
	confirm_btn.pressed.connect(_on_confirm_pressed)

func _setup_stone_banner() -> void:
	if vbox == null or reward_box == null:
		return
	_stone_banner = CenterContainer.new()
	_stone_banner.name = "StoneBanner"
	_stone_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_stone_pill = PanelContainer.new()
	_stone_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stone_pill.add_theme_stylebox_override(
		"panel",
		XianxiaUITheme.make_pill_style(Color(0.08, 0.20, 0.17, 0.94), XianxiaUITheme.COL_GOLD_BRIGHT, 2, 16, 18, 5)
	)
	_stone_banner.add_child(_stone_pill)

	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_theme_constant_override("separation", 8)
	_stone_pill.add_child(hb)

	var icon := TextureRect.new()
	icon.texture = TEX_POUCH
	icon.custom_minimum_size = Vector2(24, 24)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(icon)

	_stone_label = Label.new()
	_stone_label.text = "灵石 +0"
	_stone_label.add_theme_font_size_override("font_size", 20)
	_stone_label.add_theme_color_override("font_color", XianxiaUITheme.COL_GOLD_BRIGHT)
	XianxiaUITheme.apply_text_outline(_stone_label, 3)
	hb.add_child(_stone_label)

	vbox.add_child(_stone_banner)
	vbox.move_child(_stone_banner, reward_box.get_index())

func _setup_fx_layers() -> void:
	_glow_layer = ChestGlowLayer.new()
	_glow_layer.name = "ChestGlowLayer"
	_glow_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_glow_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_glow_layer)
	if panel != null:
		move_child(_glow_layer, panel.get_index())

	_fx_layer = ChestFxLayer.new()
	_fx_layer.name = "ChestFxLayer"
	_fx_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fx_layer)

func _set_anim_state(next: AnimState) -> void:
	anim_state = next
	is_showing = next != AnimState.HIDDEN
	_state_elapsed = 0.0
	if next == AnimState.READY:
		_ready_msec = Time.get_ticks_msec()
		if confirm_btn != null:
			confirm_btn.text = "收入囊中"
	elif next != AnimState.HIDDEN:
		if confirm_btn != null:
			confirm_btn.text = "点击或按空格跳过"

func _exit_tree() -> void:
	_kill_tweens()
	if _fx_layer != null:
		_fx_layer.clear_particles()

func _kill_tweens() -> void:
	if _panel_tween != null and _panel_tween.is_valid():
		_panel_tween.kill()
		_panel_tween = null
	for tw in _card_tweens:
		if tw != null and tw.is_valid():
			tw.kill()
	_card_tweens.clear()

func show_rewards(rewards: Array, stones_gained: int = 0, chest_tier: int = 0) -> void:
	var shown: Array = []
	for item in rewards:
		if item is Dictionary:
			shown.append(item)
	if shown.is_empty():
		shown.append({
			"is_evo": false,
			"title": "天机余韵",
			"subtitle": "机缘现世 · 灵气入怀",
			"desc": "宝箱灵气已尽数收入囊中，道行又深一分。",
			"icon": "res://assets/props/treasure_chest.png",
		})

	_kill_tweens()
	for c in reward_box.get_children():
		reward_box.remove_child(c)
		c.queue_free()
	_cards.clear()

	_stones_target = maxi(0, stones_gained)
	_stones_shown = 0
	_chest_tier = maxi(chest_tier, shown.size())
	_revealed_count = 0
	_fountain_emit_accum = 0.0
	_fountain_sfx_accum = 0.0
	_fountain_duration = 1.25 if _chest_tier >= 5 else (0.98 if _chest_tier >= 3 else 0.72)

	var is_evo := bool(shown[0].get("is_evo", false))
	if is_evo:
		title_label.text = "天机宝箱 · 法宝蜕变！"
		subtitle_label.text = "天机灵韵加持，法宝威能大盛！"
	elif _chest_tier >= 5:
		title_label.text = "天机宝箱 · 五福临门！"
		subtitle_label.text = "鸿运冲天，灵石喷涌，连获 5 重造化！"
	elif _chest_tier >= 3:
		title_label.text = "天机宝箱 · 三星报喜！"
		subtitle_label.text = "灵光大盛，爆出灵石与 3 重宝物！"
	else:
		title_label.text = "天机宝箱 · 机缘现世"
		subtitle_label.text = "斩妖除魔所得灵石奇珍"

	if _stone_banner != null and _stone_label != null:
		_stone_banner.visible = _stones_target > 0
		_stone_label.text = "灵石 +0"

	for item in shown:
		var card := _make_reward_card(item, shown.size())
		card.visible = true
		card.modulate = Color(1.0, 1.0, 1.0, 0.0)
		card.scale = Vector2(0.76, 0.76)
		reward_box.add_child(card)
		_cards.append(card)

	visible = true
	panel.visible = true
	panel.modulate = Color.WHITE
	reward_box.visible = true
	reward_box.modulate = Color.WHITE
	_opened_msec = Time.get_ticks_msec()

	if chest_icon != null:
		chest_icon.scale = Vector2.ONE
		chest_icon.rotation = 0.0
		_has_chest_base_pos = false

	if _glow_layer != null:
		_glow_layer.tier = _chest_tier
		_glow_layer.intensity = 0.25
		_glow_layer.queue_redraw()
	if _fx_layer != null:
		_fx_layer.clear_particles()

	panel.scale = Vector2(0.88, 0.88)
	panel.pivot_offset = panel.size * 0.5
	_panel_tween = create_tween()
	_panel_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_panel_tween.tween_property(panel, "scale", Vector2.ONE, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	Sfx.play("chest_open", -2.0)
	_set_anim_state(AnimState.SHAKE)

func _process(delta: float) -> void:
	if anim_state == AnimState.HIDDEN or not visible:
		return

	if _glow_layer != null:
		_glow_layer.origin = _get_chest_center()
		_glow_layer.anim_t += delta
		var target_int := 0.35 if anim_state == AnimState.SHAKE else (1.0 if anim_state in [AnimState.FOUNTAIN, AnimState.REVEAL] else 0.55)
		_glow_layer.intensity = lerpf(_glow_layer.intensity, target_int, minf(1.0, delta * 8.0))
		_glow_layer.queue_redraw()

	if _fx_layer != null:
		_fx_layer.step(delta)

	_state_elapsed += delta
	match anim_state:
		AnimState.SHAKE:
			_process_shake()
		AnimState.FOUNTAIN:
			_process_fountain(delta)
		AnimState.REVEAL:
			_process_reveal()
		AnimState.READY:
			if chest_icon != null:
				chest_icon.scale = chest_icon.scale.lerp(Vector2.ONE, minf(1.0, delta * 10.0))
				chest_icon.rotation = lerpf(chest_icon.rotation, 0.0, minf(1.0, delta * 12.0))

func _process_shake() -> void:
	var u := clampf(_state_elapsed / SHAKE_DURATION, 0.0, 1.0)
	if chest_icon != null:
		if not _has_chest_base_pos:
			_chest_base_pos = chest_icon.position
			_has_chest_base_pos = true
		chest_icon.pivot_offset = chest_icon.size * 0.5
		var amp := lerpf(4.0, 11.0, u)
		chest_icon.position = _chest_base_pos + Vector2(sin(_state_elapsed * 58.0) * amp, -u * 4.0)
		chest_icon.rotation = sin(_state_elapsed * 46.0) * 0.14 * (0.4 + 0.6 * u)
		chest_icon.scale = Vector2(1.0 + u * 0.14, 1.0 - u * 0.08)

	if _state_elapsed >= SHAKE_DURATION:
		if chest_icon != null and _has_chest_base_pos:
			chest_icon.position = _chest_base_pos
			chest_icon.rotation = 0.0
			chest_icon.scale = Vector2(1.30, 1.30)
		_burst_fountain_wave(20 if _chest_tier >= 5 else (14 if _chest_tier >= 3 else 10))
		Sfx.play_gem_pickup()
		_set_anim_state(AnimState.FOUNTAIN)

func _process_fountain(delta: float) -> void:
	if chest_icon != null:
		chest_icon.scale = chest_icon.scale.lerp(Vector2.ONE, minf(1.0, delta * 9.0))
	var u := clampf(_state_elapsed / _fountain_duration, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - u, 2.0)
	_stones_shown = int(round(float(_stones_target) * eased))
	if _stone_label != null:
		_stone_label.text = "灵石 +%d" % _stones_shown

	_fountain_emit_accum += delta
	var emit_interval := 0.025 if _chest_tier >= 5 else 0.036
	while _fountain_emit_accum >= emit_interval and u < 0.88:
		_fountain_emit_accum -= emit_interval
		_burst_fountain_wave(3 if _chest_tier >= 5 else 2)

	_fountain_sfx_accum += delta
	if _stones_target > 0 and _fountain_sfx_accum >= 0.085 and u < 0.90:
		_fountain_sfx_accum = 0.0
		Sfx.play_gem_pickup()

	if _state_elapsed >= _fountain_duration:
		_stones_shown = _stones_target
		if _stone_label != null:
			_stone_label.text = "灵石 +%d" % _stones_target
		_set_anim_state(AnimState.REVEAL)
		_reveal_card(0)

func _process_reveal() -> void:
	if _revealed_count < _cards.size():
		if _state_elapsed >= float(_revealed_count) * REVEAL_STEP_SEC:
			_reveal_card(_revealed_count)
	elif _state_elapsed >= float(_cards.size()) * REVEAL_STEP_SEC + 0.12:
		_set_anim_state(AnimState.READY)

func _reveal_card(idx: int) -> void:
	if idx < 0 or idx >= _cards.size() or idx < _revealed_count:
		return
	_revealed_count = idx + 1
	var card := _cards[idx]
	if card == null or not is_instance_valid(card):
		return
	card.pivot_offset = card.size * 0.5
	card.scale = Vector2(0.76, 0.76)
	card.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_parallel(true)
	tw.tween_property(card, "modulate:a", 1.0, 0.16)
	tw.tween_property(card, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_card_tweens.append(tw)

	if _fx_layer != null:
		var c_pos := card.get_global_rect().get_center()
		_fx_layer.spawn_card_burst(c_pos, _chest_tier >= 3)
	Sfx.play("level_up", -8.0, 1.0 + float(idx) * 0.08)

func skip_animation() -> void:
	if anim_state == AnimState.HIDDEN or anim_state == AnimState.READY:
		return
	_kill_tweens()
	if chest_icon != null:
		if _has_chest_base_pos:
			chest_icon.position = _chest_base_pos
		chest_icon.rotation = 0.0
		chest_icon.scale = Vector2.ONE
	_stones_shown = _stones_target
	if _stone_label != null:
		_stone_label.text = "灵石 +%d" % _stones_target
	for card in _cards:
		if card != null and is_instance_valid(card):
			card.modulate = Color.WHITE
			card.scale = Vector2.ONE
	_revealed_count = _cards.size()
	if _fx_layer != null:
		_fx_layer.spawn_card_burst(_get_chest_center(), true)
	_set_anim_state(AnimState.READY)

func _get_chest_center() -> Vector2:
	if chest_icon != null and is_instance_valid(chest_icon):
		var r := chest_icon.get_global_rect()
		if r.size.x > 1.0:
			return r.get_center()
	return get_viewport().get_visible_rect().size * 0.5

func _burst_fountain_wave(count: int) -> void:
	if _fx_layer == null:
		return
	_fx_layer.spawn_stone_fountain(_get_chest_center(), count, _chest_tier)

func _make_reward_card(item: Dictionary, total_count: int) -> Control:
	var is_evo: bool = bool(item.get("is_evo", false))
	var card := PanelContainer.new()
	card.clip_contents = true
	var w := 420.0 if is_evo else (162.0 if total_count >= 5 else (238.0 if total_count >= 3 else 360.0))
	var h := 196.0 if total_count >= 5 else 210.0
	card.custom_minimum_size = Vector2(w, h)
	var card_bg := Color(1.0, 0.96, 0.86, 1.0) if is_evo else XianxiaUITheme.COL_PAPER_CARD
	var card_border := Color(0.88, 0.34, 0.18, 1.0) if is_evo else XianxiaUITheme.COL_JADE
	card.add_theme_stylebox_override("panel", XianxiaUITheme.make_card_style(card_bg, card_border, 2, 10, 10))

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 6)
	card.add_child(vb)

	var icon_path := str(item.get("icon", ""))
	if icon_path != "" and ResourceLoader.exists(icon_path):
		var holder := CenterContainer.new()
		var badge := PanelContainer.new()
		var badge_border := XianxiaUITheme.COL_GOLD_BRIGHT if is_evo else XianxiaUITheme.COL_JADE
		badge.add_theme_stylebox_override(
			"panel",
			XianxiaUITheme.make_flat_box(XianxiaUITheme.COL_PLATE_DARK, badge_border, 2, 8, 5)
		)
		var tr := TextureRect.new()
		tr.texture = load(icon_path)
		tr.custom_minimum_size = Vector2(46, 46)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		badge.add_child(tr)
		holder.add_child(badge)
		vb.add_child(holder)

	var name_lbl := Label.new()
	name_lbl.text = str(item.get("title", ""))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.custom_minimum_size = Vector2(10, 0)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.add_theme_font_size_override("font_size", 22 if is_evo else (17 if total_count >= 5 else 18))
	name_lbl.add_theme_color_override("font_color", XianxiaUITheme.COL_CINNABAR if is_evo else XianxiaUITheme.COL_INK)
	vb.add_child(name_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = str(item.get("subtitle", ""))
	sub_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub_lbl.custom_minimum_size = Vector2(10, 0)
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub_lbl.add_theme_font_size_override("font_size", 14)
	sub_lbl.add_theme_color_override("font_color", Color(0.68, 0.44, 0.10))
	vb.add_child(sub_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = str(item.get("desc", ""))
	desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_lbl.custom_minimum_size = Vector2(10, 0)
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 14 if total_count >= 5 else 16)
	desc_lbl.add_theme_color_override("font_color", XianxiaUITheme.COL_INK_MUTED)
	vb.add_child(desc_lbl)

	return card

func _input(event: InputEvent) -> void:
	if anim_state == AnimState.HIDDEN or not visible:
		return
	var now := Time.get_ticks_msec()
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and anim_state != AnimState.READY:
			if now - _opened_msec >= SKIP_GRACE_MSEC:
				get_viewport().set_input_as_handled()
				skip_animation()
		return
	if not (event is InputEventKey):
		return
	var ke := event as InputEventKey
	if not ke.pressed or ke.echo:
		return
	if ke.keycode == KEY_SPACE or ke.keycode == KEY_ENTER or ke.keycode == KEY_KP_ENTER:
		get_viewport().set_input_as_handled()
		if anim_state != AnimState.READY:
			if now - _opened_msec >= SKIP_GRACE_MSEC:
				skip_animation()
		else:
			if now - _ready_msec >= CONFIRM_GRACE_MSEC:
				_on_confirm()

func _on_confirm_pressed() -> void:
	if anim_state == AnimState.HIDDEN:
		return
	var now := Time.get_ticks_msec()
	if anim_state != AnimState.READY:
		if now - _opened_msec >= SKIP_GRACE_MSEC:
			skip_animation()
		return
	if now - _ready_msec >= CONFIRM_GRACE_MSEC:
		_on_confirm()

func _on_confirm() -> void:
	if anim_state == AnimState.HIDDEN:
		return
	hide_panel()
	emit_signal("closed")

func hide_panel() -> void:
	_kill_tweens()
	if _fx_layer != null:
		_fx_layer.clear_particles()
	visible = false
	_set_anim_state(AnimState.HIDDEN)

class ChestGlowLayer extends Control:
	var origin: Vector2 = Vector2(640, 360)
	var anim_t: float = 0.0
	var intensity: float = 0.0
	var tier: int = 1

	func _draw() -> void:
		if intensity <= 0.02:
			return
		var ray_count := 10 if tier >= 5 else (8 if tier >= 3 else 6)
		var base_col := Color(1.0, 0.48, 0.22) if tier >= 5 else (Color(1.0, 0.84, 0.34) if tier >= 3 else Color(0.95, 0.82, 0.42))
		var max_r := 620.0 if tier >= 5 else 480.0
		for i in range(ray_count):
			var ang := anim_t * 0.55 + TAU * float(i) / float(ray_count)
			var half_w := 0.11 if tier >= 5 else 0.09
			var p1 := origin + Vector2.from_angle(ang - half_w) * max_r
			var p2 := origin + Vector2.from_angle(ang + half_w) * max_r
			var col := Color(base_col.r, base_col.g, base_col.b, 0.13 * intensity)
			draw_colored_polygon(PackedVector2Array([origin, p1, p2]), col)
		if TEX_LIGHT != null:
			var r := 200.0 + sin(anim_t * 4.5) * 18.0
			draw_texture_rect(TEX_LIGHT, Rect2(origin - Vector2(r, r), Vector2(r * 2.0, r * 2.0)), false, Color(base_col.r, base_col.g, base_col.b, 0.28 * intensity))

class ChestFxLayer extends Control:
	var _particles: Array[Dictionary] = []

	func clear_particles() -> void:
		_particles.clear()
		queue_redraw()

	func spawn_stone_fountain(origin: Vector2, count: int, tier: int) -> void:
		var spd_mult := 1.20 if tier >= 5 else (1.08 if tier >= 3 else 0.95)
		for _i in range(count):
			var vx := randf_range(-280.0, 280.0) * spd_mult
			var vy := randf_range(-640.0, -340.0) * spd_mult
			var life := randf_range(0.68, 1.15)
			var is_gold := randf() < 0.72
			_particles.append({
				"kind": "stone",
				"pos": origin + Vector2(randf_range(-16.0, 16.0), randf_range(-8.0, 4.0)),
				"vel": Vector2(vx, vy),
				"gravity": 980.0,
				"age": 0.0,
				"life": life,
				"size": randf_range(8.0, 14.0),
				"rot": randf() * TAU,
				"spin": randf_range(-10.0, 10.0),
				"color": Color(1.0, 0.86, 0.34) if is_gold else Color(0.32, 0.94, 0.74),
			})
		queue_redraw()

	func spawn_card_burst(center: Vector2, high_tier: bool) -> void:
		var cnt := 14 if high_tier else 9
		for i in range(cnt):
			var ang := TAU * float(i) / float(cnt) + randf_range(-0.2, 0.2)
			var spd := randf_range(120.0, 260.0)
			_particles.append({
				"kind": "spark",
				"pos": center,
				"vel": Vector2.from_angle(ang) * spd,
				"gravity": 160.0,
				"age": 0.0,
				"life": randf_range(0.32, 0.52),
				"size": randf_range(10.0, 18.0),
				"rot": ang,
				"spin": randf_range(-6.0, 6.0),
				"color": Color(1.0, 0.88, 0.38),
			})
		queue_redraw()

	func step(delta: float) -> void:
		if _particles.is_empty():
			return
		for i in range(_particles.size() - 1, -1, -1):
			var p := _particles[i]
			p["age"] = float(p["age"]) + delta
			if float(p["age"]) >= float(p["life"]):
				_particles.remove_at(i)
				continue
			var vel: Vector2 = p["vel"]
			vel.y += float(p["gravity"]) * delta
			p["vel"] = vel
			p["pos"] = (p["pos"] as Vector2) + vel * delta
			p["rot"] = float(p["rot"]) + float(p["spin"]) * delta
		queue_redraw()

	func _draw() -> void:
		for p in _particles:
			var u := clampf(float(p["age"]) / maxf(0.01, float(p["life"])), 0.0, 1.0)
			var alpha := 1.0 - pow(u, 2.2)
			var pos: Vector2 = p["pos"]
			var sz := float(p["size"]) * (1.0 - 0.25 * u)
			var col: Color = p["color"]
			col.a = alpha
			if String(p["kind"]) == "spark" and TEX_STAR != null:
				draw_set_transform(pos, float(p["rot"]), Vector2.ONE)
				draw_texture_rect(TEX_STAR, Rect2(-sz, -sz, sz * 2.0, sz * 2.0), false, col)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			else:
				var flip := absf(cos(float(p["rot"])))
				var hw := maxf(2.0, sz * 0.62 * flip)
				var hh := sz
				var pts := PackedVector2Array([
					pos + Vector2(0.0, -hh),
					pos + Vector2(hw, 0.0),
					pos + Vector2(0.0, hh),
					pos + Vector2(-hw, 0.0),
				])
				draw_colored_polygon(pts, col)
				draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color(1.0, 0.98, 0.86, alpha * 0.9), 1.4, true)
