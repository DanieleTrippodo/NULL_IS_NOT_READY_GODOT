extends Control

# =========================
# UI REFERENCES
# =========================
@onready var item_labels: Array[Label] = [
	$UI/Center/RowWrap/Row/Left/Menu/ItemStart,
	$UI/Center/RowWrap/Row/Left/Menu/ItemSettings,
	$UI/Center/RowWrap/Row/Left/Menu/ItemTutorial,
	$UI/Center/RowWrap/Row/Left/Menu/ItemExit
]

@onready var footer: Label = $UI/Center/RowWrap/Row/Left/Footer
@onready var character: TextureRect = $UI/Center/RowWrap/Row/Right/Character

@onready var settings_panel: Control = $UI/SettingsPanel
@onready var settings_title: Label = $UI/SettingsPanel/CenterContainer/VBoxContainer/Title
@onready var master_value: Label = $UI/SettingsPanel/CenterContainer/VBoxContainer/MasterValue
@onready var fullscreen_value: Label = $UI/SettingsPanel/CenterContainer/VBoxContainer/FullscreenValue
@onready var mouse_sens_value: Label = $UI/SettingsPanel/CenterContainer/VBoxContainer/MouseSensValue
@onready var back_value: Label = $UI/SettingsPanel/CenterContainer/VBoxContainer/BackValue

# =========================
# AUDIO (nodes under MainMenu root)
# =========================
@onready var bgm: AudioStreamPlayer = $BGM
@onready var sfx_switch: AudioStreamPlayer = $SfxSwitch
@onready var sfx_click: AudioStreamPlayer = $SfxClick

# =========================
# FADE (node under MainMenu root)
# FadeRect must be above CrtOverlay in the scene tree (last is best)
# =========================
@onready var fade_rect: ColorRect = $UI/FadeRect

# =========================
# STATE
# =========================
var index: int = 0
var is_transitioning: bool = false
var in_settings: bool = false
var settings_index: int = 0

# Parallax
var parallax_strength: float = 10.0
var character_base_pos: Vector2

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

	# Start BGM (if Autoplay is off)
	if bgm and bgm.stream and not bgm.playing:
		bgm.play()

	# FadeRect: start fully transparent (we animate its COLOR alpha)
	if fade_rect:
		fade_rect.visible = true
		var c := fade_rect.color
		c.a = 0.0
		fade_rect.color = c

	# Cache character base pos for parallax
	if character:
		character_base_pos = character.position

	if settings_panel:
		settings_panel.visible = false

	_update_menu()
	_update_footer()
	_refresh_settings_ui()

func _unhandled_input(event: InputEvent) -> void:
	if is_transitioning:
		return

	if in_settings:
		if event.is_action_pressed("ui_down"):
			settings_index = min(settings_index + 1, 3)
			_refresh_settings_ui()
			_play_switch()
			return

		elif event.is_action_pressed("ui_up"):
			settings_index = max(settings_index - 1, 0)
			_refresh_settings_ui()
			_play_switch()
			return

		elif event.is_action_pressed("ui_left"):
			_change_settings_value(-1)
			_play_switch()
			return

		elif event.is_action_pressed("ui_right"):
			_change_settings_value(1)
			_play_switch()
			return

		elif event.is_action_pressed("ui_accept"):
			_play_click()
			if settings_index == 3:
				_close_settings()
			return

		elif event.is_action_pressed("ui_cancel"):
			_play_click()
			_close_settings()
			return

		return

	if event.is_action_pressed("ui_down"):
		index = (index + 1) % item_labels.size()
		_update_menu()
		_play_switch()

	elif event.is_action_pressed("ui_up"):
		index = (index - 1 + item_labels.size()) % item_labels.size()
		_update_menu()
		_play_switch()

	elif event.is_action_pressed("ui_accept"):
		_play_click()
		await _start_transition()

	elif event.is_action_pressed("ui_cancel"):
		_play_click()
		await _start_quit_transition()

