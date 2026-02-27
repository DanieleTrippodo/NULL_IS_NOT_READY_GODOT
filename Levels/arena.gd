extends Node3D

@onready var spawn_points: Node3D = $SpawnPoints

func get_spawn_points() -> Array[Marker3D]:
	var out: Array[Marker3D] = []
	for c in spawn_points.get_children():
		if c is Marker3D:
			out.append(c)
	return out
