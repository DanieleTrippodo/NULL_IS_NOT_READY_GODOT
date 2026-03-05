extends Control
class_name FirmwareCard

signal hovered(card: FirmwareCard)
signal unhovered(card: FirmwareCard)
signal activated(card: FirmwareCard)

@onready var panel: PanelContainer = $Panel
@onready var content: Control = $Panel/Content
@onready var base_tex: TextureRect = $Panel/Content/Base
@onready var icon_tex: TextureRect = $Panel/Content/Icon
@onready var title_lbl: Label = $Panel/Content/Title
@onready var price_lbl: Label = $Panel/Content/Price
@onready var rarity_lbl: Label = $Panel/Content/Rarity

var perk_id: String = ""
var rarity: int = 0
var price: int = 0
var disabled: bool = false

var _hovered := false
var _tween: Tween

func setup(id: String, r: int, p: int) -> void:
	perk_id = id
	rarity = r
	price = p

	title_lbl.text = Run.get_perk_title_static(id)
	price_lbl.text = "COST: %d" % p
	rarity_lbl.text = Run.rarity_name(r)

	# texture base (layout)
	var base_path := "res://Art/Cards/Layouts/card_base.png"
	if ResourceLoader.exists(base_path):
		base_tex.texture = load(base_path)

	# icon
	var icon_path := Run.get_perk_icon_path(id)
	if ResourceLoader.exists(icon_path):
		icon_tex.texture = load(icon_path)

	_apply_rarity_border()

func set_disabled(v: bool) -> void:
	disabled = v
	mouse_filter = Control.MOUSE_FILTER_IGNORE if v else Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE if v else Control.FOCUS_ALL
	modulate = Color(1, 1, 1, 0.35) if v else Color(1, 1, 1, 1)

func _apply_rarity_border() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.0)
	sb.border_width_left = 3
	sb.border_width_right = 3
	sb.border_width_top = 3
	sb.border_width_bottom = 3

	match rarity:
		Run.PerkRarity.COMMON: sb.border_color = Color(0.7, 0.7, 0.7)
		Run.PerkRarity.RARE: sb.border_color = Color(0.3, 0.8, 1.0)
		Run.PerkRarity.EPIC: sb.border_color = Color(1.0, 0.4, 0.9)
		_: sb.border_color = Color(1, 1, 1)

	panel.add_theme_stylebox_override("panel", sb)

func _ready() -> void:
	# IMPORTANT: tutti i figli IGNORE, così il root riceve hover/click
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rarity_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# root deve catturare input
	mouse_filter = Control.MOUSE_FILTER_STOP

	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_enter)
	mouse_exited.connect(_on_mouse_exit)
	focus_entered.connect(_on_focus_enter)
	focus_exited.connect(_on_focus_exit)

func _on_gui_input(ev: InputEvent) -> void:
	if disabled:
		return
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		activated.emit(self)

func _on_mouse_enter() -> void:
	if disabled:
		return
	_set_hover(true)
	hovered.emit(self)

func _on_mouse_exit() -> void:
	if disabled:
		return
	_set_hover(false)
	unhovered.emit(self)

func _on_focus_enter() -> void:
	if disabled:
		return
	_set_hover(true)
	hovered.emit(self)

func _on_focus_exit() -> void:
	if disabled:
		return
	_set_hover(false)
	unhovered.emit(self)

func _set_hover(v: bool) -> void:
	if _hovered == v:
		return
	_hovered = v

	if _tween and _tween.is_running():
		_tween.kill()
	_tween = create_tween()

	# “alzarsi” = muoviamo il contenuto dentro la carta (non il Control in HBox)
	var target_y := -10.0 if v else 0.0
	var target_scale := Vector2(1.04, 1.04) if v else Vector2.ONE

	_tween.tween_property(content, "position:y", target_y, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(content, "scale", target_scale, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# glow leggero simulato: aumentiamo un po’ la luminosità del modulate
	var glow_col := Color(1.15, 1.15, 1.15, 1.0) if v else Color(1, 1, 1, 1.0)
	_tween.parallel().tween_property(self, "modulate", glow_col, 0.12)
