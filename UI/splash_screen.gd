extends Control

@export var total_seconds: float = 10.0
@export var black_seconds: float = 2.0
@export var strong_crt_seconds: float = 5.0
@export var settle_seconds: float = 3.0
@export var next_scene_path: String = "res://UI/main_menu.tscn"

# CRT “rounded corners” suggeriti (pronunciati)
@export var crt_corner_radius: float = 0.14
@export var crt_border_softness: float = 0.01
@export var crt_vignette: float = 0.55
@export var crt_border_dark: float = 0.85

@onready var splash_audio: AudioStreamPlayer = $SplashAudio
@onready var crt_overlay: ColorRect = $CrtOverlay2
@onready var black_overlay: ColorRect = $BlackOverlay

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Sanity: 2 + 5 + 3 = 10 (se cambi valori, aggiorna coerentemente)
	# Se non vuoi vincolarti, ignora total_seconds e usa solo le 3 fasi.
	if abs((black_seconds + strong_crt_seconds + settle_seconds) - total_seconds) > 0.01:
		push_warning("SplashScreen: timing non coerente (black+strong+settle != total_seconds).")

	# Audio
	if splash_audio and splash_audio.stream:
		splash_audio.play()

	# Shader setup
	var mat := crt_overlay.material as ShaderMaterial
	if mat:
		# Fase CRT forte (sarà coperta dal nero nei primi 2s)
		mat.set_shader_parameter("strength", 1.0)
		mat.set_shader_parameter("jitter_amt", 1.0)
		mat.set_shader_parameter("warp_amt", 1.0)

		# Rounded corners pronunciati
		_safe_set(mat, "corner_radius", crt_corner_radius)
		_safe_set(mat, "border_softness", crt_border_softness)
		_safe_set(mat, "vignette", crt_vignette)
		_safe_set(mat, "border_dark", crt_border_dark)

	# 0–2s: nero
	if black_overlay:
		black_overlay.visible = true
	await get_tree().create_timer(black_seconds).timeout

	# 2s: mostra contenuto + CRT forte
	if black_overlay:
		black_overlay.visible = false

	# 2–7s: CRT forte fisso
	await get_tree().create_timer(strong_crt_seconds).timeout

	# 7–10s: stabilizza gradualmente
	if mat:
		var tw := create_tween()
		tw.set_trans(Tween.TRANS_EXPO)
		tw.set_ease(Tween.EASE_OUT)

		tw.tween_property(mat, "shader_parameter/strength", 0.0, settle_seconds)
		tw.parallel().tween_property(mat, "shader_parameter/jitter_amt", 0.0, settle_seconds)
		tw.parallel().tween_property(mat, "shader_parameter/warp_amt", 0.0, settle_seconds)

	# Attendi fine stabilizzazione
	await get_tree().create_timer(settle_seconds).timeout

	# Stop audio
	if splash_audio and splash_audio.playing:
		splash_audio.stop()

	# Cambio scena
	if ResourceLoader.exists(next_scene_path):
		get_tree().change_scene_to_file(next_scene_path)
	else:
		push_error("SplashScreen: next_scene_path non valido -> " + next_scene_path)


func _safe_set(mat: ShaderMaterial, param: StringName, value: float) -> void:
	# Evita errori se lo shader non ha ancora quel parametro
	# (Godot non espone un "has_parameter", quindi proviamo a settare e basta)
	mat.set_shader_parameter(param, value)
