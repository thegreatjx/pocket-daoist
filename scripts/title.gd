extends Control

const CIRCLE_AVATAR_SHADER := preload("res://shaders/circle_avatar.gdshader")
const LOTUS_PEDESTAL_PATH := "res://assets/v2/ui/lotus_pedestal.png"

const ELEM_BADGE := {
	"metal": {"label": "金系亲和", "short": "金", "color": Color(0.26, 0.92, 0.82)},
	"fire": {"label": "火系亲和", "short": "火", "color": Color(0.98, 0.45, 0.18)},
	"thunder": {"label": "雷系亲和", "short": "雷", "color": Color(0.96, 0.82, 0.26)},
	"water": {"label": "水系亲和", "short": "水", "color": Color(0.36, 0.88, 0.96)},
	"wood": {"label": "木系亲和", "short": "木", "color": Color(0.29, 0.87, 0.50)},
}

@onready var vbox: VBoxContainer = $LeftMenu/VBox
@onready var seal_stamp: PanelContainer = $LeftMenu/VBox/TitleRow/SealStamp
@onready var start_btn: Button = $LeftMenu/VBox/StartButton
@onready var debug_btn: Button = $TopRightBar/DebugSandboxModeButton
@onready var settings_btn: Button = $TopRightBar/SettingsButton
@onready var quit_btn: Button = $TopRightBar/QuitButton
@onready var best_plate: PanelContainer = $BottomLeftDock/BestPlate
@onready var best_label: Label = $BottomLeftDock/BestPlate/BestLabel
@onready var hint_row: HBoxContainer = $BottomLeftDock/HintRow

var settings_panel: SettingsPanel = null
var sect_panel: Control = null

var _stage_title_lbl: Label = null
var _stage_meta_lbl: Label = null
var _stage_clear_pill: PanelContainer = null
var _stage_clear_lbl: Label = null
var _sect_btn: Button = null
var _sect_stone_lbl: Label = null
var _stone_lbl: Label = null

var _char_title_lbl: Label = null
var _char_role_lbl: Label = null
var _char_desc_lbl: Label = null
var _char_trait_lbl: Label = null
var _char_elem_pill: PanelContainer = null
var _char_elem_lbl: Label = null
var _char_weapon_icon: TextureRect = null
var _char_weapon_lbl: Label = null
var _char_skill_lbl: Label = null
var _stat_hp_lbl: Label = null
var _stat_spd_lbl: Label = null
var _stat_crit_lbl: Label = null

var _hero_stage_view: HeroStageView = null
var _hero_cards: Dictionary = {}
var _top_tooltip_pill: PanelContainer = null
var _top_tooltip_lbl: Label = null

var _preload_started: bool = false
var _starting_game: bool = false
var _loading_overlay: ColorRect = null
var _loading_lbl: Label = null


class TopRightIconGlyph extends Control:
	var icon_kind: String = "settings"
	var glyph_color: Color = Color(0.99, 0.88, 0.56)

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		var c := size * 0.5
		match icon_kind:
			"debug":
				draw_line(c + Vector2(-7.0, 7.0), c + Vector2(7.0, -7.0), glyph_color, 2.0, true)
				draw_line(c + Vector2(-7.0, -7.0), c + Vector2(7.0, 7.0), glyph_color, 2.0, true)
				draw_line(c + Vector2(-5.5, 2.0), c + Vector2(-2.0, 5.5), glyph_color, 1.8, true)
				draw_line(c + Vector2(5.5, 2.0), c + Vector2(2.0, 5.5), glyph_color, 1.8, true)
			"settings":
				draw_arc(c, 5.2, 0.0, TAU, 24, glyph_color, 2.0, true)
				draw_circle(c, 2.0, glyph_color)
				for i in range(6):
					var ang := float(i) * TAU / 6.0
					var p0 := c + Vector2(cos(ang), sin(ang)) * 6.8
					var p1 := c + Vector2(cos(ang), sin(ang)) * 9.2
					draw_line(p0, p1, glyph_color, 2.2, true)
			"quit":
				draw_arc(c, 7.5, -PI * 0.30, PI * 1.30, 24, glyph_color, 2.0, true)
				draw_line(c + Vector2(0.0, -9.0), c + Vector2(0.0, -1.5), glyph_color, 2.2, true)


class ElementAuraLayer extends Node2D:
	var element_id: String = "thunder"
	var accent_color: Color = Color(0.96, 0.82, 0.26)
	var time_acc: float = 0.0
	var _sparks: Array[Dictionary] = []
	var _spark_cd: float = 0.4

	func set_element(elem: String, col: Color) -> void:
		element_id = elem
		accent_color = col
		_sparks.clear()
		_spark_cd = 0.25
		queue_redraw()

	func step(delta: float) -> void:
		time_acc += delta
		if element_id == "thunder":
			_spark_cd -= delta
			if _spark_cd <= 0.0:
				_spark_cd = randf_range(0.55, 1.35)
				var ang := randf_range(-PI * 0.82, -PI * 0.18)
				var rad := randf_range(76.0, 128.0)
				var origin := Vector2(cos(ang) * rad * 0.9, -150.0 + sin(ang) * rad * 0.7)
				var pts := PackedVector2Array([origin])
				var cur := origin
				for _s in range(4):
					cur += Vector2(randf_range(-18.0, 18.0), randf_range(-20.0, 12.0))
					pts.append(cur)
				_sparks.append({"pts": pts, "life": 0.22, "max_life": 0.22})
		var alive: Array[Dictionary] = []
		for sp in _sparks:
			var lf := float(sp["life"]) - delta
			if lf > 0.0:
				sp["life"] = lf
				alive.append(sp)
		_sparks = alive
		queue_redraw()

	func _draw() -> void:
		var center := Vector2(0.0, -172.0)
		var ring_r := 112.0
		var rot := time_acc * 0.18
		var ring_col := Color(accent_color.r, accent_color.g, accent_color.b, 0.24)
		var faint_col := Color(accent_color.r, accent_color.g, accent_color.b, 0.12)

		draw_arc(center, ring_r, 0.0, TAU, 64, faint_col, 1.4, true)
		draw_arc(center, ring_r * 0.84, 0.0, TAU, 56, faint_col, 1.0, true)
		for i in range(8):
			var a0 := rot + float(i) * TAU / 8.0
			draw_arc(center, ring_r, a0 - 0.16, a0 + 0.16, 10, ring_col, 2.2, true)
			var tick0 := center + Vector2(cos(a0), sin(a0)) * (ring_r * 0.84)
			var tick1 := center + Vector2(cos(a0), sin(a0)) * ring_r
			draw_line(tick0, tick1, faint_col, 1.2, true)

		if element_id == "metal":
			for i in range(3):
				var p := fmod(time_acc * 0.28 + float(i) / 3.0, 1.0)
				var sx := (float(i) - 1.0) * 56.0
				var sy := -52.0 - p * 230.0
				var a := sin(p * PI) * 0.45
				draw_line(Vector2(sx, sy), Vector2(sx, sy - 26.0), Color(0.76, 1.0, 0.92, a), 1.6, true)
		elif element_id == "fire":
			for i in range(5):
				var p := fmod(time_acc * 0.46 + float(i) * 0.21, 1.0)
				var ex := sin(time_acc * 1.9 + float(i) * 1.7) * 58.0
				var ey := -28.0 - p * 220.0
				draw_circle(Vector2(ex, ey), 2.8 * (1.0 - p * 0.5), Color(1.0, 0.62, 0.24, sin(p * PI) * 0.65))
		elif element_id == "water":
			for i in range(4):
				var p := fmod(time_acc * 0.30 + float(i) * 0.25, 1.0)
				var wx := cos(time_acc * 1.2 + float(i) * 1.6) * 68.0
				var wy := -40.0 - p * 210.0
				draw_arc(Vector2(wx, wy), 4.5 + p * 5.0, 0.0, TAU, 16, Color(0.55, 0.94, 1.0, sin(p * PI) * 0.42), 1.3, true)
		elif element_id == "thunder":
			for sp in _sparks:
				var alpha := float(sp["life"]) / float(sp["max_life"])
				var pts: PackedVector2Array = sp["pts"]
				draw_polyline(pts, Color(0.76, 0.58, 1.0, alpha * 0.82), 2.0, true)
				draw_polyline(pts, Color(1.0, 0.96, 0.82, alpha * 0.92), 1.0, true)


