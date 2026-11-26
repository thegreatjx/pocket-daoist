extends Node2D
class_name BossAttack
## Boss 专属技能表现与判定器：
## - CIRCLE_SLAM: 地面红金预警圈 + 倒计时填充 + 引爆冲击波与伤害
## - LINE_DASH:   直线扑杀警戒走廊（仅作视觉预告，配合 Boss 高速突进）
## - PROJECTILE:  高对比度绯红/紫金妖气弹幕（深色外描边确保弹幕清晰可读）

enum Kind { CIRCLE_SLAM, LINE_DASH, PROJECTILE }
const SLAM_Y_SCALE := 0.80

var kind: int = Kind.CIRCLE_SLAM
var owner_boss: Node2D = null
var damage: float = 24.0
var radius: float = 110.0
var duration: float = 0.85
var dir: Vector2 = Vector2.RIGHT
var length: float = 420.0
var width: float = 68.0
var speed: float = 290.0
var color_primary: Color = Color(0.98, 0.24, 0.22, 1.0)
var color_accent: Color = Color(1.0, 0.82, 0.34, 1.0)
var persist_after_owner_death: bool = false
var slow_ratio: float = 0.0
var slow_dur: float = 0.0

var _elapsed: float = 0.0
var _detonated: bool = false
var _blast_t: float = 0.0
var _blast_dur: float = 0.28
var _cached_player: Node2D = null
var _cached_bg: Node = null
var _vfx_root: Node2D = null
var _proj_spin: Sprite2D = null
var _slam_shader_mat: ShaderMaterial = null

func _clear_vfx_children() -> void:
	if _vfx_root != null and is_instance_valid(_vfx_root):
		_vfx_root.queue_free()
	_vfx_root = null
	_proj_spin = null
	_slam_shader_mat = null

func _ensure_vfx_root() -> Node2D:
	_clear_vfx_children()
	_vfx_root = Node2D.new()
	add_child(_vfx_root)
	return _vfx_root

func pool_acquire() -> void:
	_clear_vfx_children()
	kind = Kind.CIRCLE_SLAM
	slow_ratio = 0.0
	slow_dur = 0.0
	owner_boss = null
	damage = 24.0
	radius = 110.0
	duration = 0.85
	dir = Vector2.RIGHT
	length = 420.0
	width = 68.0
	speed = 290.0
	color_primary = Color(0.98, 0.24, 0.22, 1.0)
	color_accent = Color(1.0, 0.82, 0.34, 1.0)
	persist_after_owner_death = false
	_elapsed = 0.0
	_detonated = false
	_blast_t = 0.0
	_cached_player = null
	_cached_bg = null
	visible = true
	modulate = Color.WHITE
	scale = Vector2.ONE
	rotation = 0.0

func _release_self() -> void:
	_clear_vfx_children()
	if is_in_group("boss_attacks"):
		remove_from_group("boss_attacks")
	if has_node("/root/ObjectPools"):
		ObjectPools.release_script(self)
	else:
		queue_free()

func _get_pillars() -> Array:
	if _cached_bg == null or not is_instance_valid(_cached_bg):
		var tree := get_tree()
		if tree != null:
			_cached_bg = tree.get_first_node_in_group("background")
	if _cached_bg != null and _cached_bg.has_method("get_pillars"):
		return _cached_bg.get_pillars()
	return []

func _get_player() -> Node2D:
	if _cached_player != null and is_instance_valid(_cached_player):
		return _cached_player
	var tree := get_tree()
	if tree == null:
		return null
	var players := tree.get_nodes_in_group("player")
	if players.size() > 0 and is_instance_valid(players[0]):
		_cached_player = players[0]
		return _cached_player
	return null

func is_point_in_slam(world_pos: Vector2) -> bool:
	var diff := world_pos - global_position
	var scaled := Vector2(diff.x, diff.y / SLAM_Y_SCALE)
	return scaled.length_squared() <= (radius + 10.0) * (radius + 10.0)

