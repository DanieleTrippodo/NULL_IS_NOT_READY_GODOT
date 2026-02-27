# res://Weapons/NullProjectile.gd
extends Area3D

enum State { FIRED, DROPPED }

@onready var pickup_indicator: Sprite3D = $PickupIndicator

var state: int = State.FIRED
var velocity: Vector3 = Vector3.ZERO
var traveled: float = 0.0
var t: float = 0.0

# Debug toggle (metti false quando hai finito)
const DEBUG_HITS := true

func fire(origin: Vector3, direction: Vector3) -> void:
	var dir := direction.normalized()
	global_position = origin + dir * 0.6
	velocity = dir * Constants.NULL_SPEED
	state = State.FIRED
	traveled = 0.0
	t = 0.0
	pickup_indicator.visible = false

func _physics_process(delta: float) -> void:
	t += delta

	# animazione indicatore quando a terra
	if state == State.DROPPED:
		pickup_indicator.position.y = 0.7 + sin(t * 6.0) * 0.08
		return

	# === FIRED ===
	var from_pos: Vector3 = global_position
	var step: Vector3 = velocity * delta
	var to_pos: Vector3 = from_pos + step
	traveled += step.length()

	# Sweep raycast: evita di attraversare i collider
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from_pos, to_pos)
	query.exclude = [self]
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var hit: Dictionary = space.intersect_ray(query)
	if hit.size() > 0:
		global_position = hit["position"]

		var collider: Object = hit.get("collider", null)

		if DEBUG_HITS:
			var cname := "null"
			if collider != null:
				cname = collider.get_class()
			print("[NULL HIT] collider=", collider, " class=", cname)
			if collider is Node:
				print("[NULL HIT] groups=", (collider as Node).get_groups())
			if hit.has("position"):
				print("[NULL HIT] pos=", hit["position"])
			if hit.has("normal"):
				print("[NULL HIT] normal=", hit["normal"])

		var enemy_node := _find_enemy_node(collider)
		if enemy_node != null:
			_hit_enemy(enemy_node)
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

func _hit_enemy(enemy: Node) -> void:
	if DEBUG_HITS:
		print("[NULL KILL] enemy=", enemy, " groups=", enemy.get_groups())

	Signals.enemy_killed.emit(enemy)
	Signals.null_ready_changed.emit(true)
	queue_free()

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
