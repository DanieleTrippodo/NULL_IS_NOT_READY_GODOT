# res://Game/Game.gd
extends Node

@export var arena_scene: PackedScene
@export var player_scene: PackedScene
@export var null_projectile_scene: PackedScene

@export var chaser_scene: PackedScene
@export var turret_scene: PackedScene
@export var enemy_bullet_scene: PackedScene

@onready var arena_root: Node3D = $World/ArenaRoot
@onready var player_root: Node3D = $World/PlayerRoot
@onready var enemies_root: Node3D = $World/EnemiesRoot

var null_instance: Node3D = null
var enemies_alive: int = 0
var arena_instance: Node3D = null

func _ready() -> void:
	Run.reset()

	Signals.request_shoot.connect(_on_request_shoot)
	Signals.request_pickup.connect(_on_request_pickup)
	Signals.enemy_killed.connect(_on_enemy_killed)
	Signals.player_died.connect(_on_player_died)

	_spawn_arena()
	_spawn_player()
	_spawn_wave()

func _spawn_arena() -> void:
	if arena_scene == null:
		push_error("arena_scene non assegnata in Main (inspector).")
		return

	for c in arena_root.get_children():
		c.queue_free()

	var arena := arena_scene.instantiate() as Node3D
	if arena == null:
		push_error("Arena non è un Node3D.")
		return

	arena_root.add_child(arena)
	arena_instance = arena

func _spawn_player() -> void:
	if player_scene == null:
		push_error("player_scene non assegnata in Main (inspector).")
		return

	for c in player_root.get_children():
		c.queue_free()

	var player := player_scene.instantiate() as Node3D
	if player == null:
		push_error("Player non è un Node3D.")
		return

	player_root.add_child(player)
	player.global_position = Vector3(0, 1.2, 0)

func _spawn_wave() -> void:
	if chaser_scene == null:
		push_error("chaser_scene non assegnata in Main (inspector).")
		return
	if turret_scene == null:
		push_error("turret_scene non assegnata in Main (inspector).")
		return
	if enemy_bullet_scene == null:
		push_error("enemy_bullet_scene non assegnata in Main (inspector).")
		return
	if arena_instance == null:
		return

	# pulizia nemici vecchi
	for c in enemies_root.get_children():
		c.queue_free()

	# spawn points dall’arena
	var spawns: Array = []
	if arena_instance.has_method("get_spawn_points"):
		spawns = arena_instance.get_spawn_points()

	var player := player_root.get_child(0) as Node3D
	enemies_alive = 0

	# --- Chaser(s) ---
	for i in range(Constants.START_ENEMIES):
		var e := chaser_scene.instantiate() as Node3D
		if e == null:
			continue

		enemies_root.add_child(e)
		enemies_alive += 1

		var spawn_pos := Vector3(0, 0, 0)
		if i < spawns.size():
			spawn_pos = spawns[i].global_position
		e.global_position = spawn_pos

		if e.has_method("set_target"):
			e.set_target(player)

	# --- Turret(s) ---
	for j in range(int(Constants.START_TURRETS)):
		var t := turret_scene.instantiate() as Node3D
		if t == null:
			continue

		enemies_root.add_child(t)
		enemies_alive += 1

		# prova a usare spawn successivi
		var idx := Constants.START_ENEMIES + j
		var spawn_pos2 := Vector3(0, 0, 0)
		if idx < spawns.size():
			spawn_pos2 = spawns[idx].global_position
		t.global_position = spawn_pos2

		if t.has_method("set_target"):
			t.set_target(player)
		if t.has_method("set_bullet_scene"):
			t.set_bullet_scene(enemy_bullet_scene)

func _on_request_shoot(origin: Vector3, direction: Vector3) -> void:
	if Run.null_ready == false:
		return
	if null_projectile_scene == null:
		push_error("null_projectile_scene non assegnata in Main (inspector).")
		return

	Run.null_ready = false
	Signals.null_ready_changed.emit(false)

	var p := null_projectile_scene.instantiate() as Node3D
	if p == null:
		push_error("NullProjectile non è un Node3D/Area3D.")
		Run.null_ready = true
		Signals.null_ready_changed.emit(true)
		return

	null_instance = p
	$World.add_child(p)

	if p.has_method("fire"):
		p.fire(origin, direction)

func _on_request_pickup() -> void:
	if null_instance == null:
		return

	var player := player_root.get_child(0) as Node3D if player_root.get_child_count() > 0 else null
	if player == null:
		return

	var dist: float = player.global_position.distance_to(null_instance.global_position)
	if dist > 2.0:
		return

	if null_instance.has_method("pickup"):
		null_instance.pickup()

	null_instance = null
	Run.null_ready = true
	Signals.null_ready_changed.emit(true)

func _on_enemy_killed(enemy: Node) -> void:
	if is_instance_valid(enemy):
		enemy.queue_free()

	enemies_alive -= 1

	# su kill, torna READY
	Run.null_ready = true
	Signals.null_ready_changed.emit(true)

	if enemies_alive <= 0:
		Run.depth += 1
		Signals.depth_changed.emit(Run.depth)
		_spawn_wave()

func _on_player_died() -> void:
	get_tree().reload_current_scene()