class HeroStageView extends Control:
	const TARGET_HERO_HEIGHT := 348.0
	const LOTUS_WIDTH := 248.0

	var lotus_node: Node2D = null
	var lotus_sprite: Sprite2D = null
	var aura_glow: Sprite2D = null
	var rune_layer: ElementAuraLayer = null
	var hero_anchor: Node2D = null
	var hero_sprite: Sprite2D = null
	var qi_particles: GPUParticles2D = null

	var _time: float = 0.0
	var _base_lotus_pos: Vector2 = Vector2.ZERO
	var _base_hero_scale: Vector2 = Vector2.ONE
	var _accent_color: Color = Color(0.96, 0.82, 0.26)
	var _switch_tween: Tween = null
	var _has_hero: bool = false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		lotus_node = Node2D.new()
		add_child(lotus_node)

		aura_glow = Sprite2D.new()
		aura_glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		aura_glow.position = Vector2(0.0, -172.0)
		var glow_mat := CanvasItemMaterial.new()
		glow_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		aura_glow.material = glow_mat
		aura_glow.texture = _build_aura_texture(_accent_color)
		lotus_node.add_child(aura_glow)

		rune_layer = ElementAuraLayer.new()
		lotus_node.add_child(rune_layer)

		lotus_sprite = Sprite2D.new()
		lotus_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		if ResourceLoader.exists(LOTUS_PEDESTAL_PATH):
			var ltex := load(LOTUS_PEDESTAL_PATH) as Texture2D
			lotus_sprite.texture = ltex
			if ltex != null and ltex.get_width() > 0:
				var ls := LOTUS_WIDTH / float(ltex.get_width())
				lotus_sprite.scale = Vector2(ls, ls)
		lotus_sprite.position = Vector2(0.0, 22.0)
		lotus_node.add_child(lotus_sprite)

		qi_particles = _build_lotus_qi_particles()
		lotus_node.add_child(qi_particles)

		hero_anchor = Node2D.new()
		lotus_node.add_child(hero_anchor)

		hero_sprite = Sprite2D.new()
		hero_sprite.centered = false
		hero_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		hero_anchor.add_child(hero_sprite)

		resized.connect(_reposition)
		_reposition()

	func _exit_tree() -> void:
		if _switch_tween != null and _switch_tween.is_valid():
			_switch_tween.kill()
		_switch_tween = null

	func _reposition() -> void:
		_base_lotus_pos = Vector2(roundf(size.x * 0.5), roundf(size.y * 0.81))
		if lotus_node != null:
			lotus_node.position = _base_lotus_pos

	func set_character(cfg: Dictionary, animate: bool) -> void:
		var sp_path := str(cfg.get("sprite", ""))
		var tex: Texture2D = load(sp_path) as Texture2D if (sp_path != "" and ResourceLoader.exists(sp_path)) else null
		var acc = cfg.get("accent_color", Color(0.96, 0.82, 0.26))
		if acc is Color:
			_accent_color = acc
		var elem := str(cfg.get("element_affinity", "thunder"))

		if aura_glow != null:
			aura_glow.texture = _build_aura_texture(_accent_color)
		if rune_layer != null:
			rune_layer.set_element(elem, _accent_color)
		if qi_particles != null and qi_particles.process_material is ParticleProcessMaterial:
			var pmat := qi_particles.process_material as ParticleProcessMaterial
			pmat.color = Color(_accent_color.r * 0.55 + 0.45, _accent_color.g * 0.55 + 0.45, _accent_color.b * 0.55 + 0.45, 0.88)

		var foot_arr: Array = cfg.get("foot_anchor", [256.0, 484.0])
		var fx := float(foot_arr[0]) if foot_arr.size() >= 2 else 256.0
		var fy := float(foot_arr[1]) if foot_arr.size() >= 2 else 484.0
		var body_h := maxf(180.0, fy - 34.0)
		var sc := TARGET_HERO_HEIGHT / body_h
		var target_scale := Vector2(sc, sc)

		if not animate or not _has_hero:
			_has_hero = true
			_base_hero_scale = target_scale
			if hero_sprite != null:
				hero_sprite.texture = tex
				hero_sprite.offset = Vector2(-fx, -fy)
				hero_sprite.scale = _base_hero_scale
			if hero_anchor != null:
				hero_anchor.position = Vector2.ZERO
				hero_anchor.modulate = Color.WHITE
			return

		if _switch_tween != null and _switch_tween.is_valid():
			_switch_tween.kill()

		_switch_tween = create_tween()
		_switch_tween.set_parallel(true)
		_switch_tween.tween_property(hero_anchor, "modulate:a", 0.0, 0.11)
		_switch_tween.tween_property(hero_anchor, "position:y", -14.0, 0.11)
		_switch_tween.tween_property(lotus_sprite, "position:y", 26.0, 0.11)

		_switch_tween.chain().tween_callback(func():
			_base_hero_scale = target_scale
			hero_sprite.texture = tex
			hero_sprite.offset = Vector2(-fx, -fy)
			hero_sprite.scale = _base_hero_scale
			hero_anchor.position = Vector2(0.0, -24.0)
			hero_anchor.modulate = Color(1.18, 1.12, 0.96, 0.0)
		)

		_switch_tween.chain().set_parallel(true)
		_switch_tween.tween_property(hero_anchor, "modulate", Color.WHITE, 0.22)
		_switch_tween.tween_property(hero_anchor, "position:y", 0.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_switch_tween.tween_property(lotus_sprite, "position:y", 22.0, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	func step(delta: float) -> void:
		_time += maxf(0.0, delta)
		if lotus_node != null:
			lotus_node.position.y = _base_lotus_pos.y + sin(_time * 1.55) * 4.5
		if hero_sprite != null:
			var breath := sin(_time * 2.35)
			hero_sprite.scale = Vector2(
				_base_hero_scale.x * (1.0 - breath * 0.0055),
				_base_hero_scale.y * (1.0 + breath * 0.0145)
			)
		if aura_glow != null:
			aura_glow.modulate.a = 0.56 + 0.14 * sin(_time * 1.9)
		if rune_layer != null:
			rune_layer.step(delta)

	func _build_aura_texture(col: Color) -> GradientTexture2D:
		var grad := Gradient.new()
		grad.colors = PackedColorArray([
			Color(col.r, col.g, col.b, 0.36),
			Color(col.r, col.g, col.b, 0.14),
			Color(col.r, col.g, col.b, 0.0),
		])
		grad.offsets = PackedFloat32Array([0.0, 0.50, 1.0])
		var gt := GradientTexture2D.new()
		gt.width = 360
		gt.height = 360
		gt.gradient = grad
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(0.5, 0.02)
		return gt

	func _build_lotus_qi_particles() -> GPUParticles2D:
		var p := GPUParticles2D.new()
		p.amount = 16
		p.lifetime = 3.2
		p.preprocess = 1.6
		p.position = Vector2(0.0, 8.0)

		var p_mat := CanvasItemMaterial.new()
		p_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		p.material = p_mat

		var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		for y in range(16):
			for x in range(16):
				var d := Vector2(float(x) - 7.5, float(y) - 7.5).length() / 7.5
				var a := clampf(1.0 - d, 0.0, 1.0)
				img.set_pixel(x, y, Color(1.0, 0.96, 0.80, a * a))
		p.texture = ImageTexture.create_from_image(img)

		var proc := ParticleProcessMaterial.new()
		proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		proc.emission_box_extents = Vector3(110.0, 14.0, 0.0)
		proc.direction = Vector3(0.0, -1.0, 0.0)
		proc.spread = 18.0
		proc.gravity = Vector3(0.0, -8.0, 0.0)
		proc.initial_velocity_min = 18.0
		proc.initial_velocity_max = 40.0
		proc.scale_min = 0.35
		proc.scale_max = 0.82
		proc.color = Color(0.98, 0.88, 0.52, 0.82)
		var alpha_grad := Gradient.new()
		alpha_grad.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0)])
		alpha_grad.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
		var alpha_ramp := GradientTexture1D.new()
		alpha_ramp.gradient = alpha_grad
		proc.alpha_curve = null
		proc.color_ramp = alpha_ramp
		p.process_material = proc
		return p


