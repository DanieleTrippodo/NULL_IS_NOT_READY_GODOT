shader_type canvas_item;

uniform float density = 45.0;        // quanti punti
uniform float speed = 0.06;          // velocità salita
uniform float size = 0.010;          // raggio base
uniform float jitter = 0.55;         // variazione dimensione
uniform float intensity = 0.55;      // luminosità
uniform float softness = 3.5;        // sfumatura "glow"
uniform vec2 drift = vec2(0.03, 1.0); // direzione (x, y)

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

vec2 hash2(vec2 p) {
	float n = hash(p);
	return vec2(n, hash(p + n + 19.19));
}

void fragment() {
	vec2 uv = UV;
	float t = TIME;

	// Griglia di celle (più density -> più celle -> più punti)
	vec2 g = uv * density;
	vec2 id = floor(g);
	vec2 f = fract(g);

	// Un solo punto per cella, posizione pseudo-random
	vec2 rnd = hash2(id);
	vec2 p = rnd;

	// Animazione: risali verso l'alto con wrap
	p += drift * t * speed;
	p = fract(p);

	// Distanza dal punto
	float r = size * mix(0.55, 1.35, hash(id + 3.3) * jitter);
	float d = distance(f, p);

	// Glow soft (gauss-like)
	float dotv = exp(-pow(d / r, softness)) * intensity;

	// Leggera attenuazione per ridurre "blob" troppo forti
	dotv = clamp(dotv, 0.0, 0.9);

	// Fondo nero + puntini bianchi
	COLOR = vec4(vec3(dotv), dotv);
}