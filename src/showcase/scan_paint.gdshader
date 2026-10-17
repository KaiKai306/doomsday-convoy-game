shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

// The source scan has baked shadows in its vertex colors. Compress that contrast
// before real lighting, without replacing it with an unlit or emissive material.
void fragment() {
	ALBEDO = pow(clamp(COLOR.rgb,vec3(0.0),vec3(1.0)),vec3(0.65))*0.72;
	ROUGHNESS = 0.96;
	METALLIC = 0.01;
	SPECULAR = 0.12;
}
