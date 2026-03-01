# res://Enemies/chaser.gd
extends CharacterBody3D

var target: Node3D = null

const GRAVITY: float = 25.0
const KILL_RADIUS: float = 1.25

# Knockback (per perk DROP_SHOCKWAVE)
var _knock: Vector3 = Vector3.ZERO
@export var knock_decay: float = 22.0

func set_target(t: Node3D) -> void:
	target = t

func add_knockback(v: Vector3) -> void:
	_knock += v

func _physics_process(delta: float) -> void:
	if target == null:
		return

	var to := (target.global_position - global_position)
	to.y = 0.0
	var dir := to.normalized()

	# movimento base + knockback
	velocity.x = dir.x * Constants.CHASER_SPEED + _knock.x
	velocity.z = dir.z * Constants.CHASER_SPEED + _knock.z

	# gravità
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -1.0

	# decay knockback
	_knock = _knock.move_toward(Vector3.ZERO, knock_decay * delta)

	move_and_slide()

	# kill on collision
	for i in range(get_slide_collision_count()):
		var col := get_slide_collision(i)
		var other := col.get_collider()
		if other is Node and (other as Node).is_in_group("player"):
			var away := ((other as Node3D).global_position - global_position).normalized()
			Signals.player_hit.emit(away)
			return

	# fallback distanza (in caso di collisioni “morbide”)
	if global_position.distance_to(target.global_position) <= KILL_RADIUS:
		var away2 := (target.global_position - global_position).normalized()
		Signals.player_hit.emit(away2)
