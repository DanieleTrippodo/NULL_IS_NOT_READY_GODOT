extends Control

@onready var dim: ColorRect = $Dim
@onready var panel: Panel = $Panel
@onready var title_label: Label = $Panel/Title
@onready var help_label: Label = $Panel/Help
@onready var grid_control: Control = $Panel/HSplit/Left/Grid
@onready var inventory_list: VBoxContainer = $Panel/HSplit/Right/Scroll/InventoryList
@onready var desc_label: RichTextLabel = $Panel/HSplit/Right/Desc

const CELL_SIZE: int = 52
const CELL_GAP: int = 4
const GRID_BG := Color(0.08, 0.08, 0.1, 0.92)
const GRID_LINE := Color(0.35, 0.35, 0.42, 1.0)
const CELL_FILL := Color(0.14, 0.14, 0.18, 1.0)
const EQUIPPED_FILL := Color(0.88, 0.88, 0.95, 0.18)
const PREVIEW_OK := Color(0.5, 1.0, 0.6, 0.42)
const PREVIEW_BAD := Color(1.0, 0.35, 0.35, 0.42)
const TEXT_DARK := Color(0.1, 0.1, 0.12, 1.0)

var is_open: bool = false

# pezzo selezionato dalla lista ma non ancora piazzato
var held_instance_id: int = -1
var held_rotation: int = 0

# cache hover grid
var hovered_cell: Vector2i = Vector2i(-1, -1)

# riferimento bottoni inventario
var _inventory_buttons: Dictionary = {}


func _ready() -> void:
	visible = false
	set_process(true)
	set_process_unhandled_input(true)

	title_label.text = "R.A.M."
	help_label.text = "TAB close  |  Left Click place/remove  |  R rotate  |  Click item to pick"

	grid_control.custom_minimum_size = _get_grid_pixel_size()
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

	if event.is_action_pressed("ui_text_indent") or event.is_action_pressed("ui_focus_next"):
		# ignoriamo, evita comportamenti strani con Tab/UI focus
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			_rotate_held_or_selected()
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
	_refresh_inventory_list()
	_refresh_desc()
	grid_control.queue_redraw()


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
		inventory_list.add_child(lbl)
		return

	for item in items:
		var instance_id: int = int(item.get("instance_id", -1))
		var update_id: String = str(item.get("update_id", ""))
		var rotation: int = int(item.get("rotation", 0))

		var btn := Button.new()
		btn.focus_mode = Control.FOCUS_ALL
		btn.custom_minimum_size = Vector2(0, 44)
		btn.text = _build_inventory_button_text(update_id, rotation)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_on_inventory_item_pressed.bind(instance_id))
		btn.mouse_entered.connect(_on_inventory_item_hovered.bind(instance_id))

		inventory_list.add_child(btn)
		_inventory_buttons[instance_id] = btn

		if held_instance_id == instance_id:
			btn.modulate = Color(1.0, 1.0, 1.0, 0.8)


func _build_inventory_button_text(update_id: String, rotation: int) -> String:
	var title: String = UpdatesDB.get_title(update_id)
	var size: Vector2i = Run.get_ram_size_for_update(update_id, rotation)
	var rarity_name: String = UpdatesDB.rarity_name(UpdatesDB.get_rarity(update_id))
	return "%s   [%s]   %dx%d" % [title, rarity_name, size.x, size.y]


func _on_inventory_item_pressed(instance_id: int) -> void:
	var item: Dictionary = Run.get_owned_update_by_instance_id(instance_id)
	if item.is_empty():
		return

	held_instance_id = instance_id
	held_rotation = int(item.get("rotation", 0))
	_refresh_desc_for_instance(instance_id)
	_refresh_inventory_list()
	grid_control.queue_redraw()


func _on_inventory_item_hovered(instance_id: int) -> void:
	_refresh_desc_for_instance(instance_id)


# ------------------------------------------------------------
# DESCRIPTION
# ------------------------------------------------------------
func _refresh_desc() -> void:
	if held_instance_id != -1:
		_refresh_desc_for_instance(held_instance_id)
		return

	desc_label.text = "[b]R.A.M.[/b]\nStore Updates here to activate them.\n\nClick an item from the list, then place it into the grid."
	

func _refresh_desc_for_instance(instance_id: int) -> void:
	var item: Dictionary = Run.get_owned_update_by_instance_id(instance_id)
	if item.is_empty():
		desc_label.text = ""
		return

	var update_id: String = str(item.get("update_id", ""))
	var rarity: String = UpdatesDB.rarity_name(UpdatesDB.get_rarity(update_id))
	var shape_size: Vector2i = Run.get_ram_size_for_update(update_id, int(item.get("rotation", 0)))
	var tradeoff: String = UpdatesDB.get_tradeoff_desc(update_id)
	var desc: String = UpdatesDB.get_desc(update_id)

	var bb := ""
	bb += "[b]%s[/b]\n" % UpdatesDB.get_title(update_id)
	bb += "%s\n" % rarity
	bb += "Shape: %dx%d\n\n" % [shape_size.x, shape_size.y]
	bb += "%s\n" % desc

	if tradeoff != "":
		bb += "\n[i]Trade-off:[/i] %s" % tradeoff

	desc_label.text = bb


