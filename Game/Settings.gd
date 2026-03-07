extends Node

const SETTINGS_PATH := "user://settings.cfg"
const WINDOWED_SIZE := Vector2i(1152, 648)

# Valori salvati
var master_volume: int = 80
var fullscreen: bool = true
var mouse_sens: float = 0.002

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

	master_volume = clamp(master_volume, 0, 100)
	mouse_sens = clamp(mouse_sens, 0.0005, 0.01)

func save_settings() -> void:
	var config := ConfigFile.new()

	config.set_value("audio", "master_volume", master_volume)
	config.set_value("video", "fullscreen", fullscreen)
	config.set_value("input", "mouse_sens", mouse_sens)

	config.save(SETTINGS_PATH)

func apply_settings() -> void:
	_apply_master_volume()
	_apply_fullscreen()

func set_master_volume(value: int) -> void:
	master_volume = clamp(value, 0, 100)
	_apply_master_volume()
	save_settings()

func set_fullscreen(value: bool) -> void:
	fullscreen = value
	print("fullscreen =", fullscreen)
	_apply_fullscreen()
	save_settings()

func set_mouse_sens(value: float) -> void:
	mouse_sens = clamp(value, 0.0005, 0.01)
	save_settings()

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

func _apply_fullscreen() -> void:
	call_deferred("_apply_fullscreen_impl")

func _apply_fullscreen_impl() -> void:
	var window := get_window()
	if window == null:
		return

	if fullscreen:
		window.mode = Window.MODE_FULLSCREEN
		return

	window.mode = Window.MODE_WINDOWED
	await get_tree().process_frame

	window.borderless = false
	window.size = WINDOWED_SIZE

	var screen_index := window.current_screen
	if screen_index < 0:
		screen_index = 0

	var screen_pos := DisplayServer.screen_get_position(screen_index)
	var screen_size := DisplayServer.screen_get_size(screen_index)

	window.position = screen_pos + (screen_size - WINDOWED_SIZE) / 2
