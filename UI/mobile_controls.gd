extends Control

@export var preview_on_desktop: bool = false
@export_range(0.25, 0.55, 0.01) var move_zone_ratio: float = 0.42
@export var touch_look_multiplier: float = 1.0
@export var minimum_look_drag_px: float = 1.0

@export var stick_base_radius: float = 112.0
@export var stick_knob_radius: float = 46.0
@export var stick_max_distance: float = 92.0

@export var shoot_button_size: float = 128.0
@export var main_button_size: float = 88.0
@export var utility_button_size: float = 72.0
@export var top_button_size: float = 52.0

@export var screen_margin: float = 24.0
@export var cluster_padding_right: float = 18.0
@export var cluster_padding_bottom: float = 18.0
@export_range(0.5, 1.0, 0.01) var pressed_scale: float = 0.92

@onready var dynamic_stick: Control = $DynamicStick
@onready var shoot_button: TextureRect = $ShootButton
@onready var dash_button: TextureRect = $DashButton
@onready var jump_button: TextureRect = $JumpButton
@onready var interact_button: TextureRect = $InteractButton
@onready var recall_button: TextureRect = $RecallButton
@onready var push_button: TextureRect = $PushButton
@onready var pause_button: TextureRect = $PauseButton
@onready var ram_button: TextureRect = $RamButton

var _move_touch_id: int = -1
var _look_touch_id: int = -1
var _move_vector: Vector2 = Vector2.ZERO
var _cached_player: Node = null
var _mouse_move_active: bool = false
var _mouse_look_active: bool = false

var _touch_button_map: Dictionary = {}
var _button_to_touch_map: Dictionary = {}
var _button_defs: Array[Dictionary] = []
var _layout_queued: bool = false


func _ready() -> void:
	add_to_group("mobile_controls")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0

	visible = is_mobile_active()

	_setup_button_defs()
	_reset_touch_state()

	var viewport: Viewport = get_viewport()
	if viewport != null and not viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.connect(_on_viewport_size_changed)

	_queue_layout_refresh()


func _setup_button_defs() -> void:
	_button_defs = [
		{"node": shoot_button, "action": StringName("shoot")},
		{"node": dash_button, "action": StringName("dash")},
		{"node": jump_button, "action": StringName("jump")},
		{"node": interact_button, "action": StringName("interact")},
		{"node": recall_button, "action": StringName("swap")},
		{"node": push_button, "action": StringName("push")},
		{"node": pause_button, "action": StringName("esc")},
		{"node": ram_button, "action": StringName("ram_toggle")}
	]

	for def in _button_defs:
		var button: TextureRect = def["node"] as TextureRect
		if not is_instance_valid(button):
			continue

		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.set_anchors_preset(Control.PRESET_TOP_LEFT)
		button.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED


func _on_viewport_size_changed() -> void:
	_queue_layout_refresh()


func _queue_layout_refresh() -> void:
	if _layout_queued:
		return
	_layout_queued = true
	call_deferred("_refresh_layout_deferred")


func _refresh_layout_deferred() -> void:
	_layout_queued = false

	if not is_inside_tree():
		return

	await get_tree().process_frame

	if not is_inside_tree():
		return

	_apply_layout()
	_apply_stick_values()
	_update_all_button_visuals()


func is_mobile_active() -> bool:
	return OS.has_feature("android") or preview_on_desktop


func get_move_vector() -> Vector2:
	if not is_mobile_active():
		return Vector2.ZERO
	return _move_vector


func _unhandled_input(event: InputEvent) -> void:
	if not is_mobile_active() or not visible:
		return

	if event is InputEventScreenTouch:
		_handle_screen_touch(event as InputEventScreenTouch)
		return

	if event is InputEventScreenDrag:
		_handle_screen_drag(event as InputEventScreenDrag)
		return

	if preview_on_desktop:
		_handle_mouse_preview(event)


func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		var button: TextureRect = _get_button_at_position(event.position)
		if button != null:
			_press_button_touch(event.index, button)
			return

		if _can_start_move_touch(event.position):
			_move_touch_id = event.index
			dynamic_stick.call("begin_touch", event.position)
			_move_vector = Vector2.ZERO
			return

		if _can_start_look_touch(event.position):
			_look_touch_id = event.index
			return
	else:
		if _touch_button_map.has(event.index):
			_release_button_touch(event.index)
			return

		if event.index == _move_touch_id:
			_move_touch_id = -1
			_move_vector = Vector2.ZERO
			dynamic_stick.call("end_touch")
			return

		if event.index == _look_touch_id:
			_look_touch_id = -1
			return


