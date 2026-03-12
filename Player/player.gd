# res://Player/player.gd
extends CharacterBody3D

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera

@onready var body_sprite: Sprite3D = $Body
@onready var body_down_sprite: Sprite3D = $Body_Down
@onready var left_arm_push: AnimatedSprite3D = $Head/Camera/ViewModel/LeftArmPush
@onready var hand_recovery: Sprite3D = $Head/Camera/ViewModel/HandRecovery
@onready var hand: Sprite3D = $Head/Camera/ViewModel/Hand
@onready var shoot_ring: Sprite3D = $Head/Camera/ViewModel/ShootRing

enum PState { NORMAL, KNOCKBACK, DOWNED }

# -------------------------
# CAMERA LIMITS
# -------------------------
@export_range(0.0, 89.0, 0.5) var normal_pitch_limit_deg: float = 85.0
@export_range(0.0, 89.0, 0.5) var downed_pitch_limit_deg: float = 25.0

# -------------------------
# KNOCKBACK / DOWNED
# -------------------------
# (Legacy) lasciato per compatibilità Inspector; non è usato direttamente
@export var knockback_strength: float = 14.0
@export var knockback_gravity_start: float = 7.0
@export var knockback_gravity_max: float = 20.0
@export var knockback_gravity_accel: float = 32.0
@export var knockback_lift: float = 9.0
@export var knockback_speed: float = 22.0
@export var knockback_drag_air: float = 6.0
@export var knockback_drag_ground: float = 10.0
@export var knockback_max_step: float = 6.0 # clamp anti-scatto (valore più alto = meno clamp)

@export var downed_cam_offset_y: float = -0.75
@export var downed_cam_lerp_speed: float = 10.0
@export var downed_cam_return_speed: float = 12.0
@export var knockback_min_time: float = 0.22
@export var downed_invuln_seconds: float = 0.5

# -------------------------
# PUSH (RMB)
# -------------------------
@export var push_range: float = 2.5
@export var push_cone_deg: float = 90.0
@export var push_cooldown: float = 1.0

# “medio” (valori iniziali, poi li ritocchiamo)
@export var push_strength: float = 14.0
@export var push_lift: float = 6.0
@export var push_stun_seconds: float = 1

var _push_cd_left: float = 0.0

@onready var push_sfx: AudioStreamPlayer3D = $PushSfx

@export_group("Recovery Hand Anim")
@export var hand_recovery_enter_offset_y: float = -0.22
@export var hand_recovery_enter_time: float = 0.14

var _hand_recovery_default_pos: Vector3
var _hand_recovery_tween: Tween

@export_group("External Push")
@export var external_push_decay_ground: float = 8.0
@export var external_push_decay_air: float = 5.0

var _external_push: Vector3 = Vector3.ZERO

var _camera_base_y: float = 0.0

var state: int = PState.NORMAL
var input_locked: bool = false
var is_recovering_null: bool = false

# input camera
var yaw: float = 0.0
var pitch: float = 0.0

# charge shot
var _charging: bool = false
var _charge_time: float = 0.0

# camera base pos (per abbassamento downed)
var _cam_normal_pos: Vector3
var _cam_base_pos: Vector3

# timers interni
var _knock_t: float = 0.0
var _downed_invuln_t: float = 0.0
var _knockback_gravity_current: float = 0.0

const GRAVITY: float = 20.0

# Perk-based inputs presence
var has_fly_down: bool = false
var has_dash: bool = false
var has_swap: bool = false

# Dash (perk)
var dash_cd: float = 0.0
var dash_time_left: float = 0.0
var dash_vel: Vector3 = Vector3.ZERO

const DASH_DURATION: float = 0.12
const DASH_COOLDOWN: float = 0.9
const DASH_STRENGTH: float = 14.0

@export_group("Hand Bob")
@export var hand_bob_enabled: bool = true
@export_range(0.0, 20.0, 0.1) var hand_bob_speed: float = 10.0
@export_range(0.0, 0.2, 0.001) var hand_bob_amp_x: float = 0.012
@export_range(0.0, 0.2, 0.001) var hand_bob_amp_y: float = 0.014
@export_range(0.0, 10.0, 0.1) var hand_bob_rot_z_deg: float = 2.0

