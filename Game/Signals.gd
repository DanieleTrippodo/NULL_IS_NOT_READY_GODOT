# res://Game/Signals.gd
extends Node

signal player_died
signal enemy_killed(enemy)

signal null_ready_changed(is_ready: bool)
signal depth_changed(depth: int)

signal request_shoot(origin: Vector3, direction: Vector3)
signal request_pickup

signal perk_granted(title: String, description: String)
