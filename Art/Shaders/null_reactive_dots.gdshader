shader_type spatial;

render_mode unshaded, cull_back;

global uniform vec3 null_player_world_position;

uniform vec4 base_color : source_color = vec4(0.01, 0.01, 0.012, 1.0);
uniform vec4 dot_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

uniform float emission_strength : hint_range(0.0, 10.0, 0.1) = 3.0;

uniform float dot_density : hint_range(1.0, 40.0, 0.5) = 8.0;
uniform float dot_size : hint_range(0.01, 0.45, 0.01) = 0.07;
uniform float dot_softness : hint_range(0.001, 0.2, 0.001) = 0.025;

uniform float effect_radius : hint_range(0.1, 20.0, 0.1) = 4.0;
uniform float repulsion_strength : hint_range(0.0, 3.0, 0.01) = 0.65;
uniform float center_clear_radius : hint_range(0.0, 5.0, 0.05) = 0.65;

uniform float idle_dot_visibility : hint_range(0.0, 1.0, 0.01) = 0.18;
uniform float active_dot_visibility : hint_range(0.0, 2.0, 0.01) = 1.0;

uniform float movement_speed : hint_range(0.0, 10.0, 0.1) = 2.0;
uniform float vibration_strength : hint_range(0.0, 1.0, 0.01) = 0.08;

varying vec3 world_position;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 surface_pos = world_position.xz;
	vec2 player_pos = null_player_world_position.xz;

	float dist_to_player = distance(surface_pos, player_pos);

	float influence = 1.0 - smoothstep(0.0, effect_radius, dist_to_player);

	vec2 away_dir = surface_pos - player_pos;

	if (length(away_dir) < 0.001) {
		away_dir = vec2(0.0, 1.0);
	} else {
		away_dir = normalize(away_dir);
	}

	float pulse = 0.85 + sin(TIME * movement_speed + dist_to_player * 8.0) * 0.15;

	vec2 repelled_pos = surface_pos - away_dir * repulsion_strength * influence * pulse;

	vec2 grid = repelled_pos * dot_density;
	vec2 cell_id = floor(grid);
	vec2 cell_uv = fract(grid) - 0.5;

	float random_value = hash21(cell_id);

	vec2 vibration = vec2(
		sin(TIME * movement_speed + random_value * 6.2831),
		cos(TIME * movement_speed + random_value * 6.2831)
	) * vibration_strength * influence;

	cell_uv += vibration;

	float dot_distance = length(cell_uv);
	float dot_mask = 1.0 - smoothstep(dot_size, dot_size + dot_softness, dot_distance);

	float center_clear = smoothstep(center_clear_radius * 0.25, center_clear_radius, dist_to_player);

	float visibility = mix(idle_dot_visibility, active_dot_visibility, influence);

	float final_dot = dot_mask * visibility * center_clear;

	vec3 final_color = base_color.rgb + dot_color.rgb * final_dot * emission_strength;

	ALBEDO = final_color;
	EMISSION = dot_color.rgb * final_dot * emission_strength;
}