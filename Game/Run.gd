# res://Game/Run.gd
extends Node

var depth: int = 1
var null_ready: bool = true

# --- perk state ---
var null_bounces: int = 0
var pickup_radius: float = 2.0

var move_speed_mult: float = 1.0

var jump_enabled: bool = false
var jump_velocity: float = 7.0
var air_speed_mult: float = 1.0

var flight_time_left: float = 0.0

var turret_interval_mult: float = 1.0

# ultimo perk ottenuto (per HUD)
var last_perk_title: String = ""
var last_perk_desc: String = ""

# pool (stringhe per evitare Variant)
var perk_pool: Array[String] = [
	"NULL_BOUNCE",
	"JUMP_UNLOCK",
	"LONG_JUMP",
	"FLIGHT_BURST",
	"MAGNET_PICKUP",
	"SPRINT",
	"SLOW_TURRETS"
]

func reset() -> void:
	depth = 1
	null_ready = true

	null_bounces = 0
	pickup_radius = 2.0

	move_speed_mult = 1.0

	jump_enabled = false
	jump_velocity = 7.0
	air_speed_mult = 1.0

	flight_time_left = 0.0

	turret_interval_mult = 1.0

	last_perk_title = ""
	last_perk_desc = ""

func grant_random_perk(rng: RandomNumberGenerator) -> void:
	# prova più volte finché non trova un perk “utile”
	for _i: int in range(20):
		var id: String = perk_pool[rng.randi_range(0, perk_pool.size() - 1)]
		if _can_take(id):
			_apply(id)
			return

	# fallback
	_apply("NULL_BOUNCE")

func _can_take(id: String) -> bool:
	match id:
		"JUMP_UNLOCK":
			return not jump_enabled
		"NULL_BOUNCE":
			return null_bounces < 3
		"LONG_JUMP":
			return air_speed_mult < 2.0
		"MAGNET_PICKUP":
			return pickup_radius < 6.0
		"SPRINT":
			return move_speed_mult < 2.0
		"SLOW_TURRETS":
			return turret_interval_mult < 2.0
		"FLIGHT_BURST":
			return true
		_:
			return true

func _apply(id: String) -> void:
	match id:
		"NULL_BOUNCE":
			null_bounces = min(null_bounces + 1, 3)
			last_perk_title = "NULL BOUNCE +1"
			last_perk_desc = "Il proiettile rimbalza +1 volta (max 3)."

		"JUMP_UNLOCK":
			jump_enabled = true
			last_perk_title = "JUMP UNLOCK"
			last_perk_desc = "Ora puoi saltare."

		"LONG_JUMP":
			air_speed_mult = min(air_speed_mult + 0.25, 2.0)
			last_perk_title = "LONG JUMP"
			last_perk_desc = "Velocità in aria +25% (stackabile)."

		"FLIGHT_BURST":
			flight_time_left += 3.0
			last_perk_title = "FLIGHT BURST"
			last_perk_desc = "+3s di volo (si somma)."

		"MAGNET_PICKUP":
			pickup_radius = min(pickup_radius + 1.0, 6.0)
			last_perk_title = "MAGNET PICKUP"
			last_perk_desc = "Raggio pickup +1m (max 6m)."

		"SPRINT":
			move_speed_mult = min(move_speed_mult + 0.15, 2.0)
			last_perk_title = "SPRINT"
			last_perk_desc = "Velocità movimento +15% (stackabile)."

		"SLOW_TURRETS":
			turret_interval_mult = min(turret_interval_mult + 0.15, 2.0)
			last_perk_title = "SLOW TURRETS"
			last_perk_desc = "Turret più lenti (+15% intervallo)."

		_:
			last_perk_title = "UNKNOWN"
			last_perk_desc = "Perk non definito."
