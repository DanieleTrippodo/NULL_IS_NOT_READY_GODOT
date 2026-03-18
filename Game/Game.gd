# res://Game/Game.gd
extends Node

@export var arena_scene: PackedScene
@export var arena_wave_scenes: Array[PackedScene] = []
@export var player_scene: PackedScene
@export var null_projectile_scene: PackedScene
@export var chaser_scene: PackedScene
@export var turret_scene: PackedScene
@export var drifter_turret_scene: PackedScene
@export var stealer_scene: PackedScene
@export var spike_scene: PackedScene
@export var exception_scene: PackedScene
@export var enemy_bullet_scene: PackedScene
@onready var kill_sfx: AudioStreamPlayer = $KillSfx
@onready var combat_bgm: AudioStreamPlayer = $CombatBgm
@export var enemy_death_fx_scene: PackedScene

# money + shop
@export var money_cube_scene: PackedScene
@export var shop_portal_scene: PackedScene

@onready var world: Node3D = $World
@onready var arena_root: Node3D = $World/ArenaRoot
@onready var player_root: Node3D = $World/PlayerRoot
@onready var enemies_root: Node3D = $World/EnemiesRoot
@onready var hud: Node = $UIRoot/HUD

@export var terminal_scene: PackedScene
@export var terminal_overlay_scene: PackedScene
@export var terminal_log_scenes: Array[PackedScene] = []
@export var terminal_every_n_depth: int = 3

@export var tutorial_mode: bool = false
@export var game_over_overlay_scene: PackedScene
@export var pause_terminal_scene: PackedScene
@export var pause_bgm_volume_db: float = -24.0

var game_over_overlay: Control = null
var pause_terminal: CanvasLayer = null
var pause_active: bool = false
var combat_bgm_default_volume_db: float = -15.0

var rng := RandomNumberGenerator.new()
var terminal_instance: Node3D = null
var terminal_overlay: CanvasLayer = null

var arena_instance: Node3D = null
var null_instance: Node3D = null
var enemies_alive: int = 0

var restarting: bool = false
var wave_transitioning: bool = false
var world_frozen: bool = false

enum ArenaState { WAIT_START, IN_WAVE, POST_WAVE }
var arena_state: int = ArenaState.WAIT_START

var wave_button: Node = null
var shop_portal_instance: Node3D = null
var spawned_money: Array[Node3D] = []

@export var enemy_money_drop_min: int = 0
@export var enemy_money_drop_max: int = 2
@export var money_spawn_interval: float = 0.04
@export var money_drop_scatter_radius: float = 0.9

@export var magnet_radius: float = 2.2
@export var auto_wave_delay: float = 0.35
@export var end_wave_collect_delay: float = 0.80

const PLAYER_SAFE_RADIUS: float = 4.0
const ENEMY_SPAWN_MIN_RADIUS: float = 1.8
const ENEMY_SPAWN_PLAYER_MIN_RADIUS: float = 3.0

const FLOOR_RAY_UP: float = 10.0
const FLOOR_RAY_DOWN: float = 80.0
const FLOOR_EPS: float = 0.03

const FADE_TIME: float = 0.25
const WAVE_FREEZE_TIME: float = 0.35

const KILL_FLASH_TIME := 0.09

func _ready() -> void:
	rng.randomize()
	Engine.time_scale = 1.0
	combat_bgm_default_volume_db = combat_bgm.volume_db if combat_bgm != null else pause_bgm_volume_db

	if not Run.returning_from_shop:
		Run.reset()
	else:
		Run.returning_from_shop = false

	restarting = false
	wave_transitioning = false
	world_frozen = false

	Signals.request_shoot.connect(_on_request_shoot)
	Signals.request_pickup.connect(_on_request_pickup)
	Signals.request_pull_to_hand.connect(_on_request_pull_to_hand)
	Signals.request_recovery_start.connect(_on_request_recovery_start)
	Signals.request_recovery_stop.connect(_on_request_recovery_stop)
	Signals.request_force_drop_null.connect(_on_request_force_drop_null)
	Signals.null_dropped.connect(_on_null_dropped)

	Signals.enemy_killed.connect(_on_enemy_killed)
	Signals.player_died.connect(_on_player_died)

	_spawn_arena(_get_arena_scene_for_depth(Run.depth))
	_spawn_player()

	Signals.depth_changed.emit(Run.depth)
	Signals.null_ready_changed.emit(Run.null_ready)

	_setup_wave_button()
	_set_state(ArenaState.WAIT_START)
	_setup_terminal_overlay()
	_setup_game_over_overlay()
	_setup_pause_terminal()
	
	_stop_combat_bgm()

	if not tutorial_mode:
		_queue_auto_start_next_wave()

func _play_combat_bgm() -> void:
	if combat_bgm == null:
		return
	if combat_bgm.playing:
		return
	combat_bgm.play()

