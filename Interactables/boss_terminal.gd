extends Node3D

signal activated

@export var enabled: bool = true
@export var action_name: String = "interact"

var _inside: bool = false

@onready var area: Area3D = $Area3D
@onready var prompt: Sprite3D = $Prompt
@onready var message_label: Label3D = $MessageLabel

func _ready() -> void:
	if not area.body_entered.is_connected(_on_enter):
		area.body_entered.connect(_on_enter)
	if not area.body_exited.is_connected(_on_exit):
		area.body_exited.connect(_on_exit)
	_update_visuals()

func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if not _inside:
		return
	if event.is_action_pressed(action_name):
		emit_signal("activated")

func _on_enter(body: Node) -> void:
	if body.is_in_group("player"):
		_inside = true
		_update_visuals()

func _on_exit(body: Node) -> void:
	if body.is_in_group("player"):
		_inside = false
		_update_visuals()

func _update_visuals() -> void:
	if prompt != null:
		prompt.visible = enabled and _inside

	if message_label != null:
		message_label.visible = enabled
