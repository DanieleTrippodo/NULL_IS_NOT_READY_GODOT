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

		# trova il RichTextLabel "Body" dentro la scena log
		_body_label = _find_body_label(inst)
		_setup_typewriter_if_needed()

	_open = true
	visible = true
	set_process(true)

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

	if _typing:
		if _delay > 0.0:
			_delay -= delta
			return

		_accum += delta * chars_per_second
		var add := int(floor(_accum))
		if add > 0:
			_accum -= add
			_reveal_more(add)

func _input(event: InputEvent) -> void:
	if not _open:
		return

	# Click sinistro: se sta digitando -> completa; altrimenti chiude
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _typing:
			_finish_typing()
		else:
			close()
		return

	# Tasti: E/ESC
	if event.is_action_pressed(close_action) or event.is_action_pressed(close_action_alt):
		# se sta digitando, prima completa, al secondo input chiude
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

	# Prende il testo e lo riscrive progressivamente
	_full_text = _body_label.text
	_body_label.text = ""
	_typing = true

func _reveal_more(count: int) -> void:
	if _body_label == null:
		_typing = false
		return

	var target: int = mini(_shown_chars + count, _full_text.length())
	if target == _shown_chars:
		return

	for i in range(_shown_chars, target):
		# aggiungi 1 char alla volta (così possiamo fare sfx ogni N char)
		_body_label.text += _full_text[i]
		if sfx_every_n_chars > 0 and ((i + 1) % sfx_every_n_chars == 0):
			_play_type_sfx()

	_shown_chars = target

	if _shown_chars >= _full_text.length():
		_typing = false

func _finish_typing() -> void:
	if _body_label != null:
		_body_label.text = _full_text
	_typing = false

func _play_type_sfx() -> void:
	if type_sfx == null:
		return
	if type_sfx.stream == null:
		return
	type_sfx.pitch_scale = randf_range(sfx_pitch_min, sfx_pitch_max)
	type_sfx.play()

func _find_body_label(root: Node) -> RichTextLabel:
	# Cerca un nodo chiamato "Body" che sia RichTextLabel
	if root is RichTextLabel and root.name == "Body":
		return root as RichTextLabel

	for c in root.get_children():
		var res := _find_body_label(c)
		if res != null:
			return res
	return null

func _clear() -> void:
	if log_root == null:
		return
	for c in log_root.get_children():
		c.queue_free()

	_body_label = null
	_full_text = ""
	_typing = false
