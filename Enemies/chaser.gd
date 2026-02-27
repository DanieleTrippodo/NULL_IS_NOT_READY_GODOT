# res://Enemies/Chaser.gd
extends CharacterBody3D

var target: Node3D = null

func set_target(t: Node3D) -> void:
	target = t

func _physics_process(_delta: float) -> void:
	if target == null:
		return

	var dir := (target.global_position - global_position)
	dir.y = 0.0
	dir = dir.normalized()

	var speed := Constants.CHASER_SPEED
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	move_and_slide()

	# MVP: contatto = morte
	if global_position.distance_to(target.global_position) <= 1.0:
		Signals.player_died.emit()
