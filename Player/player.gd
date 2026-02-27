# res://Player/Player.gd
extends CharacterBody3D

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera

var yaw: float = 0.0
var pitch: float = 0.0

const GRAVITY: float = 20.0
var has_fly_down: bool = false

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	set_process_unhandled_input(true)
	has_fly_down = InputMap.has_action("fly_down")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * Constants.MOUSE_SENS
		pitch -= event.relative.y * Constants.MOUSE_SENS
		pitch = clamp(pitch, deg_to_rad(-85), deg_to_rad(85))
		rotation.y = yaw
		head.rotation.x = pitch

	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if event.is_action_pressed("shoot"):
		var origin := camera.global_transform.origin
		var dir := -camera.global_transform.basis.z
		Signals.request_shoot.emit(origin, dir)

	if event.is_action_pressed("interact"):
		Signals.request_pickup.emit()

func _physics_process(delta: float) -> void:
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
			# salto sbloccato: qui NON verrà sovrascritto
			if Run.jump_enabled and Input.is_action_just_pressed("jump"):
				velocity.y = Run.jump_velocity
			else:
				velocity.y = -1.0
		else:
			velocity.y -= GRAVITY * delta

	move_and_slide()
