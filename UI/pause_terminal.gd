extends CanvasLayer

signal command_requested(command: String)

const DEFAULT_TITLE := "NULL://PAUSED"
const WINDOW_MARGIN := 18.0

@export var output_chars_per_second: float = 42.0
@export var output_start_delay: float = 0.04
@export var output_sfx_every_n_chars: int = 2
@export var input_type_sfx_cooldown: float = 0.03
@export var sfx_pitch_min: float = 0.96
@export var sfx_pitch_max: float = 1.04

@onready var dim: ColorRect = $Dim
@onready var window_panel: PanelContainer = %WindowPanel
@onready var header_hitbox: Control = %HeaderHitbox
@onready var title_label: Label = %TitleLabel
@onready var output_label: RichTextLabel = %OutputLabel
@onready var input_line: LineEdit = %InputLine
@onready var type_sfx: AudioStreamPlayer = get_node_or_null("TypeSfx") as AudioStreamPlayer
@onready var sfx_click: AudioStreamPlayer = get_node_or_null("SfxClick") as AudioStreamPlayer

var _open: bool = false
var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _opened_once: bool = false

var _queued_typed_lines: Array[String] = []
var _typing_output: bool = false
var _current_typed_line: String = ""
var _current_typed_char_index: int = 0
var _typing_accum: float = 0.0
var _typing_delay: float = 0.0

var _input_sfx_cd_left: float = 0.0
var _last_input_text: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	var header_cb := Callable(self, "_on_header_gui_input")
	if header_hitbox != null and not header_hitbox.gui_input.is_connected(header_cb):
		header_hitbox.gui_input.connect(header_cb)

	if input_line != null:
		input_line.text_submitted.connect(_on_input_submitted)
		input_line.text_changed.connect(_on_input_text_changed)
		input_line.editable = true
		input_line.clear()
		input_line.placeholder_text = "type command..."
		input_line.caret_blink = true

	if title_label != null:
		title_label.text = DEFAULT_TITLE

func open_terminal() -> void:
	_open = true
	visible = true

	if not _opened_once:
		_opened_once = true
		call_deferred("_center_window")

	_clear_output()
	_reset_output_typing()

	_queue_typed_line("SESSION HALTED.")
	_queue_typed_line("TYPE HELP TO LIST AVAILABLE COMMANDS.")
	_queue_typed_line("")

	if input_line != null:
		input_line.clear()
		_last_input_text = ""

	call_deferred("_focus_input")

func close_terminal() -> void:
	_open = false
	_dragging = false
	visible = false

	if input_line != null:
		input_line.release_focus()

func is_open() -> bool:
	return _open

func _process(delta: float) -> void:
	if not _open:
		return

	if _input_sfx_cd_left > 0.0:
		_input_sfx_cd_left = maxf(0.0, _input_sfx_cd_left - delta)

	if _typing_output:
		if _typing_delay > 0.0:
			_typing_delay -= delta
			return

		_typing_accum += delta * output_chars_per_second
		var add_count: int = int(floor(_typing_accum))
		if add_count > 0:
			_typing_accum -= float(add_count)
			_reveal_typed_output(add_count)
	elif not _queued_typed_lines.is_empty():
		_start_next_typed_line()

func _input(event: InputEvent) -> void:
	if not _open:
		return

	if event.is_action_pressed("esc") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		return

	if _dragging:
		if event is InputEventMouseMotion:
			_move_window(get_viewport().get_mouse_position() + _drag_offset)
			get_viewport().set_input_as_handled()
			return

		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_dragging = false
			get_viewport().set_input_as_handled()
			call_deferred("_focus_input")
			return

func _on_header_gui_input(event: InputEvent) -> void:
	if not _open:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_drag_offset = window_panel.position - get_viewport().get_mouse_position()
		else:
			_dragging = false
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion and _dragging:
		_move_window(get_viewport().get_mouse_position() + _drag_offset)
		get_viewport().set_input_as_handled()

