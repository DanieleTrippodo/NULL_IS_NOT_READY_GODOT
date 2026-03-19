extends Node3D

signal boss_defeated

enum BossState {
	INTRO,
	ATTACK,
	VULNERABLE,
	TRANSITION,
	DEAD
}

@export var player_scene: PackedScene = preload("res://Player/player.tscn")
@export var boss_scene: PackedScene = preload("res://Boss/red_crown.tscn")
@export var null_projectile_scene: PackedScene = preload("res://Weapons/null_projectile.tscn")
@export var hud_scene: PackedScene = preload("res://UI/hud.tscn")
@export var game_over_overlay_scene: PackedScene = preload("res://UI/game_over_overlay.tscn")
@export var credits_scene: PackedScene = preload("res://UI/end_credits.tscn")

@export_group("Flow")
@export var intro_duration: float = 5.2
@export var transition_duration: float = 1.0
@export var post_hit_buffer: float = 0.9
@export var attack_duration_phase_1: float = 20.0
@export var attack_duration_phase_2: float = 24.0
@export var attack_duration_phase_3: float = 28.0
@export var vulnerable_time_phase_1: float = 4.0
@export var vulnerable_time_phase_2: float = 3.4
@export var vulnerable_time_phase_3: float = 3.0

@export_group("Attack Chaining")
@export var pattern_switch_phase_1: float = 4.4
@export var pattern_switch_phase_2: float = 3.0
@export var pattern_switch_phase_3: float = 2.1
@export var pattern_end_buffer: float = 1.0

@export_group("Arena Darkness")
@export var intro_darkness_start_alpha: float = 0.95
@export var intro_darkness_mid_alpha: float = 0.46
@export var intro_darkness_hold_ratio: float = 0.18
@export var intro_darkness_first_fade_ratio: float = 0.30
@export var intro_darkness_mid_hold_ratio: float = 0.14
@export var intro_darkness_second_fade_ratio: float = 0.22

@export_group("Victory Transition")
@export var victory_hold_before_fade: float = 0.8
@export var victory_fade_duration: float = 1.6

@export_group("Boss Teleport")
@export var teleport_between_phases: bool = true
@export var teleport_transition_duration: float = 0.45
@export var teleport_warning_duration: float = 0.85
@export var teleport_during_attack: bool = true
@export var teleport_phase_1_interval: float = 8.8
@export var teleport_phase_2_interval: float = 6.8
@export var teleport_phase_3_interval: float = 5.2
@export var teleport_min_time_remaining: float = 2.6

@onready var player_spawn: Marker3D = $PlayerSpawn
@onready var boss_anchor: Marker3D = $BossAnchor
@onready var player_container: Node3D = $PlayerContainer
@onready var boss_bullets: Node3D = $BossBullets
@onready var arena_center: Marker3D = $ArenaCenter
@onready var platform_mesh: MeshInstance3D = $ArenaPlatform/PlatformMesh
@onready var ui_root: CanvasLayer = $UIRoot
@onready var arena_darkness: ColorRect = get_node_or_null("UIRoot/ArenaDarkness") as ColorRect

var state: int = BossState.INTRO
var state_time_left: float = 0.0

var player: CharacterBody3D = null
var boss: Node3D = null
var null_instance: Node3D = null
var hud: Control = null
var game_over_overlay: Control = null
var restarting: bool = false
var _victory_transitioning: bool = false

var boss_hits: int = 0
var phase: int = 1
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _phase_1_sequence: Array[String] = [
	"fan_burst",
	"rotating_spread"
]

var _phase_2_sequence: Array[String] = [
	"fan_burst",
	"lane_sweep",
	"rotating_spread",
	"fan_burst"
]

var _phase_3_sequence: Array[String] = [
	"lane_sweep",
	"fan_burst",
	"rotating_spread",
	"lane_sweep",
	"fan_burst",
	"rotating_spread"
]

var _attack_sequence: Array[String] = []
var _attack_sequence_index: int = 0
var _attack_pattern_time_left: float = 0.0
var _current_attack_pattern: String = ""

