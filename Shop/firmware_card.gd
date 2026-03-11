extends Control
class_name FirmwareCard

signal activated(card: FirmwareCard)
signal hovered(card: FirmwareCard)
signal unhovered(card: FirmwareCard)

@onready var panel: Control = $Panel
@onready var title_label: Label = $Panel/Content/Title
@onready var rarity_label: Label = $Panel/Content/Rarity
@onready var price_label: Label = $Panel/Content/Price
@onready var icon_rect: TextureRect = $Panel/Content/Icon
@onready var shape_preview: Control = $ShapePreview
@onready var shape_size_label: Label = $ShapePreview/ShapeSizeLabel
@onready var base_rect: TextureRect = $Panel/Content/Base

var perk_id: String = ""
var rarity: int = 0
var price: int = 0

var _is_disabled: bool = false
var _is_hovered: bool = false
var _is_focused_visual: bool = false

const PREVIEW_CELL: int = 18
const PREVIEW_GAP: int = 3
const PREVIEW_BG: Color = Color(0.08, 0.08, 0.1, 0.95)
const PREVIEW_GRID: Color = Color(0.25, 0.25, 0.32, 1.0)
const PREVIEW_FILL: Color = Color(0.92, 0.92, 1.0, 0.90)
const PREVIEW_EMPTY: Color = Color(0.12, 0.12, 0.16, 1.0)

func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP

	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)

	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)

	if shape_preview != null:
		shape_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shape_preview.custom_minimum_size = Vector2(96, 96)

		if not shape_preview.draw.is_connected(_on_shape_preview_draw):
			shape_preview.draw.connect(_on_shape_preview_draw)

		shape_preview.queue_redraw()

	_apply_visual_state()

func setup(p_id: String, p_rarity: int, p_price: int) -> void:
	perk_id = p_id
	rarity = p_rarity
	price = p_price

	if base_rect != null and ResourceLoader.exists("res://Art/Cards/Layouts/card_base.png"):
		base_rect.texture = load("res://Art/Cards/Layouts/card_base.png")
	
	if title_label != null:
		title_label.text = UpdatesDB.get_title(perk_id)

	if rarity_label != null:
		rarity_label.text = UpdatesDB.rarity_name(rarity)

	if price_label != null:
		price_label.text = "COST: %d" % price

	if icon_rect != null:
		var icon_path: String = UpdatesDB.get_icon_path(perk_id)
		if icon_path != "" and ResourceLoader.exists(icon_path):
			icon_rect.texture = load(icon_path)
		else:
			icon_rect.texture = null

	if shape_size_label != null:
		var sz: Vector2i = Run.get_ram_size_for_update(perk_id, 0)
		shape_size_label.text = "RAM: %dx%d" % [sz.x, sz.y]

	if shape_preview != null:
		shape_preview.queue_redraw()

func set_card_disabled(value: bool) -> void:
	_is_disabled = value
	mouse_filter = Control.MOUSE_FILTER_IGNORE if value else Control.MOUSE_FILTER_STOP
	_apply_visual_state()

func is_card_disabled() -> bool:
	return _is_disabled

func _apply_visual_state() -> void:
	if _is_disabled:
		modulate = Color(1.0, 1.0, 1.0, 0.45)
	else:
		modulate = Color(1.0, 1.0, 1.0, 1.0)

	if panel != null:
		if _is_hovered or _is_focused_visual:
			panel.modulate = Color(1.08, 1.08, 1.08, 1.0)
		else:
			panel.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _gui_input(event: InputEvent) -> void:
	if _is_disabled:
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_pressed()
		accept_event()

func _on_pressed() -> void:
	if _is_disabled:
		return
	activated.emit(self)

func _on_mouse_entered() -> void:
	_is_hovered = true
	_apply_visual_state()
	hovered.emit(self)

func _on_mouse_exited() -> void:
	_is_hovered = false
	_apply_visual_state()
	unhovered.emit(self)

func _focus_entered() -> void:
	_is_focused_visual = true
	_apply_visual_state()

func _focus_exited() -> void:
	_is_focused_visual = false
	_apply_visual_state()

func _on_shape_preview_draw() -> void:
	if shape_preview == null or perk_id == "":
		return

	var cells: Array[Vector2i] = Run.get_ram_cells_for_update(perk_id, 0)
	var size_cells: Vector2i = Run.get_ram_size_for_update(perk_id, 0)

	var total_w: float = size_cells.x * PREVIEW_CELL + max(size_cells.x - 1, 0) * PREVIEW_GAP
	var total_h: float = size_cells.y * PREVIEW_CELL + max(size_cells.y - 1, 0) * PREVIEW_GAP

	var origin: Vector2 = Vector2(
		(shape_preview.size.x - total_w) * 0.5,
		(shape_preview.size.y - total_h) * 0.5
	)

	shape_preview.draw_rect(Rect2(Vector2.ZERO, shape_preview.size), PREVIEW_BG, true)

	for y in range(size_cells.y):
		for x in range(size_cells.x):
			var empty_rect := Rect2(
				origin.x + x * (PREVIEW_CELL + PREVIEW_GAP),
				origin.y + y * (PREVIEW_CELL + PREVIEW_GAP),
				PREVIEW_CELL,
				PREVIEW_CELL
			)
			shape_preview.draw_rect(empty_rect, PREVIEW_EMPTY, true)
			shape_preview.draw_rect(empty_rect, PREVIEW_GRID, false, 1.0)

	for c in cells:
		var filled_rect := Rect2(
			origin.x + c.x * (PREVIEW_CELL + PREVIEW_GAP),
			origin.y + c.y * (PREVIEW_CELL + PREVIEW_GAP),
			PREVIEW_CELL,
			PREVIEW_CELL
		)
		shape_preview.draw_rect(filled_rect, PREVIEW_FILL, true)
		shape_preview.draw_rect(filled_rect, PREVIEW_GRID, false, 1.0)