func _on_input_text_changed(new_text: String) -> void:
	if not _open:
		_last_input_text = new_text
		return

	if new_text == _last_input_text:
		return

	if _input_sfx_cd_left <= 0.0:
		_play_type_sfx()
		_input_sfx_cd_left = input_type_sfx_cooldown

	_last_input_text = new_text

func _on_input_submitted(raw_text: String) -> void:
	var command := raw_text.strip_edges().to_lower()
	var raw_trimmed := raw_text.strip_edges()
	var lower_trimmed := raw_trimmed.to_lower()

	if input_line != null:
		input_line.clear()
		_last_input_text = ""

	if command.is_empty():
		call_deferred("_focus_input")
		return

	_flush_pending_typed_output()
	_play_click_sfx()
	_print_prompt(command)

	if _handle_easter_egg(command):
		return

	if lower_trimmed.begins_with("echo "):
		var echo_text := raw_trimmed.substr(5, raw_trimmed.length() - 5).strip_edges()
		if echo_text.is_empty():
			_print_error_instant("ERROR: INPUT NOT VALID")
		else:
			_queue_typed_line(echo_text)
		_scroll_to_bottom()
		call_deferred("_focus_input")
		return

	if lower_trimmed == "echo":
		_print_error_instant("ERROR: INPUT NOT VALID")
		_scroll_to_bottom()
		call_deferred("_focus_input")
		return

	match command:
		"help":
			_queue_typed_line("AVAILABLE COMMANDS:")
			_queue_typed_line("RESUME  // RETURN TO THE CURRENT RUN")
			_queue_typed_line("RESTART // RELOAD THE CURRENT RUN")
			_queue_typed_line("MENU    // RETURN TO MAIN MENU")
			_queue_typed_line("QUIT    // CLOSE THE GAME")
			_scroll_to_bottom()
			call_deferred("_focus_input")
			return

		"resume", "restart", "menu", "quit":
			_print_system_instant("EXECUTING " + command.to_upper() + "...")
			command_requested.emit(command)
			return

		_:
			_print_error_instant("ERROR: INPUT NOT VALID")
			_scroll_to_bottom()
			call_deferred("_focus_input")
			return

func _handle_easter_egg(command: String) -> bool:
	var normalized := command.strip_edges().to_lower()
	var compact := normalized.replace(".", "").replace(" ", "").replace("-", "").replace("_", "")

	var egg_text := ""

	match normalized:
		"ddd":
			egg_text = "Hi! I'm the game developer. How did you find me? I've been working hard on this, my first video game, which I developed in just a month. I hope you're enjoying it. I have a lot of other ideas, even more interesting than the ones you're seeing now, but I just haven't had time to implement them. I hope to see you as a player again soon."

		"bad ideas game jam", "bad ideas", "game jam":
			egg_text = "This is the jam this game is participating in, organized by the video game development studio \"Bad Ideas Production\""

		"null":
			egg_text = "It's a little piece of you. Never lose it."

		"nulla":
			egg_text = "is that you?.. do you like your name?"

		"box":
			egg_text = "you can call him Father"

		"m.a.m.m.a.", "m.a.m.m.a", "mamma":
			egg_text = "Modular Anomaly Management & Monitoring Authority - or if you like, Mom"

	if egg_text.is_empty() and compact == "mamma":
		egg_text = "Modular Anomaly Management & Monitoring Authority - or if you like, Mom"

	if egg_text.is_empty():
		return false

	_queue_typed_line(egg_text)
	_scroll_to_bottom()
	call_deferred("_focus_input")
	return true

func _queue_typed_line(text: String) -> void:
	_queued_typed_lines.append(text)

func _start_next_typed_line() -> void:
	if _queued_typed_lines.is_empty():
		return

	_current_typed_line = _queued_typed_lines.pop_front()
	_current_typed_char_index = 0
	_typing_accum = 0.0
	_typing_delay = output_start_delay

	if _current_typed_line.is_empty():
		_append_output("\n")
		_typing_output = false
		_scroll_to_bottom()
		return

	_typing_output = true

