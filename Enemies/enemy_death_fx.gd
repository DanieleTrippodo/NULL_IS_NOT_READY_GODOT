extends Node3D

@onready var particles: GPUParticles3D = $GPUParticles3D

func _ready() -> void:
	if particles:
		particles.restart()
		particles.emitting = true

	var wait_time: float = 1.0
	if particles:
		wait_time = particles.lifetime + 0.2

	await get_tree().create_timer(wait_time).timeout
	queue_free()