func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	if _touch_button_map.has(event.index):
		var current_button: TextureRect = _touch_button_map[event.index] as TextureRect
		var hovered_button: TextureRect = _get_button_at_position(event.position)

		if hovered_button != current_button:
			_release_button_touch(event.index)
			if hovered_button != null:
				_press_button_touch(event.index, hovered_button)
		return

	if event.index == _move_touch_id:
		dynamic_stick.call("update_touch", event.position)
		var stick_value: Variant = dynamic_stick.call("get_output_vector")
		if stick_value is Vector2:
			_move_vector = stick_value as Vector2
		return

	if event.index == _look_touch_id:
		if event.screen_relative.length() < minimum_look_drag_px:
			return
		_apply_look(event.screen_relative * touch_look_multiplier)


func _handle_mouse_preview(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton

		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				var button: TextureRect = _get_button_at_position(mb.position)
				if button != null:
					_press_button_touch(-99, button)
					return

				if _can_start_move_touch(mb.position) and not _mouse_move_active:
					_mouse_move_active = true
					dynamic_stick.call("begin_touch", mb.position)
					_move_vector = Vector2.ZERO
			else:
				if _touch_button_map.has(-99):
					_release_button_touch(-99)
				elif _mouse_move_active:
					_mouse_move_active = false
					_move_vector = Vector2.ZERO
					dynamic_stick.call("end_touch")

		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed and _can_start_look_touch(mb.position):
				_mouse_look_active = true
			elif not mb.pressed:
				_mouse_look_active = false

	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion

		if _mouse_move_active:
			dynamic_stick.call("update_touch", mm.position)
			var mouse_stick_value: Variant = dynamic_stick.call("get_output_vector")
			if mouse_stick_value is Vector2:
				_move_vector = mouse_stick_value as Vector2

		if _mouse_look_active:
			_apply_look(mm.relative)


func _apply_look(delta: Vector2) -> void:
	var player: Node = _get_player()
	if player == null:
		return

	if player.has_method("apply_mobile_look_delta"):
		player.call("apply_mobile_look_delta", delta)


func _get_player() -> Node:
	if is_instance_valid(_cached_player):
		return _cached_player

	var players: Array = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null

	_cached_player = players[0] as Node
	return _cached_player


func _apply_layout() -> void:
	var vp: Vector2 = get_viewport_rect().size

	position = Vector2.ZERO
	size = vp
	custom_minimum_size = vp

	_set_control_rect(dynamic_stick, Vector2.ZERO, vp)

	var shoot_size: Vector2 = Vector2.ONE * shoot_button_size
	var main_size: Vector2 = Vector2.ONE * main_button_size
	var utility_size: Vector2 = Vector2.ONE * utility_button_size
	var top_size: Vector2 = Vector2.ONE * top_button_size

	var pause_pos: Vector2 = Vector2(
		vp.x - screen_margin - top_size.x,
		screen_margin
	)

	var ram_pos: Vector2 = Vector2(
		pause_pos.x - top_size.x - 12.0,
		screen_margin
	)

	var right_edge: float = vp.x - cluster_padding_right
	var bottom_edge: float = vp.y - cluster_padding_bottom

	var shoot_pos: Vector2 = Vector2(
		right_edge - shoot_size.x,
		bottom_edge - shoot_size.y
	)

	var dash_pos: Vector2 = Vector2(
		shoot_pos.x - 6.0,
		shoot_pos.y - main_size.y - 34.0
	)

	var jump_pos: Vector2 = Vector2(
		dash_pos.x - main_size.x - 34.0,
		dash_pos.y + 4.0
	)

	var interact_pos: Vector2 = Vector2(
		shoot_pos.x - 10.0,
		shoot_pos.y - utility_size.y - 38.0
	)

	var recall_pos: Vector2 = Vector2(
		jump_pos.x + 8.0,
		jump_pos.y - utility_size.y - 34.0
	)

	var push_pos: Vector2 = Vector2(
		recall_pos.x - utility_size.x - 28.0,
		recall_pos.y + 8.0
	)

	_set_control_rect(shoot_button, shoot_pos, shoot_size)
	_set_control_rect(dash_button, dash_pos, main_size)
	_set_control_rect(jump_button, jump_pos, main_size)
	_set_control_rect(interact_button, interact_pos, utility_size)
	_set_control_rect(recall_button, recall_pos, utility_size)
	_set_control_rect(push_button, push_pos, utility_size)
	_set_control_rect(pause_button, pause_pos, top_size)
	_set_control_rect(ram_button, ram_pos, top_size)


func _set_control_rect(control: Control, pos: Vector2, control_size: Vector2) -> void:
	if not is_instance_valid(control):
		return

	control.anchor_left = 0.0
	control.anchor_top = 0.0
	control.anchor_right = 0.0
	control.anchor_bottom = 0.0

	control.offset_left = pos.x
	control.offset_top = pos.y
	control.offset_right = pos.x + control_size.x
	control.offset_bottom = pos.y + control_size.y

	control.position = pos
	control.size = control_size
	control.custom_minimum_size = control_size


func _apply_stick_values() -> void:
	if not is_instance_valid(dynamic_stick):
		return

	dynamic_stick.set("base_radius", stick_base_radius)
	dynamic_stick.set("knob_radius", stick_knob_radius)
	dynamic_stick.set("max_distance", stick_max_distance)
	dynamic_stick.call("queue_redraw")


func _can_start_move_touch(pos: Vector2) -> bool:
	if _move_touch_id != -1:
		return false
	if _is_over_any_button(pos):
		return false
	if pos.x > size.x * move_zone_ratio:
		return false
	return true


func _can_start_look_touch(pos: Vector2) -> bool:
	if _look_touch_id != -1:
		return false
	if _is_over_any_button(pos):
		return false
	if pos.x <= size.x * move_zone_ratio:
		return false
	return true


func _is_over_any_button(pos: Vector2) -> bool:
	return _get_button_at_position(pos) != null


func _get_button_at_position(pos: Vector2) -> TextureRect:
	for def in _button_defs:
		var button: TextureRect = def["node"] as TextureRect
		if not is_instance_valid(button):
			continue

		var rect: Rect2 = Rect2(button.global_position, button.size)
		if rect.has_point(pos):
			return button

	return null


func _press_button_touch(touch_id: int, button: TextureRect) -> void:
	if not is_instance_valid(button):
		return
	if _button_to_touch_map.has(button):
		return

	_touch_button_map[touch_id] = button
	_button_to_touch_map[button] = touch_id
	_emit_button_action(button, true)
	_update_button_visual(button, true)


func _release_button_touch(touch_id: int) -> void:
	if not _touch_button_map.has(touch_id):
		return

	var button: TextureRect = _touch_button_map[touch_id] as TextureRect
	_touch_button_map.erase(touch_id)
	_button_to_touch_map.erase(button)
	_emit_button_action(button, false)
	_update_button_visual(button, false)


func _emit_button_action(button: TextureRect, pressed: bool) -> void:
	for def in _button_defs:
		if def["node"] == button:
			var event: InputEventAction = InputEventAction.new()
			event.action = def["action"] as StringName
			event.pressed = pressed
			event.strength = 1.0 if pressed else 0.0
			Input.parse_input_event(event)
			return


func _update_all_button_visuals() -> void:
	for def in _button_defs:
		var button: TextureRect = def["node"] as TextureRect
		_update_button_visual(button, _button_to_touch_map.has(button))


func _update_button_visual(button: TextureRect, pressed: bool) -> void:
	if not is_instance_valid(button):
		return

	button.scale = Vector2.ONE * (pressed_scale if pressed else 1.0)
	button.modulate = Color(1, 1, 1, 1.0 if pressed else 0.92)

	var pressed_tex: Texture2D = button.get_meta("pressed_texture", null) as Texture2D
	var normal_tex: Texture2D = button.get_meta("normal_texture", null) as Texture2D

	if pressed and pressed_tex != null:
		button.texture = pressed_tex
	elif not pressed and normal_tex != null:
		button.texture = normal_tex


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not visible:
		_reset_touch_state()


func _reset_touch_state() -> void:
	var touch_ids: Array = _touch_button_map.keys().duplicate()

	for touch_id in touch_ids:
		_release_button_touch(int(touch_id))

	_touch_button_map.clear()
	_button_to_touch_map.clear()

	_move_touch_id = -1
	_look_touch_id = -1
	_move_vector = Vector2.ZERO
	_mouse_move_active = false
	_mouse_look_active = false

	if is_instance_valid(dynamic_stick):
		dynamic_stick.call("end_touch")

	_update_all_button_visuals()