@export_group("Hand Idle")
@export var hand_idle_enabled: bool = true
@export_range(0.0, 10.0, 0.1) var hand_idle_speed: float = 1.6
@export_range(0.0, 0.05, 0.0005) var hand_idle_amp_y: float = 0.006
@export_range(0.0, 5.0, 0.1) var hand_idle_rot_z_deg: float = 0.6

@export_group("Hand Sway")
@export var hand_sway_enabled: bool = true
@export_range(0.0, 0.1, 0.0005) var hand_sway_pos_amount: float = 0.012
@export_range(0.0, 20.0, 0.1) var hand_sway_rot_deg: float = 4.0
@export_range(0.0, 30.0, 0.1) var hand_sway_return_speed: float = 10.0

@export_group("Body Idle")
@export var body_idle_enabled: bool = true
@export_range(0.0, 10.0, 0.1) var body_idle_speed: float = 1.5
@export_range(0.0, 0.1, 0.0005) var body_idle_amp_y: float = 0.01
@export_range(0.0, 10.0, 0.1) var body_idle_rot_deg: float = 0.8

@export_group("Body Walk")
@export var body_walk_enabled: bool = true
@export_range(0.0, 20.0, 0.1) var body_walk_speed: float = 7.0
@export_range(0.0, 0.1, 0.0005) var body_walk_amp_x: float = 0.008
@export_range(0.0, 0.1, 0.0005) var body_walk_amp_y: float = 0.012
@export_range(0.0, 10.0, 0.1) var body_walk_rot_deg: float = 1.2

var _hand_base_pos: Vector3 = Vector3.ZERO
var _hand_base_rot: Vector3 = Vector3.ZERO
var _hand_tween: Tween
var _hand_bob_t: float = 0.0
var _hand_look_input: Vector2 = Vector2.ZERO
var _hand_sway_pos: Vector3 = Vector3.ZERO
var _hand_sway_rot: Vector3 = Vector3.ZERO
var _hand_idle_t: float = 0.0

var _body_base_pos: Vector3 = Vector3.ZERO
var _body_base_rot: Vector3 = Vector3.ZERO
var _body_base_scale: Vector3 = Vector3.ONE
var _body_idle_t: float = 0.0
var _body_walk_t: float = 0.0

var _shoot_ring_base_scale: Vector3 = Vector3.ONE
var _shoot_ring_tween: Tween

func _ready() -> void:
	_camera_base_y = $Head/Camera.position.y
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	set_process_unhandled_input(true)
	set_process(true)

	if hand_recovery != null:
		_hand_recovery_default_pos = hand_recovery.position

	_update_hand_mode_visual()

	add_to_group("player")

	_cam_normal_pos = camera.position
	_cam_base_pos = camera.position

	has_fly_down = InputMap.has_action("fly_down")
	has_dash = InputMap.has_action("dash")
	has_swap = InputMap.has_action("swap")

	Signals.player_hit.connect(_on_player_hit)
	Signals.enemy_killed.connect(_on_enemy_killed)

	_set_body_downed(false)

	if is_instance_valid(hand):
		_hand_base_pos = hand.position
		_hand_base_rot = hand.rotation

	if is_instance_valid(body_sprite):
		_body_base_pos = body_sprite.position
		_body_base_rot = body_sprite.rotation
		_body_base_scale = body_sprite.scale

	if is_instance_valid(shoot_ring):
		_shoot_ring_base_scale = shoot_ring.scale
		shoot_ring.visible = false
		shoot_ring.modulate = Color(1, 1, 1, 1)

