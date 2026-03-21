extends TextureButton

@export var action_name: StringName
@export_range(0.5, 1.0, 0.01) var pressed_scale: float = 0.92

var _base_scale: Vector2 = Vector2.ONE

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	keep_pressed_outside = true
	ignore_texture_size = true
	stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_base_scale = scale

	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)

func _exit_tree() -> void:
	if button_pressed:
		_emit_action(false)

func _on_button_down() -> void:
	scale = _base_scale * pressed_scale
	_emit_action(true)

func _on_button_up() -> void:
	scale = _base_scale
	_emit_action(false)

func _emit_action(pressed: bool) -> void:
	if action_name == StringName():
		return

	var event := InputEventAction.new()
	event.action = action_name
	event.pressed = pressed
	event.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(event)
