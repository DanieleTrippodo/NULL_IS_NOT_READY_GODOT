extends Node

enum PerkRarity { COMMON, RARE, EPIC }

# ------------------------------------------------------------
# DATABASE WRAPPERS
# ------------------------------------------------------------
func get_perk_rarity(id: String) -> int:
	return UpdatesDB.get_rarity(id)

func get_perk_title_static(id: String) -> String:
	return UpdatesDB.get_title(id)

func get_perk_desc_static(id: String) -> String:
	return UpdatesDB.get_desc(id)

func get_perk_icon_path(id: String) -> String:
	return UpdatesDB.get_icon_path(id)

func roll_price_for_rarity(rarity: int, rng: RandomNumberGenerator) -> int:
	var pool: Array[String] = []
	for id in perk_pool:
		if UpdatesDB.get_rarity(id) == rarity:
			pool.append(id)

	if pool.is_empty():
		match rarity:
			PerkRarity.COMMON:
				return rng.randi_range(2, 4)
			PerkRarity.RARE:
				return rng.randi_range(5, 8)
			PerkRarity.EPIC:
				return rng.randi_range(9, 14)
			_:
				return 3

	var chosen_id: String = pool[rng.randi_range(0, pool.size() - 1)]
	return UpdatesDB.roll_price_for_id(chosen_id, depth, rng)

func rarity_name(r: int) -> String:
	return UpdatesDB.rarity_name(r)

func get_perk_preview_lines(id: String) -> Array[String]:
	var lines: Array[String] = []

	match id:
		"NULL_BOUNCE":
			lines.append("Bounces: %d" % 1)

		"BOUNCE_STACK":
			lines.append("Bounces: %d" % min(null_bounces + 1, max_null_bounces))

		"JUMP_UNLOCK":
			lines.append("Jump: UNLOCKED")

		"JUMP_POWER":
			lines.append("Jump velocity: %.1f" % min(jump_velocity + 2.0, 12.0))

		"LONG_JUMP":
			lines.append("Air speed: %.2fx" % min(air_speed_mult + 0.5, 2.0))

		"FLIGHT_BURST":
			lines.append("Flight time: 5.0s")

		"MAGNET_PICKUP":
			lines.append("Magnet: ON")
			lines.append("Pickup radius: %.1f" % pickup_radius)

		"SPRINT":
			lines.append("Move speed: %.2fx" % min(move_speed_mult + 0.15, 1.5))

		"PANIC_BOOST":
			lines.append("NOT READY speed: %.2fx" % panic_speed_mult)

		"SLOW_TURRETS":
			lines.append("Turret interval: %.2fx" % max(turret_interval_mult - 0.1, 0.7))

		"NULL_SPEED":
			lines.append("Null speed: %.2fx" % min(null_speed_mult + 0.2, 1.8))

		"NULL_RANGE":
			lines.append("Null range: %.2fx" % min(null_range_mult + 0.2, 1.8))

		"PIERCE_1":
			lines.append("Pierce: 1")

		"HOMING_NUDGE":
			lines.append("Homing: ON")
			lines.append("Max angle: %.0f°" % homing_max_angle_deg)

		"DASH_UNLOCK":
			lines.append("Dash: UNLOCKED")

		"CHARGE_SHOT":
			lines.append("Charge: ON")
			lines.append("Charge time: %.1fs" % charge_shot_seconds)
			lines.append("Charge scale: %.2fx" % charge_shot_scale)

		"CHARGE_PLUS":
			if charge_shot_enabled:
				if charge_shot_seconds > 2.0:
					lines.append("Charge time: %.1fs" % max(charge_shot_seconds - 0.5, 2.0))
				else:
					lines.append("Charge scale: %.2fx" % min(charge_shot_scale + 0.25, 2.25))
			else:
				lines.append("Requires: CHARGE SHOT")

		"PULL_TO_HAND":
			lines.append("Pull: ON")
			lines.append("Channel: %.1fs" % pull_channel_seconds)
			lines.append("Max distance: %.0f" % pull_max_distance)

		"SWAP_WITH_NULL":
			lines.append("Swap: ON")
			lines.append("Cooldown: %.0fs" % swap_cooldown)
			lines.append("Max distance: %.0f" % swap_max_distance)

		"DROP_SHOCKWAVE":
			lines.append("Shockwave: ON")
			lines.append("Radius: %.0f" % shockwave_radius)

		"SLOWMO_RECOVERY":
			lines.append("Slowmo scale: %.2f" % slowmo_scale)

		"RAM_PATCH":
			lines.append("R.A.M.: %dx%d -> %dx%d" % [
				ram_cols,
				ram_rows,
				ram_cols + 1,
				ram_rows + 1
			])

		_:
			pass

	return lines


