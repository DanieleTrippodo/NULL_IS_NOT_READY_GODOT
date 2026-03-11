# res://Enemies/stealer.gd
extends CharacterBody3D

var target: Node3D = null

const GRAVITY: float = 25.0

enum State {
	ORBIT_PLAYER,
	GO_TO_NULL,
	GUARD_NULL,
	PUSH_DYING
}

@export_group("Base")
@export var move_speed: float = 2.15
@export var move_response: float = 7.0
@export var knock_decay: float = 20.0
@export var orbit_radius: float = 2.8
@export var orbit_radius_jitter: float = 0.35
@export var orbit_retarget_time_min: float = 0.7
@export var orbit_retarget_time_max: float = 1.6
@export var orbit_side_bias: float = 1.15
@export var null_reach_distance: float = 0.45

@export_group("Separation")
@export var separation_radius: float = 1.5
@export var separation_strength: float = 2.0

@export_group("Player Contact")
@export var steal_touch_radius: float = 1.15
@export var player_push_force: float = 10.0
@export var steal_cooldown: float = 0.6

@export_group("Push Death")
@export var push_death_delay: float = 0.08

@onready var _sprite: AnimatedSprite3D = $AnimatedSprite3D

var _state: int = State.ORBIT_PLAYER
var _knock: Vector3 = Vector3.ZERO

var _push_death_left: float = -1.0
var _steal_cd_left: float = 0.0

var _orbit_sign: float = 1.0
var _orbit_angle_offset: float = 0.0
var _orbit_retarget_left: float = 0.0
var _orbit_target_pos: Vector3 = Vector3.ZERO


func _ready() -> void:
	if _sprite:
		_sprite.play("walk")

	# fallback: se piazzato manualmente nella scena, trova da solo il player
	if target == null:
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0 and players[0] is Node3D:
			target = players[0] as Node3D

	_pick_new_orbit_sign()
	_pick_new_orbit_target()


func set_target(t: Node3D) -> void:
	target = t


func add_knockback(v: Vector3) -> void:
	_knock += v


func apply_push(forward: Vector3, strength: float, lift: float, _stun_seconds: float) -> void:
	if _state == State.PUSH_DYING:
		return

	var dir: Vector3 = forward
	dir.y = 0.0
	if dir.length() > 0.001:
		dir = dir.normalized()

	_knock += dir * strength
	velocity.y = maxf(velocity.y, lift)

	_state = State.PUSH_DYING
	_push_death_left = push_death_delay

	_do_flash()


func apply_impact_stun(_stun_seconds: float, impact_dir: Vector3 = Vector3.ZERO, impact_knock: float = 0.0) -> void:
	# Per compatibilità col sistema dei nemici pushati tra loro.
	# Lo Stealer non si stunna davvero: prende solo knockback leggero.
	if impact_dir.length() > 0.001 and impact_knock > 0.0:
		var flat_dir: Vector3 = impact_dir
		flat_dir.y = 0.0
		if flat_dir.length() > 0.001:
			_knock += flat_dir.normalized() * impact_knock

	_do_flash()


func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0 and players[0] is Node3D:
			target = players[0] as Node3D
		else:
			return

	_steal_cd_left = maxf(_steal_cd_left - delta, 0.0)

	if _state == State.PUSH_DYING:
		_update_push_dying(delta)
		return

	var dropped_null: Node3D = _find_dropped_null()

	if Run.null_dropped and dropped_null != null:
		var dist_to_null: float = global_position.distance_to(dropped_null.global_position)
		if dist_to_null <= null_reach_distance:
			_state = State.GUARD_NULL
		else:
			_state = State.GO_TO_NULL
	else:
		_state = State.ORBIT_PLAYER

	match _state:
		State.ORBIT_PLAYER:
			_update_orbit_player(delta)
		State.GO_TO_NULL:
			_update_go_to_null(delta, dropped_null)
		State.GUARD_NULL:
			_update_guard_null(delta, dropped_null)

	_try_player_contact()
	_apply_gravity(delta)
	move_and_slide()


func _update_push_dying(delta: float) -> void:
	velocity.x = _knock.x
	velocity.z = _knock.z

	_apply_gravity(delta)
	_knock = _knock.move_toward(Vector3.ZERO, knock_decay * delta)

	move_and_slide()

	_push_death_left -= delta
	if _push_death_left <= 0.0:
		_die()


func _update_orbit_player(delta: float) -> void:
	_orbit_retarget_left -= delta
	if _orbit_retarget_left <= 0.0:
		if randf() < 0.35:
			_pick_new_orbit_sign()
		_pick_new_orbit_target()

	var desired_dir: Vector3 = _orbit_target_pos - global_position
	desired_dir.y = 0.0

	var separation: Vector3 = _get_separation_force()
	desired_dir += separation

	if desired_dir.length() > 0.001:
		desired_dir = desired_dir.normalized()

	var desired_velocity: Vector3 = desired_dir * move_speed
	velocity.x = lerpf(velocity.x, desired_velocity.x + _knock.x, move_response * delta)
	velocity.z = lerpf(velocity.z, desired_velocity.z + _knock.z, move_response * delta)

	_knock = _knock.move_toward(Vector3.ZERO, knock_decay * delta)


