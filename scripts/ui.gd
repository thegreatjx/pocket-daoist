extends CanvasLayer

@onready var hp_bar: ProgressBar = $HUD/HPBar
@onready var exp_bar: ProgressBar = $HUD/ExpBar
@onready var realm_label: Label = $HUD/RealmLabel
@onready var timer_label: Label = $HUD/TimerLabel
@onready var hint_label: Label = $HUD/HintLabel
@onready var kill_label: Label = $HUD/KillLabel

const HINT_VISIBLE_SECONDS := 8.5
const HINT_FADE_SECONDS := 2.0

var game_time: float = 0.0
var kill_count_shown: int = -1

var _banner_panel: PanelContainer = null
var _banner_label: Label = null
var _banner_tween: Tween = null

var _boss_bar_container: PanelContainer = null
var _boss_name_label: Label = null
var _boss_hp_bar: ProgressBar = null
var _boss_hp_trail: ProgressBar = null
var _boss_hp_label: Label = null
var _boss_trail_tween: Tween = null

var _chapter_label: Label = null
var _chapter_bar: ProgressBar = null
var _chapter_name: String = ""
var _gold_label: Label = null
var _weapon_row: HBoxContainer = null
var _passive_row: HBoxContainer = null
var _edge_indicator: Control = null
var _buff_panel: PanelContainer = null
var _buff_label: Label = null

var _top_left_plate: PanelContainer = null
var _avatar_tex: TextureRect = null
var _avatar_char_id: String = ""
var _lv_badge_lbl: Label = null
var _hp_trail_bar: ProgressBar = null
var _hp_text_label: Label = null
var _exp_text_label: Label = null
var _hp_trail_tween: Tween = null
var _hp_ratio: float = 1.0
var _pulse_time: float = 0.0
var _loadout_box: VBoxContainer = null

func _ready() -> void:
	add_to_group("ui")
	_setup_edge_indicator()
	_setup_top_left_hud()
	_setup_timer_plate()
	_setup_top_right_hud()
	_setup_hint()
	_setup_banner()
	_setup_boss_bar()
	_setup_loadout_grid()
	_setup_buff_status()
	_sync_initial_player_hud.call_deferred()

func _reparent_control(ctrl: Control, new_parent: Node) -> void:
	if ctrl == null or new_parent == null:
		return
	if ctrl.get_parent() != null:
		ctrl.get_parent().remove_child(ctrl)
	new_parent.add_child(ctrl)
	ctrl.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	ctrl.position = Vector2.ZERO