func _stop_combat_bgm() -> void:
	if combat_bgm == null:
		return
	if not combat_bgm.playing:
		return
	combat_bgm.stop()

func _play_kill_sfx() -> void:
	if kill_sfx == null:
		return
	kill_sfx.pitch_scale = rng.randf_range(0.92, 1.08)
	kill_sfx.play()

func _flash_enemy(enemy: Node) -> void:
	if enemy == null or not (enemy is Node3D):
		return

	var e := enemy as Node3D
	var mesh_node := e.find_child("MeshInstance3D", true, false)
	if mesh_node == null or not (mesh_node is MeshInstance3D):
		return

	var mesh := mesh_node as MeshInstance3D
	var prev_mat := mesh.material_override

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = Color(1, 1, 1)
	mat.albedo_color = Color(1, 1, 1, 1)

	mesh.material_override = mat

	var tw := get_tree().create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, KILL_FLASH_TIME)
	tw.tween_callback(func():
		if is_instance_valid(mesh):
			mesh.material_override = prev_mat
	)

func _disable_enemy(enemy: Node) -> void:
	if enemy == null:
		return

	enemy.set_physics_process(false)
	enemy.set_process(false)

	var cs := enemy.find_child("CollisionShape3D", true, false)
	if cs != null and cs is CollisionShape3D:
		(cs as CollisionShape3D).disabled = true

func _setup_terminal_overlay() -> void:
	if terminal_overlay_scene == null:
		return

	var o := terminal_overlay_scene.instantiate()
	if not (o is CanvasLayer):
		return

	terminal_overlay = o as CanvasLayer
	$UIRoot.add_child(terminal_overlay)
	terminal_overlay.visible = false

	if terminal_overlay.has_signal("closed"):
		terminal_overlay.closed.connect(_on_terminal_closed)

func _setup_game_over_overlay() -> void:
	if game_over_overlay_scene == null:
		return

	var o := game_over_overlay_scene.instantiate()
	if o == null:
		return

	$UIRoot.add_child(o)

	if o is Control:
		game_over_overlay = o as Control

	if game_over_overlay != null:
		if game_over_overlay.has_signal("retry_pressed"):
			game_over_overlay.retry_pressed.connect(_on_game_over_retry_pressed)
		if game_over_overlay.has_signal("exit_pressed"):
			game_over_overlay.exit_pressed.connect(_on_game_over_exit_pressed)

func _setup_pause_terminal() -> void:
	if pause_terminal_scene == null:
		return

	var o := pause_terminal_scene.instantiate()
	if not (o is CanvasLayer):
		return

	pause_terminal = o as CanvasLayer
	$UIRoot.add_child(pause_terminal)
	pause_terminal.visible = false

	if pause_terminal.has_signal("command_requested"):
		pause_terminal.command_requested.connect(_on_pause_terminal_command_requested)

func _can_open_pause_terminal() -> bool:
	if pause_terminal == null:
		return false
	if pause_active or restarting or wave_transitioning:
		return false
	if terminal_overlay != null and terminal_overlay.visible:
		return false
	if game_over_overlay != null and game_over_overlay.visible:
		return false
	return true

func _open_pause_terminal() -> void:
	if not _can_open_pause_terminal():
		return

	pause_active = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if pause_terminal != null and pause_terminal.has_method("open_terminal"):
		pause_terminal.call("open_terminal")

	get_tree().paused = true
	_set_pause_bgm_attenuation(true)

func _close_pause_terminal() -> void:
	if not pause_active:
		return

	if pause_terminal != null and pause_terminal.has_method("close_terminal"):
		pause_terminal.call("close_terminal")

	get_tree().paused = false
	pause_active = false
	_set_pause_bgm_attenuation(false)

	if not restarting:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _close_pause_terminal_for_scene_change() -> void:
	if pause_terminal != null and pause_terminal.has_method("close_terminal"):
		pause_terminal.call("close_terminal")

	get_tree().paused = false
	pause_active = false
	_set_pause_bgm_attenuation(false)

func _set_pause_bgm_attenuation(paused_state: bool) -> void:
	if combat_bgm == null:
		return

	combat_bgm.volume_db = pause_bgm_volume_db if paused_state else combat_bgm_default_volume_db

func _on_pause_terminal_command_requested(command: String) -> void:
	match command:
		"resume":
			_close_pause_terminal()
		"restart":
			_close_pause_terminal_for_scene_change()
			_stop_combat_bgm()
			Run.reset()
			get_tree().reload_current_scene()
		"menu":
			_close_pause_terminal_for_scene_change()
			_stop_combat_bgm()
			Run.reset()
			get_tree().change_scene_to_file("res://UI/main_menu.tscn")
		"quit":
			_close_pause_terminal_for_scene_change()
			_stop_combat_bgm()
			Run.reset()
			get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	if restarting or pause_active:
		return

	if event.is_action_pressed("esc"):
		_open_pause_terminal()

