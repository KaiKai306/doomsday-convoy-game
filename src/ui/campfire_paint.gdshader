shader_type canvas_item;
uniform vec2 fire_position = vec2(1312.0, 847.0);
uniform float strength : hint_range(0.0, 2.0) = 1.0;

void fragment() {
	vec2 pixel = UV / TEXTURE_PIXEL_SIZE;
	vec2 local = pixel - fire_position;
	float mask = (1.0 - smoothstep(0.35, 1.0, length(local / vec2(82.0, 112.0))));
	// Leave logs and snow still; move the existing painterly flame texture only.
	mask *= 1.0 - smoothstep(45.0, 83.0, local.y);
	float wave = sin(local.y * 0.08 - TIME * 8.5) + 0.45 * sin(local.y * 0.17 - TIME * 13.0);
	vec2 displacement = vec2(wave * 5.0, sin(TIME * 10.3 + local.x * 0.07) * 3.0) * mask * strength;
	vec4 painted = texture(TEXTURE, UV + displacement * TEXTURE_PIXEL_SIZE);
	float pulse = sin(TIME * 8.3) * 0.065 + sin(TIME * 17.7 + 1.2) * 0.035;
	painted.rgb *= 1.0 + pulse * mask * strength;
	COLOR = painted;
}
