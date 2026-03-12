# res://Enemies/turret.gd
extends CharacterBody3D

@export var fire_interval: float = 1.6
@export var bullet_speed: float = 18.0

@export var knock_decay: float = 22.0
@export var push_collision_window: float = 0.28
@export var push_collision_min_speed: float = 3.0
@export var push_collision_knock_transfer: float = 0.65

const GRAVITY: float = 25.0

var target: Node3D = null
var bullet_scene: PackedScene = null
var timer: float = 0.0

var _knock: Vector3 = Vector3.ZERO
var _stun_left: float = 0.0

var _push_collision_time_left: float = 0.0
var _push_collision_used: bool = false
var _last_push_stun: float = 0.0


func set_target(t: Node3D) -> void:
	target = t


func set_bullet_scene(ps: PackedScene) -> void:
	bullet_scene = ps


func set_fire_interval(v: float) -> void:
	fire_interval = v


func add_knockback(v: Vector3) -> void:
	_knock += v


func apply_push(forward: Vector3, strength: float, lift: float, stun_seconds: float) -> void:
	_stun_left = maxf(_stun_left, stun_seconds)
	_knock += forward.normalized() * strength
	velocity.y = maxf(velocity.y, lift)

	_last_push_stun = stun_seconds
	_push_collision_time_left = push_collision_window
	_push_collision_used = false


func apply_impact_stun(stun_seconds: float, impact_dir: Vector3 = Vector3.ZERO, impact_knock: float = 0.0) -> void:
	_stun_left = maxf(_stun_left, stun_seconds)

	if impact_dir.length() > 0.001 and impact_knock > 0.0:
		var flat_dir: Vector3 = impact_dir
		flat_dir.y = 0.0
		if flat_dir.length() > 0.001:
			_knock += flat_dir.normalized() * impact_knock

	_push_collision_time_left = 0.0
	_push_collision_used = true


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

		# stun su se stessa
		apply_impact_stun(impact_stun)

		# stun sull'altro nemico
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
	if _push_collision_time_left > 0.0:
		_push_collision_time_left = maxf(_push_collision_time_left - delta, 0.0)

	# STUN: niente sparo, solo knockback + gravità
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

	# normale: non si muove attivamente, ma può avere knock residuo
	velocity.x = _knock.x
	velocity.z = _knock.z

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -1.0

	_knock = _knock.move_toward(Vector3.ZERO, knock_decay * delta)
	move_and_slide()

	_try_push_enemy_collision()

	if target == null or not is_instance_valid(target):
		return
	if bullet_scene == null:
		return

	timer += delta
	if timer < fire_interval:
		return
	timer = 0.0

	var dir: Vector3 = target.global_position - global_position
	dir.y = 0.0
	if dir.length() <= 0.001:
		return
	dir = dir.normalized()

	var b: Node3D = bullet_scene.instantiate() as Node3D
	get_tree().current_scene.get_node("World").add_child(b)

	# spawn bullet leggermente avanti/sopra
	var origin: Vector3 = global_position + Vector3(0, 0.8, 0) + dir * 0.6
	if b.has_method("fire"):
		b.fire(origin, dir, bullet_speed, self)
