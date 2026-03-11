extends RefCounted
class_name UpdatesDB

enum UpdateRarity {
	COMMON,
	RARE,
	EPIC
}

const UPDATE_IDS: Array[String] = [
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

const DATA := {
	"NULL_BOUNCE": {
		"title": "NULL BOUNCE",
		"desc": "Il NULL rimbalza 1 volta.",
		"rarity": UpdateRarity.COMMON,
		"base_price_min": 2,
		"base_price_max": 4,
		"rotatable": true,
		"size": Vector2i(2, 1),
		"cells": [Vector2i(0, 0), Vector2i(1, 0)],
		"tradeoff_desc": "",
		"icon_path": "res://Art/Cards/Icons/NULL_BOUNCE.png"
	},

	"BOUNCE_STACK": {
		"title": "BOUNCE STACK",
		"desc": "+1 rimbalzo (stackabile).",
		"rarity": UpdateRarity.RARE,
		"base_price_min": 5,
		"base_price_max": 8,
		"rotatable": true,
		"size": Vector2i(2, 2),
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)],
		"tradeoff_desc": "Occupa più spazio di un bounce base.",
		"icon_path": "res://Art/Cards/Icons/BOUNCE_STACK.png"
	},

	"JUMP_UNLOCK": {
		"title": "JUMP UNLOCK",
		"desc": "Ora puoi saltare (legacy/compatibilità).",
		"rarity": UpdateRarity.COMMON,
		"base_price_min": 2,
		"base_price_max": 4,
		"rotatable": false,
		"size": Vector2i(1, 1),
		"cells": [Vector2i(0, 0)],
		"tradeoff_desc": "",
		"icon_path": "res://Art/Cards/Icons/JUMP_UNLOCK.png"
	},

	"JUMP_POWER": {
		"title": "HIGHER JUMP",
		"desc": "Salto più alto.",
		"rarity": UpdateRarity.COMMON,
		"base_price_min": 2,
		"base_price_max": 4,
		"rotatable": true,
		"size": Vector2i(2, 2),
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)],
		"tradeoff_desc": "Forma scomoda ma efficiente.",
		"icon_path": "res://Art/Cards/Icons/JUMP_POWER.png"
	},

	"LONG_JUMP": {
		"title": "LONG JUMP",
		"desc": "Più controllo/velocità in aria.",
		"rarity": UpdateRarity.COMMON,
		"base_price_min": 2,
		"base_price_max": 4,
		"rotatable": true,
		"size": Vector2i(3, 1),
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)],
		"tradeoff_desc": "Allungato, comodo ma richiede spazio lineare.",
		"icon_path": "res://Art/Cards/Icons/LONG_JUMP.png"
	},

	"FLIGHT_BURST": {
		"title": "FLIGHT (5s)",
		"desc": "Vola per 5 secondi (Space).",
		"rarity": UpdateRarity.RARE,
		"base_price_min": 5,
		"base_price_max": 8,
		"rotatable": true,
		"size": Vector2i(2, 3),
		"cells": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 1)],
		"tradeoff_desc": "Potente ma verticale e ingombrante.",
		"icon_path": "res://Art/Cards/Icons/FLIGHT_BURST.png"
	},

	"MAGNET_PICKUP": {
		"title": "MAGNET",
		"desc": "Pickup automatico del NULL vicino.",
		"rarity": UpdateRarity.COMMON,
		"base_price_min": 2,
		"base_price_max": 4,
		"rotatable": false,
		"size": Vector2i(2, 2),
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],
		"tradeoff_desc": "Compatto, ma occupa un blocco pieno.",
		"icon_path": "res://Art/Cards/Icons/MAGNET_PICKUP.png"
	},

	"SPRINT": {
		"title": "SPEED UP",
		"desc": "Velocità movimento +15%.",
		"rarity": UpdateRarity.COMMON,
		"base_price_min": 2,
		"base_price_max": 4,
		"rotatable": true,
		"size": Vector2i(3, 2),
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1)],
		"tradeoff_desc": "Ottimo buff, ma forma un po' antipatica.",
		"icon_path": "res://Art/Cards/Icons/SPRINT.png"
	},

	"PANIC_BOOST": {
		"title": "PANIC BOOST",
		"desc": "+20% velocità quando NULL: NOT READY.",
		"rarity": UpdateRarity.RARE,
		"base_price_min": 5,
		"base_price_max": 8,
		"rotatable": true,
		"size": Vector2i(3, 2),
		"cells": [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 0)],
		"tradeoff_desc": "Forte solo nei momenti di crisi.",
		"icon_path": "res://Art/Cards/Icons/PANIC_BOOST.png"
	},

	"SLOW_TURRETS": {
		"title": "SLOW TURRETS",
		"desc": "Turret sparano più lentamente.",
		"rarity": UpdateRarity.COMMON,
		"base_price_min": 2,
		"base_price_max": 4,
		"rotatable": true,
		"size": Vector2i(2, 3),
		"cells": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 2)],
		"tradeoff_desc": "Buono contro arena dense di turret.",
		"icon_path": "res://Art/Cards/Icons/SLOW_TURRETS.png"
	},

	"NULL_SPEED": {
		"title": "NULL SPEED",
		"desc": "Il NULL vola più veloce.",
		"rarity": UpdateRarity.COMMON,
		"base_price_min": 2,
		"base_price_max": 4,
		"rotatable": true,
		"size": Vector2i(2, 1),
		"cells": [Vector2i(0, 0), Vector2i(1, 0)],
		"tradeoff_desc": "Piccolo e facile da infilare.",
		"icon_path": "res://Art/Cards/Icons/NULL_SPEED.png"
	},

	"NULL_RANGE": {
		"title": "NULL RANGE",
		"desc": "Il NULL va più lontano.",
		"rarity": UpdateRarity.COMMON,
		"base_price_min": 2,
		"base_price_max": 4,
		"rotatable": true,
		"size": Vector2i(3, 1),
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)],
		"tradeoff_desc": "Economico ma lineare.",
		"icon_path": "res://Art/Cards/Icons/NULL_RANGE.png"
	},

	"PIERCE_1": {
		"title": "PIERCE",
		"desc": "Il NULL può uccidere 2 nemici in linea.",
		"rarity": UpdateRarity.RARE,
		"base_price_min": 5,
		"base_price_max": 8,
		"rotatable": true,
		"size": Vector2i(3, 2),
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, 1)],
		"tradeoff_desc": "Danno situazionale, shape poco amichevole.",
		"icon_path": "res://Art/Cards/Icons/PIERCE_1.png"
	},

	"HOMING_NUDGE": {
		"title": "HOMING NUDGE",
		"desc": "Leggera correzione verso il bersaglio vicino.",
		"rarity": UpdateRarity.RARE,
		"base_price_min": 5,
		"base_price_max": 8,
		"rotatable": true,
		"size": Vector2i(2, 3),
		"cells": [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 2)],
		"tradeoff_desc": "Preciso, ma più ingombrante del previsto.",
		"icon_path": "res://Art/Cards/Icons/HOMING_NUDGE.png"
	},

	"DASH_UNLOCK": {
		"title": "DASH UNLOCK",
		"desc": "Scatto rapido con Shift.",
		"rarity": UpdateRarity.EPIC,
		"base_price_min": 9,
		"base_price_max": 14,
		"rotatable": true,
		"size": Vector2i(3, 2),
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1)],
		"tradeoff_desc": "Molto forte, shape a zig-zag.",
		"icon_path": "res://Art/Cards/Icons/DASH_UNLOCK.png"
	},

	"CHARGE_SHOT": {
		"title": "CHARGE SHOT",
		"desc": "Tieni premuto per caricare, rilascia per un NULL più grande.",
		"rarity": UpdateRarity.EPIC,
		"base_price_min": 9,
		"base_price_max": 14,
		"rotatable": true,
		"size": Vector2i(3, 3),
		"cells": [
			Vector2i(1, 0),
			Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1),
			Vector2i(1, 2)
		],
		"tradeoff_desc": "Potente, ma si mangia mezzo cervello. Letteralmente.",
		"icon_path": "res://Art/Cards/Icons/CHARGE_SHOT.png"
	},

	"CHARGE_PLUS": {
		"title": "CHARGE+",
		"desc": "Migliora la carica.",
		"rarity": UpdateRarity.RARE,
		"base_price_min": 5,
		"base_price_max": 8,
		"rotatable": true,
		"size": Vector2i(2, 2),
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)],
		"tradeoff_desc": "Richiede CHARGE SHOT per rendere davvero.",
		"icon_path": "res://Art/Cards/Icons/CHARGE_PLUS.png"
	},

	"PULL_TO_HAND": {
		"title": "PULL TO HAND",
		"desc": "Tieni premuto Interact per richiamare il NULL.",
		"rarity": UpdateRarity.RARE,
		"base_price_min": 5,
		"base_price_max": 8,
		"rotatable": true,
		"size": Vector2i(2, 3),
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2)],
		"tradeoff_desc": "Comodo, ma costoso in spazio verticale.",
		"icon_path": "res://Art/Cards/Icons/PULL_TO_HAND.png"
	},

	"SWAP_WITH_NULL": {
		"title": "SWAP",
		"desc": "Scambia posizione col NULL droppato (Q).",
		"rarity": UpdateRarity.EPIC,
		"base_price_min": 9,
		"base_price_max": 14,
		"rotatable": true,
		"size": Vector2i(3, 2),
		"cells": [Vector2i(0, 0), Vector2i(2, 0), Vector2i(1, 1), Vector2i(2, 1)],
		"tradeoff_desc": "Molto forte, shape asimmetrica e poco comoda.",
		"icon_path": "res://Art/Cards/Icons/SWAP_WITH_NULL.png"
	},

	"DROP_SHOCKWAVE": {
		"title": "DROP SHOCKWAVE",
		"desc": "Se missi, il drop respinge i chaser vicini.",
		"rarity": UpdateRarity.RARE,
		"base_price_min": 5,
		"base_price_max": 8,
		"rotatable": true,
		"size": Vector2i(3, 3),
		"cells": [
			Vector2i(1, 0),
			Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1),
			Vector2i(1, 2)
		],
		"tradeoff_desc": "Situazionale ma salva run.",
		"icon_path": "res://Art/Cards/Icons/DROP_SHOCKWAVE.png"
	},

	"SLOWMO_RECOVERY": {
		"title": "SLOWMO RECOVERY",
		"desc": "Rallenta il tempo quando il NULL è a terra.",
		"rarity": UpdateRarity.RARE,
		"base_price_min": 5,
		"base_price_max": 8,
		"rotatable": false,
		"size": Vector2i(2, 2),
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)],
		"tradeoff_desc": "Difensivo, shape compatta.",
		"icon_path": "res://Art/Cards/Icons/SLOWMO_RECOVERY.png"
	}
}

