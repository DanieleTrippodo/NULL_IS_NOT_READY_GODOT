extends "res://Levels/arena.gd"

@export var allowed_enemy_types := PackedStringArray(["turret", "drifter_turret"])
@export var enemy_spawn_scatter_radius: float = 0.75

func get_allowed_enemy_types() -> PackedStringArray:
	return allowed_enemy_types

func get_enemy_spawn_scatter_radius() -> float:
	return enemy_spawn_scatter_radius
