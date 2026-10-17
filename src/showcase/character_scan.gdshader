shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;
void fragment() {
	// Vertex colors were graded during export; keep the portable GLB appearance.
	ALBEDO = clamp(COLOR.rgb, vec3(0.0), vec3(1.0));
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
