shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

/* CRT controls */
uniform float warp_strength = 0.045;
uniform float vignette_strength = 0.35;
uniform float scanline_strength = 0.16;
uniform float noise_strength = 0.025;
uniform float flicker_strength = 0.02;
uniform float edge_softness = 0.02;   // 0.01..0.06 (quanto “sfuma” verso nero ai bordi)

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

vec2 barrel(vec2 uv, float amt) {
	vec2 cc = uv - 0.5;
	float r2 = dot(cc, cc);
	return uv + cc * r2 * amt;
}

float in_bounds(vec2 uv, float softness) {
	// Maschera morbida: 1 al centro, 0 fuori (con transizione softness)
	float left   = smoothstep(0.0, softness, uv.x);
	float right  = smoothstep(0.0, softness, 1.0 - uv.x);
	float top    = smoothstep(0.0, softness, uv.y);
	float bottom = smoothstep(0.0, softness, 1.0 - uv.y);
	return left * right * top * bottom;
}

void fragment() {
	vec2 uv = UV;

	// Distorsione CRT
	vec2 uvd = barrel(uv, warp_strength);

	// Maschera bordi neri (NO clamp: clamp crea “stretch”)
	float mask = in_bounds(uvd, edge_softness);

	// Campiona solo se dentro; fuori = nero
	vec3 base = vec3(0.0);
	if (mask > 0.0) {
		base = texture(screen_tex, uvd).rgb;
	}

	// Scanlines
	float sl = sin(uv.y * 3.14159 * 900.0 + TIME * 0.15) * 0.5 + 0.5;
	float scan = mix(1.0 - scanline_strength, 1.0, sl);
	base *= scan;

	// Noise neutro
	float n = hash(uv * vec2(1000.0, 600.0) + TIME * 40.0) - 0.5;
	base += vec3(n) * noise_strength;

	// Flicker neutro
	float f = (sin(TIME * 60.0) * 0.5 + 0.5) * flicker_strength;
	base *= (1.0 - f);

	// Vignette (usa UV originali, così è stabile)
	vec2 d = uv - 0.5;
	float vig = smoothstep(0.90, 0.25, dot(d, d) * 1.25);
	base *= mix(1.0, vig, vignette_strength);

	// Applica maschera bordi neri
	base *= mask;

	COLOR = vec4(base, 1.0);
}