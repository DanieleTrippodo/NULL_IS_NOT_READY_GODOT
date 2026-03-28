# res://Enemies/drifter_turret.gd
extends CharacterBody3D

enum AIState {
	WANDER,
	ALERT,
	ENGAGE
}

@export_group("Combat")
@export var fire_interval: float = 1.9
@export var fire_interval_min_mult: float = 0.38
@export var fire_interval_max_mult: float = 1.25
@export_range(1, 8, 1) var shots_per_pattern_min: int = 2
@export_range(1, 8, 1) var shots_per_pattern_max: int = 3
@export var alert_pause: float = 0.07
@export var first_shot_delay_after_alert: float = 0.22
@export var bullet_speed: float = 16.0
@export var view_distance: float = 24.0

@export_group("Telegraph")
@export var telegraph_time: float = 0.20
@export var telegraph_flash_speed: float = 20.0
@export var telegraph_flash_amount: float = 0.80

@export_group("Drift")
@export var drift_speed: float = 4.0
@export var drift_response: float = 6.5
@export var drift_change_min: float = 0.45
@export var drift_change_max: float = 1.10
@export_range(0.0, 1.0, 0.01) var idle_chance: float = 0.10

@export_group("Hover")
@export var hover_height: float = 3.0
@export var bob_extra_height: float = 0.06
@export var bob_speed: float = 2.1
@export var body_spin_speed: float = 0.9

@export_group("Push / Stun")
@export var knock_decay: float = 22.0
@export var push_collision_window: float = 0.28
@export var push_collision_min_speed: float = 3.0
@export var push_collision_knock_transfer: float = 0.65

var target: Node3D = null
var bullet_scene: PackedScene = null

var _state: int = AIState.WANDER
var _state_timer: float = 0.0
var _wander_dir: Vector3 = Vector3.ZERO
var _wander_change_left: float = 0.0

var _fire_left: float = 0.0
var _current_fire_interval: float = 0.0
var _pattern_shots_left: int = 0

var _knock: Vector3 = Vector3.ZERO
var _stun_left: float = 0.0

var _push_collision_time_left: float = 0.0
var _push_collision_used: bool = false
var _last_push_stun: float = 0.0

var _bob_t: float = 0.0
var _base_floor_y: float = 0.0
var _hover_push_offset: float = 0.0
var _telegraph_left: float = 0.0
var _sprite_base_modulate: Color = Color(1, 1, 1, 1)

@onready var body_mesh: Node3D = $Body
@onready var muzzle: Marker3D = $Muzzle
@onready var ray_origin: Marker3D = $RayOrigin
@onready var sprite_visual: Sprite3D = $Sprite3D

var _body_base_pos: Vector3 = Vector3.ZERO
var _muzzle_base_pos: Vector3 = Vector3.ZERO
var _ray_base_pos: Vector3 = Vector3.ZERO


func _ready() -> void:
	if is_instance_valid(body_mesh):
		_body_base_pos = body_mesh.position
	if is_instance_valid(muzzle):
		_muzzle_base_pos = muzzle.position
	if is_instance_valid(ray_origin):
		_ray_base_pos = ray_origin.position
	if is_instance_valid(sprite_visual):
		_sprite_base_modulate = sprite_visual.modulate

	_base_floor_y = global_position.y
	global_position.y = _base_floor_y + hover_height

	_pick_new_wander_dir()
	_choose_new_fire_pattern()
	_fire_left = _current_fire_interval


func _process(delta: float) -> void:
	_bob_t += delta * bob_speed
	var bob_y: float = sin(_bob_t) * bob_extra_height
	global_position.y = _base_floor_y + hover_height + _hover_push_offset + bob_y

	if is_instance_valid(body_mesh):
		body_mesh.position = _body_base_pos
		body_mesh.rotate_y(body_spin_speed * delta)

	if is_instance_valid(muzzle):
		muzzle.position = _muzzle_base_pos

	if is_instance_valid(ray_origin):
		ray_origin.position = _ray_base_pos


func set_target(t: Node3D) -> void:
	target = t


func set_bullet_scene(ps: PackedScene) -> void:
	bullet_scene = ps


func set_fire_interval(v: float) -> void:
	fire_interval = maxf(v, 0.05)
	_choose_new_fire_pattern()


func add_knockback(v: Vector3) -> void:
	_knock += Vector3(v.x, 0.0, v.z)


