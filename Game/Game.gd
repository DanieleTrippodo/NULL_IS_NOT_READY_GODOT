# res://Game/Game.gd
extends Node

@export var arena_scene: PackedScene
@export var player_scene: PackedScene
@export var null_projectile_scene: PackedScene
@export var chaser_scene: PackedScene
@export var turret_scene: PackedScene
@export var spike_scene: PackedScene
@export var exception_scene: PackedScene
@export var enemy_bullet_scene: PackedScene

@onready var world: Node3D = $World
@onready var arena_root: Node3D = $World/ArenaRoot
@onready var player_root: Node3D = $World/PlayerRoot
@onready var enemies_root: Node3D = $World/EnemiesRoot
@onready var hud: Node = $UIRoot/HUD

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var arena_instance: Node3D = null
var null_instance: Node3D = null
var enemies_alive: int = 0

var restarting: bool = false
var wave_transitioning: bool = false

var world_frozen: bool = false

const PLAYER_SAFE_RADIUS: float = 4.0
const ENEMY_SPAWN_MIN_RADIUS: float = 1.8
const ENEMY_SPAWN_PLAYER_MIN_RADIUS: float = 3.0

const FLOOR_RAY_UP: float = 10.0
const FLOOR_RAY_DOWN: float = 80.0
const FLOOR_EPS: float = 0.05

const FADE_TIME: float = 0.25
const WAVE_FREEZE_TIME: float = 0.35

func _ready() -> void:
	rng.randomize()
	Engine.time_scale = 1.0

	Run.reset()
	restarting = false
	wave_transitioning = false

	Signals.request_shoot.connect(_on_request_shoot)
	Signals.request_pickup.connect(_on_request_pickup)
	Signals.request_pull_to_hand.connect(_on_request_pull_to_hand)
	Signals.request_swap.connect(_on_request_swap)
	Signals.null_dropped.connect(_on_null_dropped)

	Signals.enemy_killed.connect(_on_enemy_killed)
	Signals.player_died.connect(_on_player_died)

	_spawn_arena()
	_spawn_player()

	Signals.depth_changed.emit(Run.depth)
	Signals.null_ready_changed.emit(Run.null_ready)

	call_deferred("_wave_transition_first")

func _physics_process(_delta: float) -> void:
	if restarting or wave_transitioning:
		if Engine.time_scale != 1.0:
			Engine.time_scale = 1.0
		return

	# cleanup ref proiettile (se si è auto-distrutto dopo una kill)
	if null_instance != null and not is_instance_valid(null_instance):
		null_instance = null

	# Perk: slowmo mentre il NULL è droppato
	if Run.slowmo_recovery and Run.null_dropped:
		Engine.time_scale = Run.slowmo_scale
	else:
		Engine.time_scale = 1.0

	# Perk: magnet pickup
	if not Run.pickup_magnet:
		return
	if null_instance == null or not is_instance_valid(null_instance):
		return

	var ind := null_instance.get_node_or_null("PickupIndicator")
	if ind == null or not (ind is Sprite3D) or not (ind as Sprite3D).visible:
		return

	_on_request_pickup()

func _wave_transition_first() -> void:
	await _freeze_and_fade(true)
	_spawn_wave()
	await _freeze_and_fade(false)

func _spawn_arena() -> void:
	_free_children(arena_root)

	if arena_scene == null:
		push_error("arena_scene non assegnata.")
		return

	var a := arena_scene.instantiate()
	if not (a is Node3D):
		push_error("arena_scene deve istanziare un Node3D.")
		return

	arena_root.add_child(a)
	arena_instance = a as Node3D

func _spawn_player() -> void:
	_free_children(player_root)

	if player_scene == null:
		push_error("player_scene non assegnata.")
		return

	var p := player_scene.instantiate()
	if not (p is Node3D):
		push_error("player_scene deve istanziare un Node3D.")
		return

	player_root.add_child(p)

	var player := p as Node3D
	var spawn_pos := _get_player_spawn_pos()
	player.global_position = _place_body_on_floor(player, spawn_pos)

