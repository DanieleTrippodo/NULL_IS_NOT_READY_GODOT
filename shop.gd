extends Control

@onready var cards_row: HBoxContainer = $CardsRow
@onready var money_label: Label = $MoneyLabelShop
@onready var exit_button: Button = $ExitButton

# Tooltip
@onready var tooltip: Control = $Tooltip
@onready var tt_panel: Control = $Tooltip/Panel
@onready var tt_vbox: Control = $Tooltip/Panel/VBox
@onready var tt_title: Label = $Tooltip/Panel/VBox/TTitle
@onready var tt_rarity_cost: Label = $Tooltip/Panel/VBox/TRarityCost
@onready var tt_desc: Label = $Tooltip/Panel/VBox/TDesc
@onready var tt_preview: RichTextLabel = $Tooltip/Panel/VBox/TPreview

const CARD_SCENE: PackedScene = preload("res://Shop/firmware_card.tscn")

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var focused_index: int = 0


func _ready() -> void:
	rng.randomize()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if Signals and Signals.has_signal("money_changed"):
		if not Signals.money_changed.is_connected(_on_money_changed):
			Signals.money_changed.connect(_on_money_changed)
	_on_money_changed(Run.money)

	exit_button.pressed.connect(_exit_shop)

	tooltip.visible = false
	tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE

	tt_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	tt_panel.offset_left = 0
	tt_panel.offset_top = 0
	tt_panel.offset_right = 0
	tt_panel.offset_bottom = 0

	tt_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	tt_vbox.offset_left = 8
	tt_vbox.offset_top = 8
	tt_vbox.offset_right = -8
	tt_vbox.offset_bottom = -8

	if Run.shop_offers.is_empty():
		_generate_offers_fixed_3()

	_render_cards()
	_update_focus_first_available()


func _process(_dt: float) -> void:
	if tooltip.visible:
		_move_tooltip_to_mouse()


func _unhandled_input(ev: InputEvent) -> void:
	if ev.is_action_pressed("ui_left"):
		_focus_prev()
	elif ev.is_action_pressed("ui_right"):
		_focus_next()
	elif ev.is_action_pressed("ui_accept"):
		_activate_focused()


func _on_money_changed(m: int) -> void:
	money_label.text = "CUBES: %d" % m
	_refresh_disabled_states()


func _exit_shop() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	Run.returning_from_shop = true
	Run.spawn_player_random = true
	get_tree().change_scene_to_file("res://Game/Main.tscn")


func _generate_offers_fixed_3() -> void:
	Run.shop_offers.clear()

	var candidates: Array[String] = []
	for id in Run.perk_pool:
		if Run._can_take(id):
			candidates.append(id)

	if candidates.is_empty():
		candidates = Run.perk_pool.duplicate()

	candidates.shuffle()

	var picked: Array[String] = []
	for id in candidates:
		if picked.size() >= 3:
			break
		if id in picked:
			continue
		picked.append(id)

	while picked.size() < 3 and candidates.size() > 0:
		picked.append(candidates[rng.randi_range(0, candidates.size() - 1)])

	for id in picked:
		var r: int = Run.get_perk_rarity(id)
		var price: int = Run.roll_price_for_rarity(r, rng)
		Run.shop_offers.append({
			"id": id,
			"rarity": r,
			"price": price
		})


func _render_cards() -> void:
	for c in cards_row.get_children():
		c.queue_free()

	for i in range(Run.shop_offers.size()):
		var offer: Dictionary = Run.shop_offers[i]
		var id: String = str(offer["id"])
		var r: int = int(offer["rarity"])
		var price: int = int(offer["price"])

		var card: FirmwareCard = CARD_SCENE.instantiate()
		cards_row.add_child(card)

		card.setup(id, r, price)
		card.activated.connect(_on_card_activated)
		card.hovered.connect(_on_card_hovered)
		card.unhovered.connect(_on_card_unhovered)

		card.set_card_disabled(Run.money < price)


func _refresh_disabled_states() -> void:
	for i in range(min(cards_row.get_child_count(), Run.shop_offers.size())):
		var offer: Dictionary = Run.shop_offers[i]
		var price: int = int(offer["price"])
		var c: Node = cards_row.get_child(i)
		if c is FirmwareCard:
			(c as FirmwareCard).set_card_disabled(Run.money < price)


func _on_card_hovered(card: FirmwareCard) -> void:
	focused_index = _index_of_card(card)
	_show_tooltip_for(card.perk_id, card.rarity, card.price)


