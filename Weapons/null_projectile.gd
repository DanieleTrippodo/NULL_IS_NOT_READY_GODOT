# res://Weapons/null_projectile.gd
extends Area3D

enum State { FIRED, DROPPED }

@onready var pickup_indicator: Sprite3D = $PickupIndicator
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var state: int = State.FIRED
var velocity: Vector3 = Vector3.ZERO
var traveled: float = 0.0
var t: float = 0.0

var bounces_left: int = 0
var size_mult: float = 1.0

const MIN_SEGMENT_LEN: float = 0.12
const MAX_SUBSTEPS: int = 10
const HIT_NUDGE: float = 0.05


func fire(origin: Vector3, direction: Vector3, size_mult_in: float = 1.0) -> void:
	var dir: Vector3 = direction.normalized()

	# scala il proiettile (hitbox inclusa) per i colpi caricati
	size_mult = max(0.25, size_mult_in)
	scale = Vector3.ONE * size_mult

	# spawn un po' più avanti (soprattutto se è grande) per evitare colpi "a bruciapelo" strani
	global_position = origin + dir * (0.6 + 0.25 * size_mult)

	# perk: speed
	velocity = dir * (Constants.NULL_SPEED * Run.null_speed_mult)

	state = State.FIRED
	traveled = 0.0
	t = 0.0

	# perk: bounces
	bounces_left = Run.null_bounces

	pickup_indicator.visible = false


func _physics_process(delta: float) -> void:
	t += delta

	if state == State.DROPPED:
		pickup_indicator.position.y = 0.7 + sin(t * 6.0) * 0.08
		return

	# kill immediato se spawna/finisce già dentro un enemy
	if _try_kill_at(global_position):
		return

	var step: Vector3 = velocity * delta
	var step_len: float = step.length()
	if step_len <= 0.00001:
		return

	var substeps: int = _compute_substeps(step_len)
	var seg: Vector3 = step / float(substeps)

	var space := get_world_3d().direct_space_state

	for _i in range(substeps):
		var from_pos: Vector3 = global_position
		var to_pos: Vector3 = from_pos + seg

		# raycast per muri/ostacoli (gestisce bounce/drop sul mondo)
		var query := PhysicsRayQueryParameters3D.create(from_pos, to_pos)
		query.exclude = [get_rid()]
		query.collide_with_areas = false
		query.collide_with_bodies = true

		var hit: Dictionary = space.intersect_ray(query)
		if hit.size() > 0:
			var hit_pos: Vector3 = hit["position"]
			var hit_n: Vector3 = hit.get("normal", Vector3.UP)
			var collider: Object = hit.get("collider", null)

			traveled += from_pos.distance_to(hit_pos)
			global_position = hit_pos

			# enemy kill (hit diretto col ray)
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
				global_position = hit_pos + hit_n * HIT_NUDGE
				return

			_drop()
			return

		# nessun muro col ray: avanza…
		global_position = to_pos
		traveled += seg.length()

		# …e qui fai il vero "hitbox check" (spessore reale del proiettile)
		if _try_kill_at(global_position):
			return

	# perk: range
	if traveled >= (Constants.NULL_MAX_DISTANCE * Run.null_range_mult):
		_drop()


func _compute_substeps(step_len: float) -> int:
	# Substeps basati (in modo semplice) sul raggio della SphereShape e sulla scala:
	# così riduci i “pass-through” ad alta velocità e l’hit rispecchia quello che vedi.
	var base_r: float = 0.25
	if collision_shape != null and collision_shape.shape is SphereShape3D:
		base_r = (collision_shape.shape as SphereShape3D).radius

	var world_scale_x: float = 1.0
	# scala globale uniforme (il proiettile è uniforme)
	world_scale_x = global_transform.basis.get_scale().x

	var r: float = max(0.05, base_r * world_scale_x)
	var seg_len: float = max(MIN_SEGMENT_LEN, r * 0.75)

	return clampi(ceili(step_len / seg_len), 1, MAX_SUBSTEPS)


func _try_kill_at(pos: Vector3) -> bool:
	if collision_shape == null or collision_shape.shape == null:
		return false

	var w := get_world_3d()
	if w == null:
		return false

	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = collision_shape.shape

	var xform := global_transform
	xform.origin = pos
	params.transform = xform

	params.exclude = [get_rid()]
	params.collide_with_areas = false
	params.collide_with_bodies = true

	var hits: Array = w.direct_space_state.intersect_shape(params, 8)
	for h in hits:
		if typeof(h) != TYPE_DICTIONARY:
			continue
		var collider: Object = (h as Dictionary).get("collider", null)
		var enemy_node: Node = _find_enemy_node(collider)
		if enemy_node != null:
			Signals.enemy_killed.emit(enemy_node)
			Signals.null_ready_changed.emit(true)
			queue_free()
			return true

	return false


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