var _arena_darkness_tween: Tween = null
var _boss_teleport_positions: Array[Vector3] = []
var _boss_teleport_rotations: Array[Vector3] = []
var _boss_current_teleport_index: int = 0
var _attack_teleport_pending: bool = false
var _attack_teleport_in_progress: bool = false
var _attack_teleport_cooldown_left: float = 0.0

func _ready() -> void:
	_rng.randomize()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	_connect_signals()
	_setup_ui()
	_setup_intro_darkness()
	_spawn_player()
	_spawn_boss()
	_play_intro_darkness()

	Signals.depth_changed.emit(Run.depth)
	Signals.null_ready_changed.emit(Run.null_ready)
	if Signals.has_signal("money_changed"):
		Signals.money_changed.emit(Run.money)

	state = BossState.INTRO
	state_time_left = intro_duration


func _exit_tree() -> void:
	_disconnect_signals()
	_kill_intro_darkness_tween()


func _process(delta: float) -> void:
	if null_instance != null and not is_instance_valid(null_instance):
		null_instance = null

	if Run.slowmo_recovery and Run.null_dropped:
		Engine.time_scale = Run.slowmo_scale
	else:
		Engine.time_scale = 1.0

	if Run.pickup_magnet and Run.null_dropped and null_instance != null and is_instance_valid(null_instance):
		if player != null and is_instance_valid(player) and player.global_position.distance_to(null_instance.global_position) <= 2.2:
			_on_request_pickup()

	if state == BossState.DEAD or restarting or _victory_transitioning:
		return

	if state == BossState.ATTACK:
		_update_attack_pattern_cycle(delta)

	state_time_left -= delta
	if state_time_left > 0.0:
		return

	match state:
		BossState.INTRO:
			_begin_attack_phase()
		BossState.ATTACK:
			_begin_vulnerable_phase()
		BossState.VULNERABLE:
			_begin_transition()
		BossState.TRANSITION:
			_begin_attack_phase()


func _connect_signals() -> void:
	if not Signals.enemy_killed.is_connected(_on_enemy_killed):
		Signals.enemy_killed.connect(_on_enemy_killed)
	if not Signals.request_shoot.is_connected(_on_request_shoot):
		Signals.request_shoot.connect(_on_request_shoot)
	if not Signals.request_pickup.is_connected(_on_request_pickup):
		Signals.request_pickup.connect(_on_request_pickup)
	if not Signals.request_recovery_start.is_connected(_on_request_recovery_start):
		Signals.request_recovery_start.connect(_on_request_recovery_start)
	if not Signals.request_recovery_stop.is_connected(_on_request_recovery_stop):
		Signals.request_recovery_stop.connect(_on_request_recovery_stop)
	if not Signals.request_force_drop_null.is_connected(_on_request_force_drop_null):
		Signals.request_force_drop_null.connect(_on_request_force_drop_null)
	if not Signals.null_dropped.is_connected(_on_null_dropped):
		Signals.null_dropped.connect(_on_null_dropped)
	if not Signals.player_died.is_connected(_on_player_died):
		Signals.player_died.connect(_on_player_died)


func _disconnect_signals() -> void:
	if Signals.enemy_killed.is_connected(_on_enemy_killed):
		Signals.enemy_killed.disconnect(_on_enemy_killed)
	if Signals.request_shoot.is_connected(_on_request_shoot):
		Signals.request_shoot.disconnect(_on_request_shoot)
	if Signals.request_pickup.is_connected(_on_request_pickup):
		Signals.request_pickup.disconnect(_on_request_pickup)
	if Signals.request_recovery_start.is_connected(_on_request_recovery_start):
		Signals.request_recovery_start.disconnect(_on_request_recovery_start)
	if Signals.request_recovery_stop.is_connected(_on_request_recovery_stop):
		Signals.request_recovery_stop.disconnect(_on_request_recovery_stop)
	if Signals.request_force_drop_null.is_connected(_on_request_force_drop_null):
		Signals.request_force_drop_null.disconnect(_on_request_force_drop_null)
	if Signals.null_dropped.is_connected(_on_null_dropped):
		Signals.null_dropped.disconnect(_on_null_dropped)
	if Signals.player_died.is_connected(_on_player_died):
		Signals.player_died.disconnect(_on_player_died)


