# res://UI/hud.gd
extends Control

@onready var status_label: Label = $StatusLabel
@onready var depth_label: Label = $DepthLabel
@onready var crosshair_tex: TextureRect = $Crosshair/CrosshairTex

@onready var perk_label: Label = $PerkLabel
@onready var perk_timer: Timer = $PerkTimer

@onready var fade_rect: ColorRect = $FadeRect

var base_crosshair_size: Vector2 = Vector2(32, 32)
var not_ready_size: Vector2 = Vector2(22, 22)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	Signals.null_ready_changed.connect(_on_null_ready_changed)
	Signals.depth_changed.connect(_on_depth_changed)
	Signals.perk_granted.connect(_on_perk_granted)

	# evita doppie connessioni, ma garantisce che funzioni
	var cb := Callable(self, "_on_perk_timer_timeout")
	if not perk_timer.timeout.is_connected(cb):
		perk_timer.timeout.connect(cb)

	perk_label.visible = false

	# fade init
	fade_rect.visible = false
	_set_fade_alpha(0.0)

	_update_all()

func _update_all() -> void:
	_on_null_ready_changed(Run.null_ready)
	_on_depth_changed(Run.depth)

func _on_null_ready_changed(is_ready: bool) -> void:
	status_label.text = "NULL: READY" if is_ready else "NULL: IS NOT READY"
	var s: Vector2 = base_crosshair_size if is_ready else not_ready_size
	crosshair_tex.custom_minimum_size = s
	crosshair_tex.size = s

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

# fade to black
func fade_out(duration: float = 0.25) -> void:
	fade_rect.visible = true
	var tw := create_tween()
	var c := fade_rect.color
	c.a = 1.0
	tw.tween_property(fade_rect, "color", c, duration)
	await tw.finished

# fade from black
func fade_in(duration: float = 0.25) -> void:
	var tw := create_tween()
	var c := fade_rect.color
	c.a = 0.0
	tw.tween_property(fade_rect, "color", c, duration)
	await tw.finished
	fade_rect.visible = false
