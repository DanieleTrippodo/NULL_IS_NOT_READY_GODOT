extends Control

@onready var dim: ColorRect = $Dim
@onready var panel: Panel = $Panel
@onready var title_label: Label = $Panel/Title
@onready var ram_usage_label: Label = $Panel/RamUsage
@onready var help_label: Label = $Panel/Help

@onready var grid_control: Control = $Panel/HSplit/Left/GridFrame/GridMargin/Grid
@onready var inventory_list: VBoxContainer = $Panel/HSplit/Right/ScrollFrame/ScrollMargin/Scroll/InventoryList
@onready var desc_label: RichTextLabel = $Panel/HSplit/Right/DescFrame/DescMargin/Desc

const CELL_SIZE: int = 52
const CELL_GAP: int = 4

const GRID_BG: Color = Color(0.08, 0.08, 0.10, 0.92)
const GRID_LINE: Color = Color(0.28, 0.28, 0.32, 1.0)
const CELL_FILL: Color = Color(0.14, 0.14, 0.18, 1.0)

const PIECE_FILL: Color = Color(0.93, 0.93, 0.96, 0.94)
const PIECE_OUTLINE_DARK: Color = Color(0.05, 0.05, 0.06, 1.0)
const PIECE_OUTLINE_LIGHT: Color = Color(0.42, 0.42, 0.46, 0.82)
const PIECE_DETAIL: Color = Color(0.10, 0.10, 0.11, 0.90)
const PIECE_DETAIL_SOFT: Color = Color(0.20, 0.20, 0.22, 0.65)

const PREVIEW_OK: Color = Color(1.0, 1.0, 1.0, 0.34)
const PREVIEW_BAD: Color = Color(0.24, 0.24, 0.28, 0.58)
const PREVIEW_BLOCKED: Color = Color(0.10, 0.10, 0.11, 0.72)

var is_open: bool = false

var held_instance_id: int = -1
var held_rotation: int = 0
var hovered_cell: Vector2i = Vector2i(-1, -1)

var _inventory_buttons: Dictionary = {}


func _ready() -> void:
	visible = false
	set_process(true)
	set_process_unhandled_input(true)

	title_label.text = "R.A.M. CONFIGURATION"
	help_label.text = "TAB close  |  Left Click place/remove  |  Right Click cancel  |  R rotate"

	_update_grid_minimum_size()
	grid_control.gui_input.connect(_on_grid_gui_input)

	_refresh_all()


func _process(_delta: float) -> void:
	if not is_open:
		return

	var local_mouse: Vector2 = grid_control.get_local_mouse_position()
	hovered_cell = _pixel_to_grid(local_mouse)
	grid_control.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ram_toggle"):
		_toggle_open()
		get_viewport().set_input_as_handled()
		return

	if not is_open:
		return

	if event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			_rotate_held_update()
			get_viewport().set_input_as_handled()


func _toggle_open() -> void:
	if is_open:
		_close()
	else:
		_open()


func _open() -> void:
	is_open = true
	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_refresh_all()


func _close() -> void:
	is_open = false
	visible = false
	held_instance_id = -1
	held_rotation = 0
	hovered_cell = Vector2i(-1, -1)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _refresh_all() -> void:
	_update_grid_minimum_size()
	_refresh_inventory_list()
	_refresh_desc()
	_refresh_ram_usage()
	grid_control.queue_redraw()


func _update_grid_minimum_size() -> void:
	grid_control.custom_minimum_size = _get_grid_pixel_size()


# ------------------------------------------------------------
# RAM USAGE
# ------------------------------------------------------------
func _get_used_ram_cells() -> int:
	var used: int = 0
	for y in range(Run.ram_rows):
		for x in range(Run.ram_cols):
			if int(Run.ram_grid[y][x]) != -1:
				used += 1
	return used


func _refresh_ram_usage() -> void:
	var used: int = _get_used_ram_cells()
	var total: int = Run.get_ram_total_slots()
	ram_usage_label.text = "RAM USED: %d / %d   (%dx%d)" % [used, total, Run.ram_cols, Run.ram_rows]