func _setup_top_left_hud() -> void:
	var hud = get_node_or_null("HUD")
	if hud == null:
		return
	_top_left_plate = PanelContainer.new()
	_top_left_plate.name = "TopLeftPlate"
	_top_left_plate.position = Vector2(14, 12)
	_top_left_plate.custom_minimum_size = Vector2(364, 0)
	_top_left_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top_left_plate.add_theme_stylebox_override("panel", XianxiaUITheme.make_hud_plate(XianxiaUITheme.COL_PLATE_BG, XianxiaUITheme.COL_GOLD, 10, 16))
	XianxiaUITheme.attach_ornaments(_top_left_plate, XianxiaUITheme.COL_GOLD, 11.0, 5.0)
	hud.add_child(_top_left_plate)

	var root_hb := HBoxContainer.new()
	root_hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_hb.add_theme_constant_override("separation", 10)
	_top_left_plate.add_child(root_hb)

	var avatar_wrap := Control.new()
	avatar_wrap.custom_minimum_size = Vector2(76, 76)
	avatar_wrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	avatar_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_hb.add_child(avatar_wrap)

	var avatar_frame := PanelContainer.new()
	avatar_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	avatar_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var af_st := StyleBoxFlat.new()
	af_st.bg_color = XianxiaUITheme.COL_PLATE_DARK
	af_st.border_color = XianxiaUITheme.COL_GOLD
	af_st.set_border_width_all(2)
	af_st.set_corner_radius_all(10)
	af_st.set_content_margin_all(5)
	avatar_frame.add_theme_stylebox_override("panel", af_st)
	avatar_wrap.add_child(avatar_frame)

	_avatar_tex = TextureRect.new()
	_avatar_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_avatar_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_avatar_tex.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_avatar_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	avatar_frame.add_child(_avatar_tex)

	var lv_badge := PanelContainer.new()
	lv_badge.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	lv_badge.offset_left = -38.0
	lv_badge.offset_top = -18.0
	lv_badge.offset_right = 2.0
	lv_badge.offset_bottom = 2.0
	lv_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lv_st := StyleBoxFlat.new()
	lv_st.bg_color = Color(0.07, 0.16, 0.14, 0.96)
	lv_st.border_color = XianxiaUITheme.COL_GOLD_BRIGHT
	lv_st.set_border_width_all(1)
	lv_st.set_corner_radius_all(5)
	lv_st.set_content_margin_all(2)
	lv_badge.add_theme_stylebox_override("panel", lv_st)
	avatar_wrap.add_child(lv_badge)

	_lv_badge_lbl = Label.new()
	_lv_badge_lbl.text = "Lv.1"
	_lv_badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lv_badge_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lv_badge_lbl.add_theme_font_size_override("font_size", 11)
	_lv_badge_lbl.add_theme_color_override("font_color", XianxiaUITheme.COL_GOLD_BRIGHT)
	XianxiaUITheme.apply_text_outline(_lv_badge_lbl, 2)
	lv_badge.add_child(_lv_badge_lbl)

	var info_vb := VBoxContainer.new()
	info_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_vb.add_theme_constant_override("separation", 4)
	root_hb.add_child(info_vb)

	if realm_label != null:
		_reparent_control(realm_label, info_vb)
		realm_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		realm_label.custom_minimum_size = Vector2(10, 0)
		realm_label.clip_text = true
		realm_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		realm_label.add_theme_font_size_override("font_size", 17)
		realm_label.add_theme_color_override("font_color", XianxiaUITheme.COL_WARM_TEXT)
		XianxiaUITheme.apply_text_outline(realm_label, 4)

	var hp_box := Control.new()
	hp_box.custom_minimum_size = Vector2(0, 22)
	hp_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_vb.add_child(hp_box)

	var hp_frame := Panel.new()
	hp_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hp_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hpf_st := StyleBoxFlat.new()
	hpf_st.bg_color = Color(0.05, 0.10, 0.09, 0.95)
	hpf_st.border_color = XianxiaUITheme.COL_GOLD
	hpf_st.set_border_width_all(1)
	hpf_st.set_corner_radius_all(5)
	hp_frame.add_theme_stylebox_override("panel", hpf_st)
	hp_box.add_child(hp_frame)

	_hp_trail_bar = ProgressBar.new()
	_hp_trail_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hp_trail_bar.offset_left = 1.0
	_hp_trail_bar.offset_top = 1.0
	_hp_trail_bar.offset_right = -1.0
	_hp_trail_bar.offset_bottom = -1.0
	_hp_trail_bar.show_percentage = false
	_hp_trail_bar.value = 100.0
	_hp_trail_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_overlay_bar(_hp_trail_bar, XianxiaUITheme.COL_HP_TRAIL, 4)
	hp_box.add_child(_hp_trail_bar)

	if hp_bar != null:
		_reparent_control(hp_bar, hp_box)
		hp_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hp_bar.offset_left = 1.0
		hp_bar.offset_top = 1.0
		hp_bar.offset_right = -1.0
		hp_bar.offset_bottom = -1.0
		hp_bar.show_percentage = false
		hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_style_overlay_bar(hp_bar, XianxiaUITheme.COL_HP_FILL, 4)

	var hp_shine := ColorRect.new()
	hp_shine.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hp_shine.offset_left = 2.0
	hp_shine.offset_right = -2.0
	hp_shine.offset_top = 2.0
	hp_shine.offset_bottom = 4.0
	hp_shine.color = Color(1.0, 0.90, 0.84, 0.22)
	hp_shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_box.add_child(hp_shine)

	_hp_text_label = Label.new()
	_hp_text_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hp_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hp_text_label.text = "气血 100 / 100"
	_hp_text_label.add_theme_font_size_override("font_size", 12)
	_hp_text_label.add_theme_color_override("font_color", Color(1.0, 0.98, 0.92))
	XianxiaUITheme.apply_text_outline(_hp_text_label, 3)
	hp_box.add_child(_hp_text_label)

	var exp_box := Control.new()
	exp_box.custom_minimum_size = Vector2(0, 16)
	exp_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	exp_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_vb.add_child(exp_box)

	var exp_frame := Panel.new()
	exp_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	exp_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var exf_st := StyleBoxFlat.new()
	exf_st.bg_color = Color(0.05, 0.11, 0.10, 0.95)
	exf_st.border_color = XianxiaUITheme.COL_JADE
	exf_st.set_border_width_all(1)
	exf_st.set_corner_radius_all(4)
	exp_frame.add_theme_stylebox_override("panel", exf_st)
	exp_box.add_child(exp_frame)

	if exp_bar != null:
		_reparent_control(exp_bar, exp_box)
		exp_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		exp_bar.offset_left = 1.0
		exp_bar.offset_top = 1.0
		exp_bar.offset_right = -1.0
		exp_bar.offset_bottom = -1.0
		exp_bar.show_percentage = false
		exp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_style_overlay_bar(exp_bar, XianxiaUITheme.COL_EXP_FILL, 3)

	_exp_text_label = Label.new()
	_exp_text_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_exp_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_exp_text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_exp_text_label.text = "修为 0 / 10"
	_exp_text_label.add_theme_font_size_override("font_size", 11)
	_exp_text_label.add_theme_color_override("font_color", Color(0.92, 0.99, 0.95))
	XianxiaUITheme.apply_text_outline(_exp_text_label, 3)
	exp_box.add_child(_exp_text_label)

	var wave_vb := VBoxContainer.new()
	wave_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wave_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wave_vb.add_theme_constant_override("separation", 2)
	info_vb.add_child(wave_vb)

	_chapter_label = Label.new()
	_chapter_label.name = "ChapterLabel"
	_chapter_label.text = "青冥林 · 初入仙途"
	_chapter_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chapter_label.custom_minimum_size = Vector2(10, 0)
	_chapter_label.clip_text = true
	_chapter_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_chapter_label.add_theme_font_size_override("font_size", 13)
	_chapter_label.add_theme_color_override("font_color", XianxiaUITheme.COL_GOLD_BRIGHT)
	XianxiaUITheme.apply_text_outline(_chapter_label, 3)
	wave_vb.add_child(_chapter_label)

	_chapter_bar = ProgressBar.new()
	_chapter_bar.name = "ChapterProgress"
	_chapter_bar.custom_minimum_size = Vector2(0, 7)
	_chapter_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chapter_bar.show_percentage = false
	_chapter_bar.max_value = 1.0
	_chapter_bar.value = 0.0
	XianxiaUITheme.style_progress_bar(_chapter_bar, Color(0.06, 0.13, 0.11, 0.95), Color(0.94, 0.76, 0.28, 0.98), XianxiaUITheme.COL_GOLD_SOFT, 3)
	wave_vb.add_child(_chapter_bar)

	var init_cid := Stats.selected_character_id if Stats != null else "sword_immortal"
	_sync_avatar(init_cid)