func _spawn_wave() -> void:
	if restarting:
		return

	_free_children(enemies_root)
	enemies_alive = 0

	if arena_instance == null:
		return

	var spawns: Array[Node3D] = _get_enemy_spawns()
	if spawns.is_empty():
		spawns.append(_make_temp_marker(Vector3(-8, 0, -8)))
		spawns.append(_make_temp_marker(Vector3(8, 0, -8)))
		spawns.append(_make_temp_marker(Vector3(0, 0, 8)))

	spawns.shuffle()

	var d: int = Run.depth

	# Totale “budget” crescente ma controllato
	var total: int = clampi(2 + d, 2, 10)

	var turrets: int = clampi(floori(float(d) / 3.0), 0, 3)
	var spikes: int = clampi(floori(float(d) / 2.0), 0, 4)

	# Elite rara: da depth 4 in poi, chance crescente fino a ~45%
	var exceptions: int = 0
	if d >= 4:
		var p_elite := clampf(0.12 + float(d - 4) * 0.03, 0.0, 0.45)
		if rng.randf() < p_elite:
			exceptions = 1

	var chasers: int = max(1, total - turrets - spikes - exceptions)

	var player := _get_player()
	var used: Array[int] = []

	for i in range(chasers):
		var idx := _pick_spawn_index(spawns.size(), used)
		used.append(idx)

		var e := _spawn_enemy(chaser_scene, spawns[idx].global_position)
		if e != null and player != null and e.has_method("set_target"):
			e.call("set_target", player)

	for j in range(turrets):
		var idx2 := _pick_spawn_index(spawns.size(), used)
		used.append(idx2)

		var t := _spawn_enemy(turret_scene, spawns[idx2].global_position)
		if t != null and player != null:
			if t.has_method("set_target"):
				t.call("set_target", player)

			if enemy_bullet_scene != null and t.has_method("set_bullet_scene"):
				t.call("set_bullet_scene", enemy_bullet_scene)

			if t.has_method("set_fire_interval"):
				var base_interval: float = 1.6
				var v: Variant = t.get("fire_interval")
				if typeof(v) != TYPE_NIL:
					base_interval = float(v)
				t.call("set_fire_interval", base_interval * Run.turret_interval_mult)

	for k in range(spikes):
		var idx3 := _pick_spawn_index(spawns.size(), used)
		used.append(idx3)

		var s := _spawn_enemy(spike_scene, spawns[idx3].global_position)
		if s != null and player != null and s.has_method("set_target"):
			s.call("set_target", player)

	for m in range(exceptions):
		var idx4 := _pick_spawn_index(spawns.size(), used)
		used.append(idx4)

		var ex := _spawn_enemy(exception_scene, spawns[idx4].global_position)
		if ex != null and player != null and ex.has_method("set_target"):
			ex.call("set_target", player)

	enemies_alive = chasers + turrets + spikes + exceptions

	if player != null:
		_place_player_safe(player, spawns)

func _spawn_enemy(scene: PackedScene, desired_pos: Vector3) -> Node3D:
	if scene == null:
		return null

	var n := scene.instantiate()
	if not (n is Node3D):
		return null

	var body := n as Node3D
	enemies_root.add_child(body)

	body.set_physics_process(not world_frozen)

	var final_pos := _pick_enemy_spawn_position(body, desired_pos)
	body.global_position = final_pos

	return body

func _on_request_shoot(origin: Vector3, direction: Vector3, size_mult: float) -> void:
	if restarting or wave_transitioning:
		return
	if Run.null_ready == false:
		return
	if null_projectile_scene == null:
		push_error("null_projectile_scene non assegnata.")
		return

	Run.null_ready = false
	Run.null_dropped = false
	Signals.null_ready_changed.emit(false)

	var p := null_projectile_scene.instantiate()
	if not (p is Node3D):
		Run.null_ready = true
		Signals.null_ready_changed.emit(true)
		return

	var proj := p as Node3D
	world.add_child(proj)
	null_instance = proj

	if proj.has_method("fire"):
		proj.call("fire", origin, direction, size_mult)
	else:
		proj.global_position = origin
		proj.scale = Vector3.ONE * maxf(0.25, size_mult)

func _on_request_pickup() -> void:
	if restarting or wave_transitioning:
		return
	if null_instance == null or not is_instance_valid(null_instance):
		return

	var player := _get_player()
	if player == null:
		return

	var radius: float = float(Run.pickup_radius)
	if player.global_position.distance_to(null_instance.global_position) > radius:
		return

	if null_instance.has_method("pickup"):
		null_instance.call("pickup")
	else:
		null_instance.queue_free()

	null_instance = null
	Run.null_ready = true
	Run.null_dropped = false
	Signals.null_ready_changed.emit(true)

func _is_null_dropped() -> bool:
	if null_instance == null or not is_instance_valid(null_instance):
		return false
	if null_instance.has_method("is_dropped"):
		return bool(null_instance.call("is_dropped"))

	var ind := null_instance.get_node_or_null("PickupIndicator")
	return ind is Sprite3D and (ind as Sprite3D).visible

func _on_request_pull_to_hand() -> void:
	if restarting or wave_transitioning:
		return
	if not Run.pull_to_hand:
		return
	if not _is_null_dropped():
		return

	var player := _get_player()
	if player == null:
		return

	if player.global_position.distance_to(null_instance.global_position) > Run.pull_max_distance:
		return

	if null_instance.has_method("pickup"):
		null_instance.call("pickup")
	else:
		null_instance.queue_free()

	null_instance = null
	Run.null_ready = true
	Run.null_dropped = false
	Signals.null_ready_changed.emit(true)

