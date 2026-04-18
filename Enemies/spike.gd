# res://Enemies/spike.gd
extends CharacterBody3D

var target: Node3D = null

const GRAVITY: float = 25.0
const KILL_RADIUS: float = 1.25

enum State {
	CHASE,
	AIM,
	DASH,
	RECOVER
}

var _state: int = State.CHASE
var _state_time_left: float = 0.0

# Movimento nervoso
var _jitter_dir: Vector3 = Vector3.ZERO
var _jitter_t: float = 0.0

# Dash
var _dash_dir: Vector3 = Vector3.ZERO
var _dash_cd: float = 0.0

# Knockback
var _knock: Vector3 = Vector3.ZERO
@export var knock_decay: float = 22.0

# Push / stun
var _stun_left: float = 0.0

# Push collision combo
@export var push_collision_window: float = 0.28
@export var push_collision_min_speed: float = 3.0
@export var push_collision_knock_transfer: float = 0.65

var _push_collision_time_left: float = 0.0
var _push_collision_used: bool = false
var _last_push_stun: float = 0.0

# Telegraph / timings
@export var aim_time: float = 0.18
@export var recover_time: float = 0.18
@export var chase_repath_time_min: float = 0.04
@export var chase_repath_time_max: float = 0.10
@export var aim_glitch_flash_speed: float = 42.0

# Glitch visivo
@onready var _mesh: MeshInstance3D = $MeshInstance3D
@onready var sprite: AnimatedSprite3D = $AnimatedSprite3D
var _glitch_t: float = 0.0

# Flash (on hit)
var _flash_mat: StandardMaterial3D
var _orig_override: Material = null


func _ready() -> void:
	sprite.play("walk")

func set_target(t: Node3D) -> void:
	target = t


func add_knockback(v: Vector3) -> void:
	_knock += v


func apply_push(forward: Vector3, strength: float, lift: float, stun_seconds: float) -> void:
	_stun_left = maxf(_stun_left, stun_seconds)

	var dir: Vector3 = forward
	dir.y = 0.0
	if dir.length() > 0.001:
		dir = dir.normalized()

	_knock += dir * strength
	velocity.y = maxf(velocity.y, lift)

	_last_push_stun = stun_seconds
	_push_collision_time_left = push_collision_window
	_push_collision_used = false

	# se lo pushi mentre prepara il dash o sta recoverando, interrompe lo stato
	_state = State.CHASE
	_state_time_left = 0.0
	_dash_cd = maxf(_dash_cd, 0.12)

	_do_flash()


func apply_impact_stun(stun_seconds: float, impact_dir: Vector3 = Vector3.ZERO, impact_knock: float = 0.0) -> void:
	_stun_left = maxf(_stun_left, stun_seconds)

	if impact_dir.length() > 0.001 and impact_knock > 0.0:
		var flat_dir: Vector3 = impact_dir
		flat_dir.y = 0.0
		if flat_dir.length() > 0.001:
			_knock += flat_dir.normalized() * impact_knock

	_push_collision_time_left = 0.0
	_push_collision_used = true

	_state = State.CHASE
	_state_time_left = 0.0

	_do_flash()


func _try_push_enemy_collision() -> void:
	if _push_collision_used:
		return

	if _push_collision_time_left <= 0.0:
		return

	var flat_speed: float = Vector3(velocity.x, 0.0, velocity.z).length()
	if flat_speed < push_collision_min_speed:
		return

	for i in range(get_slide_collision_count()):
		var col: KinematicCollision3D = get_slide_collision(i)
		var other := col.get_collider()

		if other == null or other == self:
			continue
		if not (other is Node):
			continue
		if not (other as Node).is_in_group("enemy"):
			continue

		var impact_stun: float = _last_push_stun * 2.0
		var impact_dir: Vector3 = Vector3(velocity.x, 0.0, velocity.z)

		if impact_dir.length() <= 0.001 and other is Node3D:
			impact_dir = global_position - (other as Node3D).global_position

		apply_impact_stun(impact_stun)

		if other.has_method("apply_impact_stun"):
			other.apply_impact_stun(
				impact_stun,
				impact_dir,
				Vector3(velocity.x, 0.0, velocity.z).length() * push_collision_knock_transfer
			)
		elif other.has_method("apply_push"):
			other.apply_push(
				impact_dir.normalized(),
				Vector3(velocity.x, 0.0, velocity.z).length() * push_collision_knock_transfer,
				0.0,
				impact_stun
			)

		break


