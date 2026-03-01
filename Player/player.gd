# res://Player/player.gd
extends CharacterBody3D

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera

@onready var body_sprite: Sprite3D = $Body
@onready var body_down_sprite: Sprite3D = $Body_Down

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

@export var knockback_lift: float = 8.0
@export var knockback_speed: float = 22.0
@export var knockback_drag_air: float = 6.0
@export var knockback_drag_ground: float = 10.0
@export var knockback_max_step: float = 6.0 # clamp anti-scatto (valore più alto = meno clamp)

@export var downed_cam_offset_y: float = -0.75
@export var knockback_min_time: float = 0.10
@export var downed_invuln_seconds: float = 0.5

var state: int = PState.NORMAL

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

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	set_process_unhandled_input(true)
	set_process(true)

	add_to_group("player")

	_cam_normal_pos = camera.position
	_cam_base_pos = camera.position

	has_fly_down = InputMap.has_action("fly_down")
	has_dash = InputMap.has_action("dash")
	has_swap = InputMap.has_action("swap")

	Signals.player_hit.connect(_on_player_hit)
	Signals.enemy_killed.connect(_on_enemy_killed)

	_set_body_downed(false)

func _unhandled_input(event: InputEvent) -> void:
	# mouse look sempre abilitato (anche in downed)
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * Constants.MOUSE_SENS
		pitch -= event.relative.y * Constants.MOUSE_SENS

		var limit_deg: float = normal_pitch_limit_deg
		if state == PState.DOWNED:
			limit_deg = downed_pitch_limit_deg
		pitch = clamp(pitch, deg_to_rad(-limit_deg), deg_to_rad(limit_deg))

		rotation.y = yaw
		head.rotation.x = pitch

	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# In KNOCKBACK: niente sparo (come richiesto)
	if state == PState.KNOCKBACK:
		return

	# DOWNED: puoi sparare ma senza perk (niente charge)
	if state == PState.DOWNED:
		if event.is_action_pressed("shoot"):
			var origin: Vector3 = camera.global_transform.origin
			var dir: Vector3 = -camera.global_transform.basis.z
			Signals.request_shoot.emit(origin, dir, 1.0)

		if event.is_action_pressed("interact"):
			Signals.request_pickup.emit()

		# SWAP (perk) - Q
		if has_swap and event.is_action_pressed("swap"):
			Signals.request_swap.emit()

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
				var size_mult := 1.0
				if _charge_time >= Run.charge_shot_seconds:
					size_mult = Run.charge_shot_scale
				Signals.request_shoot.emit(origin2, dir2, size_mult)
	else:
		if event.is_action_pressed("shoot"):
			var origin3: Vector3 = camera.global_transform.origin
			var dir3: Vector3 = -camera.global_transform.basis.z
			Signals.request_shoot.emit(origin3, dir3, 1.0)

	if event.is_action_pressed("interact"):
		Signals.request_pickup.emit()

	# SWAP (perk) - Q
	if has_swap and event.is_action_pressed("swap"):
		Signals.request_swap.emit()

func _process(delta: float) -> void:
	# charge timer (solo fuori survival)
	if Run.charge_shot_enabled and _charging and not Run.survival_mode:
		_charge_time += delta

func _physics_process(delta: float) -> void:
	# timers
	if state == PState.KNOCKBACK:
		_knock_t += delta
	if state == PState.DOWNED:
		_downed_invuln_t = maxf(_downed_invuln_t - delta, 0.0)

	# dash timers (solo NORMAL, ma aggiorniamo comunque)
	dash_cd = maxf(dash_cd - delta, 0.0)
	dash_time_left = maxf(dash_time_left - delta, 0.0)

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

	# DASH (perk)
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

	# flight / gravity
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

	move_and_slide()

func _physics_knockback(delta: float) -> void:
	# drag graduale (aria / terra)
	var drag := knockback_drag_air
	if is_on_floor():
		drag = knockback_drag_ground

	velocity.x = move_toward(velocity.x, 0.0, drag * delta)
	velocity.z = move_toward(velocity.z, 0.0, drag * delta)

	# gravità
	if is_on_floor():
		velocity.y = -1.0
	else:
		velocity.y -= GRAVITY * delta

	# clamp anti-scatto (evita “teletrasporto” se delta è alto)
	var h := Vector2(velocity.x, velocity.z)
	var max_h: float = knockback_max_step / maxf(delta, 0.001)
	if h.length() > max_h:
		h = h.normalized() * max_h
		velocity.x = h.x
		velocity.z = h.y

	move_and_slide()

	# entra in DOWNED solo dopo atterraggio + un minimo tempo
	if is_on_floor() and _knock_t >= knockback_min_time:
		_enter_downed()

func _physics_downed(delta: float) -> void:
	# immobilizzato: zero movimento orizzontale
	velocity.x = 0.0
	velocity.z = 0.0

	if is_on_floor():
		velocity.y = -1.0
	else:
		velocity.y -= GRAVITY * delta

	move_and_slide()

func _on_player_hit(knockback_dir: Vector3) -> void:
	# durante knockback ignoriamo hit extra (più fair)
	if state == PState.KNOCKBACK:
		return

	# se DOWNED: seconda hit = morte (dopo invuln)
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

	# aggiunge spinta (più naturale di sovrascrivere tutto)
	velocity.x += dir.x * knockback_speed
	velocity.z += dir.z * knockback_speed
	velocity.y = maxf(velocity.y, knockback_lift)

func _enter_downed() -> void:
	state = PState.DOWNED
	Run.survival_mode = true
	_downed_invuln_t = downed_invuln_seconds

	# camera più bassa (sdraiato)
	_cam_base_pos = _cam_normal_pos + Vector3(0, downed_cam_offset_y, 0)
	camera.position = _cam_base_pos

	_set_body_downed(true)

	Signals.survival_mode_changed.emit(true)

func _exit_downed() -> void:
	state = PState.NORMAL
	Run.survival_mode = false
	_downed_invuln_t = 0.0

	_cam_base_pos = _cam_normal_pos
	camera.position = _cam_base_pos

	_set_body_downed(false)

	Signals.survival_mode_changed.emit(false)

func _set_body_downed(downed: bool) -> void:
	if body_sprite:
		body_sprite.visible = not downed
	if body_down_sprite:
		body_down_sprite.visible = downed

func _on_enemy_killed(_enemy: Node) -> void:
	# se uccidi mentre sei DOWNED -> recover immediato
	if state == PState.DOWNED:
		_exit_downed()
