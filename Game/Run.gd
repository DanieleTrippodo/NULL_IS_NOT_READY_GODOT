# res://Game/Run.gd
extends Node

var depth: int = 1
var null_ready: bool = true

# Perks (stato run)
var null_bounces: int = 0
var jump_enabled: bool = false
var jump_velocity: float = 7.0
var flight_time_left: float = 0.0

var pickup_magnet: bool = false
var pickup_radius: float = 2.0

var move_speed_mult: float = 1.0
var air_speed_mult: float = 1.0
var turret_interval_mult: float = 1.0
var null_speed_mult: float = 1.0
var null_range_mult: float = 1.0
var dash_enabled: bool = false

# Charge shot perk
var charge_shot_enabled: bool = false
var charge_shot_seconds: float = 3.0
var charge_shot_scale: float = 1.5
var charge_shake_strength: float = 0.05

# Perk feedback
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
	"DASH_UNLOCK",
	"CHARGE_SHOT"
]

func reset() -> void:
	depth = 1
	null_ready = true

	null_bounces = 0

	jump_enabled = false
	# un po' più alto di default
	jump_velocity = 8.0
	flight_time_left = 0.0

	pickup_magnet = false
	pickup_radius = 2.0

	move_speed_mult = 1.0
	air_speed_mult = 1.0
	turret_interval_mult = 1.0
	null_speed_mult = 1.0
	null_range_mult = 1.0
	dash_enabled = false

	charge_shot_enabled = false
	charge_shot_seconds = 3.0
	charge_shot_scale = 1.5
	charge_shake_strength = 0.05

	last_perk_title = ""
	last_perk_desc = ""

func grant_random_perk(rng: RandomNumberGenerator) -> bool:
	var available := []
	for id in perk_pool:
		if _can_take(id):
			available.append(id)

	if available.is_empty():
		return false

	var pick: String = available[rng.randi_range(0, available.size() - 1)]
	_apply(pick)
	return true

func _can_take(id: String) -> bool:
	match id:
		"JUMP_UNLOCK":
			return not jump_enabled
		"DASH_UNLOCK":
			return not dash_enabled
		"CHARGE_SHOT":
			return not charge_shot_enabled

		"NULL_BOUNCE":
			return null_bounces < 1

		# dipendono dal salto: disponibili solo se jump_enabled
		"LONG_JUMP":
			return jump_enabled and air_speed_mult < 2.0
		"JUMP_POWER":
			return jump_enabled and jump_velocity < 12.0

		"FLIGHT_BURST":
			return true

		"MAGNET_PICKUP":
			return not pickup_magnet

		"SPRINT":
			return move_speed_mult < 1.5

		"SLOW_TURRETS":
			return turret_interval_mult > 0.7

		"NULL_SPEED":
			return null_speed_mult < 1.8

		"NULL_RANGE":
			return null_range_mult < 1.8

		_:
			return true

func _apply(id: String) -> void:
	match id:
		"NULL_BOUNCE":
			null_bounces = 1
			last_perk_title = "NULL BOUNCE"
			last_perk_desc = "Il NULL rimbalza 1 volta."

		"JUMP_UNLOCK":
			jump_enabled = true
			last_perk_title = "JUMP UNLOCK"
			last_perk_desc = "Ora puoi saltare (Space)."

		"JUMP_POWER":
			jump_velocity = min(jump_velocity + 2.0, 12.0)
			last_perk_title = "HIGHER JUMP"
			last_perk_desc = "Salto più alto."

		"LONG_JUMP":
			air_speed_mult = min(air_speed_mult + 0.5, 2.0)
			last_perk_title = "LONG JUMP"
			last_perk_desc = "Più controllo/velocità in aria."

		"FLIGHT_BURST":
			flight_time_left = 5.0
			last_perk_title = "FLIGHT (5s)"
			last_perk_desc = "Vola per 5 secondi (Space)."

		"MAGNET_PICKUP":
			pickup_magnet = true
			last_perk_title = "MAGNET"
			last_perk_desc = "Pickup automatico del NULL vicino."

		"SPRINT":
			move_speed_mult = min(move_speed_mult + 0.15, 1.5)
			last_perk_title = "SPEED UP"
			last_perk_desc = "Velocità movimento +15%."

		"SLOW_TURRETS":
			turret_interval_mult = max(turret_interval_mult - 0.1, 0.7)
			last_perk_title = "SLOW TURRETS"
			last_perk_desc = "Turret sparano più lentamente."

		"NULL_SPEED":
			null_speed_mult = min(null_speed_mult + 0.2, 1.8)
			last_perk_title = "NULL SPEED"
			last_perk_desc = "Il NULL vola più veloce."

		"NULL_RANGE":
			null_range_mult = min(null_range_mult + 0.2, 1.8)
			last_perk_title = "NULL RANGE"
			last_perk_desc = "Il NULL va più lontano."

		"DASH_UNLOCK":
			dash_enabled = true
			last_perk_title = "DASH UNLOCK"
			last_perk_desc = "Scatto rapido con Shift."

		"CHARGE_SHOT":
			charge_shot_enabled = true
			last_perk_title = "CHARGE SHOT"
			last_perk_desc = "Tieni premuto per 3s, rilascia per un NULL +50% più grande."
