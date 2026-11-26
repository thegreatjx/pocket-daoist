class_name OrbitWeaponRig
extends Node2D

signal weapon_fired(slot_index: int, weapon_data: Dictionary, tier_stats: Dictionary, origin: Vector2, target_pos: Vector2)
signal loadout_changed(slots: Array)

const MAX_WEAPON_TIER := 8
const FUSION_TIER := 9
const RECOIL_DURATION := 0.10
const RECOIL_DISTANCE := 25.0
const WINDUP_LEAD_SEC := 0.085
const WINDUP_PULL_DISTANCE := 9.0

@export var max_slots: int = 4
@export var orbit_radius_x: float = 54.0
@export var orbit_radius_y: float = 36.0
@export var weapon_sprite_scale: float = 0.20
@export var summon_on_cast_mode: bool = true

var loader: V2DataLoader
var slots: Array[Dictionary] = []
var unlocked_slots: int = 4
var starter_weapon_id: String = ""
var _hover_time: float = 0.0
var _facing: float = 1.0
var _hurt_scatter: float = 0.0

func trigger_hurt_scatter(strength: float = 1.0) -> void:
	_hurt_scatter = maxf(_hurt_scatter, clampf(strength, 0.3, 1.5))

func setup(data_loader: V2DataLoader) -> void:
	loader = data_loader
	if loader != null and loader.max_weapon_slots > 0:
		max_slots = loader.max_weapon_slots
		unlocked_slots = mini(unlocked_slots, max_slots)

func set_unlocked_slots(count: int) -> void:
	var next := clampi(count, 1, max_slots)
	if next == unlocked_slots:
		return
	unlocked_slots = next
	loadout_changed.emit(slots)

func get_unlocked_slots() -> int:
	return clampi(unlocked_slots, 1, max_slots)

func set_starter_weapon(weapon_id: String) -> void:
	starter_weapon_id = weapon_id
	for slot in slots:
		if bool(slot.get("is_fusion", false)):
			continue
		if String(slot.get("id", "")) != starter_weapon_id:
			continue
		var sp := slot.get("sprite") as Sprite2D
		if sp != null and is_instance_valid(sp):
			sp.visible = false

func has_free_slot() -> bool:
	return slots.size() < get_unlocked_slots()

func find_weapon_slot(weapon_id: String) -> int:
	for i in range(slots.size()):
		if not bool(slots[i]["is_fusion"]) and String(slots[i]["id"]) == weapon_id:
			return i
	return -1

func get_weapon_tier(weapon_id: String) -> int:
	var idx := find_weapon_slot(weapon_id)
	return int(slots[idx]["tier"]) if idx != -1 else 0

func has_fusion(_fusion_id: String) -> bool:
	return false

func can_upgrade_weapon(weapon_id: String) -> bool:
	var idx := find_weapon_slot(weapon_id)
	return idx != -1 and int(slots[idx]["tier"]) < MAX_WEAPON_TIER

func can_add_weapon(weapon_id: String, _tier: int = 1) -> bool:
	if loader == null or not loader.weapons_by_id.has(weapon_id):
		return false
	var existing_idx := find_weapon_slot(weapon_id)
	if existing_idx != -1:
		return int(slots[existing_idx]["tier"]) < MAX_WEAPON_TIER
	if slots.size() < get_unlocked_slots():
		return true
	return false

