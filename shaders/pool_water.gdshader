shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never;

void fragment() {
	float ripple = sin(UV.x * 140.0 + TIME * 1.3) * sin(UV.y * 90.0 - TIME);
	ALBEDO = vec3(0.10, 0.43, 0.49) + vec3(ripple * 0.035);
	ROUGHNESS = 0.28;
	METALLIC = 0.0;
	ALPHA = 0.42;
}