func _unhandled_input(event: InputEvent) -> void:
	if input_locked:
		return

	if is_recovering_null:
		if event.is_action_released("swap"):
			is_recovering_null = false
			_update_hand_mode_visual()
			Signals.request_recovery_stop.emit()
		return

	# mouse look sempre abilitato (anche in downed)
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_hand_look_input = event.relative

		yaw -= event.relative.x * Settings.mouse_sens
		pitch -= event.relative.y * Settings.mouse_sens

		var limit_deg: float = normal_pitch_limit_deg
		if state == PState.DOWNED:
			limit_deg = downed_pitch_limit_deg
		pitch = clamp(pitch, deg_to_rad(-limit_deg), deg_to_rad(limit_deg))

		rotation.y = yaw
		head.rotation.x = pitch

	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if state == PState.KNOCKBACK:
		return

	if event.is_action_pressed("push"):
		_try_push()

	# In KNOCKBACK: niente sparo
	if state == PState.KNOCKBACK:
		return

	# DOWNED: puoi sparare ma senza perk
	if state == PState.DOWNED:
		if event.is_action_pressed("swap"):
			if Run.null_dropped:
				is_recovering_null = true
				_update_hand_mode_visual()
				_play_hand_recovery_enter_anim()
				Signals.request_recovery_start.emit()
			elif has_swap:
				Signals.request_swap.emit()

		if event.is_action_released("swap"):
			if is_recovering_null:
				is_recovering_null = false
				_update_hand_mode_visual()
				Signals.request_recovery_stop.emit()

		if event.is_action_pressed("interact"):
			Signals.request_pickup.emit()

		if event.is_action_pressed("shoot"):
			if Run.null_ready:
				var origin_d: Vector3 = camera.global_transform.origin
				var dir_d: Vector3 = -camera.global_transform.basis.z
				_play_hand_shoot_anim()
				_play_shoot_ring_fx()
				Signals.request_shoot.emit(origin_d, dir_d, 1.0)

		return

	# NORMAL
	if Run.charge_shot_enabled:
		if event.is_action_pressed("shoot"):
			if Run.null_ready:
				_charging = true
				_charge_time = 0.0
		elif event.is_action_released("shoot"):
			if _charging:
				_charging = false
				var origin2: Vector3 = camera.global_transform.origin
				var dir2: Vector3 = -camera.global_transform.basis.z
				var size_mult: float = 1.0
				if _charge_time >= Run.charge_shot_seconds:
					size_mult = Run.charge_shot_scale
				_play_hand_shoot_anim()
				_play_shoot_ring_fx()
				Signals.request_shoot.emit(origin2, dir2, size_mult)
	else:
		if event.is_action_pressed("shoot"):
			var origin3: Vector3 = camera.global_transform.origin
			var dir3: Vector3 = -camera.global_transform.basis.z
			_play_hand_shoot_anim()
			_play_shoot_ring_fx()
			Signals.request_shoot.emit(origin3, dir3, 1.0)

	if event.is_action_pressed("interact"):
		Signals.request_pickup.emit()

	# SWAP (perk)
	if event.is_action_pressed("swap"):
		if Run.null_dropped:
			is_recovering_null = true
			_update_hand_mode_visual()
			_play_hand_recovery_enter_anim()
			Signals.request_recovery_start.emit()
		elif has_swap:
			Signals.request_swap.emit()

	if event.is_action_released("swap"):
		if is_recovering_null:
			is_recovering_null = false
			_update_hand_mode_visual()
			Signals.request_recovery_stop.emit()

func set_input_locked(v: bool) -> void:
	input_locked = v
	if input_locked:
		_charging = false
		_charge_time = 0.0

func _update_hand_mode_visual() -> void:
	if hand != null:
		hand.visible = not is_recovering_null

	if hand_recovery != null:
		if not is_recovering_null:
			hand_recovery.visible = false
			hand_recovery.position = _hand_recovery_default_pos

func _play_hand_recovery_enter_anim() -> void:
	if hand_recovery == null:
		return

	if is_instance_valid(_hand_recovery_tween):
		_hand_recovery_tween.kill()

	hand_recovery.position = _hand_recovery_default_pos + Vector3(0.0, hand_recovery_enter_offset_y, 0.0)
	hand_recovery.visible = true

	_hand_recovery_tween = create_tween()
	_hand_recovery_tween.set_trans(Tween.TRANS_QUAD)
	_hand_recovery_tween.set_ease(Tween.EASE_OUT)
	_hand_recovery_tween.tween_property(
		hand_recovery,
		"position",
		_hand_recovery_default_pos,
		hand_recovery_enter_time
	)

	if hand_recovery != null:
		hand_recovery.visible = is_recovering_null