func _ready() -> void:
	GameFlow.sync_after_scene_load(GameFlow.State.TITLE)
	Music.play_track("title")
	_build_atmospheric_scrims()
	_build_peach_blossom_particles()
	_build_title_lockup()
	_build_stage_selector()
	_build_sect_button()
	_build_top_right_controls()
	_build_bottom_left_hints()
	_build_hero_showcase()
	_apply_qinglv_theme()
	_refresh_best()
	_refresh_character_ui(false)
	_refresh_stage_ui()
	start_btn.pressed.connect(_on_start_pressed)
	settings_btn.pressed.connect(_on_settings_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)
	debug_btn.pressed.connect(_on_debug_mode_pressed)
	_begin_scene_preload()

func _begin_scene_preload() -> void:
	if _preload_started or DisplayServer.get_name() == "headless":
		return
	_preload_started = true
	var status := ResourceLoader.load_threaded_get_status(GameFlow.GAME_SCENE)
	if status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		ResourceLoader.load_threaded_request(GameFlow.GAME_SCENE, "", true)

func _process(delta: float) -> void:
	if _hero_stage_view != null and is_instance_valid(_hero_stage_view):
		_hero_stage_view.step(delta)

	if not _starting_game:
		return
	var progress := []
	var status := ResourceLoader.load_threaded_get_status(GameFlow.GAME_SCENE, progress)
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		_starting_game = false
		var packed := ResourceLoader.load_threaded_get(GameFlow.GAME_SCENE) as PackedScene
		GameFlow.start_game_packed(packed)
	elif status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		if _loading_lbl != null and not progress.is_empty():
			var pct := clampi(roundi(float(progress[0]) * 100.0), 0, 99)
			_loading_lbl.text = "踏入秘境中… %d%%" % pct
	else:
		_starting_game = false
		GameFlow.start_game()

func _build_atmospheric_scrims() -> void:
	var left_grad := Gradient.new()
	left_grad.colors = PackedColorArray([
		Color(0.03, 0.10, 0.09, 0.56),
		Color(0.04, 0.11, 0.10, 0.22),
		Color(0.04, 0.11, 0.10, 0.0),
	])
	left_grad.offsets = PackedFloat32Array([0.0, 0.34, 1.0])
	var left_tex := GradientTexture2D.new()
	left_tex.gradient = left_grad
	left_tex.fill_from = Vector2(0.0, 0.5)
	left_tex.fill_to = Vector2(0.42, 0.5)

	var left_scrim := TextureRect.new()
	left_scrim.name = "LeftMistScrim"
	left_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	left_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_scrim.texture = left_tex
	left_scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(left_scrim)
	move_child(left_scrim, $Scrim.get_index() + 1)

	var bottom_grad := Gradient.new()
	bottom_grad.colors = PackedColorArray([
		Color(0.03, 0.09, 0.08, 0.38),
		Color(0.03, 0.09, 0.08, 0.0),
	])
	bottom_grad.offsets = PackedFloat32Array([0.0, 1.0])
	var bottom_tex := GradientTexture2D.new()
	bottom_tex.gradient = bottom_grad
	bottom_tex.fill_from = Vector2(0.5, 1.0)
	bottom_tex.fill_to = Vector2(0.5, 0.78)

	var bottom_scrim := TextureRect.new()
	bottom_scrim.name = "BottomMistScrim"
	bottom_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bottom_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_scrim.texture = bottom_tex
	bottom_scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(bottom_scrim)
	move_child(bottom_scrim, left_scrim.get_index() + 1)

