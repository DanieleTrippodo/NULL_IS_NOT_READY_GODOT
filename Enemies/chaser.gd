# res://Enemies/Chaser.gd
extends CharacterBody3D

var target: Node3D = null

const GRAVITY: float = 25.0
const KILL_RADIUS: float = 1.2

func set_target(t: Node3D) -> void:
	target = t

func _physics_process(delta: float) -> void:
	if target == null:
		return

	var dir := (target.global_position - global_position)
	dir.y = 0.0
	dir = dir.normalized()

	velocity.x = dir.x * Constants.CHASER_SPEED
	velocity.z = dir.z * Constants.CHASER_SPEED

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -1.0

	move_and_slide()

	for i in range(get_slide_collision_count()):
		var col := get_slide_collision(i)
		var other := col.get_collider()
		if other is Node and (other as Node).is_in_group("player"):
			var away := ((other as Node3D).global_position - global_position).normalized()
			Signals.player_hit.emit(away)
			return

	if global_position.distance_to(target.global_position) <= KILL_RADIUS:
		var away2 := (target.global_position - global_position).normalized()
		Signals.player_hit.emit(away2)