func _setup_timer_plate() -> void:
	var hud = get_node_or_null("HUD")
	if hud == null:
		return
	var timer_plate := PanelContainer.new()
	timer_plate.name = "TimerPlate"
	timer_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	timer_plate.anchors_preset = Control.PRESET_CENTER_TOP
	timer_plate.anchor_left = 0.5
	timer_plate.anchor_right = 0.5
	timer_plate.offset_left = -88.0
	timer_plate.offset_right = 88.0
	timer_plate.offset_top = 12.0
	timer_plate.offset_bottom = 62.0
	timer_plate.custom_minimum_size = Vector2(176, 50)
	timer_plate.add_theme_stylebox_override("panel", XianxiaUITheme.make_hud_plate(XianxiaUITheme.COL_PLATE_BG, XianxiaUITheme.COL_GOLD, 8, 8))
	XianxiaUITheme.attach_ornaments(timer_plate, XianxiaUITheme.COL_GOLD, 10.0, 4.0)
	hud.add_child(timer_plate)

	if timer_label != null:
		_reparent_control(timer_label, timer_plate)
		timer_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		timer_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		timer_label.add_theme_font_size_override("font_size", 24)
		timer_label.add_theme_color_override("font_color", XianxiaUITheme.COL_GOLD_BRIGHT)
		XianxiaUITheme.apply_text_outline(timer_label, 4)

func _setup_top_right_hud() -> void:
	var hud = get_node_or_null("HUD")
	if hud == null:
		return
	var tr_plate := PanelContainer.new()
	tr_plate.name = "TopRightPlate"
	tr_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr_plate.anchors_preset = Control.PRESET_TOP_RIGHT
	tr_plate.anchor_left = 1.0
	tr_plate.anchor_right = 1.0
	tr_plate.offset_left = -206.0
	tr_plate.offset_right = -14.0
	tr_plate.offset_top = 12.0
	tr_plate.offset_bottom = 90.0
	tr_plate.custom_minimum_size = Vector2(192, 78)
	var tr_st := XianxiaUITheme.make_hud_plate(XianxiaUITheme.COL_PLATE_BG, XianxiaUITheme.COL_GOLD, 9, 12)
	tr_st.content_margin_left = 20
	tr_st.content_margin_right = 20
	tr_plate.add_theme_stylebox_override("panel", tr_st)
	XianxiaUITheme.attach_ornaments(tr_plate, XianxiaUITheme.COL_GOLD, 9.0, 4.0)
	hud.add_child(tr_plate)

	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 4)
	tr_plate.add_child(vb)

	if kill_label != null:
		_reparent_control(kill_label, vb)
		kill_label.modulate = Color.WHITE
		kill_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		kill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		kill_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		kill_label.add_theme_font_size_override("font_size", 18)
		kill_label.add_theme_color_override("font_color", Color(1.0, 0.91, 0.62))
		XianxiaUITheme.apply_text_outline(kill_label, 3)

	var div := ColorRect.new()
	div.custom_minimum_size = Vector2(0, 1)
	div.color = Color(0.88, 0.70, 0.30, 0.38)
	div.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(div)

func _style_overlay_bar(bar: ProgressBar, fill_color: Color, radius: int) -> void:
	if bar == null:
		return
	bar.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(radius)
	bar.add_theme_stylebox_override("fill", fill)

func _sync_avatar(char_id: String) -> void:
	if _avatar_tex == null or char_id == _avatar_char_id:
		return
	_avatar_char_id = char_id
	_avatar_tex.texture = CharacterData.get_avatar_texture(char_id)

func _sync_initial_player_hud() -> void:
	if _top_left_plate != null and _loadout_box != null:
		_loadout_box.position.y = maxf(144.0, _top_left_plate.position.y + _top_left_plate.size.y + 8.0)
		if _buff_panel != null:
			_buff_panel.position.y = _loadout_box.position.y + 92.0
	if not is_inside_tree() or get_tree() == null:
		return
	var p := get_tree().get_first_node_in_group("player")
	if p == null or not is_instance_valid(p):
		return
	if "character_id" in p:
		_sync_avatar(str(p.character_id))
	if "current_health" in p and "max_health" in p:
		update_health(float(p.current_health), float(p.max_health))
	if "current_exp" in p and "exp_to_next_level" in p and "level" in p:
		update_exp(float(p.current_exp), float(p.exp_to_next_level), int(p.level))

func _exit_tree() -> void:
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
		_banner_tween = null
	if _hp_trail_tween != null and _hp_trail_tween.is_valid():
		_hp_trail_tween.kill()
		_hp_trail_tween = null
	if _boss_trail_tween != null and _boss_trail_tween.is_valid():
		_boss_trail_tween.kill()
		_boss_trail_tween = null