func force_drop_null() -> void:
	if not Run.null_ready:
		return

	_charging = false
	_charge_time = 0.0

	var drop_pos: Vector3 = global_position + Vector3(0.0, 0.35, 0.0)
	Signals.request_force_drop_null.emit(drop_pos)

func apply_external_push(dir: Vector3, strength: float, lift: float = 0.0) -> void:
	var flat_dir: Vector3 = dir
	flat_dir.y = 0.0

	if flat_dir.length() < 0.001:
		flat_dir = -global_transform.basis.z
	else:
		flat_dir = flat_dir.normalized()

	_external_push += flat_dir * strength

	if lift > 0.0:
		velocity.y = maxf(velocity.y, lift)

func _process(delta: float) -> void:
	if Run.charge_shot_enabled and _charging and not Run.survival_mode:
		_charge_time += delta

	_update_hand_effects(delta)
	_update_body_effects(delta)

func _physics_process(delta: float) -> void:
	if state == PState.KNOCKBACK:
		_knock_t += delta
	if state == PState.DOWNED:
		_downed_invuln_t = maxf(_downed_invuln_t - delta, 0.0)

	dash_cd = maxf(dash_cd - delta, 0.0)
	dash_time_left = maxf(dash_time_left - delta, 0.0)
	_push_cd_left = maxf(_push_cd_left - delta, 0.0)

	if is_recovering_null:
		velocity.x = _external_push.x
		velocity.z = _external_push.z

		if is_on_floor():
			velocity.y = -1.0
		else:
			velocity.y -= GRAVITY * delta

		var push_decay_recovery: float = external_push_decay_ground if is_on_floor() else external_push_decay_air
		_external_push = _external_push.move_toward(Vector3.ZERO, push_decay_recovery * delta)

		move_and_slide()
		_update_downed_camera(delta)
		return

	if input_locked:
		velocity.x = _external_push.x
		velocity.z = _external_push.z

		if is_on_floor():
			velocity.y = -1.0
		else:
			velocity.y -= GRAVITY * delta

		var push_decay_locked: float = external_push_decay_ground if is_on_floor() else external_push_decay_air
		_external_push = _external_push.move_toward(Vector3.ZERO, push_decay_locked * delta)

		move_and_slide()
		_update_downed_camera(delta)
		return

	match state:
		PState.NORMAL:
			_physics_normal(delta)
		PState.KNOCKBACK:
			_physics_knockback(delta)
		PState.DOWNED:
			_physics_downed(delta)

	_update_downed_camera(delta)

func _physics_normal(delta: float) -> void:
	var input_dir: Vector3 = Vector3.ZERO
	if Input.is_action_pressed("move_forward"):
		input_dir.z -= 1.0
	if Input.is_action_pressed("move_back"):
		input_dir.z += 1.0
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1.0
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1.0
	input_dir = input_dir.normalized()

	var dir: Vector3 = transform.basis * input_dir
	dir.y = 0.0
	dir = dir.normalized()

	var speed: float = Constants.PLAYER_SPEED * Run.move_speed_mult
	if not is_on_floor():
		speed *= Run.air_speed_mult

	velocity.x = dir.x * speed + _external_push.x
	velocity.z = dir.z * speed + _external_push.z

	if Run.dash_enabled and has_dash and dash_cd <= 0.0 and Input.is_action_just_pressed("dash"):
		var fwd: Vector3 = -global_transform.basis.z
		fwd.y = 0.0
		fwd = fwd.normalized()
		dash_vel = fwd * DASH_STRENGTH
		dash_time_left = DASH_DURATION
		dash_cd = DASH_COOLDOWN

	if dash_time_left > 0.0:
		velocity.x += dash_vel.x
		velocity.z += dash_vel.z

	var flying: bool = Run.flight_time_left > 0.0
	if flying:
		Run.flight_time_left = maxf(Run.flight_time_left - delta, 0.0)

		var vy: float = 0.0
		if Input.is_action_pressed("jump"):
			vy = Run.jump_velocity
		elif has_fly_down and Input.is_action_pressed("fly_down"):
			vy = -Run.jump_velocity
		velocity.y = vy
	else:
		if is_on_floor():
			if Run.jump_enabled and Input.is_action_just_pressed("jump"):
				velocity.y = Run.jump_velocity
			else:
				velocity.y = -1.0
		else:
			velocity.y -= GRAVITY * delta

	var push_decay: float = external_push_decay_ground if is_on_floor() else external_push_decay_air
	_external_push = _external_push.move_toward(Vector3.ZERO, push_decay * delta)

	move_and_slide()

