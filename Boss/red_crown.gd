extends Node3D

signal weak_point_hit(hit_count: int)

@export var bullet_scene: PackedScene = preload("res://Boss/boss_bullet.tscn")

@export_group("General")
@export var death_shrink_time: float = 1.2
@export var base_rotation_speed: float = 0.9
@export var vulnerable_glow_alpha: float = 0.95

@export_group("Phase 1")
@export var phase_1_pattern_interval: float = 1.15
@export var phase_1_bullet_speed_mult: float = 1.0

@export_group("Phase 2")
@export var phase_2_pattern_interval: float = 0.9
@export var phase_2_bullet_speed_mult: float = 1.12

@export_group("Phase 3")
@export var phase_3_pattern_interval: float = 0.68
@export var phase_3_bullet_speed_mult: float = 1.24

@export_group("Fan Burst")
@export var fan_burst_count: int = 13
@export var fan_burst_angle_deg: float = 76.0
@export var fan_burst_speed: float = 16.8
@export var fan_prediction: float = 0.30

@export_group("Rotating Spread")
@export var rotating_spread_count: int = 12
@export var rotating_spread_speed: float = 14.8
@export var rotating_offset_step_deg: float = 18.0

@export_group("Lane Sweep")
@export var lane_sweep_rows: int = 8
@export var lane_sweep_speed: float = 18.0
@export var lane_safe_padding: float = 0.42

@onready var visuals: Node3D = $Visuals
@onready var body_closed: Sprite3D = $Visuals/BodyClosed
@onready var body_open: Sprite3D = $Visuals/BodyOpen
@onready var weak_glow: MeshInstance3D = $Visuals/WeakGlow

@onready var reflector_body: StaticBody3D = $ReflectorBody
@onready var weak_point: StaticBody3D = $WeakPoint
@onready var weak_point_shape: CollisionShape3D = $WeakPoint/CollisionShape3D

@onready var muzzles: Node3D = $Muzzles
@onready var muzzle_center: Marker3D = $Muzzles/MuzzleCenter
@onready var muzzle_left: Marker3D = $Muzzles/MuzzleLeft
@onready var muzzle_right: Marker3D = $Muzzles/MuzzleRight

var player_ref: CharacterBody3D = null
var bullets_parent: Node3D = null
var arena_center: Vector3 = Vector3.ZERO
var arena_half_extents: Vector2 = Vector2(6.0, 6.0)

var attack_active: bool = false
var vulnerable: bool = false
var _dead: bool = false

var current_pattern: String = "fan_burst"
var current_phase: int = 1
var current_pattern_interval: float = 1.0
var current_bullet_speed_mult: float = 1.0
var attack_time_left: float = 0.0
var shot_cooldown_left: float = 0.0

var rotation_offset: float = 0.0
var rotating_cycle_index: int = 0
var lane_cycle_index: int = 0
var fan_cycle_index: int = 0
var last_safe_lane: int = -1

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()

	body_closed.visible = true
	body_open.visible = false
	weak_glow.visible = false

	if weak_point_shape != null:
		weak_point_shape.disabled = true

	_reset_visual_modulate()


func setup(p_player: CharacterBody3D, p_bullets_parent: Node3D, p_arena_center: Vector3, p_half_extents: Vector2) -> void:
	player_ref = p_player
	bullets_parent = p_bullets_parent
	arena_center = p_arena_center
	arena_half_extents = p_half_extents


func begin_attack(pattern: String, duration: float, phase: int) -> void:
	if _dead:
		return

	close_weak_point()

	attack_active = true
	current_pattern = pattern
	current_phase = clampi(phase, 1, 3)
	attack_time_left = maxf(duration, 0.0)

	match current_phase:
		1:
			current_pattern_interval = phase_1_pattern_interval
			current_bullet_speed_mult = phase_1_bullet_speed_mult
		2:
			current_pattern_interval = phase_2_pattern_interval
			current_bullet_speed_mult = phase_2_bullet_speed_mult
		3:
			current_pattern_interval = phase_3_pattern_interval
			current_bullet_speed_mult = phase_3_bullet_speed_mult

	shot_cooldown_left = 0.18
	rotating_cycle_index = 0
	lane_cycle_index = 0
	fan_cycle_index = 0


