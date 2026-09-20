shader_type canvas_item;

// ── Bloom ──
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float bloom_threshold : hint_range(0.0, 2.0) = 0.75;
uniform float bloom_intensity : hint_range(0.0, 4.0) = 1.2;
uniform float bloom_spread : hint_range(0.5, 6.0) = 2.5;

// ── Color Grade ──
uniform float contrast : hint_range(0.5, 2.0) = 1.08;
uniform float shadow_detail : hint_range(0.0, 1.0) = 0.85;
uniform float saturation : hint_range(0.0, 2.0) = 0.80;
uniform vec3 tint : source_color = vec3(0.95, 1.0, 0.97);
uniform float vignette_strength : hint_range(0.0, 1.5) = 0.35;
uniform float vignette_radius : hint_range(0.0, 1.5) = 0.38;

void fragment() {
	vec2 pixel = SCREEN_PIXEL_SIZE * bloom_spread;
	// ── 9-tap bloom kernel ──
	// 3×3 box filter around the current pixel — cheap, compatibility-safe,
	// and produces a visually pleasant soft glow on emissive surfaces.
	vec3 sum = vec3(0.0);
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			vec3 tap = texture(screen_tex, SCREEN_UV + vec2(float(x), float(y)) * pixel).rgb;
			sum += max(tap - vec3(bloom_threshold), vec3(0.0));
		}
	}
	vec3 bloom = (sum / 9.0) * bloom_intensity;

	// ── Base color + bloom composite ──
	vec3 base = texture(screen_tex, SCREEN_UV).rgb;
	vec3 color = base + bloom;

	// Contrast with a soft shadow floor: do not crush the sparse night lighting
	// to absolute black. No mip chain is needed for this fixed LOD-0 kernel.
	color = max(color * shadow_detail, mix(vec3(0.5), color, contrast));

	// ── Saturation ──
	float luminance = dot(color, vec3(0.2126, 0.7152, 0.0722));
	color = mix(vec3(luminance), color, saturation);

	// ── Institutional gray-green tint ──
	color *= tint;

	// ── Vignette ──
	vec2 uv_centered = SCREEN_UV - vec2(0.5);
	float dist = length(uv_centered);
	float vig = smoothstep(vignette_radius, vignette_radius + 0.45, dist) * vignette_strength;
	color = mix(color, color * 0.15, vig);

	COLOR = vec4(color, 1.0);
}