static func has_update(id: String) -> bool:
	return DATA.has(id)

static func get_all_ids() -> Array[String]:
	return UPDATE_IDS.duplicate()

static func get_data(id: String) -> Dictionary:
	if not DATA.has(id):
		return {}
	return (DATA[id] as Dictionary).duplicate(true)

static func get_title(id: String) -> String:
	if not DATA.has(id):
		return id
	return str(DATA[id].get("title", id))

static func get_desc(id: String) -> String:
	if not DATA.has(id):
		return ""
	return str(DATA[id].get("desc", ""))

static func get_tradeoff_desc(id: String) -> String:
	if not DATA.has(id):
		return ""
	return str(DATA[id].get("tradeoff_desc", ""))

static func get_rarity(id: String) -> int:
	if not DATA.has(id):
		return UpdateRarity.COMMON
	return int(DATA[id].get("rarity", UpdateRarity.COMMON))

static func is_rotatable(id: String) -> bool:
	if not DATA.has(id):
		return false
	return bool(DATA[id].get("rotatable", false))

static func get_size(id: String) -> Vector2i:
	if not DATA.has(id):
		return Vector2i.ONE
	return DATA[id].get("size", Vector2i.ONE)

static func get_cells(id: String) -> Array:
	if not DATA.has(id):
		return [Vector2i.ZERO]
	return (DATA[id].get("cells", [Vector2i.ZERO]) as Array).duplicate(true)

static func get_icon_path(id: String) -> String:
	if DATA.has(id):
		var specific := str(DATA[id].get("icon_path", ""))
		if specific != "" and ResourceLoader.exists(specific):
			return specific

	var fallback_specific := "res://Art/Cards/Icons/%s.png" % id
	if ResourceLoader.exists(fallback_specific):
		return fallback_specific

	return "res://Art/Cards/Icons/icon_base.png"

static func rarity_name(r: int) -> String:
	match r:
		UpdateRarity.COMMON:
			return "COMMON"
		UpdateRarity.RARE:
			return "RARE"
		UpdateRarity.EPIC:
			return "EPIC"
		_:
			return "COMMON"

static func roll_price_for_id(id: String, depth: int, rng: RandomNumberGenerator) -> int:
	if not DATA.has(id):
		return 3

	var min_price := int(DATA[id].get("base_price_min", 2))
	var max_price := int(DATA[id].get("base_price_max", 4))
	var base := rng.randi_range(min_price, max_price)

	var mult := 1.0 + float(max(depth - 1, 0)) * 0.12
	mult = clamp(mult, 1.0, 3.5)

	return int(round(base * mult))