func apply_push(forward: Vector3, strength: float, lift: float, stun_seconds: float) -> void:
	var flat_forward: Vector3 = Vector3(forward.x, 0.0, forward.z)
	if flat_forward.length() > 0.001:
		_knock += flat_forward.normalized() * strength

	_stun_left = maxf(_stun_left, stun_seconds)
	_hover_push_offset = clampf(_hover_push_offset + minf(lift * 0.03, 0.22), -1.0, 0.35)

	_last_push_stun = stun_seconds
	_push_collision_time_left = push_collision_window
	_push_collision_used = false

	_enter_wander()


func apply_impact_stun(stun_seconds: float, impact_dir: Vector3 = Vector3.ZERO, impact_knock: float = 0.0) -> void:
	_stun_left = maxf(_stun_left, stun_seconds)

	var flat_dir: Vector3 = Vector3(impact_dir.x, 0.0, impact_dir.z)
	if flat_dir.length() > 0.001 and impact_knock > 0.0:
		_knock += flat_dir.normalized() * impact_knock

	_push_collision_time_left = 0.0
	_push_collision_used = true

	_enter_wander()


func _physics_process(delta: float) -> void:
	if _push_collision_time_left > 0.0:
		_push_collision_time_left = maxf(_push_collision_time_left - delta, 0.0)

	_hover_push_offset = move_toward(_hover_push_offset, 0.0, delta * 1.8)

	if _stun_left > 0.0:
		_cancel_telegraph()
		_stun_left = maxf(_stun_left - delta, 0.0)
		_update_motion(delta, Vector3.ZERO)
		_try_push_enemy_collision()
		return

	_update_ai(delta)
	_try_push_enemy_collision()


func _update_ai(delta: float) -> void:
	var sees_player: bool = _can_see_target()

	match _state:
		AIState.WANDER:
			_wander_change_left -= delta
			if _wander_change_left <= 0.0:
				_pick_new_wander_dir()

			if sees_player:
				_enter_alert()
				_update_motion(delta, Vector3.ZERO)
				return

			_update_motion(delta, _wander_dir * drift_speed)

		AIState.ALERT:
			_update_motion(delta, Vector3.ZERO)

			if not sees_player:
				_enter_wander()
				return

			_state_timer -= delta
			if _state_timer <= 0.0:
				_enter_engage()

		AIState.ENGAGE:
			if not sees_player:
				_enter_wander()
				return

			_wander_change_left -= delta
			if _wander_change_left <= 0.0:
				_pick_new_wander_dir()

			var engage_velocity: Vector3 = _wander_dir * drift_speed
			if _telegraph_left > 0.0:
				engage_velocity *= 0.35

			_update_motion(delta, engage_velocity)

			if _telegraph_left > 0.0:
				_telegraph_left = maxf(_telegraph_left - delta, 0.0)
				_update_telegraph_visual()
				if _telegraph_left <= 0.0:
					_shoot_at_target()
					_after_shot()
					_cancel_telegraph()
				return

			_fire_left -= delta
			if _fire_left <= 0.0:
				_begin_telegraph()


func _enter_wander() -> void:
	_cancel_telegraph()
	_state = AIState.WANDER
	_state_timer = 0.0
	_pick_new_wander_dir()


func _enter_alert() -> void:
	_cancel_telegraph()
	_state = AIState.ALERT
	_state_timer = alert_pause


func _enter_engage() -> void:
	_state = AIState.ENGAGE

	if _pattern_shots_left <= 0:
		_choose_new_fire_pattern()

	_fire_left = minf(_current_fire_interval, first_shot_delay_after_alert)


func _after_shot() -> void:
	_pattern_shots_left -= 1
	if _pattern_shots_left <= 0:
		_choose_new_fire_pattern()

	_fire_left = _current_fire_interval


func _begin_telegraph() -> void:
	_telegraph_left = telegraph_time
	_update_telegraph_visual()


func _choose_new_fire_pattern() -> void:
	var min_interval: float = maxf(0.08, fire_interval * fire_interval_min_mult)
	var max_interval: float = maxf(min_interval + 0.01, fire_interval * fire_interval_max_mult)

	_current_fire_interval = randf_range(min_interval, max_interval)
	_pattern_shots_left = randi_range(
		min(shots_per_pattern_min, shots_per_pattern_max),
		max(shots_per_pattern_min, shots_per_pattern_max)
	)