func _build_peach_blossom_particles() -> void:
	var p := GPUParticles2D.new()
	p.name = "PeachBlossomParticles"
	p.amount = 10
	p.lifetime = 11.5
	p.preprocess = 5.0
	p.position = Vector2(760.0, -24.0)

	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in range(16):
		for x in range(16):
			var nx := (float(x) - 7.5) / 5.8
			var ny := (float(y) - 7.5) / 4.0
			var notch := 1.0 - maxf(0.0, (nx - 0.5) * 0.9)
			var d := sqrt(nx * nx + ny * ny) / maxf(0.3, notch)
			if d <= 1.0:
				var a := smoothstep(1.0, 0.65, d) * 0.88
				var col := Color(0.99, 0.72 + (1.0 - d) * 0.14, 0.78 + (1.0 - d) * 0.12, a)
				img.set_pixel(x, y, col)
	p.texture = ImageTexture.create_from_image(img)

	var proc := ParticleProcessMaterial.new()
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	proc.emission_box_extents = Vector3(580.0, 20.0, 0.0)
	proc.direction = Vector3(-0.55, 1.0, 0.0)
	proc.spread = 18.0
	proc.gravity = Vector3(-6.0, 4.0, 0.0)
	proc.initial_velocity_min = 38.0
	proc.initial_velocity_max = 68.0
	proc.angular_velocity_min = -45.0
	proc.angular_velocity_max = 55.0
	proc.scale_min = 0.65
	proc.scale_max = 1.05
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.85), Color(1, 1, 1, 0)])
	ramp.offsets = PackedFloat32Array([0.0, 0.15, 1.0])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	proc.color_ramp = ramp_tex
	p.process_material = proc

	add_child(p)
	move_child(p, $LeftMenu.get_index())

func _build_title_lockup() -> void:
	seal_stamp.add_theme_stylebox_override("panel", XianxiaUITheme.make_seal_stamp_style())
	var rule := ColorRect.new()
	rule.name = "TitleRule"
	rule.custom_minimum_size = Vector2(236, 1)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	rule.color = Color(XianxiaUITheme.COL_GOLD.r, XianxiaUITheme.COL_GOLD.g, XianxiaUITheme.COL_GOLD.b, 0.56)
	vbox.add_child(rule)
	vbox.move_child(rule, $LeftMenu/VBox/Spacer.get_index())

func _build_stage_selector() -> void:
	var card := PanelContainer.new()
	card.name = "StageSelector"
	card.clip_contents = true
	card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	card.custom_minimum_size = Vector2(348, 72)
	card.add_theme_stylebox_override("panel", XianxiaUITheme.make_translucent_scroll_plate(Color(0.05, 0.14, 0.12, 0.72), Color(XianxiaUITheme.COL_GOLD.r, XianxiaUITheme.COL_GOLD.g, XianxiaUITheme.COL_GOLD.b, 0.76), 10, 12, 8))
	XianxiaUITheme.attach_ornaments(card, Color(XianxiaUITheme.COL_GOLD.r, XianxiaUITheme.COL_GOLD.g, XianxiaUITheme.COL_GOLD.b, 0.78), 9.0, 4.0)

	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 8)
	card.add_child(hbox)

	var prev_btn := Button.new()
	prev_btn.text = "◀"
	prev_btn.custom_minimum_size = Vector2(32, 44)
	prev_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	prev_btn.focus_mode = Control.FOCUS_NONE
	prev_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	prev_btn.pressed.connect(func(): _shift_stage(-1))
	XianxiaUITheme.style_button(prev_btn, "dark_gold")
	hbox.add_child(prev_btn)

	var info_box := VBoxContainer.new()
	info_box.clip_contents = true
	info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info_box.add_theme_constant_override("separation", 3)
	hbox.add_child(info_box)

	var title_row := HBoxContainer.new()
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override("separation", 7)
	info_box.add_child(title_row)

	_stage_title_lbl = Label.new()
	_stage_title_lbl.add_theme_font_size_override("font_size", 17)
	_stage_title_lbl.add_theme_color_override("font_color", XianxiaUITheme.COL_GOLD_BRIGHT)
	XianxiaUITheme.apply_soft_shadow(_stage_title_lbl)
	title_row.add_child(_stage_title_lbl)

	_stage_clear_pill = PanelContainer.new()
	_stage_clear_pill.visible = false
	_stage_clear_pill.add_theme_stylebox_override("panel", XianxiaUITheme.make_pill_style(Color(0.14, 0.44, 0.34, 0.90), XianxiaUITheme.COL_EXP_FILL, 1, 8, 6, 1))
	_stage_clear_lbl = Label.new()
	_stage_clear_lbl.text = "已通关"
	_stage_clear_lbl.add_theme_font_size_override("font_size", 11)
	_stage_clear_lbl.add_theme_color_override("font_color", Color(0.88, 1.0, 0.93))
	_stage_clear_pill.add_child(_stage_clear_lbl)
	title_row.add_child(_stage_clear_pill)

	_stage_meta_lbl = Label.new()
	_stage_meta_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stage_meta_lbl.custom_minimum_size = Vector2(10, 0)
	_stage_meta_lbl.clip_text = true
	_stage_meta_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_stage_meta_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage_meta_lbl.add_theme_font_size_override("font_size", 12)
	_stage_meta_lbl.add_theme_color_override("font_color", Color(0.86, 0.95, 0.90, 0.94))
	info_box.add_child(_stage_meta_lbl)

	var next_btn := Button.new()
	next_btn.text = "▶"
	next_btn.custom_minimum_size = Vector2(32, 44)
	next_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	next_btn.focus_mode = Control.FOCUS_NONE
	next_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	next_btn.pressed.connect(func(): _shift_stage(1))
	XianxiaUITheme.style_button(next_btn, "dark_gold")
	hbox.add_child(next_btn)

	vbox.add_child(card)
	vbox.move_child(card, start_btn.get_index())

func _build_sect_button() -> void:
	_sect_btn = Button.new()
	_sect_btn.name = "SectButton"
	_sect_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_sect_btn.custom_minimum_size = Vector2(348, 44)
	_sect_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_sect_btn.text = ""
	_sect_btn.pressed.connect(_on_sect_pressed)

	var hb := HBoxContainer.new()
	hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 10)
	_sect_btn.add_child(hb)

	var title_lbl := Label.new()
	title_lbl.text = "宗门修炼"
	title_lbl.add_theme_font_size_override("font_size", 17)
	title_lbl.add_theme_color_override("font_color", XianxiaUITheme.COL_WARM_TEXT)
	XianxiaUITheme.apply_soft_shadow(title_lbl)
	hb.add_child(title_lbl)

	var pill := PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_theme_stylebox_override("panel", XianxiaUITheme.make_pill_style(Color(0.05, 0.14, 0.12, 0.85), XianxiaUITheme.COL_GOLD_SOFT, 1, 10, 9, 2))
	_sect_stone_lbl = Label.new()
	_sect_stone_lbl.add_theme_font_size_override("font_size", 12)
	_sect_stone_lbl.add_theme_color_override("font_color", XianxiaUITheme.COL_GOLD_BRIGHT)
	pill.add_child(_sect_stone_lbl)
	hb.add_child(pill)

	vbox.add_child(_sect_btn)
	vbox.move_child(_sect_btn, start_btn.get_index() + 1)

