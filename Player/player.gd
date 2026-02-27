extends CharacterBody3D

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera
@onready var shoot_ray: RayCast3D = $Head/ShootRay

var yaw := 0.0
var pitch := 0.0

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

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
	var input_dir := Vector3.ZERO
	if Input.is_action_pressed("move_forward"):
		input_dir.z -= 1
	if Input.is_action_pressed("move_back"):
		input_dir.z += 1
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1

	input_dir = input_dir.normalized()

	var dir := (transform.basis * input_dir)
	dir.y = 0
	dir = dir.normalized()

	velocity.x = dir.x * Constants.PLAYER_SPEED
	velocity.z = dir.z * Constants.PLAYER_SPEED

	# gravità base
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = 0.0

	move_and_slide()
