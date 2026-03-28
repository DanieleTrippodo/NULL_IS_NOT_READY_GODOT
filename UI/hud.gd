# res://UI/hud.gd
extends Control

@onready var status_icon: TextureRect = $StatusIcon
@onready var depth_label: Label = $DepthLabel
@onready var money_label: Label = get_node_or_null("MoneyLabel") as Label
@onready var crosshair_tex: TextureRect = $Crosshair/CrosshairTex

@onready var perk_label: Label = $PerkLabel
@onready var perk_timer: Timer = $PerkTimer

@onready var fade_rect: ColorRect = $FadeRect
@onready var damage_flash: ColorRect = get_node_or_null("DamageFlash") as ColorRect
@onready var downed_recovery_ui: Control = get_node_or_null("DownedRecoveryUI") as Control
@onready var downed_recovery_label: Label = get_node_or_null("DownedRecoveryUI/DownedRecoveryLabel") as Label
@onready var downed_recovery_bar: ProgressBar = get_node_or_null("DownedRecoveryUI/DownedRecoveryBar") as ProgressBar

# Se non esiste in hud.tscn, resta null e non crasha
@onready var survival_overlay: ColorRect = get_node_or_null("SurvivalOverlay") as ColorRect

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
var _crosshair_feedback_tween: Tween
var _damage_flash_tween: Tween

# ------------------------------------------------------------
# CROSSHAIR SIZES
# ------------------------------------------------------------
var base_crosshair_size: Vector2 = Vector2(32, 32)
var not_ready_size: Vector2 = Vector2(22, 22)

@export_range(0.0, 1.0, 0.01) var hit_flash_alpha: float = 0.04
@export_range(0.0, 1.0, 0.01) var kill_flash_alpha: float = 0.08
@export_range(0.0, 1.0, 0.01) var damage_flash_alpha: float = 0.18
@export_range(0.5, 2.0, 0.01) var crosshair_hit_punch: float = 1.12
@export_range(0.5, 2.0, 0.01) var crosshair_kill_punch: float = 1.28
@export_range(0.5, 2.0, 0.01) var crosshair_damage_punch: float = 0.82

# ------------------------------------------------------------
# SURVIVAL / RECOVERY OVERLAY + GLITCH
# ------------------------------------------------------------
@export_range(0.0, 1.0, 0.01) var survival_overlay_intensity: float = 0.65
@export_range(0.0, 1.0, 0.01) var recovery_overlay_intensity: float = 0.65

@export_range(0.1, 20.0, 0.1) var recovery_overlay_rise_speed: float = 4.0
@export_range(0.1, 20.0, 0.1) var recovery_overlay_fall_speed: float = 3.0

@export var survival_glitch_enabled: bool = true
@export_range(0.0, 12.0, 0.1) var survival_glitch_px: float = 3.0
@export_range(0.0, 60.0, 1.0) var survival_glitch_hz: float = 24.0
@export var recovery_pull_speed_min: float = 1.7
@export var recovery_pull_speed_max: float = 6.0
@export var recovery_accel_time: float = 5.0

var _survival_active: bool = false
var _recovery_active: bool = false
var _overlay_current_strength: float = 0.0

var _glitch_t: float = 0.0
var _rng := RandomNumberGenerator.new()

var _status_base_pos: Vector2
var _cross_base_pos: Vector2
var _downed_recovery_active: bool = false
var _downed_recovery_remaining: float = 0.0
var _downed_recovery_total: float = 7.0
var _downed_recovery_text_refresh_t: float = 0.0
var _downed_recovery_display_text: String = ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	Signals.null_ready_changed.connect(_on_null_ready_changed)
	Signals.depth_changed.connect(_on_depth_changed)

	if Signals.has_signal("money_changed"):
		Signals.money_changed.connect(_on_money_changed)

	Signals.perk_granted.connect(_on_perk_granted)

	if Signals.has_signal("survival_mode_changed"):
		Signals.survival_mode_changed.connect(_on_survival_mode_changed)

	if Signals.has_signal("recovery_mode_changed"):
		Signals.recovery_mode_changed.connect(_on_recovery_mode_changed)

	if Signals.has_signal("downed_self_recovery_changed"):
		Signals.downed_self_recovery_changed.connect(_on_downed_self_recovery_changed)

	if Signals.has_signal("enemy_hit_feedback"):
		Signals.enemy_hit_feedback.connect(_on_enemy_hit_feedback)

	if Signals.has_signal("player_damage_feedback"):
		Signals.player_damage_feedback.connect(_on_player_damage_feedback)

	var cb := Callable(self, "_on_perk_timer_timeout")
	if not perk_timer.timeout.is_connected(cb):
		perk_timer.timeout.connect(cb)

	perk_label.visible = false

	# fade init
	fade_rect.visible = false
	_set_fade_alpha(0.0)

	_rng.randomize()

	# init dopo 1 frame (pivot/size corretti)
	call_deferred("_post_ready_init")