# ------------------------------------------------------------
# INVENTORY UI
# ------------------------------------------------------------
func _refresh_inventory_list() -> void:
	for c in inventory_list.get_children():
		c.queue_free()
	_inventory_buttons.clear()

	var items: Array[Dictionary] = Run.get_unequipped_updates()

	if items.is_empty():
		var lbl := Label.new()
		lbl.text = "No stored Updates."
		lbl.modulate = Color(1, 1, 1, 0.7)
		inventory_list.add_child(lbl)
		return

	for item in items:
		var instance_id: int = int(item.get("instance_id", -1))
		var update_id: String = str(item.get("update_id", ""))
		var item_rotation: int = int(item.get("rotation", 0))

		var btn := Button.new()
		btn.focus_mode = Control.FOCUS_ALL
		btn.custom_minimum_size = Vector2(0, 46)
		btn.text = _build_inventory_button_text(update_id, item_rotation)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_on_inventory_item_pressed.bind(instance_id))
		btn.mouse_entered.connect(_on_inventory_item_hovered.bind(instance_id))
		btn.focus_entered.connect(_on_inventory_item_focused.bind(instance_id))

		inventory_list.add_child(btn)
		_inventory_buttons[instance_id] = btn

	_refresh_inventory_button_highlight()


func _build_inventory_button_text(update_id: String, item_rotation: int) -> String:
	var title: String = UpdatesDB.get_title(update_id)
	var shape_size: Vector2i = Run.get_ram_size_for_update(update_id, item_rotation)
	var rarity_name: String = UpdatesDB.rarity_name(UpdatesDB.get_rarity(update_id))
	return "%s   [%s]   %dx%d" % [title, rarity_name, shape_size.x, shape_size.y]


func _refresh_inventory_button_highlight() -> void:
	for instance_id in _inventory_buttons.keys():
		var btn: Button = _inventory_buttons[instance_id]
		if held_instance_id == int(instance_id):
			btn.modulate = Color(1.08, 1.08, 1.08, 1.0)
		else:
			btn.modulate = Color(1.0, 1.0, 1.0, 0.92)


func _on_inventory_item_pressed(instance_id: int) -> void:
	var item: Dictionary = Run.get_owned_update_by_instance_id(instance_id)
	if item.is_empty():
		return

	held_instance_id = instance_id
	held_rotation = int(item.get("rotation", 0))

	_refresh_desc_for_instance(instance_id)
	_refresh_inventory_button_highlight()
	grid_control.queue_redraw()


func _on_inventory_item_hovered(instance_id: int) -> void:
	_refresh_desc_for_instance(instance_id)


func _on_inventory_item_focused(instance_id: int) -> void:
	_refresh_desc_for_instance(instance_id)


# ------------------------------------------------------------
# DESCRIPTION
# ------------------------------------------------------------
func _refresh_desc() -> void:
	if held_instance_id != -1:
		_refresh_desc_for_instance(held_instance_id)
		return

	desc_label.text = "[b]R.A.M.[/b]\nStore Updates here to activate them.\n\nEquip [b]RAM PATCH[/b] to expand the grid by +1 row and +1 column."


func _refresh_desc_for_instance(instance_id: int) -> void:
	var item: Dictionary = Run.get_owned_update_by_instance_id(instance_id)
	if item.is_empty():
		desc_label.text = ""
		return

	var update_id: String = str(item.get("update_id", ""))
	var rarity_name: String = UpdatesDB.rarity_name(UpdatesDB.get_rarity(update_id))
	var shape_size: Vector2i = Run.get_ram_size_for_update(update_id, int(item.get("rotation", 0)))
	var tradeoff: String = UpdatesDB.get_tradeoff_desc(update_id)
	var desc: String = UpdatesDB.get_desc(update_id)

	var bb := ""
	bb += "[b]%s[/b]\n" % UpdatesDB.get_title(update_id)
	bb += "%s\n" % rarity_name
	bb += "Shape: %dx%d\n\n" % [shape_size.x, shape_size.y]
	bb += "%s\n" % desc

	if update_id == "RAM_PATCH":
		bb += "\n[i]Current grid:[/i] %dx%d" % [Run.ram_cols, Run.ram_rows]
		bb += "\n[i]Next grid:[/i] %dx%d" % [Run.ram_cols + 1, Run.ram_rows + 1]

	if tradeoff != "":
		bb += "\n\n[i]Trade-off:[/i] %s" % tradeoff

	desc_label.text = bb


# ------------------------------------------------------------
# GRID DRAW
# ------------------------------------------------------------
func _get_grid_pixel_size() -> Vector2:
	var grid_width: int = Run.ram_cols * CELL_SIZE + max(Run.ram_cols - 1, 0) * CELL_GAP
	var grid_height: int = Run.ram_rows * CELL_SIZE + max(Run.ram_rows - 1, 0) * CELL_GAP
	return Vector2(grid_width, grid_height)


