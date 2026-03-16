extends Control

@export var main_menu_scene_path: String = "res://UI/main_menu.tscn"
@export var total_duration: float = 18.0
@export var fade_in_duration: float = 1.1
@export var fade_out_duration: float = 1.1
@export var scroll_start_y: float = 760.0
@export var scroll_end_y: float = -460.0

@onready var credits_block: VBoxContainer = $Content/CreditsBlock
@onready var fade_rect: ColorRect = $FadeRect
@onready var skip_hint: Label = $SkipHint

var _elapsed: float = 0.0
var _exiting: bool = false
var _layout_ready: bool = false

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	visible = true

	var c: Color = fade_rect.color
	c.a = 1.0
	fade_rect.color = c

	skip_hint.modulate.a = 0.78

	await get_tree().process_frame
	await get_tree().process_frame

	_layout_ready = true
	_center_credits_block()
	_set_scroll_ratio(0.0)
	_play_intro_fade()


func _process(delta: float) -> void:
	if not _layout_ready or _exiting:
		return

	_elapsed += delta

	var scroll_window: float = maxf(total_duration - fade_out_duration, 0.01)
	var ratio: float = clampf(_elapsed / scroll_window, 0.0, 1.0)
	_set_scroll_ratio(ratio)

	if _elapsed >= total_duration - fade_out_duration:
		_begin_exit()


func _unhandled_input(event: InputEvent) -> void:
	if _exiting:
		return

	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		_begin_exit()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		_begin_exit()


func _play_intro_fade() -> void:
	var t: Tween = create_tween()
	t.set_trans(Tween.TRANS_SINE)
	t.set_ease(Tween.EASE_IN_OUT)
	t.tween_property(fade_rect, "color:a", 0.0, fade_in_duration)


func _begin_exit() -> void:
	if _exiting:
		return

	_exiting = true

	var t: Tween = create_tween()
	t.set_trans(Tween.TRANS_SINE)
	t.set_ease(Tween.EASE_IN_OUT)
	t.tween_property(fade_rect, "color:a", 1.0, fade_out_duration)
	await t.finished
	get_tree().change_scene_to_file(main_menu_scene_path)


func _center_credits_block() -> void:
	var min_size: Vector2 = credits_block.get_combined_minimum_size()
	credits_block.position.x = floor((size.x - min_size.x) * 0.5)


func _set_scroll_ratio(ratio: float) -> void:
	_center_credits_block()
	credits_block.position.y = lerpf(scroll_start_y, scroll_end_y, ratio)
