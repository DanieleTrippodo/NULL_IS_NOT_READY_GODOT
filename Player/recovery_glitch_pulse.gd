# res://Player/recovery_glitch_pulse.gd
extends Node3D

@export_group("Recovery Glitch Pulse")
@export_range(0.10, 1.00, 0.01) var pulse_interval: float = 0.34
@export_range(0.20, 2.00, 0.01) var pulse_duration: float = 0.72
@export_range(0.10, 2.00, 0.05) var start_radius: float = 0.42
@export_range(0.50, 5.00, 0.05) var end_radius: float = 2.55
@export_range(12, 128, 1) var ring_segments: int = 56
@export_range(0.00, 0.50, 0.005) var glitch_jitter: float = 0.075
@export_range(0.00, 0.80, 0.01) var missing_segment_ratio: float = 0.20
@export_range(-1.00, 2.00, 0.05) var center_height: float = 0.15
@export_range(0.10, 1.00, 0.05) var vertical_scale: float = 0.62
@export_range(0.10, 1.00, 0.01) var max_alpha: float = 0.78
@export_range(0.10, 12.00, 0.10) var emission_energy: float = 5.5

var _player: Node = null
var _active: bool = false
var _spawn_timer: float = 0.0
var _seed_counter: int = 0
var _pulses: Array = []


func _ready() -> void:
	_player = get_parent()
	_spawn_timer = 0.0
	set_process(true)


func _process(delta: float) -> void:
	var recovering := false
	if is_instance_valid(_player):
		recovering = bool(_player.get("is_recovering_null"))

	if recovering and not _active:
		_active = true
		_spawn_timer = 0.0
	elif not recovering:
		_active = false

	if _active:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_pulse()
			_spawn_timer = pulse_interval

	_update_pulses(delta)


func _spawn_pulse() -> void:
	_seed_counter += 1

	var pulse_node := MeshInstance3D.new()
	pulse_node.name = "RecoveryGlitchPulse_%d" % _seed_counter
	pulse_node.position = Vector3(0.0, center_height, 0.0)
	pulse_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pulse_node)

	var pulse_mesh := ImmediateMesh.new()
	pulse_node.mesh = pulse_mesh

	var pulse_material := StandardMaterial3D.new()
	pulse_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pulse_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pulse_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	pulse_material.vertex_color_use_as_albedo = true
	pulse_material.emission_enabled = true
	pulse_material.emission = Color.WHITE
	pulse_material.emission_energy_multiplier = emission_energy
	pulse_material.render_priority = 8
	pulse_material.albedo_color = Color(1.0, 1.0, 1.0, max_alpha)

	_pulses.append({
		"node": pulse_node,
		"mesh": pulse_mesh,
		"material": pulse_material,
		"age": 0.0,
		"seed": _seed_counter,
	})

	_rebuild_pulse(_pulses.back(), 0.0)


func _update_pulses(delta: float) -> void:
	for index in range(_pulses.size() - 1, -1, -1):
		var pulse: Dictionary = _pulses[index]
		var age := float(pulse["age"]) + delta
		pulse["age"] = age

		var progress := age / maxf(pulse_duration, 0.001)
		if progress >= 1.0:
			var pulse_node: MeshInstance3D = pulse["node"]
			if is_instance_valid(pulse_node):
				pulse_node.queue_free()
			_pulses.remove_at(index)
			continue

		_rebuild_pulse(pulse, progress)


func _rebuild_pulse(pulse: Dictionary, progress: float) -> void:
	var pulse_mesh: ImmediateMesh = pulse["mesh"]
	var pulse_material: StandardMaterial3D = pulse["material"]
	var pulse_seed := int(pulse["seed"])

	var eased_progress := 1.0 - pow(1.0 - progress, 2.0)
	var radius := lerpf(start_radius, end_radius, eased_progress)
	var alpha := max_alpha * pow(1.0 - progress, 1.45)
	var flicker := 0.78 + 0.22 * sin(Time.get_ticks_msec() * 0.045 + pulse_seed * 2.17)

	pulse_material.albedo_color = Color(1.0, 1.0, 1.0, alpha * flicker)
	pulse_material.emission_energy_multiplier = emission_energy * lerpf(1.15, 0.45, progress)

	pulse_mesh.clear_surfaces()
	pulse_mesh.surface_begin(Mesh.PRIMITIVE_LINES, pulse_material)

	# Due anelli spezzati formano la gabbia digitale.
	# L'anello laterale sul piano YZ è stato rimosso perché, visto in prima persona,
	# risultava di taglio e appariva come una linea verticale al centro dello schermo.
	_add_glitch_ring(pulse_mesh, 0, radius, pulse_seed, progress)
	_add_glitch_ring(pulse_mesh, 1, radius, pulse_seed + 37, progress)
	_add_data_fragments(pulse_mesh, radius, pulse_seed, progress)

	pulse_mesh.surface_end()


