extends Area3D

@export var default_speed: float = 14.0
@export var default_life: float = 6.0
@export var owner_ignore_time: float = 0.1

var velocity: Vector3 = Vector3.ZERO
var life: float = 0.0
var shooter: Node = null
var _owner_ignore_left: float = 0.0
var _spent: bool = false

func _ready() -> void:
	add_to_group("enemy_bullet")
	life = default_life
	monitoring = true
	monitorable = true

func fire(origin: Vector3, direction: Vector3, speed: float = -1.0, shooter_owner: Node = null) -> void:
	global_position = origin

	var dir: Vector3 = direction
	if dir.length_squared() <= 0.00001:
		dir = Vector3.FORWARD
	dir = dir.normalized()

	velocity = dir * (default_speed if speed <= 0.0 else speed)
	life = default_life
	shooter = shooter_owner
	_owner_ignore_left = owner_ignore_time if shooter_owner != null else 0.0
	_spent = false

func _physics_process(delta: float) -> void:
	if _spent:
		return

	if _owner_ignore_left > 0.0:
		_owner_ignore_left = maxf(_owner_ignore_left - delta, 0.0)

	var from_pos: Vector3 = global_position
	var to_pos: Vector3 = from_pos + velocity * delta

	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from_pos, to_pos)
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var exclude: Array = [self]
	if shooter != null and is_instance_valid(shooter):
		exclude.append(shooter)
	query.exclude = exclude

	var hit: Dictionary = space.intersect_ray(query)
	if hit.size() > 0:
		var collider: Object = hit.get("collider", null)
		if _should_ignore_collider(collider):
			global_position = hit.get("position", to_pos) + velocity.normalized() * 0.06
		else:
			_handle_body_hit(collider)
			return
	else:
		global_position = to_pos

	life -= delta
	if life <= 0.0:
		_consume()

func _should_ignore_collider(collider: Object) -> bool:
	var node := _as_node(collider)
	if node == null:
		return false

	if shooter != null and node == shooter and _owner_ignore_left > 0.0:
		return true

	if node.is_in_group("boss_wall"):
		return true

	return false

func _handle_body_hit(collider: Object) -> void:
	if _spent:
		return

	var node := _as_node(collider)
	if node != null and node.is_in_group("player"):
		var knock_dir: Vector3 = velocity.normalized()
		if knock_dir.length_squared() <= 0.00001:
			knock_dir = Vector3.FORWARD
		Signals.player_hit.emit(knock_dir)

	_consume()

func _as_node(obj: Object) -> Node:
	if obj == null or not (obj is Node):
		return null
	return obj as Node

func _consume() -> void:
	if _spent:
		return

	_spent = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	set_physics_process(false)
	queue_free()