func setup_circle_slam(boss: Node2D, world_pos: Vector2, rad: float, windup: float, dmg: float, primary: Color = Color(0.98, 0.24, 0.22, 1.0)) -> void:
	kind = Kind.CIRCLE_SLAM
	owner_boss = boss
	global_position = world_pos
	radius = rad
	duration = maxf(0.25, windup)
	damage = dmg
	color_primary = primary
	z_index = -2
	add_to_group("boss_attacks")
	var vr := _ensure_vfx_root()
	var array_sp := V2VfxFactory.make_shader_sprite(V2VfxFactory.TEX_MAGIC_04, V2VfxFactory.SHADER_BAGUA_DOMAIN_WAVE, {
		"primary_color": primary,
		"accent_color": color_accent,
		"progress": 0.15,
		"ring_width": 0.16,
		"petal_count": 6.0,
		"spin_speed": 2.2,
		"alpha_limit": 0.56,
		"is_wave": 0.0,
		"fade": 1.0,
	}, rad * 2.15)
	array_sp.scale.y *= SLAM_Y_SCALE
	_slam_shader_mat = array_sp.material as ShaderMaterial
	vr.add_child(array_sp)
	queue_redraw()

func setup_line_dash(boss: Node2D, start_pos: Vector2, direction: Vector2, dash_len: float, dash_w: float, windup: float) -> void:
	kind = Kind.LINE_DASH
	owner_boss = boss
	global_position = start_pos
	dir = direction.normalized() if direction.length_squared() > 0.001 else Vector2.RIGHT
	length = dash_len
	width = dash_w
	duration = maxf(0.2, windup)
	z_index = -2
	add_to_group("boss_attacks")
	var vr := _ensure_vfx_root()
	var beam := V2VfxFactory.make_shader_line(V2VfxFactory.SHADER_SWORD_GLINT_TRAIL, dash_w * 0.78, {
		"core_color": color_accent,
		"edge_color": color_primary,
		"scroll_speed": 4.2,
		"alpha_scale": 0.65,
	})
	beam.add_point(Vector2.ZERO)
	beam.add_point(dir * dash_len)
	vr.add_child(beam)
	V2VfxFactory.spawn_boss_charge_aura(boss.get_parent() if boss != null and boss.get_parent() != null else self, start_pos, dash_w * 0.72, color_primary, duration * 0.9)
	queue_redraw()

func setup_projectile(boss: Node2D, start_pos: Vector2, direction: Vector2, spd: float, dmg: float, rad: float = 14.0, primary: Color = Color(0.96, 0.26, 0.42, 1.0)) -> void:
	kind = Kind.PROJECTILE
	owner_boss = boss
	global_position = start_pos
	dir = direction.normalized() if direction.length_squared() > 0.001 else Vector2.RIGHT
	speed = spd
	damage = dmg
	radius = rad
	duration = 3.2
	color_primary = primary
	z_index = 4
	add_to_group("boss_attacks")
	var vr := _ensure_vfx_root()
	var rim := V2VfxFactory.make_sprite(V2VfxFactory.TEX_CIRCLE_05, rad * 2.75, Color(0.14, 0.03, 0.08, 0.88), false)
	vr.add_child(rim)
	var spin := V2VfxFactory.make_sprite(V2VfxFactory.TEX_TWIRL_02, rad * 3.1, Color(primary.r, primary.g, primary.b, 0.96), true)
	vr.add_child(spin)
	_proj_spin = spin
	var core := V2VfxFactory.make_sprite(V2VfxFactory.TEX_FLARE_01, rad * 2.5, color_accent, true)
	vr.add_child(core)
	var trail := V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_SPARK_05, {
		"amount": 12,
		"lifetime": 0.28,
		"one_shot": false,
		"explosiveness": 0.0,
		"direction": -dir,
		"spread": 22.0,
		"vel_min": 32.0,
		"vel_max": 85.0,
		"scale_min": 0.032,
		"scale_max": 0.068,
		"color_start": color_accent,
		"color_end": Color(primary.r, primary.g, primary.b, 0.0),
	})
	vr.add_child(trail)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if kind != Kind.PROJECTILE and not persist_after_owner_death and (owner_boss == null or not is_instance_valid(owner_boss) or bool(owner_boss.get("is_dead"))):
		if not _detonated:
			_release_self()
			return

	match kind:
		Kind.CIRCLE_SLAM:
			if not _detonated:
				_elapsed += delta
				if _slam_shader_mat != null:
					var prog := clampf(_elapsed / maxf(0.01, duration), 0.0, 1.0)
					_slam_shader_mat.set_shader_parameter("progress", 0.15 + prog * 0.85)
				if _elapsed >= duration:
					_detonate_circle()
			else:
				_blast_t += delta
				if _blast_t >= _blast_dur:
					_release_self()
					return
			queue_redraw()

		Kind.LINE_DASH:
			_elapsed += delta
			if _elapsed >= duration:
				_release_self()
				return
			queue_redraw()

		Kind.PROJECTILE:
			_elapsed += delta
			global_position += dir * speed * delta
			if _proj_spin != null and is_instance_valid(_proj_spin):
				_proj_spin.rotation += delta * 9.5
			if _elapsed >= duration:
				_release_self()
				return
			var pillars := _get_pillars()
			if not pillars.is_empty() and EnemySteeringDirector.check_pillar_collision(global_position, radius, pillars):
				if get_parent() != null:
					V2VfxFactory.spawn_hit_spark(get_parent(), global_position, "fire", false, color_primary)
				_release_self()
				return
			var p := _get_player()
			if p != null:
				if global_position.distance_squared_to(p.global_position) <= (radius + 14.0) * (radius + 14.0):
					if p.has_method("take_damage"):
						p.take_damage(damage)
					if slow_ratio > 0.0 and p.has_method("apply_slow"):
						p.apply_slow(slow_ratio, slow_dur)
					if get_parent() != null:
						V2VfxFactory.spawn_hit_spark(get_parent(), global_position, "fire", true, color_primary)
					_release_self()
					return

