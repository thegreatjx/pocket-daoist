shader_type canvas_item;
render_mode unshaded;

uniform int motion_mode = 0;
uniform float anim_time = 0.0;
uniform float move_speed = 1.0;
uniform float amp_scale = 1.0;

const float PAD = 1.18;

void vertex() {
	VERTEX += (UV - vec2(0.5)) * (1.0 / TEXTURE_PIXEL_SIZE) * (PAD - 1.0);
}

void fragment() {
	vec4 mod_col = COLOR;
	vec2 uv = (UV - vec2(0.5)) * PAD + vec2(0.5);
	float amp = amp_scale * mix(0.35, 1.0, clamp(move_speed, 0.0, 1.2));

	if (motion_mode == 1) {
		float wing = smoothstep(0.14, 0.48, abs(uv.x - 0.5));
		float flap = sin(anim_time * 13.0);
		uv.y += wing * flap * 0.075 * amp;
		uv.y -= (1.0 - wing) * flap * 0.015 * amp;
	} else if (motion_mode == 2) {
		float top_flame = 1.0 - smoothstep(0.05, 0.28, uv.y);
		float bottom_tassel = smoothstep(0.62, 0.95, uv.y);
		uv.x += top_flame * sin(anim_time * 12.0 + uv.y * 8.0) * 0.032 * amp;
		uv.x += bottom_tassel * sin(anim_time * 5.5 + uv.y * 6.0) * 0.038 * amp;
		uv.y += sin(anim_time * 4.2 + uv.x * 5.0) * 0.012 * amp;
	} else if (motion_mode == 3) {
		float top_w = 1.0 - uv.y;
		uv.x += top_w * sin(anim_time * 9.0 - uv.y * 3.0) * 0.045 * amp;
	} else if (motion_mode == 4) {
		float upper = smoothstep(0.72, 0.45, uv.y);
		uv.x += upper * sin(anim_time * 22.0) * 0.018 * amp;
		uv.y += upper * cos(anim_time * 11.0) * 0.022 * amp;
	} else if (motion_mode == 5) {
		float tail_fade = 1.0 - smoothstep(0.88, 1.0, uv.y);
		uv.x += sin(uv.y * 10.5 - anim_time * 11.5) * 0.045 * tail_fade * amp;
	} else if (motion_mode == 6) {
		float legs = smoothstep(0.45, 0.85, uv.y) * (1.0 - smoothstep(0.88, 1.0, uv.y));
		float upper = 1.0 - smoothstep(0.30, 0.65, uv.y);
		uv.y += legs * sin(anim_time * 18.0 + uv.x * 22.0) * 0.024 * amp;
		uv.x += upper * sin(anim_time * 7.5) * 0.026 * amp;
	} else if (motion_mode == 7) {
		float top_cap = 1.0 - uv.y;
		uv.x += top_cap * sin(anim_time * 8.5 - uv.y * 2.4) * 0.042 * amp;
		uv.y += top_cap * cos(anim_time * 8.5) * 0.018 * amp;
	}

	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		COLOR = vec4(0.0);
	} else {
		COLOR = texture(TEXTURE, uv) * mod_col;
	}
}
