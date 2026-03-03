# res://Game/Run.gd
extends Node

var money: int = 0

# Per gestire cambio scena Shop <-> Arena senza resettare la run
var returning_from_shop: bool = false
var spawn_player_random: bool = false

# Offerte generate per questa visita allo shop
var shop_offers: Array = []  # array di Dictionary

var depth: int = 1
var terminal_logs_read: Array[bool] = []
var null_ready: bool = true
var null_dropped: bool = false # true solo quando il NULL è a terra (DROPPED)
var survival_mode: bool = false

# ------------------------------------------------------------
# Perks (stato run)
# ------------------------------------------------------------
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

# ------------------------------------------------------------
# Nuovi perk A (recovery / risk)
# ------------------------------------------------------------
var pull_to_hand: bool = false
var pull_channel_seconds: float = 0.6
var pull_max_distance: float = 14.0
var pull_cancel_move_dist: float = 0.75
var pull_move_mult: float = 0.35

var swap_with_null: bool = false
var swap_cooldown: float = 6.0
var swap_cd_left: float = 0.0
var swap_max_distance: float = 35.0

var panic_boost: bool = false
var panic_speed_mult: float = 1.2

var drop_shockwave: bool = false
var shockwave_radius: float = 6.0
var shockwave_strength: float = 10.0

var slowmo_recovery: bool = false
var slowmo_scale: float = 0.85

# ------------------------------------------------------------
# Nuovi perk B (shot modifiers)
# ------------------------------------------------------------
var null_pierce: int = 0 # 1 = uccide 2 nemici in linea (pierce 1)

var homing_nudge: bool = false
var homing_max_angle_deg: float = 6.0
var homing_turn_speed: float = 10.0 # più alto = correzione più rapida

var max_null_bounces: int = 3

# ------------------------------------------------------------
# Perk feedback
# ------------------------------------------------------------
var last_perk_title: String = ""
var last_perk_desc: String = ""

var perk_pool: Array[String] = [
	"NULL_BOUNCE",
	"BOUNCE_STACK",

	"JUMP_UNLOCK",
	"JUMP_POWER",
	"LONG_JUMP",
	"FLIGHT_BURST",

	"MAGNET_PICKUP",
	"SPRINT",
	"PANIC_BOOST",

	"SLOW_TURRETS",

	"NULL_SPEED",
	"NULL_RANGE",
	"PIERCE_1",
	"HOMING_NUDGE",

	"DASH_UNLOCK",

	"CHARGE_SHOT",
	"CHARGE_PLUS",

	"PULL_TO_HAND",
	"SWAP_WITH_NULL",
	"DROP_SHOCKWAVE",
	"SLOWMO_RECOVERY"
]

func _ready() -> void:
	# Mantieni Run.null_ready e Run.null_dropped coerenti con i segnali.
	var cb1 := Callable(self, "_on_null_ready_changed")
	if not Signals.null_ready_changed.is_connected(cb1):
		Signals.null_ready_changed.connect(cb1)

	var cb2 := Callable(self, "_on_null_dropped")
	if not Signals.null_dropped.is_connected(cb2):
		Signals.null_dropped.connect(cb2)

func _on_null_ready_changed(is_ready: bool) -> void:
	null_ready = is_ready
	if is_ready:
		null_dropped = false

func _on_null_dropped(_pos: Vector3) -> void:
	null_dropped = true

func add_money(v: int) -> void:
	money += max(0, v)
	if Signals.has_signal("money_changed"):
		Signals.money_changed.emit(money)

func spend_money(v: int) -> bool:
	if v <= 0:
		return true
	if money < v:
		return false
	money -= v
	if Signals.has_signal("money_changed"):
		Signals.money_changed.emit(money)
	return true


