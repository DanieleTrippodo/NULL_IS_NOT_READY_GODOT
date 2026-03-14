extends Node3D

# Debug / playtest helper:
# place this button inside the tutorial arena to jump directly to the final boss scene.
# Useful when you want to test boss flow without replaying the whole tutorial.

@export var enabled: bool = true
@export var action_name: StringName = &"interact"
@export_file("*.tscn") var target_scene_path: String = "res://Boss/boss_arena.tscn"
@export var require_player_group: StringName = &"player"

var _inside: bool = false
var _changing_scene: bool = false

@onready var area: Area3D = $Area3D
@onready var hint: Label3D = $Label3D

func _ready() -> void:
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	_update_hint()

func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if not _inside:
		return
	if _changing_scene:
		return
	if event.is_action_pressed(action_name):
		_go_to_boss()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group(require_player_group):
		_inside = true
		_update_hint()

func _on_body_exited(body: Node) -> void:
	if body.is_in_group(require_player_group):
		_inside = false
		_update_hint()

func _update_hint() -> void:
	hint.visible = enabled and _inside

func _go_to_boss() -> void:
	if target_scene_path.is_empty():
		push_error("TutorialBossButton: target_scene_path is empty.")
		return

	_changing_scene = true
	get_tree().change_scene_to_file(target_scene_path)
