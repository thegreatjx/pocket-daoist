extends Node2D
class_name BreakableJar

const TEX_JAR: Texture2D = preload("res://assets/props/celadon_jar.png")
const PICKUP_SCENE := "res://scenes/world_pickup.tscn"
const PICKUPS_JSON_PATH := "res://data/v2/pickups_v2.json"

const FALLBACK_DROPS := [
	{"id": "peach", "unlocks_at_level": 1, "weight": 45},
	{"id": "spirit_pouch", "unlocks_at_level": 1, "weight": 20},
	{"id": "medium_gem", "unlocks_at_level": 1, "weight": 20},
	{"id": "taixu_talisman", "unlocks_at_level": 5, "weight": 8},
	{"id": "qiankun_bag", "unlocks_at_level": 8, "weight": 6},
	{"id": "thunder_seal", "unlocks_at_level": 12, "weight": 4},
]

static var _cached_table: Array[Dictionary] = []

var hp: float = 20.0
var is_broken: bool = false
var _anim_t: float = 0.0

static func _load_drop_table() -> Array[Dictionary]:
	if not _cached_table.is_empty():
		return _cached_table
	if FileAccess.file_exists(PICKUPS_JSON_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PICKUPS_JSON_PATH))
		if parsed is Dictionary and parsed.has("pickups") and parsed["pickups"] is Array:
			for raw in parsed["pickups"]:
				if raw is Dictionary:
					_cached_table.append((raw as Dictionary).duplicate(true))
	if _cached_table.is_empty():
		for item in FALLBACK_DROPS:
			_cached_table.append((item as Dictionary).duplicate(true))
	return _cached_table

static func get_eligible_drops(player_level: int, frost_mult: float = 1.0) -> Array[Dictionary]:
	var lv := maxi(1, player_level)
	var out: Array[Dictionary] = []
	for entry in _load_drop_table():
		if int(entry.get("unlocks_at_level", 1)) <= lv:
			var item := entry.duplicate(true)
			var w := float(item.get("weight", 10))
			if String(item.get("id", "")) == "taixu_talisman":
				w *= maxf(0.1, frost_mult)
			item["effective_weight"] = w
			out.append(item)
	return out

static func roll_drop_kind(player_level: int, frost_mult: float = 1.0, rng_val: float = -1.0) -> String:
	var pool := get_eligible_drops(player_level, frost_mult)
	if pool.is_empty():
		return "peach"
	var total := 0.0
	for item in pool:
		total += float(item.get("effective_weight", 1.0))
	var r := (clampf(rng_val, 0.0, 0.999999) if rng_val >= 0.0 else randf()) * maxf(0.001, total)
	var acc := 0.0
	for item in pool:
		acc += float(item.get("effective_weight", 1.0))
		if r < acc:
			return String(item.get("id", "peach"))
	return String(pool[pool.size() - 1].get("id", "peach"))

func _ready() -> void:
	add_to_group("breakables")

func take_damage(amount: float) -> void:
	if is_broken:
		return
	hp -= amount
	if hp <= 0.0:
		_shatter()

func _shatter() -> void:
	is_broken = true
	Sfx.play_varied("jar_break", -6.0)
	var player_lv := 1
	var frost_mult := 1.0
	var away_dir := Vector2.ZERO
	if is_inside_tree() and get_tree() != null:
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0 and is_instance_valid(players[0]):
			var pl = players[0]
			away_dir = global_position - (pl as Node2D).global_position
			player_lv = int(pl.get("level")) if pl.get("level") != null else 1
			if "v2_combat" in pl and pl.v2_combat != null and pl.v2_combat.has_method("has_arcana"):
				if pl.v2_combat.has_arcana("arcana_glacial_shatter"):
					frost_mult = 2.0
		var gm = get_tree().get_first_node_in_group("game_manager")
		if gm != null and gm.has_method("on_jar_broken"):
			gm.on_jar_broken()
	var kind := roll_drop_kind(player_lv, frost_mult)
	if get_parent() != null:
		V2VfxFactory.spawn_hit_spark(get_parent(), global_position, "water", true)
	var scene := load(PICKUP_SCENE) as PackedScene
	if scene != null and get_parent() != null:
		var p = scene.instantiate()
		p.global_position = global_position
		get_parent().add_child(p)
		if p.has_method("setup"):
			p.setup(kind)
		if p.has_method("pop_out"):
			p.pop_out(away_dir)
	queue_free()

func _process(delta: float) -> void:
	_anim_t += delta
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0 and is_instance_valid(players[0]):
		var pl = players[0]
		if global_position.distance_to(pl.global_position) <= 28.0:
			_shatter()
			return
	queue_redraw()

func _draw() -> void:
	draw_set_transform(Vector2(0.0, 18.0), 0.0, Vector2(1.0, 0.44))
	draw_circle(Vector2.ZERO, 16.0, Color(0.08, 0.18, 0.14, 0.22))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var pulse := 0.14 + 0.06 * sin(_anim_t * 4.0)
	draw_circle(Vector2(0.0, -2.0), 22.0, Color(0.32, 0.90, 0.78, pulse))
	if TEX_JAR != null:
		draw_texture_rect(TEX_JAR, Rect2(-24.0, -32.0, 48.0, 48.0), false)