func _physics_process(_delta: float) -> void:
	if restarting or wave_transitioning:
		Engine.time_scale = 1.0
		return

	if null_instance != null and not is_instance_valid(null_instance):
		null_instance = null

	if Run.slowmo_recovery and Run.null_dropped:
		Engine.time_scale = Run.slowmo_scale
	else:
		Engine.time_scale = 1.0

	if Run.pickup_magnet and Run.null_dropped:
		if null_instance != null and is_instance_valid(null_instance):
			var player := _get_player()
			if player != null:
				if player.global_position.distance_to(null_instance.global_position) <= magnet_radius:
					_on_request_pickup()

# ------------------------------------------------------------
# Wave button / block flow
# ------------------------------------------------------------
func _is_shop_checkpoint_depth() -> bool:
	if tutorial_mode:
		return false
	return Run.depth > 1 and (((Run.depth - 1) % 5) == 0)

func _should_show_wave_button() -> bool:
	if tutorial_mode:
		return arena_state == ArenaState.WAIT_START

	return arena_state == ArenaState.WAIT_START and (Run.depth == 1 or _is_shop_checkpoint_depth())

func _refresh_wave_button() -> void:
	if wave_button == null:
		return

	var active := _should_show_wave_button()
	wave_button.set("enabled", active)

	if wave_button is Node3D:
		(wave_button as Node3D).visible = active

func _setup_wave_button() -> void:
	if arena_instance == null:
		return

	wave_button = arena_instance.get_node_or_null("WaveStartButton")
	if wave_button != null and wave_button.has_signal("pressed"):
		var cb := Callable(self, "_on_wave_button_pressed")
		if not wave_button.pressed.is_connected(cb):
			wave_button.pressed.connect(cb)

	_refresh_wave_button()

func _on_wave_button_pressed() -> void:
	if restarting or wave_transitioning:
		return
	if arena_state != ArenaState.WAIT_START:
		return

	call_deferred("_start_next_wave")

func _set_state(s: int) -> void:
	arena_state = s
	_refresh_wave_button()

func _queue_auto_start_next_wave() -> void:
	if tutorial_mode:
		return
	if restarting or wave_transitioning:
		return
	if arena_state != ArenaState.WAIT_START:
		return
	if _should_show_wave_button():
		return

	call_deferred("_auto_start_next_wave_async")

func _auto_start_next_wave_async() -> void:
	await get_tree().create_timer(auto_wave_delay).timeout

	if tutorial_mode:
		return
	if restarting or wave_transitioning:
		return
	if arena_state != ArenaState.WAIT_START:
		return
	if _should_show_wave_button():
		return

	_start_next_wave()

func _queue_post_wave_auto_continue() -> void:
	if tutorial_mode:
		return
	if restarting or wave_transitioning:
		return
	if arena_state != ArenaState.WAIT_START:
		return
	if _should_show_wave_button():
		return

	call_deferred("_post_wave_auto_continue_async")

func _post_wave_auto_continue_async() -> void:
	await get_tree().create_timer(end_wave_collect_delay).timeout

	if tutorial_mode:
		return
	if restarting or wave_transitioning:
		return
	if arena_state != ArenaState.WAIT_START:
		return
	if _should_show_wave_button():
		return

	_start_next_wave()

func _start_next_wave() -> void:
	_play_combat_bgm()
	_despawn_terminal()
	_cleanup_uncollected_money()
	_cleanup_shop_portal()

	_set_state(ArenaState.IN_WAVE)
	await _wave_transition()

# ------------------------------------------------------------
# Wave transition
# ------------------------------------------------------------
func _wave_transition() -> void:
	if restarting or wave_transitioning:
		return

	wave_transitioning = true

	await _freeze_and_fade(true)

	_swap_arena_for_current_depth()
	_spawn_wave()

	await _freeze_and_fade(false)

	wave_transitioning = false

func _swap_arena_for_current_depth() -> void:
	var next_arena_scene := _get_arena_scene_for_depth(Run.depth)
	if next_arena_scene == null:
		return

	var player := _get_player()

	_spawn_arena(next_arena_scene)
	_setup_wave_button()

	if player != null:
		var spawn_pos := _get_player_spawn_pos()
		player.global_position = _place_body_on_floor(player, spawn_pos)

# ------------------------------------------------------------
# Spawn arena / player
# ------------------------------------------------------------
func _spawn_arena(scene_to_spawn: PackedScene = null) -> void:
	_free_children(arena_root)

	var chosen_scene: PackedScene = scene_to_spawn
	if chosen_scene == null:
		chosen_scene = arena_scene

	if chosen_scene == null:
		push_error("arena_scene non assegnata.")
		return

	var a := chosen_scene.instantiate()
	if not (a is Node3D):
		push_error("La scena arena deve istanziare un Node3D.")
		return

	arena_root.add_child(a)
	arena_instance = a as Node3D

