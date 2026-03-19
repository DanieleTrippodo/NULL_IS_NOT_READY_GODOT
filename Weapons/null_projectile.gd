# res://Weapons/null_projectile.gd
extends Area3D

enum State { FIRED, DROPPED }

@onready var pickup_indicator: Sprite3D = $PickupIndicator
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var projectile_mesh: MeshInstance3D = $MeshInstance3D

var state: int = State.FIRED
var velocity: Vector3 = Vector3.ZERO
var traveled: float = 0.0
var t: float = 0.0

var bounces_left: int = 0
var pierce_left: int = 0
var size_mult: float = 1.0
var range_mult: float = 1.0

var _recent_hit: Dictionary = {} # instance_id -> seconds_left
const RECENT_HIT_TIME: float = 0.07

const MIN_SEGMENT_LEN: float = 0.12
const MAX_SUBSTEPS: int = 10
const HIT_NUDGE: float = 0.05

@export_group("Ghost Afterimages")
@export var ghost_enabled: bool = true
@export_range(0.001, 0.2, 0.001) var ghost_spawn_interval: float = 0.025
@export_range(0.01, 1.0, 0.01) var ghost_lifetime: float = 0.14
@export_range(0.1, 3.0, 0.01) var ghost_scale_mult: float = 1.0
@export_range(0.1, 3.0, 0.01) var ghost_end_scale_mult: float = 0.65
@export_range(0.0, 1.0, 0.01) var ghost_alpha: float = 0.55
@export_range(0.0, 1.0, 0.01) var ghost_alpha_min: float = 0.25
@export_range(0.0, 1.0, 0.01) var ghost_alpha_max: float = 0.55

@export_group("Remote Recovery")
@export var recovery_pull_speed_min: float = 1.7
@export var recovery_pull_speed_max: float = 6.0
@export var recovery_accel_time: float = 5.0
@export var recovery_pickup_radius: float = 1.0

@export_group("Stealer Ricochet")
@export var stealer_ricochet_time: float = 0.10
@export var stealer_ricochet_speed_mult: float = 0.9

@export_group("Boss Interactions")
@export var body_reflect_speed_mult: float = 0.95

var _ghost_timer: float = 0.0

var _remote_recovering: bool = false
var _recovery_target: Node3D = null
var _recovery_hold_time: float = 0.0

var _pending_drop_after_ricochet: bool = false
var _ricochet_drop_left: float = 0.0

var _pickup_indicator_base_scale: Vector3 = Vector3.ONE
var _thread_line_mesh: MeshInstance3D = null
var _thread_line_immediate: ImmediateMesh = null
var _thread_line_material: StandardMaterial3D = null
var _pulse_tween: Tween = null

func _ready() -> void:
	if pickup_indicator != null:
		_pickup_indicator_base_scale = pickup_indicator.scale
	_ensure_thread_lock_visuals()
	_set_thread_lock_visible(false)


func is_dropped() -> bool:
	return state == State.DROPPED


func start_remote_recovery(target: Node3D) -> void:
	if state != State.DROPPED:
		return
	if target == null:
		return

	_remote_recovering = true
	_recovery_target = target
	_recovery_hold_time = 0.0
	Signals.recovery_mode_changed.emit(true)


func stop_remote_recovery() -> void:
	if not _remote_recovering:
		return

	_remote_recovering = false
	_recovery_target = null
	_recovery_hold_time = 0.0
	Signals.recovery_mode_changed.emit(false)


func fire(origin: Vector3, direction: Vector3, size_mult_in: float = 1.0) -> void:
	var dir: Vector3 = direction.normalized()

	# In survival: ignore charge/size perk
	size_mult = max(0.25, size_mult_in)
	scale = Vector3.ONE * size_mult

	global_position = origin + dir * (0.6 + 0.25 * size_mult)

	# In survival: perks ignored
	var spd_mult: float = 1.0 if Run.survival_mode else Run.null_speed_mult
	velocity = dir * (Constants.NULL_SPEED * spd_mult)

	state = State.FIRED
	traveled = 0.0
	t = 0.0
	_ghost_timer = 0.0

	_remote_recovering = false
	_recovery_target = null
	_recovery_hold_time = 0.0

	_pending_drop_after_ricochet = false
	_ricochet_drop_left = 0.0

	bounces_left = 0 if Run.survival_mode else Run.null_bounces
	pierce_left = 0 if Run.survival_mode else Run.null_pierce
	range_mult = 1.0 if Run.survival_mode else Run.null_range_mult

	if pickup_indicator != null:
		pickup_indicator.visible = false
		pickup_indicator.scale = _pickup_indicator_base_scale
	_set_thread_lock_visible(false)


