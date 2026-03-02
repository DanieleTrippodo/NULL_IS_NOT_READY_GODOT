shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform float jitter_amt : hint_range(0.0, 1.0) = 1.0;
uniform float warp_amt : hint_range(0.0, 1.0) = 1.0;
uniform float scanline : hint_range(0.0, 1.0) = 0.35;
uniform float noise_amt : hint_range(0.0, 1.0) = 0.25;

uniform float corner_radius : hint_range(0.0, 0.25) = 0.06;
uniform float border_softness : hint_range(0.0, 0.1) = 0.02;
uniform float vignette : hint_range(0.0, 1.0) = 0.35;

float rand(vec2 uv) {
	return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
}

float rounded_mask(vec2 uv, float r, float s) {
	vec2 p = uv * 2.0 - 1.0;
	vec2 b = vec2(1.0 - r, 1.0 - r);
	vec2 q = abs(p) - b;
	float d = length(max(q, 0.0)) - r;
	return 1.0 - smoothstep(0.0, s, d);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float t = TIME;

	// Distorsione più forte vicino top/bottom
	float edge = smoothstep(0.0, 0.18, uv.y) + smoothstep(1.0, 0.82, uv.y);
	edge = clamp(edge, 0.0, 1.0);

	// Jitter per-linea
	float line_jitter = (rand(vec2(floor(uv.y * 240.0), t * 60.0)) - 0.5);
	float jitter = line_jitter * 0.03 * jitter_amt * strength;

	// Wave + warp ai bordi
	float wave = sin((uv.y * 45.0) + t * 10.0) * 0.004;
	float warp = sin(t * 2.5 + uv.y * 8.0) * 0.012 * edge * warp_amt;

	float offset = (wave + jitter + warp) * strength;

	// Aberrazione cromatica
	vec2 uvr = uv + vec2(offset, 0.0);
	vec2 uvg = uv + vec2(offset * 0.65, 0.0);
	vec2 uvb = uv + vec2(offset * 0.35, 0.0);

	vec4 col = vec4(0.0);
	col.r = texture(screen_texture, uvr).r;
	col.g = texture(screen_texture, uvg).g;
	col.b = texture(screen_texture, uvb).b;
	col.a = 1.0;

	// Scanlines
	float sl = sin(uv.y * 900.0) * 0.05 * scanline;
	col.rgb -= sl;

	// Noise
	float n = (rand(uv * (t + 1.0)) - 0.5) * 0.14 * noise_amt * strength;
	col.rgb += n;

	// Vignette
	vec2 c = uv - 0.5;
	float v = 1.0 - (dot(c, c) * 2.2 * vignette);
	v = clamp(v, 0.0, 1.0);
	col.rgb *= v;

	// Rounded corners mask
	float m = rounded_mask(uv, corner_radius, border_softness);
	col.rgb = mix(vec3(0.0), col.rgb, m);
	col.a *= m;

	COLOR = col;
}