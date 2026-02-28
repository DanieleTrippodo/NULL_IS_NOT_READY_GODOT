shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.65;
uniform float softness  : hint_range(0.01, 1.0) = 0.35;

void fragment() {
	vec2 uv = SCREEN_UV;
	float d = distance(uv, vec2(0.5));
	// bordo scuro
	float v = smoothstep(0.5 - softness, 0.5, d);
	float a = v * intensity;
	COLOR = vec4(0.0, 0.0, 0.0, a);
}