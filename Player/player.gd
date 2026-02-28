# res://Player/Player.gd
extends CharacterBody3D

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera

var _charging: bool = false
var _charge_time: float = 0.0
var _cam_base_pos: Vector3
var _shake_rng := RandomNumberGenerator.new()

var yaw: float = 0.0
var pitch: float = 0.0

const GRAVITY: float = 20.0

var has_fly_down: bool = false
var has_dash: bool = false

# Dash (perk)
var dash_cd: float = 0.0
var dash_time_left: float = 0.0
var dash_vel: Vector3 = Vector3.ZERO

const DASH_DURATION: float = 0.12
const DASH_COOLDOWN: float = 0.9
const DASH_STRENGTH: float = 14.0

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	set_process_unhandled_input(true)
	set_process(true)

	_cam_base_pos = camera.position
	_shake_rng.randomize()

	has_fly_down = InputMap.has_action("fly_down")
	has_dash = InputMap.has_action("dash")

func _process(delta: float) -> void:
	# camera shake mentre carichi il colpo
	if Run.charge_shot_enabled and _charging:
		_charge_time += delta
		var s := Run.charge_shake_strength
		camera.position = _cam_base_pos + Vector3(
			_shake_rng.randf_range(-s, s),
			_shake_rng.randf_range(-s, s),
			_shake_rng.randf_range(-s, s)
		)
	else:
		camera.position = _cam_base_pos

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * Constants.MOUSE_SENS
		pitch -= event.relative.y * Constants.MOUSE_SENS
		pitch = clamp(pitch, deg_to_rad(-85), deg_to_rad(85))
		rotation.y = yaw
		head.rotation.x = pitch

	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Shoot / Charge shot
	if Run.charge_shot_enabled:
		if event.is_action_pressed("shoot"):
			# inizia a caricare solo se puoi sparare
			if Run.null_ready:
				_charging = true
				_charge_time = 0.0
		elif event.is_action_released("shoot"):
			if _charging:
				_charging = false
				var origin: Vector3 = camera.global_transform.origin
				var dir: Vector3 = -camera.global_transform.basis.z
				var size_mult := 1.0
				if _charge_time >= Run.charge_shot_seconds:
					size_mult = Run.charge_shot_scale
				Signals.request_shoot.emit(origin, dir, size_mult)
	else:
		if event.is_action_pressed("shoot"):
			var origin: Vector3 = camera.global_transform.origin
			var dir: Vector3 = -camera.global_transform.basis.z
			Signals.request_shoot.emit(origin, dir, 1.0)

	if event.is_action_pressed("interact"):
		Signals.request_pickup.emit()

func _physics_process(delta: float) -> void:
	# dash timers
	dash_cd = max(dash_cd - delta, 0.0)
	dash_time_left = max(dash_time_left - delta, 0.0)

	# input movimento
	var input_dir := Vector3.ZERO
	if Input.is_action_pressed("move_forward"):
		input_dir.z -= 1.0
	if Input.is_action_pressed("move_back"):
		input_dir.z += 1.0
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1.0
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1.0
	input_dir = input_dir.normalized()

	var dir := (transform.basis * input_dir)
	dir.y = 0.0
	dir = dir.normalized()

	# speed con perk
	var speed: float = Constants.PLAYER_SPEED * Run.move_speed_mult
	if not is_on_floor():
		speed *= Run.air_speed_mult

	velocity.x = dir.x * speed
	velocity.z = dir.z * speed

	# DASH (solo se sbloccato e azione esiste)
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

	# flight / gravity / jump
	var flying: bool = Run.flight_time_left > 0.0

	if flying:
		Run.flight_time_left = max(Run.flight_time_left - delta, 0.0)

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

	move_and_slide()