func reset() -> void:
	
	money = 0
	returning_from_shop = false
	spawn_player_random = false
	shop_offers.clear()
	terminal_logs_read.clear()
	
	survival_mode = false
	depth = 1
	null_ready = true
	null_dropped = false

	null_bounces = 0

	jump_enabled = false
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

	pull_to_hand = false
	swap_with_null = false
	swap_cd_left = 0.0
	panic_boost = false
	drop_shockwave = false
	slowmo_recovery = false

	null_pierce = 0
	homing_nudge = false

	last_perk_title = ""
	last_perk_desc = ""
	terminal_logs_read.clear()

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
		"BOUNCE_STACK":
			return null_bounces >= 1 and null_bounces < max_null_bounces

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

		"PANIC_BOOST":
			return not panic_boost

		"SLOW_TURRETS":
			return turret_interval_mult > 0.7

		"NULL_SPEED":
			return null_speed_mult < 1.8

		"NULL_RANGE":
			return null_range_mult < 1.8

		"PIERCE_1":
			return null_pierce < 1

		"HOMING_NUDGE":
			return not homing_nudge

		"CHARGE_PLUS":
			return charge_shot_enabled and (charge_shot_seconds > 2.0 or charge_shot_scale < 2.25)

		"PULL_TO_HAND":
			return not pull_to_hand

		"SWAP_WITH_NULL":
			return not swap_with_null

		"DROP_SHOCKWAVE":
			return not drop_shockwave

		"SLOWMO_RECOVERY":
			return not slowmo_recovery

		_:
			return true

func _apply(id: String) -> void:
	match id:
		"NULL_BOUNCE":
			null_bounces = 1
			last_perk_title = "NULL BOUNCE"
			last_perk_desc = "Il NULL rimbalza 1 volta."

		"BOUNCE_STACK":
			null_bounces = min(null_bounces + 1, max_null_bounces)
			last_perk_title = "BOUNCE STACK"
			last_perk_desc = "+1 rimbalzo (max %d)." % max_null_bounces

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

		"PANIC_BOOST":
			panic_boost = true
			last_perk_title = "PANIC BOOST"
			last_perk_desc = "+20% velocità quando NULL: NOT READY."

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

		"PIERCE_1":
			null_pierce = 1
			last_perk_title = "PIERCE"
			last_perk_desc = "Il NULL può uccidere 2 nemici in linea."

		"HOMING_NUDGE":
			homing_nudge = true
			last_perk_title = "HOMING NUDGE"
			last_perk_desc = "Leggera correzione verso il bersaglio vicino."

		"DASH_UNLOCK":
			dash_enabled = true
			last_perk_title = "DASH UNLOCK"
			last_perk_desc = "Scatto rapido con Shift."

		"CHARGE_SHOT":
			charge_shot_enabled = true
			last_perk_title = "CHARGE SHOT"
			last_perk_desc = "Tieni premuto per caricare, rilascia per un NULL più grande."

		"CHARGE_PLUS":
			if charge_shot_seconds > 2.0:
				charge_shot_seconds = max(charge_shot_seconds - 0.5, 2.0)
				last_perk_desc = "Tempo di carica -0.5s (min 2.0s)."
			else:
				charge_shot_scale = min(charge_shot_scale + 0.25, 2.25)
				last_perk_desc = "Colpo caricato più grande (+0.25x)."
			last_perk_title = "CHARGE+"

		"PULL_TO_HAND":
			pull_to_hand = true
			last_perk_title = "PULL TO HAND"
			last_perk_desc = "Tieni premuto Interact per richiamare il NULL (0.6s)."

		"SWAP_WITH_NULL":
			swap_with_null = true
			last_perk_title = "SWAP"
			last_perk_desc = "Scambia posizione col NULL droppato (Q)."

		"DROP_SHOCKWAVE":
			drop_shockwave = true
			last_perk_title = "DROP SHOCKWAVE"
			last_perk_desc = "Se missi, il drop respinge i chaser vicini."

		"SLOWMO_RECOVERY":
			slowmo_recovery = true
			last_perk_title = "SLOWMO RECOVERY"
			last_perk_desc = "Rallenta il tempo quando il NULL è a terra."
