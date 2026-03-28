# res://Game/Signals.gd
extends Node

@warning_ignore("unused_signal")
signal money_changed(money: int)

# Requests (input -> Game)
@warning_ignore("unused_signal")
signal request_shoot(origin: Vector3, direction: Vector3, size_mult: float)
@warning_ignore("unused_signal")
signal request_pickup
@warning_ignore("unused_signal")
signal request_pull_to_hand
@warning_ignore("unused_signal")
signal request_swap
@warning_ignore("unused_signal")
signal request_recovery_start
@warning_ignore("unused_signal")
signal request_recovery_stop

# Combat / run
@warning_ignore("unused_signal")
signal enemy_killed(enemy: Node)
@warning_ignore("unused_signal")
signal enemy_hit_feedback(enemy: Node, killed: bool)
@warning_ignore("unused_signal")
signal request_force_drop_null(pos: Vector3)

@warning_ignore("unused_signal")
signal player_hit(knockback_dir: Vector3)
@warning_ignore("unused_signal")
signal player_damage_feedback(knockback_dir: Vector3, fatal: bool)
@warning_ignore("unused_signal")
signal player_died()

# Null state
@warning_ignore("unused_signal")
signal null_ready_changed(is_ready: bool)
@warning_ignore("unused_signal")
signal null_dropped(pos: Vector3)
@warning_ignore("unused_signal")
signal null_recovered(pos: Vector3)

# UI / progression
@warning_ignore("unused_signal")
signal depth_changed(depth: int)
@warning_ignore("unused_signal")
signal perk_granted(title: String, description: String)

# Survival UI
@warning_ignore("unused_signal")
signal survival_mode_changed(active: bool)
@warning_ignore("unused_signal")
signal recovery_mode_changed(active: bool)

@warning_ignore("unused_signal")
signal downed_self_recovery_changed(active: bool, remaining: float, total: float)