func _physics_process(delta: float) -> void:
	t += delta

	if not _recent_hit.is_empty():
		var keys: Array = _recent_hit.keys()
		for k in keys:
			_recent_hit[k] = float(_recent_hit[k]) - delta
			if float(_recent_hit[k]) <= 0.0:
				_recent_hit.erase(k)

	if _pending_drop_after_ricochet:
		_ricochet_drop_left -= delta
		if _ricochet_drop_left <= 0.0:
			_drop()
			return

	if state == State.DROPPED:
		_update_thread_lock_visual()
		if pickup_indicator != null:
			pickup_indicator.position.y = 0.7 + sin(t * 6.0) * 0.08

		if _remote_recovering:
			if _recovery_target == null or not is_instance_valid(_recovery_target):
				stop_remote_recovery()
				return

			var target_pos: Vector3 = _recovery_target.global_position
			var to_target: Vector3 = target_pos - global_position
			var dist: float = to_target.length()

			if dist <= recovery_pickup_radius:
				stop_remote_recovery()
				Run.null_ready = true
				Run.null_dropped = false
				Signals.null_ready_changed.emit(true)
				pickup()
				return

			if dist > 0.0001:
				_recovery_hold_time += delta

				var accel_div: float = maxf(recovery_accel_time * (Run.overclock_accel_time_mult if Run.overclock else 1.0), 0.05)
				var accel_t: float = clamp(_recovery_hold_time / accel_div, 0.0, 1.0)
				var speed_mult: float = Run.overclock_pull_speed_mult if Run.overclock else 1.0
				var current_speed: float = lerp(recovery_pull_speed_min * speed_mult, recovery_pull_speed_max * speed_mult, accel_t)

				var pull_step: float = current_speed * delta
				global_position += to_target.normalized() * min(pull_step, dist)

		return

	_update_ghost_afterimages(delta)
	_apply_homing(delta)

	if _try_hit_enemy_at(global_position):
		return

	var step: Vector3 = velocity * delta
	var step_len: float = step.length()
	if step_len <= 0.00001:
		return

	var substeps: int = _compute_substeps(step_len)
	var seg: Vector3 = step / float(substeps)

	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state

	for _i in range(substeps):
		var from_pos: Vector3 = global_position
		var to_pos: Vector3 = from_pos + seg

		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from_pos, to_pos)
		query.exclude = [get_rid()]
		query.collide_with_areas = false
		query.collide_with_bodies = true

		var hit: Dictionary = space.intersect_ray(query)
		if hit.size() > 0:
			var hit_pos: Vector3 = hit["position"]
			var hit_n: Vector3 = hit.get("normal", Vector3.UP)
			var collider: Object = hit.get("collider", null)

			traveled += from_pos.distance_to(hit_pos)
			global_position = hit_pos

			var hit_node: Node = _as_node(collider)
			if _is_null_passthrough(hit_node):
				global_position = hit_pos + seg.normalized() * HIT_NUDGE
				continue

			var enemy_node: Node = _find_enemy_node(collider)
			if enemy_node != null:
				if _handle_enemy_hit(enemy_node):
					return
				global_position = hit_pos + velocity.normalized() * HIT_NUDGE
				continue

			if _is_boss_reflector(hit_node):
				velocity = velocity.bounce(hit_n) * body_reflect_speed_mult
				global_position = hit_pos + hit_n * HIT_NUDGE
				return

			if bounces_left > 0:
				bounces_left -= 1
				velocity = velocity.bounce(hit_n)
				global_position = hit_pos + hit_n * HIT_NUDGE
				return

			_drop()
			return

		global_position = to_pos
		traveled += seg.length()

		if _try_hit_enemy_at(global_position):
			return

	if traveled >= (Constants.NULL_MAX_DISTANCE * range_mult):
		_drop()


func _apply_homing(delta: float) -> void:
	if not Run.homing_nudge:
		return

	var speed: float = velocity.length()
	if speed <= 0.00001:
		return

	var current_dir: Vector3 = velocity / speed
	var target: Node3D = _find_nearest_enemy()
	if target == null:
		return

	var to: Vector3 = target.global_position - global_position
	if to.length_squared() <= 0.00001:
		return
	var desired_dir: Vector3 = to.normalized()

	var dotv: float = clampf(current_dir.dot(desired_dir), -1.0, 1.0)
	var angle: float = acos(dotv)
	var max_angle: float = deg_to_rad(Run.homing_max_angle_deg)
	if angle > max_angle:
		return

	var tturn: float = clampf(Run.homing_turn_speed * delta, 0.0, 1.0)
	var new_dir: Vector3 = current_dir.slerp(desired_dir, tturn).normalized()
	velocity = new_dir * speed


