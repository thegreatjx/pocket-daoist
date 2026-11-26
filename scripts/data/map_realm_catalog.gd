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
		"map_size": 4200.0,
		"center_dojo_radius": 560.0,
		"center_array_radius": 270.0,
		"road_half_width": 105.0,
		"obstacle_count": 22,
		"obstacle_min_spacing": 260.0,
		"seed": 202611261,
		"ground_tile": "res://assets/v2/maps/forest/tile_ground_grass.png",
		"ground_tint": Color(0.92, 0.96, 0.90, 1.0),
		"road_decal": "res://assets/v2/maps/forest/decal_road_stone.png",
		"center_array": "res://assets/v2/maps/forest/decal_spirit_array.png",
		"center_array_name": "聚灵大阵",
		"props": [
			"res://assets/v2/maps/forest/prop_ancient_pine.png",
			"res://assets/v2/maps/forest/prop_jade_rock.png",
			"res://assets/v2/maps/forest/prop_lantern_stele.png",
		],
		"prop_scales": [0.42, 0.34, 0.30],
		"border": "res://assets/v2/maps/forest/border_cliff_trees.png",
		"hazard_textures": {
			"spring_pool": "res://assets/v2/maps/forest/decal_spring_pool.png",
		},
		"hazards": ["spring_pool"],
		"particles": "petals_fireflies",
	},
	"volcano": {
		"mode": "realm",
		"map_size": 4400.0,
		"center_dojo_radius": 560.0,
		"center_array_radius": 270.0,
		"road_half_width": 105.0,
		"obstacle_count": 24,
		"obstacle_min_spacing": 260.0,
		"seed": 202611262,
		"ground_tile": "res://assets/v2/maps/volcano/tile_ground_basalt.png",
		"ground_tint": Color(0.95, 0.90, 0.88, 1.0),
		"road_decal": "res://assets/v2/maps/volcano/decal_road_basalt.png",
		"center_array": "res://assets/v2/maps/volcano/decal_alchemy_array.png",
		"center_array_name": "八卦丹炉阵",
		"props": [
			"res://assets/v2/maps/volcano/prop_bronze_cauldron.png",
			"res://assets/v2/maps/volcano/prop_danxia_pillar.png",
		],
		"prop_scales": [0.38, 0.44],
		"border": "res://assets/v2/maps/volcano/border_volcano_cliff.png",
		"hazard_textures": {
			"lava_vent": "res://assets/v2/maps/volcano/decal_lava_vent.png",
		},
		"hazards": ["lava_vent"],
		"particles": "embers",
	},
	"ice": {
		"mode": "realm",
		"map_size": 4600.0,
		"center_dojo_radius": 560.0,
		"center_array_radius": 270.0,
		"road_half_width": 105.0,
		"obstacle_count": 24,
		"obstacle_min_spacing": 260.0,
		"seed": 202611263,
		"asset_root": "assets/v2/maps/ice",
		"ground_tile_file": "tile_ground_snow.png",
		"ground_tint": Color(0.92, 0.96, 1.0, 1.0),
		"road_decal_file": "decal_road_ice.png",
		"center_array_file": "decal_sword_array.png",
		"center_array_name": "太极剑阵",
		"prop_files": [
			"prop_giant_sword.png",
			"prop_ice_crystal.png",
		],
		"prop_scales": [0.42, 0.36],
		"border_file": "border_ice_cliff.png",
		"hazard_files": {
			"frozen_pond": "decal_frozen_pond.png",
			"sword_stele": "prop_sword_stele.png",
		},
		"hazards": ["frozen_pond", "sword_stele"],
		"particles": "snowflakes",
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

static func load_realm_texture(realm_cfg: Dictionary, slot: String, index: int = 0, subkey: String = "") -> Texture2D:
	var path := _resolve_path(realm_cfg, slot, index, subkey)
	if not path.is_empty():
		if _tex_cache.has(path):
			return _tex_cache[path] as Texture2D
		if ResourceLoader.exists(path):
			var loaded := load(path) as Texture2D
			if loaded != null:
				_tex_cache[path] = loaded
				return loaded
	var cache_key := "proc:%s:%s:%d:%s" % [String(realm_cfg.get("particles", "ice")), slot, index, subkey]
	if _tex_cache.has(cache_key):
		return _tex_cache[cache_key] as Texture2D
	var proc := _build_fallback_texture(slot, index, subkey)
	_tex_cache[cache_key] = proc
	return proc

static func _resolve_path(realm_cfg: Dictionary, slot: String, index: int, subkey: String) -> String:
	var asset_root := String(realm_cfg.get("asset_root", ""))
	match slot:
		"ground_tile":
			var p := String(realm_cfg.get("ground_tile", ""))
			if p.is_empty() and not asset_root.is_empty():
				p = "res://" + asset_root + "/" + String(realm_cfg.get("ground_tile_file", ""))
			return p
		"road_decal":
			var p := String(realm_cfg.get("road_decal", ""))
			if p.is_empty() and not asset_root.is_empty():
				p = "res://" + asset_root + "/" + String(realm_cfg.get("road_decal_file", ""))
			return p
		"center_array":
			var p := String(realm_cfg.get("center_array", ""))
			if p.is_empty() and not asset_root.is_empty():
				p = "res://" + asset_root + "/" + String(realm_cfg.get("center_array_file", ""))
			return p
		"border":
			var p := String(realm_cfg.get("border", ""))
			if p.is_empty() and not asset_root.is_empty():
				p = "res://" + asset_root + "/" + String(realm_cfg.get("border_file", ""))
			return p
		"prop":
			var props: Array = realm_cfg.get("props", [])
			if index >= 0 and index < props.size():
				return String(props[index])
			var files: Array = realm_cfg.get("prop_files", [])
			if not asset_root.is_empty() and index >= 0 and index < files.size():
				return "res://" + asset_root + "/" + String(files[index])
			return ""
		"hazard":
			var hmap: Dictionary = realm_cfg.get("hazard_textures", {})
			if hmap.has(subkey):
				return String(hmap[subkey])
			var hfiles: Dictionary = realm_cfg.get("hazard_files", {})
			if not asset_root.is_empty() and hfiles.has(subkey):
				return "res://" + asset_root + "/" + String(hfiles[subkey])
			return ""
	return ""

static func _build_fallback_texture(slot: String, index: int, subkey: String) -> Texture2D:
	var sz := 256
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var c := Vector2(sz * 0.5, sz * 0.5)
	if slot == "ground_tile":
		img.fill(Color(0.24, 0.31, 0.39, 1.0))
		for y in range(sz):
			for x in range(sz):
				var wave := sin(float(x) * 0.06) * cos(float(y) * 0.06) * 0.04
				var speck := fmod(float(x * 73 + y * 139), 29.0)
				var lum := 0.25 + wave + (0.03 if speck < 2.0 else 0.0)
				img.set_pixel(x, y, Color(lum * 0.85, lum * 1.05, lum * 1.28, 1.0))
		return ImageTexture.create_from_image(img)

	img.fill(Color(0, 0, 0, 0))
	match slot:
		"road_decal":
			for y in range(sz):
				for x in range(sz):
					var dx := absf(float(x) - c.x)
					var dy := absf(float(y) - c.y)
					if (dx < 104.0 and dy < 66.0) or (dy < 104.0 and dx < 66.0):
						var seam := (int(x) % 44 < 3) or (int(y) % 44 < 3)
						var col := Color(0.32, 0.42, 0.52, 0.92) if seam else Color(0.56, 0.68, 0.78, 0.92)
						img.set_pixel(x, y, col)
		"center_array":
			for y in range(sz):
				for x in range(sz):
					var d := Vector2(x, y).distance_to(c)
					if d <= 118.0:
						var ring := (d >= 104.0) or (d >= 66.0 and d <= 74.0) or (d <= 26.0)
						var col := Color(0.62, 0.88, 0.98, 0.95) if ring else Color(0.20, 0.32, 0.44, 0.86)
						img.set_pixel(x, y, col)
		"hazard":
			if subkey == "frozen_pond":
				for y in range(sz):
					for x in range(sz):
						var d := Vector2(x, y).distance_to(c)
						if d <= 110.0:
							var rim := d >= 96.0
							var col := Color(0.74, 0.92, 0.99, 0.85) if rim else Color(0.44, 0.76, 0.94, 0.72)
							img.set_pixel(x, y, col)
			else:
				_draw_rect_box(img, Rect2i(92, 32, 72, 204), Color(0.30, 0.44, 0.56, 1.0), Color(0.75, 0.92, 1.0, 1.0))
				_draw_rect_box(img, Rect2i(118, 60, 20, 110), Color(0.95, 0.84, 0.44, 1.0), Color(0.95, 0.84, 0.44, 1.0))
		"border":
			_draw_rect_box(img, Rect2i(18, 72, 220, 168), Color(0.26, 0.38, 0.48, 1.0), Color(0.72, 0.88, 0.98, 1.0))
		_:
			if index % 2 == 0:
				_draw_rect_box(img, Rect2i(108, 22, 40, 212), Color(0.44, 0.56, 0.68, 1.0), Color(0.84, 0.94, 1.0, 1.0))
				_draw_rect_box(img, Rect2i(76, 70, 104, 22), Color(0.78, 0.66, 0.34, 1.0), Color(0.96, 0.86, 0.52, 1.0))
			else:
				_draw_rect_box(img, Rect2i(72, 48, 112, 188), Color(0.50, 0.82, 0.96, 0.94), Color(0.86, 0.97, 1.0, 1.0))
	return ImageTexture.create_from_image(img)

static func _draw_rect_box(img: Image, rect: Rect2i, fill_col: Color, border_col: Color) -> void:
	for y in range(maxi(0, rect.position.y), mini(img.get_height(), rect.end.y)):
		for x in range(maxi(0, rect.position.x), mini(img.get_width(), rect.end.x)):
			var is_border := x <= rect.position.x + 2 or x >= rect.end.x - 3 or y <= rect.position.y + 2 or y >= rect.end.y - 3
			img.set_pixel(x, y, border_col if is_border else fill_col)