func stop_attack() -> void:
	attack_active = false
	attack_time_left = 0.0
	shot_cooldown_left = 0.0


func open_weak_point() -> void:
	if _dead:
		return

	stop_attack()
	vulnerable = true

	body_closed.visible = false
	body_open.visible = true
	weak_glow.visible = true

	if weak_point_shape != null:
		weak_point_shape.disabled = false

	_flash_open_state()


func close_weak_point() -> void:
	vulnerable = false

	body_closed.visible = true
	body_open.visible = false
	weak_glow.visible = false

	if weak_point_shape != null:
		weak_point_shape.disabled = true


func is_weak_point_node(node: Node) -> bool:
	if node == null:
		return false

	if node == weak_point:
		return true

	var current: Node = node
	while current != null:
		if current == weak_point:
			return true
		current = current.get_parent()

	return false


func on_weak_point_hit(hit_count: int) -> void:
	if _dead:
		return

	emit_signal("weak_point_hit", hit_count)
	close_weak_point()

	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(visuals, "scale", Vector3.ONE * 1.08, 0.08)
	t.tween_property(visuals, "rotation:z", visuals.rotation.z + deg_to_rad(10.0), 0.08)
	t.chain().tween_property(visuals, "scale", Vector3.ONE, 0.16)
	t.parallel().tween_property(visuals, "rotation:z", 0.0, 0.16)

	if weak_glow != null:
		weak_glow.visible = true
		var mat := weak_glow.get_active_material(0)
		if mat is BaseMaterial3D:
			var glow_mat := mat as BaseMaterial3D
			glow_mat.albedo_color.a = 1.0
			var t2 := create_tween()
			t2.tween_method(
				func(a: float) -> void:
					if weak_glow != null:
						var active_mat := weak_glow.get_active_material(0)
						if active_mat is BaseMaterial3D:
							(active_mat as BaseMaterial3D).albedo_color.a = a,
				1.0,
				0.0,
				0.22
			)
			t2.finished.connect(func() -> void:
				if not vulnerable and weak_glow != null:
					weak_glow.visible = false
			)


func play_death() -> void:
	if _dead:
		return

	_dead = true
	stop_attack()
	close_weak_point()

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "rotation:z", rotation.z + deg_to_rad(360.0), death_shrink_time)
	tween.tween_property(self, "scale", Vector3.ONE * 0.08, death_shrink_time)
	tween.tween_property(body_closed, "modulate:a", 0.0, death_shrink_time)
	tween.tween_property(body_open, "modulate:a", 0.0, death_shrink_time)

	if weak_glow != null:
		tween.tween_property(weak_glow, "transparency", 1.0, death_shrink_time)

	tween.chain().tween_callback(queue_free)


func _physics_process(delta: float) -> void:
	if _dead:
		return

	rotation_offset += delta * base_rotation_speed

	if attack_active:
		attack_time_left = maxf(attack_time_left - delta, 0.0)
		shot_cooldown_left -= delta

		if shot_cooldown_left <= 0.0:
			_fire_current_pattern()
			shot_cooldown_left = current_pattern_interval


func _fire_current_pattern() -> void:
	match current_pattern:
		"fan_burst":
			_fire_fan_burst_pattern()
		"rotating_spread":
			_fire_rotating_spread_pattern()
		"lane_sweep":
			_fire_lane_sweep_pattern()
		_:
			_fire_fan_burst_pattern()


func _direction_to_point(from: Vector3, to: Vector3) -> Vector3:
	var dir: Vector3 = (to - from).normalized()
	if dir.length_squared() <= 0.00001:
		return Vector3.FORWARD
	return dir


