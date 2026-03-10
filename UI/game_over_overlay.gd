extends Control

signal retry_pressed
signal exit_pressed

@onready var crt_layer: ColorRect = $CRTLayer
@onready var black_bg: ColorRect = $BlackBg
@onready var power_line: ColorRect = $PowerLine

@onready var center_container: CenterContainer = $CenterContainer
@onready var menu_root: VBoxContainer = $CenterContainer/MenuRoot

@onready var title_label: Label = $CenterContainer/MenuRoot/TitleLabel
@onready var subtitle_label: Label = $CenterContainer/MenuRoot/SubtitleLabel
@onready var hbox: HBoxContainer = $CenterContainer/MenuRoot/HBoxContainer

@onready var retry_group: HBoxContainer = $CenterContainer/MenuRoot/HBoxContainer/RetryGroup
@onready var selector_retry: Label = $CenterContainer/MenuRoot/HBoxContainer/RetryGroup/SelectorRetry
@onready var retry_button: Button = $CenterContainer/MenuRoot/HBoxContainer/RetryGroup/RetryButton

@onready var exit_group: HBoxContainer = $CenterContainer/MenuRoot/HBoxContainer/ExitGroup
@onready var selector_exit: Label = $CenterContainer/MenuRoot/HBoxContainer/ExitGroup/SelectorExit
@onready var exit_button: Button = $CenterContainer/MenuRoot/HBoxContainer/ExitGroup/ExitButton

@onready var sfx_switch: AudioStreamPlayer = $SfxSwitch
@onready var sfx_click: AudioStreamPlayer = $SfxClick

var _busy: bool = false
var _menu_index: int = 0


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP

	crt_layer.visible = false
	black_bg.visible = false
	power_line.visible = false
	center_container.visible = false
	menu_root.visible = false

	black_bg.z_index = 10
	crt_layer.z_index = 11
	power_line.z_index = 12
	center_container.z_index = 20
	menu_root.z_index = 21

	menu_root.modulate = Color(1, 1, 1, 1)

	retry_button.focus_mode = Control.FOCUS_NONE
	exit_button.focus_mode = Control.FOCUS_NONE

	retry_button.text = "RETRY"
	exit_button.text = "MAIN MENU"

	retry_button.pressed.connect(_on_retry_pressed)
	exit_button.pressed.connect(_on_exit_pressed)

	retry_button.mouse_entered.connect(func() -> void:
		if _menu_index != 0:
			_menu_index = 0
			_refresh_menu_selector()
			_play_switch()
	)

	exit_button.mouse_entered.connect(func() -> void:
		if _menu_index != 1:
			_menu_index = 1
			_refresh_menu_selector()
			_play_switch()
	)

	_refresh_menu_selector()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if _busy:
		return

	if event.is_action_pressed("ui_left"):
		var vp_left := get_viewport()
		if vp_left:
			vp_left.set_input_as_handled()
		_menu_index = (_menu_index - 1 + 2) % 2
		_refresh_menu_selector()
		_play_switch()
		return

	if event.is_action_pressed("ui_right"):
		var vp_right := get_viewport()
		if vp_right:
			vp_right.set_input_as_handled()
		_menu_index = (_menu_index + 1) % 2
		_refresh_menu_selector()
		_play_switch()
		return

	if event.is_action_pressed("ui_accept"):
		var vp_accept := get_viewport()
		if vp_accept:
			vp_accept.set_input_as_handled()
		_activate_current()
		return

	if event.is_action_pressed("ui_cancel"):
		var vp_cancel := get_viewport()
		if vp_cancel:
			vp_cancel.set_input_as_handled()

		if _busy:
			return

		_busy = true
		_play_click()

		var delay: float = 0.14
		if sfx_click and sfx_click.stream != null:
			delay = min(sfx_click.stream.get_length(), 0.18)

		await get_tree().create_timer(delay).timeout
		_on_exit_pressed()
		return