func add_weapon(weapon_id: String, tier: int = 1) -> bool:
	if not can_add_weapon(weapon_id, tier):
		return false

	var existing_idx := find_weapon_slot(weapon_id)
	if existing_idx != -1:
		var cur_tier: int = int(slots[existing_idx]["tier"])
		slots[existing_idx]["tier"] = clampi(maxi(cur_tier + 1, tier), 1, MAX_WEAPON_TIER)
		_sync_max_tier_visual(slots[existing_idx])
	elif slots.size() >= get_unlocked_slots():
		return false
	else:
		var w_def: Dictionary = loader.weapons_by_id[weapon_id]
		var sp := Sprite2D.new()
		var icon_path: String = String(w_def.get("icon", ""))
		if ResourceLoader.exists(icon_path):
			sp.texture = load(icon_path)
		sp.scale = Vector2(weapon_sprite_scale, weapon_sprite_scale)
		if weapon_id == starter_weapon_id:
			sp.visible = false
		add_child(sp)
		var seal := V2VfxFactory.make_sprite(V2VfxFactory.TEX_MAGIC_04, 240.0, Color(0.96, 0.86, 0.46, 0.78), true)
		seal.name = "SummonSeal"
		seal.z_index = -1
		seal.visible = false
		sp.add_child(seal)
		var slot_data := {
			"id": weapon_id,
			"tier": clampi(tier, 1, MAX_WEAPON_TIER),
			"cd_left": randf_range(0.05, 0.25),
			"is_fusion": false,
			"sprite": sp,
			"recoil": Vector2.ZERO,
			"recoil_peak": Vector2.ZERO,
			"recoil_elapsed": RECOIL_DURATION,
			"cast_vis": 0.0,
			"cast_dir": Vector2.RIGHT,
		}
		slots.append(slot_data)
		_sync_max_tier_visual(slot_data)

	_settle_fusions()
	loadout_changed.emit(slots)
	return true

func upgrade_weapon(weapon_id: String, step: int = 1) -> bool:
	if not can_upgrade_weapon(weapon_id):
		return false
	var idx := find_weapon_slot(weapon_id)
	slots[idx]["tier"] = mini(MAX_WEAPON_TIER, int(slots[idx]["tier"]) + maxi(1, step))
	_sync_max_tier_visual(slots[idx])
	_settle_fusions()
	loadout_changed.emit(slots)
	return true

func sell_weapon(slot_index: int) -> Dictionary:
	if slot_index < 0 or slot_index >= slots.size():
		return {}
	var removed: Dictionary = slots[slot_index]
	var sp: Sprite2D = removed.get("sprite") as Sprite2D
	if sp != null and is_instance_valid(sp):
		sp.queue_free()
	slots.remove_at(slot_index)
	loadout_changed.emit(slots)
	return removed

func _settle_fusions() -> void:
	return

func _try_fuse_once() -> bool:
	for recipe in loader.fusion_recipes:
		var req_tier: int = int(recipe.get("required_tier", MAX_WEAPON_TIER))
		var ing: Array = recipe["ingredients"]
		var idx_a: int = _find_slot(String(ing[0]), req_tier)
		var idx_b: int = _find_slot(String(ing[1]), req_tier)
		if idx_a != -1 and idx_b != -1 and idx_a != idx_b:
			var remove_first: int = maxi(idx_a, idx_b)
			var keep_idx: int = mini(idx_a, idx_b)
			var sp_rem: Sprite2D = slots[remove_first]["sprite"] as Sprite2D
			if sp_rem != null and is_instance_valid(sp_rem):
				sp_rem.queue_free()
			slots.remove_at(remove_first)
			_convert_slot_to_fusion(keep_idx, recipe)
			return true
	return false

func _convert_slot_to_fusion(slot_idx: int, recipe: Dictionary) -> void:
	slots[slot_idx]["id"] = String(recipe["id"])
	slots[slot_idx]["is_fusion"] = true
	slots[slot_idx]["tier"] = FUSION_TIER
	_apply_fusion_visual(slots[slot_idx], recipe)

