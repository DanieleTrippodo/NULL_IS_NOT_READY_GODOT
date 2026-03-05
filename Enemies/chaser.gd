# res://Enemies/chaser.gd
extends CharacterBody3D

var target: Node3D = null

const GRAVITY: float = 25.0
const KILL_RADIUS: float = 1.25

# Knockback (per perk DROP_SHOCKWAVE)
var _knock: Vector3 = Vector3.ZERO
@export var knock_decay: float = 22.0

var _stun_left: float = 0.0
@onready var _mesh: MeshInstance3D = $MeshInstance3D
var _flash_mat: StandardMaterial3D
var _orig_override: Material = null

func set_target(t: Node3D) -> void:
	target = t

func add_knockback(v: Vector3) -> void:
	_knock += v

func _physics_process(delta: float) -> void:
	if target == null:
		return

# STUN: freeze totale (niente AI / niente kill), ma applichiamo gravità + knock
	if _stun_left > 0.0:
		_stun_left = maxf(_stun_left - delta, 0.0)

		# solo knock + gravità
		velocity.x = _knock.x
		velocity.z = _knock.z

		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		else:
			velocity.y = -1.0

		_knock = _knock.move_toward(Vector3.ZERO, knock_decay * delta)
		move_and_slide()
		return

	var to := (target.global_position - global_position)
	to.y = 0.0
	var dir := to.normalized()

	# movimento base + knockback
	velocity.x = dir.x * Constants.CHASER_SPEED + _knock.x
	velocity.z = dir.z * Constants.CHASER_SPEED + _knock.z

	# gravità
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -1.0

	# decay knockback
	_knock = _knock.move_toward(Vector3.ZERO, knock_decay * delta)

	move_and_slide()

	# kill on collision
	for i in range(get_slide_collision_count()):
		var col := get_slide_collision(i)
		var other := col.get_collider()
		if other is Node and (other as Node).is_in_group("player"):
			var away := ((other as Node3D).global_position - global_position).normalized()
			Signals.player_hit.emit(away)
			return

	# fallback distanza (in caso di collisioni “morbide”)
	if global_position.distance_to(target.global_position) <= KILL_RADIUS:
		var away2 := (target.global_position - global_position).normalized()
		Signals.player_hit.emit(away2)

func _do_flash() -> void:
	if _mesh == null:
		return
	if _flash_mat == null:
		_flash_mat = StandardMaterial3D.new()
		_flash_mat.emission_enabled = true
		_flash_mat.emission = Color(1, 1, 1)
		_flash_mat.albedo_color = Color(1, 1, 1)
		_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	if _orig_override == null:
		_orig_override = _mesh.material_override
	_mesh.material_override = _flash_mat

	# restore after short time
	await get_tree().create_timer(0.08).timeout
	if is_instance_valid(_mesh):
		_mesh.material_override = _orig_override

func apply_push(forward: Vector3, strength: float, lift: float, stun_seconds: float) -> void:
	_stun_left = maxf(_stun_left, stun_seconds)
	_knock += forward.normalized() * strength
	velocity.y = maxf(velocity.y, lift)
	_do_flash()