func _cell_rect(cell: Vector2i) -> Rect2:
	var cell_x: int = cell.x * (CELL_SIZE + CELL_GAP)
	var cell_y: int = cell.y * (CELL_SIZE + CELL_GAP)
	return Rect2(cell_x, cell_y, CELL_SIZE, CELL_SIZE)


func _pixel_to_grid(point: Vector2) -> Vector2i:
	for y in range(Run.ram_rows):
		for x in range(Run.ram_cols):
			var rect := _cell_rect(Vector2i(x, y))
			if rect.has_point(point):
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func _draw() -> void:
	pass


func _notification(what: int) -> void:
	if what == NOTIFICATION_READY:
		if not grid_control.draw.is_connected(_on_grid_draw):
			grid_control.draw.connect(_on_grid_draw)


func _on_grid_draw() -> void:
	var grid_size: Vector2 = _get_grid_pixel_size()
	grid_control.draw_rect(Rect2(Vector2.ZERO, grid_size), GRID_BG, true)

	for y in range(Run.ram_rows):
		for x in range(Run.ram_cols):
			var rect := _cell_rect(Vector2i(x, y))
			grid_control.draw_rect(rect, CELL_FILL, true)
			grid_control.draw_rect(rect, GRID_LINE, false, 1.0)

	var equipped_updates = Run.get_equipped_updates()
	for item in equipped_updates:
		var update_id: String = str(item.get("update_id", ""))
		var origin: Vector2i = item.get("grid_pos", Vector2i(-1, -1)) as Vector2i
		var item_rotation: int = int(item.get("rotation", 0))
		var cells: Array[Vector2i] = Run.get_ram_cells_for_update(update_id, item_rotation)

		for i in range(cells.size()):
			var c: Vector2i = cells[i]
			var grid_pos: Vector2i = origin + c
			if grid_pos.x < 0 or grid_pos.y < 0:
				continue
			if grid_pos.x >= Run.ram_cols or grid_pos.y >= Run.ram_rows:
				continue

			var rect := _cell_rect(grid_pos)
			var is_anchor: bool = (i == 0)

			_draw_chip_cell(rect, update_id, is_anchor, false)

	if held_instance_id != -1 and hovered_cell != Vector2i(-1, -1):
		var held_item: Dictionary = Run.get_owned_update_by_instance_id(held_instance_id)
		if not held_item.is_empty():
			var update_id: String = str(held_item.get("update_id", ""))
			var cells: Array[Vector2i] = Run.get_ram_cells_for_update(update_id, held_rotation)
			var can_place: bool = Run.can_place_update_instance(held_instance_id, hovered_cell, held_rotation)

			for i in range(cells.size()):
				var c: Vector2i = cells[i]
				var preview_pos: Vector2i = hovered_cell + c
				if preview_pos.x < 0 or preview_pos.x >= Run.ram_cols or preview_pos.y < 0 or preview_pos.y >= Run.ram_rows:
					continue

				var rect := _cell_rect(preview_pos)
				var cell_value: int = int(Run.ram_grid[preview_pos.y][preview_pos.x])
				var is_anchor: bool = (i == 0)

				if can_place:
					_draw_chip_preview_cell(rect, update_id, is_anchor, PREVIEW_OK)
				else:
					if cell_value != -1 and cell_value != held_instance_id:
						_draw_chip_preview_cell(rect, update_id, is_anchor, PREVIEW_BLOCKED)
					else:
						_draw_chip_preview_cell(rect, update_id, is_anchor, PREVIEW_BAD)


func _draw_chip_cell(rect: Rect2, update_id: String, is_anchor: bool, is_preview: bool) -> void:
	grid_control.draw_rect(rect, PIECE_FILL, true)

	var inner := Rect2(
		rect.position.x + 4.0,
		rect.position.y + 4.0,
		rect.size.x - 8.0,
		rect.size.y - 8.0
	)
	grid_control.draw_rect(inner, Color(0.88, 0.88, 0.90, 0.25), false, 1.0)

	_draw_chip_notches(rect, is_preview)
	_draw_chip_pins(rect, is_preview)

	if is_anchor:
		_draw_chip_symbol(update_id, rect, is_preview)

	grid_control.draw_rect(rect, PIECE_OUTLINE_DARK, false, 2.0)
	grid_control.draw_rect(rect, PIECE_OUTLINE_LIGHT, false, 1.0)
	grid_control.draw_rect(rect, GRID_LINE, false, 1.0)


