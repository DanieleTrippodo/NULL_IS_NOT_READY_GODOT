# res://UI/HUD.gd
extends Control

@onready var status_label: Label = $StatusLabel
@onready var depth_label: Label = $DepthLabel

func _ready() -> void:
	Signals.null_ready_changed.connect(_on_null_ready_changed)
	Signals.depth_changed.connect(_on_depth_changed)
	_update_all()

func _update_all() -> void:
	_on_null_ready_changed(Run.null_ready)
	_on_depth_changed(Run.depth)

func _on_null_ready_changed(is_ready: bool) -> void:
	status_label.text = "NULL: READY" if is_ready else "NULL: IS NOT READY"

func _on_depth_changed(d: int) -> void:
	depth_label.text = "DEPTH: %d" % d
