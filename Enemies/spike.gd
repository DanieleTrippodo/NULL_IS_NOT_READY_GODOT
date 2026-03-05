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

# Knockback (perk shockwave + push melee)
var _knock: Vector3 = Vector3.ZERO
@export var knock_decay: float = 22.0

# Glitch (MVP)
@onready var _mesh: MeshInstance3D = $MeshInstance3D
var _glitch_t: float = 0.0

# PUSH / STUN
var _stun_left: float = 0.0

# Flash (on hit)
var _flash_mat: StandardMaterial3D
var _orig_override: Material = null

func set_target(t: Node3D) -> void:
	target = t

func add_knockback(v: Vector3) -> void:
	_knock += v

# Chiamata dal Player (RMB push)
func apply_push(forward: Vector3, strength: float, lift: float, stun_seconds: float) -> void:
	_stun_left = maxf(_stun_left, stun_seconds)

	var dir := forward
	dir.y = 0.0
	if dir.length() > 0.001:
		dir = dir.normalized()

	_knock += dir * strength
	velocity.y = maxf(velocity.y, lift)

	_do_flash()

func _physics_process(delta: float) -> void:
	# STUN: freeze totale (niente AI / niente glitch / niente kill)
	# Però knockback + gravità devono continuare (così il push si vede).
	if _stun_left > 0.0:
		_stun_left = maxf(_stun_left - delta, 0.0)

		if is_instance_valid(_mesh):
			_mesh.visible = true

		velocity.x = _knock.x
		velocity.z = _knock.z

		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		else:
			velocity.y = -1.0

		_knock = _knock.move_toward(Vector3.ZERO, knock_decay * delta)
		move_and_slide()
		return

	if target == null:
		return

	_glitch_t += delta
	if is_instance_valid(_mesh):
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

func _do_flash() -> void:
	if not is_instance_valid(_mesh):
		return

	if _flash_mat == null:
		_flash_mat = StandardMaterial3D.new()
		_flash_mat.emission_enabled = true
		_flash_mat.emission = Color(1, 1, 1)
		_flash_mat.albedo_color = Color(1, 1, 1)
		_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	if _orig_override == null:
		_orig_override = _mesh.material_override

	_mesh.visible = true
	_mesh.material_override = _flash_mat

	await get_tree().create_timer(0.08).timeout
	if is_instance_valid(_mesh):
		_mesh.material_override = _orig_override