func _setup_hint() -> void:
	if hint_label == null:
		return
	if not Settings.get_bool("ui/hint_enabled"):
		hint_label.visible = false
		return
	hint_label.offset_left = 14.0
	hint_label.offset_right = 560.0
	hint_label.offset_top = -106.0
	hint_label.offset_bottom = -14.0
	hint_label.add_theme_font_size_override("font_size", 15)
	hint_label.add_theme_color_override("font_color", Color(0.96, 0.96, 0.88))
	XianxiaUITheme.apply_text_outline(hint_label, 4)
	var t = create_tween()
	t.tween_interval(HINT_VISIBLE_SECONDS)
	t.tween_property(hint_label, "modulate:a", 0.0, HINT_FADE_SECONDS)

func _process(delta: float) -> void:
	game_time += delta
	var minutes = int(game_time) / 60
	var seconds = int(game_time) % 60
	timer_label.text = "%02d:%02d" % [minutes, seconds]
	_update_kill_count()
	_update_buff_status()
	if hp_bar != null:
		if _hp_ratio > 0.0 and _hp_ratio <= 0.30:
			_pulse_time += delta * 7.0
			var k := 0.5 + 0.5 * sin(_pulse_time)
			hp_bar.modulate = Color(1.0 + 0.25 * k, 0.72 + 0.28 * (1.0 - k), 0.72 + 0.28 * (1.0 - k))
		elif hp_bar.modulate != Color.WHITE:
			hp_bar.modulate = Color.WHITE

func _update_kill_count() -> void:
	if kill_label == null:
		return
	var mgrs = get_tree().get_nodes_in_group("game_manager")
	if mgrs.size() == 0:
		return
	var kills = mgrs[0].kill_count
	if kills != kill_count_shown:
		kill_count_shown = kills
		kill_label.text = "诛魔 %d" % kills

func update_health(curr: float, max_h: float) -> void:
	var safe_max := maxf(1.0, max_h)
	var clamped_curr := clampf(curr, 0.0, safe_max)
	_hp_ratio = clamped_curr / safe_max
	if hp_bar != null:
		hp_bar.max_value = safe_max
		hp_bar.value = clamped_curr
	if _hp_trail_bar != null:
		var prev_ratio := _hp_trail_bar.value / maxf(1.0, _hp_trail_bar.max_value)
		_hp_trail_bar.max_value = safe_max
		if clamped_curr < _hp_trail_bar.value and prev_ratio > _hp_ratio:
			if _hp_trail_tween != null and _hp_trail_tween.is_valid():
				_hp_trail_tween.kill()
			_hp_trail_tween = create_tween()
			_hp_trail_tween.tween_property(_hp_trail_bar, "value", clamped_curr, 0.36).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		else:
			_hp_trail_bar.value = clamped_curr
	if _hp_text_label != null:
		_hp_text_label.text = "气血 %d / %d" % [maxi(0, int(roundf(curr))), maxi(1, int(roundf(max_h)))]

func update_gold(gold: int) -> void:
	if _gold_label != null:
		_gold_label.text = "灵石 %d" % gold

func update_exp(curr: float, max_e: float, level: int) -> void:
	var safe_max := maxf(1.0, max_e)
	if exp_bar != null:
		exp_bar.max_value = safe_max
		exp_bar.value = clampf(curr, 0.0, safe_max)
	if _exp_text_label != null:
		_exp_text_label.text = "修为 %d / %d" % [maxi(0, int(floorf(curr))), int(roundf(safe_max))]
	if _lv_badge_lbl != null:
		_lv_badge_lbl.text = "Lv.%d" % level
	var realm := "练气"
	if level >= 34:
		realm = "合道"
	elif level >= 28:
		realm = "渡劫"
	elif level >= 22:
		realm = "化神"
	elif level >= 15:
		realm = "元婴"
	elif level >= 9:
		realm = "金丹"
	elif level >= 4:
		realm = "筑基"
	var cid := Stats.selected_character_id if Stats != null else "sword_immortal"
	var p := get_tree().get_first_node_in_group("player")
	if p != null and "character_id" in p:
		cid = str(p.character_id)
	_sync_avatar(cid)
	var cname := str(CharacterData.get_character(cid).get("name", "沈砚"))
	if realm_label != null:
		realm_label.text = "【%s · %s】Lv.%d" % [cname, realm, level]

func _setup_banner() -> void:
	var hud = get_node_or_null("HUD")
	if hud == null:
		return
	_banner_panel = PanelContainer.new()
	_banner_panel.name = "BannerPanel"
	_banner_panel.visible = false
	_banner_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_panel.anchors_preset = Control.PRESET_CENTER_TOP
	_banner_panel.anchor_left = 0.5
	_banner_panel.anchor_right = 0.5
	_banner_panel.offset_left = -280.0
	_banner_panel.offset_right = 280.0
	_banner_panel.offset_top = 146.0
	_banner_panel.offset_bottom = 194.0
	_banner_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	var banner_st := XianxiaUITheme.make_hud_plate(Color(0.08, 0.20, 0.17, 0.92), XianxiaUITheme.COL_GOLD_BRIGHT, 8, 10)
	banner_st.content_margin_left = 20
	banner_st.content_margin_right = 20
	_banner_panel.add_theme_stylebox_override("panel", banner_st)
	XianxiaUITheme.attach_ornaments(_banner_panel, XianxiaUITheme.COL_GOLD_BRIGHT, 10.0, 4.0)

	_banner_label = Label.new()
	_banner_label.name = "BannerLabel"
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner_label.add_theme_font_size_override("font_size", 21)
	_banner_label.add_theme_color_override("font_color", XianxiaUITheme.COL_GOLD_BRIGHT)
	XianxiaUITheme.apply_text_outline(_banner_label, 4)
	_banner_panel.add_child(_banner_label)
	hud.add_child(_banner_panel)