func _spread_direction_toward_point(from: Vector3, to: Vector3, yaw_offset_rad: float, pitch_offset_rad: float = 0.0) -> Vector3:
	var base_dir: Vector3 = _direction_to_point(from, to)

	var yaw_basis := Basis(Vector3.UP, yaw_offset_rad)
	var dir_after_yaw: Vector3 = (yaw_basis * base_dir).normalized()

	var right: Vector3 = dir_after_yaw.cross(Vector3.UP).normalized()
	if right.length_squared() <= 0.00001:
		right = Vector3.RIGHT

	var pitch_basis := Basis(right, pitch_offset_rad)
	return (pitch_basis * dir_after_yaw).normalized()


func _fire_fan_burst_pattern() -> void:
	if player_ref == null or not is_instance_valid(player_ref):
		return

	var muzzle: Marker3D = muzzle_center
	if fan_cycle_index % 3 == 1:
		muzzle = muzzle_left
	elif fan_cycle_index % 3 == 2:
		muzzle = muzzle_right

	var aimed_pos: Vector3 = player_ref.global_position + player_ref.velocity * fan_prediction
	var total_angle: float = deg_to_rad(fan_burst_angle_deg + float(current_phase - 1) * 4.0)
	var start_angle: float = -total_angle * 0.5
	var step: float = total_angle / float(maxi(fan_burst_count - 1, 1))
	var speed: float = fan_burst_speed * current_bullet_speed_mult

	for i in range(fan_burst_count):
		var yaw: float = start_angle + step * float(i)
		var dir: Vector3 = _spread_direction_toward_point(
			muzzle.global_position,
			aimed_pos,
			yaw,
			0.0
		)
		_spawn_bullet(muzzle.global_position, dir, speed)

	var micro_count: int = 5 + current_phase
	var micro_angle: float = deg_to_rad(22.0)
	var micro_start: float = -micro_angle * 0.5
	var micro_step: float = micro_angle / float(maxi(micro_count - 1, 1))

	for i in range(micro_count):
		var yaw: float = micro_start + micro_step * float(i)
		var dir: Vector3 = _spread_direction_toward_point(
			muzzle_center.global_position,
			aimed_pos,
			yaw,
			0.0
		)
		_spawn_bullet(muzzle_center.global_position, dir, speed * 1.08)

	fan_cycle_index += 1


func _fire_rotating_spread_pattern() -> void:
	var target_center: Vector3 = arena_center + Vector3(0.0, 0.35, 0.0)

	var count: int = rotating_spread_count + (current_phase - 1) * 2
	var total_angle: float = deg_to_rad(110.0)
	var step: float = total_angle / float(maxi(count - 1, 1))
	var offset: float = deg_to_rad(rotating_offset_step_deg * float(rotating_cycle_index))
	var speed: float = rotating_spread_speed * current_bullet_speed_mult

	var start: float = -total_angle * 0.5 + offset

	for i in range(count):
		var yaw: float = start + step * float(i)
		var dir: Vector3 = _spread_direction_toward_point(
			muzzle_left.global_position,
			target_center,
			yaw,
			0.0
		)
		_spawn_bullet(muzzle_left.global_position, dir, speed)

	for i in range(count):
		var yaw: float = start + step * float(i) + step * 0.5
		var dir: Vector3 = _spread_direction_toward_point(
			muzzle_right.global_position,
			target_center,
			yaw,
			0.0
		)
		_spawn_bullet(muzzle_right.global_position, dir, speed * 0.96)

	if player_ref != null and is_instance_valid(player_ref):
		var aimed_pos: Vector3 = player_ref.global_position + player_ref.velocity * 0.18
		var burst_count: int = 4 + current_phase
		var burst_angle: float = deg_to_rad(18.0)
		var burst_start: float = -burst_angle * 0.5
		var burst_step: float = burst_angle / float(maxi(burst_count - 1, 1))

		for i in range(burst_count):
			var yaw: float = burst_start + burst_step * float(i)
			var dir: Vector3 = _spread_direction_toward_point(
				muzzle_center.global_position,
				aimed_pos,
				yaw,
				0.0
			)
			_spawn_bullet(muzzle_center.global_position, dir, speed * 1.05)

	rotating_cycle_index += 1


