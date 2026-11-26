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
		"road_end_radius": 1960.0,
		"courtyard_ring_dist": 720.0,
		"obstacle_count": 20,
		"obstacle_min_spacing": 280.0,
		"ground_tile": "res://assets/v2/maps/forest/tile_ground_grass.png",
		"ground_tint": Color(0.94, 0.97, 0.92, 1.0),
		"road_decal": "res://assets/v2/maps/forest/decal_road_stone_straight.png",
		"road_cross_decal": "res://assets/v2/maps/forest/decal_road_stone.png",
		"center_array": "res://assets/v2/maps/forest/decal_spirit_array.png",
		"center_array_name": "聚灵大阵",
		"border": "res://assets/v2/maps/forest/border_cliff_trees.png",
		"border_step": 220.0,
		"border_scale": 0.72,
		"border_foot_y": 0.81,
		"border_wall_inset": 48.0,
		"prop_pool": [
			{
				"tex": "res://assets/v2/maps/forest/prop_ancient_pine.png",
				"weight": 0.65,
				"height": 240.0,
				"foot_y_norm": 0.94,
				"foot_x_norm": -0.02,
				"shape": "circle",
				"coll_rx": 0.13,
				"shadow_rx": 0.26,
				"shadow_ry": 0.11,
				"occlude": true,
			},
			{
				"tex": "res://assets/v2/maps/forest/prop_jade_rock.png",
				"weight": 0.35,
				"height": 146.0,
				"foot_y_norm": 0.85,
				"shape": "capsule",
				"coll_rx": 0.38,
				"coll_ry": 0.16,
				"shadow_rx": 0.44,
				"shadow_ry": 0.18,
				"occlude": false,
			},
		],
		"landmark_prop_spec": {
			"foot_y_norm": 0.90,
			"shape": "circle",
			"coll_rx": 0.15,
			"shadow_rx": 0.22,
			"shadow_ry": 0.10,
			"occlude": true,
		},
		"fixed_landmarks": [
			{"type": "spring_pool", "pos": Vector2(720, -720), "radius": 155.0, "tex": "res://assets/v2/maps/forest/decal_spring_pool.png"},
			{"type": "spring_pool", "pos": Vector2(-720, 720), "radius": 155.0, "tex": "res://assets/v2/maps/forest/decal_spring_pool.png"},
			{"type": "prop_anchor", "pos": Vector2(-720, -720), "height": 175.0, "tex": "res://assets/v2/maps/forest/prop_lantern_stele.png"},
			{"type": "prop_anchor", "pos": Vector2(720, 720), "height": 175.0, "tex": "res://assets/v2/maps/forest/prop_lantern_stele.png"},
			{"type": "prop_anchor", "pos": Vector2(-155, -980), "height": 155.0, "tex": "res://assets/v2/maps/forest/prop_lantern_stele.png"},
			{"type": "prop_anchor", "pos": Vector2(155, -980), "height": 155.0, "tex": "res://assets/v2/maps/forest/prop_lantern_stele.png"},
			{"type": "prop_anchor", "pos": Vector2(-155, 980), "height": 155.0, "tex": "res://assets/v2/maps/forest/prop_lantern_stele.png"},
			{"type": "prop_anchor", "pos": Vector2(155, 980), "height": 155.0, "tex": "res://assets/v2/maps/forest/prop_lantern_stele.png"},
			{"type": "prop_anchor", "pos": Vector2(-980, -155), "height": 155.0, "tex": "res://assets/v2/maps/forest/prop_lantern_stele.png"},
			{"type": "prop_anchor", "pos": Vector2(-980, 155), "height": 155.0, "tex": "res://assets/v2/maps/forest/prop_lantern_stele.png"},
			{"type": "prop_anchor", "pos": Vector2(980, -155), "height": 155.0, "tex": "res://assets/v2/maps/forest/prop_lantern_stele.png"},
			{"type": "prop_anchor", "pos": Vector2(980, 155), "height": 155.0, "tex": "res://assets/v2/maps/forest/prop_lantern_stele.png"},
		],
		"layout_props": [
			{"pos": Vector2(-440, -520), "pool_idx": 0, "height": 235.0, "flip_h": false},
			{"pos": Vector2(-1020, -520), "pool_idx": 1, "height": 145.0, "flip_h": true},
			{"pos": Vector2(-520, -1040), "pool_idx": 0, "height": 240.0, "flip_h": true},
			{"pos": Vector2(-1180, -960), "pool_idx": 0, "height": 250.0, "flip_h": false},
			{"pos": Vector2(-1480, -480), "pool_idx": 1, "height": 150.0, "flip_h": false},
			{"pos": Vector2(440, -520), "pool_idx": 0, "height": 235.0, "flip_h": true},
			{"pos": Vector2(1020, -520), "pool_idx": 0, "height": 245.0, "flip_h": false},
			{"pos": Vector2(520, -1040), "pool_idx": 1, "height": 142.0, "flip_h": false},
			{"pos": Vector2(1180, -960), "pool_idx": 0, "height": 250.0, "flip_h": true},
			{"pos": Vector2(1480, -480), "pool_idx": 0, "height": 230.0, "flip_h": false},
			{"pos": Vector2(-440, 520), "pool_idx": 0, "height": 235.0, "flip_h": false},
			{"pos": Vector2(-1020, 520), "pool_idx": 0, "height": 245.0, "flip_h": true},
			{"pos": Vector2(-520, 1040), "pool_idx": 1, "height": 142.0, "flip_h": true},
			{"pos": Vector2(-1180, 960), "pool_idx": 0, "height": 250.0, "flip_h": false},
			{"pos": Vector2(-1480, 480), "pool_idx": 0, "height": 230.0, "flip_h": true},
			{"pos": Vector2(440, 520), "pool_idx": 0, "height": 235.0, "flip_h": true},
			{"pos": Vector2(1020, 520), "pool_idx": 1, "height": 145.0, "flip_h": false},
			{"pos": Vector2(520, 1040), "pool_idx": 0, "height": 240.0, "flip_h": false},
			{"pos": Vector2(1180, 960), "pool_idx": 0, "height": 250.0, "flip_h": true},
			{"pos": Vector2(1480, 480), "pool_idx": 1, "height": 150.0, "flip_h": true},
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
		"road_end_radius": 2060.0,
		"obstacle_count": 22,
		"obstacle_min_spacing": 280.0,
		"ground_tile": "res://assets/v2/maps/volcano/tile_ground_basalt.png",
		"ground_tint": Color(0.95, 0.90, 0.88, 1.0),
		"road_decal": "res://assets/v2/maps/volcano/decal_road_basalt_straight.png",
		"road_cross_decal": "",
		"center_array": "res://assets/v2/maps/volcano/decal_alchemy_array.png",
		"center_array_name": "八卦丹炉阵",
		"border": "res://assets/v2/maps/volcano/border_volcano_cliff.png",
		"border_step": 225.0,
		"border_scale": 0.74,
		"border_foot_y": 0.94,
		"border_wall_inset": 52.0,
		"prop_pool": [
			{
				"tex": "res://assets/v2/maps/volcano/prop_bronze_cauldron.png",
				"weight": 0.35,
				"height": 210.0,
				"foot_y_norm": 0.86,
				"shape": "capsule",
				"coll_rx": 0.30,
				"coll_ry": 0.16,
				"shadow_rx": 0.36,
				"shadow_ry": 0.17,
				"occlude": true,
			},
			{
				"tex": "res://assets/v2/maps/volcano/prop_danxia_pillar.png",
				"weight": 0.65,
				"height": 176.0,
				"foot_y_norm": 0.91,
				"shape": "capsule",
				"coll_rx": 0.24,
				"coll_ry": 0.14,
				"shadow_rx": 0.30,
				"shadow_ry": 0.14,
				"occlude": true,
			},
		],
		"landmark_prop_spec": {
			"foot_y_norm": 0.86,
			"shape": "capsule",
			"coll_rx": 0.30,
			"coll_ry": 0.16,
			"shadow_rx": 0.36,
			"shadow_ry": 0.17,
			"occlude": true,
		},
		"fixed_landmarks": [
			{"type": "lava_vent", "pos": Vector2(700, -700), "radius": 145.0, "phase_offset": 0.0, "tex": "res://assets/v2/maps/volcano/decal_lava_vent.png"},
			{"type": "lava_vent", "pos": Vector2(-700, 700), "radius": 145.0, "phase_offset": 0.0, "tex": "res://assets/v2/maps/volcano/decal_lava_vent.png"},
			{"type": "lava_vent", "pos": Vector2(-700, -700), "radius": 145.0, "phase_offset": 5.5, "tex": "res://assets/v2/maps/volcano/decal_lava_vent.png"},
			{"type": "lava_vent", "pos": Vector2(700, 700), "radius": 145.0, "phase_offset": 5.5, "tex": "res://assets/v2/maps/volcano/decal_lava_vent.png"},
			{"type": "prop_anchor", "pos": Vector2(180, -1360), "height": 238.0, "tex": "res://assets/v2/maps/volcano/prop_bronze_cauldron.png"},
			{"type": "prop_anchor", "pos": Vector2(-180, 1360), "height": 238.0, "tex": "res://assets/v2/maps/volcano/prop_bronze_cauldron.png"},
			{"type": "prop_anchor", "pos": Vector2(1360, 180), "height": 238.0, "tex": "res://assets/v2/maps/volcano/prop_bronze_cauldron.png"},
			{"type": "prop_anchor", "pos": Vector2(-1360, -180), "height": 238.0, "tex": "res://assets/v2/maps/volcano/prop_bronze_cauldron.png"},
		],
		"layout_props": [
			{"pos": Vector2(-420, -560), "pool_idx": 1, "height": 175.0, "flip_h": false},
			{"pos": Vector2(-1040, -560), "pool_idx": 1, "height": 180.0, "flip_h": true},
			{"pos": Vector2(-560, -1040), "pool_idx": 0, "height": 210.0, "flip_h": false},
			{"pos": Vector2(-1180, -1040), "pool_idx": 1, "height": 185.0, "flip_h": false},
			{"pos": Vector2(-1580, -540), "pool_idx": 1, "height": 170.0, "flip_h": true},
			{"pos": Vector2(-640, -1540), "pool_idx": 1, "height": 175.0, "flip_h": false},
			{"pos": Vector2(420, -560), "pool_idx": 1, "height": 175.0, "flip_h": true},
			{"pos": Vector2(1040, -560), "pool_idx": 1, "height": 180.0, "flip_h": false},
			{"pos": Vector2(560, -1040), "pool_idx": 0, "height": 210.0, "flip_h": true},
			{"pos": Vector2(1180, -1040), "pool_idx": 1, "height": 185.0, "flip_h": true},
			{"pos": Vector2(1580, -540), "pool_idx": 1, "height": 170.0, "flip_h": false},
			{"pos": Vector2(-420, 560), "pool_idx": 1, "height": 175.0, "flip_h": false},
			{"pos": Vector2(-1040, 560), "pool_idx": 1, "height": 180.0, "flip_h": true},
			{"pos": Vector2(-560, 1040), "pool_idx": 0, "height": 210.0, "flip_h": false},
			{"pos": Vector2(-1180, 1040), "pool_idx": 1, "height": 185.0, "flip_h": true},
			{"pos": Vector2(-1580, 540), "pool_idx": 1, "height": 170.0, "flip_h": false},
			{"pos": Vector2(420, 560), "pool_idx": 1, "height": 175.0, "flip_h": true},
			{"pos": Vector2(1040, 560), "pool_idx": 1, "height": 180.0, "flip_h": false},
			{"pos": Vector2(560, 1040), "pool_idx": 0, "height": 210.0, "flip_h": true},
			{"pos": Vector2(1180, 1040), "pool_idx": 1, "height": 185.0, "flip_h": false},
			{"pos": Vector2(1580, 540), "pool_idx": 1, "height": 170.0, "flip_h": true},
			{"pos": Vector2(640, 1540), "pool_idx": 1, "height": 175.0, "flip_h": true},
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
		"road_end_radius": 2160.0,
		"obstacle_count": 24,
		"obstacle_min_spacing": 290.0,
		"ground_tile": "res://assets/v2/maps/ice/tile_ground_snow.png",
		"ground_tint": Color(0.86, 0.90, 0.94, 1.0),
		"road_decal": "res://assets/v2/maps/ice/decal_road_froststone_straight.png",
		"road_cross_decal": "",
		"center_array": "res://assets/v2/maps/ice/decal_sword_array.png",
		"center_array_name": "太极剑阵",
		"border": "res://assets/v2/maps/ice/border_ice_ridge.png",
		"border_step": 230.0,
		"border_scale": 0.74,
		"border_foot_y": 0.78,
		"border_wall_inset": 52.0,
		"prop_pool": [
			{
				"tex": "res://assets/v2/maps/ice/prop_giant_sword.png",
				"weight": 1.0,
				"height": 225.0,
				"foot_y_norm": 0.87,
				"shape": "capsule",
				"coll_rx": 0.34,
				"coll_ry": 0.16,
				"shadow_rx": 0.40,
				"shadow_ry": 0.17,
				"occlude": true,
			},
		],
		"landmark_prop_spec": {
			"foot_y_norm": 0.84,
			"shape": "capsule",
			"coll_rx": 0.27,
			"coll_ry": 0.15,
			"shadow_rx": 0.33,
			"shadow_ry": 0.16,
			"occlude": true,
		},
		"fixed_landmarks": [
			{"type": "frozen_pond", "pos": Vector2(700, -700), "radius": 165.0, "tex": "res://assets/v2/maps/ice/decal_frozen_pond.png"},
			{"type": "frozen_pond", "pos": Vector2(-700, 700), "radius": 165.0, "tex": "res://assets/v2/maps/ice/decal_frozen_pond.png"},
			{"type": "frozen_pond", "pos": Vector2(-700, -700), "radius": 165.0, "tex": "res://assets/v2/maps/ice/decal_frozen_pond.png"},
			{"type": "frozen_pond", "pos": Vector2(700, 700), "radius": 165.0, "tex": "res://assets/v2/maps/ice/decal_frozen_pond.png"},
			{"type": "sword_stele", "pos": Vector2(165, -1080), "radius": 135.0, "height": 220.0, "tex": "res://assets/v2/maps/ice/prop_sword_stele.png"},
			{"type": "sword_stele", "pos": Vector2(-165, 1080), "radius": 135.0, "height": 220.0, "tex": "res://assets/v2/maps/ice/prop_sword_stele.png"},
			{"type": "sword_stele", "pos": Vector2(1080, 165), "radius": 135.0, "height": 220.0, "tex": "res://assets/v2/maps/ice/prop_sword_stele.png"},
			{"type": "sword_stele", "pos": Vector2(-1080, -165), "radius": 135.0, "height": 220.0, "tex": "res://assets/v2/maps/ice/prop_sword_stele.png"},
		],
		"layout_props": [
			{"pos": Vector2(-420, -560), "pool_idx": 0, "height": 220.0, "flip_h": false},
			{"pos": Vector2(-1060, -560), "pool_idx": 0, "height": 230.0, "flip_h": true},
			{"pos": Vector2(-560, -1060), "pool_idx": 0, "height": 225.0, "flip_h": false},
			{"pos": Vector2(-1220, -1060), "pool_idx": 0, "height": 240.0, "flip_h": true},
			{"pos": Vector2(-1640, -540), "pool_idx": 0, "height": 215.0, "flip_h": false},
			{"pos": Vector2(-720, -1580), "pool_idx": 0, "height": 225.0, "flip_h": true},
			{"pos": Vector2(420, -560), "pool_idx": 0, "height": 220.0, "flip_h": true},
			{"pos": Vector2(1060, -560), "pool_idx": 0, "height": 230.0, "flip_h": false},
			{"pos": Vector2(560, -1060), "pool_idx": 0, "height": 225.0, "flip_h": true},
			{"pos": Vector2(1220, -1060), "pool_idx": 0, "height": 240.0, "flip_h": false},
			{"pos": Vector2(1640, -540), "pool_idx": 0, "height": 215.0, "flip_h": true},
			{"pos": Vector2(720, -1580), "pool_idx": 0, "height": 225.0, "flip_h": false},
			{"pos": Vector2(-420, 560), "pool_idx": 0, "height": 220.0, "flip_h": false},
			{"pos": Vector2(-1060, 560), "pool_idx": 0, "height": 230.0, "flip_h": true},
			{"pos": Vector2(-560, 1060), "pool_idx": 0, "height": 225.0, "flip_h": false},
			{"pos": Vector2(-1220, 1060), "pool_idx": 0, "height": 240.0, "flip_h": true},
			{"pos": Vector2(-1640, 540), "pool_idx": 0, "height": 215.0, "flip_h": false},
			{"pos": Vector2(-720, 1580), "pool_idx": 0, "height": 225.0, "flip_h": true},
			{"pos": Vector2(420, 560), "pool_idx": 0, "height": 220.0, "flip_h": true},
			{"pos": Vector2(1060, 560), "pool_idx": 0, "height": 230.0, "flip_h": false},
			{"pos": Vector2(560, 1060), "pool_idx": 0, "height": 225.0, "flip_h": true},
			{"pos": Vector2(1220, 1060), "pool_idx": 0, "height": 240.0, "flip_h": false},
			{"pos": Vector2(1640, 540), "pool_idx": 0, "height": 215.0, "flip_h": true},
			{"pos": Vector2(720, 1580), "pool_idx": 0, "height": 225.0, "flip_h": false},
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
		"ground_tile", "road_decal", "road_cross_decal", "center_array", "border":
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
