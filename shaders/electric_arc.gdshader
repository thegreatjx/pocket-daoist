shader_type canvas_item;
render_mode blend_add, unshaded;

// Adapted from GodotShaders.com CC0 2D Electric Arc shader (FencerDevLog).
uniform vec4 bolt_color : source_color = vec4(0.51, 0.55, 0.97, 1.0);
uniform vec4 core_color : source_color = vec4(0.95, 0.97, 1.0, 1.0);
uniform float speed = 14.0;
uniform float jitter_amp = 0.34;
uniform float thickness = 0.16;
uniform float core_ratio = 0.38;
uniform float intensity = 1.65;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float taper_ends : hint_range(0.0, 1.0) = 0.2;

varying vec4 v_modulate;

void vertex() {
	v_modulate = COLOR;
}

vec2 hash22(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return 2.0 * fract(sin(p) * 43758.5453) - 1.0;
}

float grad_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = dot(hash22(i + vec2(0.0, 0.0)), f - vec2(0.0, 0.0));
	float b = dot(hash22(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0));
	float c = dot(hash22(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0));
	float d = dot(hash22(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y) + 0.5;
}

float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		v += amp * grad_noise(p);
		p *= 2.15;
		amp *= 0.5;
	}
	return v;
}

void fragment() {
	float end_taper = 1.0;
	if (taper_ends > 0.001) {
		end_taper = smoothstep(0.0, taper_ends, UV.x) * smoothstep(1.0, 1.0 - taper_ends, UV.x);
	}

	float n1 = fbm(vec2(UV.x * 5.0 + TIME * speed * 0.28, TIME * speed * 0.19));
	float n2 = fbm(vec2(UV.x * 11.0 - TIME * speed * 0.41, 4.7 + TIME * speed * 0.13));
	float offset = ((n1 - 0.5) * 0.72 + (n2 - 0.5) * 0.28) * jitter_amp;

	float dist = abs((UV.y - 0.5) + offset);
	float outer_w = max(0.015, thickness * (0.55 + 0.45 * end_taper));
	float core_w = max(0.006, outer_w * core_ratio);

	float flicker = 0.82 + 0.18 * sin(TIME * 75.0 + UV.x * 19.0);
	float plasma = clamp(outer_w / max(dist, 0.0025), 0.0, 1.65) * smoothstep(0.45, 0.02, dist);
	float core = smoothstep(core_w * 1.1, core_w * 0.14, dist);

	vec3 rgb = (bolt_color.rgb * plasma * 0.85 + core_color.rgb * core * 1.75) * intensity * flicker;
	float alpha = clamp((plasma * 0.65 + core * 1.1) * fade * v_modulate.a * bolt_color.a, 0.0, 1.0);
	COLOR = vec4(rgb * v_modulate.rgb, alpha);
}
