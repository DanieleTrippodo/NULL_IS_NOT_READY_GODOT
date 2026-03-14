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

@export_group("Flow")
@export var intro_duration: float = 1.8
@export var transition_duration: float = 1.0
@export var post_hit_buffer: float = 0.9
@export var attack_duration_phase_1: float = 20.0
@export var attack_duration_phase_2: float = 24.0
@export var attack_duration_phase_3: float = 28.0
@export var vulnerable_time_phase_1: float = 3.0
@export var vulnerable_time_phase_2: float = 2.4
@export var vulnerable_time_phase_3: float = 1.8

@onready var player_spawn: Marker3D = $PlayerSpawn
@onready var boss_anchor: Marker3D = $BossAnchor
@onready var player_container: Node3D = $PlayerContainer
@onready var boss_bullets: Node3D = $BossBullets
@onready var arena_center: Marker3D = $ArenaCenter
@onready var platform_mesh: MeshInstance3D = $ArenaPlatform/PlatformMesh
@onready var ui_root: CanvasLayer = $UIRoot

var state: int = BossState.INTRO
var state_time_left: float = 0.0

var player: CharacterBody3D = null
var boss: Node3D = null
var null_instance: Node3D = null
var hud: Control = null
var game_over_overlay: Control = null
var restarting: bool = false

var boss_hits: int = 0
var phase: int = 1
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _phase_1_patterns: Array[String] = ["fan_burst", "rotating_spread"]
var _phase_2_patterns: Array[String] = ["fan_burst", "rotating_spread", "lane_sweep"]
var _phase_3_patterns: Array[String] = ["rotating_spread", "lane_sweep", "fan_burst"]

func _ready() -> void:
	_rng.randomize()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_connect_signals()
	_setup_ui()
	_spawn_player()
	_spawn_boss()

	Signals.depth_changed.emit(Run.depth)
	Signals.null_ready_changed.emit(Run.null_ready)
	if Signals.has_signal("money_changed"):
		Signals.money_changed.emit(Run.money)

	state = BossState.INTRO
	state_time_left = intro_duration

func _exit_tree() -> void:
	_disconnect_signals()

func _process(delta: float) -> void:
	if state == BossState.DEAD or restarting:
		return

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
		var hud_instance := hud_scene.instantiate()
		if hud_instance is Control:
			hud = hud_instance as Control
			ui_root.add_child(hud)

	if game_over_overlay_scene != null:
		var overlay_instance := game_over_overlay_scene.instantiate()
		if overlay_instance is Control:
			game_over_overlay = overlay_instance as Control
			ui_root.add_child(game_over_overlay)
			if game_over_overlay.has_signal("retry_pressed"):
				game_over_overlay.retry_pressed.connect(_on_game_over_retry_pressed)
			if game_over_overlay.has_signal("exit_pressed"):
				game_over_overlay.exit_pressed.connect(_on_game_over_exit_pressed)

func _spawn_player() -> void:
	if player_scene == null:
		push_error("BossArena: player_scene missing.")
		return

	player = player_scene.instantiate() as CharacterBody3D
	player_container.add_child(player)
	player.global_position = player_spawn.global_position
	player.rotation = player_spawn.rotation

func _spawn_boss() -> void:
	if boss_scene == null:
		push_error("BossArena: boss_scene missing.")
		return

	boss = boss_scene.instantiate()
	add_child(boss)
	boss.global_position = boss_anchor.global_position
	boss.rotation = boss_anchor.rotation

	var half_extents := _get_platform_half_extents()
	if boss.has_method("setup"):
		boss.call(
			"setup",
			player,
			boss_bullets,
			arena_center.global_position,
			half_extents
		)

func _get_platform_half_extents() -> Vector2:
	if platform_mesh == null or platform_mesh.mesh == null:
		return Vector2(6.0, 6.0)

	if platform_mesh.mesh is BoxMesh:
		var box := platform_mesh.mesh as BoxMesh
		return Vector2(box.size.x * 0.5, box.size.z * 0.5)

	return Vector2(6.0, 6.0)

func _begin_attack_phase() -> void:
	if boss == null:
		return

	_update_phase()

	state = BossState.ATTACK
	state_time_left = _get_attack_duration_for_phase(phase)

	var pool: Array[String] = _get_pattern_pool_for_phase(phase)
	var pattern: String = pool[_rng.randi_range(0, pool.size() - 1)]

	if boss.has_method("close_weak_point"):
		boss.call("close_weak_point")

	if boss.has_method("begin_attack"):
		boss.call("begin_attack", pattern, state_time_left, phase)

func _begin_vulnerable_phase() -> void:
	if boss == null:
		return

	state = BossState.VULNERABLE
	state_time_left = _get_vulnerable_duration_for_phase(phase)

	if boss.has_method("stop_attack"):
		boss.call("stop_attack")

	if boss.has_method("open_weak_point"):
		boss.call("open_weak_point")

func _begin_transition(custom_time: float = -1.0) -> void:
	if boss == null:
		return

	state = BossState.TRANSITION
	state_time_left = transition_duration if custom_time <= 0.0 else custom_time

	if boss.has_method("stop_attack"):
		boss.call("stop_attack")

	if boss.has_method("close_weak_point"):
		boss.call("close_weak_point")

func _update_phase() -> void:
	if boss_hits >= 4:
		phase = 3
	elif boss_hits >= 2:
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
	match p:
		1:
			return vulnerable_time_phase_1
		2:
			return vulnerable_time_phase_2
		3:
			return vulnerable_time_phase_3
		_:
			return vulnerable_time_phase_1

func _get_pattern_pool_for_phase(p: int) -> Array[String]:
	match p:
		1:
			return _phase_1_patterns
		2:
			return _phase_2_patterns
		3:
			return _phase_3_patterns
		_:
			return _phase_1_patterns

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

	boss_hits += 1

	if boss.has_method("on_weak_point_hit"):
		boss.call("on_weak_point_hit", boss_hits)

	_force_null_return()

	if boss_hits >= 5:
		_kill_boss()
		return

	_begin_transition(post_hit_buffer)

func _kill_boss() -> void:
	state = BossState.DEAD
	state_time_left = 0.0
	_force_null_return()

	if boss != null and boss.has_method("play_death"):
		boss.call("play_death")

	emit_signal("boss_defeated")

func _on_request_shoot(origin: Vector3, direction: Vector3, size_mult: float = 1.0) -> void:
	if restarting:
		return
	if not Run.null_ready:
		return
	if null_projectile_scene == null:
		return

	Run.null_ready = false
	Run.null_dropped = false
	Signals.null_ready_changed.emit(false)

	var p := null_projectile_scene.instantiate()
	if not (p is Node3D):
		Run.null_ready = true
		Signals.null_ready_changed.emit(true)
		return

	null_instance = p as Node3D
	add_child(null_instance)

	if null_instance.has_method("fire"):
		null_instance.call("fire", origin, direction, size_mult)
	else:
		null_instance.global_position = origin

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
	if restarting:
		return
	if not Run.null_ready:
		return
	if null_projectile_scene == null:
		return

	Run.null_ready = false
	Run.null_dropped = false
	Signals.null_ready_changed.emit(false)

	var p := null_projectile_scene.instantiate()
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
	if restarting:
		return

	restarting = true
	state = BossState.DEAD
	_force_null_return()

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