func _draw_chip_preview_cell(rect: Rect2, update_id: String, is_anchor: bool, preview_color: Color) -> void:
	grid_control.draw_rect(rect, preview_color, true)
	_draw_chip_notches(rect, true)
	_draw_chip_pins(rect, true)

	if is_anchor:
		_draw_chip_symbol(update_id, rect, true)

	grid_control.draw_rect(rect, PIECE_OUTLINE_DARK, false, 2.0)
	grid_control.draw_rect(rect, GRID_LINE, false, 1.0)


func _draw_chip_notches(rect: Rect2, is_preview: bool) -> void:
	var col: Color = PIECE_DETAIL if not is_preview else Color(0.08, 0.08, 0.09, 0.50)
	var s: float = 5.0

	var top_left_rect := Rect2(rect.position.x + 3.0, rect.position.y + 3.0, s, s)
	var top_right_rect := Rect2(rect.position.x + rect.size.x - s - 3.0, rect.position.y + 3.0, s, s)
	var bottom_left_rect := Rect2(rect.position.x + 3.0, rect.position.y + rect.size.y - s - 3.0, s, s)
	var bottom_right_rect := Rect2(rect.position.x + rect.size.x - s - 3.0, rect.position.y + rect.size.y - s - 3.0, s, s)

	grid_control.draw_rect(top_left_rect, col, true)
	grid_control.draw_rect(top_right_rect, col, true)
	grid_control.draw_rect(bottom_left_rect, col, true)
	grid_control.draw_rect(bottom_right_rect, col, true)


func _draw_chip_pins(rect: Rect2, is_preview: bool) -> void:
	var col: Color = PIECE_DETAIL_SOFT if not is_preview else Color(0.10, 0.10, 0.11, 0.35)
	var pin_w: float = 6.0
	var pin_h: float = 2.0

	var cx: float = rect.position.x + rect.size.x * 0.5
	var cy: float = rect.position.y + rect.size.y * 0.5

	var top_pin := Rect2(cx - pin_w * 0.5, rect.position.y - 1.0, pin_w, pin_h)
	var bottom_pin := Rect2(cx - pin_w * 0.5, rect.position.y + rect.size.y - 1.0, pin_w, pin_h)
	var left_pin := Rect2(rect.position.x - 1.0, cy - pin_w * 0.5, pin_h, pin_w)
	var right_pin := Rect2(rect.position.x + rect.size.x - 1.0, cy - pin_w * 0.5, pin_h, pin_w)

	grid_control.draw_rect(top_pin, col, true)
	grid_control.draw_rect(bottom_pin, col, true)
	grid_control.draw_rect(left_pin, col, true)
	grid_control.draw_rect(right_pin, col, true)


