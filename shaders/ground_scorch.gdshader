shader_type canvas_item;
render_mode unshaded;

uniform vec4 char_color : source_color = vec4(0.16, 0.11, 0.07, 1.0);
uniform vec4 ash_color : source_color = vec4(0.34, 0.30, 0.25, 1.0);
uniform float progress : hint_range(0.0, 1.2) = 1.0;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float alpha_limit : hint_range(0.0, 1.0) = 0.50;
uniform float noise_scale = 5.0;
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
	float r = length(UV - 0.5) * 2.0;
	float src = texture(TEXTURE, UV).a;
	float n = fbm(UV * noise_scale + seed);
	float edge = progress * (0.90 + (n - 0.5) * 0.34);
	float radial = smoothstep(1.0, 0.72, r);
	float mask = smoothstep(edge + 0.07, edge - 0.06, src) * radial;
	float depth = smoothstep(edge, 0.0, src);
	vec3 col = mix(char_color.rgb * 2.1, char_color.rgb * 0.95, depth);
	float grain = fbm(UV * noise_scale * 3.7 + seed * 1.7);
	col = mix(col, ash_color.rgb, grain * 0.34 * (1.0 - depth * 0.45));
	float rim = smoothstep(0.07, 0.0, abs(src - edge)) * radial;
	col = mix(col, vec3(0.86, 0.28, 0.05), rim * 0.80);
	COLOR = vec4(col, mask * alpha_limit * fade);
}
