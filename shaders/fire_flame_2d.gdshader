shader_type canvas_item;
render_mode unshaded;

uniform vec4 core_color : source_color = vec4(1.0, 0.96, 0.72, 1.0);
uniform vec4 mid_color : source_color = vec4(1.0, 0.50, 0.12, 1.0);
uniform vec4 outer_color : source_color = vec4(0.72, 0.14, 0.05, 1.0);
uniform float speed = 3.2;
uniform float noise_scale = 4.2;
uniform float flame_shape = 1.0;
uniform float intensity = 1.15;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float alpha_limit : hint_range(0.0, 1.0) = 0.88;
uniform float ring_progress : hint_range(0.0, 1.5) = 1.0;

varying vec4 v_modulate;

void vertex() {
	v_modulate = COLOR;
}

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 3; i++) {
		v += amp * value_noise(p);
		p = p * 2.05 + vec2(13.7, 29.3);
		amp *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 centered = UV - vec2(0.5);
	vec3 col = outer_color.rgb;
	float out_alpha = 0.0;

	if (flame_shape < 0.5) {
		float r = length(centered) * 2.0;
		float ang = atan(centered.y, centered.x);
		float n = fbm(vec2(cos(ang), sin(ang)) * (noise_scale * 0.65) + vec2(TIME * speed * 0.35, -TIME * speed * 0.45));
		float lotus_wave = 0.045 * sin(ang * 8.0 + TIME * speed * 1.4);
		float edge_r = clamp(ring_progress, 0.15, 1.1) * (0.91 + lotus_wave + (n - 0.5) * 0.07);
		float inner_r = edge_r - 0.16;

		float outer_cut = 1.0 - smoothstep(edge_r - 0.02, edge_r + 0.015, r);
		float ring_band = smoothstep(inner_r - 0.025, inner_r + 0.02, r) * outer_cut;
		float rim_outline = smoothstep(edge_r - 0.045, edge_r - 0.015, r) * outer_cut;
		float inner_gold = smoothstep(inner_r - 0.01, inner_r + 0.03, r) * (1.0 - smoothstep(inner_r + 0.04, inner_r + 0.08, r));

		float fill_mask = 1.0 - smoothstep(inner_r - 0.01, inner_r + 0.03, r);
		float inner_lotus = 0.5 + 0.5 * cos(ang * 8.0 - TIME * speed * 0.9);
		float inner_ring = smoothstep(edge_r * 0.46, edge_r * 0.50, r) * (1.0 - smoothstep(edge_r * 0.50, edge_r * 0.55, r)) * (0.45 + 0.55 * inner_lotus);

		col = mix(mid_color.rgb, core_color.rgb, clamp(inner_gold * 0.95 + inner_ring * 0.6, 0.0, 1.0));
		col = mix(col, outer_color.rgb * 0.78, rim_outline);

		float center_a = fill_mask * (0.28 + 0.14 * inner_ring);
		float ring_a = ring_band * 0.94;
		out_alpha = clamp(max(center_a, ring_a) * alpha_limit, 0.0, 1.0);
	} else if (flame_shape < 1.5) {
		float h = 1.0 - UV.y;
		float n = fbm(UV * noise_scale + vec2(sin(TIME * speed * 0.7 + h * 3.5) * 0.18, TIME * speed));
		float half_w = mix(0.32, 0.05, pow(clamp(h, 0.0, 1.0), 1.05));
		float wobble = (n - 0.5) * 0.16 * smoothstep(0.10, 0.85, h);
		float x_dist = abs(centered.x + wobble * 0.35) / max(half_w, 0.04);
		float y_mask = smoothstep(0.02, 0.16, h) * (1.0 - smoothstep(0.60, 0.96, h));
		float heat = clamp((1.0 - smoothstep(0.45, 0.98, x_dist)) * y_mask * (0.76 + 0.44 * n), 0.0, 1.0);

		float outer_m = smoothstep(0.14, 0.24, heat);
		float mid_m = smoothstep(0.30, 0.42, heat);
		float core_m = smoothstep(0.62, 0.74, heat);

		col = mix(outer_color.rgb * 0.82, mid_color.rgb, mid_m);
		col = mix(col, core_color.rgb, core_m);
		out_alpha = clamp(outer_m * alpha_limit, 0.0, 1.0);
	} else {
		float r = length(centered) * 2.0;
		float ang = atan(centered.y, centered.x);
		float n = fbm(vec2(cos(ang), sin(ang)) * noise_scale + vec2(TIME * speed * 0.8, -TIME * speed * 0.6));
		float orb_r = 0.76 + (n - 0.5) * 0.14;
		float outer_m = 1.0 - smoothstep(orb_r - 0.06, orb_r + 0.03, r);
		float mid_m = 1.0 - smoothstep(orb_r * 0.72, orb_r * 0.84, r);
		float core_m = 1.0 - smoothstep(orb_r * 0.38, orb_r * 0.50, r);

		col = mix(outer_color.rgb * 0.82, mid_color.rgb, mid_m);
		col = mix(col, core_color.rgb, core_m);
		out_alpha = clamp(outer_m * alpha_limit, 0.0, 1.0);
	}

	COLOR = vec4(col * intensity * v_modulate.rgb, out_alpha * fade * v_modulate.a);
}
