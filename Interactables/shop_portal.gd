# res://Interactables/shop_portal.gd
extends Area3D

@export var shop_scene_path: String = "res://Shop/Shop.tscn"

var _used: bool = false

func _ready() -> void:
	body_entered.connect(_on_enter)

func _on_enter(body: Node) -> void:
	if _used:
		return
	if not body.is_in_group("player"):
		return

	_used = true

	# In shop vogliamo mouse libero
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Forza rigenerazione offerte ad ogni visita
	Run.shop_offers.clear()

	# Cambia scena deferred (siamo in callback fisica)
	call_deferred("_go_shop")

func _go_shop() -> void:
	get_tree().change_scene_to_file(shop_scene_path)