func _physics_knockback(delta: float) -> void:
	_external_push = _external_push.move_toward(Vector3.ZERO, knockback_drag_ground * delta)

	var drag: float = knockback_drag_air
	if is_on_floor():
		drag = knockback_drag_ground

	velocity.x = move_toward(velocity.x, 0.0, drag * delta)
	velocity.z = move_toward(velocity.z, 0.0, drag * delta)

	if is_on_floor():
		velocity.y = -1.0
	else:
		_knockback_gravity_current = minf(
			_knockback_gravity_current + knockback_gravity_accel * delta,
			knockback_gravity_max
		)
		velocity.y -= _knockback_gravity_current * delta

	var h: Vector2 = Vector2(velocity.x, velocity.z)
	var max_h: float = knockback_max_step / maxf(delta, 0.001)
	if h.length() > max_h:
		h = h.normalized() * max_h
		velocity.x = h.x
		velocity.z = h.y

	move_and_slide()

	if is_on_floor() and _knock_t >= knockback_min_time:
		_enter_downed()

func _physics_downed(delta: float) -> void:
	velocity.x = _external_push.x
	velocity.z = _external_push.z

	if is_on_floor():
		velocity.y = -1.0
	else:
		velocity.y -= GRAVITY * delta

	var push_decay: float = external_push_decay_ground if is_on_floor() else external_push_decay_air
	_external_push = _external_push.move_toward(Vector3.ZERO, push_decay * delta)

	move_and_slide()

func _on_player_hit(knockback_dir: Vector3) -> void:
	if is_recovering_null:
		is_recovering_null = false
		_update_hand_mode_visual()
		Signals.request_recovery_stop.emit()

	if state == PState.KNOCKBACK:
		return

	if state == PState.DOWNED:
		if _downed_invuln_t > 0.0:
			return
		Signals.player_died.emit()
		return

	_charging = false
	_charge_time = 0.0
	_external_push = Vector3.ZERO

	state = PState.KNOCKBACK
	_knock_t = 0.0
	_knockback_gravity_current = knockback_gravity_start

	var dir: Vector3 = knockback_dir
	if dir.length() < 0.001:
		dir = -global_transform.basis.z
	dir = dir.normalized()

	velocity.x += dir.x * knockback_speed
	velocity.z += dir.z * knockback_speed
	velocity.y = maxf(velocity.y, knockback_lift)

func _enter_downed() -> void:
	state = PState.DOWNED
	Run.survival_mode = true
	_downed_invuln_t = downed_invuln_seconds

	_set_body_downed(true)
	Signals.survival_mode_changed.emit(true)

func _exit_downed() -> void:
	state = PState.NORMAL
	Run.survival_mode = false
	_downed_invuln_t = 0.0

	_set_body_downed(false)
	Signals.survival_mode_changed.emit(false)

func _set_body_downed(downed: bool) -> void:
	if body_sprite:
		body_sprite.visible = not downed
	if body_down_sprite:
		body_down_sprite.visible = downed

func _on_enemy_killed(_enemy: Node) -> void:
	if state == PState.DOWNED:
		_exit_downed()