func _apply_fusion_visual(slot: Dictionary, recipe: Dictionary) -> void:
	var sp_keep: Sprite2D = slot["sprite"] as Sprite2D
	if sp_keep == null or not is_instance_valid(sp_keep):
		return
	var max_fx := sp_keep.get_node_or_null("MaxTierParticles")
	if max_fx != null:
		max_fx.queue_free()
	for extra_name in ["MaxTierAura", "MaxTierTrail"]:
		var extra_fx := sp_keep.get_node_or_null(extra_name)
		if extra_fx != null:
			extra_fx.queue_free()

	var icon_path: String = String(recipe.get("icon", ""))
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		sp_keep.texture = load(icon_path)
	sp_keep.scale = Vector2(weapon_sprite_scale * 1.18, weapon_sprite_scale * 1.18)
	sp_keep.modulate = Color(1.25, 1.15, 0.95, 1.0)

	var fid := String(recipe.get("id", ""))
	var aura_col := _fusion_aura_color(recipe)
	if sp_keep.get_node_or_null("FusionAura") == null:
		var aura_tex := V2VfxFactory.TEX_MAGIC_05
		var accent := Color(1.0, 0.90, 0.45, 1.0)
		var petals := 6.0
		if fid == "fusion_thunder_frost_domain":
			aura_tex = V2VfxFactory.TEX_MAGIC_03
			accent = Color(0.75, 0.95, 1.0, 1.0)
			petals = 8.0
		elif fid == "fusion_venom_zen_bell":
			aura_tex = V2VfxFactory.TEX_MAGIC_02
			accent = Color(0.98, 0.84, 0.35, 1.0)
			petals = 8.0
		var aura := V2VfxFactory.make_shader_sprite(aura_tex, V2VfxFactory.SHADER_BAGUA_DOMAIN_WAVE, {
			"primary_color": Color(aura_col.r, aura_col.g, aura_col.b, 0.95),
			"accent_color": accent,
			"petal_count": petals,
			"spin_speed": 1.6,
			"alpha_limit": 0.48,
			"is_wave": 0.0,
		}, 196.0)
		aura.name = "FusionAura"
		aura.z_index = -1
		sp_keep.add_child(aura)

	if sp_keep.get_node_or_null("FusionParticles") == null:
		var p_tex := V2VfxFactory.TEX_FLAME_03
		var p_col := Color(1.0, 0.56, 0.16, 0.85)
		var p_add := true
		if fid == "fusion_thunder_frost_domain":
			p_tex = V2VfxFactory.TEX_SPARK_05
			p_col = Color(0.55, 0.84, 1.0, 0.90)
		elif fid == "fusion_venom_zen_bell":
			p_tex = V2VfxFactory.TEX_SMOKE_07
			p_col = Color(0.24, 0.88, 0.60, 0.55)
			p_add = false
		var fp := V2VfxFactory.make_gpu_particles(p_tex, {
			"amount": 8,
			"lifetime": 0.48,
			"one_shot": false,
			"local_coords": true,
			"shape": "ring",
			"shape_radius": 74.0,
			"vel_min": 8.0,
			"vel_max": 24.0,
			"scale_min": 0.08,
			"scale_max": 0.15,
			"additive": p_add,
			"color_start": p_col,
			"color_end": Color(p_col.r, p_col.g, p_col.b, 0.0),
		})
		fp.name = "FusionParticles"
		fp.z_index = -1
		sp_keep.add_child(fp)

	var sec_path: String = String(recipe.get("secondary_icon", ""))
	if not sec_path.is_empty() and ResourceLoader.exists(sec_path) and sp_keep.get_node_or_null("FusionSecondary") == null:
		var sec := Sprite2D.new()
		sec.name = "FusionSecondary"
		sec.texture = load(sec_path)
		sec.scale = Vector2(0.62, 0.62)
		sec.position = Vector2(-65.0, -45.0)
		sec.z_index = -1
		sp_keep.add_child(sec)

