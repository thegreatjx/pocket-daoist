shader_type canvas_item;

uniform float border_width : hint_range(0.0, 0.12) = 0.048;
uniform vec4 border_color : source_color = vec4(0.88, 0.70, 0.30, 0.96);
uniform vec4 bg_color : source_color = vec4(0.06, 0.16, 0.14, 0.94);
uniform float vignette_strength : hint_range(0.0, 0.6) = 0.20;

varying vec4 v_modulate;

void vertex() {
	v_modulate = COLOR;
}

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float dist = length(centered);
	float aa = fwidth(dist) * 1.4 + 0.005;
	float outer_mask = 1.0 - smoothstep(0.490 - aa, 0.490 + aa, dist);
	float inner_radius = 0.490 - border_width;
	float ring_mask = smoothstep(inner_radius - aa, inner_radius + aa, dist) * outer_mask;

	vec4 tex = texture(TEXTURE, UV);
	float vign = 1.0 - smoothstep(0.24, inner_radius, dist) * vignette_strength;
	vec3 interior_rgb = mix(bg_color.rgb, tex.rgb * vign, tex.a);
	float interior_a = max(bg_color.a, tex.a) * (1.0 - ring_mask);

	vec3 final_rgb = mix(interior_rgb, border_color.rgb, ring_mask);
	float final_a = clamp(interior_a + ring_mask * border_color.a, 0.0, 1.0) * outer_mask;
	COLOR = vec4(final_rgb * v_modulate.rgb, final_a * v_modulate.a);
}
