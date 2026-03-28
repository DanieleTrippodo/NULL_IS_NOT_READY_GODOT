extends Control

@export_file("*.tscn") var next_scene_path: String = "res://UI/splash_screen.tscn"
@export var wait_seconds: float = 10.0
@export var fade_duration: float = 0.45
@export var allow_skip: bool = true

@onready var timer_label: Label = $Center/VBox/TimerLabel
@onready var continue_timer: Timer = $ContinueTimer

var _is_leaving: bool = false


func _ready() -> void:
	modulate.a = 0.0
	_update_timer_text(wait_seconds)

	await get_tree().process_frame
	await _fade_in()

	_start_countdown()


func _process(_delta: float) -> void:
	if _is_leaving:
		return

	var time_left: float = continue_timer.time_left
	if time_left < 0.0:
		time_left = 0.0

	_update_timer_text(time_left)


func _unhandled_input(event: InputEvent) -> void:
	if _is_leaving or not allow_skip:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		_go_next()
	elif event is InputEventMouseButton and event.pressed:
		_go_next()
	elif event is InputEventJoypadButton and event.pressed:
		_go_next()


func _start_countdown() -> void:
	continue_timer.start(wait_seconds)
	await continue_timer.timeout
	_go_next()


func _go_next() -> void:
	if _is_leaving:
		return

	_is_leaving = true
	continue_timer.stop()
	timer_label.text = "LOADING..."

	await _fade_out()
	get_tree().change_scene_to_file(next_scene_path)


func _fade_in() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, fade_duration)
	await tween.finished


func _fade_out() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, fade_duration)
	await tween.finished


func _update_timer_text(time_left: float) -> void:
	timer_label.text = "CONTINUING IN %d" % int(ceil(time_left))