func _get_arena_scene_for_depth(_depth: int) -> PackedScene:
	var all_arenas: Array[PackedScene] = []

	if arena_scene != null:
		all_arenas.append(arena_scene)

	for a in arena_wave_scenes:
		if a != null:
			all_arenas.append(a)

	if all_arenas.is_empty():
		return null

	var index := rng.randi_range(0, all_arenas.size() - 1)
	return all_arenas[index]

func _spawn_player() -> void:
	_free_children(player_root)

	if player_scene == null:
		push_error("player_scene non assegnata.")
		return

	var p := player_scene.instantiate()
	if not (p is Node3D):
		push_error("player_scene deve istanziare un Node3D.")
		return

	player_root.add_child(p)

	var player := p as Node3D
	var spawn_pos := _get_player_spawn_pos()

	if Run.spawn_player_random:
		Run.spawn_player_random = false
		spawn_pos = _get_random_arena_pos()

	player.global_position = _place_body_on_floor(player, spawn_pos)
	player.set_physics_process(not world_frozen)

# ------------------------------------------------------------
# Spawn wave
# ------------------------------------------------------------
func _spawn_wave() -> void:
	if restarting:
		return

	_free_children(enemies_root)
	enemies_alive = 0

	if arena_instance == null:
		return

	var spawns: Array[Node3D] = _get_enemy_spawns()
	if spawns.is_empty():
		spawns.append(_make_temp_marker(Vector3(-8, 0, -8)))
		spawns.append(_make_temp_marker(Vector3(8, 0, -8)))
		spawns.append(_make_temp_marker(Vector3(0, 0, 8)))

	spawns.shuffle()

	var d: int = Run.depth

	var total: int = clampi(2 + d, 2, 10)
	var turrets: int = clampi(floori(float(d) / 3.0), 0, 3)
	var spikes: int = clampi(floori(float(d) / 2.0), 0, 4)

	var drifters: int = 0
	if d >= 4 and drifter_turret_scene != null:
		var p_drifter: float = clampf(0.22 + float(d - 4) * 0.05, 0.0, 0.70)
		if rng.randf() < p_drifter:
			drifters = 1
		if d >= 9 and rng.randf() < 0.18:
			drifters += 1

	var exceptions: int = 0
	if d >= 4:
		var p_elite: float = clampf(0.12 + float(d - 4) * 0.03, 0.0, 0.45)
		if rng.randf() < p_elite:
			exceptions = 1

	var stealers: int = 0
	if d >= 3 and stealer_scene != null:
		var p_stealer: float = clampf(0.30 + float(d - 3) * 0.06, 0.0, 0.70)
		if rng.randf() < p_stealer:
			stealers = 1
		if d >= 8 and rng.randf() < 0.20:
			stealers += 1

	var chasers: int = max(1, total - turrets - drifters - spikes - exceptions - stealers)

	var player := _get_player()
	var used: Array[int] = []

	for i in range(chasers):
		var idx := _pick_spawn_index(spawns.size(), used)
		used.append(idx)

		var e := _spawn_enemy(chaser_scene, spawns[idx].global_position)
		if e != null and player != null and e.has_method("set_target"):
			e.call("set_target", player)

	for j in range(turrets):
		var idx2 := _pick_spawn_index(spawns.size(), used)
		used.append(idx2)

		var t := _spawn_enemy(turret_scene, spawns[idx2].global_position)
		if t != null and player != null:
			if t.has_method("set_target"):
				t.call("set_target", player)

			if enemy_bullet_scene != null and t.has_method("set_bullet_scene"):
				t.call("set_bullet_scene", enemy_bullet_scene)

			if t.has_method("set_fire_interval"):
				var base_interval: float = 1.6
				var v: Variant = t.get("fire_interval")
				if typeof(v) != TYPE_NIL:
					base_interval = float(v)
				t.call("set_fire_interval", base_interval * Run.turret_interval_mult)

	for j2 in range(drifters):
		var idx_d := _pick_spawn_index(spawns.size(), used)
		used.append(idx_d)

		var dt := _spawn_enemy(drifter_turret_scene, spawns[idx_d].global_position)
		if dt != null and player != null:
			if dt.has_method("set_target"):
				dt.call("set_target", player)

			if enemy_bullet_scene != null and dt.has_method("set_bullet_scene"):
				dt.call("set_bullet_scene", enemy_bullet_scene)

			if dt.has_method("set_fire_interval"):
				var base_interval_d: float = 1.9
				var vd: Variant = dt.get("fire_interval")
				if typeof(vd) != TYPE_NIL:
					base_interval_d = float(vd)
				dt.call("set_fire_interval", base_interval_d * Run.turret_interval_mult)

	for k in range(spikes):
		var idx3 := _pick_spawn_index(spawns.size(), used)
		used.append(idx3)

		var s := _spawn_enemy(spike_scene, spawns[idx3].global_position)
		if s != null and player != null and s.has_method("set_target"):
			s.call("set_target", player)

	for m in range(exceptions):
		var idx4 := _pick_spawn_index(spawns.size(), used)
		used.append(idx4)

		var ex := _spawn_enemy(exception_scene, spawns[idx4].global_position)
		if ex != null and player != null and ex.has_method("set_target"):
			ex.call("set_target", player)

	for n in range(stealers):
		var idx5 := _pick_spawn_index(spawns.size(), used)
		used.append(idx5)

		var st := _spawn_enemy(stealer_scene, spawns[idx5].global_position)
		if st != null and player != null and st.has_method("set_target"):
			st.call("set_target", player)

	enemies_alive = chasers + turrets + drifters + spikes + exceptions + stealers

	if player != null:
		_place_player_safe(player, spawns)