func _find_nearest_enemy() -> Node3D:
	var best: Node3D = null
	var best_d2: float = INF

	for n in get_tree().get_nodes_in_group("enemy"):
		if not (n is Node3D):
			continue
		var e: Node3D = n as Node3D
		var iid: int = e.get_instance_id()
		if _recent_hit.has(iid):
			continue
		var d2: float = e.global_position.distance_squared_to(global_position)
		if d2 < best_d2:
			best_d2 = d2
			best = e

	return best


func _compute_substeps(step_len: float) -> int:
	var base_r: float = 0.25
	if collision_shape != null and collision_shape.shape is SphereShape3D:
		base_r = (collision_shape.shape as SphereShape3D).radius

	var world_scale_x: float = global_transform.basis.get_scale().x
	var r: float = max(0.05, base_r * world_scale_x)
	var seg_len: float = max(MIN_SEGMENT_LEN, r * 0.75)

	return clampi(ceili(step_len / seg_len), 1, MAX_SUBSTEPS)


func _try_hit_enemy_at(pos: Vector3) -> bool:
	if collision_shape == null or collision_shape.shape == null:
		return false

	var w: World3D = get_world_3d()
	if w == null:
		return false

	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = collision_shape.shape

	var xform: Transform3D = global_transform
	xform.origin = pos
	params.transform = xform

	params.exclude = [get_rid()]
	params.collide_with_areas = false
	params.collide_with_bodies = true

	var hits: Array = w.direct_space_state.intersect_shape(params, 8)
	for h in hits:
		if typeof(h) != TYPE_DICTIONARY:
			continue
		var collider: Object = (h as Dictionary).get("collider", null)
		var enemy_node: Node = _find_enemy_node(collider)
		if enemy_node != null:
			if _handle_enemy_hit(enemy_node):
				return true
			global_position += velocity.normalized() * HIT_NUDGE
			return false

	return false


func _handle_enemy_hit(enemy_node: Node) -> bool:
	if enemy_node == null:
		return false

	var iid: int = enemy_node.get_instance_id()
	if _recent_hit.has(iid):
		return false

	_recent_hit[iid] = RECENT_HIT_TIME

	# Special case: Stealer -> real ricochet for a moment, then drop
	if enemy_node.is_in_group("stealer"):
		var bounce_vel: Vector3 = velocity
		if bounce_vel.length() <= 0.001:
			bounce_vel = -global_transform.basis.z * Constants.NULL_SPEED

		var normal: Vector3 = global_position - (enemy_node as Node3D).global_position
		normal.y = 0.0

		if normal.length() <= 0.001:
			normal = -bounce_vel
			normal.y = 0.0

		if normal.length() <= 0.001:
			normal = Vector3.BACK
		else:
			normal = normal.normalized()

		var bounced: Vector3 = bounce_vel.bounce(normal)
		if bounced.length() <= 0.001:
			bounced = normal * bounce_vel.length()

		velocity = bounced.normalized() * maxf(
			bounce_vel.length() * stealer_ricochet_speed_mult,
			Constants.NULL_SPEED * 0.55
		)

		global_position += normal * HIT_NUDGE

		_pending_drop_after_ricochet = true
		_ricochet_drop_left = stealer_ricochet_time
		return false

	Signals.enemy_killed.emit(enemy_node)

	if is_queued_for_deletion():
		return true

	if pierce_left > 0:
		pierce_left -= 1
		return false

	Signals.null_ready_changed.emit(true)
	queue_free()
	return true


func _find_enemy_node(collider: Object) -> Node:
	if collider == null or not (collider is Node):
		return null

	var n: Node = collider as Node
	while n != null:
		if n.is_in_group("enemy"):
			return n
		n = n.get_parent()

	return null


func _as_node(obj: Object) -> Node:
	if obj == null or not (obj is Node):
		return null
	return obj as Node


func _is_null_passthrough(node: Node) -> bool:
	var n: Node = node
	while n != null:
		if n.is_in_group("null_passthrough"):
			return true
		n = n.get_parent()
	return false


func _is_boss_reflector(node: Node) -> bool:
	var n: Node = node
	while n != null:
		if n.is_in_group("boss_reflector"):
			return true
		n = n.get_parent()
	return false


