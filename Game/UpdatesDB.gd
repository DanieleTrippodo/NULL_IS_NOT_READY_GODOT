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
	"JUMP_POWER",
	"LONG_JUMP",
	"MAGNET_PICKUP",
	"SPRINT",
	"PANIC_BOOST",
	"SLOW_TURRETS",
	"NULL_SPEED",
	"NULL_RANGE",
	"PIERCE_1",
	"HOMING_NUDGE",
	"DASH_UNLOCK",
	"SLIDE_DODGE",
	"CHARGE_SHOT",
	"PULL_TO_HAND",
	"SLOWMO_RECOVERY",
	"IMPACT_PULSE",
	"THREAD_LOCK",
	"NULL_FREEZE",
	"AUTO_RECALL",
	"RECOVERY_IFRAME",
	"STASIS_FIELD",
	"SECOND_CHANCE",
	"HEAVY_NULL",
	"OVERCLOCK",
	"GROUND_ECHO",
	"RAM_PATCH",
	"INFINITE"
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
		"desc": "Gain a major speed boost while NULL is not ready.",
		"rarity": UpdateRarity.RARE,
		"base_price_min": 5,
		"base_price_max": 8,
		"rotatable": true,
		"size": Vector2i(3, 2),
		"cells": [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 0)],
		"tradeoff_desc": "Only activates in danger, but it activates hard.",
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
		"desc": "Adds strong target correction to NULL.",
		"rarity": UpdateRarity.RARE,
		"base_price_min": 5,
		"base_price_max": 8,
		"rotatable": true,
		"size": Vector2i(2, 3),
		"cells": [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 2)],
		"tradeoff_desc": "Makes shots far more reliable, but it still wants vertical space.",
		"icon_path": "res://Art/Cards/Icons/HOMING_NUDGE.png"
	},

	"DASH_UNLOCK": {
		"title": "ENERGY DASH",
		"desc": "Replaces the base dash with a much longer burst that grants dash invulnerability.",
		"rarity": UpdateRarity.EPIC,
		"base_price_min": 9,
		"base_price_max": 14,
		"rotatable": true,
		"size": Vector2i(3, 2),
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1)],
		"tradeoff_desc": "Very strong escape tool, but still costs premium space.",
		"icon_path": "res://Art/Cards/Icons/DASH_UNLOCK.png"
	},

	"SLIDE_DODGE": {
		"title": "SLIDE DODGE",
		"desc": "Press dash while moving on the ground to slide forward and push enemies you hit.",
		"rarity": UpdateRarity.RARE,
		"base_price_min": 5,
		"base_price_max": 8,
		"rotatable": true,
		"size": Vector2i(3, 2),
		"cells": [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 0)],
		"tradeoff_desc": "Great for making space, but it only works while grounded and moving.",
		"icon_path": "res://Art/Cards/Icons/SLIDE_DODGE.png"
	},

	"CHARGE_SHOT": {
		"title": "CHARGE SHOT",
		"desc": "Hold the shot briefly to fire a much larger charged NULL.",
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
		"tradeoff_desc": "Huge payoff, but still expensive in both money and space.",
		"icon_path": "res://Art/Cards/Icons/CHARGE_SHOT.png"
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

	"SLOWMO_RECOVERY": {
		"title": "SLOWMO RECOVERY",
		"desc": "Heavily slows time while NULL is on the ground.",
		"rarity": UpdateRarity.RARE,
		"base_price_min": 5,
		"base_price_max": 8,
		"rotatable": false,
		"size": Vector2i(2, 2),
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)],
		"tradeoff_desc": "Defensive and compact, but it only matters after a miss.",
		"icon_path": "res://Art/Cards/Icons/SLOWMO_RECOVERY.png"
	},

	"IMPACT_PULSE": {
		"title": "IMPACT PULSE",
		"desc": "A missed NULL emits a large shock pulse that throws back nearby enemies.",
		"rarity": UpdateRarity.RARE,
		"base_price_min": 6,
		"base_price_max": 9,
		"rotatable": true,
		"size": Vector2i(3, 3),
		"cells": [
			Vector2i(1, 0),
			Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1),
			Vector2i(1, 2)
		],
		"tradeoff_desc": "Turns a miss into a panic button, but it takes premium space.",
		"icon_path": "res://Art/Cards/Icons/IMPACT_PULSE.png"
	},

	"THREAD_LOCK": {
		"title": "THREAD LOCK",
		"desc": "Draws a live thread between you and a dropped NULL.",
		"rarity": UpdateRarity.COMMON,
		"base_price_min": 2,
		"base_price_max": 4,
		"rotatable": true,
		"size": Vector2i(3, 1),
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)],
		"tradeoff_desc": "Pure utility, but perfect for long empty gaps in your grid.",
		"icon_path": "res://Art/Cards/Icons/THREAD_LOCK.png"
	},

	"NULL_FREEZE": {
		"title": "NULL FREEZE",
		"desc": "Recovering NULL freezes nearby enemies for a noticeable moment.",
		"rarity": UpdateRarity.RARE,
		"base_price_min": 6,
		"base_price_max": 9,
		"rotatable": true,
		"size": Vector2i(2, 3),
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(0, 2)],
		"tradeoff_desc": "Excellent panic tool, but the tall shape is awkward.",
		"icon_path": "res://Art/Cards/Icons/NULL_FREEZE.png"
	},

	"AUTO_RECALL": {
		"title": "AUTO RECALL",
		"desc": "If NULL stays on the ground too long, it automatically starts flying back to you.",
		"rarity": UpdateRarity.EPIC,
		"base_price_min": 10,
		"base_price_max": 15,
		"rotatable": true,
		"size": Vector2i(3, 3),
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1), Vector2i(1, 2)],
		"tradeoff_desc": "Very forgiving, but it takes a lot of useful central space.",
		"icon_path": "res://Art/Cards/Icons/AUTO_RECALL.png"
	},

	"RECOVERY_IFRAME": {
		"title": "RECOVERY I-FRAME",
		"desc": "Recovering NULL grants a short burst of invulnerability.",
		"rarity": UpdateRarity.RARE,
		"base_price_min": 6,
		"base_price_max": 10,
		"rotatable": true,
		"size": Vector2i(2, 3),
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2)],
		"tradeoff_desc": "Excellent safety net, but you only feel it when you commit to a pickup.",
		"icon_path": "res://Art/Cards/Icons/RECOVERY_IFRAME.png"
	},

	"STASIS_FIELD": {
		"title": "STASIS FIELD",
		"desc": "A dropped NULL emits repeated stasis pulses that lock nearby enemies in place.",
		"rarity": UpdateRarity.EPIC,
		"base_price_min": 10,
		"base_price_max": 15,
		"rotatable": true,
		"size": Vector2i(3, 3),
		"cells": [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(0, 2), Vector2i(2, 2)],
		"tradeoff_desc": "Absurdly strong for recovery, but it hogs a lot of R.A.M.",
		"icon_path": "res://Art/Cards/Icons/STASIS_FIELD.png"
	},

	"SECOND_CHANCE": {
		"title": "SECOND CHANCE",
		"desc": "If a shot would fail, NULL gets one emergency redirect toward a nearby enemy.",
		"rarity": UpdateRarity.EPIC,
		"base_price_min": 12,
		"base_price_max": 16,
		"rotatable": true,
		"size": Vector2i(4, 3),
		"cells": [Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, 1), Vector2i(3, 1)],
		"tradeoff_desc": "Incredibly powerful shot correction, but very expensive in space and cost.",
		"icon_path": "res://Art/Cards/Icons/SECOND_CHANCE.png"
	},

	"HEAVY_NULL": {
		"title": "HEAVY NULL",
		"desc": "NULL becomes larger and easier to land, but it travels slower and reaches less distance.",
		"rarity": UpdateRarity.RARE,
		"base_price_min": 6,
		"base_price_max": 9,
		"rotatable": true,
		"size": Vector2i(3, 2),
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1)],
		"tradeoff_desc": "Makes hits easier, but intentionally weakens speed and range.",
		"icon_path": "res://Art/Cards/Icons/HEAVY_NULL.png"
	},

	"OVERCLOCK": {
		"title": "OVERCLOCK",
		"desc": "Remote recovery accelerates faster and pulls harder.",
		"rarity": UpdateRarity.RARE,
		"base_price_min": 5,
		"base_price_max": 8,
		"rotatable": true,
		"size": Vector2i(2, 2),
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)],
		"tradeoff_desc": "High-pressure utility in a compact footprint.",
		"icon_path": "res://Art/Cards/Icons/OVERCLOCK.png"
	},

	"GROUND_ECHO": {
		"title": "GROUND ECHO",
		"desc": "A dropped NULL emits a scan pulse that pings nearby threats.",
		"rarity": UpdateRarity.COMMON,
		"base_price_min": 2,
		"base_price_max": 4,
		"rotatable": true,
		"size": Vector2i(2, 2),
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)],
		"tradeoff_desc": "Information over power, but the scan can save your route.",
		"icon_path": "res://Art/Cards/Icons/GROUND_ECHO.png"
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
	},

	"INFINITE": {
		"title": "INFINITE",
		"desc": "NULL is no longer consumed when firing. You can keep shooting forever.",
		"rarity": UpdateRarity.EPIC,
		"base_price_min": 50,
		"base_price_max": 50,
		"rotatable": false,
		"size": Vector2i(4, 4),
		"cells": [
			Vector2i(1, 0), Vector2i(2, 0),
			Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1),
			Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2),
			Vector2i(1, 3), Vector2i(2, 3)
		],
		"tradeoff_desc": "Totally breaks the core rule in your favor, so it is intentionally massive and extremely expensive.",
		"icon_path": "res://Art/Cards/Icons/INFINITE.png"
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
