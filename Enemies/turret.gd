# res://Enemies/Turret.gd
extends StaticBody3D

@export var fire_interval: float = 1.6

var target: Node3D = null
var bullet_scene: PackedScene = null
var timer: float = 0.0

func set_target(t: Node3D) -> void:
	target = t

func set_bullet_scene(ps: PackedScene) -> void:
	bullet_scene = ps

func _physics_process(delta: float) -> void:
	if target == null or bullet_scene == null:
		return

	timer += delta
	if timer < fire_interval:
		return
	timer = 0.0

	var dir := (target.global_position - global_position).normalized()
	dir.y = 0.0
	dir = dir.normalized()

	var b := bullet_scene.instantiate() as Node3D
	get_tree().current_scene.get_node("World").add_child(b)

	# spawn bullet leggermente avanti/sopra
	var origin := global_position + Vector3(0, 0.8, 0) + dir * 0.6
	if b.has_method("fire"):
		b.fire(origin, dir, 18.0)
