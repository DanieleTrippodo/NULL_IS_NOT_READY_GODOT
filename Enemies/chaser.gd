extends CharacterBody3D

var target: Node3D = null

const GRAVITY: float = 25.0
const KILL_RADIUS: float = 1.25

# Knockback
var _knock: Vector3 = Vector3.ZERO
@export var knock_decay: float = 22.0

# Stun
var _stun_left: float = 0.0
@onready var _sprite: AnimatedSprite3D = $AnimatedSprite3D

# Movimento più organico
@export var move_response: float = 7.5
@export var wander_strength: float = 0.22
@export var separation_radius: float = 1.4
@export var separation_strength: float = 2.2

var _wander_time: float = 0.0
var _wander_angle: float = 0.0

# Push collision combo
@export var push_collision_window: float = 0.28
@export var push_collision_min_speed: float = 3.0
@export var push_collision_knock_transfer: float = 0.65

var _push_collision_time_left: float = 0.0
var _push_collision_used: bool = false
var _last_push_stun: float = 0.0


func _ready() -> void:
	if _sprite:
		_sprite.play("walk")

	_wander_angle = randf_range(0.0, TAU)
	_wander_time = randf_range(0.0, 10.0)


func set_target(t: Node3D) -> void:
	target = t


func add_knockback(v: Vector3) -> void:
	_knock += v


func _get_separation_force() -> Vector3:
	var push: Vector3 = Vector3.ZERO

	for other in get_tree().get_nodes_in_group("enemy"):
		if other == self:
			continue
		if not (other is CharacterBody3D):
			continue

		var other_body: CharacterBody3D = other as CharacterBody3D
		var offset: Vector3 = global_position - other_body.global_position
		offset.y = 0.0

		var dist: float = offset.length()
		if dist <= 0.001 or dist > separation_radius:
			continue

		var weight: float = 1.0 - (dist / separation_radius)
		push += offset.normalized() * weight

	if push.length() > 0.001:
		push = push.normalized() * separation_strength

	return push


func _do_flash() -> void:
	if _sprite == null:
		return

	_sprite.modulate = Color(0.405, 0.405, 0.405, 1.0)
	await get_tree().create_timer(0.03).timeout

	if is_instance_valid(_sprite):
		_sprite.modulate = Color(0.385, 0.385, 0.385, 1.0)
	await get_tree().create_timer(0.03).timeout

	if is_instance_valid(_sprite):
		_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)


func apply_push(forward: Vector3, strength: float, lift: float, stun_seconds: float) -> void:
	_stun_left = maxf(_stun_left, stun_seconds)
	_knock += forward.normalized() * strength
	velocity.y = maxf(velocity.y, lift)

	_last_push_stun = stun_seconds
	_push_collision_time_left = push_collision_window
	_push_collision_used = false

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
		if impact_dir.length() <= 0.001:
			impact_dir = global_position - (other as Node3D).global_position

		# self
		apply_impact_stun(impact_stun)

		# other enemy
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


func _physics_process(delta: float) -> void:
	if target == null:
		return

	if _push_collision_time_left > 0.0:
		_push_collision_time_left = maxf(_push_collision_time_left - delta, 0.0)

	# STUN: niente AI, ma gravità + knock attivi
	if _stun_left > 0.0:
		_stun_left = maxf(_stun_left - delta, 0.0)

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

	var to: Vector3 = target.global_position - global_position
	to.y = 0.0

	var base_dir: Vector3 = Vector3.ZERO
	if to.length() > 0.001:
		base_dir = to.normalized()

	# micro-variazione continua
	_wander_time += delta
	_wander_angle += randf_range(-1.2, 1.2) * delta
	var wander_dir: Vector3 = Vector3(cos(_wander_angle), 0.0, sin(_wander_angle)) * wander_strength

	# separazione dagli altri nemici
	var separation: Vector3 = _get_separation_force()

	# direzione finale
	var desired_dir: Vector3 = base_dir + wander_dir + separation
	desired_dir.y = 0.0

	if desired_dir.length() > 0.001:
		desired_dir = desired_dir.normalized()
	else:
		desired_dir = base_dir

	var desired_velocity: Vector3 = desired_dir * Constants.CHASER_SPEED

	# inerzia / smoothing
	velocity.x = lerpf(velocity.x, desired_velocity.x + _knock.x, move_response * delta)
	velocity.z = lerpf(velocity.z, desired_velocity.z + _knock.z, move_response * delta)

	# gravità
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -1.0

	# decay knockback
	_knock = _knock.move_toward(Vector3.ZERO, knock_decay * delta)

	move_and_slide()

	# collisione push contro altri nemici
	_try_push_enemy_collision()

	# kill on collision col player
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