func _update_jitter(delta: float) -> void:
	_jitter_t -= delta
	if _jitter_t <= 0.0:
		_jitter_t = randf_range(chase_repath_time_min, chase_repath_time_max)
		var a: float = randf_range(0.0, TAU)
		_jitter_dir = Vector3(cos(a), 0.0, sin(a))


func _enter_aim(chase_dir: Vector3) -> void:
	_state = State.AIM
	_state_time_left = aim_time
	_dash_dir = chase_dir


func _enter_dash() -> void:
	_state = State.DASH
	_state_time_left = Constants.SPIKE_DASH_TIME


func _enter_recover() -> void:
	_state = State.RECOVER
	_state_time_left = recover_time
	_dash_cd = Constants.SPIKE_DASH_COOLDOWN


func _update_visual(delta: float) -> void:
	_glitch_t += delta

	if not is_instance_valid(_mesh):
		return

	match _state:
		State.AIM:
			# più visibile e “nervoso” mentre telegraph-a
			_mesh.visible = int(_glitch_t * aim_glitch_flash_speed) % 2 == 0
		State.DASH:
			# durante il dash quasi sempre visibile
			_mesh.visible = int(_glitch_t * 30.0) % 9 != 0
		_:
			# flicker leggero normale
			_mesh.visible = int(_glitch_t * 24.0) % 7 != 0


func _physics_process(delta: float) -> void:
	if _push_collision_time_left > 0.0:
		_push_collision_time_left = maxf(_push_collision_time_left - delta, 0.0)

	# STUN: niente AI / niente dash decision, ma knockback + gravità attivi
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

		_try_push_enemy_collision()
		return

	if target == null:
		return

	_update_visual(delta)
	_update_jitter(delta)

	if _dash_cd > 0.0:
		_dash_cd = maxf(_dash_cd - delta, 0.0)

	var to: Vector3 = target.global_position - global_position
	to.y = 0.0

	var chase_dir: Vector3 = Vector3.ZERO
	if to.length() > 0.001:
		chase_dir = to.normalized()

	var move_dir: Vector3 = Vector3.ZERO
	var speed: float = 0.0

	match _state:
		State.CHASE:
			if chase_dir.length() > 0.001:
				move_dir = (chase_dir + _jitter_dir * 0.18).normalized()
			speed = Constants.SPIKE_SPEED * 1.35

			# prepara il dash da più lontano
			if _dash_cd <= 0.0 and to.length() <= 11.0 and chase_dir.length() > 0.001:
				_enter_aim(chase_dir)

		State.AIM:
			_state_time_left -= delta
			move_dir = Vector3.ZERO
			speed = 0.0

			# durante aim blocca la direzione del dash
			if chase_dir.length() > 0.001:
				_dash_dir = chase_dir

			if _state_time_left <= 0.0:
				_enter_dash()

		State.DASH:
			_state_time_left -= delta
			move_dir = _dash_dir
			speed = Constants.SPIKE_DASH_SPEED

			if _state_time_left <= 0.0:
				_enter_recover()

		State.RECOVER:
			_state_time_left -= delta
			move_dir = Vector3.ZERO
			speed = 0.0

			if _state_time_left <= 0.0:
				_state = State.CHASE
				_state_time_left = 0.0

	# velocità
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

	_try_push_enemy_collision()

	# se sbatte in dash contro qualcosa, finisce in recover
	if _state == State.DASH and get_slide_collision_count() > 0:
		for i in range(get_slide_collision_count()):
			var dash_col: KinematicCollision3D = get_slide_collision(i)
			var dash_other := dash_col.get_collider()
			if dash_other is Node and not (dash_other as Node).is_in_group("player"):
				_enter_recover()
				break

	# collision kill col player
	for i in range(get_slide_collision_count()):
		var col: KinematicCollision3D = get_slide_collision(i)
		var other := col.get_collider()
		if other is Node and (other as Node).is_in_group("player"):
			var away: Vector3 = ((other as Node3D).global_position - global_position).normalized()
			Signals.player_hit.emit(away)
			return

	# fallback distanza
	if global_position.distance_to(target.global_position) <= KILL_RADIUS:
		var away2: Vector3 = (target.global_position - global_position).normalized()
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
