# res://Enemies/exception.gd
extends CharacterBody3D

var target: Node3D = null

const GRAVITY: float = 25.0

# Kill / contatto
@export var kill_radius: float = 1.35

# Movimento base (se nel tuo progetto avevi già Constants, questi export ti permettono di regolare dall'Inspector)
@export var speed: float = 6.5
@export var jitter_strength: float = 0.35

# “Exception” vibe: piccoli blink/warp (solo estetico + riposizionamento leggero)
@export var warp_interval_min: float = 1.2
@export var warp_interval_max: float = 2.2
@export var warp_distance: float = 1.6

var _warp_t: float = 0.0
var _warp_next: float = 1.6

# Jitter
var _jitter_dir: Vector3 = Vector3.ZERO
var _jitter_t: float = 0.0

# Knockback (perk + push melee)
var _knock: Vector3 = Vector3.ZERO
@export var knock_decay: float = 22.0

# Glitch/flicker
@onready var _mesh: MeshInstance3D = $MeshInstance3D
var _glitch_t: float = 0.0

# PUSH / STUN
var _stun_left: float = 0.0

# Flash (on hit)
var _flash_mat: StandardMaterial3D
var _orig_override: Material = null

func _ready() -> void:
	_warp_next = randf_range(warp_interval_min, warp_interval_max)

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
	# STUN: freeze totale (niente AI / niente warp / niente kill)
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

	# Flicker leggero
	_glitch_t += delta
	if is_instance_valid(_mesh):
		_mesh.visible = int(_glitch_t * 26.0) % 9 != 0

	# Jitter
	_jitter_t -= delta
	if _jitter_t <= 0.0:
		_jitter_t = randf_range(0.08, 0.18)
		var a := randf_range(0.0, TAU)
		_jitter_dir = Vector3(cos(a), 0.0, sin(a))

	# Warp timer (piccolo riposizionamento)
	_warp_t += delta
	if _warp_t >= _warp_next:
		_warp_t = 0.0
		_warp_next = randf_range(warp_interval_min, warp_interval_max)

		var to := (target.global_position - global_position)
		to.y = 0.0
		var forward := to.normalized()
		var side := Vector3(-forward.z, 0.0, forward.x) # perpendicolare

		var side_sign := -1.0 if randf() < 0.5 else 1.0
		var offset := side * side_sign * warp_distance

		# warp solo se non troppo vicino al player (evita “telefrag”)
		if global_position.distance_to(target.global_position) > 1.1:
			global_position += offset

	# Chase
	var to2 := (target.global_position - global_position)
	to2.y = 0.0
	var chase_dir := to2.normalized()

	var move_dir := (chase_dir + _jitter_dir * jitter_strength).normalized()

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

	# Collision kill (stesso pattern)
	for i in range(get_slide_collision_count()):
		var col := get_slide_collision(i)
		var other := col.get_collider()
		if other is Node and (other as Node).is_in_group("player"):
			var away := ((other as Node3D).global_position - global_position).normalized()
			Signals.player_hit.emit(away)
			return

	# Kill radius (fallback)
	if global_position.distance_to(target.global_position) <= kill_radius:
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