func _fire_lane_sweep_pattern() -> void:
	var cols: int = maxi(lane_sweep_rows, 5)
	var width: float = arena_half_extents.x * 2.0
	var speed: float = lane_sweep_speed * current_bullet_speed_mult
	var y_target: float = arena_center.y + 0.2

	var safe_lane: int = _pick_next_safe_lane(cols)
	var safe_lane_2: int = _pick_shifted_lane(cols, safe_lane)
	var lane_width: float = width / float(cols)

	for i in range(cols):
		if i == safe_lane:
			continue

		var x: float = arena_center.x - arena_half_extents.x + lane_width * (float(i) + 0.5)
		var target: Vector3 = Vector3(x, y_target, arena_center.z)
		var dir: Vector3 = _direction_to_point(muzzle_left.global_position, target)
		_spawn_bullet(muzzle_left.global_position, dir, speed)

	for i in range(cols):
		if i == safe_lane_2:
			continue

		var x: float = arena_center.x - arena_half_extents.x + lane_width * (float(i) + 0.5)
		var target: Vector3 = Vector3(x, y_target, arena_center.z + 0.4)
		var dir: Vector3 = _direction_to_point(muzzle_right.global_position, target)
		_spawn_bullet(muzzle_right.global_position, dir, speed * 1.07)

	var center_target: int = cols / 2
	if current_phase >= 2:
		for i in range(cols):
			if i == center_target:
				continue
			if i == safe_lane_2:
				continue
			if abs(i - center_target) > 2:
				continue

			var x: float = arena_center.x - arena_half_extents.x + lane_width * (float(i) + 0.5)
			var target: Vector3 = Vector3(x, y_target, arena_center.z - 0.35)
			var dir: Vector3 = _direction_to_point(muzzle_center.global_position, target)
			_spawn_bullet(muzzle_center.global_position, dir, speed * 1.12)

	lane_cycle_index += 1
	last_safe_lane = safe_lane_2


func _pick_next_safe_lane(cols: int) -> int:
	if cols <= 1:
		return 0

	var idx: int = rng.randi_range(0, cols - 1)
	if idx == last_safe_lane:
		idx = (idx + 2) % cols
	return idx


func _pick_shifted_lane(cols: int, previous_lane: int) -> int:
	if cols <= 1:
		return 0

	var shift: int = 2 if current_phase < 3 else 3
	var dir_sign: int = -1 if lane_cycle_index % 2 == 0 else 1
	var idx: int = previous_lane + shift * dir_sign

	while idx < 0:
		idx += cols
	while idx >= cols:
		idx -= cols

	return idx


func _spawn_bullet(origin: Vector3, direction: Vector3, speed: float) -> void:
	if bullet_scene == null:
		return
	if bullets_parent == null or not is_instance_valid(bullets_parent):
		return

	var bullet := bullet_scene.instantiate()
	if bullet == null:
		return

	bullets_parent.add_child(bullet)

	if bullet is Node3D:
		(bullet as Node3D).global_position = origin

	if bullet.has_method("fire"):
		bullet.call("fire", origin, direction.normalized(), speed, self)
	elif bullet.has_method("setup"):
		bullet.call("setup", direction.normalized(), speed)


func _flash_open_state() -> void:
	if weak_glow == null:
		return

	weak_glow.visible = true

	var mat := weak_glow.get_active_material(0)
	if mat is BaseMaterial3D:
		var glow_mat := mat as BaseMaterial3D
		glow_mat.albedo_color.a = 0.0

		var t := create_tween()
		t.tween_method(
			func(a: float) -> void:
				if weak_glow != null:
					var active_mat := weak_glow.get_active_material(0)
					if active_mat is BaseMaterial3D:
						(active_mat as BaseMaterial3D).albedo_color.a = a,
			0.0,
			vulnerable_glow_alpha,
			0.16
		)


func _reset_visual_modulate() -> void:
	body_closed.modulate = Color(1, 1, 1, 0.96)
	body_open.modulate = Color(1, 1, 1, 0.98)

	if weak_glow != null:
		var mat := weak_glow.get_active_material(0)
		if mat is BaseMaterial3D:
			var glow_mat := mat as BaseMaterial3D
			glow_mat.albedo_color.a = 0.0
