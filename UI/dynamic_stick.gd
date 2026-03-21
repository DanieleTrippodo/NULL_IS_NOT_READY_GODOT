extends Control

@export var base_radius: float = 116.0
@export var knob_radius: float = 48.0
@export var max_distance: float = 94.0
@export_range(0.0, 1.0, 0.01) var idle_alpha: float = 0.0
@export_range(0.0, 1.0, 0.01) var active_alpha: float = 1.0
@export_range(1.0, 30.0, 0.1) var fade_speed: float = 12.0
@export_range(0.0, 0.5, 0.01) var deadzone: float = 0.08

var active: bool = false
var base_position: Vector2 = Vector2.ZERO
var knob_position: Vector2 = Vector2.ZERO
var output_vector: Vector2 = Vector2.ZERO
var _draw_alpha: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_draw_alpha = idle_alpha
	queue_redraw()

func _process(delta: float) -> void:
	var target_alpha: float = active_alpha if active else idle_alpha
	_draw_alpha = move_toward(_draw_alpha, target_alpha, fade_speed * delta)
	queue_redraw()

func begin_touch(screen_pos: Vector2) -> void:
	active = true
	base_position = screen_pos
	knob_position = screen_pos
	output_vector = Vector2.ZERO
	queue_redraw()

func update_touch(screen_pos: Vector2) -> void:
	if not active:
		return

	var delta_pos: Vector2 = screen_pos - base_position
	if delta_pos.length() > max_distance:
		delta_pos = delta_pos.normalized() * max_distance

	knob_position = base_position + delta_pos

	var normalized: Vector2 = delta_pos / maxf(max_distance, 0.001)
	if normalized.length() < deadzone:
		normalized = Vector2.ZERO

	output_vector = Vector2(normalized.x, -normalized.y)
	queue_redraw()

func end_touch() -> void:
	active = false
	output_vector = Vector2.ZERO
	queue_redraw()

func get_output_vector() -> Vector2:
	return output_vector

func _draw() -> void:
	if _draw_alpha <= 0.001:
		return

	var outer_line := Color(1.0, 1.0, 1.0, 0.95 * _draw_alpha)
	var outer_fill := Color(1.0, 1.0, 1.0, 0.09 * _draw_alpha)
	var inner_line := Color(1.0, 1.0, 1.0, 0.95 * _draw_alpha)
	var inner_fill := Color(1.0, 1.0, 1.0, 0.24 * _draw_alpha)

	draw_circle(base_position, base_radius, outer_fill)
	draw_arc(base_position, base_radius, 0.0, TAU, 64, outer_line, 4.0, true)

	var knob_draw_radius: float = knob_radius * 1.22
	draw_circle(knob_position, knob_draw_radius, inner_fill)
	draw_arc(knob_position, knob_radius, 0.0, TAU, 48, inner_line, 4.0, true)