func _process(_delta: float) -> void:
	if is_transitioning:
		return
	if not character:
		return

	# Mouse parallax (clamped)
	var vp: Vector2 = get_viewport_rect().size
	if vp.x <= 0.0 or vp.y <= 0.0:
		return

	var m: Vector2 = get_viewport().get_mouse_position()
	var denom: float = max(vp.x, vp.y)
	var centered: Vector2 = (m - (vp * 0.5)) / denom

	var offset: Vector2 = centered * parallax_strength
	offset.x = clamp(offset.x, -12.0, 12.0)
	offset.y = clamp(offset.y, -8.0, 8.0)

	character.position = character_base_pos + offset

# =========================
# MENU LOGIC
# =========================
func _update_menu() -> void:
	for i in range(item_labels.size()):
		var base := item_labels[i].text.strip_edges()
		base = base.trim_prefix(">")
		base = base.strip_edges()

		if i == index:
			item_labels[i].text = "> " + base
			item_labels[i].modulate.a = 1.0
		else:
			item_labels[i].text = "  " + base
			item_labels[i].modulate.a = 0.75

func _activate_current() -> void:
	match index:
		0:
			# START
			get_tree().change_scene_to_file("res://Game/Main.tscn")
		1:
			# SETTINGS
			_restore_from_transition()
			_open_settings()
		2:
			# TUTORIAL
			get_tree().change_scene_to_file("res://Game/tutorial_main.tscn")
		3:
			# EXIT
			get_tree().quit()

func _update_footer() -> void:
	var v := str(ProjectSettings.get_setting("application/config/version"))
	footer.text = "v%s  © 2026 DDD" % v

func _open_settings() -> void:
	in_settings = true
	settings_index = 0
	settings_panel.visible = true
	_refresh_settings_ui()

func _close_settings() -> void:
	in_settings = false
	settings_panel.visible = false
	_update_menu()

func _refresh_settings_ui() -> void:
	if not settings_panel:
		return

	settings_title.text = "SETTINGS"

	var master_text := "MASTER VOLUME: " + str(Settings.master_volume)
	var fullscreen_text := "FULLSCREEN: " + ("ON" if Settings.fullscreen else "OFF")
	var mouse_text := "MOUSE SENS: " + str(snapped(Settings.mouse_sens, 0.0001))
	var back_text := "BACK"

	var rows: Array[Label] = [master_value, fullscreen_value, mouse_sens_value, back_value]
	var texts: Array[String] = [master_text, fullscreen_text, mouse_text, back_text]

	for i in range(rows.size()):
		if i == settings_index:
			rows[i].text = "> " + texts[i]
			rows[i].modulate.a = 1.0
		else:
			rows[i].text = "  " + texts[i]
			rows[i].modulate.a = 0.75

func _change_settings_value(direction: int) -> void:
	match settings_index:
		0:
			Settings.set_master_volume(Settings.master_volume + (5 * direction))
		1:
			if direction != 0:
				Settings.set_fullscreen(not Settings.fullscreen)
		2:
			Settings.set_mouse_sens(Settings.mouse_sens + (0.0002 * direction))
		3:
			pass

	_refresh_settings_ui()

# =========================
# TRANSITIONS
# =========================
func _start_transition() -> void:
	is_transitioning = true
	await _fade_out(1.2)
	await get_tree().create_timer(0.08).timeout
	_activate_current()

func _start_quit_transition() -> void:
	is_transitioning = true
	await _fade_out(0.7)
	await get_tree().create_timer(0.05).timeout
	get_tree().quit()

func _fade_out(duration: float) -> void:
	if not fade_rect:
		return

	fade_rect.visible = true

	var t := create_tween()
	t.set_trans(Tween.TRANS_SINE)
	t.set_ease(Tween.EASE_IN_OUT)
	t.tween_property(fade_rect, "color:a", 1.0, duration)
	await t.finished

func _restore_from_transition() -> void:
	is_transitioning = false
	if fade_rect:
		var c := fade_rect.color
		c.a = 0.0
		fade_rect.color = c

# =========================
# AUDIO HELPERS
# =========================
func _play_switch() -> void:
	if not sfx_switch or sfx_switch.stream == null:
		return
	sfx_switch.stop()
	sfx_switch.play()

func _play_click() -> void:
	if not sfx_click or sfx_click.stream == null:
		return
	sfx_click.stop()
	sfx_click.play()
