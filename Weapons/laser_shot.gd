# res://Weapons/laser_shot.gd
extends Node3D

@export_group("Laser Shot")
@export var activation_delay: float = 0.35
@export var active_duration: float = 2.0
@export var max_range: float = 34.0
@export var beam_width: float = 0.22
@export var damage_tick: float = 0.05

var _direction: Vector3 = Vector3.FORWARD
var _beam_length: float = 1.0
var _delay_left: float = 0.0
var _active_left: float = 0.0
var _tick_left: float = 0.0
var _activated: bool = false
var _finished: bool = false
var _beam: MeshInstance3D = null
var _beam_material: StandardMaterial3D = null
var _hit_enemy_ids: Dictionary = {}

func _ready() -> void:
	_create_beam()

func fire(origin: Vector3, direction: Vector3, _size_mult: float = 1.0) -> void:
	global_position = origin
	_direction = direction.normalized()
	_delay_left = activation_delay
	_active_left = active_duration
	_tick_left = 0.0
	_activated = false
	_finished = false
	_hit_enemy_ids.clear()
	_beam_length = global_position.distance_to(_find_beam_end(origin, _direction))
	_update_beam_transform(0.035, 0.22)

func _physics_process(delta: float) -> void:
	if _finished:
		return

	if not _activated:
		_delay_left -= delta
		var pulse_alpha: float = 0.15 + (sin(Time.get_ticks_msec() * 0.025) * 0.5 + 0.5) * 0.18
		_update_beam_transform(0.035, pulse_alpha)
		if _delay_left <= 0.0:
			_activated = true
			_update_beam_transform(beam_width, 1.0)
		return

	_active_left -= delta
	_tick_left -= delta
	if _tick_left <= 0.0:
		_damage_enemies_in_beam()
		_tick_left = maxf(damage_tick, 0.01)

	if _active_left <= 0.0:
		_complete_laser()

func is_dropped() -> bool:
	return false

func blocks_forced_return() -> bool:
	return not _finished

func pickup() -> void:
	_complete_laser()

func pull_to_hand() -> void:
	pass

func start_remote_recovery(_target: Node3D) -> void:
	pass

func stop_remote_recovery() -> void:
	pass

func _create_beam() -> void:
	_beam = MeshInstance3D.new()
	_beam.name = "PersistentLaser"
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam_material = StandardMaterial3D.new()
	_beam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_beam_material.albedo_color = Color(1.0, 1.0, 1.0, 0.2)
	_beam_material.emission_enabled = true
	_beam_material.emission = Color.WHITE
	_beam_material.disable_fog = true
	_beam.material_override = _beam_material
	add_child(_beam)

func _update_beam_transform(width: float, alpha: float) -> void:
	if _beam == null:
		return

	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, width, maxf(_beam_length, 0.1))
	_beam.mesh = mesh
	_beam.position = _direction * (_beam_length * 0.5)
	_beam.basis = _basis_from_forward(_direction)
	_beam_material.albedo_color = Color(1.0, 1.0, 1.0, alpha)

func _damage_enemies_in_beam() -> void:
	var shape := BoxShape3D.new()
	shape.size = Vector3(beam_width * 2.0, beam_width * 2.0, maxf(_beam_length, 0.1))

	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(
		_basis_from_forward(_direction),
		global_position + _direction * (_beam_length * 0.5)
	)
	params.collide_with_areas = false
	params.collide_with_bodies = true

	var hits: Array[Dictionary] = get_world_3d().direct_space_state.intersect_shape(params, 64)
	for hit in hits:
		var enemy: Node = _find_enemy_node(hit.get("collider", null))
		if enemy == null or not is_instance_valid(enemy):
			continue
		var enemy_id: int = enemy.get_instance_id()
		if _hit_enemy_ids.has(enemy_id):
			continue
		_hit_enemy_ids[enemy_id] = true
		if Signals.has_signal("enemy_hit_feedback"):
			Signals.enemy_hit_feedback.emit(enemy, true)
		Signals.enemy_killed.emit(enemy)

func _find_beam_end(origin: Vector3, direction: Vector3) -> Vector3:
	var end_position: Vector3 = origin + direction * max_range
	var exclude: Array[RID] = []
	var player := get_tree().get_first_node_in_group("player")
	if player is CollisionObject3D:
		exclude.append((player as CollisionObject3D).get_rid())

	for _attempt in range(32):
		var query := PhysicsRayQueryParameters3D.create(origin, end_position)
		query.exclude = exclude
		query.collide_with_areas = false
		query.collide_with_bodies = true
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			return end_position

		var collider: Object = hit.get("collider", null)
		if _find_enemy_node(collider) != null or _is_passthrough(collider):
			if collider is CollisionObject3D:
				exclude.append((collider as CollisionObject3D).get_rid())
				continue
		return hit.get("position", end_position)

	return end_position

func _basis_from_forward(forward: Vector3) -> Basis:
	var z_axis: Vector3 = forward.normalized()
	var reference_up: Vector3 = Vector3.UP
	if absf(z_axis.dot(reference_up)) > 0.98:
		reference_up = Vector3.RIGHT
	var x_axis: Vector3 = reference_up.cross(z_axis).normalized()
	var y_axis: Vector3 = z_axis.cross(x_axis).normalized()
	return Basis(x_axis, y_axis, z_axis)

func _find_enemy_node(collider: Object) -> Node:
	if collider == null or not (collider is Node):
		return null
	var node := collider as Node
	while node != null:
		if node.is_in_group("enemy"):
			return node
		node = node.get_parent()
	return null

func _is_passthrough(collider: Object) -> bool:
	if collider == null or not (collider is Node):
		return false
	var node := collider as Node
	while node != null:
		if node.is_in_group("null_passthrough"):
			return true
		node = node.get_parent()
	return false

func _complete_laser() -> void:
	if _finished:
		return
	_finished = true
	Run.null_ready = true
	Run.null_dropped = false
	Signals.null_ready_changed.emit(true)
	queue_free()
