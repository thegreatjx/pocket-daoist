shader_type canvas_item;
render_mode unshaded;

// Open-source MIT/CC0 Godot 4 polar radial shockwave & plasma energy ring shader
// Inspired by GodotShaders.com 2D shockwave / energy ring snippets.
uniform vec4 primary_color : source_color = vec4(0.98, 0.26, 0.20, 1.0);
uniform vec4 accent_color : source_color = vec4(1.0, 0.88, 0.42, 1.0);
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float ring_width : hint_range(0.03, 0.40) = 0.14;
uniform float noise_intensity : hint_range(0.0, 0.15) = 0.045;
uniform float twist_speed = 3.2;
uniform float fade : hint_range(0.0, 1.0) = 1.0;

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

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float dist = length(centered);
	float ang = atan(centered.y, centered.x);

	float n1 = value_noise(vec2(ang * 3.0 + TIME * twist_speed, dist * 14.0 - TIME * 4.0));
	float n2 = value_noise(vec2(ang * 6.0 - TIME * twist_speed * 1.4, dist * 22.0));
	float noisy_dist = dist + (n1 * 0.65 + n2 * 0.35 - 0.5) * noise_intensity;

	float target_r = mix(0.06, 0.46, progress);
	float d_ring = abs(noisy_dist - target_r);
	float main_ring = smoothstep(ring_width, ring_width * 0.12, d_ring);
	float inner_core = smoothstep(ring_width * 0.45, 0.0, d_ring);
	float outer_fade = 1.0 - smoothstep(0.42, 0.50, dist);
	float trail_glow = smoothstep(target_r, 0.02, dist) * 0.18 * (1.0 - progress);

	float alpha = clamp((main_ring * 0.88 + trail_glow) * outer_fade * fade, 0.0, 0.92);
	vec3 col = mix(primary_color.rgb, accent_color.rgb, clamp(inner_core * 0.85 + n1 * 0.30, 0.0, 1.0));
	COLOR = vec4(col, alpha * primary_color.a);
}