func _setup_ui() -> void:
	if hud_scene != null:
		var hud_instance: Node = hud_scene.instantiate()
		if hud_instance is Control:
			hud = hud_instance as Control
			ui_root.add_child(hud)

	if game_over_overlay_scene != null:
		var overlay_instance: Node = game_over_overlay_scene.instantiate()
		if overlay_instance is Control:
			game_over_overlay = overlay_instance as Control
			ui_root.add_child(game_over_overlay)
			if game_over_overlay.has_signal("retry_pressed"):
				game_over_overlay.retry_pressed.connect(_on_game_over_retry_pressed)
			if game_over_overlay.has_signal("exit_pressed"):
				game_over_overlay.exit_pressed.connect(_on_game_over_exit_pressed)


func _setup_intro_darkness() -> void:
	if arena_darkness == null:
		return

	arena_darkness.visible = true
	arena_darkness.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arena_darkness.color = Color.BLACK
	arena_darkness.modulate = Color(1.0, 1.0, 1.0, intro_darkness_start_alpha)


func _play_intro_darkness() -> void:
	if arena_darkness == null:
		return

	_kill_intro_darkness_tween()

	var total: float = maxf(intro_duration, 0.1)
	var hold_time: float = total * intro_darkness_hold_ratio
	var first_fade_time: float = total * intro_darkness_first_fade_ratio
	var mid_hold_time: float = total * intro_darkness_mid_hold_ratio
	var second_fade_time: float = total * intro_darkness_second_fade_ratio

	_arena_darkness_tween = create_tween()
	_arena_darkness_tween.set_trans(Tween.TRANS_SINE)
	_arena_darkness_tween.set_ease(Tween.EASE_IN_OUT)

	if hold_time > 0.0:
		_arena_darkness_tween.tween_interval(hold_time)

	_arena_darkness_tween.tween_property(
		arena_darkness,
		"modulate:a",
		intro_darkness_mid_alpha,
		first_fade_time
	)

	if mid_hold_time > 0.0:
		_arena_darkness_tween.tween_interval(mid_hold_time)

	_arena_darkness_tween.tween_property(
		arena_darkness,
		"modulate:a",
		0.0,
		second_fade_time
	)

	_arena_darkness_tween.finished.connect(func() -> void:
		if arena_darkness != null:
			arena_darkness.visible = false
	)


func _kill_intro_darkness_tween() -> void:
	if _arena_darkness_tween != null:
		_arena_darkness_tween.kill()
		_arena_darkness_tween = null


func _spawn_player() -> void:
	if player_scene == null:
		push_error("BossArena: player_scene missing.")
		return

	player = player_scene.instantiate() as CharacterBody3D
	if player == null:
		push_error("BossArena: failed to instantiate player.")
		return

	player_container.add_child(player)
	player.global_position = player_spawn.global_position
	player.rotation = player_spawn.rotation


func _spawn_boss() -> void:
	if boss_scene == null:
		push_error("BossArena: boss_scene missing.")
		return

	boss = boss_scene.instantiate()
	if boss == null:
		push_error("BossArena: failed to instantiate boss.")
		return

	add_child(boss)
	boss.global_position = boss_anchor.global_position
	boss.rotation = boss_anchor.rotation

	var half_extents: Vector2 = _get_platform_half_extents()
	if boss.has_method("setup"):
		boss.call(
			"setup",
			player,
			boss_bullets,
			arena_center.global_position,
			half_extents
		)

	if boss.has_method("play_intro_appearance"):
		boss.call("play_intro_appearance", intro_duration)

	_cache_boss_teleport_points()

	if boss.has_signal("teleport_sequence_finished") and not boss.teleport_sequence_finished.is_connected(_on_boss_teleport_sequence_finished):
		boss.teleport_sequence_finished.connect(_on_boss_teleport_sequence_finished)


func _get_platform_half_extents() -> Vector2:
	if platform_mesh == null or platform_mesh.mesh == null:
		return Vector2(6.0, 6.0)

	if platform_mesh.mesh is BoxMesh:
		var box: BoxMesh = platform_mesh.mesh as BoxMesh
		return Vector2(box.size.x * 0.5, box.size.z * 0.5)

	return Vector2(6.0, 6.0)