func show_game_over() -> void:
	if _busy:
		return

	_busy = true
	visible = true
	_menu_index = 0
	_refresh_menu_selector()

	# Lasciamo intravedere il gameplay sotto per far vedere davvero il CRT.
	black_bg.visible = true
	black_bg.color = Color(0, 0, 0, 0.15)

	crt_layer.visible = true
	crt_layer.scale = Vector2.ONE
	crt_layer.modulate = Color(1, 1, 1, 1)

	power_line.visible = false
	power_line.scale = Vector2.ONE
	power_line.modulate = Color(1, 1, 1, 1)

	center_container.visible = false
	menu_root.visible = false
	menu_root.modulate = Color(1, 1, 1, 0)

	await get_tree().process_frame

	crt_layer.pivot_offset = crt_layer.size * 0.5
	power_line.pivot_offset = power_line.size * 0.5

	var mat := crt_layer.material as ShaderMaterial
	if mat != null:
		# Solo parametri realmente presenti nel tuo CRT.gdshader
		_set_shader_param_if_exists(mat, "warp_strength", 0.22)
		_set_shader_param_if_exists(mat, "vignette_strength", 0.90)
		_set_shader_param_if_exists(mat, "scanline_strength", 0.75)
		_set_shader_param_if_exists(mat, "noise_strength", 0.18)
		_set_shader_param_if_exists(mat, "flicker_strength", 0.15)
		_set_shader_param_if_exists(mat, "edge_softness", 0.08)

	await get_tree().create_timer(0.16).timeout

	# 1) Assestamento CRT più evidente e più lungo
	var tw1 := create_tween()
	tw1.set_trans(Tween.TRANS_SINE)
	tw1.set_ease(Tween.EASE_OUT)

	if mat != null:
		tw1.parallel().tween_method(
			func(v: float) -> void:
				_set_shader_param_if_exists(mat, "warp_strength", v),
			0.22, 0.08, 0.45
		)
		tw1.parallel().tween_method(
			func(v: float) -> void:
				_set_shader_param_if_exists(mat, "noise_strength", v),
			0.18, 0.05, 0.45
		)
		tw1.parallel().tween_method(
			func(v: float) -> void:
				_set_shader_param_if_exists(mat, "flicker_strength", v),
			0.15, 0.04, 0.45
		)
		tw1.parallel().tween_method(
			func(v: float) -> void:
				_set_shader_param_if_exists(mat, "scanline_strength", v),
			0.75, 0.35, 0.45
		)

	await tw1.finished

	# 2) Compare la linea
	power_line.visible = true
	power_line.scale = Vector2(1.0, 1.0)
	power_line.modulate = Color(1, 1, 1, 1)

	var tw2 := create_tween()
	tw2.set_trans(Tween.TRANS_CUBIC)
	tw2.set_ease(Tween.EASE_IN)
	tw2.parallel().tween_property(crt_layer, "scale:y", 0.015, 0.20)
	tw2.parallel().tween_property(power_line, "scale:y", 0.4, 0.20)

	await tw2.finished

	var tw3 := create_tween()
	tw3.set_trans(Tween.TRANS_LINEAR)
	tw3.set_ease(Tween.EASE_OUT)
	tw3.parallel().tween_property(power_line, "modulate:a", 0.0, 0.14)
	tw3.parallel().tween_property(crt_layer, "modulate:a", 0.0, 0.14)

	await tw3.finished

	crt_layer.visible = false
	power_line.visible = false

	# Solo adesso nero pieno stabile
	black_bg.visible = true
	black_bg.color = Color(0, 0, 0, 1.0)

	await get_tree().create_timer(0.32).timeout

	center_container.visible = true
	menu_root.visible = true
	menu_root.modulate = Color(1, 1, 1, 0)
	_refresh_menu_selector()

	var tw_menu := create_tween()
	tw_menu.set_trans(Tween.TRANS_SINE)
	tw_menu.set_ease(Tween.EASE_OUT)
	tw_menu.tween_property(menu_root, "modulate:a", 1.0, 0.18)

	await tw_menu.finished

	_busy = false


func hide_game_over() -> void:
	_busy = false
	visible = false

	crt_layer.visible = false
	black_bg.visible = false
	power_line.visible = false
	center_container.visible = false
	menu_root.visible = false

	crt_layer.scale = Vector2.ONE
	crt_layer.modulate = Color(1, 1, 1, 1)

	power_line.scale = Vector2.ONE
	power_line.modulate = Color(1, 1, 1, 1)

	menu_root.modulate = Color(1, 1, 1, 1)


func _refresh_menu_selector() -> void:
	selector_retry.text = ""
	selector_exit.text = ""

	retry_button.modulate.a = 0.75
	exit_button.modulate.a = 0.75

	match _menu_index:
		0:
			selector_retry.text = ">"
			retry_button.modulate.a = 1.0
		1:
			selector_exit.text = ">"
			exit_button.modulate.a = 1.0


func _activate_current() -> void:
	if _busy:
		return

	_busy = true
	_play_click()

	var delay: float = 0.14
	if sfx_click and sfx_click.stream != null:
		delay = min(sfx_click.stream.get_length(), 0.18)

	await get_tree().create_timer(delay).timeout

	match _menu_index:
		0:
			_on_retry_pressed()
		1:
			_on_exit_pressed()


func _on_retry_pressed() -> void:
	retry_pressed.emit()


func _on_exit_pressed() -> void:
	exit_pressed.emit()


func _set_shader_param_if_exists(mat: ShaderMaterial, param_name: String, value: Variant) -> void:
	if mat == null:
		return
	if not _has_shader_param(mat, param_name):
		return
	mat.set_shader_parameter(param_name, value)


func _has_shader_param(mat: ShaderMaterial, param_name: String) -> bool:
	if mat == null:
		return false

	var shader := mat.shader
	if shader == null:
		return false

	for p in shader.get_shader_uniform_list():
		if p.has("name") and String(p["name"]) == param_name:
			return true

	return false

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
