extends Node2D

const TEX_RUN: Texture2D = preload("res://assets/sprites/anim_hero_run.png")
const TEX_GUNNER_RUN: Texture2D = preload("res://assets/sprites/anim_gunner_run.png")
const CELL := 128.0
const RUN_FRAMES := 8

var character_id: String = "sword_immortal"
var lifetime: float = 0.22
var max_lifetime: float = 0.22
var facing_sign: float = 1.0
var dir_mode: int = 0
var frame_idx: int = 0
var dash_tilt: float = 0.0

func pool_acquire() -> void:
	lifetime = max_lifetime
	facing_sign = 1.0
	dir_mode = 0
	frame_idx = 0
	dash_tilt = 0.0
	visible = true
	modulate = Color(1, 1, 1, 1)
	queue_redraw()

func setup_pose(f_sign: float, f_idx: int = 0, tilt: float = 0.0) -> void:
	dir_mode = 0
	facing_sign = -1.0 if f_sign < 0.0 else 1.0
	frame_idx = clampi(f_idx, 0, RUN_FRAMES - 1)
	dash_tilt = tilt
	queue_redraw()

func setup_pose_dir(row: int, f_idx: int = 0, tilt: float = 0.0) -> void:
	dir_mode = 0
	facing_sign = -1.0 if (row >= 3 and row <= 5) else 1.0
	frame_idx = clampi(f_idx, 0, RUN_FRAMES - 1)
	dash_tilt = tilt
	queue_redraw()

func _process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0:
		ObjectPools.release(self)
	else:
		queue_redraw()

func _draw() -> void:
	var t := clampf(lifetime / max_lifetime, 0.0, 1.0)
	var cfg := CharacterData.get_character(character_id)
	var mode := str(cfg.get("motion_mode", "hover_ride"))
	var acc_val = cfg.get("accent_color", Color(0.35, 0.96, 0.86))
	var acc: Color = acc_val if acc_val is Color else Color(0.35, 0.96, 0.86)
	var col := Color(acc.r, acc.g, acc.b, t * 0.52)

	if mode != "sheet":
		var sp_path := str(cfg.get("sprite", ""))
		if sp_path != "" and ResourceLoader.exists(sp_path):
			var single_tex := load(sp_path) as Texture2D
			if single_tex != null:
				var tex_sz := single_tex.get_size()
				var draw_h := float(cfg.get("draw_height", 86.0 if mode == "hover_ride" else 66.0))
				var draw_w := draw_h * (tex_sz.x / maxf(1.0, tex_sz.y))
				var y_base := 9.0 if mode == "hover_ride" else 20.0
				draw_set_transform(Vector2(0.0, y_base), dash_tilt, Vector2(1.08 * facing_sign, 0.92))
				draw_texture_rect(single_tex, Rect2(-draw_w * 0.5, -draw_h, draw_w, draw_h), false, col)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				return

	var is_gunner := character_id == "jinyiwei_gunner"
	var tex: Texture2D = TEX_GUNNER_RUN if is_gunner else TEX_RUN
	if tex != null:
		draw_set_transform(Vector2(0.0, 22.0), dash_tilt, Vector2(1.08 * facing_sign, 0.92))
		draw_texture_rect_region(tex, Rect2(-46.0, -86.0, 92.0, 92.0), Rect2(float(frame_idx % RUN_FRAMES) * CELL, 0.0, CELL, CELL), col)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_circle(Vector2(0, -14), 10.0, Color(acc.r, acc.g, acc.b, t * 0.34))