func _post_ready_init() -> void:
	await get_tree().process_frame

	# StatusIcon setup
	status_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_apply_status_icon_layout()

	# Salva pos base per glitch
	_status_base_pos = status_icon.position
	_cross_base_pos = crosshair_tex.position

	# Survival overlay init: deve partire SPENTO sempre
	if survival_overlay != null:
		survival_overlay.visible = true
		_set_survival_overlay_alpha(0.0)

	if damage_flash != null:
		damage_flash.visible = true
		var flash_color: Color = damage_flash.color
		flash_color.a = 0.0
		damage_flash.color = flash_color

	if downed_recovery_ui != null:
		downed_recovery_ui.visible = false

	_update_all()

func _process(delta: float) -> void:
	_update_overlay_strength(delta)
	_update_survival_glitch(delta)
	_update_downed_self_recovery_ui(delta)

# -------------------------
# STATUS ICON LAYOUT
# -------------------------
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
	if Signals.has_signal("money_changed"):
		_on_money_changed(Run.money)

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
	crosshair_tex.pivot_offset = s * 0.5
	crosshair_tex.scale = Vector2.ONE

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

func _on_money_changed(m: int) -> void:
	if money_label == null:
		return
	money_label.text = "CUBES: %d" % m

func _on_perk_granted(title: String, description: String) -> void:
	perk_label.text = "%s\n%s" % [title, description]
	perk_label.visible = true
	perk_timer.stop()
	perk_timer.start()

func _on_perk_timer_timeout() -> void:
	perk_label.visible = false

# -------------------------
# SURVIVAL / RECOVERY OVERLAY + GLITCH
# -------------------------
func _set_survival_overlay_alpha(a: float) -> void:
	if survival_overlay == null:
		return

	# Se c'è uno ShaderMaterial, NON usare l'alpha del ColorRect
	# Controlla solo via uniform dello shader.
	if survival_overlay.material is ShaderMaterial:
		survival_overlay.color = Color(1, 1, 1, 1)

		var mat := survival_overlay.material as ShaderMaterial
		mat.set_shader_parameter("effect_strength", a)
		mat.set_shader_parameter("pulse", 0.0)
		return

	# Fallback: vecchia logica (senza shader)
	var c := survival_overlay.color
	c.a = a
	survival_overlay.color = c

func _on_survival_mode_changed(active: bool) -> void:
	_survival_active = active
	_glitch_t = 0.0

	if not active:
		if not _recovery_active:
			_set_survival_overlay_alpha(0.0)
			status_icon.position = _status_base_pos
			crosshair_tex.position = _cross_base_pos
		return

func _on_recovery_mode_changed(active: bool) -> void:
	_recovery_active = active
	if not active:
		_glitch_t = 0.0

func _update_overlay_strength(delta: float) -> void:
	var target: float = 0.0

	if _survival_active:
		target = max(target, survival_overlay_intensity)

	if _recovery_active:
		target = max(target, recovery_overlay_intensity)

	var speed: float = recovery_overlay_rise_speed if target > _overlay_current_strength else recovery_overlay_fall_speed
	_overlay_current_strength = move_toward(_overlay_current_strength, target, speed * delta)

	_set_survival_overlay_alpha(_overlay_current_strength)

	if _overlay_current_strength <= 0.001 and not _survival_active and not _recovery_active:
		status_icon.position = _status_base_pos
		crosshair_tex.position = _cross_base_pos

func _update_survival_glitch(delta: float) -> void:
	if not (_survival_active or _recovery_active) or not survival_glitch_enabled:
		return

	_glitch_t += delta
	var step: float = 1.0 / maxf(1.0, survival_glitch_hz)
	if _glitch_t < step:
		return
	_glitch_t = 0.0

	var ox := _rng.randf_range(-survival_glitch_px, survival_glitch_px)
	var oy := _rng.randf_range(-survival_glitch_px, survival_glitch_px)

	# micro “desync” tra indicatori per feel glitch
	status_icon.position = _status_base_pos + Vector2(ox, oy)
	crosshair_tex.position = _cross_base_pos + Vector2(-ox, oy)

