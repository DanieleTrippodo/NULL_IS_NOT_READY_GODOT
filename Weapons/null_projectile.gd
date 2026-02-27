# res://Weapons/NullProjectile.gd
extends Area3D

enum State { FIRED, DROPPED }

@onready var pickup_indicator: Sprite3D = $PickupIndicator
@onready var col_shape: CollisionShape3D = $CollisionShape3D

var state: int = State.FIRED
var velocity: Vector3 = Vector3.ZERO
var traveled: float = 0.0
var t: float = 0.0

var bounces_left: int = 0
var sweep_radius: float = 0.2

func _ready() -> void:
	# prova a leggere il raggio reale dalla shape (se è una SphereShape3D)
	if col_shape != null and col_shape.shape is SphereShape3D:
		sweep_radius = (col_shape.shape as SphereShape3D).radius
	else:
		sweep_radius = 0.2

func fire(origin: Vector3, direction: Vector3) -> void:
	var dir: Vector3 = direction.normalized()
	global_position = origin + dir * 0.6

	velocity = dir * (Constants.NULL_SPEED * Run.null_speed_mult)

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

	var hit: Dictionary = _sweep_thick(from_pos, to_pos)
	if hit.size() > 0:
		var hit_pos: Vector3 = hit["position"]
		var hit_n: Vector3 = hit.get("normal", Vector3.UP)
		var collider: Object = hit.get("collider", null)

		global_position = hit_pos

		# enemy kill
		var enemy_node: Node = _find_enemy_node(collider)
		if enemy_node != null:
			Signals.enemy_killed.emit(enemy_node)
			Signals.null_ready_changed.emit(true)
			queue_free()
			return

		# bounce (solo su non-enemy)
		if bounces_left > 0:
			bounces_left -= 1
			velocity = velocity.bounce(hit_n)
			global_position = hit_pos + hit_n * 0.05
			return

		_drop()
		return

	global_position = to_pos

	if traveled >= (Constants.NULL_MAX_DISTANCE * Run.null_range_mult):
		_drop()

# Raycast “spesso”: 5 raggi (centro + 4 offset) e prende l’hit più vicino
func _sweep_thick(from_pos: Vector3, to_pos: Vector3) -> Dictionary:
	var dir: Vector3 = to_pos - from_pos
	if dir.length() < 0.0001:
		return {}

	dir = dir.normalized()

	# costruisci due assi perpendicolari al verso di tiro
	var right := dir.cross(Vector3.UP)
	if right.length() < 0.001:
		right = dir.cross(Vector3.FORWARD)
	right = right.normalized()

	var up := right.cross(dir).normalized()

	var offsets: Array[Vector3] = [
		Vector3.ZERO,
		right * sweep_radius,
		-right * sweep_radius,
		up * sweep_radius,
		-up * sweep_radius
	]

	var best_hit: Dictionary = {}
	var best_dist: float = INF

	var space := get_world_3d().direct_space_state

	for off: Vector3 in offsets:
		var q := PhysicsRayQueryParameters3D.create(from_pos + off, to_pos + off)
		q.exclude = [self]
		q.collide_with_areas = false
		q.collide_with_bodies = true

		var h: Dictionary = space.intersect_ray(q)
		if h.size() > 0 and h.has("position"):
			var p: Vector3 = h["position"]
			var d: float = (p - from_pos).length()
			if d < best_dist:
				best_dist = d
				best_hit = h

	return best_hit

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