func _begin_attack_phase() -> void:
	if boss == null:
		return

	_update_phase()

	state = BossState.ATTACK
	state_time_left = _get_attack_duration_for_phase(phase)
	_attack_teleport_pending = false
	_attack_teleport_in_progress = false
	_attack_teleport_cooldown_left = _get_attack_teleport_interval_for_phase(phase)

	_prepare_attack_sequence_for_phase(phase)
	_start_next_attack_pattern(true)


func _begin_vulnerable_phase() -> void:
	if boss == null:
		return

	state = BossState.VULNERABLE
	state_time_left = _get_vulnerable_duration_for_phase(phase)
	_reset_attack_chain_state()

	if boss.has_method("stop_attack"):
		boss.call("stop_attack")

	if boss.has_method("open_weak_point"):
		boss.call("open_weak_point")


func _begin_transition(custom_time: float = -1.0) -> void:
	if boss == null:
		return

	state = BossState.TRANSITION
	state_time_left = transition_duration if custom_time <= 0.0 else custom_time
	_reset_attack_chain_state()

	if boss.has_method("stop_attack"):
		boss.call("stop_attack")

	if boss.has_method("close_weak_point"):
		boss.call("close_weak_point")


func _update_phase() -> void:
	if boss_hits >= 2:
		phase = 3
	elif boss_hits >= 1:
		phase = 2
	else:
		phase = 1


func _get_attack_duration_for_phase(p: int) -> float:
	match p:
		1:
			return attack_duration_phase_1
		2:
			return attack_duration_phase_2
		3:
			return attack_duration_phase_3
		_:
			return attack_duration_phase_1


func _get_vulnerable_duration_for_phase(p: int) -> float:
	var t: float

	match p:
		1:
			t = vulnerable_time_phase_1
		2:
			t = vulnerable_time_phase_2
		3:
			t = vulnerable_time_phase_3
		_:
			t = vulnerable_time_phase_1

	return maxf(t, 3.0)


func _get_pattern_switch_interval_for_phase(p: int) -> float:
	match p:
		1:
			return pattern_switch_phase_1
		2:
			return pattern_switch_phase_2
		3:
			return pattern_switch_phase_3
		_:
			return pattern_switch_phase_1


func _get_attack_teleport_interval_for_phase(p: int) -> float:
	match p:
		1:
			return teleport_phase_1_interval
		2:
			return teleport_phase_2_interval
		3:
			return teleport_phase_3_interval
		_:
			return teleport_phase_1_interval


func _get_pattern_sequence_for_phase(p: int) -> Array[String]:
	match p:
		1:
			return _phase_1_sequence.duplicate()
		2:
			return _phase_2_sequence.duplicate()
		3:
			return _phase_3_sequence.duplicate()
		_:
			return _phase_1_sequence.duplicate()


func _prepare_attack_sequence_for_phase(p: int) -> void:
	_attack_sequence = _get_pattern_sequence_for_phase(p)
	_current_attack_pattern = ""
	_attack_pattern_time_left = 0.0

	if _attack_sequence.is_empty():
		return

	_attack_sequence_index = _rng.randi_range(0, _attack_sequence.size() - 1)


func _reset_attack_chain_state() -> void:
	_attack_sequence.clear()
	_attack_sequence_index = 0
	_attack_pattern_time_left = 0.0
	_current_attack_pattern = ""
	_attack_teleport_pending = false
	_attack_teleport_in_progress = false


func _update_attack_pattern_cycle(delta: float) -> void:
	if boss == null:
		return
	if _attack_sequence.is_empty():
		return
	if _attack_teleport_in_progress:
		return

	if teleport_during_attack:
		_attack_teleport_cooldown_left -= delta
		if _attack_teleport_cooldown_left <= 0.0:
			_attack_teleport_pending = true
			_attack_teleport_cooldown_left = 999999.0

	_attack_pattern_time_left -= delta
	if _attack_pattern_time_left > 0.0:
		return

	var required_remaining: float = maxf(pattern_end_buffer, teleport_min_time_remaining + teleport_warning_duration + teleport_transition_duration)
	if _attack_teleport_pending and state_time_left > required_remaining:
		_start_pending_attack_teleport()
		return

	if state_time_left <= pattern_end_buffer:
		return

	_start_next_attack_pattern(false)


