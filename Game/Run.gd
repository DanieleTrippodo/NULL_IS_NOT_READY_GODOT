# res://Game/Run.gd
extends Node

var depth: int = 1
var null_ready: bool = true

# --- perk state ---
var null_bounces: int = 0
var pickup_radius: float = 2.0

var move_speed_mult: float = 1.0
var air_speed_mult: float = 1.0

var jump_enabled: bool = false
var jump_velocity: float = 7.0
var flight_time_left: float = 0.0

var turret_interval_mult: float = 1.0

# NEW
var null_speed_mult: float = 1.0
var null_range_mult: float = 1.0
var dash_enabled: bool = false

var last_perk_title: String = ""
var last_perk_desc: String = ""

var perk_pool: Array[String] = [
	"NULL_BOUNCE",
	"JUMP_UNLOCK",
	"JUMP_POWER",
	"LONG_JUMP",
	"FLIGHT_BURST",
	"MAGNET_PICKUP",
	"SPRINT",
	"SLOW_TURRETS",
	"NULL_SPEED",
	"NULL_RANGE",
	"DASH_UNLOCK"
]

func reset() -> void:
	depth = 1
	null_ready = true

	null_bounces = 0
	pickup_radius = 2.0

	move_speed_mult = 1.0
	air_speed_mult = 1.0

	jump_enabled = false
	jump_velocity = 7.0
	flight_time_left = 0.0

	turret_interval_mult = 1.0

	null_speed_mult = 1.0
	null_range_mult = 1.0
	dash_enabled = false

	last_perk_title = ""
	last_perk_desc = ""

func grant_random_perk(rng: RandomNumberGenerator) -> void:
	for _i: int in range(30):
		var id: String = perk_pool[rng.randi_range(0, perk_pool.size() - 1)]
		if _can_take(id):
			_apply(id)
			return
	_apply("NULL_BOUNCE")

func _can_take(id: String) -> bool:
	match id:
		"JUMP_UNLOCK":
			return not jump_enabled
		"DASH_UNLOCK":
			return not dash_enabled

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

		"NULL_SPEED":
			return null_speed_mult < 2.0
		"NULL_RANGE":
			return null_range_mult < 2.5
		"JUMP_POWER":
			return jump_velocity < 12.0

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

		"JUMP_POWER":
			jump_velocity = min(jump_velocity + 1.0, 12.0)
			last_perk_title = "JUMP POWER +1"
			last_perk_desc = "Salto più alto (stackabile)."

		"LONG_JUMP":
			air_speed_mult = min(air_speed_mult + 0.25, 2.0)
			last_perk_title = "LONG JUMP"
			last_perk_desc = "Velocità in aria +25% (stackabile)."

		"FLIGHT_BURST":
			flight_time_left += 5.0
			last_perk_title = "FLIGHT BURST +5s"
			last_perk_desc = "Volo per 5s (si somma)."

		"MAGNET_PICKUP":
			pickup_radius = min(pickup_radius + 1.0, 6.0)
			last_perk_title = "MAGNET PICKUP +1m"
			last_perk_desc = "Raggio pickup +1m (max 6m)."

		"SPRINT":
			move_speed_mult = min(move_speed_mult + 0.15, 2.0)
			last_perk_title = "SPRINT +15%"
			last_perk_desc = "Velocità movimento +15% (stackabile)."

		"SLOW_TURRETS":
			turret_interval_mult = min(turret_interval_mult + 0.15, 2.0)
			last_perk_title = "SLOW TURRETS +15%"
			last_perk_desc = "Turret più lenti (+15% intervallo)."

		"NULL_SPEED":
			null_speed_mult = min(null_speed_mult + 0.15, 2.0)
			last_perk_title = "NULL SPEED +15%"
			last_perk_desc = "Proiettile più veloce (stackabile)."

		"NULL_RANGE":
			null_range_mult = min(null_range_mult + 0.25, 2.5)
			last_perk_title = "NULL RANGE +25%"
			last_perk_desc = "Distanza prima del drop +25% (stackabile)."

		"DASH_UNLOCK":
			dash_enabled = true
			last_perk_title = "DASH UNLOCK"
			last_perk_desc = "Scatto rapido con Shift."

		_:
			last_perk_title = "UNKNOWN"
			last_perk_desc = "Perk non definito."
