extends Control

# =========================
# UI REFERENCES
# =========================
@onready var menu_buttons: Array[Button] = [
	$UI/Center/RowWrap/Row/Left/Menu/StartGroup/ItemStart,
	$UI/Center/RowWrap/Row/Left/Menu/SettingsGroup/ItemSettings,
	$UI/Center/RowWrap/Row/Left/Menu/TutorialGroup/ItemTutorial,
	$UI/Center/RowWrap/Row/Left/Menu/CreditsGroup/ItemCredits,
	$UI/Center/RowWrap/Row/Left/Menu/ExitGroup/ItemExit
]

@onready var menu_selectors: Array[Label] = [
	$UI/Center/RowWrap/Row/Left/Menu/StartGroup/SelectorStart,
	$UI/Center/RowWrap/Row/Left/Menu/SettingsGroup/SelectorSettings,
	$UI/Center/RowWrap/Row/Left/Menu/TutorialGroup/SelectorTutorial,
	$UI/Center/RowWrap/Row/Left/Menu/CreditsGroup/SelectorCredits,
	$UI/Center/RowWrap/Row/Left/Menu/ExitGroup/SelectorExit
]

@onready var footer: Label = $UI/Center/RowWrap/Row/Left/Footer
@onready var character: TextureRect = $UI/Center/RowWrap/Row/Right/Character

@onready var settings_panel: Control = $UI/SettingsPanel
@onready var settings_bg: ColorRect = $UI/SettingsPanel/ColorRect
@onready var settings_title: Label = $UI/SettingsPanel/CenterContainer/VBoxContainer/Title
@onready var master_value: Button = $UI/SettingsPanel/CenterContainer/VBoxContainer/MasterValue
@onready var fullscreen_value: Button = $UI/SettingsPanel/CenterContainer/VBoxContainer/FullscreenValue
@onready var resolution_value: Button = $UI/SettingsPanel/CenterContainer/VBoxContainer/ResolutionValue
@onready var mouse_sens_value: Button = $UI/SettingsPanel/CenterContainer/VBoxContainer/MouseSensValue
@onready var camera_tilt_value: Button = $UI/SettingsPanel/CenterContainer/VBoxContainer/CameraTiltValue
@onready var back_value: Button = $UI/SettingsPanel/CenterContainer/VBoxContainer/BackValue

@onready var credits_panel: Control = $UI/CreditsPanel
@onready var credits_bg: ColorRect = $UI/CreditsPanel/ColorRect
@onready var credits_title: Label = $UI/CreditsPanel/CenterContainer/VBoxContainer/Title
@onready var credits_name_1: Label = $UI/CreditsPanel/CenterContainer/VBoxContainer/CreditsName1
@onready var credits_name_2: Label = $UI/CreditsPanel/CenterContainer/VBoxContainer/CreditsName2
@onready var credits_name_3: Label = $UI/CreditsPanel/CenterContainer/VBoxContainer/CreditsName3
@onready var special_thanks_title: Label = $UI/CreditsPanel/CenterContainer/VBoxContainer/SpecialThanksTitle
@onready var special_thanks_1: Label = $UI/CreditsPanel/CenterContainer/VBoxContainer/LaSpecialThanks1bel
@onready var credits_back_value: Button = $UI/CreditsPanel/CenterContainer/VBoxContainer/BackValue

@onready var settings_buttons: Array[Button] = [
	master_value,
	fullscreen_value,
	resolution_value,
	mouse_sens_value,
	camera_tilt_value,
	back_value
]

# =========================
# AUDIO (nodes under MainMenu root)
# =========================
@onready var bgm: AudioStreamPlayer = $BGM
@onready var sfx_switch: AudioStreamPlayer = $SfxSwitch
@onready var sfx_click: AudioStreamPlayer = $SfxClick

# =========================
# FADE
# =========================
@onready var fade_rect: ColorRect = $UI/FadeRect

# =========================
# STATE
# =========================
var index: int = 0
var is_transitioning: bool = false
var in_settings: bool = false
var settings_index: int = 0
var in_credits: bool = false