func _start_next_attack_pattern(force_immediate: bool) -> void:
	if boss == null:
		return
	if _attack_sequence.is_empty():
		return

	var pattern: String = _attack_sequence[_attack_sequence_index % _attack_sequence.size()]
	if pattern == _current_attack_pattern and _attack_sequence.size() > 1:
		_attack_sequence_index += 1
		pattern = _attack_sequence[_attack_sequence_index % _attack_sequence.size()]

	_attack_sequence_index += 1
	_current_attack_pattern = pattern

	var switch_interval: float = _get_pattern_switch_interval_for_phase(phase)
	var remaining_window: float = maxf(state_time_left - pattern_end_buffer, 0.35)
	var pattern_duration: float = minf(switch_interval, remaining_window)

	_attack_pattern_time_left = switch_interval
	if force_immediate:
		_attack_pattern_time_left = switch_interval

	if boss.has_method("close_weak_point"):
		boss.call("close_weak_point")

	if boss.has_method("begin_attack"):
		boss.call("begin_attack", pattern, pattern_duration, phase)


func _on_enemy_killed(enemy: Node) -> void:
	if state != BossState.VULNERABLE:
		return
	if boss == null:
		return
	if enemy == null:
		return
	if not boss.has_method("is_weak_point_node"):
		return
	if not boss.call("is_weak_point_node", enemy):
		return

	var previous_phase: int = phase
	boss_hits += 1
	_update_phase()
	var phase_changed: bool = phase != previous_phase

	if boss.has_method("on_weak_point_hit"):
		boss.call("on_weak_point_hit", boss_hits)

	_force_null_return()

	if boss_hits >= 3:
		_kill_boss()
		return

	var transition_time: float = post_hit_buffer
	if phase_changed and phase >= 2 and teleport_between_phases:
		transition_time = maxf(transition_time, teleport_warning_duration + teleport_transition_duration + 0.15)

	_begin_transition(transition_time)

	if phase_changed and phase >= 2 and teleport_between_phases:
		_teleport_boss_to_next_anchor()


func _kill_boss() -> void:
	if _victory_transitioning:
		return

	state = BossState.DEAD
	state_time_left = 0.0
	_reset_attack_chain_state()
	_force_null_return()
	_clear_boss_bullets()

	if boss != null and boss.has_method("play_death"):
		boss.call("play_death")

	emit_signal("boss_defeated")
	call_deferred("_begin_boss_victory_transition")


func _begin_boss_victory_transition() -> void:
	if _victory_transitioning:
		return

	_victory_transitioning = true
	_kill_intro_darkness_tween()
	_clear_boss_bullets()

	if boss != null and boss.has_method("stop_attack"):
		boss.call("stop_attack")

	if player != null and is_instance_valid(player):
		player.set_process_input(false)
		player.set_process_unhandled_input(false)
		player.set_physics_process(false)

	if arena_darkness != null:
		arena_darkness.visible = true
		arena_darkness.modulate = Color(1.0, 1.0, 1.0, 0.0)

	await get_tree().create_timer(victory_hold_before_fade).timeout

	if arena_darkness != null:
		_arena_darkness_tween = create_tween()
		_arena_darkness_tween.set_trans(Tween.TRANS_SINE)
		_arena_darkness_tween.set_ease(Tween.EASE_IN_OUT)
		_arena_darkness_tween.tween_property(arena_darkness, "modulate:a", 1.0, victory_fade_duration)
		await _arena_darkness_tween.finished

	Run.null_ready = true
	Run.null_dropped = false
	Run.survival_mode = false

	if credits_scene != null:
		get_tree().change_scene_to_packed(credits_scene)
	else:
		get_tree().change_scene_to_file("res://UI/main_menu.tscn")


func _clear_boss_bullets() -> void:
	if boss_bullets == null:
		return

	for child in boss_bullets.get_children():
		child.queue_free()