func _try_push() -> void:
	if _push_cd_left > 0.0:
		return

	_push_cd_left = push_cooldown
	_play_push_anim()

	var cam_origin: Vector3 = camera.global_transform.origin

	# Forward reale della camera (serve per riflettere i bullet dove guarda il player)
	var full_fwd: Vector3 = -camera.global_transform.basis.z
	if full_fwd.length() < 0.001:
		return
	full_fwd = full_fwd.normalized()

	# Forward sul piano XZ (manteniamo il push dei nemici come prima)
	var flat_fwd: Vector3 = full_fwd
	flat_fwd.y = 0.0
	if flat_fwd.length() < 0.001:
		flat_fwd = Vector3(full_fwd.x, 0.0, full_fwd.z)
		if flat_fwd.length() < 0.001:
			flat_fwd = -global_transform.basis.z
			flat_fwd.y = 0.0
			if flat_fwd.length() < 0.001:
				return
	flat_fwd = flat_fwd.normalized()

	var half_angle_rad: float = deg_to_rad(push_cone_deg * 0.5)
	var cos_limit: float = cos(half_angle_rad)

	var any_hit: bool = false

	# -------------------------
	# PUSH SUI NEMICI
	# -------------------------
	for e in get_tree().get_nodes_in_group("enemy"):
		if not (e is Node3D):
			continue

		var en: Node3D = e as Node3D
		var to: Vector3 = en.global_position - global_position

		if to.length() > push_range:
			continue

		to.y = 0.0
		if to.length() < 0.001:
			continue

		var dir_to: Vector3 = to.normalized()
		if flat_fwd.dot(dir_to) < cos_limit:
			continue

		if e.has_method("apply_push"):
			e.apply_push(flat_fwd, push_strength, push_lift, push_stun_seconds)
			any_hit = true

	# -------------------------
	# PUSH SUI PROIETTILI NEMICI
	# -------------------------
	for b in get_tree().get_nodes_in_group("enemy_bullet"):
		if not (b is Node3D):
			continue

		var bullet: Node3D = b as Node3D
		var to_bullet: Vector3 = bullet.global_position - cam_origin
		var dist: float = to_bullet.length()

		if dist > push_range:
			continue

		if dist < 0.001:
			continue

		var dir_to_bullet: Vector3 = to_bullet.normalized()
		if full_fwd.dot(dir_to_bullet) < cos_limit:
			continue

		if b.has_method("reflect"):
			var reflected_speed: float = 0.0

			if b.has_method("get_speed"):
				reflected_speed = b.get_speed()

			b.reflect(full_fwd, reflected_speed)
			any_hit = true

	if any_hit and is_instance_valid(push_sfx):
		push_sfx.play()

func _play_push_anim() -> void:
	if not is_instance_valid(left_arm_push):
		return

	left_arm_push.visible = true
	left_arm_push.stop()
	left_arm_push.play("push")

	await left_arm_push.animation_finished

	if is_instance_valid(left_arm_push):
		left_arm_push.visible = false