func show_banner(msg: String) -> void:
	if _banner_panel == null or _banner_label == null:
		return
	_banner_label.text = msg
	_banner_panel.visible = true
	_banner_panel.modulate.a = 0.0
	_banner_panel.scale = Vector2(0.9, 0.9)
	_banner_panel.pivot_offset = Vector2(280.0, 23.0)

	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.set_parallel(true)
	_banner_tween.tween_property(_banner_panel, "modulate:a", 1.0, 0.25)
	_banner_tween.tween_property(_banner_panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.chain().tween_interval(2.4)
	_banner_tween.chain().tween_property(_banner_panel, "modulate:a", 0.0, 0.55)
	_banner_tween.chain().tween_callback(func(): _banner_panel.visible = false)

func _setup_boss_bar() -> void:
	var hud = get_node_or_null("HUD")
	if hud == null:
		return
	_boss_bar_container = PanelContainer.new()
	_boss_bar_container.name = "BossBarContainer"
	_boss_bar_container.visible = false
	_boss_bar_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_bar_container.anchors_preset = Control.PRESET_CENTER_TOP
	_boss_bar_container.anchor_left = 0.5
	_boss_bar_container.anchor_right = 0.5
	_boss_bar_container.offset_left = -240.0
	_boss_bar_container.offset_right = 240.0
	_boss_bar_container.offset_top = 70.0
	_boss_bar_container.offset_bottom = 138.0
	_boss_bar_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	var boss_st := XianxiaUITheme.make_hud_plate(Color(0.09, 0.14, 0.13, 0.92), Color(0.92, 0.44, 0.22, 0.96), 8, 13)
	boss_st.content_margin_left = 18
	boss_st.content_margin_right = 18
	_boss_bar_container.add_theme_stylebox_override("panel", boss_st)
	XianxiaUITheme.attach_ornaments(_boss_bar_container, Color(0.96, 0.72, 0.30, 0.92), 9.0, 4.0)

	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 4)
	_boss_bar_container.add_child(vb)

	_boss_name_label = Label.new()
	_boss_name_label.name = "BossNameLabel"
	_boss_name_label.text = "【苍鬃狼王】"
	_boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_name_label.add_theme_font_size_override("font_size", 18)
	_boss_name_label.add_theme_color_override("font_color", XianxiaUITheme.COL_GOLD_BRIGHT)
	XianxiaUITheme.apply_text_outline(_boss_name_label, 4)
	vb.add_child(_boss_name_label)

	var bar_wrap := Control.new()
	bar_wrap.custom_minimum_size = Vector2(440, 20)
	bar_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(bar_wrap)

	var frame := Panel.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fst := StyleBoxFlat.new()
	fst.bg_color = Color(0.06, 0.10, 0.09, 0.96)
	fst.border_color = XianxiaUITheme.COL_GOLD
	fst.set_border_width_all(1)
	fst.set_corner_radius_all(5)
	frame.add_theme_stylebox_override("panel", fst)
	bar_wrap.add_child(frame)

	_boss_hp_trail = ProgressBar.new()
	_boss_hp_trail.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_boss_hp_trail.offset_left = 1.0
	_boss_hp_trail.offset_top = 1.0
	_boss_hp_trail.offset_right = -1.0
	_boss_hp_trail.offset_bottom = -1.0
	_boss_hp_trail.show_percentage = false
	_boss_hp_trail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_overlay_bar(_boss_hp_trail, XianxiaUITheme.COL_HP_TRAIL, 4)
	bar_wrap.add_child(_boss_hp_trail)

	_boss_hp_bar = ProgressBar.new()
	_boss_hp_bar.name = "BossProgressBar"
	_boss_hp_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_boss_hp_bar.offset_left = 1.0
	_boss_hp_bar.offset_top = 1.0
	_boss_hp_bar.offset_right = -1.0
	_boss_hp_bar.offset_bottom = -1.0
	_boss_hp_bar.show_percentage = false
	_boss_hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_overlay_bar(_boss_hp_bar, Color(0.86, 0.21, 0.16, 1.0), 4)
	bar_wrap.add_child(_boss_hp_bar)

	_boss_hp_label = Label.new()
	_boss_hp_label.name = "BossHpLabel"
	_boss_hp_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_boss_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_boss_hp_label.add_theme_font_size_override("font_size", 13)
	_boss_hp_label.add_theme_color_override("font_color", Color(1.0, 0.97, 0.90))
	XianxiaUITheme.apply_text_outline(_boss_hp_label, 3)
	bar_wrap.add_child(_boss_hp_label)
	hud.add_child(_boss_bar_container)

func activate_boss_bar(max_hp: float) -> void:
	if _boss_bar_container == null:
		return
	var safe_max := maxf(1.0, max_hp)
	_boss_bar_container.visible = true
	_boss_bar_container.modulate.a = 0.0
	if _boss_hp_bar != null:
		_boss_hp_bar.max_value = safe_max
		_boss_hp_bar.value = safe_max
	if _boss_hp_trail != null:
		_boss_hp_trail.max_value = safe_max
		_boss_hp_trail.value = safe_max
	if _boss_hp_label != null:
		_boss_hp_label.text = "%d / %d" % [int(safe_max), int(safe_max)]
	var t = create_tween()
	t.tween_property(_boss_bar_container, "modulate:a", 1.0, 0.45)

