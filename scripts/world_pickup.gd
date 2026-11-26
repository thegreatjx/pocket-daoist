extends Node2D
class_name WorldPickup

const TEX_PEACH: Texture2D = preload("res://assets/sprites/pickup_peach.png")
const TEX_SPIRIT_POUCH: Texture2D = preload("res://assets/sprites/pickup_spirit_pouch.png")
const TEX_QIANKUN_BAG: Texture2D = preload("res://assets/sprites/pickup_qiankun_bag.png")
const TEX_COMPASS: Texture2D = preload("res://assets/sprites/pickup_magnet.png")
const TEX_TAIXU_TALISMAN: Texture2D = preload("res://assets/sprites/pickup_taixu_talisman.png")
const TEX_GEM: Texture2D = preload("res://assets/sprites/exp_gem_jade.png")
const TEX_HALO: Texture2D = preload("res://addons/kenney_particle_pack/light_01.png")
const MAX_ACTIVE_SPIRIT_STONES := 40
const KIND_ALIASES := {
	"magnet": "qiankun_bag",
	"magnet_compass": "qiankun_bag",
	"frost_talisman": "taixu_talisman",
}

var kind: String = "peach"
var gold_amount: int = 0
var _anim_t: float = 0.0
var _age: float = 0.0
var _lifetime: float = 35.0
var _pickup_delay: float = 0.0
var _pop_vel: Vector2 = Vector2.ZERO
var _pop_h: float = 0.0
var _pop_vz: float = 0.0
var _magnet_attracting: bool = false

func _ready() -> void:
	if kind == "spirit_stone":
		if is_in_group("world_pickups"):
			remove_from_group("world_pickups")
		if not is_in_group("spirit_stones"):
			add_to_group("spirit_stones")
		_try_merge_excess_stones()
	elif not is_in_group("world_pickups"):
		add_to_group("world_pickups")

static func normalize_kind(pickup_kind: String) -> String:
	return String(KIND_ALIASES.get(pickup_kind, pickup_kind))

static func kind_auto_pulls(pickup_kind: String) -> bool:
	return normalize_kind(pickup_kind) == "spirit_stone"

func setup(pickup_kind: String, amount: int = 0) -> void:
	kind = normalize_kind(pickup_kind)
	gold_amount = maxi(1, amount) if kind == "spirit_stone" else amount
	_anim_t = 0.0
	_age = 0.0
	_lifetime = 120.0 if kind == "spirit_stone" else 35.0
	_pickup_delay = 0.0
	_pop_vel = Vector2.ZERO
	_pop_h = 0.0
	_pop_vz = 0.0
	_magnet_attracting = false
	if kind == "spirit_stone":
		if is_in_group("world_pickups"):
			remove_from_group("world_pickups")
		if not is_in_group("spirit_stones"):
			add_to_group("spirit_stones")
		_try_merge_excess_stones()
	else:
		if is_in_group("spirit_stones"):
			remove_from_group("spirit_stones")
		if not is_in_group("world_pickups"):
			add_to_group("world_pickups")
	queue_redraw()

func attract_to(_player: Node2D = null, force: bool = false) -> void:
	if not force and not kind_auto_pulls(kind):
		return
	_magnet_attracting = true
	_pickup_delay = 0.0

func _try_merge_excess_stones() -> void:
	if not is_inside_tree() or get_tree() == null:
		return
	var stones := get_tree().get_nodes_in_group("spirit_stones")
	if stones.size() <= MAX_ACTIVE_SPIRIT_STONES:
		return
	var candidates: Array = []
	for s in stones:
		if s != self and is_instance_valid(s) and not s.is_queued_for_deletion() and not bool(s.get("_magnet_attracting")):
			candidates.append(s)
	candidates.sort_custom(func(a, b): return float(a.get("_age")) > float(b.get("_age")))
	if candidates.size() < 2:
		return
	var anchor = candidates[0]
	var merged := 0
	for i in range(1, mini(9, candidates.size())):
		var st = candidates[i]
		merged += maxi(1, int(st.get("gold_amount")))
		st.set("gold_amount", 0)
		if st.is_in_group("spirit_stones"):
			st.remove_from_group("spirit_stones")
		st.queue_free()
	anchor.set("gold_amount", maxi(1, int(anchor.get("gold_amount"))) + merged)
	anchor.queue_redraw()

