# res://UI/HUD.gd
extends Control

@onready var status_label: Label = $StatusLabel
@onready var depth_label: Label = $DepthLabel

@onready var crosshair: Control = $Crosshair
@onready var crosshair_tex: TextureRect = $Crosshair/CrosshairTex

@onready var perk_label: Label = $PerkLabel
@onready var perk_timer: Timer = $PerkTimer

var base_size: Vector2 = Vector2(18, 18)
var not_ready_size: Vector2 = Vector2(10, 10)

func _ready() -> void:
	# consigliato: HUD non deve “mangiare” input mouse
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	Signals.null_ready_changed.connect(_on_null_ready_changed)
	Signals.depth_changed.connect(_on_depth_changed)
	Signals.perk_granted.connect(_on_perk_granted)

	perk_timer.timeout.connect(_on_perk_timeout)

	_update_all()

func _update_all() -> void:
	_on_null_ready_changed(Run.null_ready)
	_on_depth_changed(Run.depth)
	perk_label.visible = false

func _on_null_ready_changed(is_ready: bool) -> void:
	status_label.text = "NULL: READY" if is_ready else "NULL: IS NOT READY"
	_set_crosshair_ready(is_ready)

func _on_depth_changed(d: int) -> void:
	depth_label.text = "DEPTH: %d" % d

# ---- Perk popup ----
func _on_perk_granted(title: String, description: String) -> void:
	perk_label.text = "%s\n%s" % [title, description]
	perk_label.visible = true
	perk_timer.start() # usa Wait Time impostato nel Timer

func _on_perk_timeout() -> void:
	perk_label.visible = false

# ---- Crosshair API ----
func _set_crosshair_ready(is_ready: bool) -> void:
	var crosshair_size := base_size if is_ready else not_ready_size
	_set_crosshair_size(crosshair_size)

func _set_crosshair_size(crosshair_size: Vector2) -> void:
	crosshair_tex.custom_minimum_size = crosshair_size
	crosshair_tex.size = crosshair_size

func set_crosshair_visible(v: bool) -> void:
	crosshair.visible = v

func set_crosshair_texture(tex: Texture2D) -> void:
	crosshair_tex.texture = tex
