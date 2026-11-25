class_name SpawnTelegraph
extends Node2D

var duration: float = 0.8
var radius: float = 34.0
var color: Color = Color(0.86, 0.15, 0.15, 1.0)
var on_complete: Callable = Callable()

var _elapsed: float = 0.0
var _done: bool = false
var _ring_sp: Sprite2D = null

func setup(world_pos: Vector2, telegraph_sec: float, rad: float, callback: Callable) -> void:
	global_position = world_pos
	duration = maxf(0.05, telegraph_sec)
	radius = maxf(14.0, rad)
	on_complete = callback
	z_index = -3
	add_to_group("spawn_telegraphs")
	_ring_sp = V2VfxFactory.make_shader_sprite(V2VfxFactory.TEX_MAGIC_05, V2VfxFactory.SHADER_BAGUA_DOMAIN_WAVE, {
		"primary_color": color,
		"accent_color": Color(1.0, 0.72, 0.36, 1.0),
		"progress": 0.0,
		"ring_width": 0.18,
		"petal_count": 6.0,
		"spin_speed": 2.8,
		"alpha_limit": 0.68,
		"is_wave": 0.0,
		"fade": 1.0,
	}, radius * 2.4)
	_ring_sp.scale.y *= 0.78
	add_child(_ring_sp)
	var gp := V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_SPARK_04, {
		"amount": 6,
		"lifetime": minf(0.45, duration),
		"one_shot": false,
		"explosiveness": 0.0,
		"shape": "ring",
		"shape_radius": radius * 0.65,
		"direction": Vector2(0.0, -1.0),
		"spread": 18.0,
		"vel_min": 28.0,
		"vel_max": 68.0,
		"scale_min": 0.025,
		"scale_max": 0.050,
		"color_start": Color(1.0, 0.65, 0.35, 0.88),
		"color_end": Color(color.r, color.g, color.b, 0.0),
	})
	add_child(gp)

func _process(delta: float) -> void:
	if _done:
		return
	_elapsed += delta
	var t := clampf(_elapsed / duration, 0.0, 1.0)
	if _ring_sp != null and is_instance_valid(_ring_sp):
		var sc := 0.55 + 0.55 * t
		var tex_sz := maxf(1.0, _ring_sp.texture.get_size().x)
		var base_sc := (radius * 2.4) / tex_sz
		_ring_sp.scale = Vector2(base_sc * sc, base_sc * sc * 0.78)
	if _elapsed >= duration:
		_done = true
		if get_parent() != null:
			V2VfxFactory.spawn_hit_spark(get_parent(), global_position, "fire", false, color)
		if on_complete.is_valid():
			on_complete.call(global_position)
		queue_free()
