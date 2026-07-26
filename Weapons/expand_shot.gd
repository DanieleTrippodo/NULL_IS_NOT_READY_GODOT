# res://Weapons/expand_shot.gd
extends "res://Weapons/recoverable_null_shot.gd"

@export_group("Expand Shot")
@export_range(3, 25, 2) var fragment_count: int = 9
@export_range(1.0, 45.0, 0.5) var spread_degrees: float = 18.0
@export var fragment_speed: float = 24.0
@export var fragment_range: float = 8.5
@export var fragment_radius: float = 0.10

@export_group("Expand Shot Trails")
@export_range(0.2, 4.0, 0.05) var trail_length: float = 1.55
@export_range(0.01, 0.25, 0.005) var trail_width: float = 0.055
@export_range(0.05, 1.0, 0.05) var trail_alpha: float = 0.72

var _fragment_nodes: Array[MeshInstance3D] = []
var _trail_nodes: Array[MeshInstance3D] = []
var _fragment_positions: Array[Vector3] = []
var _fragment_velocities: Array[Vector3] = []
var _fragment_directions: Array[Vector3] = []
var _fragment_traveled: Array[float] = []
var _fragment_active: Array[bool] = []
var _fragment_end_positions: Array[Vector3] = []
var _fired: bool = false

func _ready() -> void:
	_create_fragments()

func fire(origin: Vector3, direction: Vector3, _size_mult: float = 1.0) -> void:
	shot_state = ShotState.ACTIVE
	global_position = origin
	_fired = true

	var forward: Vector3 = direction.normalized()
	var count: int = maxi(fragment_count, 3)
	var pellet_directions: Array[Vector3] = _build_pellet_directions(forward, count)
	var start_position: Vector3 = forward * 0.7

	for index in range(count):
		var pellet_direction: Vector3 = pellet_directions[index]
		_fragment_positions[index] = start_position
		_fragment_velocities[index] = pellet_direction * fragment_speed
		_fragment_directions[index] = pellet_direction
		_fragment_traveled[index] = 0.0
		_fragment_active[index] = true
		_fragment_end_positions[index] = start_position
		_set_fragment_visual(index, start_position, pellet_direction, true)

func _physics_process(delta: float) -> void:
	if not _fired or shot_state != ShotState.ACTIVE:
		return

	var space := get_world_3d().direct_space_state
	var active_left: int = 0

	for index in range(_fragment_nodes.size()):
		if not _fragment_active[index]:
			continue

		var from_local: Vector3 = _fragment_positions[index]
		var step: Vector3 = _fragment_velocities[index] * delta
		var to_local: Vector3 = from_local + step
		var from_world: Vector3 = global_position + from_local
		var to_world: Vector3 = global_position + to_local

		var query := PhysicsRayQueryParameters3D.create(from_world, to_world)
		query.collide_with_areas = false
		query.collide_with_bodies = true
		var player := get_tree().get_first_node_in_group("player")
		if player is CollisionObject3D:
			query.exclude = [(player as CollisionObject3D).get_rid()]
		var hit: Dictionary = space.intersect_ray(query)

		if not hit.is_empty():
			var collider: Object = hit.get("collider", null)
			if _is_passthrough(collider):
				_fragment_positions[index] = to_local
				_fragment_traveled[index] += step.length()
				_set_fragment_visual(index, to_local, _fragment_directions[index], true)
				if _fragment_traveled[index] >= fragment_range:
					_deactivate_fragment(index, to_local)
				else:
					active_left += 1
				continue

			var enemy: Node = _find_enemy_node(collider)
			if enemy != null:
				_emit_enemy_kill(enemy)
				return_null()
				return

			var hit_position: Vector3 = hit.get("position", to_world)
			_deactivate_fragment(index, hit_position - global_position)
			continue

		_fragment_positions[index] = to_local
		_fragment_traveled[index] += step.length()
		_set_fragment_visual(index, to_local, _fragment_directions[index], true)

		if _fragment_traveled[index] >= fragment_range:
			_deactivate_fragment(index, to_local)
		else:
			active_left += 1

	if active_left <= 0 and shot_state == ShotState.ACTIVE:
		_drop_after_miss()

