# res://Shop/shop.gd
extends Control

@onready var offers_box: VBoxContainer = $OffersBox
@onready var money_label: Label = $MoneyLabelShop
@onready var exit_button: Button = $ExitButton

var rng := RandomNumberGenerator.new()

enum Rarity { COMMON, RARE, EPIC }

func _ready() -> void:
	rng.randomize()

	# In shop il mouse deve essere libero per cliccare i bottoni
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# HUD soldi in shop
	if Signals.has_signal("money_changed"):
		Signals.money_changed.connect(_on_money_changed)
	_on_money_changed(Run.money)

	# Exit
	exit_button.pressed.connect(_exit_shop)

	# Genera offerte ad ogni visita (Run.shop_offers viene svuotato dal portale,
	# ma qui siamo safe anche se non lo fosse)
	if Run.shop_offers.is_empty():
		_generate_offers()

	_render_offers()

func _on_money_changed(m: int) -> void:
	money_label.text = "CUBES: %d" % m

func _exit_shop() -> void:
	# Torniamo in arena
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	Run.returning_from_shop = true
	Run.spawn_player_random = true
	get_tree().change_scene_to_file("res://Game/Main.tscn")

# -----------------------------
# OFFERS
# -----------------------------
func _generate_offers() -> void:
	var count := randi_range(1, 3)
	Run.shop_offers.clear()

	# candidates: perks acquistabili (riusa la tua logica attuale)
	var candidates: Array[String] = []
	for id in Run.perk_pool:
		if Run._can_take(id):
			candidates.append(id)

	# fallback: se non ce ne sono, prendi pool intero (stackable)
	if candidates.is_empty():
		candidates = Run.perk_pool.duplicate()

	candidates.shuffle()

	for i in range(min(count, candidates.size())):
		var id := candidates[i]
		var r := _rarity_for(id)
		var price := _price_for(r)
		Run.shop_offers.append({
			"id": id,
			"rarity": r,
			"price": price
		})

func _render_offers() -> void:
	for c in offers_box.get_children():
		c.queue_free()

	for i in range(Run.shop_offers.size()):
		var offer: Dictionary = Run.shop_offers[i] as Dictionary
		var id: String = offer["id"]
		var price: int = offer["price"]
		var r: int = offer["rarity"]

		var row := HBoxContainer.new()

		var title := Label.new()
		title.text = "%s (%s) - %d" % [id, _rarity_name(r), price]
		row.add_child(title)

		var buy := Button.new()
		buy.text = "BUY"
		buy.pressed.connect(func():
			_try_buy(i)
		)
		row.add_child(buy)

		offers_box.add_child(row)

func _try_buy(index: int) -> void:
	if index < 0 or index >= Run.shop_offers.size():
		return

	var offer: Dictionary = Run.shop_offers[index] as Dictionary
	var id: String = offer["id"]
	var price: int = offer["price"]

	# Se non puoi più prendere quel perk, rimuovilo
	if not Run._can_take(id):
		Run.shop_offers.remove_at(index)
		_render_offers()
		return

	# soldi
	if not Run.spend_money(price):
		return

	# applica perk (usa la tua funzione esistente)
	Run._apply(id)

	# Dopo l’acquisto, lo slot sparisce (non ricomprabile nella stessa visita)
	Run.shop_offers.remove_at(index)
	_render_offers()

# -----------------------------
# RARITY + PRICING
# -----------------------------
func _rarity_for(perk_id: String) -> int:
	# Mappa semplice (personalizzabile)
	match perk_id:
		"JUMP_UNLOCK", "DASH_UNLOCK", "CHARGE_SHOT", "SWAP_WITH_NULL":
			return Rarity.EPIC
		"PIERCE_1", "HOMING_NUDGE", "PULL_TO_HAND", "DROP_SHOCKWAVE", "SLOWMO_RECOVERY":
			return Rarity.RARE
		_:
			return Rarity.COMMON

func _price_for(r: int) -> int:
	match r:
		Rarity.COMMON: return randi_range(2, 4)
		Rarity.RARE: return randi_range(5, 8)
		Rarity.EPIC: return randi_range(9, 14)
	return 3

func _rarity_name(r: int) -> String:
	match r:
		Rarity.COMMON:
			return "COMMON"
		Rarity.RARE:
			return "RARE"
		Rarity.EPIC:
			return "EPIC"
	return "?"
