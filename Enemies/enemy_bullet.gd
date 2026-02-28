# res://Enemies/EnemyBullet.gd
extends Area3D

var velocity: Vector3 = Vector3.ZERO
var life: float = 3.0

func fire(origin: Vector3, direction: Vector3, speed: float = 18.0) -> void:
	global_position = origin
	velocity = direction.normalized() * speed
	life = 3.0

func _physics_process(delta: float) -> void:
	var from_pos: Vector3 = global_position
	var step: Vector3 = velocity * delta
	var to_pos: Vector3 = from_pos + step

	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from_pos, to_pos)
	query.exclude = [self]
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var hit: Dictionary = space.intersect_ray(query)
	if hit.size() > 0:
		var collider: Object = hit.get("collider", null)
		if collider is Node and (collider as Node).is_in_group("player"):
			# Knockback: away-from-enemy == direzione del proiettile
			Signals.player_hit.emit(velocity.normalized())
			queue_free()
			return

		queue_free()
		return

	global_position = to_pos

	life -= delta
	if life <= 0.0:
		queue_free()
