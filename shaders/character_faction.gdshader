shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D source_texture : source_color, filter_nearest_mipmap, repeat_disable;
uniform float inmate_mix : hint_range(0.0, 1.0) = 0.0;
uniform vec4 skin_color : source_color = vec4(0.65, 0.39, 0.25, 1.0);
uniform vec4 inmate_primary : source_color = vec4(0.83, 0.25, 0.06, 1.0);
uniform vec4 inmate_secondary : source_color = vec4(0.48, 0.34, 0.20, 1.0);

float rect_mask(vec2 uv, vec4 bounds) {
	vec2 lower = step(bounds.xy, uv);
	vec2 upper = step(uv, bounds.zw);
	return lower.x * lower.y * upper.x * upper.y;
}

void fragment() {
	vec4 texel = texture(source_texture, UV);
	float detail = clamp(dot(texel.rgb, vec3(0.28, 0.55, 0.17)) * 1.35 + 0.22, 0.38, 1.15);
	float warm_skin = smoothstep(0.04, 0.20, texel.r - max(texel.g, texel.b));
	// The two head-island groups in the unchanged Characters PSX UV atlas.
	float head_region = max(
		rect_mask(UV, vec4(0.56, 0.13, 0.87, 0.32)),
		rect_mask(UV, vec4(0.62, 0.78, 0.84, 1.00))
	);
	float skin_region = clamp(max(warm_skin, head_region), 0.0, 1.0);
	float blue_bias = smoothstep(-0.02, 0.10, texel.b - texel.g);
	vec3 inmate_cloth = mix(inmate_secondary.rgb, inmate_primary.rgb, blue_bias) * detail;
	vec3 inmate_color = mix(inmate_cloth, skin_color.rgb * detail, skin_region);
	ALBEDO = mix(texel.rgb, inmate_color, inmate_mix);
	ROUGHNESS = mix(0.76, 0.9, inmate_mix);
	METALLIC = 0.0;
	ALPHA = texel.a;
}