# Parallax
var parallax_strength: float = 10.0
var character_base_pos: Vector2

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if bgm and bgm.stream and not bgm.playing:
		bgm.play()

	if fade_rect:
		fade_rect.visible = true
		var c := fade_rect.color
		c.a = 0.0
		fade_rect.color = c

	if character:
		character_base_pos = character.position

	if settings_panel:
		settings_panel.visible = false

	if credits_panel:
		credits_panel.visible = false

	_setup_mouse_passthrough()
	_wire_menu_mouse()
	_wire_settings_mouse()
	_wire_credits_mouse()
	_update_menu()
	_update_footer()
	_refresh_settings_ui()
	_refresh_credits_ui()

func _setup_mouse_passthrough() -> void:
	var passthrough_nodes: Array[Control] = [
		$BG/Background,
		$BG/DustShader,
		$UI/Center/RowWrap/Row/Left/Title,
		$UI/Center/RowWrap/Row/Left/Footer,
		$UI/Center/RowWrap/Row/Fill,
		$UI/Center/RowWrap/Row/Right,
		$UI/Center/RowWrap/Row/Right/Character,
		settings_bg,
		settings_title,
		credits_bg,
		credits_title,
		credits_name_1,
		credits_name_2,
		credits_name_3,
		special_thanks_title,
		special_thanks_1,
		$UI/CreditsPanel/CenterContainer/VBoxContainer/Spacer,
		$UI/CreditsPanel/CenterContainer/VBoxContainer/Spacer2,
		get_node("UI/CreditsPanel/GameJam info"),
		$UI/CrtOverlay,
		$UI/FadeRect
	]

	for node in passthrough_nodes:
		if node:
			node.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _wire_menu_mouse() -> void:
	for i in range(menu_buttons.size()):
		var button := menu_buttons[i]
		button.mouse_entered.connect(_on_menu_button_hovered.bind(i))
		button.pressed.connect(_on_menu_button_pressed.bind(i))

func _wire_settings_mouse() -> void:
	for i in range(settings_buttons.size()):
		var button := settings_buttons[i]
		button.mouse_entered.connect(_on_settings_button_hovered.bind(i))
		button.pressed.connect(_on_settings_button_pressed.bind(i))
		button.gui_input.connect(_on_settings_button_gui_input.bind(i))

func _wire_credits_mouse() -> void:
	credits_back_value.mouse_entered.connect(_on_credits_back_hovered)
	credits_back_value.pressed.connect(_on_credits_back_pressed)

func _on_menu_button_hovered(button_index: int) -> void:
	if is_transitioning or in_settings or in_credits:
		return
	if index != button_index:
		index = button_index
		_update_menu()
		_play_switch()

func _on_menu_button_pressed(button_index: int) -> void:
	if is_transitioning or in_settings or in_credits:
		return
	index = button_index
	_update_menu()
	_play_click()
	await _start_transition()

func _on_settings_button_hovered(button_index: int) -> void:
	if is_transitioning or not in_settings:
		return
	if settings_index != button_index:
		settings_index = button_index
		_refresh_settings_ui()
		_play_switch()

func _on_settings_button_pressed(button_index: int) -> void:
	if is_transitioning or not in_settings:
		return

	settings_index = button_index
	_refresh_settings_ui()
	_play_click()

	if button_index == 5:
		_close_settings()
		return

	_change_settings_value(1)

func _on_settings_button_gui_input(event: InputEvent, button_index: int) -> void:
	if is_transitioning or not in_settings:
		return

	if not (event is InputEventMouseButton):
		return

	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed:
		return

	settings_index = button_index
	_refresh_settings_ui()

	match mouse_event.button_index:
		MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_WHEEL_DOWN:
			if button_index != 5:
				_play_click()
				_change_settings_value(-1)
				get_viewport().set_input_as_handled()
		MOUSE_BUTTON_WHEEL_UP:
			if button_index != 5:
				_play_click()
				_change_settings_value(1)
				get_viewport().set_input_as_handled()

func _on_credits_back_hovered() -> void:
	if is_transitioning or not in_credits:
		return
	_refresh_credits_ui(true)

