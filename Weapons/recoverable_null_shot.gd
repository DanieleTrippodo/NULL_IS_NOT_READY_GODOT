# res://Weapons/recoverable_null_shot.gd
# Base condivisa dei colpi speciali.
# Non crea più un Null alternativo: quando un colpo deve cadere,
# chiede al controller dell'arena di istanziare il vero null_projectile.tscn.
class_name SpecialNullShotBase
extends Node3D

enum ShotState { ACTIVE, FINISHED }

var shot_state: int = ShotState.ACTIVE

func become_dropped(drop_position: Vector3) -> void:
	if shot_state == ShotState.FINISHED:
		return

	shot_state = ShotState.FINISHED

	# In modalità Null infinito non deve esistere alcun oggetto recuperabile.
	if Run.infinite_enabled and not Run.survival_mode:
		queue_free()
		return

	Signals.request_spawn_dropped_null.emit(drop_position)
	queue_free()

func return_null() -> void:
	if shot_state == ShotState.FINISHED:
		return

	shot_state = ShotState.FINISHED
	Run.null_ready = true
	Run.null_dropped = false
	Signals.null_ready_changed.emit(true)
	queue_free()

func _make_glow_material(color: Color, alpha: float = 1.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(color.r, color.g, color.b, alpha)
	material.emission_enabled = true
	material.emission = color
	material.disable_fog = true
	return material

func _find_enemy_node(collider: Object) -> Node:
	if collider == null or not (collider is Node):
		return null

	var node := collider as Node
	while node != null:
		if node.is_in_group("enemy"):
			return node
		node = node.get_parent()
	return null

func _is_passthrough(collider: Object) -> bool:
	if collider == null or not (collider is Node):
		return false

	var node := collider as Node
	while node != null:
		if node.is_in_group("null_passthrough"):
			return true
		node = node.get_parent()
	return false

func _emit_enemy_kill(enemy: Node) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if Signals.has_signal("enemy_hit_feedback"):
		Signals.enemy_hit_feedback.emit(enemy, true)
	Signals.enemy_killed.emit(enemy)