func _spawn_enemy(scene: PackedScene, desired_pos: Vector3) -> Node3D:
	if scene == null:
		return null

	var n := scene.instantiate()
	if not (n is Node3D):
		return null

	var body := n as Node3D
	enemies_root.add_child(body)
	body.set_physics_process(not world_frozen)

	var final_pos := _pick_enemy_spawn_position(body, desired_pos)
	body.global_position = final_pos

	return body

# ------------------------------------------------------------
# NULL / player requests
# ------------------------------------------------------------
func _on_request_shoot(origin: Vector3, direction: Vector3, _extra: Variant = null) -> void:
	if restarting or wave_transitioning:
		return
	if world_frozen:
		return
	if not Run.null_ready:
		return

	Run.null_ready = false
	Run.null_dropped = false
	Signals.null_ready_changed.emit(false)

	var p := null_projectile_scene.instantiate()
	if not (p is Node3D):
		Run.null_ready = true
		Signals.null_ready_changed.emit(true)
		return

	var proj := p as Node3D
	world.add_child(proj)
	null_instance = proj

	if proj.has_method("fire"):
		proj.call("fire", origin, direction)
	else:
		proj.global_position = origin

func _on_request_force_drop_null(pos: Vector3) -> void:
	if restarting or wave_transitioning:
		return
	if world_frozen:
		return
	if not Run.null_ready:
		return

	Run.null_ready = false
	Run.null_dropped = false
	Signals.null_ready_changed.emit(false)

	var p := null_projectile_scene.instantiate()
	if not (p is Node3D):
		Run.null_ready = true
		Signals.null_ready_changed.emit(true)
		return

	var proj := p as Node3D
	world.add_child(proj)
	null_instance = proj
	proj.global_position = pos

	if proj.has_method("_drop"):
		proj.call("_drop")

func _on_request_pickup() -> void:
	if restarting or wave_transitioning:
		return
	if null_instance == null or not is_instance_valid(null_instance):
		return

	var player := _get_player()
	if player == null:
		return

	var pickup_radius := 1.6
	if Run.pickup_magnet:
		pickup_radius = magnet_radius

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

func _on_request_pull_to_hand() -> void:
	if restarting or wave_transitioning:
		return
	if null_instance == null or not is_instance_valid(null_instance):
		return
	if null_instance.has_method("pull_to_hand"):
		null_instance.call("pull_to_hand")

func _on_request_recovery_start() -> void:
	if restarting or wave_transitioning:
		return
	if null_instance == null or not is_instance_valid(null_instance):
		return
	if not Run.null_dropped:
		return

	var player := _get_player()
	if player == null:
		return

	if null_instance.has_method("start_remote_recovery"):
		null_instance.call("start_remote_recovery", player)

func _on_request_recovery_stop() -> void:
	if null_instance == null or not is_instance_valid(null_instance):
		return

	if null_instance.has_method("stop_remote_recovery"):
		null_instance.call("stop_remote_recovery")

func _on_null_dropped(_arg: Variant = null) -> void:
	Run.null_dropped = true

# ------------------------------------------------------------
# Enemy killed / wave end
# ------------------------------------------------------------
func _on_enemy_killed(enemy: Node) -> void:
	if restarting or wave_transitioning:
		return

	var death_pos := Vector3.ZERO
	var can_drop_money := false

	if is_instance_valid(enemy):
		death_pos = enemy.global_position
		can_drop_money = true

		_spawn_enemy_death_fx(death_pos)
		_disable_enemy(enemy)
		_play_kill_sfx()
		_flash_enemy(enemy)

		get_tree().create_timer(KILL_FLASH_TIME).timeout.connect(
			Callable(self, "_queue_free_if_valid").bind(enemy)
		)

	if can_drop_money:
		_spawn_enemy_money_drop(death_pos)

	enemies_alive -= 1

	if enemies_alive > 0:
		return

	_force_null_return()

	if tutorial_mode:
		_set_state(ArenaState.WAIT_START)
		return

	Run.depth += 1
	Signals.depth_changed.emit(Run.depth)

	_set_state(ArenaState.POST_WAVE)
	_set_state(ArenaState.WAIT_START)

	if _is_shop_checkpoint_depth():
		_stop_combat_bgm()
		_spawn_shop_portal()
		_maybe_spawn_terminal_in_shop()
	else:
		_cleanup_shop_portal()
		_despawn_terminal()
		_queue_post_wave_auto_continue()

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