# ------------------------------------------------------------
# ECONOMY / RUN
# ------------------------------------------------------------
var money: int = 0

var returning_from_shop: bool = false
var spawn_player_random: bool = false

var shop_offers: Array = []

var depth: int = 1
var terminal_logs_read: Array[bool] = []
var null_ready: bool = true
var null_dropped: bool = false
var survival_mode: bool = false


# ------------------------------------------------------------
# GAMEPLAY RUNTIME STATE
# ------------------------------------------------------------
var null_bounces: int = 0
var jump_enabled: bool = true
var jump_velocity: float = 8.0
var flight_time_left: float = 0.0

var pickup_magnet: bool = false
var pickup_radius: float = 2.0

var move_speed_mult: float = 1.0
var air_speed_mult: float = 1.0
var turret_interval_mult: float = 1.0
var null_speed_mult: float = 1.0
var null_range_mult: float = 1.0
var dash_enabled: bool = false

# Charge shot
var charge_shot_enabled: bool = false
var charge_shot_seconds: float = 3.0
var charge_shot_scale: float = 1.5
var charge_shake_strength: float = 0.05

# Recovery / risk
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

# Shot modifiers
var null_pierce: int = 0
var homing_nudge: bool = false
var homing_max_angle_deg: float = 6.0
var homing_turn_speed: float = 10.0

var max_null_bounces: int = 3


# ------------------------------------------------------------
# UI FEEDBACK
# ------------------------------------------------------------
var last_perk_title: String = ""
var last_perk_desc: String = ""


