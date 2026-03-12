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
	"SLOWMO_RECOVERY",
	"RAM_PATCH"
]

const DATA := {
	"NULL_BOUNCE": {
		"title": "NULL BOUNCE",
		"desc": "Your NULL projectile bounces once.",
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
		"desc": "Adds +1 extra bounce.",
		"rarity": UpdateRarity.RARE,
		"base_price_min": 5,
		"base_price_max": 8,
		"rotatable": true,
		"size": Vector2i(2, 2),
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)],
		"tradeoff_desc": "Takes more space than the base bounce upgrade.",
		"icon_path": "res://Art/Cards/Icons/BOUNCE_STACK.png"
	},

	"JUMP_UNLOCK": {
		"title": "JUMP UNLOCK",
		"desc": "Enables jumping. Kept for legacy compatibility.",
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
		"desc": "Increases jump height.",
		"rarity": UpdateRarity.COMMON,
		"base_price_min": 2,
		"base_price_max": 4,
		"rotatable": true,
		"size": Vector2i(2, 2),
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)],
		"tradeoff_desc": "Efficient, but the shape is awkward.",
		"icon_path": "res://Art/Cards/Icons/JUMP_POWER.png"
	},

	"LONG_JUMP": {
		"title": "LONG JUMP",
		"desc": "Improves air control and aerial speed.",
		"rarity": UpdateRarity.COMMON,
		"base_price_min": 2,
		"base_price_max": 4,
		"rotatable": true,
		"size": Vector2i(3, 1),
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)],
		"tradeoff_desc": "Easy to understand, but needs long horizontal space.",
		"icon_path": "res://Art/Cards/Icons/LONG_JUMP.png"
	},

	"FLIGHT_BURST": {
		"title": "FLIGHT (5s)",
		"desc": "Allows flight for 5 seconds.",
		"rarity": UpdateRarity.RARE,
		"base_price_min": 5,
		"base_price_max": 8,
		"rotatable": true,
		"size": Vector2i(2, 3),
		"cells": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 1)],
		"tradeoff_desc": "Powerful, but tall and space-hungry.",
		"icon_path": "res://Art/Cards/Icons/FLIGHT_BURST.png"
	},

	"MAGNET_PICKUP": {
		"title": "MAGNET",
		"desc": "Automatically picks up nearby NULL drops.",
		"rarity": UpdateRarity.COMMON,
		"base_price_min": 2,
		"base_price_max": 4,
		"rotatable": false,
		"size": Vector2i(2, 2),
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],
		"tradeoff_desc": "Compact, but still consumes a full block.",
		"icon_path": "res://Art/Cards/Icons/MAGNET_PICKUP.png"
	},

	"SPRINT": {
		"title": "SPEED UP",
		"desc": "Increases movement speed by 15%.",
		"rarity": UpdateRarity.COMMON,
		"base_price_min": 2,
		"base_price_max": 4,
		"rotatable": true,
		"size": Vector2i(3, 2),
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1)],
		"tradeoff_desc": "Strong general boost, but awkward to fit.",
		"icon_path": "res://Art/Cards/Icons/SPRINT.png"
	},

	"PANIC_BOOST": {
		"title": "PANIC BOOST",
		"desc": "Gain bonus speed while NULL is not ready.",
		"rarity": UpdateRarity.RARE,
		"base_price_min": 5,
		"base_price_max": 8,
		"rotatable": true,
		"size": Vector2i(3, 2),
		"cells": [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 0)],
		"tradeoff_desc": "Strong under pressure, but useless while stable.",
		"icon_path": "res://Art/Cards/Icons/PANIC_BOOST.png"
	},

	"SLOW_TURRETS": {
		"title": "SLOW TURRETS",
		"desc": "Enemy turrets fire more slowly.",
		"rarity": UpdateRarity.COMMON,
		"base_price_min": 2,
		"base_price_max": 4,
		"rotatable": true,
		"size": Vector2i(2, 3),
		"cells": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 2)],
		"tradeoff_desc": "Great in turret-heavy arenas.",
		"icon_path": "res://Art/Cards/Icons/SLOW_TURRETS.png"
	},

	"NULL_SPEED": {
		"title": "NULL SPEED",
		"desc": "Makes the NULL projectile travel faster.",
		"rarity": UpdateRarity.COMMON,
		"base_price_min": 2,
		"base_price_max": 4,
		"rotatable": true,
		"size": Vector2i(2, 1),
		"cells": [Vector2i(0, 0), Vector2i(1, 0)],
		"tradeoff_desc": "Small and easy to fit.",
		"icon_path": "res://Art/Cards/Icons/NULL_SPEED.png"
	},

	"NULL_RANGE": {
		"title": "NULL RANGE",
		"desc": "Increases NULL projectile travel distance.",
		"rarity": UpdateRarity.COMMON,
		"base_price_min": 2,
		"base_price_max": 4,
		"rotatable": true,
		"size": Vector2i(3, 1),
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)],
		"tradeoff_desc": "Cheap, but wants a long line of free space.",
		"icon_path": "res://Art/Cards/Icons/NULL_RANGE.png"
	},

	"PIERCE_1": {
		"title": "PIERCE",
		"desc": "Lets NULL kill two enemies in a line.",
		"rarity": UpdateRarity.RARE,
		"base_price_min": 5,
		"base_price_max": 8,
		"rotatable": true,
		"size": Vector2i(3, 2),
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, 1)],
		"tradeoff_desc": "Situational damage, awkward shape.",
		"icon_path": "res://Art/Cards/Icons/PIERCE_1.png"
	},

	"HOMING_NUDGE": {
		"title": "HOMING NUDGE",
		"desc": "Adds slight target correction to NULL.",
		"rarity": UpdateRarity.RARE,
		"base_price_min": 5,
		"base_price_max": 8,
		"rotatable": true,
		"size": Vector2i(2, 3),
		"cells": [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 2)],
		"tradeoff_desc": "Helpful, but bulkier than it looks.",
		"icon_path": "res://Art/Cards/Icons/HOMING_NUDGE.png"
	},

	"DASH_UNLOCK": {
		"title": "DASH UNLOCK",
		"desc": "Unlocks dash movement.",
		"rarity": UpdateRarity.EPIC,
		"base_price_min": 9,
		"base_price_max": 14,
		"rotatable": true,
		"size": Vector2i(3, 2),
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1)],
		"tradeoff_desc": "Very strong, but the zig-zag shape is awkward.",
		"icon_path": "res://Art/Cards/Icons/DASH_UNLOCK.png"
	},

	"CHARGE_SHOT": {
		"title": "CHARGE SHOT",
		"desc": "Hold the shot to fire a larger charged NULL.",
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
		"tradeoff_desc": "Extremely strong, but expensive in both money and space.",
		"icon_path": "res://Art/Cards/Icons/CHARGE_SHOT.png"
	},

	"CHARGE_PLUS": {
		"title": "CHARGE+",
		"desc": "Improves charged shots.",
		"rarity": UpdateRarity.RARE,
		"base_price_min": 5,
		"base_price_max": 8,
		"rotatable": true,
		"size": Vector2i(2, 2),
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)],
		"tradeoff_desc": "Only shines if you already use CHARGE SHOT.",
		"icon_path": "res://Art/Cards/Icons/CHARGE_PLUS.png"
	},

	"PULL_TO_HAND": {
		"title": "PULL TO HAND",
		"desc": "Hold interact to pull NULL back to your hand.",
		"rarity": UpdateRarity.RARE,
		"base_price_min": 5,
		"base_price_max": 8,
		"rotatable": true,
		"size": Vector2i(2, 3),
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2)],
		"tradeoff_desc": "Very useful, but vertical and awkward to place.",
		"icon_path": "res://Art/Cards/Icons/PULL_TO_HAND.png"
	},

	"SWAP_WITH_NULL": {
		"title": "SWAP",
		"desc": "Swap positions with a dropped NULL.",
		"rarity": UpdateRarity.EPIC,
		"base_price_min": 9,
		"base_price_max": 14,
		"rotatable": true,
		"size": Vector2i(3, 2),
		"cells": [Vector2i(0, 0), Vector2i(2, 0), Vector2i(1, 1), Vector2i(2, 1)],
		"tradeoff_desc": "Very strong repositioning tool, but messy to fit.",
		"icon_path": "res://Art/Cards/Icons/SWAP_WITH_NULL.png"
	},

	"DROP_SHOCKWAVE": {
		"title": "DROP SHOCKWAVE",
		"desc": "Dropped NULL emits a shockwave on miss.",
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
		"tradeoff_desc": "Situational, but can save a run.",
		"icon_path": "res://Art/Cards/Icons/DROP_SHOCKWAVE.png"
	},

	"SLOWMO_RECOVERY": {
		"title": "SLOWMO RECOVERY",
		"desc": "Slows time while NULL is on the ground.",
		"rarity": UpdateRarity.RARE,
		"base_price_min": 5,
		"base_price_max": 8,
		"rotatable": false,
		"size": Vector2i(2, 2),
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)],
		"tradeoff_desc": "Defensive and compact.",
		"icon_path": "res://Art/Cards/Icons/SLOWMO_RECOVERY.png"
	},

	"RAM_PATCH": {
		"title": "RAM PATCH",
		"desc": "Adds +1 row and +1 column to your R.A.M. grid.",
		"rarity": UpdateRarity.EPIC,
		"base_price_min": 11,
		"base_price_max": 16,
		"rotatable": true,
		"size": Vector2i(2, 3),
		"cells": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 2)],
		"tradeoff_desc": "Extremely convenient, so the shape is intentionally awkward and the price is high.",
		"icon_path": "res://Art/Cards/Icons/RAM_PATCH.png"
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
		var specific: String = str(DATA[id].get("icon_path", ""))
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

	var min_price: int = int(DATA[id].get("base_price_min", 2))
	var max_price: int = int(DATA[id].get("base_price_max", 4))
	var base: int = rng.randi_range(min_price, max_price)

	var mult: float = 1.0 + float(max(depth - 1, 0)) * 0.12
	mult = clamp(mult, 1.0, 3.5)

	return int(round(base * mult))