func _sync_max_tier_visual(slot: Dictionary) -> void:
	if bool(slot.get("is_fusion", false)) or int(slot.get("tier", 1)) < MAX_WEAPON_TIER:
		return
	var sp: Sprite2D = slot.get("sprite") as Sprite2D
	if sp == null or not is_instance_valid(sp) or sp.get_node_or_null("MaxTierAura") != null:
		return
	var w_def: Dictionary = _get_def(slot)
	var elem := String(w_def.get("element", "metal"))
	var profile: Dictionary = w_def.get("vfx_profile", {})
	var tex := V2VfxFactory.elem_glyph_texture("venom" if elem == "wood" else elem)
	var col := Color(0.98, 0.78, 0.24, 0.78)
	var is_add := true
	var max_hex := String(profile.get("max_tier_color", ""))
	if not max_hex.is_empty():
		col = Color.from_string(max_hex, col)
		col.a = 0.80
	else:
		match elem:
			"fire":
				col = Color(1.0, 0.52, 0.14, 0.78)
			"ice":
				col = Color(0.28, 0.84, 1.0, 0.78)
			"water":
				col = Color(0.12, 0.88, 0.94, 0.78)
			"thunder":
				col = Color(0.98, 0.88, 0.30, 0.85)
			"wood", "venom":
				col = Color(0.64, 0.90, 0.21, 0.72)
				is_add = false
			_:
				col = Color(0.98, 0.80, 0.12, 0.82)
	sp.scale = Vector2(weapon_sprite_scale * 1.18, weapon_sprite_scale * 1.18)
	sp.modulate = Color.WHITE.lerp(Color(col.r, col.g, col.b, 1.0), 0.22)

	var aura_tex := V2VfxFactory.TEX_MAGIC_04
	var petals := 8.0
	match elem:
		"fire":
			aura_tex = V2VfxFactory.TEX_FIRE_01
			petals = 6.0
		"ice":
			aura_tex = V2VfxFactory.TEX_STAR_08
			petals = 8.0
		"water":
			aura_tex = V2VfxFactory.TEX_CIRCLE_03
			petals = 6.0
		"thunder":
			aura_tex = V2VfxFactory.TEX_SPARK_05
			petals = 8.0
		"wood", "toxin", "venom":
			aura_tex = V2VfxFactory.TEX_TWIRL_01
			petals = 6.0
	var aura := V2VfxFactory.make_shader_sprite(aura_tex, V2VfxFactory.SHADER_BAGUA_DOMAIN_WAVE, {
		"primary_color": Color(col.r, col.g, col.b, 0.92),
		"accent_color": Color(1.0, 0.97, 0.82, 0.96),
		"petal_count": petals,
		"spin_speed": 1.5,
		"alpha_limit": 0.46,
		"is_wave": 0.0,
	}, 176.0)
	aura.name = "MaxTierAura"
	aura.z_index = -2
	sp.add_child(aura)

	var max_p := V2VfxFactory.make_gpu_particles(tex, {
		"amount": 7,
		"lifetime": 0.50,
		"one_shot": false,
		"local_coords": true,
		"shape": "sphere",
		"shape_radius": 52.0,
		"vel_min": 6.0,
		"vel_max": 20.0,
		"scale_min": 0.06,
		"scale_max": 0.12,
		"additive": is_add,
		"color_start": col,
		"color_end": Color(col.r, col.g, col.b, 0.0),
	})
	max_p.name = "MaxTierParticles"
	max_p.z_index = -1
	sp.add_child(max_p)

	var trail := V2VfxFactory.make_gpu_particles(tex, {
		"amount": 5,
		"lifetime": 0.55,
		"one_shot": false,
		"local_coords": true,
		"shape": "ring",
		"shape_radius": 36.0,
		"vel_min": 3.0,
		"vel_max": 12.0,
		"scale_min": 0.03,
		"scale_max": 0.07,
		"additive": is_add,
		"color_start": Color(col.r, col.g, col.b, col.a * 0.8),
		"color_end": Color(col.r, col.g, col.b, 0.0),
	})
	trail.name = "MaxTierTrail"
	trail.z_index = -1
	sp.add_child(trail)

func _fusion_aura_color(recipe: Dictionary) -> Color:
	var profile: Dictionary = recipe.get("vfx_profile", {})
	var hex: String = String(profile.get("trail_color", profile.get("bolt_color", profile.get("wave_color", "#F59E0B"))))
	var c := Color.from_string(hex, Color(0.96, 0.62, 0.04, 1.0))
	c.a = 0.32
	return c

func _find_fusion_match(weapon_id: String, tier: int) -> Dictionary:
	for recipe in loader.fusion_recipes:
		var req_tier: int = int(recipe.get("required_tier", MAX_WEAPON_TIER))
		if tier < req_tier:
			continue
		var ing: Array = recipe["ingredients"]
		if String(ing[0]) == weapon_id:
			var p_idx: int = _find_slot(String(ing[1]), req_tier)
			if p_idx != -1:
				return {"recipe": recipe, "partner_idx": p_idx}
		elif String(ing[1]) == weapon_id:
			var p_idx: int = _find_slot(String(ing[0]), req_tier)
			if p_idx != -1:
				return {"recipe": recipe, "partner_idx": p_idx}
	return {}