func _update_hand_effects(delta: float) -> void:
	if not is_instance_valid(hand):
		return

	if is_instance_valid(_hand_tween) and _hand_tween.is_running():
		_hand_look_input = _hand_look_input.lerp(Vector2.ZERO, delta * hand_sway_return_speed)
		return

	var target_pos: Vector3 = _hand_base_pos
	var target_rot: Vector3 = _hand_base_rot

	if hand_idle_enabled:
		_hand_idle_t += delta * hand_idle_speed

		var idle_y: float = sin(_hand_idle_t) * hand_idle_amp_y
		var idle_rot_z: float = sin(_hand_idle_t * 0.8) * deg_to_rad(hand_idle_rot_z_deg)

		target_pos.y += idle_y
		target_rot.z += idle_rot_z

	if hand_bob_enabled:
		var move_input: Vector2 = Vector2.ZERO
		if Input.is_action_pressed("move_forward"):
			move_input.y += 1.0
		if Input.is_action_pressed("move_back"):
			move_input.y -= 1.0
		if Input.is_action_pressed("move_left"):
			move_input.x -= 1.0
		if Input.is_action_pressed("move_right"):
			move_input.x += 1.0

		var is_moving: bool = move_input.length() > 0.0 and state == PState.NORMAL and is_on_floor()

		if is_moving:
			var planar_speed: float = Vector2(velocity.x, velocity.z).length()
			var speed_factor: float = clampf(planar_speed / maxf(Constants.PLAYER_SPEED, 0.001), 0.0, 1.2)

			_hand_bob_t += delta * hand_bob_speed * lerpf(0.45, 0.9, speed_factor)

			var bob_y: float = -absf(sin(_hand_bob_t)) * hand_bob_amp_y
			var bob_x: float = sin(_hand_bob_t * 0.5) * hand_bob_amp_x * 0.35
			var bob_rot_z: float = sin(_hand_bob_t * 0.5) * deg_to_rad(hand_bob_rot_z_deg) * 0.35
			var bob_rot_x: float = absf(sin(_hand_bob_t)) * deg_to_rad(1.2)

			target_pos += Vector3(bob_x, bob_y, 0.0)
			target_rot.x += bob_rot_x
			target_rot.z += bob_rot_z
		else:
			_hand_bob_t = lerpf(_hand_bob_t, 0.0, delta * 4.0)

	if hand_sway_enabled:
		var look: Vector2 = _hand_look_input.clamp(
			Vector2(-120.0, -120.0),
			Vector2(120.0, 120.0)
		)

		var target_sway_pos: Vector3 = Vector3(
			-look.x * hand_sway_pos_amount * 0.018,
			-look.y * hand_sway_pos_amount * 0.014,
			absf(look.x) * hand_sway_pos_amount * 0.006
		)

		var target_sway_rot: Vector3 = Vector3(
			deg_to_rad(-look.y * hand_sway_rot_deg * 0.012),
			deg_to_rad(-look.x * hand_sway_rot_deg * 0.010),
			deg_to_rad(-look.x * hand_sway_rot_deg * 0.014)
		)

		_hand_sway_pos = _hand_sway_pos.lerp(target_sway_pos, delta * hand_sway_return_speed)
		_hand_sway_rot = _hand_sway_rot.lerp(target_sway_rot, delta * hand_sway_return_speed)

		target_pos += _hand_sway_pos
		target_rot += _hand_sway_rot

		_hand_look_input = _hand_look_input.lerp(Vector2.ZERO, delta * hand_sway_return_speed * 0.85)

	hand.position = hand.position.lerp(target_pos, delta * hand_sway_return_speed)
	hand.rotation = hand.rotation.lerp(target_rot, delta * hand_sway_return_speed)

func _update_body_effects(delta: float) -> void:
	if not is_instance_valid(body_sprite):
		return

	if not body_sprite.visible:
		return

	var target_pos: Vector3 = _body_base_pos
	var target_rot: Vector3 = _body_base_rot
	var base_scale: Vector3 = _body_base_scale
	var target_scale: Vector3 = _body_base_scale

	if body_idle_enabled:
		_body_idle_t += delta * body_idle_speed

		var idle_y: float = sin(_body_idle_t) * body_idle_amp_y
		var idle_x: float = sin(_body_idle_t * 0.5) * body_idle_amp_y * 0.35
		var idle_rot_z: float = sin(_body_idle_t * 0.8) * deg_to_rad(body_idle_rot_deg)
		var idle_rot_x: float = sin(_body_idle_t * 0.6) * deg_to_rad(body_idle_rot_deg * 0.35)

		target_pos.x += idle_x
		target_pos.y += idle_y
		target_rot.x += idle_rot_x
		target_rot.z += idle_rot_z

		target_scale.x = base_scale.x * (1.0 + sin(_body_idle_t * 0.7) * 0.003)
		target_scale.y = base_scale.y * (1.0 - sin(_body_idle_t * 0.7) * 0.002)
		target_scale.z = base_scale.z

	if body_walk_enabled:
		var move_input: Vector2 = Vector2.ZERO
		if Input.is_action_pressed("move_forward"):
			move_input.y += 1.0
		if Input.is_action_pressed("move_back"):
			move_input.y -= 1.0
		if Input.is_action_pressed("move_left"):
			move_input.x -= 1.0
		if Input.is_action_pressed("move_right"):
			move_input.x += 1.0

		var is_moving: bool = move_input.length() > 0.0 and state == PState.NORMAL and is_on_floor()

		if is_moving:
			var planar_speed: float = Vector2(velocity.x, velocity.z).length()
			var speed_factor: float = clampf(planar_speed / maxf(Constants.PLAYER_SPEED, 0.001), 0.0, 1.2)

			_body_walk_t += delta * body_walk_speed * lerpf(0.5, 1.0, speed_factor)

			var walk_x: float = sin(_body_walk_t * 0.5) * body_walk_amp_x
			var walk_y: float = -absf(sin(_body_walk_t)) * body_walk_amp_y
			var walk_rot_z: float = sin(_body_walk_t * 0.5) * deg_to_rad(body_walk_rot_deg)
			var walk_rot_x: float = absf(sin(_body_walk_t)) * deg_to_rad(body_walk_rot_deg * 0.45)

			target_pos += Vector3(walk_x, walk_y, 0.0)
			target_rot.x += walk_rot_x
			target_rot.z += walk_rot_z

			target_scale.x = target_scale.x * (1.0 + absf(sin(_body_walk_t)) * 0.004)
			target_scale.y = target_scale.y * (1.0 - absf(sin(_body_walk_t)) * 0.003)
		else:
			_body_walk_t = lerpf(_body_walk_t, 0.0, delta * 4.0)

	body_sprite.position = body_sprite.position.lerp(target_pos, delta * 6.0)
	body_sprite.rotation = body_sprite.rotation.lerp(target_rot, delta * 6.0)
	body_sprite.scale = body_sprite.scale.lerp(target_scale, delta * 6.0)