func update_boss_hp(curr: float, max_h: float) -> void:
	if _boss_bar_container == null or not _boss_bar_container.visible:
		return
	var safe_max := maxf(1.0, max_h)
	var clamped_curr := clampf(curr, 0.0, safe_max)
	if _boss_hp_bar != null:
		_boss_hp_bar.max_value = safe_max
		_boss_hp_bar.value = clamped_curr
	if _boss_hp_trail != null:
		_boss_hp_trail.max_value = safe_max
		if clamped_curr < _boss_hp_trail.value:
			if _boss_trail_tween != null and _boss_trail_tween.is_valid():
				_boss_trail_tween.kill()
			_boss_trail_tween = create_tween()
			_boss_trail_tween.tween_property(_boss_hp_trail, "value", clamped_curr, 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		else:
			_boss_hp_trail.value = clamped_curr
	if _boss_hp_label != null:
		_boss_hp_label.text = "%d / %d" % [max(0, int(roundf(curr))), int(roundf(safe_max))]
	if curr <= 0:
		var t = create_tween()
		t.tween_property(_boss_bar_container, "modulate:a", 0.0, 0.6)
		t.tween_callback(func(): _boss_bar_container.visible = false)

func set_boss_name(boss_name: String) -> void:
	if _boss_name_label != null:
		_boss_name_label.text = "【%s】" % boss_name

func set_chapter(chapter: Dictionary) -> void:
	if _chapter_label == null:
		return
	var ch_name := str(chapter.get("name", "青冥林"))
	_chapter_name = ch_name
	_chapter_label.text = ch_name
	var duration := float(chapter.get("duration", 90.0))
	if _chapter_bar != null:
		_chapter_bar.max_value = maxf(1.0, duration)
		_chapter_bar.value = 0.0
	if int(chapter.get("id", 1)) > 1:
		show_banner("【%s】" % ch_name)

func update_wave_info(wave_num: int, total_waves: int, wave_name: String = "") -> void:
	if _chapter_label == null:
		return
	var base_name := _chapter_name if not _chapter_name.is_empty() else "青冥林"
	var tail := " · %s" % wave_name if not wave_name.is_empty() else ""
	_chapter_label.text = "%s [W%d/%d%s]" % [base_name, wave_num, maxi(1, total_waves), tail]

func update_chapter_progress(elapsed: float, duration: float) -> void:
	if _chapter_bar == null:
		return
	_chapter_bar.max_value = maxf(1.0, duration)
	_chapter_bar.value = clampf(elapsed, 0.0, duration)

func _setup_loadout_grid() -> void:
	var hud = get_node_or_null("HUD")
	if hud == null:
		return
	_loadout_box = VBoxContainer.new()
	_loadout_box.name = "LoadoutGrid"
	_loadout_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loadout_box.position = Vector2(14, 144)
	_loadout_box.add_theme_constant_override("separation", 5)

	_weapon_row = HBoxContainer.new()
	_weapon_row.add_theme_constant_override("separation", 5)
	_passive_row = HBoxContainer.new()
	_passive_row.add_theme_constant_override("separation", 5)
	_loadout_box.add_child(_weapon_row)
	_loadout_box.add_child(_passive_row)
	hud.add_child(_loadout_box)

func refresh_loadout(wm: WeaponManager) -> void:
	if _weapon_row == null or _passive_row == null or wm == null:
		return
	for c in _weapon_row.get_children():
		_weapon_row.remove_child(c)
		c.queue_free()
	for c in _passive_row.get_children():
		_passive_row.remove_child(c)
		c.queue_free()

	var w_slots := wm.get_weapon_slots()
	for i in range(WeaponCatalog.MAX_WEAPON_SLOTS):
		if i < w_slots.size():
			_weapon_row.add_child(_make_slot_cell(w_slots[i], true))
		else:
			_weapon_row.add_child(_make_empty_slot(true))

	var p_slots := wm.get_passive_slots()
	for i in range(WeaponCatalog.MAX_PASSIVE_SLOTS):
		if i < p_slots.size():
			_passive_row.add_child(_make_slot_cell(p_slots[i], false))
		else:
			_passive_row.add_child(_make_empty_slot(false))

func refresh_v2_loadout(v2: V2CombatController) -> void:
	if _weapon_row == null or _passive_row == null or v2 == null:
		return
	for c in _weapon_row.get_children():
		_weapon_row.remove_child(c)
		c.queue_free()
	for c in _passive_row.get_children():
		_passive_row.remove_child(c)
		c.queue_free()

	var w_slots := v2.get_hud_weapons()
	var unlocked := v2.get_unlocked_slots()
	var realm_by_slot := {}
	for entry in v2.get_realm_table():
		realm_by_slot[int(entry.get("slots", 0))] = entry
	var max_w := v2.get_max_weapon_slots()
	for i in range(max_w):
		if i < w_slots.size():
			var w: Dictionary = w_slots[i]
			var tier := int(w.get("tier", 1))
			var is_f := bool(w.get("is_fusion", false))
			_weapon_row.add_child(_make_slot_cell({
				"id": w["id"],
				"name": w["name"],
				"icon": w["icon"],
				"level": tier,
				"evolved": is_f,
				"maxed": tier >= OrbitWeaponRig.MAX_WEAPON_TIER and not is_f,
				"ready_evo": false,
			}, true))
		elif i < unlocked:
			_weapon_row.add_child(_make_empty_slot(true))
		else:
			var unlock_entry: Dictionary = realm_by_slot.get(i + 1, {})
			var unlock_lv := int(unlock_entry.get("level", 0))
			var unlock_label := "锁"
			if unlock_lv > 0:
				unlock_label = "Lv%d" % unlock_lv
			_weapon_row.add_child(_make_empty_slot(true, unlock_label, true))

	var i_slots := v2.get_hud_items()
	for i in range(6):
		if i < i_slots.size():
			var it: Dictionary = i_slots[i]
			var iid := String(it["id"])
			_passive_row.add_child(_make_slot_cell({
				"id": iid,
				"name": it["name"],
				"icon": String(V2ShopUI.ITEM_ICONS.get(iid, "res://assets/icons/relic_insight.png")),
				"level": int(it.get("count", 1)),
				"evolved": false,
				"maxed": false,
				"ready_evo": false,
			}, false))
		else:
			_passive_row.add_child(_make_empty_slot(false))

func _make_empty_slot(is_weapon: bool, label_text: String = "", locked: bool = false) -> Control:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(40, 40)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := StyleBoxFlat.new()
	if locked:
		st.bg_color = Color(0.05, 0.12, 0.11, 0.58)
		st.border_color = Color(0.26, 0.38, 0.34, 0.45)
	else:
		st.bg_color = Color(0.07, 0.17, 0.15, 0.56)
		st.border_color = Color(0.42, 0.72, 0.64, 0.52) if is_weapon else Color(0.86, 0.70, 0.34, 0.48)
	st.set_border_width_all(1)
	st.set_corner_radius_all(6)
	p.add_theme_stylebox_override("panel", st)
	if label_text != "":
		var lbl := Label.new()
		lbl.text = label_text
		lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.add_theme_color_override("font_color", Color(0.42, 0.55, 0.50, 0.88))
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(lbl)
	return p

func _make_slot_cell(data: Dictionary, is_weapon: bool) -> Control:
	var is_evo: bool = bool(data.get("evolved", false))
	var ready_evo: bool = bool(data.get("ready_evo", false))
	var is_maxed: bool = bool(data.get("maxed", false))
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(40, 40)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.tooltip_text = str(data.get("name", ""))

	var st := StyleBoxFlat.new()
	if is_evo:
		st.bg_color = Color(0.44, 0.15, 0.10, 0.94)
		st.border_color = XianxiaUITheme.COL_GOLD_BRIGHT
	elif ready_evo:
		st.bg_color = Color(0.28, 0.22, 0.08, 0.94)
		st.border_color = XianxiaUITheme.COL_GOLD_BRIGHT
	else:
		st.bg_color = XianxiaUITheme.COL_PLATE_BG
		st.border_color = XianxiaUITheme.COL_GOLD_BRIGHT if is_maxed else (Color(0.32, 0.86, 0.72, 0.92) if is_weapon else XianxiaUITheme.COL_GOLD)
	st.set_border_width_all(2 if (is_evo or ready_evo or is_maxed) else 1)
	st.set_corner_radius_all(6)
	st.set_content_margin_all(2)
	slot.add_theme_stylebox_override("panel", st)

	var stack := Control.new()
	stack.custom_minimum_size = Vector2(36, 36)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(stack)

	var icon_path := str(data.get("icon", ""))
	if icon_path != "" and ResourceLoader.exists(icon_path):
		var tr := TextureRect.new()
		tr.texture = load(icon_path)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tr.offset_left = 3
		tr.offset_top = 3
		tr.offset_right = -3
		tr.offset_bottom = -3
		stack.add_child(tr)

	var badge := PanelContainer.new()
	badge.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	badge.offset_left = -16.0
	badge.offset_top = -15.0
	badge.offset_right = 1.0
	badge.offset_bottom = 1.0
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bst := StyleBoxFlat.new()
	bst.bg_color = Color(0.05, 0.11, 0.10, 0.88)
	bst.set_corner_radius_all(3)
	bst.content_margin_left = 2
	bst.content_margin_right = 2
	badge.add_theme_stylebox_override("panel", bst)
	stack.add_child(badge)

	var lv_lbl := Label.new()
	if is_evo:
		lv_lbl.text = "★"
	elif is_maxed:
		lv_lbl.text = "满"
	else:
		lv_lbl.text = str(data.get("level", 1))
	lv_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lv_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lv_lbl.add_theme_font_size_override("font_size", 10 if is_maxed else 11)
	lv_lbl.add_theme_color_override("font_color", XianxiaUITheme.COL_GOLD_BRIGHT if (is_evo or ready_evo or is_maxed) else Color(0.98, 0.98, 0.90))
	XianxiaUITheme.apply_text_outline(lv_lbl, 2)
	badge.add_child(lv_lbl)
	return slot

func _setup_buff_status() -> void:
	var hud = get_node_or_null("HUD")
	if hud == null:
		return
	_buff_panel = PanelContainer.new()
	_buff_panel.name = "BuffStatusPanel"
	_buff_panel.position = Vector2(14, 236)
	_buff_panel.visible = false
	_buff_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_buff_panel.add_theme_stylebox_override("panel", XianxiaUITheme.make_hud_plate(XianxiaUITheme.COL_PLATE_BG, Color(0.28, 0.94, 0.78, 0.92), 6, 8))

	_buff_label = Label.new()
	_buff_label.add_theme_font_size_override("font_size", 14)
	_buff_label.add_theme_color_override("font_color", Color(0.56, 0.98, 0.84))
	XianxiaUITheme.apply_text_outline(_buff_label, 3)
	_buff_panel.add_child(_buff_label)
	hud.add_child(_buff_panel)

func _update_buff_status() -> void:
	if _buff_panel == null or _buff_label == null or not is_inside_tree() or get_tree() == null:
		return
	var p := get_tree().get_first_node_in_group("player")
	if p == null or not is_instance_valid(p) or not ("_temp_buff_timer" in p):
		_buff_panel.visible = false
		return
	var rem := float(p.get("_temp_buff_timer"))
	if rem > 0.0:
		_buff_panel.visible = true
		_buff_label.text = "✦ 灵气暴涨：伤害+25%% 攻速+30%% (%.1fs)" % rem
	else:
		_buff_panel.visible = false

func _setup_edge_indicator() -> void:
	var hud = get_node_or_null("HUD")
	if hud == null:
		return
	_edge_indicator = EdgeIndicator.new()
	_edge_indicator.name = "EdgeIndicator"
	_edge_indicator.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_edge_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_edge_indicator)
	hud.move_child(_edge_indicator, 0)