func _draw_chip_symbol(update_id: String, rect: Rect2, is_preview: bool) -> void:
	var col: Color = PIECE_DETAIL if not is_preview else Color(0.08, 0.08, 0.09, 0.55)
	var cx: float = rect.position.x + rect.size.x * 0.5
	var cy: float = rect.position.y + rect.size.y * 0.5
	var x1: float = rect.position.x + 14.0
	var y1: float = rect.position.y + 14.0
	var x2: float = rect.position.x + rect.size.x - 14.0
	var y2: float = rect.position.y + rect.size.y - 14.0

	match update_id:
		"RAM_PATCH":
			grid_control.draw_line(Vector2(cx, y1), Vector2(cx, y2), col, 2.0)
			grid_control.draw_line(Vector2(x1, cy), Vector2(x2, cy), col, 2.0)

		"SPRINT":
			grid_control.draw_line(Vector2(x1, cy - 4.0), Vector2(x2 - 6.0, cy - 4.0), col, 2.0)
			grid_control.draw_line(Vector2(x1, cy + 4.0), Vector2(x2 - 6.0, cy + 4.0), col, 2.0)
			grid_control.draw_line(Vector2(x2 - 10.0, cy - 9.0), Vector2(x2, cy - 4.0), col, 2.0)
			grid_control.draw_line(Vector2(x2 - 10.0, cy + 1.0), Vector2(x2, cy + 4.0), col, 2.0)

		"NULL_SPEED":
			grid_control.draw_line(Vector2(x1, cy), Vector2(x2 - 5.0, cy), col, 2.0)
			grid_control.draw_line(Vector2(x2 - 9.0, cy - 6.0), Vector2(x2, cy), col, 2.0)
			grid_control.draw_line(Vector2(x2 - 9.0, cy + 6.0), Vector2(x2, cy), col, 2.0)

		"NULL_RANGE":
			grid_control.draw_line(Vector2(cx, y1), Vector2(cx, y2), col, 2.0)
			grid_control.draw_line(Vector2(cx - 5.0, y1 + 6.0), Vector2(cx, y1), col, 2.0)
			grid_control.draw_line(Vector2(cx + 5.0, y1 + 6.0), Vector2(cx, y1), col, 2.0)
			grid_control.draw_line(Vector2(cx - 5.0, y2 - 6.0), Vector2(cx, y2), col, 2.0)
			grid_control.draw_line(Vector2(cx + 5.0, y2 - 6.0), Vector2(cx, y2), col, 2.0)

		"MAGNET_PICKUP":
			grid_control.draw_arc(Vector2(cx, cy), 8.0, PI, TAU, 16, col, 2.0)
			grid_control.draw_line(Vector2(cx - 8.0, cy), Vector2(cx - 8.0, y2), col, 2.0)
			grid_control.draw_line(Vector2(cx + 8.0, cy), Vector2(cx + 8.0, y2), col, 2.0)

		"CHARGE_SHOT":
			grid_control.draw_line(Vector2(cx, y1), Vector2(cx - 4.0, cy), col, 2.0)
			grid_control.draw_line(Vector2(cx - 4.0, cy), Vector2(cx + 1.0, cy), col, 2.0)
			grid_control.draw_line(Vector2(cx + 1.0, cy), Vector2(cx - 3.0, y2), col, 2.0)
			grid_control.draw_line(Vector2(cx - 3.0, y2), Vector2(cx + 7.0, cy + 3.0), col, 2.0)
			grid_control.draw_line(Vector2(cx + 7.0, cy + 3.0), Vector2(cx + 1.0, cy + 3.0), col, 2.0)
			grid_control.draw_line(Vector2(cx + 1.0, cy + 3.0), Vector2(cx + 5.0, y1), col, 2.0)

		"PULL_TO_HAND":
			grid_control.draw_line(Vector2(x1, cy), Vector2(x2, cy), col, 2.0)
			grid_control.draw_line(Vector2(x1 + 8.0, cy - 6.0), Vector2(x1, cy), col, 2.0)
			grid_control.draw_line(Vector2(x1 + 8.0, cy + 6.0), Vector2(x1, cy), col, 2.0)

		"IMPACT_PULSE":
			grid_control.draw_circle(Vector2(cx, cy), 4.0, col)
			grid_control.draw_circle(Vector2(cx, cy), 9.0, Color(col.r, col.g, col.b, col.a * 0.6), false, 2.0)
			grid_control.draw_circle(Vector2(cx, cy), 14.0, Color(col.r, col.g, col.b, col.a * 0.35), false, 2.0)

		"THREAD_LOCK":
			grid_control.draw_line(Vector2(x1, cy), Vector2(x2, cy), col, 2.0)
			grid_control.draw_circle(Vector2(x1 + 4.0, cy), 2.0, col)
			grid_control.draw_circle(Vector2(x2 - 4.0, cy), 2.0, col)

		"HOMING_NUDGE":
			grid_control.draw_line(Vector2(x1, cy), Vector2(x2 - 6.0, cy), col, 2.0)
			grid_control.draw_line(Vector2(x2 - 12.0, cy - 6.0), Vector2(x2, cy), col, 2.0)
			grid_control.draw_line(Vector2(x2 - 12.0, cy + 6.0), Vector2(x2, cy), col, 2.0)

		"PIERCE_1":
			grid_control.draw_line(Vector2(x1, cy - 4.0), Vector2(x2, cy - 4.0), col, 2.0)
			grid_control.draw_line(Vector2(x1, cy + 4.0), Vector2(x2, cy + 4.0), col, 2.0)

		"SLOWMO_RECOVERY":
			var inner := Rect2(rect.position.x + 14.0, rect.position.y + 14.0, rect.size.x - 28.0, rect.size.y - 28.0)
			grid_control.draw_rect(inner, col, false, 2.0)

		"NULL_FREEZE":
			grid_control.draw_line(Vector2(x1 + 4.0, y1 + 2.0), Vector2(cx, cy), col, 2.0)
			grid_control.draw_line(Vector2(cx, cy), Vector2(x2 - 4.0, y1 + 2.0), col, 2.0)
			grid_control.draw_line(Vector2(cx, cy), Vector2(cx, y2), col, 2.0)

		"OVERCLOCK":
			grid_control.draw_line(Vector2(cx, y1), Vector2(cx - 4.0, cy), col, 2.0)
			grid_control.draw_line(Vector2(cx - 4.0, cy), Vector2(cx + 1.0, cy), col, 2.0)
			grid_control.draw_line(Vector2(cx + 1.0, cy), Vector2(cx - 3.0, y2), col, 2.0)
			grid_control.draw_line(Vector2(cx - 3.0, y2), Vector2(cx + 7.0, cy + 3.0), col, 2.0)

		"GROUND_ECHO":
			grid_control.draw_arc(Vector2(cx, cy), 6.0, 0.0, TAU, 20, col, 2.0)
			grid_control.draw_arc(Vector2(cx, cy), 12.0, 0.0, PI, 12, Color(col.r, col.g, col.b, col.a * 0.5), 2.0)

		"DASH_UNLOCK":
			grid_control.draw_line(Vector2(x1 + 2.0, cy), Vector2(x2 - 8.0, cy), col, 2.0)
			grid_control.draw_line(Vector2(cx - 6.0, y1 + 5.0), Vector2(x2 - 8.0, cy), col, 2.0)
			grid_control.draw_line(Vector2(cx - 6.0, y2 - 5.0), Vector2(x2 - 8.0, cy), col, 2.0)
			grid_control.draw_rect(Rect2(x2 - 12.0, cy - 8.0, 8.0, 16.0), col, false, 2.0)

		"SLIDE_DODGE":
			grid_control.draw_line(Vector2(x1 + 2.0, y2 - 2.0), Vector2(cx, y2 - 2.0), col, 2.0)
			grid_control.draw_line(Vector2(cx, y2 - 2.0), Vector2(x2 - 4.0, cy), col, 2.0)
			grid_control.draw_line(Vector2(cx - 2.0, cy + 3.0), Vector2(cx + 5.0, cy + 3.0), col, 2.0)
			grid_control.draw_line(Vector2(cx + 5.0, cy + 3.0), Vector2(x2 - 10.0, cy - 3.0), col, 2.0)

		"LONG_JUMP":
			grid_control.draw_line(Vector2(x1, y2), Vector2(cx, y1), col, 2.0)
			grid_control.draw_line(Vector2(cx, y1), Vector2(x2, y2), col, 2.0)

		"JUMP_POWER":
			grid_control.draw_line(Vector2(cx, y2), Vector2(cx, y1), col, 2.0)
			grid_control.draw_line(Vector2(cx - 6.0, y1 + 8.0), Vector2(cx, y1), col, 2.0)
			grid_control.draw_line(Vector2(cx + 6.0, y1 + 8.0), Vector2(cx, y1), col, 2.0)

		"PANIC_BOOST":
			grid_control.draw_line(Vector2(x1, y2), Vector2(cx - 2.0, cy + 2.0), col, 2.0)
			grid_control.draw_line(Vector2(cx - 2.0, cy + 2.0), Vector2(cx + 2.0, cy - 2.0), col, 2.0)
			grid_control.draw_line(Vector2(cx + 2.0, cy - 2.0), Vector2(x2, y1), col, 2.0)

		"NULL_BOUNCE":
			grid_control.draw_circle(Vector2(cx, cy), 8.0, col, false, 2.0)

		"BOUNCE_STACK":
			grid_control.draw_circle(Vector2(cx - 5.0, cy), 5.0, col, false, 2.0)
			grid_control.draw_circle(Vector2(cx + 5.0, cy), 5.0, col, false, 2.0)

		"SLOW_TURRETS":
			grid_control.draw_line(Vector2(x1, y1), Vector2(x2, y1), col, 2.0)
			grid_control.draw_line(Vector2(x1, cy), Vector2(x2, cy), col, 2.0)
			grid_control.draw_line(Vector2(x1, y2), Vector2(x2, y2), col, 2.0)

		"AUTO_RECALL":
			grid_control.draw_line(Vector2(x2, cy), Vector2(x1 + 8.0, cy), col, 2.0)
			grid_control.draw_line(Vector2(x1 + 8.0, cy), Vector2(x1 + 15.0, cy - 6.0), col, 2.0)
			grid_control.draw_line(Vector2(x1 + 8.0, cy), Vector2(x1 + 15.0, cy + 6.0), col, 2.0)
			grid_control.draw_arc(Vector2(cx, cy), 11.0, PI * 0.15, PI * 1.55, 18, col, 2.0)

		"RECOVERY_IFRAME":
			grid_control.draw_rect(Rect2(cx - 8.0, cy - 10.0, 16.0, 20.0), col, false, 2.0)
			grid_control.draw_line(Vector2(cx, y1 + 2.0), Vector2(cx, y2 - 2.0), col, 2.0)

		"STASIS_FIELD":
			grid_control.draw_circle(Vector2(cx, cy), 5.0, col)
			grid_control.draw_circle(Vector2(cx, cy), 10.0, Color(col.r, col.g, col.b, col.a * 0.65), false, 2.0)
			grid_control.draw_rect(Rect2(cx - 2.0, y1 + 2.0, 4.0, y2 - y1 - 4.0), col, true)

		"SECOND_CHANCE":
			grid_control.draw_line(Vector2(x1, cy), Vector2(cx, cy), col, 2.0)
			grid_control.draw_line(Vector2(cx, cy), Vector2(x2 - 8.0, y1 + 4.0), col, 2.0)
			grid_control.draw_line(Vector2(cx, cy), Vector2(x2 - 8.0, y2 - 4.0), col, 2.0)
			grid_control.draw_circle(Vector2(cx, cy), 3.0, col)

		"HEAVY_NULL":
			grid_control.draw_circle(Vector2(cx, cy), 10.0, col, false, 2.5)
			grid_control.draw_line(Vector2(cx - 6.0, cy + 12.0), Vector2(cx + 6.0, cy + 12.0), col, 2.0)
			grid_control.draw_line(Vector2(cx - 3.0, cy + 8.0), Vector2(cx - 3.0, cy + 15.0), col, 2.0)
			grid_control.draw_line(Vector2(cx + 3.0, cy + 8.0), Vector2(cx + 3.0, cy + 15.0), col, 2.0)

		"INFINITE":
			grid_control.draw_arc(Vector2(cx - 6.0, cy), 6.0, PI * 0.25, PI * 1.75, 18, col, 2.0)
			grid_control.draw_arc(Vector2(cx + 6.0, cy), 6.0, -PI * 0.75, PI * 0.75, 18, col, 2.0)

		_:
			grid_control.draw_circle(Vector2(cx, cy), 3.0, col)


