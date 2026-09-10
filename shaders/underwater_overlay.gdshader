shader_type canvas_item;
uniform float immersion : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	float edge = smoothstep(0.2, 0.72, length(UV - vec2(0.5)));
	float light_band = sin(UV.x * 19.0 + UV.y * 7.0 + TIME * 1.5) * 0.012;
	COLOR = vec4(vec3(0.025, 0.25 + light_band, 0.31), immersion * (0.16 + edge * 0.25));
}
