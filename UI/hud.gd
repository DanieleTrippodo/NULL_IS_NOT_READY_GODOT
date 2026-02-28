# res://UI/hud.gd
extends Control

@onready var hand: TextureRect = $Hand
@onready var status_icon: TextureRect = $StatusIcon
@onready var depth_label: Label = $DepthLabel
@onready var crosshair_tex: TextureRect = $Crosshair/CrosshairTex

@onready var perk_label: Label = $PerkLabel
@onready var perk_timer: Timer = $PerkTimer

@onready var fade_rect: ColorRect = $FadeRect

# ------------------------------------------------------------
# STATUS ICON (READY / NOT READY)
# ------------------------------------------------------------
@export var status_ready_texture: Texture2D
@export var status_not_ready_texture: Texture2D

# Rettangolo “di design” (prima dello scaling). Se (0,0) usa size texture.
@export var status_rect_size: Vector2 = Vector2(160, 32)

# Slider unico per ridimensionare dall’Inspector
@export_range(0.25, 3.0, 0.01) var status_scale: float = 1.0

# READY leggermente più grande (oltre allo status_scale)
@export_range(1.0, 2.0, 0.01) var ready_scale: float = 1.12

# Pop quando torna READY
@export var ready_pop_enabled: bool = true
@export_range(1.0, 1.6, 0.01) var ready_pop_mult: float = 1.22
@export_range(0.01, 0.5, 0.01) var ready_pop_up_time: float = 0.08
@export_range(0.01, 0.5, 0.01) var ready_pop_down_time: float = 0.12

var _last_ready: bool = true
var _status_tween: Tween

# ------------------------------------------------------------
# HAND BOB (DOOM-ish walking)
# ------------------------------------------------------------
@export var hand_bob_enabled: bool = true
@export var hand_bob_only_on_floor: bool = true
@export_range(0.0, 2.0, 0.01) var walk_speed_threshold: float = 0.10

# Taratura: velocità orizzontale alla quale il bob è “pieno”
@export_range(0.1, 20.0, 0.1) var walk_speed_reference: float = 6.0

@export_range(0.0, 50.0, 0.1) var hand_bob_speed: float = 12.0
@export var hand_bob_amplitude: Vector2 = Vector2(5.0, 9.0) # px (x,y)
@export_range(0.0, 10.0, 0.1) var hand_bob_rotation_deg: float = 1.4
@export_range(0.0, 30.0, 0.1) var hand_return_speed: float = 14.0

# Se true usa “step bob” (2 bump per ciclo) stile DOOM
@export var doom_step_bob: bool = true

var _hand_base_pos: Vector2
var _hand_base_rot: float
var _hand_phase: float = 0.0
var _hand_has_base: bool = false
var _player_cache: CharacterBody3D

# ------------------------------------------------------------
# CROSSHAIR SIZES
# ------------------------------------------------------------
var base_crosshair_size: Vector2 = Vector2(32, 32)
var not_ready_size: Vector2 = Vector2(22, 22)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	Signals.null_ready_changed.connect(_on_null_ready_changed)
	Signals.depth_changed.connect(_on_depth_changed)
	Signals.perk_granted.connect(_on_perk_granted)

	var cb := Callable(self, "_on_perk_timer_timeout")
	if not perk_timer.timeout.is_connected(cb):
		perk_timer.timeout.connect(cb)

	perk_label.visible = false

	# fade init
	fade_rect.visible = false
	_set_fade_alpha(0.0)

	# init dopo 1 frame (pivot/size corretti)
	call_deferred("_post_ready_init")

func _post_ready_init() -> void:
	await get_tree().process_frame

	# StatusIcon setup
	status_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_apply_status_icon_layout()

	# Hand bob base pose
	_hand_base_pos = hand.position
	_hand_base_rot = hand.rotation
	hand.pivot_offset = hand.size * 0.5
	_hand_has_base = true

	_update_all()