func _add_glitch_ring(
	mesh: ImmediateMesh,
	plane: int,
	radius: float,
	pulse_seed: int,
	progress: float
) -> void:
	var time_phase := Time.get_ticks_msec() * 0.025
	var segment_angle := TAU / float(maxi(ring_segments, 3))

	for segment in range(ring_segments):
		var segment_noise := _hash01(segment * 31 + pulse_seed * 101)
		var animated_gap := 0.05 * sin(time_phase * 0.55 + segment * 1.71 + pulse_seed)
		if segment_noise < clampf(missing_segment_ratio + animated_gap, 0.0, 0.85):
			continue

		var angle_a := float(segment) * segment_angle
		var angle_b := float(segment + 1) * segment_angle
		var jitter_strength := glitch_jitter * (1.0 - progress * 0.55)
		var jitter_a := (_hash01(segment * 17 + pulse_seed * 43) - 0.5) * jitter_strength
		var jitter_b := (_hash01((segment + 1) * 17 + pulse_seed * 43) - 0.5) * jitter_strength

		# Alcuni frammenti scattano avanti e indietro per accentuare il glitch.
		if (segment + pulse_seed) % 11 == 0:
			jitter_a += sin(time_phase + segment) * jitter_strength * 2.4
			jitter_b += sin(time_phase + segment + 0.7) * jitter_strength * 2.4

		var point_a := _ring_point(plane, angle_a, radius + jitter_a)
		var point_b := _ring_point(plane, angle_b, radius + jitter_b)
		mesh.surface_set_color(Color.WHITE)
		mesh.surface_add_vertex(point_a)
		mesh.surface_add_vertex(point_b)


func _add_data_fragments(
	mesh: ImmediateMesh,
	radius: float,
	pulse_seed: int,
	progress: float
) -> void:
	var fragment_count := 8
	var time_phase := Time.get_ticks_msec() * 0.018

	for fragment in range(fragment_count):
		var base_angle := TAU * _hash01(fragment * 71 + pulse_seed * 29)
		var fragment_radius := radius * lerpf(0.72, 1.12, _hash01(fragment * 47 + pulse_seed * 13))
		var y := lerpf(-0.55, 0.85, _hash01(fragment * 19 + pulse_seed * 61)) * vertical_scale
		var slide := sin(time_phase + fragment * 2.4 + pulse_seed) * glitch_jitter * 2.0
		var tangent := Vector3(-sin(base_angle), 0.0, cos(base_angle))
		var center := Vector3(cos(base_angle) * fragment_radius, y + slide, sin(base_angle) * fragment_radius)
		var half_length := lerpf(0.05, 0.22, _hash01(fragment * 89 + pulse_seed * 7)) * (1.0 - progress * 0.35)

		mesh.surface_set_color(Color.WHITE)
		mesh.surface_add_vertex(center - tangent * half_length)
		mesh.surface_add_vertex(center + tangent * half_length)


func _ring_point(plane: int, angle: float, radius: float) -> Vector3:
	var c := cos(angle)
	var s := sin(angle)

	match plane:
		0:
			# Piano orizzontale, attorno ai piedi e al busto.
			return Vector3(c * radius, -0.38, s * radius)
		1:
			# Piano verticale frontale.
			return Vector3(c * radius, s * radius * vertical_scale, 0.0)
		_:
			# Piano verticale laterale.
			return Vector3(0.0, s * radius * vertical_scale, c * radius)


func _hash01(value: int) -> float:
	return fposmod(sin(float(value) * 12.9898) * 43758.5453, 1.0)
