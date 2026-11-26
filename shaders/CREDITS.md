# VFX Assets & Open-Source Shaders Credits

## Particle Textures
- **Kenney Particle Pack (v1.1)** — `addons/kenney_particle_pack/`
  - Author: Kenney Vleugels (`https://kenney.nl/assets/particle-pack`)
  - Godot Package: `https://github.com/Calinou/kenney-particle-pack`
  - License: Creative Commons Zero v1.0 Universal (CC0 1.0) — Public Domain (`addons/kenney_particle_pack/LICENSE.txt`)

- **Weapon Slash Effect Sprite Strips** — `assets/sprites/fx_slash_arc_strip.png`, `assets/sprites/fx_slash_cross_strip.png`, `assets/sprites/fx_slash_thrust_strip.png`
  - Author: Cethiel (`https://opengameart.org/content/weapon-slash-effect`)
  - License: Creative Commons Zero v1.0 Universal (CC0 1.0) — Public Domain
  - Modification: Repacked into 6-frame horizontal strips (`900x150`, `150x150` per frame) and desaturated to neutral luminance-white RGBA for runtime element tinting.

## Godot 4 CanvasItem Shaders (`shaders/`)
- **`spark_star.gdshader`** & **`impact_ring.gdshader`**
  - Source: `tavryxlabs-lab/kapowfx-starter` (`https://github.com/tavryxlabs-lab/kapowfx-starter`)
  - License: MIT License (`Copyright (c) tavryxlabs-lab`)
- **`burn_dissolve.gdshader`**
  - Adapted from GDQuest `dissolve2D.gdshader` (`https://github.com/gdquest-demos/godot-shaders`, MIT License) with procedural FBM swirl noise and configurable ground-layer alpha ceiling for Godot 4 `gl_compatibility`.
- **`electric_arc.gdshader`**
  - Adapted from FencerDevLog 2D Electric Arc shader on GodotShaders.com (CC0 1.0), extended with tapered beam endpoints, 4-octave procedural FBM jitter, and dual-color plasma/gold core for `Line2D` chain bolts.
- **`sword_glint_trail.gdshader`**
  - Open-source MIT/CC0 Godot 4 `canvas_item` ribbon & slash-wipe shader combining longitudinal qi streaks (`Line2D` UV flow), ink-outline contrast mode, and directional slash-texture sweep (`Sprite2D` mask mode).
- **`bagua_domain_wave.gdshader`**
  - Open-source MIT/CC0 Godot 4 `canvas_item` polar shockwave & Bagua array shader supporting rotating harmonic petals, subtle UV ripple, expanding ring fronts, and readability-capped ground alpha.
- **`boss_shockwave_ring.gdshader`**
  - Open-source MIT/CC0 Godot 4 `canvas_item` polar shockwave & flame energy ring shader inspired by GodotShaders.com 2D shockwave/energy ring implementations, using procedural value noise and dual-color plasma edge modulation.
- **`fire_flame_2d.gdshader`**
  - Adapted from GodotShaders.com CC0 2D Fire shader concept, using procedural 4-octave FBM upward-scrolling noise and 3-tier thermal color ramp (`core_color` / `mid_color` / `outer_color`) with `flame_shape` switching between rising tongues and boiling ground fire for Godot 4 `gl_compatibility`.
- **`ground_scorch.gdshader`**
  - Original: samples the Kenney CC0 `scorch_02.png` alpha as an irregular burn mask, grows it with FBM-modulated threshold, and darkens toward charred center with ash mottling. `blend_mix` for the ground decal layer.
- **`flame_tongue.gdshader`**
  - Original: samples a Kenney CC0 flame silhouette (`flame_05` / `flame_06`) as the tongue mask and applies a vertical thermal ramp (hot base → orange body → dark red tip) with FBM flicker. `blend_add` for the flame layer.