func _on_request_swap() -> void:
	if restarting or wave_transitioning:
		return
	if not Run.swap_with_null:
		return
	if Run.swap_cd_left > 0.0:
		return
	if not _is_null_dropped():
		return

	var player := _get_player()
	if player == null:
		return

	var ppos := player.global_position
	var npos := null_instance.global_position

	if ppos.distance_to(npos) > Run.swap_max_distance:
		return

	player.global_position = _place_body_on_floor(player, npos)

	var floor_y := _raycast_floor_y(ppos, player)
	null_instance.global_position = Vector3(ppos.x, floor_y + 0.10, ppos.z)

	Run.swap_cd_left = Run.swap_cooldown

func _on_null_dropped(pos: Vector3) -> void:
	if not Run.drop_shockwave:
		return

	for e in enemies_root.get_children():
		if not (e is Node3D):
			continue
		var n := e as Node3D
		if not n.has_method("add_knockback"):
			continue

		var v := (n.global_position - pos)
		v.y = 0.0
		var d := v.length()
		if d <= 0.001 or d > Run.shockwave_radius:
			continue

		var t: float = clampf(d / Run.shockwave_radius, 0.0, 1.0)
		var s: float = lerpf(Run.shockwave_strength, 0.0, t)
		n.call("add_knockback", v.normalized() * s)

func _on_enemy_killed(enemy: Node) -> void:
	if restarting or wave_transitioning:
		return

	if is_instance_valid(enemy):
		enemy.queue_free()

	enemies_alive -= 1

	if enemies_alive <= 0:
		# con PIERCE il proiettile può essere ancora in volo → lo recuperiamo
		_force_null_return()

		Run.depth += 1
		Signals.depth_changed.emit(Run.depth)

		Run.grant_random_perk(rng)
		Signals.perk_granted.emit(Run.last_perk_title, Run.last_perk_desc)

		call_deferred("_wave_transition")

func _force_null_return() -> void:
	if null_instance != null and is_instance_valid(null_instance):
		if null_instance.has_method("pickup"):
			null_instance.call("pickup")
		else:
			null_instance.queue_free()
		null_instance = null

	Run.null_ready = true
	Run.null_dropped = false
	Signals.null_ready_changed.emit(true)

func _wave_transition() -> void:
	if restarting or wave_transitioning:
		return
	wave_transitioning = true

	await _freeze_and_fade(true)
	_spawn_wave()
	await _freeze_and_fade(false)

	wave_transitioning = false

func _freeze_and_fade(to_black: bool) -> void:
	_set_world_frozen(true)

	if to_black:
		if hud != null and hud.has_method("fade_out"):
			await hud.fade_out(FADE_TIME)
		await get_tree().create_timer(WAVE_FREEZE_TIME).timeout
	else:
		if hud != null and hud.has_method("fade_in"):
			await hud.fade_in(FADE_TIME)
		_set_world_frozen(false)

func _set_world_frozen(v: bool) -> void:
	world_frozen = v

	var player := _get_player()
	if player != null:
		player.set_physics_process(not v)

	for e in enemies_root.get_children():
		if e is Node:
			(e as Node).set_physics_process(not v)

func _on_player_died() -> void:
	if restarting:
		return
	restarting = true
	Engine.time_scale = 1.0
	Run.reset()
	get_tree().call_deferred("reload_current_scene")

# --- resto invariato (spawnpoints / floor helpers / free children) ---

func _get_enemy_spawns() -> Array[Node3D]:
	var out: Array[Node3D] = []
	if arena_instance == null:
		return out

	var sp := arena_instance.get_node_or_null("SpawnPoints")
	if sp == null:
		return out

	for c in sp.get_children():
		if c is Node3D and (c as Node3D).name != "PlayerSpawn":
			out.append(c as Node3D)
	return out

func _get_player_spawn_pos() -> Vector3:
	if arena_instance == null:
		return Vector3.ZERO
	var n := arena_instance.get_node_or_null("SpawnPoints/PlayerSpawn")
	if n is Node3D:
		return (n as Node3D).global_position
	return Vector3.ZERO

func _pick_spawn_index(max_count: int, used: Array[int]) -> int:
	if max_count <= 0:
		return 0
	for _i in range(64):
		var r := rng.randi_range(0, max_count - 1)
		if not used.has(r):
			return r
	return rng.randi_range(0, max_count - 1)

