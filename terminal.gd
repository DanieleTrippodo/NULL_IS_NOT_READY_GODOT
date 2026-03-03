extends Node3D
signal pressed

@export var enabled: bool = true
@export var action_name := "interact"

var _inside := false

@onready var area: Area3D = $Area3D
@onready var prompt: Sprite3D = $Prompt

func _ready() -> void:
	area.body_entered.connect(_on_enter)
	area.body_exited.connect(_on_exit)
	_update_prompt()

func _unhandled_input(event: InputEvent) -> void:
	if not enabled: return
	if not _inside: return
	if event.is_action_pressed(action_name):
		emit_signal("pressed")

func _on_enter(body: Node) -> void:
	if body.is_in_group("player"):
		_inside = true
		_update_prompt()

func _on_exit(body: Node) -> void:
	if body.is_in_group("player"):
		_inside = false
		_update_prompt()

func _update_prompt() -> void:
	prompt.visible = enabled and _inside