func _on_credits_back_pressed() -> void:
	if is_transitioning or not in_credits:
		return
	_play_click()
	_close_credits()

func _unhandled_input(event: InputEvent) -> void:
	if is_transitioning:
		return

	if in_settings:
		if event.is_action_pressed("ui_down"):
			settings_index = min(settings_index + 1, 5)
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

			if settings_index == 1 or settings_index == 4:
				_change_settings_value(1)
			elif settings_index == 5:
				_close_settings()
			else:
				_change_settings_value(1)

			return

		elif event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
			if settings_index == 1 or settings_index == 4:
				_play_click()
				_change_settings_value(1)
				return

		elif event.is_action_pressed("ui_cancel"):
			_play_click()
			_close_settings()
			return

		return

	if in_credits:
		if event.is_action_pressed("ui_accept"):
			_play_click()
			_close_credits()
			return

		elif event.is_action_pressed("ui_cancel"):
			_play_click()
			_close_credits()
			return

		return

	if event.is_action_pressed("ui_down"):
		index = (index + 1) % menu_buttons.size()
		_update_menu()
		_play_switch()

	elif event.is_action_pressed("ui_up"):
		index = (index - 1 + menu_buttons.size()) % menu_buttons.size()
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
	for i in range(menu_buttons.size()):
		menu_buttons[i].modulate.a = 1.0 if i == index else 0.75
		menu_selectors[i].text = ">" if i == index else ""
		menu_selectors[i].modulate.a = 1.0 if i == index else 0.0

func _activate_current() -> void:
	match index:
		0:
			get_tree().change_scene_to_file("res://Game/Main.tscn")
		1:
			_restore_from_transition()
			_open_settings()
		2:
			get_tree().change_scene_to_file("res://Game/tutorial_main.tscn")
		3:
			_restore_from_transition()
			_open_credits()
		4:
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

	var resolution_text := "RESOLUTION: " + Settings.get_current_resolution_text()
	if Settings.fullscreen:
		resolution_text += "  (FULLSCREEN)"

	var mouse_text := "MOUSE SENS: " + str(snapped(Settings.mouse_sens, 0.0001))
	var camera_tilt_text := "CAMERA TILT: " + ("ON" if Settings.camera_tilt_enabled else "OFF")
	var back_text := "BACK"

	var texts: Array[String] = [
		master_text,
		fullscreen_text,
		resolution_text,
		mouse_text,
		camera_tilt_text,
		back_text
	]

	for i in range(settings_buttons.size()):
		var selected := i == settings_index
		settings_buttons[i].text = ("> " if selected else "  ") + texts[i]
		settings_buttons[i].modulate.a = 1.0 if selected else 0.75

func _change_settings_value(direction: int) -> void:
	match settings_index:
		0:
			Settings.set_master_volume(Settings.master_volume + (5 * direction))
		1:
			if direction != 0:
				Settings.set_fullscreen(not Settings.fullscreen)
		2:
			Settings.set_resolution_index(Settings.resolution_index + direction)
		3:
			Settings.set_mouse_sens(Settings.mouse_sens + (0.0002 * direction))
		4:
			if direction != 0:
				Settings.set_camera_tilt_enabled(not Settings.camera_tilt_enabled)
		5:
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

func _open_credits() -> void:
	in_credits = true
	credits_panel.visible = true
	_refresh_credits_ui(false)

func _close_credits() -> void:
	in_credits = false
	credits_panel.visible = false
	_update_menu()

func _refresh_credits_ui(selected_back: bool = true) -> void:
	if not credits_panel:
		return

	credits_title.text = "CREDITS"
	credits_name_1.text = "  Main / Developer: DDD"
	credits_name_2.text = "  Composer: Niko Chantzis"
	credits_name_3.text = "  Animator: Siti Arina M. / rouxbah"

	special_thanks_title.text = "SPECIAL THANKS"
	special_thanks_title.modulate.a = 0.95
	special_thanks_1.text = "  Playtesting: Adircas"

	credits_back_value.text = ("> " if selected_back else "  ") + "BACK"
	credits_back_value.modulate.a = 1.0 if selected_back else 0.75
