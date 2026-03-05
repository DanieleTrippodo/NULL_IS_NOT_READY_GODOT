extends Area3D

@export var enemy_scene: PackedScene           # qui trascini la scena del Chaser
@export var spawn_point_path: NodePath = ^"SpawnPoint"
@export var interact_action: StringName = &"interact"  # se da te E è "interact"
@export var cooldown_sec: float = 0.25
@export var max_alive_from_this_button: int = 1

var _player_in_range := false
var _cd_left := 0.0
var _spawned: Array[Node] = []

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(delta: float) -> void:
	if _cd_left > 0.0:
		_cd_left -= delta

	_cleanup_spawned()

	if not _player_in_range:
		return
	if _cd_left > 0.0:
		return
	if Input.is_action_just_pressed(interact_action):
		_try_spawn()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = true

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = false

func _cleanup_spawned() -> void:
	_spawned = _spawned.filter(func(n): return is_instance_valid(n) and n.is_inside_tree())

func _try_spawn() -> void:
	if enemy_scene == null:
		push_error("TutorialSpawnButton: enemy_scene is null (assign it in Inspector).")
		return

	_cleanup_spawned()
	if max_alive_from_this_button > 0 and _spawned.size() >= max_alive_from_this_button:
		_cd_left = cooldown_sec
		return

	var spawn_point := get_node_or_null(spawn_point_path) as Node3D
	var pos := (spawn_point.global_position if spawn_point != null else global_position)

	var e := enemy_scene.instantiate()

	# IMPORTANTE: prima add_child, poi global_position
	get_tree().current_scene.add_child(e)

	if e is Node3D:
		(e as Node3D).global_position = pos

	# Target al player se supportato
	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		if e.has_method("set_target"):
			e.call("set_target", player)
		elif "target" in e:
			e.set("target", player)

	_spawned.append(e)
	_cd_left = cooldown_sec
