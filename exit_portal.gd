# res://Interactables/exit_portal.gd
extends Area3D

@export var arena_scene_path: String = "res://Game/Main.tscn"

var _used: bool = false

func _ready() -> void:
	body_entered.connect(_on_enter)

func _on_enter(body: Node) -> void:
	if _used:
		return
	if not body.is_in_group("player"):
		return

	_used = true

	# Quando torni all'arena (FPS), riprendi il mouse catturato
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# Flag run per non resettare e per spawn random
	Run.returning_from_shop = true
	Run.spawn_player_random = true

	# Cambia scena deferred (siamo in callback fisica)
	call_deferred("_go_arena")

func _go_arena() -> void:
	get_tree().change_scene_to_file(arena_scene_path)
