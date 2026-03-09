# res://Enemies/exception.gd
extends CharacterBody3D

var target: Node3D = null

const GRAVITY: float = 25.0

enum State {
	CHASE,
	GLITCH_AIM,
	RECOVER
}

# Kill / contatto
@export var kill_radius: float = 1.35

# Movimento base
@export var speed: float = 6.8
@export var jitter_strength: float = 0.28

# Teleport / glitch
@export var teleport_interval_min: float = 1.8
@export var teleport_interval_max: float = 3.0
@export var glitch_aim_time: float = 0.16
@export var recover_time: float = 0.14
@export var teleport_side_distance: float = 2.2
@export var teleport_forward_offset: float = 0.8
@export var teleport_min_player_distance: float = 2.2
@export var teleport_max_player_distance: float = 6.0
@export var teleport_trigger_distance: float = 8.5

var _teleport_t: float = 0.0
var _teleport_next: float = 2.2

# Stato
var _state: int = State.CHASE
var _state_time_left: float = 0.0

# Jitter
var _jitter_dir: Vector3 = Vector3.ZERO
var _jitter_t: float = 0.0

# Knockback
var _knock: Vector3 = Vector3.ZERO
@export var knock_decay: float = 22.0

# Glitch/flicker
@onready var _mesh: MeshInstance3D = $MeshInstance3D
var _glitch_t: float = 0.0

# PUSH / STUN
var _stun_left: float = 0.0

# Push collision combo
@export var push_collision_window: float = 0.28
@export var push_collision_min_speed: float = 3.0
@export var push_collision_knock_transfer: float = 0.65

var _push_collision_time_left: float = 0.0
var _push_collision_used: bool = false
var _last_push_stun: float = 0.0

# Flash
var _flash_mat: StandardMaterial3D
var _orig_override: Material = null


func _ready() -> void:
	_teleport_next = randf_range(teleport_interval_min, teleport_interval_max)


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

	# interrompe eventuale teleport/glitch
	_state = State.CHASE
	_state_time_left = 0.0
	_teleport_t = 0.0
	_teleport_next = randf_range(teleport_interval_min, teleport_interval_max)

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

		# self
		apply_impact_stun(impact_stun)

		# other
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
		_jitter_t = randf_range(0.06, 0.16)
		var a: float = randf_range(0.0, TAU)
		_jitter_dir = Vector3(cos(a), 0.0, sin(a))


func _enter_glitch_aim() -> void:
	_state = State.GLITCH_AIM
	_state_time_left = glitch_aim_time


func _enter_recover() -> void:
	_state = State.RECOVER
	_state_time_left = recover_time


func _try_teleport() -> void:
	if target == null:
		return

	var to_player: Vector3 = target.global_position - global_position
	to_player.y = 0.0
	var dist_to_player: float = to_player.length()

	if dist_to_player <= 0.001:
		return

	if dist_to_player > teleport_trigger_distance:
		return

	var forward: Vector3 = to_player.normalized()
	var side: Vector3 = Vector3(-forward.z, 0.0, forward.x)
	var side_sign: float = -1.0 if randf() < 0.5 else 1.0

	var candidate: Vector3 = target.global_position
	candidate += side * side_sign * teleport_side_distance
	candidate -= forward * teleport_forward_offset
	candidate.y = global_position.y

	var final_dist: float = candidate.distance_to(target.global_position)

	if final_dist < teleport_min_player_distance:
		candidate = target.global_position - forward * teleport_min_player_distance
		candidate += side * side_sign * (teleport_side_distance * 0.5)
		candidate.y = global_position.y
	elif final_dist > teleport_max_player_distance:
		candidate = target.global_position - forward * teleport_max_player_distance
		candidate += side * side_sign * (teleport_side_distance * 0.4)
		candidate.y = global_position.y

	global_position = candidate


func _update_visual(delta: float) -> void:
	_glitch_t += delta

	if not is_instance_valid(_mesh):
		return

	match _state:
		State.GLITCH_AIM:
			_mesh.visible = int(_glitch_t * 42.0) % 2 == 0
		State.RECOVER:
			_mesh.visible = int(_glitch_t * 30.0) % 6 != 0
		_:
			_mesh.visible = int(_glitch_t * 26.0) % 9 != 0


func _physics_process(delta: float) -> void:
	if _push_collision_time_left > 0.0:
		_push_collision_time_left = maxf(_push_collision_time_left - delta, 0.0)

	# STUN
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

	_teleport_t += delta

	var to_player: Vector3 = target.global_position - global_position
	to_player.y = 0.0

	var chase_dir: Vector3 = Vector3.ZERO
	if to_player.length() > 0.001:
		chase_dir = to_player.normalized()

	var move_dir: Vector3 = Vector3.ZERO
	var move_speed: float = 0.0

	match _state:
		State.CHASE:
			if chase_dir.length() > 0.001:
				move_dir = (chase_dir + _jitter_dir * jitter_strength).normalized()
			move_speed = speed

			if _teleport_t >= _teleport_next and to_player.length() <= teleport_trigger_distance:
				_enter_glitch_aim()

		State.GLITCH_AIM:
			_state_time_left -= delta
			move_dir = Vector3.ZERO
			move_speed = 0.0

			if _state_time_left <= 0.0:
				_try_teleport()
				_teleport_t = 0.0
				_teleport_next = randf_range(teleport_interval_min, teleport_interval_max)
				_enter_recover()

		State.RECOVER:
			_state_time_left -= delta
			move_dir = Vector3.ZERO
			move_speed = 0.0

			if _state_time_left <= 0.0:
				_state = State.CHASE
				_state_time_left = 0.0

	velocity.x = move_dir.x * move_speed + _knock.x
	velocity.z = move_dir.z * move_speed + _knock.z

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -1.0

	_knock = _knock.move_toward(Vector3.ZERO, knock_decay * delta)

	move_and_slide()

	_try_push_enemy_collision()

	# collision kill
	for i in range(get_slide_collision_count()):
		var col: KinematicCollision3D = get_slide_collision(i)
		var other := col.get_collider()
		if other is Node and (other as Node).is_in_group("player"):
			var away: Vector3 = ((other as Node3D).global_position - global_position).normalized()
			Signals.player_hit.emit(away)
			return

	# fallback radius
	if global_position.distance_to(target.global_position) <= kill_radius:
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