# ------------------------------------------------------------
# GRID DRAW
# ------------------------------------------------------------
func _get_grid_pixel_size() -> Vector2:
	var w := Run.ram_cols * CELL_SIZE + (Run.ram_cols - 1) * CELL_GAP
	var h := Run.ram_rows * CELL_SIZE + (Run.ram_rows - 1) * CELL_GAP
	return Vector2(w, h)


func _cell_rect(cell: Vector2i) -> Rect2:
	var x := cell.x * (CELL_SIZE + CELL_GAP)
	var y := cell.y * (CELL_SIZE + CELL_GAP)
	return Rect2(x, y, CELL_SIZE, CELL_SIZE)


func _pixel_to_grid(p: Vector2) -> Vector2i:
	for y in range(Run.ram_rows):
		for x in range(Run.ram_cols):
			var rect := _cell_rect(Vector2i(x, y))
			if rect.has_point(p):
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func _draw() -> void:
	# root non disegna
	pass


func _notification(what: int) -> void:
	if what == NOTIFICATION_READY:
		if not grid_control.draw.is_connected(_on_grid_draw):
			grid_control.draw.connect(_on_grid_draw)


func _on_grid_draw() -> void:
	var size := _get_grid_pixel_size()
	grid_control.draw_rect(Rect2(Vector2.ZERO, size), GRID_BG, true)

	# celle base
	for y in range(Run.ram_rows):
		for x in range(Run.ram_cols):
			var rect := _cell_rect(Vector2i(x, y))
			grid_control.draw_rect(rect, CELL_FILL, true)
			grid_control.draw_rect(rect, GRID_LINE, false, 1.0)

	# pezzi equipaggiati
	var equipped: Array[Dictionary] = Run.get_equipped_updates()
	for item in equipped:
		var instance_id: int = int(item.get("instance_id", -1))
		var update_id: String = str(item.get("update_id", ""))
		var origin: Vector2i = item.get("grid_pos", Vector2i(-1, -1)) as Vector2i
		var rotation: int = int(item.get("rotation", 0))
		var cells: Array[Vector2i] = Run.get_ram_cells_for_update(update_id, rotation)

		var fill := _instance_color(instance_id)
		for c in cells:
			var pos := origin + c
			if pos.x < 0 or pos.y < 0:
				continue
			var rect := _cell_rect(pos)
			grid_control.draw_rect(rect, fill, true)
			grid_control.draw_rect(rect, GRID_LINE, false, 1.0)

	# preview held item
	if held_instance_id != -1 and hovered_cell != Vector2i(-1, -1):
		var held_item: Dictionary = Run.get_owned_update_by_instance_id(held_instance_id)
		if not held_item.is_empty():
			var update_id: String = str(held_item.get("update_id", ""))
			var cells: Array[Vector2i] = Run.get_ram_cells_for_update(update_id, held_rotation)
			var can_place: bool = Run.can_place_update_instance(held_instance_id, hovered_cell, held_rotation)
			var preview_color: Color = PREVIEW_OK if can_place else PREVIEW_BAD

			for c in cells:
				var pos := hovered_cell + c
				if pos.x < 0 or pos.x >= Run.ram_cols or pos.y < 0 or pos.y >= Run.ram_rows:
					continue
				var rect := _cell_rect(pos)
				grid_control.draw_rect(rect, preview_color, true)
				grid_control.draw_rect(rect, GRID_LINE, false, 1.0)


func _instance_color(instance_id: int) -> Color:
	var hue := fmod(float(instance_id) * 0.173, 1.0)
	return Color.from_hsv(hue, 0.22, 0.95, 0.70)


# ------------------------------------------------------------
# GRID INPUT
# ------------------------------------------------------------
func _on_grid_gui_input(event: InputEvent) -> void:
	if not is_open:
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var local_pos: Vector2 = grid_control.get_local_mouse_position()
		var cell: Vector2i = _pixel_to_grid(local_pos)
		if cell == Vector2i(-1, -1):
			return

		# se sto tenendo un pezzo, provo a piazzarlo
		if held_instance_id != -1:
			if Run.equip_update_instance(held_instance_id, cell, held_rotation):
				held_instance_id = -1
				held_rotation = 0
				_refresh_all()
			else:
				grid_control.queue_redraw()
			return

		# altrimenti provo a prendere/rimuovere un pezzo già piazzato
		var instance_id: int = int(Run.ram_grid[cell.y][cell.x])
		if instance_id != -1:
			var item: Dictionary = Run.get_owned_update_by_instance_id(instance_id)
			if not item.is_empty():
				held_instance_id = instance_id
				held_rotation = int(item.get("rotation", 0))
				Run.remove_update_from_ram(instance_id)
				_refresh_all()


func _rotate_held_or_selected() -> void:
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
	_refresh_inventory_list()
	grid_control.queue_redraw()
