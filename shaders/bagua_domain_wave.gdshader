shader_type canvas_item;
render_mode unshaded;

// Open-source MIT/CC0 Godot 4 polar Bagua / domain / shockwave shader.
uniform vec4 primary_color : source_color = vec4(0.18, 0.83, 0.75, 1.0);
uniform vec4 accent_color : source_color = vec4(0.95, 0.92, 0.65, 1.0);
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float ring_width : hint_range(0.02, 0.45) = 0.16;
uniform float petal_count = 8.0;
uniform float spin_speed = 1.2;
uniform float distortion_amp = 0.02;
uniform float alpha_limit : hint_range(0.0, 1.0) = 0.36;
uniform float is_wave : hint_range(0.0, 1.0) = 1.0;
uniform float fade : hint_range(0.0, 1.0) = 1.0;

varying vec4 v_modulate;

void vertex() {
	v_modulate = COLOR;
}

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float dist = length(centered);
	float ang = atan(centered.y, centered.x);

	float rot_ang = ang + TIME * spin_speed;
	float ripple = sin(dist * 24.0 - TIME * 6.0) * distortion_amp;
	vec2 sample_uv = vec2(0.5) + vec2(cos(rot_ang), sin(rot_ang)) * clamp(dist + ripple, 0.0, 0.7);
	vec4 tex = texture(TEXTURE, sample_uv);

	float petals = 0.5 + 0.5 * cos(rot_ang * max(1.0, petal_count));
	float outer_fade = 1.0 - smoothstep(0.42, 0.5, dist);

	float ring_mask = 1.0;
	if (is_wave >= 0.5) {
		float target_r = mix(0.08, 0.46, progress);
		float d_ring = abs(dist - target_r);
		ring_mask = smoothstep(ring_width, ring_width * 0.15, d_ring);
	} else {
		float rim = smoothstep(0.32, 0.45, dist) * outer_fade;
		ring_mask = clamp(tex.a * 0.75 + rim * (0.45 + 0.55 * petals), 0.0, 1.0);
	}

	float pattern = clamp(tex.a * 0.8 + petals * 0.32 * outer_fade, 0.0, 1.0);
	float combined = pattern * ring_mask * outer_fade;
	vec3 rgb = mix(primary_color.rgb, accent_color.rgb, clamp(petals * 0.55 + (1.0 - smoothstep(0.0, 0.14, abs(dist - 0.42))) * 0.5, 0.0, 1.0));
	float out_alpha = clamp(combined * primary_color.a, 0.0, alpha_limit) * fade * v_modulate.a;
	COLOR = vec4(rgb * v_modulate.rgb, out_alpha);
}
