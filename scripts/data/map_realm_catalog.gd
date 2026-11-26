class_name MapRealmCatalog

const REALMS := {
	"tutorial": {
		"mode": "classic",
		"map_size": 2800.0,
		"arena_height": 2000.0,
		"particles": "",
	},
	"forest": {
		"mode": "realm",
		"seed": 1001,
		"map_size": 4200.0,
		"center_dojo_radius": 560.0,
		"center_array_size": 640.0,
		"center_array_radius": 320.0,
		"road_half_width": 85.0,
		"road_end_radius": 1880.0,
		"obstacle_count": 20,
		"obstacle_min_spacing": 280.0,
		"ground_tile": "res://assets/v2/maps/forest/tile_ground_grass.png",
		"ground_tint": Color(0.94, 0.97, 0.92, 1.0),
		"road_decal": "res://assets/v2/maps/forest/decal_road_stone.png",
		"center_array": "res://assets/v2/maps/forest/decal_spirit_array.png",
		"center_array_name": "聚灵大阵",
		"border": "res://assets/v2/maps/forest/border_cliff_trees.png",
		"border_step": 220.0,
		"border_scale": 0.62,
		"prop_pool": [
			{"tex": "res://assets/v2/maps/forest/prop_ancient_pine.png", "weight": 0.60, "height": 230.0, "coll_ratio": 0.24, "occlude": true},
			{"tex": "res://assets/v2/maps/forest/prop_jade_rock.png", "weight": 0.40, "height": 136.0, "coll_ratio": 0.30, "occlude": false},
		],
		"fixed_landmarks": [
			{"type": "spring_pool", "pos": Vector2(720, -720), "radius": 155.0, "tex": "res://assets/v2/maps/forest/decal_spring_pool.png"},
			{"type": "spring_pool", "pos": Vector2(-720, 720), "radius": 155.0, "tex": "res://assets/v2/maps/forest/decal_spring_pool.png"},
			{"type": "prop_anchor", "pos": Vector2(-720, -720), "height": 175.0, "tex": "res://assets/v2/maps/forest/prop_lantern_stele.png"},
			{"type": "prop_anchor", "pos": Vector2(720, 720), "height": 175.0, "tex": "res://assets/v2/maps/forest/prop_lantern_stele.png"},
			{"type": "prop_anchor", "pos": Vector2(140, -1150), "height": 155.0, "tex": "res://assets/v2/maps/forest/prop_lantern_stele.png"},
			{"type": "prop_anchor", "pos": Vector2(-140, 1150), "height": 155.0, "tex": "res://assets/v2/maps/forest/prop_lantern_stele.png"},
			{"type": "prop_anchor", "pos": Vector2(1150, 140), "height": 155.0, "tex": "res://assets/v2/maps/forest/prop_lantern_stele.png"},
			{"type": "prop_anchor", "pos": Vector2(-1150, -140), "height": 155.0, "tex": "res://assets/v2/maps/forest/prop_lantern_stele.png"},
		],
		"particles": "forest",
	},
	"volcano": {
		"mode": "realm",
		"seed": 2002,
		"map_size": 4400.0,
		"center_dojo_radius": 580.0,
		"center_array_size": 680.0,
		"center_array_radius": 340.0,
		"road_half_width": 88.0,
		"road_end_radius": 1980.0,
		"obstacle_count": 22,
		"obstacle_min_spacing": 280.0,
		"ground_tile": "res://assets/v2/maps/volcano/tile_ground_basalt.png",
		"ground_tint": Color(0.95, 0.90, 0.88, 1.0),
		"road_decal": "res://assets/v2/maps/volcano/decal_road_basalt.png",
		"center_array": "res://assets/v2/maps/volcano/decal_alchemy_array.png",
		"center_array_name": "八卦丹炉阵",
		"border": "res://assets/v2/maps/volcano/border_volcano_cliff.png",
		"border_step": 225.0,
		"border_scale": 0.64,
		"prop_pool": [
			{"tex": "res://assets/v2/maps/volcano/prop_bronze_cauldron.png", "weight": 0.35, "height": 210.0, "coll_ratio": 0.25, "occlude": true},
			{"tex": "res://assets/v2/maps/volcano/prop_danxia_pillar.png", "weight": 0.65, "height": 168.0, "coll_ratio": 0.26, "occlude": true},
		],
		"fixed_landmarks": [
			{"type": "lava_vent", "pos": Vector2(680, -680), "radius": 145.0, "phase_offset": 0.0, "tex": "res://assets/v2/maps/volcano/decal_lava_vent.png"},
			{"type": "lava_vent", "pos": Vector2(-680, 680), "radius": 145.0, "phase_offset": 0.0, "tex": "res://assets/v2/maps/volcano/decal_lava_vent.png"},
			{"type": "lava_vent", "pos": Vector2(-680, -680), "radius": 145.0, "phase_offset": 5.5, "tex": "res://assets/v2/maps/volcano/decal_lava_vent.png"},
			{"type": "lava_vent", "pos": Vector2(680, 680), "radius": 145.0, "phase_offset": 5.5, "tex": "res://assets/v2/maps/volcano/decal_lava_vent.png"},
			{"type": "prop_anchor", "pos": Vector2(180, -1360), "height": 238.0, "tex": "res://assets/v2/maps/volcano/prop_bronze_cauldron.png"},
			{"type": "prop_anchor", "pos": Vector2(-180, 1360), "height": 238.0, "tex": "res://assets/v2/maps/volcano/prop_bronze_cauldron.png"},
			{"type": "prop_anchor", "pos": Vector2(1360, 180), "height": 238.0, "tex": "res://assets/v2/maps/volcano/prop_bronze_cauldron.png"},
			{"type": "prop_anchor", "pos": Vector2(-1360, -180), "height": 238.0, "tex": "res://assets/v2/maps/volcano/prop_bronze_cauldron.png"},
		],
		"particles": "volcano",
	},
	"ice": {
		"mode": "realm",
		"seed": 3003,
		"map_size": 4600.0,
		"center_dojo_radius": 600.0,
		"center_array_size": 700.0,
		"center_array_radius": 350.0,
		"road_half_width": 90.0,
		"road_end_radius": 2080.0,
		"obstacle_count": 24,
		"obstacle_min_spacing": 290.0,
		"ground_tile": "res://assets/v2/maps/ice/tile_ground_snow.png",
		"ground_tint": Color(0.86, 0.90, 0.94, 1.0),
		"road_decal": "res://assets/v2/maps/ice/decal_road_froststone.png",
		"center_array": "res://assets/v2/maps/ice/decal_sword_array.png",
		"center_array_name": "太极剑阵",
		"border": "res://assets/v2/maps/ice/border_ice_ridge.png",
		"border_step": 230.0,
		"border_scale": 0.65,
		"prop_pool": [
			{"tex": "res://assets/v2/maps/ice/prop_giant_sword.png", "weight": 1.0, "height": 220.0, "coll_ratio": 0.24, "occlude": true},
		],
		"fixed_landmarks": [
			{"type": "frozen_pond", "pos": Vector2(670, -670), "radius": 165.0, "tex": "res://assets/v2/maps/ice/decal_frozen_pond.png"},
			{"type": "frozen_pond", "pos": Vector2(-670, 670), "radius": 165.0, "tex": "res://assets/v2/maps/ice/decal_frozen_pond.png"},
			{"type": "frozen_pond", "pos": Vector2(-670, -670), "radius": 165.0, "tex": "res://assets/v2/maps/ice/decal_frozen_pond.png"},
			{"type": "frozen_pond", "pos": Vector2(670, 670), "radius": 165.0, "tex": "res://assets/v2/maps/ice/decal_frozen_pond.png"},
			{"type": "sword_stele", "pos": Vector2(155, -1120), "radius": 135.0, "height": 220.0, "tex": "res://assets/v2/maps/ice/prop_sword_stele.png"},
			{"type": "sword_stele", "pos": Vector2(-155, 1120), "radius": 135.0, "height": 220.0, "tex": "res://assets/v2/maps/ice/prop_sword_stele.png"},
			{"type": "sword_stele", "pos": Vector2(1120, 155), "radius": 135.0, "height": 220.0, "tex": "res://assets/v2/maps/ice/prop_sword_stele.png"},
			{"type": "sword_stele", "pos": Vector2(-1120, -155), "radius": 135.0, "height": 220.0, "tex": "res://assets/v2/maps/ice/prop_sword_stele.png"},
		],
		"particles": "ice",
	},
}