func _build_top_right_controls() -> void:
	var specs := [
		{"btn": debug_btn, "kind": "debug", "label": "演武调试"},
		{"btn": settings_btn, "kind": "settings", "label": "音画设置"},
		{"btn": quit_btn, "kind": "quit", "label": "暂退仙途"},
	]
	_top_tooltip_pill = PanelContainer.new()
	_top_tooltip_pill.visible = false
	_top_tooltip_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top_tooltip_pill.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_top_tooltip_pill.offset_left = -188.0
	_top_tooltip_pill.offset_right = -28.0
	_top_tooltip_pill.offset_top = 74.0
	_top_tooltip_pill.offset_bottom = 98.0
	_top_tooltip_pill.add_theme_stylebox_override("panel", XianxiaUITheme.make_pill_style(Color(0.05, 0.14, 0.12, 0.86), XianxiaUITheme.COL_GOLD_SOFT, 1, 10, 10, 2))
	_top_tooltip_lbl = Label.new()
	_top_tooltip_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_top_tooltip_lbl.add_theme_font_size_override("font_size", 12)
	_top_tooltip_lbl.add_theme_color_override("font_color", XianxiaUITheme.COL_WARM_TEXT)
	_top_tooltip_pill.add_child(_top_tooltip_lbl)
	add_child(_top_tooltip_pill)

	for item in specs:
		var b: Button = item["btn"]
		b.text = ""
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var glyph := TopRightIconGlyph.new()
		glyph.icon_kind = String(item["kind"])
		b.add_child(glyph)
		var tip := String(item["label"])
		b.mouse_entered.connect(func():
			if _top_tooltip_pill != null and _top_tooltip_lbl != null:
				_top_tooltip_lbl.text = tip
				_top_tooltip_pill.visible = true
		)
		b.mouse_exited.connect(func():
			if _top_tooltip_pill != null:
				_top_tooltip_pill.visible = false
		)

func _build_bottom_left_hints() -> void:
	best_plate.add_theme_stylebox_override("panel", XianxiaUITheme.make_translucent_scroll_plate(Color(0.04, 0.12, 0.10, 0.72), Color(XianxiaUITheme.COL_GOLD.r, XianxiaUITheme.COL_GOLD.g, XianxiaUITheme.COL_GOLD.b, 0.48), 8, 12, 5))

	var hint_bg := PanelContainer.new()
	hint_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_bg.add_theme_stylebox_override("panel", XianxiaUITheme.make_translucent_scroll_plate(Color(0.04, 0.11, 0.10, 0.64), Color(XianxiaUITheme.COL_GOLD.r, XianxiaUITheme.COL_GOLD.g, XianxiaUITheme.COL_GOLD.b, 0.28), 8, 10, 4))
	var inner_hb := HBoxContainer.new()
	inner_hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner_hb.add_theme_constant_override("separation", 5)
	hint_bg.add_child(inner_hb)

	_add_keycap_group(inner_hb, ["W", "A", "S", "D"], "移动")
	_add_hint_sep(inner_hb)
	_add_keycap_group(inner_hb, ["Space"], "踏云步")
	_add_hint_sep(inner_hb)
	_add_keycap_group(inner_hb, ["ESC"], "暂停")
	hint_row.add_child(hint_bg)

func _add_keycap_group(parent: HBoxContainer, keys: Array[String], label_txt: String) -> void:
	for k in keys:
		var cap := PanelContainer.new()
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cap.add_theme_stylebox_override("panel", XianxiaUITheme.make_keycap_style())
		var kl := Label.new()
		kl.text = k
		kl.add_theme_font_size_override("font_size", 11)
		kl.add_theme_color_override("font_color", XianxiaUITheme.COL_GOLD_BRIGHT)
		cap.add_child(kl)
		parent.add_child(cap)
	var desc := Label.new()
	desc.text = label_txt
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", Color(0.84, 0.94, 0.89, 0.92))
	parent.add_child(desc)

func _add_hint_sep(parent: HBoxContainer) -> void:
	var sep := Label.new()
	sep.text = "·"
	sep.add_theme_font_size_override("font_size", 12)
	sep.add_theme_color_override("font_color", Color(XianxiaUITheme.COL_GOLD.r, XianxiaUITheme.COL_GOLD.g, XianxiaUITheme.COL_GOLD.b, 0.6))
	parent.add_child(sep)

