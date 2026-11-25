shader_type canvas_item;
render_mode unshaded;

uniform vec4 hot_color : source_color = vec4(1.0, 0.72, 0.22, 1.0);
uniform vec4 mid_color : source_color = vec4(0.95, 0.30, 0.04, 1.0);
uniform vec4 outer_color : source_color = vec4(0.42, 0.05, 0.02, 1.0);
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float alpha_limit : hint_range(0.0, 1.0) = 0.85;
uniform float seed = 0.0;

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
		p = p * 2.05 + vec2(11.3, 27.1);
		amp *= 0.5;
	}
	return v;
}

void fragment() {
	float dens = texture(TEXTURE, UV).a;
	float h = 1.0 - UV.y;
	float n = fbm(vec2(UV.x * 4.0 + seed, UV.y * 3.0 - TIME * 1.8));
	float d = dens * (0.70 + 0.50 * n);
	vec3 col = mix(outer_color.rgb, mid_color.rgb, smoothstep(0.10, 0.48, d));
	col = mix(col, hot_color.rgb, smoothstep(0.48, 0.88, d));
	col = mix(col, vec3(1.0, 0.97, 0.82), smoothstep(0.82, 1.0, d) * smoothstep(0.62, 0.08, h) * 0.75);
	float a = smoothstep(0.02, 0.52, d) * alpha_limit * fade;
	COLOR = vec4(col, a);
}