# ------------------------------------------------------------
# Money
# ------------------------------------------------------------
func _spawn_enemy_money_drop(center_pos: Vector3) -> void:
	if money_cube_scene == null:
		return

	var amount := rng.randi_range(enemy_money_drop_min, enemy_money_drop_max)
	if amount <= 0:
		return

	call_deferred("_spawn_money_drop_async", center_pos, amount)

func _spawn_money_drop_async(center_pos: Vector3, amount: int) -> void:
	for i in range(amount):
		var m := money_cube_scene.instantiate()
		if m is Node3D:
			var cube := m as Node3D
			world.add_child(cube)
			cube.set_physics_process(not world_frozen)

			var angle := rng.randf_range(0.0, TAU)
			var rr := sqrt(rng.randf()) * money_drop_scatter_radius
			var desired := center_pos + Vector3(cos(angle) * rr, 0.0, sin(angle) * rr)

			cube.global_position = _place_body_on_floor(cube, desired)
			spawned_money.append(cube)

		if i < amount - 1:
			await get_tree().create_timer(money_spawn_interval).timeout

func _cleanup_uncollected_money() -> void:
	for n in spawned_money:
		if is_instance_valid(n):
			n.queue_free()
	spawned_money.clear()

# ------------------------------------------------------------
# Shop portal
# ------------------------------------------------------------
func _spawn_shop_portal() -> void:
	if shop_portal_scene == null or arena_instance == null:
		return

	_cleanup_shop_portal()

	var p := shop_portal_scene.instantiate()
	if not (p is Node3D):
		return

	shop_portal_instance = p as Node3D
	world.add_child(shop_portal_instance)
	shop_portal_instance.global_position = arena_instance.global_position + Vector3(2.0, 0.0, 0.0)
	shop_portal_instance.set_physics_process(not world_frozen)

func _cleanup_shop_portal() -> void:
	if shop_portal_instance != null and is_instance_valid(shop_portal_instance):
		shop_portal_instance.queue_free()
	shop_portal_instance = null

# ------------------------------------------------------------
# Freeze / fade
# ------------------------------------------------------------
func _freeze_and_fade(to_black: bool) -> void:
	_set_world_frozen(true)

	if to_black:
		if hud != null and hud.has_method("fade_out"):
			await hud.fade_out(FADE_TIME)
		await get_tree().create_timer(WAVE_FREEZE_TIME).timeout
	else:
		if hud != null and hud.has_method("fade_in"):
			await hud.fade_in(FADE_TIME)

	_set_world_frozen(false)

func _set_world_frozen(v: bool) -> void:
	world_frozen = v

	var player := _get_player()
	if player != null:
		player.set_physics_process(not v)

	for e in enemies_root.get_children():
		if e is Node:
			(e as Node).set_physics_process(not v)

	for n in spawned_money:
		if is_instance_valid(n):
			(n as Node).set_physics_process(not v)

	if shop_portal_instance != null and is_instance_valid(shop_portal_instance):
		(shop_portal_instance as Node).set_physics_process(not v)

# ------------------------------------------------------------
# Player died / game over
# ------------------------------------------------------------
func _on_player_died() -> void:
	if restarting:
		return

	restarting = true
	_stop_combat_bgm()

	_cleanup_uncollected_money()
	_cleanup_shop_portal()

	_set_world_frozen(true)

	var player := _get_player()
	if player != null:
		player.set_process_input(false)
		player.set_process_unhandled_input(false)
		player.set_physics_process(false)

	if game_over_overlay != null and game_over_overlay.has_method("show_game_over"):
		await game_over_overlay.show_game_over()
	else:
		call_deferred("_restart_run")

func _on_game_over_retry_pressed() -> void:
	_stop_combat_bgm()
	Run.reset()
	get_tree().reload_current_scene()

func _on_game_over_exit_pressed() -> void:
	_stop_combat_bgm()
	Run.reset()
	get_tree().change_scene_to_file("res://UI/main_menu.tscn")

func _restart_run() -> void:
	if hud != null and hud.has_method("fade_out"):
		await hud.fade_out(FADE_TIME)

	Run.reset()
	get_tree().reload_current_scene()

