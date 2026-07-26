# res://UI/shot_cycle_ui.gd
extends Control

const SLOT_COUNT: int = 8
const EMPTY_SLOT: int = -1
const SLOT_TYPES: Array[int] = [0, EMPTY_SLOT, 1, EMPTY_SLOT, 2, EMPTY_SLOT, 3, EMPTY_SLOT]
const SLOT_SPACING: float = 82.0
const ICON_SIZE: Vector2 = Vector2(58.0, 58.0)
const TICK_SNAP_DURATION: float = 0.18
const TICK_FLASH_DURATION: float = 0.24

const ICONS: Array[Texture2D] = [
	preload("res://Art/ShotCycle/Icon_SingleShot.png"),
	preload("res://Art/ShotCycle/Icon_ExpandShot.png"),
	preload("res://Art/ShotCycle/Icon_LaserShot.png"),
	preload("res://Art/ShotCycle/Icon_BombShot.png"),
]

var _slot_nodes: Array[Control] = []
var _active_type: int = 0
var _display_cycle_position: float = 0.0
var _last_visual_slot: int = 0
var _tick_tween: Tween = null
var _tick_flash_tween: Tween = null
var _tick_flash: float = 0.0

@onready var track: Control = $Track
@onready var active_label: Label = $ActiveLabel

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_active_type = ShotCycle.get_active_shot_type()
	_display_cycle_position = floor(ShotCycle.get_cycle_position() + 0.00001)
	_last_visual_slot = posmod(int(_display_cycle_position), SLOT_COUNT)
	_build_slots()
	Signals.shot_type_changed.connect(_on_shot_type_changed)
	_update_active_label()
	queue_redraw()

func _process(_delta: float) -> void:
	_update_tick_state()
	_update_slot_positions()
	if _tick_flash > 0.001:
		queue_redraw()

func _update_tick_state() -> void:
	var current_visual_slot: int = posmod(
		int(floor(ShotCycle.get_cycle_position() + 0.00001)),
		SLOT_COUNT
	)
	if current_visual_slot == _last_visual_slot:
		return

	var forward_steps: int = posmod(current_visual_slot - _last_visual_slot, SLOT_COUNT)
	_last_visual_slot = current_visual_slot

	if is_instance_valid(_tick_tween):
		_tick_tween.kill()

	var target_position: float = _display_cycle_position + float(forward_steps)
	_tick_tween = create_tween()
	_tick_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tick_tween.set_trans(Tween.TRANS_CUBIC)
	_tick_tween.set_ease(Tween.EASE_IN_OUT)
	_tick_tween.tween_property(
		self,
		"_display_cycle_position",
		target_position,
		TICK_SNAP_DURATION
	)

	_play_tick_flash()

func _play_tick_flash() -> void:
	_tick_flash = 1.0
	queue_redraw()
	if is_instance_valid(_tick_flash_tween):
		_tick_flash_tween.kill()
	_tick_flash_tween = create_tween()
	_tick_flash_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tick_flash_tween.set_trans(Tween.TRANS_QUAD)
	_tick_flash_tween.set_ease(Tween.EASE_OUT)
	_tick_flash_tween.tween_property(self, "_tick_flash", 0.0, TICK_FLASH_DURATION)
	_tick_flash_tween.tween_callback(Callable(self, "queue_redraw"))

func _draw() -> void:
	var center_x: float = size.x * 0.5
	var pointer_top: float = 0.0
	var pointer_tip: float = 17.0
	var line_bottom: float = 70.0

	draw_colored_polygon(PackedVector2Array([
		Vector2(center_x - 7.0, pointer_top),
		Vector2(center_x + 7.0, pointer_top),
		Vector2(center_x, pointer_tip),
	]), Color(1.0, 1.0, 1.0, 0.95))
	var pointer_alpha: float = 0.65 + _tick_flash * 0.30
	draw_line(Vector2(center_x, pointer_tip), Vector2(center_x, line_bottom), Color(1.0, 1.0, 1.0, pointer_alpha), 2.0 + _tick_flash * 1.5)
	draw_circle(Vector2(center_x, 42.0), 2.5 + _tick_flash * 4.0, Color(1.0, 1.0, 1.0, 0.15 + _tick_flash * 0.55))
	draw_line(Vector2(28.0, 75.0), Vector2(size.x - 28.0, 75.0), Color(1.0, 1.0, 1.0, 0.14), 1.0)

func _build_slots() -> void:
	for child in track.get_children():
		child.queue_free()
	_slot_nodes.clear()

	for slot_index in range(SLOT_COUNT):
		var holder := Control.new()
		holder.custom_minimum_size = ICON_SIZE
		holder.size = ICON_SIZE
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		track.add_child(holder)
		_slot_nodes.append(holder)

		var shot_type: int = SLOT_TYPES[slot_index]
		if shot_type == EMPTY_SLOT:
			var dot := ColorRect.new()
			dot.color = Color(1.0, 1.0, 1.0, 0.12)
			dot.size = Vector2(5.0, 5.0)
			dot.position = ICON_SIZE * 0.5 - dot.size * 0.5
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			holder.add_child(dot)
			continue

		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.texture = ICONS[shot_type]
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size = ICON_SIZE
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(icon)

func _update_slot_positions() -> void:
	if _slot_nodes.size() != SLOT_COUNT:
		return

	var cycle_position: float = _display_cycle_position
	var center_x: float = size.x * 0.5

	for slot_index in range(SLOT_COUNT):
		var relative_slots: float = fposmod(float(slot_index) - cycle_position + float(SLOT_COUNT) * 0.5, float(SLOT_COUNT)) - float(SLOT_COUNT) * 0.5
		var holder: Control = _slot_nodes[slot_index]
		holder.position = Vector2(
			center_x + relative_slots * SLOT_SPACING - ICON_SIZE.x * 0.5,
			16.0
		)

		var shot_type: int = SLOT_TYPES[slot_index]
		if shot_type == EMPTY_SLOT:
			holder.modulate = Color(1.0, 1.0, 1.0, 0.55)
			holder.scale = Vector2.ONE
			continue

		var is_active: bool = shot_type == _active_type
		holder.modulate = Color(1.0, 1.0, 1.0, 1.0 if is_active else 0.30)
		holder.scale = Vector2.ONE * (1.08 if is_active else 0.88)
		holder.pivot_offset = ICON_SIZE * 0.5

func _on_shot_type_changed(shot_type: int) -> void:
	_active_type = shot_type
	_update_active_label()

func _update_active_label() -> void:
	active_label.text = "NULL // %s" % ShotCycle.get_shot_name(_active_type)