func _on_card_unhovered(_card: FirmwareCard) -> void:
	tooltip.visible = false


func _show_tooltip_for(id: String, rarity: int, price: int) -> void:
	tooltip.visible = true

	tt_title.text = Run.get_perk_title_static(id)
	tt_rarity_cost.text = "%s  |  COST: %d" % [Run.rarity_name(rarity), price]
	tt_desc.text = Run.get_perk_desc_static(id)

	var lines: Array[String] = Run.get_perk_preview_lines(id)
	if lines.is_empty():
		tt_preview.text = ""
	else:
		var bb := ""
		for l in lines:
			bb += "• %s\n" % l
		tt_preview.text = bb

	_resize_tooltip()
	_move_tooltip_to_mouse()


func _resize_tooltip() -> void:
	await get_tree().process_frame

	var w: float = 420.0
	var pad_x: float = 24.0
	var pad_y: float = 20.0
	var gap: float = 6.0

	tooltip.size.x = w

	var h: float = 0.0
	h += tt_title.get_combined_minimum_size().y + gap
	h += tt_rarity_cost.get_combined_minimum_size().y + gap
	h += tt_desc.get_minimum_size().y + gap

	if tt_preview.text.strip_edges() != "":
		h += tt_preview.get_content_height() + gap

	tooltip.size = Vector2(w + pad_x, h + pad_y)


func _move_tooltip_to_mouse() -> void:
	var m: Vector2 = get_viewport().get_mouse_position()
	var pad := Vector2(16, 16)
	var pos: Vector2 = m + pad

	var vp: Vector2 = get_viewport_rect().size
	var sz: Vector2 = tooltip.size

	if pos.x + sz.x > vp.x:
		pos.x = vp.x - sz.x - 8
	if pos.y + sz.y > vp.y:
		pos.y = vp.y - sz.y - 8
	if pos.x < 8:
		pos.x = 8
	if pos.y < 8:
		pos.y = 8

	tooltip.position = pos


func _on_card_activated(card: FirmwareCard) -> void:
	var idx: int = _index_of_card(card)
	if idx == -1:
		return
	_try_buy(idx)


func _try_buy(index: int) -> void:
	if index < 0 or index >= Run.shop_offers.size():
		return

	var offer: Dictionary = Run.shop_offers[index]
	var id: String = str(offer["id"])
	var price: int = int(offer["price"])

	if not Run._can_take(id):
		Run.shop_offers.remove_at(index)
		tooltip.visible = false
		_render_cards()
		_update_focus_first_available()
		return

	if not Run.spend_money(price):
		return

	var inst: Dictionary = Run.add_owned_update(id)
	if inst.is_empty():
		return

	Run.last_perk_title = UpdatesDB.get_title(id)
	Run.last_perk_desc = "Update acquired. Equip it in R.A.M."

	if Signals.has_signal("perk_granted"):
		Signals.perk_granted.emit(Run.last_perk_title, Run.last_perk_desc)

	Run.shop_offers.remove_at(index)
	tooltip.visible = false
	_render_cards()
	_update_focus_first_available()


func _index_of_card(card: FirmwareCard) -> int:
	for i in range(cards_row.get_child_count()):
		if cards_row.get_child(i) == card:
			return i
	return -1


func _update_focus_first_available() -> void:
	for i in range(cards_row.get_child_count()):
		var c: Node = cards_row.get_child(i)
		if c is FirmwareCard and not (c as FirmwareCard).is_card_disabled():
			focused_index = i
			(c as FirmwareCard).grab_focus()
			return


func _focus_next() -> void:
	_focus_move(+1)


func _focus_prev() -> void:
	_focus_move(-1)


func _focus_move(dir: int) -> void:
	if cards_row.get_child_count() == 0:
		return

	var i: int = focused_index
	for _k in range(cards_row.get_child_count()):
		i = (i + dir + cards_row.get_child_count()) % cards_row.get_child_count()
		var c: Node = cards_row.get_child(i)
		if c is FirmwareCard and not (c as FirmwareCard).is_card_disabled():
			focused_index = i
			(c as FirmwareCard).grab_focus()
			_show_tooltip_for((c as FirmwareCard).perk_id, (c as FirmwareCard).rarity, (c as FirmwareCard).price)
			return


func _activate_focused() -> void:
	if focused_index < 0 or focused_index >= cards_row.get_child_count():
		return

	var c: Node = cards_row.get_child(focused_index)
	if c is FirmwareCard and not (c as FirmwareCard).is_card_disabled():
		_try_buy(focused_index)