func _build_pellet_directions(forward: Vector3, count: int) -> Array[Vector3]:
	var directions: Array[Vector3] = []
	directions.append(forward)
	if count <= 1:
		return directions

	var shot_basis: Basis = _basis_from_forward(forward)
	var right: Vector3 = shot_basis.x
	var up: Vector3 = shot_basis.y
	var spread_tangent: float = tan(deg_to_rad(spread_degrees))
	var outer_count: int = count - 1

	for index in range(outer_count):
		var angle: float = TAU * float(index) / float(outer_count)
		var ring_scale: float = 1.0
		# Con molti frammenti alterna un anello interno e uno esterno.
		if outer_count > 8 and index % 2 == 0:
			ring_scale = 0.55
		var offset: Vector3 = (
			right * cos(angle) +
			up * sin(angle)
		) * spread_tangent * ring_scale
		directions.append((forward + offset).normalized())

	return directions

func _create_fragments() -> void:
	var count: int = maxi(fragment_count, 3)

	var shared_fragment_mesh := SphereMesh.new()
	shared_fragment_mesh.radius = fragment_radius
	shared_fragment_mesh.height = fragment_radius * 2.0
	var fragment_material := _make_glow_material(Color.WHITE, 1.0)

	var shared_trail_mesh := BoxMesh.new()
	shared_trail_mesh.size = Vector3(trail_width, trail_width, 1.0)
	var trail_material := _make_glow_material(Color.WHITE, trail_alpha)

	for _index in range(count):
		var trail := MeshInstance3D.new()
		trail.name = "ExpandTrail"
		trail.mesh = shared_trail_mesh
		trail.material_override = trail_material
		trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		trail.visible = false
		add_child(trail)
		_trail_nodes.append(trail)

		var fragment := MeshInstance3D.new()
		fragment.name = "ExpandFragment"
		fragment.mesh = shared_fragment_mesh
		fragment.material_override = fragment_material
		fragment.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fragment.visible = false
		add_child(fragment)
		_fragment_nodes.append(fragment)

		_fragment_positions.append(Vector3.ZERO)
		_fragment_velocities.append(Vector3.ZERO)
		_fragment_directions.append(Vector3.FORWARD)
		_fragment_traveled.append(0.0)
		_fragment_active.append(false)
		_fragment_end_positions.append(Vector3.ZERO)

func _set_fragment_visual(index: int, local_position: Vector3, direction: Vector3, visible_state: bool) -> void:
	_fragment_nodes[index].position = local_position
	_fragment_nodes[index].visible = visible_state

	var visible_trail_length: float = minf(trail_length, maxf(_fragment_traveled[index], 0.10))
	_trail_nodes[index].basis = _basis_from_forward(direction) * Basis.from_scale(Vector3(1.0, 1.0, visible_trail_length))
	_trail_nodes[index].position = local_position - direction * (visible_trail_length * 0.5)
	_trail_nodes[index].visible = visible_state

func _basis_from_forward(forward: Vector3) -> Basis:
	var z_axis: Vector3 = forward.normalized()
	var reference_up: Vector3 = Vector3.UP
	if absf(z_axis.dot(reference_up)) > 0.98:
		reference_up = Vector3.RIGHT
	var x_axis: Vector3 = reference_up.cross(z_axis).normalized()
	var y_axis: Vector3 = z_axis.cross(x_axis).normalized()
	return Basis(x_axis, y_axis, z_axis)

func _deactivate_fragment(index: int, local_position: Vector3) -> void:
	_fragment_active[index] = false
	_fragment_positions[index] = local_position
	_fragment_end_positions[index] = local_position
	_fragment_nodes[index].position = local_position
	_fragment_nodes[index].visible = false
	_trail_nodes[index].visible = false

func _drop_after_miss() -> void:
	var drop_local_position := Vector3.ZERO
	if not _fragment_end_positions.is_empty():
		for end_position in _fragment_end_positions:
			drop_local_position += end_position
		drop_local_position /= float(_fragment_end_positions.size())

	for fragment in _fragment_nodes:
		fragment.visible = false
	for trail in _trail_nodes:
		trail.visible = false
	become_dropped(global_position + drop_local_position + Vector3.UP * 0.05)