func _cache_boss_teleport_points() -> void:
	_boss_teleport_positions.clear()
	_boss_teleport_rotations.clear()

	if boss_anchor == null or arena_center == null:
		return

	var center: Vector3 = arena_center.global_position
	var anchor_pos: Vector3 = boss_anchor.global_position
	var radius_vec: Vector2 = Vector2(anchor_pos.x - center.x, anchor_pos.z - center.z)
	var radius: float = maxf(radius_vec.length(), 1.0)
	var base_y: float = anchor_pos.y
	var base_rot: Vector3 = boss_anchor.rotation
	var yaws: Array[float] = [base_rot.y, base_rot.y - PI * 0.5, base_rot.y + PI, base_rot.y + PI * 0.5]
	var dirs: Array[Vector3] = [Vector3(0.0, 0.0, -1.0), Vector3(1.0, 0.0, 0.0), Vector3(0.0, 0.0, 1.0), Vector3(-1.0, 0.0, 0.0)]

	for i in range(dirs.size()):
		var dir: Vector3 = dirs[i]
		var pos: Vector3 = Vector3(center.x + dir.x * radius, base_y, center.z + dir.z * radius)
		_boss_teleport_positions.append(pos)
		_boss_teleport_rotations.append(Vector3(base_rot.x, yaws[i], base_rot.z))

	_boss_current_teleport_index = _find_nearest_boss_teleport_index(anchor_pos)


func _find_nearest_boss_teleport_index(pos: Vector3) -> int:
	if _boss_teleport_positions.is_empty():
		return 0

	var best_index: int = 0
	var best_distance: float = INF
	for i in range(_boss_teleport_positions.size()):
		var d: float = pos.distance_squared_to(_boss_teleport_positions[i])
		if d < best_distance:
			best_distance = d
			best_index = i

	return best_index


func _pick_next_boss_teleport_index() -> int:
	if _boss_teleport_positions.size() <= 1:
		return _boss_current_teleport_index

	var next_index: int = _rng.randi_range(0, _boss_teleport_positions.size() - 1)
	if next_index == _boss_current_teleport_index:
		next_index = (next_index + 1 + _rng.randi_range(0, _boss_teleport_positions.size() - 2)) % _boss_teleport_positions.size()

	return next_index


func _teleport_boss_to_next_anchor() -> void:
	if boss == null:
		return
	if _boss_teleport_positions.is_empty():
		return

	var next_index: int = _pick_next_boss_teleport_index()
	_boss_current_teleport_index = next_index

	var target_pos: Vector3 = _boss_teleport_positions[next_index]
	var target_rot: Vector3 = _boss_teleport_rotations[next_index]

	if boss.has_method("play_teleport_blink"):
		boss.call("play_teleport_blink", target_pos, target_rot, teleport_warning_duration, teleport_transition_duration)
	else:
		boss.global_position = target_pos
		boss.rotation = target_rot


func _start_pending_attack_teleport() -> void:
	if boss == null:
		return
	if _boss_teleport_positions.is_empty():
		return

	_attack_teleport_pending = false
	_attack_teleport_in_progress = true

	if boss.has_method("stop_attack"):
		boss.call("stop_attack")
	if boss.has_method("close_weak_point"):
		boss.call("close_weak_point")

	var next_index: int = _pick_next_boss_teleport_index()
	_boss_current_teleport_index = next_index

	var target_pos: Vector3 = _boss_teleport_positions[next_index]
	var target_rot: Vector3 = _boss_teleport_rotations[next_index]

	if boss.has_method("play_teleport_blink"):
		boss.call("play_teleport_blink", target_pos, target_rot, teleport_warning_duration, teleport_transition_duration)
	else:
		boss.global_position = target_pos
		boss.rotation = target_rot
		_on_boss_teleport_sequence_finished()


func _on_boss_teleport_sequence_finished() -> void:
	_attack_teleport_in_progress = false
	_attack_teleport_cooldown_left = _get_attack_teleport_interval_for_phase(phase)

	if state != BossState.ATTACK:
		return
	if restarting or _victory_transitioning:
		return
	if boss == null:
		return
	if state_time_left <= pattern_end_buffer:
		return

	_start_next_attack_pattern(false)