func _process(delta: float) -> void:
	if not hand_bob_enabled or not _hand_has_base:
		return

	var walking := _is_player_walking()

	if walking:
		var p := _get_player()
		if p == null:
			return

		var v := p.velocity
		var horizontal_speed: float = Vector2(v.x, v.z).length()

		# 0..1: amp e velocità bob scalano con la velocità reale
		var speed_factor: float = clamp(horizontal_speed / walk_speed_reference, 0.0, 1.0)

		_hand_phase += delta * hand_bob_speed * lerp(0.35, 1.0, speed_factor)

		var amp: Vector2 = hand_bob_amplitude * speed_factor

		# DOOM-ish: sway laterale + “step bob” (2 bump per ciclo)
		var x: float = sin(_hand_phase) * amp.x

		var y: float
		if doom_step_bob:
			# 0..amp.y (sempre positivo) con due bump per ciclo
			y = ((1.0 - cos(_hand_phase * 2.0)) * 0.5) * amp.y
		else:
			# oscillazione simmetrica
			y = sin(_hand_phase * 2.0) * amp.y

		hand.position = _hand_base_pos + Vector2(x, y)

		var rot_amp: float = deg_to_rad(hand_bob_rotation_deg) * speed_factor
		hand.rotation = _hand_base_rot + sin(_hand_phase) * rot_amp
	else:
		# rientro morbido alla posa base
		var k: float = 1.0 - exp(-hand_return_speed * delta)
		hand.position = hand.position.lerp(_hand_base_pos, k)
		hand.rotation = lerp_angle(hand.rotation, _hand_base_rot, k)

func _get_player() -> CharacterBody3D:
	# Richiede: il Player deve essere in group "player"
	if _player_cache == null or not is_instance_valid(_player_cache):
		_player_cache = get_tree().get_first_node_in_group("player") as CharacterBody3D
	return _player_cache

func _is_player_walking() -> bool:
	var p := _get_player()
	if p == null:
		return false

	var v := p.velocity
	var horizontal_speed: float = Vector2(v.x, v.z).length()
	if horizontal_speed < walk_speed_threshold:
		return false

	if hand_bob_only_on_floor:
		return p.is_on_floor()

	return true

func _apply_status_icon_layout() -> void:
	var sz := status_rect_size

	if sz == Vector2.ZERO:
		if status_not_ready_texture:
			sz = status_not_ready_texture.get_size()
		elif status_ready_texture:
			sz = status_ready_texture.get_size()
		else:
			sz = Vector2(160, 32)

	sz *= status_scale

	status_icon.custom_minimum_size = sz
	status_icon.size = sz
	# pivot a (0,0) per non spostare l’icona in corner quando scala
	status_icon.pivot_offset = Vector2.ZERO

func _update_all() -> void:
	_last_ready = Run.null_ready # evita pop all'avvio
	_on_null_ready_changed(Run.null_ready)
	_on_depth_changed(Run.depth)

func _on_null_ready_changed(is_ready: bool) -> void:
	var just_became_ready := is_ready and not _last_ready
	_last_ready = is_ready

	# texture
	status_icon.texture = status_ready_texture if is_ready else status_not_ready_texture

	# size + scale
	_apply_status_icon_layout()
	status_icon.scale = Vector2.ONE * (ready_scale if is_ready else 1.0)

	# crosshair
	var s: Vector2 = base_crosshair_size if is_ready else not_ready_size
	crosshair_tex.custom_minimum_size = s
	crosshair_tex.size = s

	if ready_pop_enabled and just_became_ready:
		_play_ready_pop()

func _play_ready_pop() -> void:
	if is_instance_valid(_status_tween):
		_status_tween.kill()

	var base := Vector2.ONE * ready_scale
	status_icon.scale = base

	_status_tween = create_tween()
	_status_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_status_tween.tween_property(status_icon, "scale", base * ready_pop_mult, ready_pop_up_time)
	_status_tween.tween_property(status_icon, "scale", base, ready_pop_down_time)

func _on_depth_changed(d: int) -> void:
	depth_label.text = "DEPTH: %d" % d

func _on_perk_granted(title: String, description: String) -> void:
	perk_label.text = "%s\n%s" % [title, description]
	perk_label.visible = true
	perk_timer.stop()
	perk_timer.start()

func _on_perk_timer_timeout() -> void:
	perk_label.visible = false

func _set_fade_alpha(a: float) -> void:
	var c := fade_rect.color
	c.a = a
	fade_rect.color = c

func fade_out(duration: float = 0.25) -> void:
	fade_rect.visible = true
	var tw := create_tween()
	var c := fade_rect.color
	c.a = 1.0
	tw.tween_property(fade_rect, "color", c, duration)
	await tw.finished

func fade_in(duration: float = 0.25) -> void:
	var tw := create_tween()
	var c := fade_rect.color
	c.a = 0.0
	tw.tween_property(fade_rect, "color", c, duration)
	await tw.finished
	fade_rect.visible = false
