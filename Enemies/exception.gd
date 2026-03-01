# res://Enemies/exception.gd
extends CharacterBody3D

var target: Node3D = null

const GRAVITY: float = 25.0
const KILL_RADIUS: float = 1.35

# Wander / imprevedibilità
var _wander: Vector3 = Vector3.ZERO
var _wander_t: float = 0.0

# Dash
var _dash_left: float = 0.0
var _dash_cd: float = 0.0
var _dash_dir: Vector3 = Vector3.ZERO

# Knockback
var _knock: Vector3 = Vector3.ZERO
@export var knock_decay: float = 18.0

# Glitch forte
@onready var _mesh: Node3D = $MeshInstance3D
var _glitch_t: float = 0.0

func set_target(t: Node3D) -> void:
	target = t

func add_knockback(v: Vector3) -> void:
	_knock += v

func _physics_process(delta: float) -> void:
	if target == null:
		return

	# glitch: flicker + micro-rotazioni
	_glitch_t += delta
	if _mesh != null:
		_mesh.visible = int(_glitch_t * 30.0) % 5 != 0
		_mesh.rotation.y += sin(_glitch_t * 22.0) * 0.002

	# refresh wander spesso
	_wander_t -= delta
	if _wander_t <= 0.0:
		_wander_t = randf_range(0.10, 0.22)
		var a := randf_range(0.0, TAU)
		_wander = Vector3(cos(a), 0.0, sin(a))

	# dash timers
	if _dash_cd > 0.0:
		_dash_cd -= delta
	if _dash_left > 0.0:
		_dash_left -= delta

	var to := (target.global_position - global_position)
	to.y = 0.0
	var chase_dir := to.normalized()

	# probabilità dash quando “vede” il player (semplice) e non è in cooldown
	if _dash_left <= 0.0 and _dash_cd <= 0.0:
		if randf() < 0.22: # “rare ma spesso abbastanza da spaventare”
			_dash_left = Constants.EXCEPTION_DASH_TIME
			_dash_cd = Constants.EXCEPTION_DASH_COOLDOWN
			# dash imprevedibile: verso player + wander forte
			_dash_dir = (chase_dir + _wander * 0.9).normalized()

	var move_dir := chase_dir
	var speed := Constants.EXCEPTION_SPEED

	if _dash_left > 0.0:
		move_dir = _dash_dir
		speed = Constants.EXCEPTION_DASH_SPEED
	else:
		# steer: inseguimento + wander medio
		move_dir = (chase_dir * 0.75 + _wander * 0.25).normalized()

	velocity.x = move_dir.x * speed + _knock.x
	velocity.z = move_dir.z * speed + _knock.z

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -1.0

	_knock = _knock.move_toward(Vector3.ZERO, knock_decay * delta)

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