# ------------------------------------------------------------
# SHOP POOL
# ------------------------------------------------------------
var perk_pool: Array[String] = [
	"NULL_BOUNCE",
	"BOUNCE_STACK",

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


# ------------------------------------------------------------
# R.A.M.
# ------------------------------------------------------------
var ram_base_cols: int = 6
var ram_base_rows: int = 4

var ram_cols: int = 6
var ram_rows: int = 4

# [y][x] -> instance_id or -1
var ram_grid: Array = []

# {
#   "instance_id": int,
#   "update_id": String,
#   "rotation": int,
#   "equipped": bool,
#   "grid_pos": Vector2i
# }
var owned_updates: Array[Dictionary] = []

var _next_update_instance_id: int = 1


func _ready() -> void:
	var cb1 := Callable(self, "_on_null_ready_changed")
	if not Signals.null_ready_changed.is_connected(cb1):
		Signals.null_ready_changed.connect(cb1)

	var cb2 := Callable(self, "_on_null_dropped")
	if not Signals.null_dropped.is_connected(cb2):
		Signals.null_dropped.connect(cb2)

	_refresh_ram_dimensions()
	_build_empty_ram_grid()


func _on_null_ready_changed(is_ready: bool) -> void:
	null_ready = is_ready
	if is_ready:
		null_dropped = false


func _on_null_dropped(_pos: Vector3) -> void:
	null_dropped = true


# ------------------------------------------------------------
# MONEY
# ------------------------------------------------------------
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


# ------------------------------------------------------------
# RESET RUN
# ------------------------------------------------------------
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

	swap_cd_left = 0.0

	last_perk_title = ""
	last_perk_desc = ""

	owned_updates.clear()
	_next_update_instance_id = 1

	_refresh_ram_dimensions()
	_build_empty_ram_grid()

	_reset_runtime_stats_to_base()


func _reset_runtime_stats_to_base() -> void:
	null_bounces = 0

	jump_enabled = true
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
	pull_channel_seconds = 0.6
	pull_max_distance = 14.0
	pull_cancel_move_dist = 0.75
	pull_move_mult = 0.35

	swap_with_null = false
	swap_cooldown = 6.0
	swap_max_distance = 35.0

	panic_boost = false
	panic_speed_mult = 1.2

	drop_shockwave = false
	shockwave_radius = 6.0
	shockwave_strength = 10.0

	slowmo_recovery = false
	slowmo_scale = 0.85

	null_pierce = 0
	homing_nudge = false
	homing_max_angle_deg = 6.0
	homing_turn_speed = 10.0


# ------------------------------------------------------------
# R.A.M. DIMENSIONS
# ------------------------------------------------------------
func get_equipped_ram_patch_count() -> int:
	return count_equipped_update("RAM_PATCH")


func _refresh_ram_dimensions() -> void:
	var patch_count: int = get_equipped_ram_patch_count()
	ram_cols = ram_base_cols + patch_count
	ram_rows = ram_base_rows + patch_count


func get_ram_total_slots() -> int:
	return ram_cols * ram_rows


func get_ram_active_slots() -> int:
	return get_ram_total_slots()


func get_ram_max_slots() -> int:
	return get_ram_total_slots()


func is_ram_cell_active(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < ram_cols and cell.y >= 0 and cell.y < ram_rows


func _build_empty_ram_grid() -> void:
	ram_grid.clear()
	for y in range(ram_rows):
		var row: Array = []
		for x in range(ram_cols):
			row.append(-1)
		ram_grid.append(row)


func _resize_ram_grid_preserve_contents(new_cols: int, new_rows: int) -> void:
	var old_grid: Array = get_ram_grid_copy()
	var old_rows: int = ram_grid.size()
	var old_cols: int = 0
	if old_rows > 0:
		old_cols = (ram_grid[0] as Array).size()

	ram_cols = new_cols
	ram_rows = new_rows
	_build_empty_ram_grid()

	var copy_rows: int = min(old_rows, new_rows)
	var copy_cols: int = min(old_cols, new_cols)

	for y in range(copy_rows):
		for x in range(copy_cols):
			ram_grid[y][x] = old_grid[y][x]


func _send_all_equipped_updates_back_to_inventory() -> void:
	for y in range(ram_grid.size()):
		for x in range((ram_grid[y] as Array).size()):
			ram_grid[y][x] = -1

	for i in range(owned_updates.size()):
		owned_updates[i]["equipped"] = false
		owned_updates[i]["grid_pos"] = Vector2i(-1, -1)

	_refresh_ram_dimensions()
	_build_empty_ram_grid()


# ------------------------------------------------------------
# OWNED UPDATES
# ------------------------------------------------------------
func add_owned_update(update_id: String) -> Dictionary:
	if not UpdatesDB.has_update(update_id):
		return {}

	var inst: Dictionary = {
		"instance_id": _next_update_instance_id,
		"update_id": update_id,
		"rotation": 0,
		"equipped": false,
		"grid_pos": Vector2i(-1, -1)
	}

	_next_update_instance_id += 1
	owned_updates.append(inst)
	return inst.duplicate(true)


func get_owned_updates() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for item in owned_updates:
		out.append(item.duplicate(true))
	return out


func get_unequipped_updates() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for item in owned_updates:
		if not bool(item.get("equipped", false)):
			out.append(item.duplicate(true))
	return out


func get_equipped_updates() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for item in owned_updates:
		if bool(item.get("equipped", false)):
			out.append(item.duplicate(true))
	return out


func get_owned_update_index_by_instance_id(instance_id: int) -> int:
	for i in range(owned_updates.size()):
		if int(owned_updates[i].get("instance_id", -1)) == instance_id:
			return i
	return -1


func get_owned_update_by_instance_id(instance_id: int) -> Dictionary:
	var idx: int = get_owned_update_index_by_instance_id(instance_id)
	if idx == -1:
		return {}
	return owned_updates[idx].duplicate(true)


func is_update_equipped(instance_id: int) -> bool:
	var idx: int = get_owned_update_index_by_instance_id(instance_id)
	if idx == -1:
		return false
	return bool(owned_updates[idx].get("equipped", false))


func count_owned_update(update_id: String) -> int:
	var n: int = 0
	for item in owned_updates:
		if str(item.get("update_id", "")) == update_id:
			n += 1
	return n


func count_equipped_update(update_id: String) -> int:
	var n: int = 0
	for item in owned_updates:
		if str(item.get("update_id", "")) == update_id and bool(item.get("equipped", false)):
			n += 1
	return n


# ------------------------------------------------------------
# SHAPE / ROTATION HELPERS
# ------------------------------------------------------------
func get_ram_cells_for_update(update_id: String, item_rotation: int = 0) -> Array[Vector2i]:
	var base_cells: Array = UpdatesDB.get_cells(update_id)

	var typed_cells: Array[Vector2i] = []
	for c in base_cells:
		if c is Vector2i:
			typed_cells.append(c)

	return _rotate_cells_to_fit_positive_space(typed_cells, item_rotation)


func get_ram_size_for_update(update_id: String, item_rotation: int = 0) -> Vector2i:
	var cells: Array[Vector2i] = get_ram_cells_for_update(update_id, item_rotation)
	return _get_cells_bounds(cells)


func _rotate_cells_to_fit_positive_space(cells: Array[Vector2i], item_rotation: int) -> Array[Vector2i]:
	var rot: int = wrapi(item_rotation, 0, 4)
	var rotated: Array[Vector2i] = []

	for c in cells:
		var p: Vector2i = c
		match rot:
			0:
				p = Vector2i(c.x, c.y)
			1:
				p = Vector2i(-c.y, c.x)
			2:
				p = Vector2i(-c.x, -c.y)
			3:
				p = Vector2i(c.y, -c.x)
		rotated.append(p)

	var min_x: int = 999999
	var min_y: int = 999999
	for p in rotated:
		min_x = min(min_x, p.x)
		min_y = min(min_y, p.y)

	var normalized: Array[Vector2i] = []
	for p in rotated:
		normalized.append(Vector2i(p.x - min_x, p.y - min_y))

	return normalized


func _get_cells_bounds(cells: Array[Vector2i]) -> Vector2i:
	if cells.is_empty():
		return Vector2i.ONE

	var max_x: int = 0
	var max_y: int = 0
	for c in cells:
		max_x = max(max_x, c.x)
		max_y = max(max_y, c.y)

	return Vector2i(max_x + 1, max_y + 1)


# ------------------------------------------------------------
# R.A.M. GRID HELPERS
# ------------------------------------------------------------
func get_ram_grid_copy() -> Array:
	var out: Array = []
	for row in ram_grid:
		out.append((row as Array).duplicate(true))
	return out


func clear_ram_grid() -> void:
	_refresh_ram_dimensions()
	_build_empty_ram_grid()
	for i in range(owned_updates.size()):
		owned_updates[i]["equipped"] = false
		owned_updates[i]["grid_pos"] = Vector2i(-1, -1)
		owned_updates[i]["rotation"] = 0
	rebuild_equipped_updates_effects()


func remove_update_from_ram(instance_id: int) -> bool:
	var idx: int = get_owned_update_index_by_instance_id(instance_id)
	if idx == -1:
		return false

	var was_equipped: bool = bool(owned_updates[idx].get("equipped", false))
	if not was_equipped:
		return true

	var update_id: String = str(owned_updates[idx].get("update_id", ""))

	# Removing RAM_PATCH collapses the grid:
	# everything returns to inventory and dimensions shrink.
	if update_id == "RAM_PATCH":
		_send_all_equipped_updates_back_to_inventory()
		rebuild_equipped_updates_effects()
		return true

	for y in range(ram_rows):
		for x in range(ram_cols):
			if int(ram_grid[y][x]) == instance_id:
				ram_grid[y][x] = -1

	owned_updates[idx]["equipped"] = false
	owned_updates[idx]["grid_pos"] = Vector2i(-1, -1)

	rebuild_equipped_updates_effects()
	return true


func can_place_update_instance(instance_id: int, origin: Vector2i, item_rotation: int = 0) -> bool:
	var item: Dictionary = get_owned_update_by_instance_id(instance_id)
	if item.is_empty():
		return false

	var update_id: String = str(item.get("update_id", ""))
	var cells: Array[Vector2i] = get_ram_cells_for_update(update_id, item_rotation)

	# If we're placing a fresh RAM_PATCH, it still needs to fit
	# inside the current grid before expanding it.
	for c in cells:
		var gx: int = origin.x + c.x
		var gy: int = origin.y + c.y

		if gx < 0 or gx >= ram_cols or gy < 0 or gy >= ram_rows:
			return false

		var cell_value: int = int(ram_grid[gy][gx])
		if cell_value != -1 and cell_value != instance_id:
			return false

	return true


func equip_update_instance(instance_id: int, origin: Vector2i, item_rotation: int = 0) -> bool:
	var idx: int = get_owned_update_index_by_instance_id(instance_id)
	if idx == -1:
		return false

	remove_update_from_ram(instance_id)

	if not can_place_update_instance(instance_id, origin, item_rotation):
		return false

	var update_id: String = str(owned_updates[idx].get("update_id", ""))
	var cells: Array[Vector2i] = get_ram_cells_for_update(update_id, item_rotation)

	for c in cells:
		var gx: int = origin.x + c.x
		var gy: int = origin.y + c.y
		ram_grid[gy][gx] = instance_id

	owned_updates[idx]["equipped"] = true
	owned_updates[idx]["grid_pos"] = origin
	owned_updates[idx]["rotation"] = wrapi(item_rotation, 0, 4)

	var old_cols: int = ram_cols
	var old_rows: int = ram_rows

	rebuild_equipped_updates_effects()

	# If equipping RAM_PATCH changed grid dimensions, preserve existing contents.
	if update_id == "RAM_PATCH":
		if ram_cols != old_cols or ram_rows != old_rows:
			_resize_ram_grid_preserve_contents(ram_cols, ram_rows)

			# redraw all equipped items into the resized grid
			for y in range(ram_rows):
				for x in range(ram_cols):
					ram_grid[y][x] = -1

			for equipped_item in owned_updates:
				if not bool(equipped_item.get("equipped", false)):
					continue

				var equipped_update_id: String = str(equipped_item.get("update_id", ""))
				var equipped_origin: Vector2i = equipped_item.get("grid_pos", Vector2i(-1, -1)) as Vector2i
				var equipped_rotation: int = int(equipped_item.get("rotation", 0))
				var equipped_cells: Array[Vector2i] = get_ram_cells_for_update(equipped_update_id, equipped_rotation)

				for ec in equipped_cells:
					var ex: int = equipped_origin.x + ec.x
					var ey: int = equipped_origin.y + ec.y
					if ex >= 0 and ex < ram_cols and ey >= 0 and ey < ram_rows:
						ram_grid[ey][ex] = int(equipped_item.get("instance_id", -1))

	return true


func move_equipped_update(instance_id: int, new_origin: Vector2i) -> bool:
	var item: Dictionary = get_owned_update_by_instance_id(instance_id)
	if item.is_empty():
		return false

	var item_rotation: int = int(item.get("rotation", 0))
	return equip_update_instance(instance_id, new_origin, item_rotation)


func rotate_equipped_update(instance_id: int) -> bool:
	var item: Dictionary = get_owned_update_by_instance_id(instance_id)
	if item.is_empty():
		return false

	var update_id: String = str(item.get("update_id", ""))
	if not UpdatesDB.is_rotatable(update_id):
		return false

	var current_rot: int = int(item.get("rotation", 0))
	var next_rot: int = wrapi(current_rot + 1, 0, 4)
	var grid_pos: Vector2i = item.get("grid_pos", Vector2i(-1, -1)) as Vector2i

	if grid_pos == Vector2i(-1, -1):
		var idx: int = get_owned_update_index_by_instance_id(instance_id)
		if idx == -1:
			return false
		owned_updates[idx]["rotation"] = next_rot
		return true

	return equip_update_instance(instance_id, grid_pos, next_rot)


# ------------------------------------------------------------
# REBUILD ACTIVE EFFECTS
# ------------------------------------------------------------
func rebuild_equipped_updates_effects() -> void:
	var prev_flight_time: float = flight_time_left
	var prev_swap_cd: float = swap_cd_left

	_reset_runtime_stats_to_base()
	_refresh_ram_dimensions()

	for item in owned_updates:
		if bool(item.get("equipped", false)):
			var update_id: String = str(item.get("update_id", ""))
			_apply_equipped_update_effect(update_id)

	flight_time_left = max(flight_time_left, prev_flight_time)
	swap_cd_left = prev_swap_cd


func _apply_equipped_update_effect(id: String) -> void:
	match id:
		"NULL_BOUNCE":
			null_bounces = max(null_bounces, 1)

		"BOUNCE_STACK":
			null_bounces = min(null_bounces + 1, max_null_bounces)

		"JUMP_UNLOCK":
			jump_enabled = true

		"JUMP_POWER":
			jump_velocity = min(jump_velocity + 2.0, 12.0)

		"LONG_JUMP":
			air_speed_mult = min(air_speed_mult + 0.5, 2.0)

		"FLIGHT_BURST":
			flight_time_left = max(flight_time_left, 0.0)

		"MAGNET_PICKUP":
			pickup_magnet = true

		"SPRINT":
			move_speed_mult = min(move_speed_mult + 0.15, 1.5)

		"PANIC_BOOST":
			panic_boost = true

		"SLOW_TURRETS":
			turret_interval_mult = max(turret_interval_mult - 0.1, 0.7)

		"NULL_SPEED":
			null_speed_mult = min(null_speed_mult + 0.2, 1.8)

		"NULL_RANGE":
			null_range_mult = min(null_range_mult + 0.2, 1.8)

		"PIERCE_1":
			null_pierce = max(null_pierce, 1)

		"HOMING_NUDGE":
			homing_nudge = true

		"DASH_UNLOCK":
			dash_enabled = true

		"CHARGE_SHOT":
			charge_shot_enabled = true

		"CHARGE_PLUS":
			if charge_shot_enabled:
				if charge_shot_seconds > 2.0:
					charge_shot_seconds = max(charge_shot_seconds - 0.5, 2.0)
				else:
					charge_shot_scale = min(charge_shot_scale + 0.25, 2.25)

		"PULL_TO_HAND":
			pull_to_hand = true

		"SWAP_WITH_NULL":
			swap_with_null = true

		"DROP_SHOCKWAVE":
			drop_shockwave = true

		"SLOWMO_RECOVERY":
			slowmo_recovery = true

		"RAM_PATCH":
			# R.A.M. size is handled by _refresh_ram_dimensions()
			pass


# ------------------------------------------------------------
# LEGACY SHOP / PERK FLOW
# ------------------------------------------------------------
func grant_random_perk(rng: RandomNumberGenerator) -> bool:
	var available: Array[String] = []
	for id in perk_pool:
		if _can_take(id):
			available.append(id)

	if available.is_empty():
		return false

	var pick: String = available[rng.randi_range(0, available.size() - 1)]
	_apply(pick)
	return true


func _can_take(_id: String) -> bool:
	return true


func _apply(id: String) -> void:
	match id:
		"NULL_BOUNCE":
			null_bounces = 1
			last_perk_title = "NULL BOUNCE"
			last_perk_desc = "Your NULL projectile bounces once."

		"BOUNCE_STACK":
			null_bounces = min(null_bounces + 1, max_null_bounces)
			last_perk_title = "BOUNCE STACK"
			last_perk_desc = "Adds +1 extra bounce."

		"JUMP_POWER":
			jump_velocity = min(jump_velocity + 2.0, 12.0)
			last_perk_title = "HIGHER JUMP"
			last_perk_desc = "Increases jump height."

		"LONG_JUMP":
			air_speed_mult = min(air_speed_mult + 0.5, 2.0)
			last_perk_title = "LONG JUMP"
			last_perk_desc = "Improves air control and aerial speed."

		"FLIGHT_BURST":
			flight_time_left = 5.0
			last_perk_title = "FLIGHT (5s)"
			last_perk_desc = "Allows flight for 5 seconds."

		"MAGNET_PICKUP":
			pickup_magnet = true
			last_perk_title = "MAGNET"
			last_perk_desc = "Automatically picks up nearby NULL drops."

		"SPRINT":
			move_speed_mult = min(move_speed_mult + 0.15, 1.5)
			last_perk_title = "SPEED UP"
			last_perk_desc = "Increases movement speed by 15%."

		"PANIC_BOOST":
			panic_boost = true
			last_perk_title = "PANIC BOOST"
			last_perk_desc = "Gain bonus speed while NULL is not ready."

		"SLOW_TURRETS":
			turret_interval_mult = max(turret_interval_mult - 0.1, 0.7)
			last_perk_title = "SLOW TURRETS"
			last_perk_desc = "Enemy turrets fire more slowly."

		"NULL_SPEED":
			null_speed_mult = min(null_speed_mult + 0.2, 1.8)
			last_perk_title = "NULL SPEED"
			last_perk_desc = "Makes the NULL projectile travel faster."

		"NULL_RANGE":
			null_range_mult = min(null_range_mult + 0.2, 1.8)
			last_perk_title = "NULL RANGE"
			last_perk_desc = "Increases NULL projectile travel distance."

		"PIERCE_1":
			null_pierce = 1
			last_perk_title = "PIERCE"
			last_perk_desc = "Lets NULL kill two enemies in a line."

		"HOMING_NUDGE":
			homing_nudge = true
			last_perk_title = "HOMING NUDGE"
			last_perk_desc = "Adds slight target correction to NULL."

		"DASH_UNLOCK":
			dash_enabled = true
			last_perk_title = "DASH UNLOCK"
			last_perk_desc = "Unlocks dash movement."

		"CHARGE_SHOT":
			charge_shot_enabled = true
			last_perk_title = "CHARGE SHOT"
			last_perk_desc = "Hold the shot to fire a larger charged NULL."

		"CHARGE_PLUS":
			if charge_shot_seconds > 2.0:
				charge_shot_seconds = max(charge_shot_seconds - 0.5, 2.0)
				last_perk_desc = "Charge time reduced by 0.5s."
			else:
				charge_shot_scale = min(charge_shot_scale + 0.25, 2.25)
				last_perk_desc = "Charged shot scale increased."
			last_perk_title = "CHARGE+"

		"PULL_TO_HAND":
			pull_to_hand = true
			last_perk_title = "PULL TO HAND"
			last_perk_desc = "Hold interact to pull NULL back to your hand."

		"SWAP_WITH_NULL":
			swap_with_null = true
			last_perk_title = "SWAP"
			last_perk_desc = "Swap positions with a dropped NULL."

		"DROP_SHOCKWAVE":
			drop_shockwave = true
			last_perk_title = "DROP SHOCKWAVE"
			last_perk_desc = "Dropped NULL emits a shockwave on miss."

		"SLOWMO_RECOVERY":
			slowmo_recovery = true
			last_perk_title = "SLOWMO RECOVERY"
			last_perk_desc = "Slows time while NULL is on the ground."

		"RAM_PATCH":
			last_perk_title = "RAM PATCH"
			last_perk_desc = "Adds +1 row and +1 column to your R.A.M. grid."

	if Signals.has_signal("perk_granted"):
		Signals.perk_granted.emit(last_perk_title, last_perk_desc)
