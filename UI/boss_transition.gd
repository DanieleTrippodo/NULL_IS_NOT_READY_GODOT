extends CanvasLayer

signal transition_finished

@export var base_text: String = "THE BOX RELEASES THE FRAGMENT"
@export var secondary_text: String = "BOX://FRAGMENT_RELEASE"
@export var fade_in_time: float = 0.24
@export var glitch_duration: float = 1.10
@export var settle_duration: float = 0.28
@export var cleanup_delay: float = 0.06

@onready var background: ColorRect = $Root/Background
@onready var noise: ColorRect = $Root/Noise
@onready var main_label: Label = $Root/CenterContainer/VBoxContainer/MainLabel
@onready var sub_label: Label = $Root/CenterContainer/VBoxContainer/SubLabel

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _playing: bool = false

func _ready() -> void:
	_rng.randomize()
	visible = false
	_reset_visuals()

func play_transition() -> void:
	if _playing:
		return

	_playing = true
	visible = true
	_reset_visuals()

	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE)
	tw.set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(background, "modulate:a", 1.0, fade_in_time)
	tw.parallel().tween_property(main_label, "modulate:a", 1.0, fade_in_time * 0.9)
	tw.parallel().tween_property(sub_label, "modulate:a", 0.8, fade_in_time * 0.9)
	await tw.finished

	var elapsed: float = 0.0
	while elapsed < glitch_duration:
		main_label.text = _glitchify(base_text)
		sub_label.text = _glitchify(secondary_text)
		noise.modulate.a = _rng.randf_range(0.04, 0.16)
		await get_tree().create_timer(0.05).timeout
		elapsed += 0.05

	main_label.text = base_text
	sub_label.text = secondary_text
	noise.modulate.a = 0.06

	await get_tree().create_timer(settle_duration).timeout
	emit_signal("transition_finished")
	await get_tree().create_timer(cleanup_delay).timeout

	_playing = false
	visible = false
	_reset_visuals()

func _reset_visuals() -> void:
	background.modulate.a = 0.0
	noise.modulate.a = 0.0
	main_label.modulate.a = 0.0
	sub_label.modulate.a = 0.0
	main_label.text = ""
	sub_label.text = ""

func _glitchify(source: String) -> String:
	var chars: PackedStringArray = ["0", "1", "/", "\\", "_", ":", "#", "X", "?", "N", "L"]
	var out: String = ""

	for i in range(source.length()):
		var c: String = source.substr(i, 1)
		if c != " " and _rng.randf() < 0.22:
			out += chars[_rng.randi_range(0, chars.size() - 1)]
		else:
			out += c

	return out
