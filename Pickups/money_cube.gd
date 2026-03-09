extends Area3D

@export var value: int = 1

@onready var pickup_sfx: AudioStreamPlayer3D = $AudioStreamPlayer3D

var _collected: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if _collected:
		return
	if not body.is_in_group("player"):
		return

	_collected = true
	Run.add_money(value)

	set_deferred("monitoring", false)
	set_deferred("monitorable", false)

	if has_node("CollisionShape3D"):
		$CollisionShape3D.set_deferred("disabled", true)

	if has_node("MoneySprite"):
		$MoneySprite.visible = false

	if pickup_sfx and pickup_sfx.stream:
		pickup_sfx.play()
		await pickup_sfx.finished

	queue_free()
