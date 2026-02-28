# res://Player/Player.gd
extends CharacterBody3D

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera
@onready var body_sprite: Sprite3D = $Body
@onready var body_down_sprite: Sprite3D = $Body_Down

enum PState { NORMAL, KNOCKBACK, DOWNED }

@export var knockback_strength: float = 200.0
@export var knockback_lift: float = 90.0
@export var downed_cam_offset_y: float = -0.75
@export var knockback_min_time: float = 0.10
@export var downed_invuln_seconds: float = 0.5


var state: int = PState.NORMAL

var _charging: bool = false
var _charge_time: float = 0.0

var _cam_base_pos: Vector3
var _cam_normal_pos: Vector3
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

# timers interni
var _knock_t: float = 0.0
var _downed_invuln_t: float = 0.0

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	set_process_unhandled_input(true)
	set_process(true)

	add_to_group("player")

	_cam_base_pos = camera.position
	_cam_normal_pos = camera.position
	_shake_rng.randomize()

	has_fly_down = InputMap.has_action("fly_down")
	has_dash = InputMap.has_action("dash")

	Signals.player_hit.connect(_on_player_hit)
	Signals.enemy_killed.connect(_on_enemy_killed)
	_set_body_downed(false)
	
	

func _set_body_downed(downed: bool) -> void:
	# fuori survival: Body ON, Body_Down OFF
	# in survival:    Body OFF, Body_Down ON
	if body_sprite:
		body_sprite.visible = not downed
	if body_down_sprite:
		body_down_sprite.visible = downed

func _process(delta: float) -> void:
	# camera shake mentre carichi il colpo (solo fuori survival)
	if Run.charge_shot_enabled and _charging and not Run.survival_mode:
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

	# SHOOT
	# - In KNOCKBACK: NON puoi sparare
	# - In DOWNED: puoi sparare ma senza perk (niente charge)
	if state == PState.KNOCKBACK:
		return

	if state == PState.DOWNED:
		if event.is_action_pressed("shoot"):
			var origin: Vector3 = camera.global_transform.origin
			var dir: Vector3 = -camera.global_transform.basis.z
			Signals.request_shoot.emit(origin, dir, 1.0)
		# pickup ok anche da sdraiato
		if event.is_action_pressed("interact"):
			Signals.request_pickup.emit()
		return

	# NORMAL (comportamento attuale)
	if Run.charge_shot_enabled:
		if event.is_action_pressed("shoot"):
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
	# timers
	if state == PState.KNOCKBACK:
		_knock_t += delta
	if state == PState.DOWNED:
		_downed_invuln_t = max(_downed_invuln_t - delta, 0.0)

	# dash timers (solo NORMAL, ma li teniamo aggiornati comunque)
	dash_cd = max(dash_cd - delta, 0.0)
	dash_time_left = max(dash_time_left - delta, 0.0)

	match state:
		PState.NORMAL:
			_physics_normal(delta)
		PState.KNOCKBACK:
			_physics_knockback(delta)
		PState.DOWNED:
			_physics_downed(delta)

func _physics_normal(delta: float) -> void:
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

	var speed: float = Constants.PLAYER_SPEED * Run.move_speed_mult
	if not is_on_floor():
		speed *= Run.air_speed_mult

	velocity.x = dir.x * speed
	velocity.z = dir.z * speed

	# DASH
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

func _physics_knockback(delta: float) -> void:
	# niente input, solo fisica + gravità
	if is_on_floor():
		# frena un po' sul pavimento
		velocity.x = lerp(velocity.x, 0.0, 10.0 * delta)
		velocity.z = lerp(velocity.z, 0.0, 10.0 * delta)
		velocity.y = -1.0
	else:
		velocity.y -= GRAVITY * delta

	move_and_slide()

	# entra in DOWNED solo dopo atterraggio + un minimo tempo (evita trigger immediato)
	if is_on_floor() and _knock_t >= knockback_min_time:
		_enter_downed()

func _physics_downed(_delta: float) -> void:
	# immobilizzato: zero movimento
	velocity.x = 0.0
	velocity.z = 0.0
	if is_on_floor():
		velocity.y = -1.0
	else:
		velocity.y -= GRAVITY * _delta

	move_and_slide()

func _on_player_hit(knockback_dir: Vector3) -> void:
	# Durante knockback ignoriamo hit (evita double-tap ingiusto)
	if state == PState.KNOCKBACK:
		return

	# Se sei DOWNED: seconda hit = morte (dopo invuln)
	if state == PState.DOWNED:
		if _downed_invuln_t > 0.0:
			return
		Signals.player_died.emit()
		return

	# NORMAL -> entra in knockback
	_charging = false
	_charge_time = 0.0

	state = PState.KNOCKBACK
	_knock_t = 0.0

	var dir := knockback_dir
	if dir.length() < 0.001:
		dir = -global_transform.basis.z
	dir = dir.normalized()

	velocity = dir * knockback_strength
	velocity.y = knockback_lift

func _enter_downed() -> void:
	_set_body_downed(true)
	state = PState.DOWNED
	Run.survival_mode = true
	_downed_invuln_t = downed_invuln_seconds

	# camera più bassa (sdraiato)
	_cam_base_pos = _cam_normal_pos + Vector3(0, downed_cam_offset_y, 0)

	Signals.survival_mode_changed.emit(true)

func _exit_downed() -> void:
	_set_body_downed(false)
	state = PState.NORMAL
	Run.survival_mode = false
	_downed_invuln_t = 0.0

	_cam_base_pos = _cam_normal_pos

	Signals.survival_mode_changed.emit(false)

func _on_enemy_killed(_enemy: Node) -> void:
	# Se uccidi mentre sei DOWNED -> recover immediato
	if state == PState.DOWNED:
		_exit_downed()
