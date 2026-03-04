extends Area3D

@export var shop_scene_path: String = "res://Shop/shop.tscn"
@export var prompt_path: NodePath = NodePath("PromptE")

var _player_in_range := false
var _is_loading := false
@onready var _prompt: Node = get_node_or_null(prompt_path)

func _ready() -> void:
	# Prompt nascosto all'avvio
	if _prompt:
		_prompt.visible = false

	# Collega i segnali se non lo hai già fatto da editor
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

func _process(_delta: float) -> void:
	if _is_loading:
		return

	if _player_in_range and Input.is_action_just_pressed("interact"):
		_is_loading = true
		if _prompt:
			_prompt.visible = false

		# ✅ forza rigenerazione offerte ad ogni visita
		Run.shop_offers.clear()

		get_tree().change_scene_to_file(shop_scene_path)

func _on_body_entered(body: Node) -> void:
	# Adatta il check al tuo player:
	# Opzione A: group "player"
	# Opzione B: nome nodo "Player"
	if body.is_in_group("player") or body.name == "Player":
		_player_in_range = true
		if _prompt:
			_prompt.visible = true

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player") or body.name == "Player":
		_player_in_range = false
		if _prompt:
			_prompt.visible = false
