extends CanvasLayer
signal closed

@export var close_action := "interact"
@export var close_action_alt := "ui_cancel"

# Typewriter
@export var typewriter_enabled: bool = true
@export var chars_per_second: float = 40.0
@export var start_delay: float = 0.05
@export var sfx_every_n_chars: int = 2
@export var sfx_pitch_min: float = 0.95
@export var sfx_pitch_max: float = 1.05

# Blinking cursor (underscore)
@export var cursor_enabled: bool = true
@export var cursor_char: String = "_"
@export var cursor_blink_speed: float = 2.0 # blinks per second

@onready var log_root: Control = %LogRoot
@onready var type_sfx: AudioStreamPlayer = $TypeSfx

var _open := false

# typewriter state
var _body_label: RichTextLabel = null
var _full_text := ""
var _shown_chars := 0
var _accum := 0.0
var _delay := 0.0
var _typing := false

# cursor state
var _cursor_timer := 0.0
var _cursor_on := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)

func is_open() -> bool:
	return _open

func open_log(log_scene: PackedScene) -> void:
	_clear()

	if log_scene:
		var inst := log_scene.instantiate()
		log_root.add_child(inst)

		# Find RichTextLabel "Body" inside the log scene
		_body_label = _find_body_label(inst)
		_setup_typewriter_if_needed()

	_open = true
	visible = true
	set_process(true)

	# reset cursor
	_cursor_timer = 0.0
	_cursor_on = false

func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	set_process(false)
	_clear()
	closed.emit()

func _process(delta: float) -> void:
	if not _open:
		return

	# Typewriter update
	if _typing:
		if _delay > 0.0:
			_delay -= delta
			return

		_accum += delta * chars_per_second
		var add: int = int(floor(_accum))
		if add > 0:
			_accum -= add
			_reveal_more(add)
	else:
		# Cursor blink only when typing is finished
		if cursor_enabled and _body_label != null:
			_cursor_timer += delta
			var interval: float = 1.0 / maxf(cursor_blink_speed, 0.01)
			if _cursor_timer >= interval:
				_cursor_timer = 0.0
				_cursor_on = not _cursor_on
				_apply_cursor()

func _input(event: InputEvent) -> void:
	if not _open:
		return

	# Left click: if typing, finish instantly; else close
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _typing:
			_finish_typing()
		else:
			close()
		return

	# Keys: E/ESC
	if event.is_action_pressed(close_action) or event.is_action_pressed(close_action_alt):
		# If typing, first completes. Next press closes.
		if _typing:
			_finish_typing()
		else:
			close()

func _setup_typewriter_if_needed() -> void:
	_typing = false
	_full_text = ""
	_shown_chars = 0
	_accum = 0.0
	_delay = start_delay

	if not typewriter_enabled:
		return
	if _body_label == null:
		return

	_full_text = _body_label.text
	_body_label.text = ""
	_typing = true

func _reveal_more(count: int) -> void:
	if _body_label == null:
		_typing = false
		return

	# IMPORTANT: mini() keeps it strictly int (avoids Variant typing warnings)
	var target: int = mini(_shown_chars + count, _full_text.length())
	if target == _shown_chars:
		return

	for i in range(_shown_chars, target):
		_body_label.text += _full_text[i]
		if sfx_every_n_chars > 0 and ((i + 1) % sfx_every_n_chars == 0):
			_play_type_sfx()

	_shown_chars = target

	if _shown_chars >= _full_text.length():
		_typing = false
		_cursor_timer = 0.0
		_cursor_on = true
		if cursor_enabled:
			_apply_cursor()

func _finish_typing() -> void:
	if _body_label != null:
		_body_label.text = _full_text
	_typing = false
	_cursor_timer = 0.0
	_cursor_on = true
	if cursor_enabled:
		_apply_cursor()

func _apply_cursor() -> void:
	if _body_label == null:
		return

	# base text = current text without cursor if already appended
	var base := _body_label.text
	if base.ends_with(cursor_char):
		base = base.substr(0, base.length() - cursor_char.length())

	_body_label.text = base + (cursor_char if _cursor_on else "")

func _play_type_sfx() -> void:
	if type_sfx == null:
		return
	if type_sfx.stream == null:
		return
	type_sfx.pitch_scale = randf_range(sfx_pitch_min, sfx_pitch_max)
	type_sfx.play()

func _find_body_label(root: Node) -> RichTextLabel:
	# Searches for a RichTextLabel named "Body"
	if root is RichTextLabel and root.name == "Body":
		return root as RichTextLabel
	for c in root.get_children():
		var res := _find_body_label(c)
		if res != null:
			return res
	return null

func _clear() -> void:
	if log_root != null:
		for c in log_root.get_children():
			c.queue_free()

	_body_label = null
	_full_text = ""
	_typing = false
	_cursor_timer = 0.0
	_cursor_on = false
