shader_type canvas_item;

uniform float darkness : hint_range(0.0, 1.0) = 0.22;
uniform float noise_strength : hint_range(0.0, 1.0) = 0.035;
uniform float flicker_strength : hint_range(0.0, 1.0) = 0.025;

uniform float scanline_strength : hint_range(0.0, 1.0) = 0.10;
uniform float scanline_density : hint_range(100.0, 4000.0) = 900.0;

uniform float refresh_strength : hint_range(0.0, 1.0) = 0.10;
uniform float refresh_speed : hint_range(0.0, 10.0) = 1.6;
uniform float refresh_thickness : hint_range(0.001, 0.2) = 0.035;

uniform vec3 tint = vec3(0.82, 0.88, 0.84); // grigio/verde molto soft

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 uv = UV;

	// Oscurimento base
	float dark = 1.0 - darkness;

	// Rumore fine
	float noise = hash(floor(uv * vec2(640.0, 360.0) + TIME * 12.0));
	noise = (noise - 0.5) * 2.0;
	float grain = noise * noise_strength;

	// Scanlines orizzontali
	float scan = sin(uv.y * scanline_density) * 0.5 + 0.5;
	scan = (scan - 0.5) * 2.0;
	float scanlines = -scan * scanline_strength;

	// Refresh line che scende dall'alto verso il basso
	float refresh_pos = fract(TIME * refresh_speed);
	float dist = abs(uv.y - refresh_pos);
	float refresh_line = smoothstep(refresh_thickness, 0.0, dist) * refresh_strength;

	// Flicker globale
	float flicker = 1.0 + sin(TIME * 19.0) * flicker_strength;

	float value = dark + grain + scanlines + refresh_line;
	value *= flicker;
	value = clamp(value, 0.0, 1.0);

	vec3 col = tint * value;

	COLOR = vec4(col, 0.32);
}