func _on_request_shoot(origin: Vector3, direction: Vector3, size_mult: float = 1.0) -> void:
	if restarting or _victory_transitioning:
		return
	if not Run.null_ready and not Run.infinite_enabled:
		return
	if null_projectile_scene == null:
		return

	var p: Node = null_projectile_scene.instantiate()
	if not (p is Node3D):
		if not Run.infinite_enabled:
			Run.null_ready = true
			Signals.null_ready_changed.emit(true)
		return

	if not Run.infinite_enabled:
		Run.null_ready = false
		Run.null_dropped = false
		Signals.null_ready_changed.emit(false)

	var proj := p as Node3D
	add_child(proj)
	if not Run.infinite_enabled:
		null_instance = proj

	if proj.has_method("fire"):
		proj.call("fire", origin, direction, size_mult)
	else:
		proj.global_position = origin


func _on_request_pickup() -> void:
	if null_instance == null or not is_instance_valid(null_instance):
		return
	if player == null or not is_instance_valid(player):
		return

	var pickup_radius: float = 1.6
	if Run.pickup_magnet:
		pickup_radius = 2.2

	if player.global_position.distance_to(null_instance.global_position) > pickup_radius:
		return

	if null_instance.has_method("pickup"):
		null_instance.call("pickup")
	else:
		null_instance.queue_free()

	null_instance = null
	Run.null_ready = true
	Run.null_dropped = false
	Signals.null_ready_changed.emit(true)


func _on_request_recovery_start() -> void:
	if null_instance == null or not is_instance_valid(null_instance):
		return
	if not Run.null_dropped:
		return
	if player == null or not is_instance_valid(player):
		return
	if null_instance.has_method("start_remote_recovery"):
		null_instance.call("start_remote_recovery", player)


func _on_request_recovery_stop() -> void:
	if null_instance == null or not is_instance_valid(null_instance):
		return
	if null_instance.has_method("stop_remote_recovery"):
		null_instance.call("stop_remote_recovery")


func _on_request_force_drop_null(pos: Vector3) -> void:
	if restarting or _victory_transitioning:
		return
	if not Run.null_ready:
		return
	if null_projectile_scene == null:
		return

	Run.null_ready = false
	Run.null_dropped = false
	Signals.null_ready_changed.emit(false)

	var p: Node = null_projectile_scene.instantiate()
	if not (p is Node3D):
		Run.null_ready = true
		Signals.null_ready_changed.emit(true)
		return

	null_instance = p as Node3D
	add_child(null_instance)
	null_instance.global_position = pos

	if null_instance.has_method("_drop"):
		null_instance.call("_drop")


func _on_null_dropped(_pos: Variant = null) -> void:
	Run.null_dropped = true


func _force_null_return() -> void:
	if null_instance != null and is_instance_valid(null_instance):
		if null_instance.has_method("pickup"):
			null_instance.call("pickup")
		else:
			null_instance.queue_free()
		null_instance = null

	Run.null_ready = true
	Run.null_dropped = false
	Signals.null_ready_changed.emit(true)


func _on_player_died() -> void:
	if restarting or _victory_transitioning:
		return

	restarting = true
	state = BossState.DEAD
	_reset_attack_chain_state()
	_force_null_return()
	_kill_intro_darkness_tween()

	if boss != null and boss.has_method("stop_attack"):
		boss.call("stop_attack")

	if player != null and is_instance_valid(player):
		player.set_process_input(false)
		player.set_process_unhandled_input(false)
		player.set_physics_process(false)

	if game_over_overlay != null and game_over_overlay.has_method("show_game_over"):
		await game_over_overlay.show_game_over()
	else:
		get_tree().reload_current_scene()


func _on_game_over_retry_pressed() -> void:
	Run.null_ready = true
	Run.null_dropped = false
	Run.survival_mode = false
	get_tree().reload_current_scene()


func _on_game_over_exit_pressed() -> void:
	Run.null_ready = true
	Run.null_dropped = false
	Run.survival_mode = false
	get_tree().change_scene_to_file("res://UI/main_menu.tscn")