class EdgeIndicator extends Control:
	var _t: float = 0.0
	var _had_markers: bool = false

	func _process(delta: float) -> void:
		_t += delta
		var tree := get_tree()
		if tree == null:
			return
		var has_targets := (not tree.get_nodes_in_group("chests").is_empty()) or (not tree.get_nodes_in_group("bosses").is_empty()) or (not tree.get_nodes_in_group("elite_enemies").is_empty())
		if has_targets or _had_markers:
			queue_redraw()

	func _draw() -> void:
		var tree := get_tree()
		if tree == null:
			return
		var vp := get_viewport()
		if vp == null:
			return
		var vp_size: Vector2 = vp.get_visible_rect().size
		if vp_size.x <= 1.0 or vp_size.y <= 1.0:
			return
		var canvas_xform: Transform2D = vp.get_canvas_transform()
		var inner_rect := Rect2(Vector2(28.0, 28.0), vp_size - Vector2(56.0, 56.0))
		var pulse: float = 0.88 + 0.12 * sin(_t * 5.2)

		var drew_any := false
		for node in tree.get_nodes_in_group("chests"):
			if not is_instance_valid(node) or not (node is Node2D):
				continue
			var n2 := node as Node2D
			if not n2.visible:
				continue
			var sp: Vector2 = canvas_xform * n2.global_position
			if not inner_rect.has_point(sp):
				drew_any = true
				_draw_edge_marker(vp_size, sp, "宝箱", Color(0.98, 0.80, 0.24, pulse), Color(0.46, 0.22, 0.06, 0.95))

		for node in tree.get_nodes_in_group("bosses"):
			if not is_instance_valid(node) or not (node is Node2D):
				continue
			if bool(node.get("is_dead")):
				continue
			var n2 := node as Node2D
			var sp: Vector2 = canvas_xform * n2.global_position
			if not inner_rect.has_point(sp):
				drew_any = true
				_draw_edge_marker(vp_size, sp, "首领", Color(0.95, 0.34, 0.24, pulse), Color(0.28, 0.06, 0.05, 0.95))

		for node in tree.get_nodes_in_group("elite_enemies"):
			if not is_instance_valid(node) or not (node is Node2D):
				continue
			if bool(node.get("is_dead")) or bool(node.get("is_mini_boss")):
				continue
			var elite_node := node as Node2D
			var elite_sp: Vector2 = canvas_xform * elite_node.global_position
			if not inner_rect.has_point(elite_sp):
				drew_any = true
				_draw_edge_marker(vp_size, elite_sp, "精英", Color(0.82, 0.54, 0.98, pulse), Color(0.24, 0.10, 0.32, 0.95))
		_had_markers = drew_any

	func _draw_edge_marker(vp_size: Vector2, target_screen: Vector2, label_text: String, fill_col: Color, rim_col: Color) -> void:
		var center: Vector2 = vp_size * 0.5
		var dir: Vector2 = target_screen - center
		if dir.length_squared() < 1.0:
			return
		var left_b := 54.0
		var right_b := vp_size.x - 54.0
		var top_b := 88.0
		var bottom_b := vp_size.y - 46.0
		var tx := ((right_b - center.x) / dir.x) if dir.x > 0.001 else (((left_b - center.x) / dir.x) if dir.x < -0.001 else 1e9)
		var ty := ((bottom_b - center.y) / dir.y) if dir.y > 0.001 else (((top_b - center.y) / dir.y) if dir.y < -0.001 else 1e9)
		var edge_pos: Vector2 = center + dir * minf(tx, ty)
		var unit: Vector2 = dir.normalized()
		var perp: Vector2 = Vector2(-unit.y, unit.x)

		var tip: Vector2 = edge_pos + unit * 15.0
		var base_l: Vector2 = edge_pos - unit * 6.0 + perp * 10.0
		var base_r: Vector2 = edge_pos - unit * 6.0 - perp * 10.0
		var pts := PackedVector2Array([tip, base_l, base_r])
		draw_colored_polygon(pts, fill_col)
		draw_polyline(PackedVector2Array([tip, base_l, base_r, tip]), rim_col, 2.0, true)

		var badge_center: Vector2 = edge_pos - unit * 22.0
		var pill_rect := Rect2(badge_center - Vector2(22.0, 11.0), Vector2(44.0, 22.0))
		draw_rect(pill_rect, rim_col, true)
		draw_rect(pill_rect, fill_col, false, 1.5)
		var font: Font = get_theme_default_font()
		if font != null:
			draw_string(font, badge_center + Vector2(-14.0, 5.0), label_text, HORIZONTAL_ALIGNMENT_CENTER, 28.0, 13, Color(1.0, 0.97, 0.88, 1.0))
