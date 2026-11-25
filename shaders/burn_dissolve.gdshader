shader_type canvas_item;
render_mode unshaded;

// Adapted from GDQuest dissolve2D.gdshader (MIT) with procedural FBM swirl noise.
uniform vec4 primary_color : source_color = vec4(0.92, 0.35, 0.05, 1.0);
uniform vec4 burn_color : source_color = vec4(1.0, 0.78, 0.28, 1.0);
uniform float dissolve_amount : hint_range(0.0, 1.0) = 0.0;
uniform float burn_size : hint_range(0.01, 0.5) = 0.16;
uniform float flow_speed = 1.4;
uniform float swirl_strength = 0.35;
uniform float noise_scale = 5.5;
uniform float emission_amount = 1.6;
uniform float alpha_limit : hint_range(0.0, 1.0) = 0.36;
uniform float fade : hint_range(0.0, 1.0) = 1.0;

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
	for (int i = 0; i < 4; i++) {
		v += amp * value_noise(p);
		p = p * 2.03 + vec2(17.1, 31.7);
		amp *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float r = length(centered);
	float ang = atan(centered.y, centered.x) + swirl_strength * (1.0 - smoothstep(0.0, 0.5, r)) + TIME * flow_speed * 0.25;
	vec2 swirl_uv = vec2(0.5) + vec2(cos(ang), sin(ang)) * r;

	vec4 tex = texture(TEXTURE, mix(UV, swirl_uv, 0.35));
	float n = fbm(UV * noise_scale + vec2(0.0, -TIME * flow_speed * 0.5));
	float n_mask = clamp(n * 0.85 + tex.r * 0.25, 0.0, 1.0);

	float thresh = dissolve_amount * (1.0 + burn_size);
	float keep_alpha = smoothstep(thresh - burn_size, thresh + 0.02, n_mask);
	float rim = smoothstep(thresh - burn_size, thresh, n_mask) * (1.0 - smoothstep(thresh, thresh + burn_size, n_mask));

	vec3 base_rgb = mix(primary_color.rgb, burn_color.rgb * emission_amount, clamp(rim * 2.2 + (1.0 - r * 2.0) * 0.25, 0.0, 1.0));
	float edge_mask = 1.0 - smoothstep(0.41, 0.495, r);
	float out_alpha = clamp(tex.a * keep_alpha * edge_mask * primary_color.a, 0.0, alpha_limit) * fade * v_modulate.a;
	COLOR = vec4(base_rgb * v_modulate.rgb, out_alpha);
}