func _find_slot(weapon_id: String, req_tier: int) -> int:
	for i in range(slots.size()):
		if not bool(slots[i]["is_fusion"]) and String(slots[i]["id"]) == weapon_id and int(slots[i]["tier"]) >= req_tier:
			return i
	return -1

func trigger_slot_recoil(slot_index: int, shot_dir: Vector2, strength: float = 1.0) -> void:
	if slot_index < 0 or slot_index >= slots.size():
		return
	var d := shot_dir.normalized() if shot_dir.length_squared() > 0.0001 else Vector2.RIGHT
	var peak := -d * (RECOIL_DISTANCE * clampf(strength, 0.15, 1.5))
	var slot := slots[slot_index]
	slot["recoil_peak"] = peak
	slot["recoil_elapsed"] = 0.0
	slot["recoil"] = peak

func _apply_slot_transform(i: int, slot: Dictionary, count: int, delta: float) -> void:
	var sp: Sprite2D = slot["sprite"]
	var is_f: bool = bool(slot["is_fusion"])
	var base_sc: float = weapon_sprite_scale * (1.15 if is_f else 1.0)
	var cast_vis: float = float(slot.get("cast_vis", 0.0))
	var rec_t: float = clampf(float(slot.get("recoil_elapsed", RECOIL_DURATION)), 0.0, RECOIL_DURATION)
	var recoil_sq := Vector2.ONE
	if rec_t < RECOIL_DURATION:
		var k := 1.0 - rec_t / RECOIL_DURATION
		var rx := 1.0 - 0.14 * k
		recoil_sq = Vector2(rx, 1.0 / rx)
	var rec_vec: Vector2 = slot.get("recoil", Vector2.ZERO)
	var windup_u: float = clampf(float(slot.get("windup_u", 0.0)), 0.0, 1.0)
	var windup_vec := Vector2.ZERO
	var windup_sq := Vector2.ONE
	if windup_u > 0.0 and rec_t >= RECOIL_DURATION:
		var w_dir: Vector2 = slot.get("windup_dir", Vector2.RIGHT)
		windup_vec = -w_dir * (WINDUP_PULL_DISTANCE * windup_u)
		windup_sq = Vector2(1.0 - 0.10 * windup_u, 1.0 + 0.10 * windup_u)
	var scatter_vec := Vector2.ZERO
	if _hurt_scatter > 0.0:
		var ang_s: float = TAU * float(i) / float(maxi(1, count)) + _hover_time * 0.45
		var jitter_s := Vector2(sin(_hover_time * 52.0 + float(i) * 2.1), cos(_hover_time * 47.0 + float(i) * 1.7)) * (3.2 * _hurt_scatter)
		scatter_vec = Vector2(cos(ang_s), sin(ang_s)) * (18.0 * _hurt_scatter) + jitter_s

	if summon_on_cast_mode:
		if i == 0:
			sp.visible = true
			var poise := Vector2(-_facing * 34.0, -44.0 + sin(_hover_time * 3.0) * 2.5)
			sp.position = poise + rec_vec + windup_vec + scatter_vec
			sp.z_index = 2 if cast_vis > 0.05 else -1
			var target_rot: float = -0.45 * _facing
			if cast_vis > 0.0:
				var cd_dir: Vector2 = slot.get("cast_dir", Vector2.RIGHT)
				target_rot = clampf(cd_dir.x * 0.35, -0.45, 0.45)
			elif windup_u > 0.0:
				target_rot -= _facing * 0.16 * windup_u
			sp.rotation = lerpf(sp.rotation, target_rot, minf(1.0, delta * 14.0))
			sp.scale = Vector2(base_sc * recoil_sq.x * windup_sq.x, base_sc * recoil_sq.y * windup_sq.y)
			sp.modulate = Color(1.18, 1.12, 0.98, 0.98) if cast_vis > 0.0 else (Color(0.85, 0.65, 0.65, 0.92) if _hurt_scatter > 0.25 else Color(1.0, 1.0, 1.0, 0.95))
			var max_fx := sp.get_node_or_null("MaxTierParticles") as GPUParticles2D
			if max_fx != null:
				max_fx.emitting = true
		else:
			if cast_vis <= 0.0:
				sp.visible = false
				sp.modulate.a = 0.0
				var max_fx := sp.get_node_or_null("MaxTierParticles") as GPUParticles2D
				if max_fx != null:
					max_fx.emitting = false
				var seal := sp.get_node_or_null("SummonSeal") as Sprite2D
				if seal != null:
					seal.visible = false
			else:
				sp.visible = true
				var max_fx := sp.get_node_or_null("MaxTierParticles") as GPUParticles2D
				if max_fx != null:
					max_fx.emitting = true
				var p: float = 1.0 - clampf(cast_vis / 0.56, 0.0, 1.0)
				var seal := sp.get_node_or_null("SummonSeal") as Sprite2D
				if seal != null:
					seal.visible = true
					seal.rotation += delta * 2.8
					seal.modulate.a = clampf(1.0 - p, 0.0, 0.85)
				var cd_dir: Vector2 = slot.get("cast_dir", Vector2.RIGHT)
				var out_dir: Vector2 = cd_dir.normalized() if cd_dir.length_squared() > 0.001 else Vector2.RIGHT
				var slot_ang_jit := (float((i % 2) * 2 - 1)) * 0.24
				var anchor := out_dir.rotated(slot_ang_jit)
				sp.position = Vector2(anchor.x * 68.0, anchor.y * 56.0 - 34.0 - p * 10.0) + rec_vec
				sp.z_index = 2
				sp.rotation = clampf(out_dir.x * 0.22, -0.24, 0.24)
				var pop: float = lerpf(0.65, 1.12, minf(1.0, p / 0.18)) if p < 0.18 else lerpf(1.12, 1.0, minf(1.0, (p - 0.18) / 0.2))
				sp.scale = Vector2(base_sc * pop * recoil_sq.x, base_sc * pop * recoil_sq.y)
				var alpha: float = clampf(p / 0.12, 0.0, 1.0) if p < 0.12 else (clampf((1.0 - p) / 0.32, 0.0, 1.0) if p > 0.68 else 1.0)
				sp.modulate = Color(1.22, 1.16, 1.0, alpha)
	else:
		sp.visible = true
		var angle: float = TAU * float(i) / float(count) + _hover_time * 0.45
		var rest_pos := Vector2(cos(angle) * orbit_radius_x, sin(angle) * orbit_radius_y - 18.0)
		sp.position = rest_pos + Vector2(0, sin(_hover_time * 3.0 + float(i)) * 3.0) + rec_vec + windup_vec + scatter_vec
		sp.scale = Vector2(base_sc * recoil_sq.x * windup_sq.x, base_sc * recoil_sq.y * windup_sq.y)

	if is_f and sp.visible:
		var sec := sp.get_node_or_null("FusionSecondary") as Sprite2D
		if sec != null:
			var sec_ang: float = _hover_time * 2.4 + float(i)
			sec.position = Vector2(cos(sec_ang) * 72.0, sin(sec_ang) * 52.0)
		var f_aura := sp.get_node_or_null("FusionAura") as Sprite2D
		if f_aura != null:
			f_aura.rotation += delta * 0.8

	var max_aura := sp.get_node_or_null("MaxTierAura") as Sprite2D
	if max_aura != null and sp.visible:
		max_aura.rotation += delta * 1.4
		max_aura.modulate.a = 0.66 + 0.20 * sin(_hover_time * 3.1 + float(i) * 1.7)

