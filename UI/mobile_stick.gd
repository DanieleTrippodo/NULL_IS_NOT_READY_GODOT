extends Control

@export var radius: float = 90.0
@export_range(0.0, 1.0, 0.01) var deadzone: float = 0.12

@onready var base: TextureRect = $Base
@onready var knob: TextureRect = $Knob

var touch_id: int = -1
var value: Vector2 = Vector2.ZERO
var _center: Vector2 = Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_update_center()
	_reset_knob()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_center()
		if touch_id == -1:
			_reset_knob()
	elif what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_release_touch()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed:
			if touch_id == -1:
				touch_id = e.index
				_update_from_local(e.position)
				accept_event()
		elif e.index == touch_id:
			_release_touch()
			accept_event()
		return

	if event is InputEventScreenDrag:
		var e := event as InputEventScreenDrag
		if e.index == touch_id:
			_update_from_local(e.position)
			accept_event()
		return

	if OS.has_feature("android"):
		return

	if event is InputEventMouseButton:
		var e := event as InputEventMouseButton
		if e.button_index != MOUSE_BUTTON_LEFT:
			return
		if e.pressed:
			touch_id = -99
			_update_from_local(e.position)
		else:
			_release_touch()
		accept_event()
	elif event is InputEventMouseMotion and touch_id == -99:
		var e := event as InputEventMouseMotion
		_update_from_local(e.position)
		accept_event()

func _update_center() -> void:
	_center = size * 0.5

func _update_from_local(local_pos: Vector2) -> void:
	var diff := local_pos - _center
	if diff.length() > radius:
		diff = diff.normalized() * radius

	value = diff / radius
	if value.length() < deadzone:
		value = Vector2.ZERO

	knob.position = (_center + diff) - (knob.size * 0.5)
	_apply_actions()

func _reset_knob() -> void:
	if knob != null:
		knob.position = _center - (knob.size * 0.5)
	value = Vector2.ZERO
	_apply_actions()

func _release_touch() -> void:
	touch_id = -1
	_reset_knob()

func _apply_actions() -> void:
	_set_action_strength("move_left", maxf(0.0, -value.x))
	_set_action_strength("move_right", maxf(0.0, value.x))
	_set_action_strength("move_forward", maxf(0.0, -value.y))
	_set_action_strength("move_back", maxf(0.0, value.y))

func _set_action_strength(action: StringName, strength: float) -> void:
	if strength > 0.001:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)