func _play_hand_shoot_anim() -> void:
	if not is_instance_valid(hand):
		return

	if is_instance_valid(_hand_tween):
		_hand_tween.kill()

	_hand_sway_pos = Vector3.ZERO
	_hand_sway_rot = Vector3.ZERO

	hand.position = _hand_base_pos
	hand.rotation = _hand_base_rot
	var base_scale: Vector3 = hand.scale

	var recoil_pos: Vector3 = _hand_base_pos + Vector3(-0.008, -0.055, 0.02)
	var recoil_scale: Vector3 = Vector3(
		base_scale.x * 1.015,
		base_scale.y * 0.985,
		base_scale.z
	)

	_hand_tween = create_tween()
	_hand_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_hand_tween.tween_property(hand, "position", recoil_pos, 0.045)
	_hand_tween.parallel().tween_property(hand, "scale", recoil_scale, 0.045)

	_hand_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_hand_tween.tween_property(hand, "position", _hand_base_pos, 0.12)
	_hand_tween.parallel().tween_property(hand, "scale", base_scale, 0.12)

func _play_shoot_ring_fx() -> void:
	if not is_instance_valid(shoot_ring):
		return

	if is_instance_valid(_shoot_ring_tween):
		_shoot_ring_tween.kill()

	shoot_ring.visible = true
	shoot_ring.scale = _shoot_ring_base_scale * 0.4
	shoot_ring.modulate = Color(1, 1, 1, 1)

	_shoot_ring_tween = create_tween()
	_shoot_ring_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_shoot_ring_tween.tween_property(shoot_ring, "scale", _shoot_ring_base_scale * 1.8, 0.12)
	_shoot_ring_tween.parallel().tween_property(shoot_ring, "modulate", Color(1, 1, 1, 0), 0.12)

	await _shoot_ring_tween.finished

	if is_instance_valid(shoot_ring):
		shoot_ring.visible = false
		shoot_ring.scale = _shoot_ring_base_scale
		shoot_ring.modulate = Color(1, 1, 1, 1)

func _update_downed_camera(delta: float) -> void:
	if not is_instance_valid(camera):
		return

	var target_y: float = _camera_base_y
	var speed: float = downed_cam_return_speed

	if state == PState.DOWNED:
		target_y = _camera_base_y + downed_cam_offset_y
		speed = downed_cam_lerp_speed

	camera.position.y = lerpf(camera.position.y, target_y, speed * delta)