func _drop() -> void:
	_remote_recovering = false
	_recovery_target = null
	_recovery_hold_time = 0.0

	_pending_drop_after_ricochet = false
	_ricochet_drop_left = 0.0

	state = State.DROPPED
	velocity = Vector3.ZERO
	global_position.y += 0.05
	_ghost_timer = 0.0

	if pickup_indicator != null:
		pickup_indicator.visible = true
		pickup_indicator.position.y = 0.7
		pickup_indicator.scale = _pickup_indicator_base_scale

	_apply_drop_upgrades()
	_update_thread_lock_visual()

	Signals.null_dropped.emit(global_position)
	Signals.null_ready_changed.emit(false)


func pickup() -> void:
	stop_remote_recovery()
	_set_thread_lock_visible(false)
	_apply_pickup_upgrades()
	if pickup_indicator != null:
		pickup_indicator.visible = false
		pickup_indicator.scale = _pickup_indicator_base_scale
	_ghost_timer = 0.0
	queue_free()


func _apply_drop_upgrades() -> void:
	var used_pulse: bool = false

	if Run.impact_pulse:
		used_pulse = true
		for enemy in _get_enemies_in_radius(global_position, Run.impact_pulse_radius):
			var dir: Vector3 = (enemy.global_position - global_position)
			dir.y = 0.0
			if dir.length() <= 0.001:
				dir = Vector3.FORWARD
			else:
				dir = dir.normalized()

			if enemy.has_method("apply_impact_stun"):
				enemy.call("apply_impact_stun", Run.impact_pulse_stun, dir, Run.impact_pulse_strength)
			elif enemy.has_method("apply_push"):
				enemy.call("apply_push", dir, Run.impact_pulse_strength, 0.0, Run.impact_pulse_stun)

	if Run.ground_echo:
		used_pulse = true
		for enemy in _get_enemies_in_radius(global_position, Run.ground_echo_radius):
			_ping_enemy_visual(enemy, Run.ground_echo_flash_time)

	if used_pulse:
		_play_pickup_indicator_pulse(1.75, 0.16)


func _apply_pickup_upgrades() -> void:
	if not Run.null_freeze:
		return

	for enemy in _get_enemies_in_radius(global_position, Run.null_freeze_radius):
		var dir: Vector3 = (enemy.global_position - global_position)
		dir.y = 0.0
		if dir.length() <= 0.001:
			dir = Vector3.FORWARD
		else:
			dir = dir.normalized()

		if enemy.has_method("apply_impact_stun"):
			enemy.call("apply_impact_stun", Run.null_freeze_stun, dir, 0.0)
		elif enemy.has_method("apply_push"):
			enemy.call("apply_push", dir, 0.0, 0.0, Run.null_freeze_stun)

		_ping_enemy_visual(enemy, 0.14)


func _get_enemies_in_radius(center: Vector3, radius: float) -> Array[Node3D]:
	var result: Array[Node3D] = []
	var r2: float = radius * radius
	for n in get_tree().get_nodes_in_group("enemy"):
		if not (n is Node3D):
			continue
		var e := n as Node3D
		if not is_instance_valid(e):
			continue
		if e.global_position.distance_squared_to(center) <= r2:
			result.append(e)
	return result


func _ping_enemy_visual(enemy: Node3D, duration: float) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return

	var mesh_node := enemy.find_child("MeshInstance3D", true, false)
	if mesh_node == null or not (mesh_node is MeshInstance3D):
		return

	var mesh := mesh_node as MeshInstance3D
	var prev_mat: Material = mesh.material_override

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1, 1, 1, 0.95)
	mat.emission_enabled = true
	mat.emission = Color(1, 1, 1)
	mesh.material_override = mat

	var tween := enemy.create_tween()
	tween.tween_property(mat, "albedo_color", Color(1, 1, 1, 0.0), duration)
	tween.tween_callback(func():
		if is_instance_valid(mesh):
			mesh.material_override = prev_mat
	)


func _play_pickup_indicator_pulse(scale_mult: float, duration: float) -> void:
	if pickup_indicator == null:
		return
	if is_instance_valid(_pulse_tween):
		_pulse_tween.kill()
	pickup_indicator.scale = _pickup_indicator_base_scale
	_pulse_tween = create_tween()
	_pulse_tween.set_trans(Tween.TRANS_QUAD)
	_pulse_tween.set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_property(pickup_indicator, "scale", _pickup_indicator_base_scale * scale_mult, duration * 0.45)
	_pulse_tween.tween_property(pickup_indicator, "scale", _pickup_indicator_base_scale, duration * 0.55)


