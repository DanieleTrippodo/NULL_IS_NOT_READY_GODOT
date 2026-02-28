# res://Game/Signals.gd
extends Node

signal request_shoot(origin: Vector3, direction: Vector3, size_mult: float)
signal request_pickup

signal enemy_killed(enemy: Node)
signal player_died()

signal null_ready_changed(is_ready: bool)
signal depth_changed(depth: int)

signal perk_granted(title: String, description: String)
