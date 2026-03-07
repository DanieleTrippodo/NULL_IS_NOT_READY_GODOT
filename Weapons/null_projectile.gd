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
@export_range(0.1, 1.0, 0.01) var ghost_end_scale_mult: float = 0.65
@export_range(0.0, 1.0, 0.01) var ghost_alpha: float = 0.55
@export_range(0.0, 1.0, 0.01) var ghost_alpha_min: float = 0.25
@export_range(0.0, 1.0, 0.01) var ghost_alpha_max: float = 0.55

var _ghost_timer: float = 0.0

func is_dropped() -> bool:
	return state == State.DROPPED

func fire(origin: Vector3, direction: Vector3, size_mult_in: float = 1.0) -> void:
	var dir: Vector3 = direction.normalized()

	# In survival: ignora charge/size perk (ma tu già invii size_mult=1 dal player)
	size_mult = max(0.25, size_mult_in)
	scale = Vector3.ONE * size_mult

	global_position = origin + dir * (0.6 + 0.25 * size_mult)

	# In survival: perk ignorati
	var spd_mult := 1.0 if Run.survival_mode else Run.null_speed_mult
	velocity = dir * (Constants.NULL_SPEED * spd_mult)

	state = State.FIRED
	traveled = 0.0
	t = 0.0
	_ghost_timer = 0.0

	bounces_left = 0 if Run.survival_mode else Run.null_bounces
	pierce_left = 0 if Run.survival_mode else Run.null_pierce
	range_mult = 1.0 if Run.survival_mode else Run.null_range_mult

	pickup_indicator.visible = false

func _physics_process(delta: float) -> void:
	t += delta

	if not _recent_hit.is_empty():
		var keys := _recent_hit.keys()
		for k in keys:
			_recent_hit[k] = float(_recent_hit[k]) - delta
			if float(_recent_hit[k]) <= 0.0:
				_recent_hit.erase(k)

	if state == State.DROPPED:
		pickup_indicator.position.y = 0.7 + sin(t * 6.0) * 0.08
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

	var space := get_world_3d().direct_space_state

	for _i in range(substeps):
		var from_pos: Vector3 = global_position
		var to_pos: Vector3 = from_pos + seg

		var query := PhysicsRayQueryParameters3D.create(from_pos, to_pos)
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

			var enemy_node: Node = _find_enemy_node(collider)
			if enemy_node != null:
				if _handle_enemy_hit(enemy_node):
					return
				global_position = hit_pos + velocity.normalized() * HIT_NUDGE
				continue

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

	var speed := velocity.length()
	if speed <= 0.00001:
		return

	var current_dir := velocity / speed
	var target := _find_nearest_enemy()
	if target == null:
		return

	var to := (target.global_position - global_position)
	if to.length_squared() <= 0.00001:
		return
	var desired_dir := to.normalized()

	var dotv: float = clampf(current_dir.dot(desired_dir), -1.0, 1.0)
	var angle := acos(dotv)
	var max_angle := deg_to_rad(Run.homing_max_angle_deg)
	if angle > max_angle:
		return

	var tturn: float = clampf(Run.homing_turn_speed * delta, 0.0, 1.0)
	var new_dir := current_dir.slerp(desired_dir, tturn).normalized()
	velocity = new_dir * speed

func _find_nearest_enemy() -> Node3D:
	var best: Node3D = null
	var best_d2 := INF

	for n in get_tree().get_nodes_in_group("enemy"):
		if not (n is Node3D):
			continue
		var e := n as Node3D
		var iid := e.get_instance_id()
		if _recent_hit.has(iid):
			continue
		var d2 := e.global_position.distance_squared_to(global_position)
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

	var w := get_world_3d()
	if w == null:
		return false

	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = collision_shape.shape

	var xform := global_transform
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

	var iid := enemy_node.get_instance_id()
	if _recent_hit.has(iid):
		return false

	_recent_hit[iid] = RECENT_HIT_TIME
	Signals.enemy_killed.emit(enemy_node)

	# se durante il segnale qualcuno ha già chiamato pickup()/queue_free(), fermati.
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

func _drop() -> void:
	state = State.DROPPED
	velocity = Vector3.ZERO
	global_position.y += 0.05
	_ghost_timer = 0.0

	pickup_indicator.visible = true
	pickup_indicator.position.y = 0.7

	Signals.null_dropped.emit(global_position)
	Signals.null_ready_changed.emit(false)

func pickup() -> void:
	pickup_indicator.visible = false
	_ghost_timer = 0.0
	queue_free()

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
	var _start_alpha: float = randf_range(ghost_alpha_min, ghost_alpha_max)

	if projectile_mesh.material_override != null:
		ghost_mat = projectile_mesh.material_override.duplicate(true)
		ghost.material_override = ghost_mat
	elif projectile_mesh.get_surface_override_material_count() > 0:
		var src_mat := projectile_mesh.get_surface_override_material(0)
		if src_mat != null:
			ghost_mat = src_mat.duplicate(true)
			ghost.set_surface_override_material(0, ghost_mat)

	get_tree().current_scene.add_child(ghost)

	var end_scale: Vector3 = ghost.scale * ghost_end_scale_mult
	var tween := ghost.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ghost, "scale", end_scale, ghost_lifetime)

	if ghost_mat is StandardMaterial3D:
		var sm := ghost_mat as StandardMaterial3D
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var c := sm.albedo_color
		sm.albedo_color = Color(c.r, c.g, c.b, ghost_alpha)
		tween.tween_property(sm, "albedo_color", Color(c.r, c.g, c.b, 0.0), ghost_lifetime)
	elif ghost_mat is BaseMaterial3D:
		var bm := ghost_mat as BaseMaterial3D
		bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var c2 := bm.albedo_color
		bm.albedo_color = Color(c2.r, c2.g, c2.b, ghost_alpha)
		tween.tween_property(bm, "albedo_color", Color(c2.r, c2.g, c2.b, 0.0), ghost_lifetime)
	else:
		ghost.transparency = 1.0 - ghost_alpha
		tween.tween_property(ghost, "transparency", 1.0, ghost_lifetime)

	get_tree().create_timer(ghost_lifetime).timeout.connect(
		func():
			if is_instance_valid(ghost):
				ghost.queue_free()
	)