func _reveal_typed_output(count: int) -> void:
	if output_label == null:
		_typing_output = false
		return

	var target: int = mini(_current_typed_char_index + count, _current_typed_line.length())
	if target <= _current_typed_char_index:
		return

	for i in range(_current_typed_char_index, target):
		_append_output(_current_typed_line[i])
		if output_sfx_every_n_chars > 0 and ((i + 1) % output_sfx_every_n_chars == 0):
			_play_type_sfx()

	_current_typed_char_index = target
	_scroll_to_bottom()

	if _current_typed_char_index >= _current_typed_line.length():
		_append_output("\n")
		_typing_output = false
		_scroll_to_bottom()

func _flush_pending_typed_output() -> void:
	if output_label == null:
		_reset_output_typing()
		return

	if _typing_output:
		var remaining_len: int = _current_typed_line.length() - _current_typed_char_index
		if remaining_len > 0:
			_append_output(_current_typed_line.substr(_current_typed_char_index, remaining_len))
		_append_output("\n")

	_typing_output = false
	_current_typed_line = ""
	_current_typed_char_index = 0
	_typing_accum = 0.0
	_typing_delay = 0.0

	while not _queued_typed_lines.is_empty():
		var line: String = _queued_typed_lines.pop_front()
		_print_system_instant(line)

	_scroll_to_bottom()

func _reset_output_typing() -> void:
	_queued_typed_lines.clear()
	_typing_output = false
	_current_typed_line = ""
	_current_typed_char_index = 0
	_typing_accum = 0.0
	_typing_delay = 0.0

func _move_window(target_position: Vector2) -> void:
	if window_panel == null:
		return

	var viewport_size := get_viewport().get_visible_rect().size
	var panel_size := window_panel.size
	var max_x := maxf(WINDOW_MARGIN, viewport_size.x - panel_size.x - WINDOW_MARGIN)
	var max_y := maxf(WINDOW_MARGIN, viewport_size.y - panel_size.y - WINDOW_MARGIN)

	window_panel.position = Vector2(
		clampf(target_position.x, WINDOW_MARGIN, max_x),
		clampf(target_position.y, WINDOW_MARGIN, max_y)
	)

func _center_window() -> void:
	if window_panel == null:
		return

	await get_tree().process_frame

	var viewport_size := get_viewport().get_visible_rect().size
	var panel_size := window_panel.size
	window_panel.position = ((viewport_size - panel_size) * 0.5).round()

func _focus_input() -> void:
	if not _open or input_line == null:
		return

	input_line.grab_focus()
	input_line.caret_column = input_line.text.length()

func _clear_output() -> void:
	if output_label != null:
		output_label.text = ""

func _append_output(text: String) -> void:
	if output_label == null:
		return
	output_label.text += text

func _print_prompt(command: String) -> void:
	if output_label == null:
		return
	output_label.text += "> " + command.to_upper() + "\n"

func _print_system_instant(text: String) -> void:
	if output_label == null:
		return
	output_label.text += text + "\n"

func _print_error_instant(text: String) -> void:
	if output_label == null:
		return
	output_label.text += text + "\n"

func _scroll_to_bottom() -> void:
	if output_label == null or not is_inside_tree():
		return
	call_deferred("_do_scroll_to_bottom")

func _do_scroll_to_bottom() -> void:
	if not is_inside_tree():
		return
	if output_label == null or not is_instance_valid(output_label):
		return

	output_label.scroll_to_line(maxi(0, output_label.get_line_count() - 1))

func _play_type_sfx() -> void:
	if type_sfx == null or type_sfx.stream == null:
		return
	type_sfx.pitch_scale = randf_range(sfx_pitch_min, sfx_pitch_max)
	type_sfx.play()

func _play_click_sfx() -> void:
	if sfx_click == null or sfx_click.stream == null:
		return
	sfx_click.play()
