# res://Enemies/Chaser.gd
extends CharacterBody3D

var target: Node3D = null

const GRAVITY: float = 25.0
const KILL_RADIUS: float = 1.2 # fallback distanza

func set_target(t: Node3D) -> void:
	target = t

func _physics_process(delta: float) -> void:
	if target == null:
		return

	# movimento verso player (solo X/Z)
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

	# ✅ Kill affidabile: se ho colliso con il player
	for i in range(get_slide_collision_count()):
		var col := get_slide_collision(i)
		var other := col.get_collider()
		if other is Node and (other as Node).is_in_group("player"):
			Signals.player_died.emit()
			return

	# Fallback: usa distanza 3D (evita kill se il chaser viene sparato in aria)
	if global_position.distance_to(target.global_position) <= KILL_RADIUS:
		Signals.player_died.emit()
