# res://Weapons/NullProjectile.gd
extends Area3D

enum State { FIRED, DROPPED }

@onready var pickup_indicator: Sprite3D = $PickupIndicator

var state: int = State.FIRED
var velocity: Vector3 = Vector3.ZERO
var traveled: float = 0.0
var t: float = 0.0

var bounces_left: int = 0

func fire(origin: Vector3, direction: Vector3) -> void:
	var dir := direction.normalized()
	global_position = origin + dir * 0.6
	velocity = dir * Constants.NULL_SPEED
	state = State.FIRED
	traveled = 0.0
	t = 0.0

	bounces_left = Run.null_bounces
	pickup_indicator.visible = false

func _physics_process(delta: float) -> void:
	t += delta

	if state == State.DROPPED:
		pickup_indicator.position.y = 0.7 + sin(t * 6.0) * 0.08
		return

	var from_pos: Vector3 = global_position
	var step: Vector3 = velocity * delta
	var to_pos: Vector3 = from_pos + step
	traveled += step.length()

	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from_pos, to_pos)
	query.exclude = [self]
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var hit: Dictionary = space.intersect_ray(query)
	if hit.size() > 0:
		var hit_pos: Vector3 = hit["position"]
		var hit_n: Vector3 = hit.get("normal", Vector3.UP)
		var collider: Object = hit.get("collider", null)

		global_position = hit_pos

		# enemy kill
		var enemy_node := _find_enemy_node(collider)
		if enemy_node != null:
			Signals.enemy_killed.emit(enemy_node)
			Signals.null_ready_changed.emit(true)
			queue_free()
			return

		# bounce (solo su non-enemy)
		if bounces_left > 0:
			bounces_left -= 1
			velocity = velocity.bounce(hit_n)
			# piccolo offset per evitare ri-hit immediato
			global_position = hit_pos + hit_n * 0.05
			return

		_drop()
		return

	global_position = to_pos

	if traveled >= Constants.NULL_MAX_DISTANCE:
		_drop()

func _find_enemy_node(collider: Object) -> Node:
	if collider == null or not (collider is Node):
		return null

	var n: Node = collider as Node
	while n != null:
		if n.is_in_group("enemy"):
			return n
		n = n.get_parent()
	return null

func _drop() -> void:
	state = State.DROPPED
	velocity = Vector3.ZERO
	global_position.y += 0.05

	pickup_indicator.visible = true
	pickup_indicator.position.y = 0.7

	Signals.null_ready_changed.emit(false)

func pickup() -> void:
	pickup_indicator.visible = false
	queue_free()