func _detonate_circle() -> void:
	_detonated = true
	_blast_t = 0.0
	_clear_vfx_children()
	if get_parent() != null:
		V2VfxFactory.spawn_boss_shockwave(get_parent(), global_position, radius, color_primary, color_accent, 0.42)
	Sfx.play_boss_or_fallback("boss_slam", "thunder", -3.0)
	var p := _get_player()
	if p != null:
		if p.has_method("shake_camera"):
			p.shake_camera(7.5)
		if is_point_in_slam(p.global_position):
			if p.has_method("take_damage"):
				p.take_damage(damage)
			if slow_ratio > 0.0 and p.has_method("apply_slow"):
				p.apply_slow(slow_ratio, slow_dur)

func _draw() -> void:
	match kind:
		Kind.CIRCLE_SLAM:
			_draw_circle_slam()
		Kind.LINE_DASH:
			_draw_line_dash()
		Kind.PROJECTILE:
			pass

func _draw_circle_slam() -> void:
	if _detonated:
		return
	var t := clampf(_elapsed / maxf(0.01, duration), 0.0, 1.0)
	var pulse := 0.78 + 0.22 * sin(_elapsed * 22.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, SLAM_Y_SCALE))
	draw_circle(Vector2.ZERO, radius * t, Color(color_primary.r, color_primary.g, color_primary.b, 0.22 + 0.22 * t))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 44, Color(color_primary.r, color_primary.g, color_primary.b, 0.85 * pulse), 2.8)
	draw_arc(Vector2.ZERO, radius * t, 0.0, TAU, 36, Color(color_accent.r, color_accent.g, color_accent.b, 0.90), 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_line_dash() -> void:
	var t := clampf(_elapsed / maxf(0.01, duration), 0.0, 1.0)
	var ang := dir.angle()
	var pulse := 0.78 + 0.22 * sin(_elapsed * 26.0)
	draw_set_transform(Vector2.ZERO, ang, Vector2.ONE)
	draw_rect(Rect2(0.0, -width * 0.5, length * t, width), Color(color_primary.r, color_primary.g, color_primary.b, 0.24 + 0.16 * t))
	draw_line(Vector2(0.0, -width * 0.5), Vector2(length, -width * 0.5), Color(color_primary.r, color_primary.g, color_primary.b, 0.9 * pulse), 2.6)
	draw_line(Vector2(0.0, width * 0.5), Vector2(length, width * 0.5), Color(color_primary.r, color_primary.g, color_primary.b, 0.9 * pulse), 2.6)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
