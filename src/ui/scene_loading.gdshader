shader_type canvas_item;
render_mode unshaded;

void fragment() {
	vec2 step_uv = TEXTURE_PIXEL_SIZE * 1.6;
	vec4 blurred = texture(TEXTURE, UV) * 0.28;
	blurred += texture(TEXTURE, UV + vec2(step_uv.x, 0.0)) * 0.12;
	blurred += texture(TEXTURE, UV - vec2(step_uv.x, 0.0)) * 0.12;
	blurred += texture(TEXTURE, UV + vec2(0.0, step_uv.y)) * 0.12;
	blurred += texture(TEXTURE, UV - vec2(0.0, step_uv.y)) * 0.12;
	blurred += texture(TEXTURE, UV + step_uv) * 0.06;
	blurred += texture(TEXTURE, UV - step_uv) * 0.06;
	blurred += texture(TEXTURE, UV + vec2(step_uv.x, -step_uv.y)) * 0.06;
	blurred += texture(TEXTURE, UV + vec2(-step_uv.x, step_uv.y)) * 0.06;
	COLOR = vec4(blurred.rgb * 0.82, 1.0);
}