func _build_hero_showcase() -> void:
	# 居中偏右舞台：完全避开左侧菜单与右侧窄版卷轴，底部给圆形头像坞留足净空
	_hero_stage_view = HeroStageView.new()
	_hero_stage_view.name = "HeroStageView"
	_hero_stage_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hero_stage_view.anchor_left = 0.34
	_hero_stage_view.anchor_right = 0.76
	_hero_stage_view.offset_top = 36.0
	_hero_stage_view.offset_bottom = -124.0
	add_child(_hero_stage_view)
	move_child(_hero_stage_view, $SettingsLayer.get_index())

	# 右侧贴边修长竖版角色卷轴卡（彻底远离莲台）
	var dossier := PanelContainer.new()
	dossier.name = "HeroDossier"
	dossier.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	dossier.offset_left = -292.0
	dossier.offset_right = -24.0
	dossier.offset_top = -182.0
	dossier.offset_bottom = 198.0
	dossier.add_theme_stylebox_override("panel", XianxiaUITheme.make_translucent_scroll_plate(Color(0.05, 0.14, 0.13, 0.78), XianxiaUITheme.COL_GOLD, 12, 18, 16))
	XianxiaUITheme.attach_ornaments(dossier, XianxiaUITheme.COL_GOLD, 11.0, 5.0)
	add_child(dossier)
	move_child(dossier, $SettingsLayer.get_index())

	var d_vb := VBoxContainer.new()
	d_vb.add_theme_constant_override("separation", 9)
	dossier.add_child(d_vb)

	var head_row := HBoxContainer.new()
	head_row.add_theme_constant_override("separation", 8)
	d_vb.add_child(head_row)

	var name_vb := VBoxContainer.new()
	name_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_vb.add_theme_constant_override("separation", 1)
	head_row.add_child(name_vb)

	_char_title_lbl = Label.new()
	var tf = load("res://assets/title_font.tres")
	if tf != null:
		_char_title_lbl.add_theme_font_override("font", tf)
	_char_title_lbl.add_theme_font_size_override("font_size", 26)
	_char_title_lbl.add_theme_color_override("font_color", XianxiaUITheme.COL_GOLD_BRIGHT)
	XianxiaUITheme.apply_soft_shadow(_char_title_lbl)
	name_vb.add_child(_char_title_lbl)

	_char_role_lbl = Label.new()
	_char_role_lbl.add_theme_font_size_override("font_size", 13)
	_char_role_lbl.add_theme_color_override("font_color", Color(0.76, 0.92, 0.86, 0.92))
	name_vb.add_child(_char_role_lbl)

	_char_elem_pill = PanelContainer.new()
	_char_elem_pill.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_char_elem_lbl = Label.new()
	_char_elem_lbl.add_theme_font_size_override("font_size", 11)
	_char_elem_pill.add_child(_char_elem_lbl)
	head_row.add_child(_char_elem_pill)

	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(0, 1)
	rule.color = Color(XianxiaUITheme.COL_GOLD.r, XianxiaUITheme.COL_GOLD.g, XianxiaUITheme.COL_GOLD.b, 0.34)
	d_vb.add_child(rule)

	_char_desc_lbl = Label.new()
	_char_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_char_desc_lbl.add_theme_font_size_override("font_size", 13)
	_char_desc_lbl.add_theme_color_override("font_color", Color(0.88, 0.95, 0.91, 0.94))
	d_vb.add_child(_char_desc_lbl)

	var weapon_card := PanelContainer.new()
	weapon_card.add_theme_stylebox_override("panel", XianxiaUITheme.make_translucent_scroll_plate(Color(0.04, 0.10, 0.09, 0.65), XianxiaUITheme.COL_GOLD_SOFT, 8, 10, 8))
	d_vb.add_child(weapon_card)

	var weapon_row := HBoxContainer.new()
	weapon_row.add_theme_constant_override("separation", 9)
	weapon_card.add_child(weapon_row)

	var w_frame := PanelContainer.new()
	w_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	w_frame.add_theme_stylebox_override("panel", XianxiaUITheme.make_pill_style(XianxiaUITheme.COL_PLATE_DARK, XianxiaUITheme.COL_GOLD_SOFT, 1, 8, 4, 4))
	_char_weapon_icon = TextureRect.new()
	_char_weapon_icon.custom_minimum_size = Vector2(30, 30)
	_char_weapon_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_char_weapon_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	w_frame.add_child(_char_weapon_icon)
	weapon_row.add_child(w_frame)

	var w_vb := VBoxContainer.new()
	w_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	w_vb.add_theme_constant_override("separation", 2)
	weapon_row.add_child(w_vb)

	_char_weapon_lbl = Label.new()
	_char_weapon_lbl.add_theme_font_size_override("font_size", 13)
	_char_weapon_lbl.add_theme_color_override("font_color", XianxiaUITheme.COL_WARM_TEXT)
	w_vb.add_child(_char_weapon_lbl)

	_char_skill_lbl = Label.new()
	_char_skill_lbl.add_theme_font_size_override("font_size", 12)
	_char_skill_lbl.add_theme_color_override("font_color", Color(0.75, 0.90, 0.84, 0.92))
	w_vb.add_child(_char_skill_lbl)

	var stats_hb := HBoxContainer.new()
	stats_hb.add_theme_constant_override("separation", 6)
	d_vb.add_child(stats_hb)
	_stat_hp_lbl = _make_stat_chip(stats_hb, "气血")
	_stat_spd_lbl = _make_stat_chip(stats_hb, "移速")
	_stat_crit_lbl = _make_stat_chip(stats_hb, "暴击")

	_char_trait_lbl = Label.new()
	_char_trait_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_char_trait_lbl.add_theme_font_size_override("font_size", 12)
	_char_trait_lbl.add_theme_color_override("font_color", Color(0.56, 0.96, 0.80))
	d_vb.add_child(_char_trait_lbl)

	# 底部居中圆形玉佩头像坞（紧贴莲台下方，彻底让出左右桃花与山水）
	var dock_center := CenterContainer.new()
	dock_center.name = "CharacterDock"
	dock_center.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	dock_center.anchor_left = 0.34
	dock_center.anchor_right = 0.76
	dock_center.offset_top = -112.0
	dock_center.offset_bottom = -14.0
	dock_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dock_center)
	move_child(dock_center, $SettingsLayer.get_index())

	var roster_row := HBoxContainer.new()
	roster_row.name = "CharacterSelector"
	roster_row.alignment = BoxContainer.ALIGNMENT_CENTER
	roster_row.add_theme_constant_override("separation", 20)
	dock_center.add_child(roster_row)

	var chars := CharacterData.all()
	_hero_cards.clear()
	for c in chars:
		var cid := String(c.get("id", ""))
		var slot := Control.new()
		slot.custom_minimum_size = Vector2(76, 94)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var card_btn := Button.new()
		card_btn.name = "HeroCard_" + cid
		card_btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		card_btn.focus_mode = Control.FOCUS_NONE
		card_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card_btn.pressed.connect(func(): _select_character(cid))

		var vb := VBoxContainer.new()
		vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		vb.alignment = BoxContainer.ALIGNMENT_CENTER
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_theme_constant_override("separation", 4)
		card_btn.add_child(vb)

		var avatar_tr := TextureRect.new()
		avatar_tr.name = "AvatarPortrait"
		avatar_tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		avatar_tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		avatar_tr.custom_minimum_size = Vector2(64, 64)
		avatar_tr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		avatar_tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		avatar_tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

		var sp_path := String(c.get("sprite", ""))
		if sp_path != "" and ResourceLoader.exists(sp_path):
			var full_tex := load(sp_path) as Texture2D
			var reg_arr: Array = c.get("avatar_region", [164, 48, 200, 200])
			if full_tex != null and reg_arr.size() >= 4:
				var full_img := full_tex.get_image()
				if full_img != null:
					var rx := clampi(int(reg_arr[0]), 0, maxi(0, full_img.get_width() - 1))
					var ry := clampi(int(reg_arr[1]), 0, maxi(0, full_img.get_height() - 1))
					var rw := clampi(int(reg_arr[2]), 1, full_img.get_width() - rx)
					var rh := clampi(int(reg_arr[3]), 1, full_img.get_height() - ry)
					var sub_img := full_img.get_region(Rect2i(rx, ry, rw, rh))
					avatar_tr.texture = ImageTexture.create_from_image(sub_img)
				else:
					avatar_tr.texture = full_tex
			else:
				avatar_tr.texture = full_tex

		var smat := ShaderMaterial.new()
		smat.shader = CIRCLE_AVATAR_SHADER
		avatar_tr.material = smat
		vb.add_child(avatar_tr)

		var n_lbl := Label.new()
		n_lbl.name = "AvatarName"
		n_lbl.text = String(c.get("name", ""))
		n_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n_lbl.add_theme_font_size_override("font_size", 13)
		n_lbl.add_theme_color_override("font_color", XianxiaUITheme.COL_WARM_TEXT)
		XianxiaUITheme.apply_text_outline(n_lbl, 3, Color(0.03, 0.10, 0.08, 0.90))
		vb.add_child(n_lbl)

		slot.add_child(card_btn)
		roster_row.add_child(slot)
		_hero_cards[cid] = card_btn

func _make_stat_chip(parent: HBoxContainer, title_txt: String) -> Label:
	var box := PanelContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_stylebox_override("panel", XianxiaUITheme.make_translucent_scroll_plate(Color(0.04, 0.11, 0.10, 0.72), XianxiaUITheme.COL_GOLD_SOFT, 6, 6, 5))
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 1)
	box.add_child(vb)

	var t_lbl := Label.new()
	t_lbl.text = title_txt
	t_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t_lbl.add_theme_font_size_override("font_size", 11)
	t_lbl.add_theme_color_override("font_color", Color(0.72, 0.88, 0.82))
	vb.add_child(t_lbl)

	var v_lbl := Label.new()
	v_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v_lbl.add_theme_font_size_override("font_size", 15)
	v_lbl.add_theme_color_override("font_color", XianxiaUITheme.COL_GOLD_BRIGHT)
	vb.add_child(v_lbl)

	parent.add_child(box)
	return v_lbl

