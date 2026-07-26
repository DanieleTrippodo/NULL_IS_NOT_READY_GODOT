# res://Weapons/bomb_shot.gd
extends "res://Weapons/recoverable_null_shot.gd"

@export_group("Bomb Shot")
@export var projectile_speed: float = 13.0
@export var max_range: float = 22.0
@export var explosion_radius: float = 5.0
@export var knockback_strength: float = 26.0
@export var knockback_lift: float = 7.0
@export var knockback_stun: float = 0.45

var _velocity: Vector3 = Vector3.ZERO
var _traveled: float = 0.0
var _fired: bool = false
var _bomb_mesh: MeshInstance3D = null

func _ready() -> void:
	_create_bomb_visual()

func fire(origin: Vector3, direction: Vector3, size_mult: float = 1.0) -> void:
	shot_state = ShotState.ACTIVE
	_fired = true
	_traveled = 0.0
	global_position = origin + direction.normalized() * 0.9
	_velocity = direction.normalized() * projectile_speed
	if _bomb_mesh != null:
		_bomb_mesh.visible = true
		_bomb_mesh.scale = Vector3.ONE * maxf(size_mult, 0.75)

func _physics_process(delta: float) -> void:
	if not _fired or shot_state != ShotState.ACTIVE:
		return

	var from_position: Vector3 = global_position
	var step: Vector3 = _velocity * delta
	var to_position: Vector3 = from_position + step
	var query := PhysicsRayQueryParameters3D.create(from_position, to_position)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var player := get_tree().get_first_node_in_group("player")
	if player is CollisionObject3D:
		query.exclude = [(player as CollisionObject3D).get_rid()]

	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var collider: Object = hit.get("collider", null)
		if not _is_passthrough(collider):
			_explode(hit.get("position", to_position))
			return

	global_position = to_position
	_traveled += step.length()
	if _traveled >= max_range:
		_explode(global_position)

func _create_bomb_visual() -> void:
	_bomb_mesh = MeshInstance3D.new()
	_bomb_mesh.name = "BombNull"
	var sphere := SphereMesh.new()
	sphere.radius = 0.55
	sphere.height = 1.1
	_bomb_mesh.mesh = sphere
	_bomb_mesh.material_override = _make_glow_material(Color.WHITE, 1.0)
	_bomb_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bomb_mesh.visible = false
	add_child(_bomb_mesh)

func _explode(position: Vector3) -> void:
	_fired = false
	global_position = position
	if _bomb_mesh != null:
		_bomb_mesh.visible = false

	for node in get_tree().get_nodes_in_group("enemy"):
		if not (node is Node3D) or not is_instance_valid(node):
			continue
		var enemy := node as Node3D
		var offset: Vector3 = enemy.global_position - position
		if offset.length_squared() > explosion_radius * explosion_radius:
			continue

		var push_direction: Vector3 = offset
		push_direction.y = 0.0
		if push_direction.length_squared() <= 0.0001:
			push_direction = Vector3.FORWARD
		else:
			push_direction = push_direction.normalized()

		if enemy.has_method("apply_push"):
			enemy.call("apply_push", push_direction, knockback_strength, knockback_lift, knockback_stun)
		elif enemy.has_method("apply_impact_stun"):
			enemy.call("apply_impact_stun", knockback_stun, push_direction, knockback_strength)

	_spawn_explosion_ring(position)
	become_dropped(position + Vector3.UP * 0.05)

func _spawn_explosion_ring(position: Vector3) -> void:
	var ring := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = 1.0
	mesh.height = 0.025
	mesh.radial_segments = 40
	ring.mesh = mesh
	ring.material_override = _make_glow_material(Color.WHITE, 0.9)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.scale = Vector3.ONE * 0.2
	get_tree().current_scene.add_child(ring)
	ring.global_position = position + Vector3.UP * 0.06

	var material := ring.material_override as StandardMaterial3D
	var tween := ring.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector3(explosion_radius, 0.2, explosion_radius), 0.28)
	tween.tween_property(material, "albedo_color", Color(1.0, 1.0, 1.0, 0.0), 0.28)
	tween.chain().tween_callback(Callable(ring, "queue_free"))