static var _tex_cache: Dictionary = {}

static func resolve_realm_id(chapter: Dictionary) -> String:
	var explicit := String(chapter.get("realm_id", ""))
	if not explicit.is_empty() and REALMS.has(explicit):
		return explicit
	match int(chapter.get("id", 1)):
		2: return "forest"
		3: return "volcano"
		4: return "ice"
		_: return "tutorial"

static func get_realm(realm_id: String) -> Dictionary:
	if REALMS.has(realm_id):
		return (REALMS[realm_id] as Dictionary).duplicate(true)
	return (REALMS["tutorial"] as Dictionary).duplicate(true)

static func load_tex_safe(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _tex_cache.has(path):
		return _tex_cache[path] as Texture2D
	if ResourceLoader.exists(path):
		var res := load(path)
		if res is Texture2D:
			_tex_cache[path] = res
			return res as Texture2D
	return null

static func load_realm_texture(realm_cfg: Dictionary, slot: String, index: int = 0, subkey: String = "") -> Texture2D:
	var path := ""
	match slot:
		"ground_tile", "road_decal", "center_array", "border":
			path = String(realm_cfg.get(slot, ""))
		"prop":
			var pool: Array = realm_cfg.get("prop_pool", [])
			if index >= 0 and index < pool.size():
				path = String((pool[index] as Dictionary).get("tex", ""))
		"hazard":
			for lm in realm_cfg.get("fixed_landmarks", []):
				if String((lm as Dictionary).get("type", "")) == subkey:
					path = String((lm as Dictionary).get("tex", ""))
					break
	return load_tex_safe(path)