# ------------------------------------------------------------
# GRID INPUT
# ------------------------------------------------------------
func _on_grid_gui_input(event: InputEvent) -> void:
	if not is_open:
		return

	if event is InputEventMouseButton and event.pressed:
		var local_pos: Vector2 = grid_control.get_local_mouse_position()
		var cell: Vector2i = _pixel_to_grid(local_pos)

		if event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_held_update()
			return

		if event.button_index != MOUSE_BUTTON_LEFT:
			return

		if cell == Vector2i(-1, -1):
			return

		if held_instance_id != -1:
			if Run.equip_update_instance(held_instance_id, cell, held_rotation):
				held_instance_id = -1
				held_rotation = 0
				_refresh_all()
			else:
				grid_control.queue_redraw()
			return

		var instance_id: int = int(Run.ram_grid[cell.y][cell.x])
		if instance_id != -1:
			var item: Dictionary = Run.get_owned_update_by_instance_id(instance_id)
			if not item.is_empty():
				held_instance_id = instance_id
				held_rotation = int(item.get("rotation", 0))
				Run.remove_update_from_ram(instance_id)
				_refresh_all()


func _cancel_held_update() -> void:
	if held_instance_id == -1:
		return

	held_instance_id = -1
	held_rotation = 0
	_refresh_all()


func _rotate_held_update() -> void:
	if held_instance_id == -1:
		return

	var item: Dictionary = Run.get_owned_update_by_instance_id(held_instance_id)
	if item.is_empty():
		return

	var update_id: String = str(item.get("update_id", ""))
	if not UpdatesDB.is_rotatable(update_id):
		return

	held_rotation = wrapi(held_rotation + 1, 0, 4)
	_refresh_desc_for_instance(held_instance_id)
	_refresh_inventory_button_highlight()
	grid_control.queue_redraw()
