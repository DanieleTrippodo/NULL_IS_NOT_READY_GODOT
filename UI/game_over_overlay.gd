extends Control

signal retry_pressed
signal exit_pressed

@onready var crt_layer: ColorRect = $CRTLayer
@onready var black_bg: ColorRect = $BlackBg
@onready var power_line: ColorRect = $PowerLine

@onready var center_container: CenterContainer = $CenterContainer
@onready var panel: Panel = $CenterContainer/Panel
@onready var menu: VBoxContainer = $CenterContainer/Panel/Menu

@onready var retry_button: Button = $CenterContainer/Panel/Menu/RetryButton
@onready var exit_button: Button = $CenterContainer/Panel/Menu/ExitButton

var _busy: bool = false

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP

	crt_layer.visible = false
	black_bg.visible = false
	power_line.visible = false
	center_container.visible = false
	panel.visible = false
	menu.visible = false

	# Forza il menu sopra tutto
	black_bg.z_index = 10
	center_container.z_index = 20
	panel.z_index = 21

	retry_button.pressed.connect(_on_retry_pressed)
	exit_button.pressed.connect(_on_exit_pressed)

func show_game_over() -> void:
	if _busy:
		return

	_busy = true
	visible = true

	crt_layer.visible = true
	black_bg.visible = false
	power_line.visible = false

	center_container.visible = false
	panel.visible = false
	menu.visible = false

	crt_layer.scale = Vector2.ONE
	crt_layer.modulate = Color(1, 1, 1, 1)

	power_line.scale = Vector2.ONE
	power_line.modulate = Color(1, 1, 1, 1)

	await get_tree().process_frame

	crt_layer.pivot_offset = crt_layer.size * 0.5
	power_line.pivot_offset = power_line.size * 0.5

	var mat := crt_layer.material as ShaderMaterial
	if mat != null:
		_set_shader_param_if_exists(mat, "warp_strength", 0.22)
		_set_shader_param_if_exists(mat, "vignette_strength", 0.65)
		_set_shader_param_if_exists(mat, "scanline_strength", 0.50)
		_set_shader_param_if_exists(mat, "noise_strength", 0.10)
		_set_shader_param_if_exists(mat, "flicker_strength", 0.10)
		_set_shader_param_if_exists(mat, "edge_softness", 0.04)
		_set_shader_param_if_exists(mat, "black_border_x", 0.06)
		_set_shader_param_if_exists(mat, "black_border_y", 0.06)
		_set_shader_param_if_exists(mat, "border_feather", 0.015)

	# Totale animazione ~0.9s
	await get_tree().create_timer(0.08).timeout

	var tw1 := create_tween()
	tw1.set_trans(Tween.TRANS_SINE)
	tw1.set_ease(Tween.EASE_OUT)

	if mat != null:
		tw1.parallel().tween_method(
			func(v: float) -> void:
				_set_shader_param_if_exists(mat, "warp_strength", v),
			0.22, 0.12, 0.34
		)
		tw1.parallel().tween_method(
			func(v: float) -> void:
				_set_shader_param_if_exists(mat, "noise_strength", v),
			0.10, 0.05, 0.34
		)
		tw1.parallel().tween_method(
			func(v: float) -> void:
				_set_shader_param_if_exists(mat, "flicker_strength", v),
			0.10, 0.04, 0.34
		)

	await tw1.finished

	power_line.visible = true
	power_line.scale = Vector2.ONE
	power_line.modulate = Color(1, 1, 1, 1)

	var tw2 := create_tween()
	tw2.set_trans(Tween.TRANS_CUBIC)
	tw2.set_ease(Tween.EASE_IN)
	tw2.parallel().tween_property(crt_layer, "scale:y", 0.02, 0.26)

	await tw2.finished

	await get_tree().create_timer(0.06).timeout

	var tw3 := create_tween()
	tw3.set_trans(Tween.TRANS_CUBIC)
	tw3.set_ease(Tween.EASE_IN)
	tw3.parallel().tween_property(crt_layer, "scale:x", 0.0, 0.16)
	tw3.parallel().tween_property(power_line, "scale:x", 0.0, 0.16)
	tw3.parallel().tween_property(power_line, "modulate:a", 0.0, 0.16)

	await tw3.finished

	crt_layer.visible = false
	power_line.visible = false

	black_bg.visible = true
	black_bg.color = Color(0, 0, 0, 0.98)

	center_container.visible = true
	panel.visible = true
	menu.visible = true

	retry_button.grab_focus()

	_busy = false

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