func _place_player_safe(player: Node3D, spawns: Array[Node3D]) -> void:
	var candidates := spawns.duplicate()
	candidates.shuffle()

	for m in candidates:
		if _is_position_safe(m.global_position):
			player.global_position = _place_body_on_floor(player, m.global_position)
			return

func _is_position_safe(pos: Vector3) -> bool:
	var r2 := PLAYER_SAFE_RADIUS * PLAYER_SAFE_RADIUS
	for e in enemies_root.get_children():
		if e is Node3D:
			var ep := (e as Node3D).global_position
			var dx := ep.x - pos.x
			var dz := ep.z - pos.z
			if (dx * dx + dz * dz) < r2:
				return false
	return true

func _pick_enemy_spawn_position(body: Node3D, desired_pos: Vector3) -> Vector3:
	var player := _get_player()

	for _i in range(24):
		var angle := rng.randf_range(0.0, TAU)
		var radius := rng.randf_range(0.0, 2.2)
		var candidate := desired_pos + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		var placed := _place_body_on_floor(body, candidate)

		if not _is_enemy_spawn_clear(placed, body, ENEMY_SPAWN_MIN_RADIUS):
			continue

		if player != null:
			var dxp := player.global_position.x - placed.x
			var dzp := player.global_position.z - placed.z
			if (dxp * dxp + dzp * dzp) < (ENEMY_SPAWN_PLAYER_MIN_RADIUS * ENEMY_SPAWN_PLAYER_MIN_RADIUS):
				continue

		return placed

	return _place_body_on_floor(body, desired_pos)

func _is_enemy_spawn_clear(pos: Vector3, exclude: Node3D, min_radius: float) -> bool:
	var r2 := min_radius * min_radius
	for e in enemies_root.get_children():
		if e == exclude:
			continue
		if e is Node3D:
			var ep := (e as Node3D).global_position
			var dx := ep.x - pos.x
			var dz := ep.z - pos.z
			if (dx * dx + dz * dz) < r2:
				return false
	return true

func _get_player() -> Node3D:
	if player_root.get_child_count() <= 0:
		return null
	return player_root.get_child(0) as Node3D

func _make_temp_marker(p: Vector3) -> Node3D:
	var m := Node3D.new()
	m.global_position = p
	return m

func _place_body_on_floor(body: Node3D, desired_pos: Vector3) -> Vector3:
	var floor_y: float = _raycast_floor_y(desired_pos, body)
	var offset_y: float = _compute_body_floor_offset_y(body)
	return Vector3(desired_pos.x, floor_y + offset_y, desired_pos.z)

func _raycast_floor_y(pos: Vector3, exclude_body: Node3D) -> float:
	var vp := get_viewport()
	if vp == null:
		return pos.y

	var w: World3D = vp.get_world_3d()
	if w == null:
		return pos.y

	var space: PhysicsDirectSpaceState3D = w.direct_space_state

	var from_pos: Vector3 = pos + Vector3(0, FLOOR_RAY_UP, 0)
	var to_pos: Vector3 = pos - Vector3(0, FLOOR_RAY_DOWN, 0)

	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from_pos, to_pos)
	query.collide_with_areas = false
	query.collide_with_bodies = true

	if exclude_body != null and exclude_body is CollisionObject3D:
		query.exclude = [(exclude_body as CollisionObject3D).get_rid()]

	var hit: Dictionary = space.intersect_ray(query)
	if not hit.is_empty() and hit.has("position"):
		return (hit["position"] as Vector3).y
	return pos.y

func _compute_body_floor_offset_y(body: Node3D) -> float:
	var cs: CollisionShape3D = _find_first_collision_shape(body)
	if cs == null or cs.shape == null:
		return 1.0 + FLOOR_EPS

	var half_height: float = 0.5
	var sh: Shape3D = cs.shape

	if sh is CapsuleShape3D:
		var cap := sh as CapsuleShape3D
		half_height = (cap.height * 0.5) + cap.radius
	elif sh is BoxShape3D:
		var box := sh as BoxShape3D
		half_height = box.size.y * 0.5
	elif sh is SphereShape3D:
		var sph := sh as SphereShape3D
		half_height = sph.radius
	elif sh is CylinderShape3D:
		var cyl := sh as CylinderShape3D
		half_height = cyl.height * 0.5

	var cs_y_in_body: float = body.to_local(cs.global_position).y
	var bottom_local: float = cs_y_in_body - half_height
	return -bottom_local + FLOOR_EPS

func _find_first_collision_shape(root: Node) -> CollisionShape3D:
	for c in root.get_children():
		if c is CollisionShape3D:
			return c as CollisionShape3D
		var found := _find_first_collision_shape(c)
		if found != null:
			return found
	return null

func _free_children(n: Node) -> void:
	for c in n.get_children():
		c.free()
