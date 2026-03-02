shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

uniform float effect_strength : hint_range(0.0, 1.0) = 0.0;
uniform float pulse           : hint_range(0.0, 1.0) = 0.0;

uniform float speed           : hint_range(0.0, 8.0) = 2.5;

uniform float line_jitter     : hint_range(0.0, 0.04) = 0.012;
uniform float rgb_split       : hint_range(0.0, 0.02) = 0.006;

uniform float block_strength  : hint_range(0.0, 1.0) = 0.85;
uniform float block_size_y    : hint_range(8.0, 240.0) = 64.0;

uniform float noise_strength  : hint_range(0.0, 0.25) = 0.06;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.35;

uniform float vignette_strength : hint_range(0.0, 1.0) = 0.35;
uniform float vignette_softness : hint_range(0.01, 1.0) = 0.35;

float hash11(float n) { return fract(sin(n) * 43758.5453123); }
float hash21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123); }

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 viewport_size = 1.0 / SCREEN_PIXEL_SIZE;

	vec4 base = texture(screen_tex, uv);

	float t = TIME * speed;

	// --- LINE JITTER (per righe)
	float yline = floor(uv.y * 720.0);
	float lj = (hash11(yline * 0.07 + floor(t * 24.0)) - 0.5) * line_jitter;

	// --- BLOCK GLITCH (shift per blocchi)
	float by = floor((uv.y * viewport_size.y) / block_size_y);
	float block_gate = step(0.78, hash11(by * 3.1 + floor(t * 6.0)));
	float bx = (hash11(by * 9.7 + floor(t * 6.0) + 13.0) - 0.5) * 0.12;
	float block_shift = bx * block_gate * block_strength;

	// intensità finale (master + spike)
	float s = clamp(effect_strength + pulse * 0.65, 0.0, 1.0);

	// offset UV totale
	vec2 duv = vec2(lj + block_shift, 0.0) * s;

	// --- RGB SPLIT
	float cs = rgb_split * s;
	vec4 cr = texture(screen_tex, uv + duv + vec2( cs, 0.0));
	vec4 cg = texture(screen_tex, uv + duv + vec2(-cs, 0.0));
	vec4 cb = texture(screen_tex, uv + duv);

	vec4 glitch = vec4(cr.r, cg.g, cb.b, 1.0);

	// --- NOISE
	float n = (hash21(uv * viewport_size + vec2(floor(t * 120.0), 0.0)) - 0.5) * 2.0;
	glitch.rgb += n * noise_strength * s;

	// --- SCANLINES
	float scan = sin((uv.y * viewport_size.y) * 3.14159) * 0.5 + 0.5;
	glitch.rgb *= mix(1.0, scan, scanline_strength * s);

	// --- VIGNETTE
	float d = distance(uv, vec2(0.5));
	float v = smoothstep(0.5 - vignette_softness, 0.5, d);
	glitch.rgb *= (1.0 - v * vignette_strength * s);

	COLOR = mix(base, glitch, s);
}