func _select_character(char_id: String) -> void:
	if Stats.selected_character_id == char_id:
		return
	Stats.selected_character_id = char_id
	Stats.save_stats()
	_refresh_character_ui(true)

func _refresh_character_ui(animate_switch: bool = false) -> void:
	if _char_title_lbl == null or _stat_hp_lbl == null:
		return
	var c := CharacterData.get_character(Stats.selected_character_id)
	var cid := str(c.get("id", ""))
	if Stats.selected_character_id != cid:
		Stats.selected_character_id = cid
		Stats.save_stats()

	var v2_wid := str(c.get("v2_start_weapon", "wpn_jade_sword"))
	var w_info := _load_v2_weapon_info(v2_wid)
	var w_name := str(w_info.get("name", "青霜飞剑"))
	var w_icon_path := str(w_info.get("icon", ""))

	if _hero_stage_view != null:
		_hero_stage_view.set_character(c, animate_switch)

	if _char_weapon_icon != null:
		_char_weapon_icon.texture = load(w_icon_path) as Texture2D if (w_icon_path != "" and ResourceLoader.exists(w_icon_path)) else null

	var aff := str(c.get("element_affinity", "metal"))
	var eb: Dictionary = ELEM_BADGE.get(aff, ELEM_BADGE["metal"])
	var accent: Color = c.get("accent_color", eb["color"]) if c.get("accent_color") is Color else eb["color"]

	_char_title_lbl.text = str(c.get("name", "沈砚"))
	if _char_role_lbl != null:
		_char_role_lbl.text = str(c.get("role", "御剑道君"))
	if _char_desc_lbl != null:
		_char_desc_lbl.text = str(c.get("desc", ""))
	if _char_elem_pill != null and _char_elem_lbl != null:
		_char_elem_pill.add_theme_stylebox_override("panel", XianxiaUITheme.make_pill_style(
			Color(accent.r, accent.g, accent.b, 0.20),
			Color(accent.r, accent.g, accent.b, 0.82),
			1, 10, 9, 3
		))
		_char_elem_lbl.text = "%s +%d%%" % [str(eb["short"]), roundi(float(c.get("affinity_bonus_pct", 0.15)) * 100.0)]
		_char_elem_lbl.add_theme_color_override("font_color", accent.lightened(0.28))

	if _char_weapon_lbl != null:
		_char_weapon_lbl.text = "本命 · %s" % w_name
	if _char_skill_lbl != null:
		_char_skill_lbl.text = "身法 · %s" % str(c.get("active_name", "御剑瞬步"))

	_stat_hp_lbl.text = str(int(c.get("max_health", 120.0)))
	_stat_spd_lbl.text = str(int(c.get("speed", 190.0)))
	_stat_crit_lbl.text = "%d%%" % roundi(float(c.get("crit_chance", 0.12)) * 100.0)
	if _char_trait_lbl != null:
		_char_trait_lbl.text = "命格：%s" % str(c.get("trait_summary", "均衡全能"))

	for k in _hero_cards.keys():
		var card_btn := _hero_cards[k] as Button
		var is_sel := str(k) == cid
		var kc := CharacterData.get_character(str(k))
		var k_acc: Color = kc.get("accent_color", XianxiaUITheme.COL_GOLD_BRIGHT) if kc.get("accent_color") is Color else XianxiaUITheme.COL_GOLD_BRIGHT
		XianxiaUITheme.style_avatar_medallion(card_btn, is_sel, k_acc)

		var target_y := -7.0 if is_sel else 0.0
		if animate_switch and is_inside_tree():
			var tw := create_tween()
			tw.tween_property(card_btn, "position:y", target_y, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			card_btn.position.y = target_y

		var avatar_tr := card_btn.find_child("AvatarPortrait", true, false) as TextureRect
		if avatar_tr != null and avatar_tr.material is ShaderMaterial:
			var smat := avatar_tr.material as ShaderMaterial
			smat.set_shader_parameter("border_color", k_acc if is_sel else Color(XianxiaUITheme.COL_GOLD.r, XianxiaUITheme.COL_GOLD.g, XianxiaUITheme.COL_GOLD.b, 0.55))
			smat.set_shader_parameter("border_width", 0.052 if is_sel else 0.032)
			smat.set_shader_parameter("bg_color", Color(k_acc.r * 0.22 + 0.04, k_acc.g * 0.22 + 0.09, k_acc.b * 0.22 + 0.08, 0.94) if is_sel else Color(0.05, 0.14, 0.12, 0.88))

		var name_lbl := card_btn.find_child("AvatarName", true, false) as Label
		if name_lbl != null:
			name_lbl.add_theme_color_override("font_color", k_acc.lightened(0.32) if is_sel else Color(0.84, 0.92, 0.88, 0.88))

func _load_v2_weapon_info(weapon_id: String) -> Dictionary:
	var p := "res://data/v2/weapons_v2.json"
	if not FileAccess.file_exists(p):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(p))
	if parsed is Dictionary:
		for w in (parsed as Dictionary).get("weapons", []):
			if w is Dictionary and String((w as Dictionary).get("id", "")) == weapon_id:
				return w as Dictionary
	return {}

func _shift_stage(delta_idx: int) -> void:
	var total := ChapterData.count()
	var idx := (Stats.selected_stage_id - 1 + delta_idx + total) % total
	Stats.selected_stage_id = idx + 1
	Stats.save_stats()
	_refresh_stage_ui()

func _refresh_stage_ui() -> void:
	var ch := ChapterData.get_chapter(Stats.selected_stage_id - 1)
	if ch.is_empty():
		return
	var cleared := Stats.is_stage_cleared(int(ch["id"]))
	var mins := int(round(float(ch.get("duration", 480.0)) / 60.0))
	_stage_title_lbl.text = "秘境 %d · %s" % [int(ch["id"]), str(ch["name"])]
	if _stage_clear_pill != null:
		_stage_clear_pill.visible = cleared
	_stage_meta_lbl.text = "%d分钟 · %s · %s · 灵石×%.1f" % [
		mins, str(ch.get("difficulty", "")), str(ch.get("boss_name", "")), float(ch.get("stone_mult", 1.0))
	]
	if _sect_stone_lbl != null:
		_sect_stone_lbl.text = "灵石 %d" % Stats.spirit_stones

func _apply_qinglv_theme() -> void:
	XianxiaUITheme.style_button(start_btn, "cinnabar")
	XianxiaUITheme.attach_ornaments(start_btn, XianxiaUITheme.COL_GOLD_BRIGHT, 9.0, 4.0)
	start_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if _sect_btn != null:
		XianxiaUITheme.style_button(_sect_btn, "primary")
	XianxiaUITheme.style_circle_icon_button(debug_btn, XianxiaUITheme.COL_GOLD)
	XianxiaUITheme.style_circle_icon_button(settings_btn, XianxiaUITheme.COL_GOLD)
	XianxiaUITheme.style_circle_icon_button(quit_btn, XianxiaUITheme.COL_GOLD)

