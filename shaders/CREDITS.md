# VFX Assets & Open-Source Shaders Credits

## Particle Textures
- **Kenney Particle Pack (v1.1)** — `addons/kenney_particle_pack/`
  - Author: Kenney Vleugels (`https://kenney.nl/assets/particle-pack`)
  - Godot Package: `https://github.com/Calinou/kenney-particle-pack`
  - License: Creative Commons Zero v1.0 Universal (CC0 1.0) — Public Domain (`addons/kenney_particle_pack/LICENSE.txt`)

## Godot 4 CanvasItem Shaders (`shaders/`)
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