func _ensure_thread_lock_visuals() -> void:
	if _thread_line_mesh != null and is_instance_valid(_thread_line_mesh):
		return

	_thread_line_mesh = MeshInstance3D.new()
	_thread_line_mesh.name = "ThreadLockLine"
	_thread_line_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_thread_line_mesh.top_level = true

	_thread_line_immediate = ImmediateMesh.new()
	_thread_line_mesh.mesh = _thread_line_immediate

	_thread_line_material = StandardMaterial3D.new()
	_thread_line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_thread_line_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_thread_line_material.albedo_color = Color(1, 1, 1, 0.55)
	_thread_line_material.emission_enabled = true
	_thread_line_material.emission = Color(1, 1, 1)
	_thread_line_material.no_depth_test = true

	add_child(_thread_line_mesh)


func _set_thread_lock_visible(visible_now: bool) -> void:
	if _thread_line_mesh != null and is_instance_valid(_thread_line_mesh):
		_thread_line_mesh.visible = visible_now


func _update_thread_lock_visual() -> void:
	if not Run.thread_lock or state != State.DROPPED:
		_set_thread_lock_visible(false)
		return

	var player := get_tree().get_first_node_in_group("player")
	if player == null or not (player is Node3D):
		_set_thread_lock_visible(false)
		return

	_ensure_thread_lock_visuals()
	_set_thread_lock_visible(true)

	var start_pos: Vector3 = global_position + Vector3(0.0, 0.12, 0.0)
	var end_pos: Vector3 = (player as Node3D).global_position + Vector3(0.0, 0.95, 0.0)
	var alpha: float = 0.35 + 0.2 * (0.5 + 0.5 * sin(t * 8.0))
	_thread_line_material.albedo_color = Color(1, 1, 1, alpha)

	if pickup_indicator != null:
		pickup_indicator.scale = _pickup_indicator_base_scale * (1.0 + 0.08 * (0.5 + 0.5 * sin(t * 8.0)))

	_thread_line_immediate.clear_surfaces()
	_thread_line_immediate.surface_begin(Mesh.PRIMITIVE_LINES, _thread_line_material)
	_thread_line_immediate.surface_add_vertex(start_pos)
	_thread_line_immediate.surface_add_vertex(end_pos)
	_thread_line_immediate.surface_end()


func _update_ghost_afterimages(delta: float) -> void:
	if not ghost_enabled:
		return
	if state != State.FIRED:
		return
	if not is_instance_valid(projectile_mesh):
		return

	_ghost_timer += delta
	if _ghost_timer < ghost_spawn_interval:
		return

	_ghost_timer = 0.0
	_spawn_ghost_afterimage()


func _spawn_ghost_afterimage() -> void:
	if not is_instance_valid(projectile_mesh):
		return
	if get_tree() == null or get_tree().current_scene == null:
		return

	var ghost := MeshInstance3D.new()
	ghost.mesh = projectile_mesh.mesh
	ghost.global_transform = projectile_mesh.global_transform
	ghost.scale = projectile_mesh.scale * ghost_scale_mult
	ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var ghost_mat: Material = null
	var start_alpha: float = randf_range(ghost_alpha_min, ghost_alpha_max)

	if projectile_mesh.material_override != null:
		ghost_mat = projectile_mesh.material_override.duplicate(true)
		ghost.material_override = ghost_mat
	elif projectile_mesh.get_surface_override_material_count() > 0:
		var src_mat: Material = projectile_mesh.get_surface_override_material(0)
		if src_mat != null:
			ghost_mat = src_mat.duplicate(true)
			ghost.set_surface_override_material(0, ghost_mat)

	get_tree().current_scene.add_child(ghost)

	var end_scale: Vector3 = ghost.scale * ghost_end_scale_mult
	var tween: Tween = ghost.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ghost, "scale", end_scale, ghost_lifetime)

	if ghost_mat is StandardMaterial3D:
		var sm: StandardMaterial3D = ghost_mat as StandardMaterial3D
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var c: Color = sm.albedo_color
		sm.albedo_color = Color(c.r, c.g, c.b, start_alpha)
		tween.tween_property(sm, "albedo_color", Color(c.r, c.g, c.b, 0.0), ghost_lifetime)
	elif ghost_mat is BaseMaterial3D:
		var bm: BaseMaterial3D = ghost_mat as BaseMaterial3D
		bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var c2: Color = bm.albedo_color
		bm.albedo_color = Color(c2.r, c2.g, c2.b, start_alpha)
		tween.tween_property(bm, "albedo_color", Color(c2.r, c2.g, c2.b, 0.0), ghost_lifetime)
	else:
		ghost.transparency = 1.0 - start_alpha
		tween.tween_property(ghost, "transparency", 1.0, ghost_lifetime)

	tween.chain().tween_callback(Callable(ghost, "queue_free"))
