# res://Enemies/enemy_bullet.gd
extends Area3D

@export var default_speed: float = 18.0
@export var default_life: float = 3.0
@export var owner_ignore_time: float = 0.12

var velocity: Vector3 = Vector3.ZERO
var life: float = 0.0

var shooter: Node = null
var _owner_ignore_left: float = 0.0
var _reflected: bool = false
var _spent: bool = false


func _ready() -> void:
	add_to_group("enemy_bullet")
	life = default_life
	monitoring = true
	monitorable = true


func fire(origin: Vector3, direction: Vector3, speed: float = -1.0, shooter_owner: Node = null) -> void:
	global_position = origin

	var dir: Vector3 = direction
	if dir.length() <= 0.001:
		dir = Vector3.FORWARD
	dir = dir.normalized()

	var final_speed: float = default_speed if speed <= 0.0 else speed

	velocity = dir * final_speed
	life = default_life
	shooter = shooter_owner
	_owner_ignore_left = owner_ignore_time if shooter_owner != null else 0.0
	_reflected = false
	_spent = false


func reflect(new_direction: Vector3, new_speed: float = -1.0) -> void:
	if _spent:
		return

	var dir: Vector3 = new_direction
	if dir.length() <= 0.001:
		return
	dir = dir.normalized()

	var final_speed: float = new_speed
	if final_speed <= 0.0:
		final_speed = maxf(velocity.length(), default_speed)

	velocity = dir * final_speed
	_reflected = true
	shooter = null
	_owner_ignore_left = 0.0


func is_reflected() -> bool:
	return _reflected


func get_speed() -> float:
	return velocity.length()


func _physics_process(delta: float) -> void:
	if _spent:
		return

	if _owner_ignore_left > 0.0:
		_owner_ignore_left = maxf(_owner_ignore_left - delta, 0.0)

	var from_pos: Vector3 = global_position
	var step: Vector3 = velocity * delta
	var to_pos: Vector3 = from_pos + step

	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from_pos, to_pos)
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var exclude: Array = [self]

	if shooter != null and is_instance_valid(shooter):
		exclude.append(shooter)

	# Bullet nemico: ignora tutti i nemici, può colpire solo player / world
	if not _reflected:
		for e in get_tree().get_nodes_in_group("enemy"):
			if e != null and is_instance_valid(e):
				exclude.append(e)
	# Bullet riflesso: ignora il player, può colpire i nemici
	else:
		for p in get_tree().get_nodes_in_group("player"):
			if p != null and is_instance_valid(p):
				exclude.append(p)

	query.exclude = exclude

	var hit: Dictionary = space.intersect_ray(query)
	if hit.size() > 0:
		var collider: Object = hit.get("collider", null)
		if _handle_body_hit(collider):
			return

		_consume()
		return

	global_position = to_pos

	life -= delta
	if life <= 0.0:
		_consume()


func _handle_body_hit(collider: Object) -> bool:
	if _spent:
		return true

	if collider == null:
		_consume()
		return true

	if collider == self:
		return false

	if shooter != null and collider == shooter and _owner_ignore_left > 0.0:
		return false

	if collider is Node:
		var node := collider as Node

		if node.is_in_group("player"):
			if _reflected:
				# bullet riflesso non deve più ferire il player
				return false

			var knock_dir: Vector3 = velocity.normalized()
			if knock_dir.length() <= 0.001:
				knock_dir = Vector3.FORWARD

			Signals.player_hit.emit(knock_dir)
			_consume()
			return true

		if node.is_in_group("enemy"):
			if not _reflected:
				# normalmente non dovrebbe succedere perché li escludiamo dal raycast
				return false

			Signals.enemy_killed.emit(node)
			_consume()
			return true

	# qualsiasi altra cosa = muro / ostacolo / ambiente
	_consume()
	return true


func _on_body_entered(body: Node) -> void:
	# Safety net nel caso il body_entered scatti prima/durante il raycast
	if _spent or body == null:
		return

	if shooter != null and body == shooter and _owner_ignore_left > 0.0:
		return

	if body.is_in_group("enemy") and not _reflected:
		return

	if body.is_in_group("player") and _reflected:
		return

	_handle_body_hit(body)


func _consume() -> void:
	if _spent:
		return

	_spent = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	set_physics_process(false)
	queue_free()
