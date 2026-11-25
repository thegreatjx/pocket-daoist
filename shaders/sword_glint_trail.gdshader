shader_type canvas_item;
render_mode blend_add, unshaded;

// Open-source MIT/CC0 Godot 4 ribbon & directional slash-wipe glint shader.
uniform vec4 primary_color : source_color = vec4(0.18, 0.83, 0.75, 1.0);
uniform vec4 edge_color : source_color = vec4(0.92, 1.0, 0.98, 1.0);
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float flow_speed = 4.5;
uniform float intensity = 1.4;
uniform float ink_strength : hint_range(0.0, 1.0) = 0.0;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float use_texture_mask : hint_range(0.0, 1.0) = 0.0;

varying vec4 v_modulate;

void vertex() {
	v_modulate = COLOR;
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float streak_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x),
		mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x),
		u.y
	);
}

void fragment() {
	if (use_texture_mask >= 0.5) {
		vec4 mask_tex = texture(TEXTURE, UV);
		float sweep_pos = mix(-0.2, 1.25, progress);
		float band = smoothstep(sweep_pos - 0.35, sweep_pos, UV.x) * (1.0 - smoothstep(sweep_pos + 0.08, sweep_pos + 0.45, UV.x));
		float life_fade = (1.0 - smoothstep(0.55, 1.0, progress)) * fade;
		float mask_val = clamp(mask_tex.a + mask_tex.r * 0.5, 0.0, 1.0);

		vec3 base_rgb = mix(primary_color.rgb, edge_color.rgb, clamp(band * 0.85 + mask_tex.r * 0.45, 0.0, 1.0));
		base_rgb = mix(base_rgb, vec3(0.04, 0.06, 0.08), ink_strength * (1.0 - mask_tex.r) * 0.65);
		float a = clamp(mask_val * (0.68 + 0.55 * band) * life_fade * primary_color.a * v_modulate.a, 0.0, 1.0);
		COLOR = vec4(base_rgb * intensity * v_modulate.rgb, a);
	} else {
		float head_fade = smoothstep(0.0, 0.22, UV.x) * smoothstep(1.0, 0.88, UV.x);
		float cross_dist = abs(UV.y - 0.5) * 2.0;
		float profile = pow(clamp(1.0 - cross_dist, 0.0, 1.0), 1.5);
		float s_noise = streak_noise(vec2(UV.x * 7.0 - TIME * flow_speed, UV.y * 5.0));
		float ribbon = profile * (0.62 + 0.38 * s_noise) * head_fade;

		float core_line = smoothstep(0.26, 0.04, cross_dist) * UV.x;
		vec3 rgb = mix(primary_color.rgb, edge_color.rgb, clamp(core_line * 1.1 + UV.x * 0.25, 0.0, 1.0));
		rgb = mix(rgb, vec3(0.05, 0.06, 0.09), ink_strength * smoothstep(0.35, 0.85, cross_dist) * 0.75);
		float alpha = clamp(ribbon * primary_color.a * fade * v_modulate.a, 0.0, 1.0);
		COLOR = vec4(rgb * intensity * v_modulate.rgb, alpha);
	}
}