func pop_out(away_dir: Vector2 = Vector2.ZERO) -> void:
	var dir := away_dir.normalized() if away_dir.length_squared() > 0.01 else Vector2.from_angle(randf() * TAU)
	_pop_vel = dir * randf_range(95.0, 140.0)
	_pop_h = 2.0
	_pop_vz = 155.0
	_pickup_delay = 0.45

func _physics_process(delta: float) -> void:
	_anim_t += delta
	_age += delta
	_lifetime -= delta
	if _lifetime <= 0.0:
		queue_free()
		return
	if _pickup_delay > 0.0:
		_pickup_delay = maxf(0.0, _pickup_delay - delta)
		global_position += _pop_vel * delta
		_pop_vel = _pop_vel.lerp(Vector2.ZERO, minf(1.0, delta * 5.2))
		_pop_h = maxf(0.0, _pop_h + _pop_vz * delta)
		_pop_vz -= 640.0 * delta
		if _pop_h <= 0.0 and _pop_vz < 0.0:
			_pop_h = 0.0
			_pop_vz = 0.0
		queue_redraw()
		return
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0 and is_instance_valid(players[0]):
		var p = players[0]
		var dist := global_position.distance_to(p.global_position)
		if kind_auto_pulls(kind) or _magnet_attracting:
			var pull_r := maxf(64.0, float(p.magnet_radius))
			var fly_spd := 680.0 if _magnet_attracting else 580.0
			if _magnet_attracting or dist <= pull_r:
				global_position = global_position.move_toward(p.global_position, fly_spd * delta)
			if dist <= 28.0:
				_collect(p)
				return
		elif dist <= _contact_radius():
			_collect(p)
			return
	queue_redraw()

func _contact_radius() -> float:
	match kind:
		"qiankun_bag", "taixu_talisman", "thunder_seal":
			return 26.0
		_:
			return 22.0

func _collect(player: Node) -> void:
	match kind:
		"peach":
			if player.has_method("heal"):
				player.heal(35.0)
			Sfx.play("level_up", -10.0, 1.35)
			get_tree().call_group("ui", "show_banner", "拾得【仙林蟠桃】· 恢复 35 气血")
		"spirit_stone":
			if player.has_method("gain_exp"):
				player.gain_exp(18.0)
			Sfx.play("gem_pickup", -8.0, 1.32)
		"spirit_pouch":
			if player.has_method("gain_exp"):
				player.gain_exp(45.0)
			Sfx.play_gem_pickup()
			get_tree().call_group("ui", "show_banner", "拾得【灵石锦囊】· 修为 +45")
		"qiankun_bag":
			_collect_qiankun_bag(player)
		"taixu_talisman":
			_collect_taixu_talisman(player)
		"thunder_seal":
			for e in get_tree().get_nodes_in_group("enemies"):
				if is_instance_valid(e) and not bool(e.get("is_dead")) and not bool(e.get("is_boss")):
					if e.has_method("take_damage"):
						e.take_damage(99999.0)
			Sfx.play("thunder", -2.0, 0.9)
			get_tree().call_group("ui", "show_banner", "激活【神霄灭魔符】· 天雷清屏！")
		_:
			if player.has_method("gain_exp"):
				player.gain_exp(35.0)
			Sfx.play_gem_pickup()
	queue_free()