# ------------------------------------------------------------
# Helpers
# ------------------------------------------------------------
func _get_player() -> Node3D:
	var p := get_tree().get_first_node_in_group("player")
	if p != null and p is Node3D:
		return p as Node3D
	return null

func _free_children(node: Node) -> void:
	for c in node.get_children():
		c.queue_free()

func _make_temp_marker(pos: Vector3) -> Node3D:
	var m := Node3D.new()
	world.add_child(m)
	m.global_position = pos
	return m

func _get_enemy_spawns() -> Array[Node3D]:
	if arena_instance == null:
		return []

	var sp := arena_instance.get_node_or_null("SpawnPoints")
	if sp == null:
		return []

	var out: Array[Node3D] = []
	for c in sp.get_children():
		if c is Node3D and c.name.begins_with("Spawn_"):
			out.append(c)

	return out

func _pick_spawn_index(count: int, used: Array[int]) -> int:
	if count <= 0:
		return 0

	for _i in range(32):
		var idx := rng.randi_range(0, count - 1)
		if used.has(idx):
			continue
		return idx

	return rng.randi_range(0, count - 1)

func _place_player_safe(player: Node3D, _spawns: Array[Node3D]) -> void:
	var ps := _get_player_spawn_pos()
	player.global_position = _place_body_on_floor(player, ps)

func _is_enemy_spawn_clear(pos: Vector3, body: Node3D, min_radius: float) -> bool:
	for e in enemies_root.get_children():
		if e == body:
			continue
		if not (e is Node3D):
			continue

		var ep := (e as Node3D).global_position
		var dx := ep.x - pos.x
		var dz := ep.z - pos.z

		if (dx * dx + dz * dz) < (min_radius * min_radius):
			return false

	return true

func _pick_enemy_spawn_position(body: Node3D, desired_pos: Vector3) -> Vector3:
	var player := _get_player()

	for _i in range(24):
		var angle := rng.randf_range(0.0, TAU)
		var radius := rng.randf_range(0.0, 2.2)
		var candidate := desired_pos + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		var placed := _place_body_on_floor(body, candidate)

		if not _is_enemy_spawn_clear(placed, body, ENEMY_SPAWN_MIN_RADIUS):
			continue

		if player != null:
			var dxp := player.global_position.x - placed.x
			var dzp := player.global_position.z - placed.z
			if (dxp * dxp + dzp * dzp) < (ENEMY_SPAWN_PLAYER_MIN_RADIUS * ENEMY_SPAWN_PLAYER_MIN_RADIUS):
				continue

		return placed

	return _place_body_on_floor(body, desired_pos)

func _get_random_arena_pos() -> Vector3:
	var spawns := _get_enemy_spawns()
	if spawns.is_empty():
		return _get_player_spawn_pos()

	spawns.shuffle()
	return spawns[0].global_position

func _get_player_spawn_pos() -> Vector3:
	if arena_instance == null:
		return Vector3.ZERO

	var sp := arena_instance.get_node_or_null("SpawnPoints")
	if sp != null:
		var ps := sp.get_node_or_null("PlayerSpawn")
		if ps != null and ps is Node3D:
			return (ps as Node3D).global_position

	var ps2 := arena_instance.get_node_or_null("PlayerSpawn")
	if ps2 != null and ps2 is Node3D:
		return (ps2 as Node3D).global_position

	return arena_instance.global_position

func _hitstop(seconds: float = 0.045) -> void:
	if world_frozen:
		return

	_set_world_frozen(true)
	await get_tree().create_timer(seconds).timeout
	_set_world_frozen(false)

func _place_body_on_floor(body: Node3D, desired_pos: Vector3) -> Vector3:
	var floor_y: float = _raycast_floor_y(desired_pos, body)
	var offset_y: float = _compute_body_floor_offset_y(body)
	return Vector3(desired_pos.x, floor_y + offset_y, desired_pos.z)

func _raycast_floor_y(pos: Vector3, exclude_body: Node3D) -> float:
	var vp := get_viewport()
	if vp == null:
		return pos.y

	var w: World3D = vp.get_world_3d()
	if w == null:
		return pos.y

	var space: PhysicsDirectSpaceState3D = w.direct_space_state

	var from_pos: Vector3 = pos + Vector3(0, FLOOR_RAY_UP, 0)
	var to_pos: Vector3 = pos - Vector3(0, FLOOR_RAY_DOWN, 0)

	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from_pos, to_pos)
	query.collide_with_areas = false
	query.collide_with_bodies = true

	if exclude_body != null and exclude_body is CollisionObject3D:
		query.exclude = [(exclude_body as CollisionObject3D).get_rid()]

	var hit: Dictionary = space.intersect_ray(query)
	if not hit.is_empty() and hit.has("position"):
		return (hit["position"] as Vector3).y

	return pos.y

