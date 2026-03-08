extends Node

const SETTINGS_PATH := "user://settings.cfg"
const DEFAULT_WINDOWED_INDEX := 2

const WINDOWED_RESOLUTIONS: Array[Vector2i] = [
	Vector2i(960, 540),
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080)
]

var master_volume: int = 80
var fullscreen: bool = true
var mouse_sens: float = 0.002
var resolution_index: int = DEFAULT_WINDOWED_INDEX

func _ready() -> void:
	load_settings()
	apply_settings()

func load_settings() -> void:
	var config := ConfigFile.new()
	var err := config.load(SETTINGS_PATH)

	if err != OK:
		save_settings()
		return

	master_volume = int(config.get_value("audio", "master_volume", 80))
	fullscreen = bool(config.get_value("video", "fullscreen", true))
	mouse_sens = float(config.get_value("input", "mouse_sens", 0.002))
	resolution_index = int(config.get_value("video", "resolution_index", DEFAULT_WINDOWED_INDEX))

	master_volume = clamp(master_volume, 0, 100)
	mouse_sens = clamp(mouse_sens, 0.0005, 0.01)
	resolution_index = clamp(resolution_index, 0, WINDOWED_RESOLUTIONS.size() - 1)

func save_settings() -> void:
	var config := ConfigFile.new()

	config.set_value("audio", "master_volume", master_volume)
	config.set_value("video", "fullscreen", fullscreen)
	config.set_value("video", "resolution_index", resolution_index)
	config.set_value("input", "mouse_sens", mouse_sens)

	config.save(SETTINGS_PATH)

func apply_settings() -> void:
	_apply_master_volume()
	_apply_window_mode_and_resolution()

func set_master_volume(value: int) -> void:
	master_volume = clamp(value, 0, 100)
	_apply_master_volume()
	save_settings()

func set_fullscreen(value: bool) -> void:
	fullscreen = value
	_apply_window_mode_and_resolution()
	save_settings()

func set_mouse_sens(value: float) -> void:
	mouse_sens = clamp(value, 0.0005, 0.01)
	save_settings()

func set_resolution_index(value: int) -> void:
	resolution_index = clamp(value, 0, WINDOWED_RESOLUTIONS.size() - 1)
	_apply_window_mode_and_resolution()
	save_settings()

func get_current_resolution() -> Vector2i:
	return WINDOWED_RESOLUTIONS[resolution_index]

func get_current_resolution_text() -> String:
	var r := get_current_resolution()
	return str(r.x) + "x" + str(r.y)

func _apply_master_volume() -> void:
	var bus_index := AudioServer.get_bus_index("Master")
	if bus_index == -1:
		return

	var db: float
	if master_volume <= 0:
		db = -80.0
	else:
		db = lerp(-30.0, 0.0, master_volume / 100.0)

	AudioServer.set_bus_volume_db(bus_index, db)

func _apply_window_mode_and_resolution() -> void:
	call_deferred("_apply_window_mode_and_resolution_impl")

func _apply_window_mode_and_resolution_impl() -> void:
	var window := get_window()
	if window == null:
		return

	if fullscreen:
		window.mode = Window.MODE_FULLSCREEN
		return

	window.mode = Window.MODE_WINDOWED
	await get_tree().process_frame

	window.borderless = false

	var size := get_current_resolution()
	window.size = size

	var screen_index := window.current_screen
	if screen_index < 0:
		screen_index = 0

	var screen_pos := DisplayServer.screen_get_position(screen_index)
	var screen_size := DisplayServer.screen_get_size(screen_index)
	window.position = screen_pos + (screen_size - size) / 2