func _collect_qiankun_bag(player: Node) -> void:
	var p2 := player as Node2D
	if p2 == null:
		return
	for g in get_tree().get_nodes_in_group("exp_gems"):
		if is_instance_valid(g) and g.has_method("attract_to"):
			g.attract_to(p2)
	for st in get_tree().get_nodes_in_group("spirit_stones"):
		if st != self and is_instance_valid(st) and st.has_method("attract_to"):
			st.attract_to(p2)
	Sfx.play("gem_pickup", -6.0, 1.18)
	get_tree().call_group("ui", "show_banner", "激活【聚灵罗盘】· 全图灵玉与灵石汇聚而来！")
	_popup_text(player, "聚灵罗盘 · 全图汇灵", Color(0.45, 0.96, 0.86))

func _collect_taixu_talisman(player: Node) -> void:
	var p2 := player as Node2D
	if p2 == null:
		return
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or bool(e.get("is_dead")):
			continue
		if e.has_method("apply_freeze"):
			e.apply_freeze(5.0)
	if get_parent() != null:
		V2VfxFactory.spawn_taixu_domain(get_parent(), p2.global_position, 960.0)
	Sfx.play("thunder", -5.0, 1.52)
	get_tree().call_group("ui", "show_banner", "激活【太虚定身符】· 全场妖物定身 5 秒，首领定身 1.5 秒！")
	_popup_text(player, "太虚定身符 · 时停 5 秒", Color(0.62, 0.94, 1.0))
	if player.has_method("shake_camera"):
		player.shake_camera(5.0)

func _popup_text(player: Node, text: String, color: Color) -> void:
	if not ("v2_combat" in player) or player.v2_combat == null:
		return
	var p2 := player as Node2D
	if p2 == null:
		return
	if player.v2_combat.has_method("_spawn_text_popup"):
		player.v2_combat._spawn_text_popup(p2.global_position + Vector2(0.0, -42.0), text, color)

func _draw() -> void:
	var bob := sin(_anim_t * 4.5) * 3.5 - _pop_h
	draw_set_transform(Vector2(0.0, 15.0), 0.0, Vector2(1.0, 0.44))
	draw_circle(Vector2.ZERO, 15.0, Color(0.06, 0.14, 0.10, 0.28))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var tex: Texture2D = TEX_PEACH
	var glow := Color(1.0, 0.68, 0.78, 0.45)
	var icon_sz := 44.0
	var base_halo := 30.0
	match kind:
		"spirit_stone":
			tex = TEX_SPIRIT_POUCH
			glow = Color(1.0, 0.84, 0.28, 0.52)
			if gold_amount <= 2:
				icon_sz = 26.0
				base_halo = 18.0
			elif gold_amount <= 5:
				icon_sz = 32.0
				base_halo = 22.0
			else:
				icon_sz = 38.0
				base_halo = 26.0
		"spirit_pouch":
			tex = TEX_SPIRIT_POUCH
			glow = Color(1.0, 0.86, 0.36, 0.50)
		"qiankun_bag":
			tex = TEX_COMPASS
			glow = Color(0.32, 0.90, 0.82, 0.48)
			icon_sz = 46.0
		"medium_gem", "big_gem":
			tex = TEX_GEM
			glow = Color(0.32, 0.94, 0.72, 0.48)
		"taixu_talisman":
			tex = TEX_TAIXU_TALISMAN
			glow = Color(0.52, 0.92, 1.0, 0.54)
			icon_sz = 46.0
		"thunder_seal":
			tex = TEX_GEM
			glow = Color(0.86, 0.56, 1.0, 0.52)
	var halo_r := base_halo + sin(_anim_t * 5.0) * 3.0
	draw_texture_rect(TEX_HALO, Rect2(-halo_r, -halo_r + bob, halo_r * 2.0, halo_r * 2.0), false, glow)
	if tex != null:
		draw_texture_rect(tex, Rect2(-icon_sz * 0.5, -icon_sz * 0.5 + bob, icon_sz, icon_sz), false)