func _update_go_to_null(delta: float, dropped_null: Node3D) -> void:
	if dropped_null == null or not is_instance_valid(dropped_null):
		velocity.x = lerpf(velocity.x, _knock.x, move_response * delta)
		velocity.z = lerpf(velocity.z, _knock.z, move_response * delta)
		_knock = _knock.move_toward(Vector3.ZERO, knock_decay * delta)
		return

	var to_null: Vector3 = dropped_null.global_position - global_position
	to_null.y = 0.0

	var desired_dir: Vector3 = Vector3.ZERO
	if to_null.length() > 0.001:
		desired_dir = to_null.normalized()

	var separation: Vector3 = _get_separation_force()
	desired_dir += separation

	if desired_dir.length() > 0.001:
		desired_dir = desired_dir.normalized()

	var desired_velocity: Vector3 = desired_dir * move_speed
	velocity.x = lerpf(velocity.x, desired_velocity.x + _knock.x, move_response * delta)
	velocity.z = lerpf(velocity.z, desired_velocity.z + _knock.z, move_response * delta)

	_knock = _knock.move_toward(Vector3.ZERO, knock_decay * delta)


func _update_guard_null(delta: float, dropped_null: Node3D) -> void:
	if dropped_null == null or not is_instance_valid(dropped_null):
		_state = State.ORBIT_PLAYER
		return

	var to_null: Vector3 = dropped_null.global_position - global_position
	to_null.y = 0.0
	var dist: float = to_null.length()

	if dist > null_reach_distance:
		_state = State.GO_TO_NULL
		_update_go_to_null(delta, dropped_null)
		return

	# resta quasi fermo sopra il Null
	velocity.x = lerpf(velocity.x, _knock.x, move_response * delta)
	velocity.z = lerpf(velocity.z, _knock.z, move_response * delta)
	_knock = _knock.move_toward(Vector3.ZERO, knock_decay * delta)


func _pick_new_orbit_sign() -> void:
	_orbit_sign = -1.0 if randf() < 0.5 else 1.0


func _pick_new_orbit_target() -> void:
	if target == null or not is_instance_valid(target):
		return

	var to_me: Vector3 = global_position - target.global_position
	to_me.y = 0.0

	var base_dir: Vector3
	if to_me.length() > 0.001:
		base_dir = to_me.normalized()
	else:
		var a: float = randf_range(0.0, TAU)
		base_dir = Vector3(cos(a), 0.0, sin(a))

	# side vector per orbitare e non andare addosso diretto al player
	var side: Vector3 = Vector3(-base_dir.z, 0.0, base_dir.x) * _orbit_sign

	var radius: float = orbit_radius + randf_range(-orbit_radius_jitter, orbit_radius_jitter)
	radius = maxf(radius, 1.6)

	var mix_dir: Vector3 = (base_dir + side * orbit_side_bias).normalized()
	_orbit_target_pos = target.global_position + mix_dir * radius
	_orbit_retarget_left = randf_range(orbit_retarget_time_min, orbit_retarget_time_max)


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


func _try_player_contact() -> void:
	if target == null or not is_instance_valid(target):
		return
	if _steal_cd_left > 0.0:
		return

	var to_player: Vector3 = target.global_position - global_position
	to_player.y = 0.0
	if to_player.length() > steal_touch_radius:
		return

	_steal_cd_left = steal_cooldown

	var push_dir: Vector3 = to_player.normalized()
	if push_dir.length() <= 0.001:
		push_dir = -global_transform.basis.z

	# Se il player ha il Null: forza il drop
	if Run.null_ready and target.has_method("force_drop_null"):
		target.call("force_drop_null")

	# Spinta player
	if target.has_method("apply_external_push"):
		target.call("apply_external_push", push_dir, player_push_force, 0.0)


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -1.0


func _find_dropped_null() -> Node3D:
	# Cerca il Null droppato nella scena corrente.
	# Non elegantissimo, ma robusto per il test iniziale senza toccare ancora Game.gd.
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return null

	return _find_dropped_null_recursive(scene_root)


func _find_dropped_null_recursive(node: Node) -> Node3D:
	if node == null:
		return null

	if node.has_method("is_dropped"):
		var dropped: bool = bool(node.call("is_dropped"))
		if dropped and node is Node3D:
			return node as Node3D

	for child in node.get_children():
		var found: Node3D = _find_dropped_null_recursive(child)
		if found != null:
			return found

	return null


func _do_flash() -> void:
	if _sprite == null:
		return

	_sprite.modulate = Color(0.45, 0.45, 0.45, 1.0)
	await get_tree().create_timer(0.03).timeout

	if is_instance_valid(_sprite):
		_sprite.modulate = Color(0.30, 0.30, 0.30, 1.0)
	await get_tree().create_timer(0.03).timeout

	if is_instance_valid(_sprite):
		_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)


func _die() -> void:
	Signals.enemy_killed.emit(self)