func tick(delta: float, enemies: Array, attack_speed_mult: float = 1.0) -> void:
	_hover_time += delta
	if _hurt_scatter > 0.0:
		_hurt_scatter = maxf(0.0, _hurt_scatter - delta * 3.6)
	_update_facing()
	var count: int = maxi(1, slots.size())
	var windup_lead: float = WINDUP_LEAD_SEC * maxf(0.35, attack_speed_mult)
	for i in range(slots.size()):
		var slot: Dictionary = slots[i]
		var sp: Sprite2D = slot["sprite"]
		var cast_vis: float = maxf(0.0, float(slot.get("cast_vis", 0.0)) - delta)
		slot["cast_vis"] = cast_vis
		var rec_t: float = float(slot.get("recoil_elapsed", RECOIL_DURATION))
		if rec_t < RECOIL_DURATION:
			rec_t = minf(RECOIL_DURATION, rec_t + delta)
			slot["recoil_elapsed"] = rec_t
			var u := rec_t / RECOIL_DURATION
			slot["recoil"] = (slot.get("recoil_peak", Vector2.ZERO) as Vector2).lerp(Vector2.ZERO, u)
		else:
			slot["recoil"] = Vector2.ZERO

		var cd_before: float = float(slot["cd_left"])
		if cd_before > 0.0 and cd_before <= windup_lead and not enemies.is_empty():
			var w_def_pre: Dictionary = _get_def(slot)
			var stats_pre: Dictionary = _get_stats(slot, w_def_pre)
			var max_r_pre: float = float(stats_pre.get("range", stats_pre.get("aoe_radius", 320.0)))
			var origin_pre: Vector2 = global_position + Vector2(0.0, -24.0)
			var target_pre: Node2D = _find_nearest_enemy(origin_pre, enemies, max_r_pre)
			if target_pre != null:
				slot["windup_u"] = clampf(1.0 - cd_before / maxf(0.001, windup_lead), 0.0, 1.0)
				slot["windup_dir"] = (target_pre.global_position - origin_pre).normalized()
			else:
				slot["windup_u"] = 0.0
		else:
			slot["windup_u"] = 0.0

		_apply_slot_transform(i, slot, count, delta)

		slot["cd_left"] = float(slot["cd_left"]) - delta * attack_speed_mult
		if float(slot["cd_left"]) <= 0.0 and not enemies.is_empty():
			var w_def: Dictionary = _get_def(slot)
			var stats: Dictionary = _get_stats(slot, w_def)
			var max_r: float = float(stats.get("range", stats.get("aoe_radius", 320.0)))
			var origin_pos: Vector2 = global_position + Vector2(0.0, -24.0)
			var target: Node2D = _find_nearest_enemy(origin_pos, enemies, max_r)
			if target != null:
				var dir: Vector2 = (target.global_position - origin_pos).normalized()
				slot["cast_dir"] = dir
				slot["windup_u"] = 0.0
				slot["cast_vis"] = 0.28 if i == 0 else 0.56
				if not summon_on_cast_mode:
					sp.rotation = dir.angle()
				trigger_slot_recoil(i, dir, 1.0)
				_apply_slot_transform(i, slot, count, 0.0)
				slot["cd_left"] = float(stats.get("cooldown", 1.0))
				weapon_fired.emit(i, w_def, stats, origin_pos + dir * 24.0, target.global_position)

