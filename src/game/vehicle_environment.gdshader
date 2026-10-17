shader_type canvas_item;
render_mode unshaded;

// Source art keeps neutral illumination. Each scene supplies exposure and color.
uniform float exposure_stops = -0.5;
uniform vec3 ambient_tint = vec3(0.7, 0.82, 1.0);
uniform float saturation = 0.88;
uniform vec2 source_origin;
uniform vec2 source_size;
uniform vec2 ground_pivot;
uniform float surface_angle = 0.0;
uniform vec2 warm_position;
uniform float warm_radius = 1000.0;
uniform float warm_strength = 0.0;

void fragment() {
	vec4 texel = texture(TEXTURE, UV);
	float luma = dot(texel.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 base = mix(vec3(luma), texel.rgb, saturation);
	vec3 ambient = base * ambient_tint * exp2(exposure_stops);
	vec2 position = source_origin + UV * source_size;
	vec2 local = position - ground_pivot;
	position = ground_pivot + vec2(local.x*cos(surface_angle)-local.y*sin(surface_angle), local.x*sin(surface_angle)+local.y*cos(surface_angle));
	float falloff = pow(clamp(1.0 - distance(position, warm_position) / max(warm_radius, 1.0), 0.0, 1.0), 2.0);
	vec3 warm = base * vec3(1.0, 0.48, 0.17) * warm_strength * falloff;
	COLOR = vec4(ambient + warm, texel.a);
}