func _compute_body_floor_offset_y(body: Node3D) -> float:
	var cs: CollisionShape3D = _find_first_collision_shape(body)
	if cs == null or cs.shape == null:
		return 1.0 + FLOOR_EPS

	var half_height: float = 0.5
	var sh: Shape3D = cs.shape

	if sh is CapsuleShape3D:
		var cap := sh as CapsuleShape3D
		half_height = (cap.height * 0.5) + cap.radius
	elif sh is BoxShape3D:
		var box := sh as BoxShape3D
		half_height = box.size.y * 0.5
	elif sh is SphereShape3D:
		var sph := sh as SphereShape3D
		half_height = sph.radius
	elif sh is CylinderShape3D:
		var cyl := sh as CylinderShape3D
		half_height = cyl.height * 0.5

	var cs_y_in_body: float = body.to_local(cs.global_position).y
	var bottom_local: float = cs_y_in_body - half_height
	return -bottom_local + FLOOR_EPS

func _find_first_collision_shape(n: Node) -> CollisionShape3D:
	for c in n.get_children():
		if c is CollisionShape3D:
			return c

		var r := _find_first_collision_shape(c)
		if r != null:
			return r

	return null

# ------------------------------------------------------------
# Terminal / logs only in shop pause
# ------------------------------------------------------------
func _get_pending_terminal_log_index_for_shop() -> int:
	if terminal_every_n_depth <= 0:
		return -1
	if terminal_log_scenes.is_empty():
		return -1

	if Run.terminal_logs_read.size() != terminal_log_scenes.size():
		Run.terminal_logs_read.resize(terminal_log_scenes.size())
		for i in range(Run.terminal_logs_read.size()):
			if Run.terminal_logs_read[i] == null:
				Run.terminal_logs_read[i] = false

	var completed_depth: int = maxi(Run.depth - 1, 0)
	var unlocked_count: int = int(floor(float(completed_depth) / float(terminal_every_n_depth)))
	var max_index: int = mini(unlocked_count - 1, terminal_log_scenes.size() - 1)

	if max_index < 0:
		return -1

	for i in range(max_index + 1):
		if not bool(Run.terminal_logs_read[i]):
			return i

	return -1

func _maybe_spawn_terminal_in_shop() -> void:
	_despawn_terminal()

	if arena_state != ArenaState.WAIT_START:
		return

	if not _is_shop_checkpoint_depth():
		return

	var log_index := _get_pending_terminal_log_index_for_shop()
	if log_index == -1:
		return

	_spawn_terminal(log_index)

func _spawn_terminal(log_index: int) -> void:
	if terminal_scene == null or arena_instance == null:
		return

	var t := terminal_scene.instantiate()
	if not (t is Node3D):
		return

	terminal_instance = t as Node3D
	world.add_child(terminal_instance)

	var marker := arena_instance.get_node_or_null("SpawnPoints/TerminalSpawn")
	if marker != null and marker is Node3D:
		terminal_instance.global_position = (marker as Node3D).global_position
	else:
		if wave_button != null and wave_button is Node3D:
			terminal_instance.global_position = (wave_button as Node3D).global_position + Vector3(1.2, 0.0, 0.0)
		else:
			terminal_instance.global_position = arena_instance.global_position

	if terminal_instance.has_signal("pressed"):
		var cb := Callable(self, "_on_terminal_pressed").bind(log_index)
		if not terminal_instance.pressed.is_connected(cb):
			terminal_instance.pressed.connect(cb)

func _despawn_terminal() -> void:
	if terminal_instance != null and is_instance_valid(terminal_instance):
		terminal_instance.queue_free()
	terminal_instance = null

func _on_terminal_pressed(log_index: int) -> void:
	if terminal_overlay == null:
		return
	if arena_state != ArenaState.WAIT_START:
		return

	if log_index >= 0 and log_index < Run.terminal_logs_read.size():
		Run.terminal_logs_read[log_index] = true

	if terminal_instance != null and is_instance_valid(terminal_instance):
		terminal_instance.set("enabled", false)

	var p := _get_player()
	if p != null and p.has_method("set_input_locked"):
		p.call("set_input_locked", true)

	terminal_overlay.open_log(terminal_log_scenes[log_index])

func _on_terminal_closed() -> void:
	var player := _get_player()
	if player != null and player.has_method("set_input_locked"):
		player.call("set_input_locked", false)

	await get_tree().process_frame
	while Input.is_action_pressed("interact"):
		await get_tree().process_frame

	if terminal_instance != null and is_instance_valid(terminal_instance):
		terminal_instance.set("enabled", true)

func _queue_free_if_valid(node: Node) -> void:
	if is_instance_valid(node):
		node.queue_free()

func _spawn_enemy_death_fx(pos: Vector3) -> void:
	if enemy_death_fx_scene == null:
		return

	var fx := enemy_death_fx_scene.instantiate()
	add_child(fx)
	fx.global_position = pos
