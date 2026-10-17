shader_type canvas_item;
render_mode unshaded;
uniform vec3 ambient_tint = vec3(0.73,0.85,1.0);
uniform float exposure_stops = -0.4;
uniform float warm_amount = 0.0;
void fragment() {
	vec4 texel = texture(TEXTURE,UV);
	float luma = dot(texel.rgb,vec3(0.2126,0.7152,0.0722));
	vec3 base = mix(vec3(luma),texel.rgb,0.88);
	vec3 lit = base*(ambient_tint*exp2(exposure_stops)+vec3(1.0,0.49,0.20)*warm_amount);
	COLOR = vec4(lit,texel.a)*COLOR;
}