func _refresh_best() -> void:
	best_label.text = Stats.summary_text()
	best_plate.visible = Stats.has_history()

func _show_loading_overlay() -> void:
	if _loading_overlay != null and is_instance_valid(_loading_overlay):
		return
	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.04, 0.11, 0.09, 0.72)
	var plate := PanelContainer.new()
	plate.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	plate.offset_left = -180.0
	plate.offset_right = 180.0
	plate.offset_top = -42.0
	plate.offset_bottom = 42.0
	plate.add_theme_stylebox_override("panel", XianxiaUITheme.make_hud_plate(XianxiaUITheme.COL_PLATE_DARK, XianxiaUITheme.COL_GOLD, 10, 16))
	overlay.add_child(plate)
	var lbl := Label.new()
	lbl.text = "踏入秘境中…"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", XianxiaUITheme.COL_GOLD_BRIGHT)
	XianxiaUITheme.apply_soft_shadow(lbl)
	plate.add_child(lbl)
	$SettingsLayer.add_child(overlay)
	_loading_overlay = overlay
	_loading_lbl = lbl

func _on_start_pressed() -> void:
	if _starting_game:
		return
	_close_settings()
	_close_sect()
	Music.play_track("battle")
	var status := ResourceLoader.load_threaded_get_status(GameFlow.GAME_SCENE)
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		var packed := ResourceLoader.load_threaded_get(GameFlow.GAME_SCENE) as PackedScene
		GameFlow.start_game_packed(packed)
		return
	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		_starting_game = true
		start_btn.disabled = true
		_show_loading_overlay()
		return
	GameFlow.start_game()

func _on_quit_pressed() -> void:
	GameFlow.quit_game()

func _on_debug_mode_pressed() -> void:
	if _starting_game:
		return
	_close_settings()
	_close_sect()
	Music.play_track("battle")
	GameFlow.start_debug_sandbox()

func _on_settings_pressed() -> void:
	_close_sect()
	if settings_panel != null and is_instance_valid(settings_panel):
		_close_settings()
		return
	settings_panel = SettingsPanel.new()
	settings_panel.closed.connect(_close_settings)
	$SettingsLayer.add_child(settings_panel)

func _close_settings() -> void:
	if settings_panel != null and is_instance_valid(settings_panel):
		settings_panel.queue_free()
	settings_panel = null

func _on_sect_pressed() -> void:
	_close_settings()
	if sect_panel != null and is_instance_valid(sect_panel):
		_close_sect()
		return
	_open_sect_panel()

func _close_sect() -> void:
	if sect_panel != null and is_instance_valid(sect_panel):
		sect_panel.queue_free()
	sect_panel = null
	_refresh_stage_ui()

func _open_sect_panel() -> void:
	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.05, 0.14, 0.12, 0.52)

	var pc := PanelContainer.new()
	pc.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	pc.offset_left = -350.0
	pc.offset_right = 350.0
	pc.offset_top = -280.0
	pc.offset_bottom = 280.0
	pc.add_theme_stylebox_override("panel", XianxiaUITheme.make_scroll_panel(XianxiaUITheme.COL_GOLD, 26))
	XianxiaUITheme.attach_ornaments(pc, XianxiaUITheme.COL_GOLD, 14.0, 6.0)
	overlay.add_child(pc)

	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 12)
	pc.add_child(root_box)

	var head := Label.new()
	head.text = "宗门修炼 · 十四脉永久根基"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tf = load("res://assets/title_font.tres")
	if tf != null:
		head.add_theme_font_override("font", tf)
	head.add_theme_font_size_override("font_size", 26)
	head.add_theme_color_override("font_color", XianxiaUITheme.COL_INK)
	root_box.add_child(head)

	_stone_lbl = Label.new()
	_stone_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stone_lbl.add_theme_font_size_override("font_size", 18)
	_stone_lbl.add_theme_color_override("font_color", Color(0.68, 0.36, 0.10))
	root_box.add_child(_stone_lbl)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	XianxiaUITheme.style_scroll_container(scroll)
	root_box.add_child(scroll)

	var list_box := XianxiaUITheme.make_scroll_body(scroll, 8, 10, 4)
	list_box.name = "ListBox"

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	root_box.add_child(btn_row)

	var recycle_btn := Button.new()
	recycle_btn.name = "RecycleButton"
	recycle_btn.text = "全部回收返还灵石"
	recycle_btn.custom_minimum_size = Vector2(210, 42)
	XianxiaUITheme.style_button(recycle_btn, "cinnabar")
	recycle_btn.pressed.connect(func():
		if Stats.recycle_sect_upgrades() > 0:
			Sfx.play("level_up", -6.0)
			_rebuild_sect_rows(list_box)
			_refresh_stage_ui()
	)
	btn_row.add_child(recycle_btn)

	var close_btn := Button.new()
	close_btn.text = "返回"
	close_btn.custom_minimum_size = Vector2(160, 42)
	XianxiaUITheme.style_button(close_btn, "primary")
	close_btn.pressed.connect(_close_sect)
	btn_row.add_child(close_btn)

	sect_panel = overlay
	$SettingsLayer.add_child(overlay)
	_rebuild_sect_rows(list_box)

func _rebuild_sect_rows(list_box: VBoxContainer) -> void:
	for c in list_box.get_children():
		c.queue_free()
	var invested := Stats.get_sect_invested_stones()
	if _stone_lbl != null:
		_stone_lbl.text = "当前可用灵石：%d · 已投入：%d" % [Stats.spirit_stones, invested]
	for item in Stats.SECT_CATALOG:
		var uid := str(item["id"])
		var lv := Stats.get_sect_level(uid)
		var max_lv := int(item["max"])
		var cost := Stats.get_sect_cost(uid)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var lbl := Label.new()
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.text = "%s (Lv.%d/%d) — %s" % [str(item["name"]), lv, max_lv, str(item["desc"])]
		lbl.add_theme_font_size_override("font_size", 15)
		lbl.add_theme_color_override("font_color", Color(0.14, 0.24, 0.22))
		row.add_child(lbl)

		var buy_btn := Button.new()
		buy_btn.custom_minimum_size = Vector2(112, 34)
		if cost < 0:
			buy_btn.text = "已圆满"
			buy_btn.disabled = true
		else:
			buy_btn.text = "%d 灵石" % cost
			buy_btn.disabled = Stats.spirit_stones < cost
			buy_btn.pressed.connect(func():
				if Stats.buy_sect_upgrade(uid):
					Sfx.play("level_up", -6.0)
					_rebuild_sect_rows(list_box)
					_refresh_stage_ui()
			)
		XianxiaUITheme.style_button(buy_btn, "primary")
		row.add_child(buy_btn)
		list_box.add_child(row)