func _update_facing() -> void:
	var par := get_parent()
	if par != null and "player" in par and par.player != null and is_instance_valid(par.player):
		var pl: Node = par.player
		if "facing_dir" in pl:
			var fx: float = (pl.facing_dir as Vector2).x
			if absf(fx) > 0.1:
				_facing = -1.0 if fx < 0.0 else 1.0

func _get_def(slot: Dictionary) -> Dictionary:
	if bool(slot["is_fusion"]):
		for r in loader.fusion_recipes:
			if String(r["id"]) == String(slot["id"]):
				return r
		return {}
	return loader.weapons_by_id.get(String(slot["id"]), {})

func _get_stats(slot: Dictionary, w_def: Dictionary) -> Dictionary:
	if bool(slot["is_fusion"]):
		return w_def
	var tiers: Array = w_def.get("tiers", [])
	var idx: int = clampi(int(slot["tier"]) - 1, 0, tiers.size() - 1)
	return tiers[idx] if not tiers.is_empty() else {}

func _find_nearest_enemy(origin: Vector2, enemies: Array, max_range: float) -> Node2D:
	var best: Node2D = null
	var best_d2: float = max_range * max_range
	for e in enemies:
		if not is_instance_valid(e):
			continue
		var d2: float = origin.distance_squared_to((e as Node2D).global_position)
		if d2 < best_d2:
			best_d2 = d2
			best = e as Node2D
	return best
