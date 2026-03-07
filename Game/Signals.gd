# res://Game/Signals.gd
extends Node

signal money_changed(money: int)

# Requests (input -> Game)
signal request_shoot(origin: Vector3, direction: Vector3, size_mult: float)
signal request_pickup
signal request_pull_to_hand
signal request_swap
signal request_recovery_start
signal request_recovery_stop

# Combat / run
signal enemy_killed(enemy: Node)

signal player_hit(knockback_dir: Vector3)
signal player_died()

# Null state
signal null_ready_changed(is_ready: bool)
signal null_dropped(pos: Vector3)

# UI / progression
signal depth_changed(depth: int)
signal perk_granted(title: String, description: String)

# Survival UI
signal survival_mode_changed(active: bool)
signal recovery_mode_changed(active: bool)