func _update_motion(delta: float, desired_velocity: Vector3) -> void:
	var target_x: float = desired_velocity.x + _knock.x
	var target_z: float = desired_velocity.z + _knock.z

	velocity.x = lerpf(velocity.x, target_x, minf(drift_response * delta, 1.0))
	velocity.z = lerpf(velocity.z, target_z, minf(drift_response * delta, 1.0))
	velocity.y = 0.0

	_knock = _knock.move_toward(Vector3.ZERO, knock_decay * delta)

	move_and_slide()

	global_position.y = _base_floor_y + hover_height + _hover_push_offset + sin(_bob_t) * bob_extra_height

	if _state == AIState.WANDER or _state == AIState.ENGAGE:
		for i in range(get_slide_collision_count()):
			var col: KinematicCollision3D = get_slide_collision(i)
			var other := col.get_collider()
			if other == null or other == self:
				continue
			if other is Node and (other as Node).is_in_group("enemy"):
				continue
			_pick_new_wander_dir()
			break


func _pick_new_wander_dir() -> void:
	_wander_change_left = randf_range(drift_change_min, drift_change_max)

	if randf() < idle_chance:
		_wander_dir = Vector3.ZERO
		return

	var angle: float = randf_range(0.0, TAU)
	_wander_dir = Vector3(cos(angle), 0.0, sin(angle)).normalized()


func _can_see_target() -> bool:
	if target == null or not is_instance_valid(target):
		return false

	var origin: Vector3 = global_position
	if is_instance_valid(ray_origin):
		origin = ray_origin.global_position

	var target_pos: Vector3 = _get_target_aim_point()
	var to_target: Vector3 = target_pos - origin

	if to_target.length() > view_distance:
		return false
	if to_target.length() <= 0.001:
		return true

	var query := PhysicsRayQueryParameters3D.create(origin, target_pos)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [self]

	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false

	var collider: Object = hit.get("collider", null)
	if collider == null:
		return false

	if collider == target:
		return true

	if collider is Node and (collider as Node).is_in_group("player"):
		return true

	return false


func _shoot_at_target() -> void:
	if bullet_scene == null:
		return
	if target == null or not is_instance_valid(target):
		return
	if not _can_see_target():
		return

	var bullet := bullet_scene.instantiate()
	if bullet == null:
		return

	var parent_node: Node = _get_bullet_parent()
	parent_node.add_child(bullet)

	var origin: Vector3 = global_position + Vector3(0.0, 0.1, 0.0)
	if is_instance_valid(muzzle):
		origin = muzzle.global_position

	var target_pos: Vector3 = _get_target_aim_point()
	var dir: Vector3 = target_pos - origin
	if dir.length() <= 0.001:
		dir = Vector3.FORWARD
	else:
		dir = dir.normalized()

	if bullet.has_method("fire"):
		bullet.fire(origin, dir, bullet_speed, self)


func _get_bullet_parent() -> Node:
	var current := get_tree().current_scene
	if current != null and current.has_node("World"):
		return current.get_node("World")
	if current != null:
		return current
	return get_parent()


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

		apply_impact_stun(impact_stun)

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


func _get_target_aim_point() -> Vector3:
	if target == null or not is_instance_valid(target):
		return global_position + Vector3(0.0, 0.55, 0.0)

	var aim_target: Node3D = target.get_node_or_null("Head/AimTarget") as Node3D
	if aim_target == null:
		aim_target = target.get_node_or_null("AimTarget") as Node3D

	if aim_target != null:
		return aim_target.global_position

	return target.global_position + Vector3(0.0, 0.55, 0.0)


func _update_telegraph_visual() -> void:
	if not is_instance_valid(sprite_visual):
		return

	var elapsed: float = maxf(telegraph_time - _telegraph_left, 0.0)
	var pulse: float = 0.5 + 0.5 * sin(elapsed * telegraph_flash_speed * TAU)
	var boost: float = 1.0 + pulse * telegraph_flash_amount
	sprite_visual.modulate = Color(
		_sprite_base_modulate.r * boost,
		_sprite_base_modulate.g * boost,
		_sprite_base_modulate.b * boost,
		_sprite_base_modulate.a
	)


func _cancel_telegraph() -> void:
	_telegraph_left = 0.0
	if is_instance_valid(sprite_visual):
		sprite_visual.modulate = _sprite_base_modulate
