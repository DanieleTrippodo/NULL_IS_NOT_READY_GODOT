# res://Enemies/Chaser.gd
extends CharacterBody3D

var target: Node3D = null

const GRAVITY: float = 25.0
const KILL_RADIUS: float = 1.0

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

	# gravità stabile
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -1.0

	move_and_slide()

	# kill solo in X/Z
	var dx := target.global_position.x - global_position.x
	var dz := target.global_position.z - global_position.z
	if (dx * dx + dz * dz) <= (KILL_RADIUS * KILL_RADIUS):
		Signals.player_died.emit()
