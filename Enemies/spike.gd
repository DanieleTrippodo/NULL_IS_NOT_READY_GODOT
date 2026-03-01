# res://Enemies/spike.gd
extends CharacterBody3D

var target: Node3D = null

const GRAVITY: float = 25.0
const KILL_RADIUS: float = 1.25

# Movimento nervoso
var _jitter_dir: Vector3 = Vector3.ZERO
var _jitter_t: float = 0.0

# Dash
var _dash_left: float = 0.0
var _dash_cd: float = 0.0
var _dash_dir: Vector3 = Vector3.ZERO

# Knockback (perk shockwave)
var _knock: Vector3 = Vector3.ZERO
@export var knock_decay: float = 22.0

# Glitch (MVP)
@onready var _mesh: Node3D = $MeshInstance3D
var _glitch_t: float = 0.0

func set_target(t: Node3D) -> void:
	target = t

func add_knockback(v: Vector3) -> void:
	_knock += v

func _physics_process(delta: float) -> void:
	if target == null:
		return

	_glitch_t += delta
	if _mesh != null:
		# flicker leggero
		_mesh.visible = int(_glitch_t * 24.0) % 7 != 0

	# aggiorna jitter
	_jitter_t -= delta
	if _jitter_t <= 0.0:
		_jitter_t = randf_range(0.08, 0.18)
		var a := randf_range(0.0, TAU)
		_jitter_dir = Vector3(cos(a), 0.0, sin(a))

	# dash timers
	if _dash_cd > 0.0:
		_dash_cd -= delta
	if _dash_left > 0.0:
		_dash_left -= delta

	var to := (target.global_position - global_position)
	to.y = 0.0
	var chase_dir := to.normalized()

	# decide dash
	if _dash_left <= 0.0 and _dash_cd <= 0.0:
		_dash_left = Constants.SPIKE_DASH_TIME
		_dash_cd = Constants.SPIKE_DASH_COOLDOWN
		# dash “sporco”: verso player + jitter
		_dash_dir = (chase_dir + _jitter_dir * 0.65).normalized()

	var move_dir := chase_dir
	var speed := Constants.SPIKE_SPEED

	if _dash_left > 0.0:
		move_dir = _dash_dir
		speed = Constants.SPIKE_DASH_SPEED
	else:
		# nervoso: un po’ di jitter in corsa
		move_dir = (chase_dir + _jitter_dir * 0.35).normalized()

	# compone velocità
	velocity.x = move_dir.x * speed + _knock.x
	velocity.z = move_dir.z * speed + _knock.z

	# gravità
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -1.0

	# decay knockback
	_knock = _knock.move_toward(Vector3.ZERO, knock_decay * delta)

	move_and_slide()

	# collision kill (stesso pattern del chaser)
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
