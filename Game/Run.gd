# res://Game/Run.gd
extends Node

var depth: int = 1
var null_ready: bool = true

# --- PLAYER stats ---
var move_speed_mult: float = 1.0
var air_speed_mult: float = 1.0

var jump_enabled: bool = false
var jump_velocity: float = 9.5   # salto più alto di default

# volo (secondi rimanenti)
var flight_time_left: float = 0.0

# dash
var dash_enabled: bool = false

# --- PICKUP ---
var pickup_radius: float = 2.0

# --- NULL stats ---
var null_bounces: int = 0
var null_speed_mult: float = 1.0
var null_range_mult: float = 1.0

# --- ENEMIES ---
var turret_interval_mult: float = 1.0

# UI
var last_perk_title: String = ""
var last_perk_desc: String = ""

# pool
var perk_pool: Array[String] = [
	"JUMP_UNLOCK",
	"JUMP_POWER",
	"LONG_JUMP",
	"FLIGHT_BURST",
	"SPRINT",
	"MAGNET_PICKUP",
	"NULL_BOUNCE",
	"NULL_SPEED",
	"NULL_RANGE",
	"SLOW_TURRETS",
	"DASH_UNLOCK",
]

func reset() -> void:
	depth = 1
	null_ready = true

	move_speed_mult = 1.0
	air_speed_mult = 1.0

	jump_enabled = false
	jump_velocity = 9.5

	flight_time_left = 0.0
	dash_enabled = false

	pickup_radius = 2.0

	null_bounces = 0
	null_speed_mult = 1.0
	null_range_mult = 1.0

	turret_interval_mult = 1.0

	last_perk_title = ""
	last_perk_desc = ""

func grant_random_perk(rng: RandomNumberGenerator) -> void:
	for _i in range(30):
		var id: String = perk_pool[rng.randi_range(0, perk_pool.size() - 1)]
		if _can_take(id):
			_apply(id)
			return
	_apply("NULL_BOUNCE")

func _can_take(id: String) -> bool:
	match id:
		# perk che dipendono dal salto
		"JUMP_POWER", "LONG_JUMP", "FLIGHT_BURST":
			return jump_enabled
		"JUMP_UNLOCK":
			return not jump_enabled

		"DASH_UNLOCK":
			return not dash_enabled

		"NULL_BOUNCE":
			return null_bounces < 3

		"SPRINT":
			return move_speed_mult < 2.0

		"MAGNET_PICKUP":
			return pickup_radius < 6.0

		"NULL_SPEED":
			return null_speed_mult < 2.0
		"NULL_RANGE":
			return null_range_mult < 2.5

		"SLOW_TURRETS":
			return turret_interval_mult < 2.0
		_:
			return true

func _apply(id: String) -> void:
	match id:
		"JUMP_UNLOCK":
			jump_enabled = true
			last_perk_title = "JUMP"
			last_perk_desc = "Ora puoi saltare."

		"JUMP_POWER":
			jump_velocity = min(jump_velocity + 1.0, 12.0)
			last_perk_title = "HIGH JUMP"
			last_perk_desc = "Salto più alto (+1)."

		"LONG_JUMP":
			air_speed_mult = min(air_speed_mult + 0.25, 2.0)
			last_perk_title = "LONG JUMP"
			last_perk_desc = "Controllo/velocità in aria +25%."

		"FLIGHT_BURST":
			flight_time_left += 5.0
			last_perk_title = "FLIGHT +5s"
			last_perk_desc = "Volo per 5 secondi (si somma)."

		"SPRINT":
			move_speed_mult = min(move_speed_mult + 0.15, 2.0)
			last_perk_title = "SPRINT +15%"
			last_perk_desc = "Movimento più veloce."

		"MAGNET_PICKUP":
			pickup_radius = min(pickup_radius + 1.0, 6.0)
			last_perk_title = "MAGNET +1m"
			last_perk_desc = "Pickup più facile (raggio +1m)."

		"NULL_BOUNCE":
			null_bounces = min(null_bounces + 1, 3)
			last_perk_title = "BOUNCE +1"
			last_perk_desc = "Null rimbalza +1 volta."

		"NULL_SPEED":
			null_speed_mult = min(null_speed_mult + 0.15, 2.0)
			last_perk_title = "NULL SPEED +15%"
			last_perk_desc = "Proiettile più veloce."

		"NULL_RANGE":
			null_range_mult = min(null_range_mult + 0.25, 2.5)
			last_perk_title = "NULL RANGE +25%"
			last_perk_desc = "Proiettile vola più lontano."

		"SLOW_TURRETS":
			turret_interval_mult = min(turret_interval_mult + 0.15, 2.0)
			last_perk_title = "SLOW TURRETS"
			last_perk_desc = "Turret più lenti."

		"DASH_UNLOCK":
			dash_enabled = true
			last_perk_title = "DASH"
			last_perk_desc = "Scatto con Shift."

		_:
			last_perk_title = "UNKNOWN"
			last_perk_desc = "Perk non definito."