func _flash_damage_overlay(alpha: float, duration: float) -> void:
	if damage_flash == null:
		return

	if is_instance_valid(_damage_flash_tween):
		_damage_flash_tween.kill()

	var start_color: Color = damage_flash.color
	start_color.a = maxf(start_color.a, alpha)
	damage_flash.color = start_color

	_damage_flash_tween = create_tween()
	_damage_flash_tween.tween_property(damage_flash, "color:a", 0.0, duration)

func _pulse_crosshair(mult: float, up_time: float, down_time: float) -> void:
	if crosshair_tex == null:
		return

	if is_instance_valid(_crosshair_feedback_tween):
		_crosshair_feedback_tween.kill()

	crosshair_tex.scale = Vector2.ONE
	_crosshair_feedback_tween = create_tween()
	_crosshair_feedback_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_crosshair_feedback_tween.tween_property(crosshair_tex, "scale", Vector2.ONE * mult, up_time)
	_crosshair_feedback_tween.tween_property(crosshair_tex, "scale", Vector2.ONE, down_time)

func _on_enemy_hit_feedback(_enemy: Node, killed: bool) -> void:
	if killed:
		_pulse_crosshair(crosshair_kill_punch, 0.04, 0.09)
		return

	_flash_damage_overlay(hit_flash_alpha, 0.05)
	_pulse_crosshair(crosshair_hit_punch, 0.03, 0.06)

func _on_player_damage_feedback(_knockback_dir: Vector3, fatal: bool) -> void:
	var alpha: float = damage_flash_alpha
	if fatal:
		alpha *= 1.2
	_flash_damage_overlay(alpha, 0.16 if not fatal else 0.22)
	_pulse_crosshair(crosshair_damage_punch, 0.03, 0.12)

func _on_downed_self_recovery_changed(active: bool, remaining: float, total: float) -> void:
	_downed_recovery_active = active
	_downed_recovery_remaining = maxf(remaining, 0.0)
	_downed_recovery_total = maxf(total, 0.001)
	_downed_recovery_text_refresh_t = 0.0

	if downed_recovery_ui != null:
		downed_recovery_ui.visible = active

	if downed_recovery_bar != null:
		downed_recovery_bar.max_value = _downed_recovery_total
		downed_recovery_bar.value = _downed_recovery_total - _downed_recovery_remaining

	if not active and downed_recovery_label != null:
		downed_recovery_label.text = ""

func _update_downed_self_recovery_ui(delta: float) -> void:
	if downed_recovery_ui == null:
		return

	downed_recovery_ui.visible = _downed_recovery_active
	if not _downed_recovery_active:
		return

	if downed_recovery_bar != null:
		downed_recovery_bar.max_value = _downed_recovery_total
		downed_recovery_bar.value = _downed_recovery_total - _downed_recovery_remaining

	_downed_recovery_text_refresh_t -= delta
	if _downed_recovery_text_refresh_t <= 0.0:
		_downed_recovery_text_refresh_t = _rng.randf_range(0.03, 0.08)
		_downed_recovery_display_text = _build_downed_console_text()

	if downed_recovery_label != null:
		downed_recovery_label.text = _downed_recovery_display_text

func _build_downed_console_text() -> String:
	var seconds_text := "%.1f" % _downed_recovery_remaining
	var line := "> SELF-RECOVERY IN %ss" % seconds_text

	if _rng.randf() < 0.35:
		line = _glitch_text(line)

	return line

func _glitch_text(source: String) -> String:
	var chars := ["#", "@", "%", "?", "!", "/", "\\", "*", "_"]
	var out := source
	var changes := _rng.randi_range(1, 3)

	for _i in range(changes):
		if out.length() <= 4:
			break
		var idx := _rng.randi_range(2, out.length() - 2)
		if out.substr(idx, 1) == " ":
			continue
		out = out.substr(0, idx) + chars[_rng.randi_range(0, chars.size() - 1)] + out.substr(idx + 1)

	return out

# -------------------------
# FADE
# -------------------------
func _set_fade_alpha(a: float) -> void:
	var c := fade_rect.color
	c.a = a
	fade_rect.color = c
