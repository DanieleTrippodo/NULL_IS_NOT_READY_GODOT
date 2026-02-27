# res://Game/Game.gd
extends Node

@export var arena_scene: PackedScene
@export var player_scene: PackedScene
@export var null_projectile_scene: PackedScene
@export var chaser_scene: PackedScene
@export var turret_scene: PackedScene
@export var enemy_bullet_scene: PackedScene

@onready var arena_root: Node3D = $World/ArenaRoot
@onready var player_root: Node3D = $World/PlayerRoot
@onready var enemies_root: Node3D = $World/EnemiesRoot
@onready var hud: Node = $UIRoot/HUD

var arena_instance: Node3D = null
var null_instance: Node3D = null
var enemies_alive: int = 0

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

const PLAYER_SAFE_RADIUS: float = 4.0
const FLOOR_RAY_UP: float = 10.0
const FLOOR_RAY_DOWN: float = 50.0
const FLOOR_EPS: float = 0.05

var restarting: bool = false
var wave_transitioning: bool = false


func _ready() -> void:
	rng.randomize()
	Run.reset()
	restarting = false
	wave_transitioning = false

	Signals.request_shoot.connect(_on_request_shoot)
	Signals.request_pickup.connect(_on_request_pickup)
	Signals.enemy_killed.connect(_on_enemy_killed)
	Signals.player_died.connect(_on_player_died)

	_spawn_arena()
	_spawn_player()
	_spawn_wave()


# -------------------------
# Spawn helpers
# -------------------------
func _spawn_arena() -> void:
	if arena_scene == null:
		push_error("arena_scene non assegnata in Main (inspector).")
		return

	for c in arena_root.get_children():
		c.queue_free()

	var a := arena_scene.instantiate() as Node3D
	if a == null:
		push_error("Arena non è un Node3D.")
		return

	arena_root.add_child(a)
	arena_instance = a


func _spawn_player() -> void:
	if player_scene == null:
		push_error("player_scene non assegnata in Main (inspector).")
		return

	for c in player_root.get_children():
		c.queue_free()

	var p := player_scene.instantiate() as Node3D
	if p == null:
		push_error("Player non è un Node3D.")
		return

	player_root.add_child(p)


func _spawn_wave() -> void:
	if restarting:
		return

	if chaser_scene == null or turret_scene == null or enemy_bullet_scene == null:
		push_error("Scene nemici non assegnate (chaser/turret/enemy_bullet).")
		return
	if arena_instance == null:
		return

	# pulizia nemici vecchi
	for c in enemies_root.get_children():
		c.queue_free()

	# spawn points
	var spawns: Array[Marker3D] = []
	if arena_instance.has_method("get_spawn_points"):
		for s in arena_instance.get_spawn_points():
			if s is Marker3D and s.name != "PlayerSpawn":
				spawns.append(s)

	if spawns.is_empty():
		spawns.append(_make_temp_marker(Vector3(-8, 0, -8)))
		spawns.append(_make_temp_marker(Vector3( 8, 0, -8)))
		spawns.append(_make_temp_marker(Vector3( 0, 0,  8)))

	spawns.shuffle()

	var player := player_root.get_child(0) as Node3D
	enemies_alive = 0

	# composizione wave
	var chasers: int = 2 + floori(float(Run.depth - 1) / 2.0)
	chasers = min(max(chasers, 2), 6)

	var turrets: int = floori(float(Run.depth) / 3.0)
	turrets = min(max(turrets, 0), 3)

	if chasers + turrets <= 0:
		chasers = 1

	var used: Array[int] = []

	# chasers
	for i in range(chasers):
		var e := chaser_scene.instantiate() as Node3D
		if e == null:
			continue
		enemies_root.add_child(e)
		enemies_alive += 1

		var idx := _pick_spawn_index(spawns.size(), used)
		_place_body_on_floor(e, spawns[idx].global_position)

		if e.has_method("set_target"):
			e.set_target(player)

	# turrets
	for j in range(turrets):
		var t := turret_scene.instantiate() as Node3D
		if t == null:
			continue
		enemies_root.add_child(t)
		enemies_alive += 1

		var idx2 := _pick_spawn_index(spawns.size(), used)
		_place_body_on_floor(t, spawns[idx2].global_position)

		if t.has_method("set_target"):
			t.set_target(player)
		if t.has_method("set_bullet_scene"):
			t.set_bullet_scene(enemy_bullet_scene)

		# perk: turrets più lenti
		if t.has_method("set_fire_interval"):
			var base_interval: float = 1.6
			var v: Variant = t.get("fire_interval")
			if v != null:
				base_interval = float(v)
			t.set_fire_interval(base_interval * Run.turret_interval_mult)

	_place_player_safe(player, spawns)


func _pick_spawn_index(max_count: int, used: Array[int]) -> int:
	if max_count <= 0:
		return 0
	for _k in range(20):
		var idx: int = rng.randi_range(0, max_count - 1)
		if not used.has(idx):
			used.append(idx)
			return idx
	return rng.randi_range(0, max_count - 1)


func _place_player_safe(player: Node3D, spawns: Array[Marker3D]) -> void:
	var ps := arena_instance.get_node_or_null("SpawnPoints/PlayerSpawn") as Marker3D
	if ps != null and _is_position_safe(ps.global_position):
		_place_body_on_floor(player, ps.global_position)
		return

	var candidates := spawns.duplicate()
	candidates.shuffle()
	for m in candidates:
		if _is_position_safe(m.global_position):
			_place_body_on_floor(player, m.global_position)
			return

	_place_body_on_floor(player, Vector3(0, 0, 0))


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


func _make_temp_marker(p: Vector3) -> Marker3D:
	var m := Marker3D.new()
	m.global_position = p
	return m


# -------------------------
# Floor snap (anti-jitter)
# -------------------------
func _place_body_on_floor(body: Node3D, desired_pos: Vector3) -> void:
	var floor_y := _raycast_floor_y(desired_pos)
	var offset_y := _compute_body_floor_offset_y(body)
	body.global_position = Vector3(desired_pos.x, floor_y + offset_y, desired_pos.z)


func _raycast_floor_y(pos: Vector3) -> float:
	var from_pos := pos + Vector3(0, FLOOR_RAY_UP, 0)
	var to_pos := pos - Vector3(0, FLOOR_RAY_DOWN, 0)

	var world := get_viewport().get_world_3d()
	if world == null:
		return pos.y

	var space := world.direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from_pos, to_pos)
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var hit := space.intersect_ray(query)
	if hit.size() > 0 and hit.has("position"):
		return (hit["position"] as Vector3).y
	return pos.y


func _compute_body_floor_offset_y(body: Node3D) -> float:
	var cs := _find_first_collision_shape(body)
	if cs == null or cs.shape == null:
		return 1.0 + FLOOR_EPS

	var half_h: float = 0.5
	var shape := cs.shape

	if shape is CapsuleShape3D:
		var cap := shape as CapsuleShape3D
		half_h = (cap.height * 0.5) + cap.radius
	elif shape is BoxShape3D:
		var box := shape as BoxShape3D
		half_h = box.size.y * 0.5
	elif shape is SphereShape3D:
		var sph := shape as SphereShape3D
		half_h = sph.radius
	elif shape is CylinderShape3D:
		var cyl := shape as CylinderShape3D
		half_h = cyl.height * 0.5

	var cs_y_in_body := body.to_local(cs.global_position).y
	var bottom_local := cs_y_in_body - half_h
	return -bottom_local + FLOOR_EPS


func _find_first_collision_shape(root: Node) -> CollisionShape3D:
	for c in root.get_children():
		if c is CollisionShape3D:
			return c
		var found := _find_first_collision_shape(c)
		if found != null:
			return found
	return null


# -------------------------
# Input / Shoot / Pickup
# -------------------------
func _on_request_shoot(origin: Vector3, direction: Vector3) -> void:
	if restarting or wave_transitioning:
		return
	if Run.null_ready == false:
		return

	Run.null_ready = false
	Signals.null_ready_changed.emit(false)

	var p := null_projectile_scene.instantiate() as Node3D
	null_instance = p
	$World.add_child(p)

	if p.has_method("fire"):
		p.fire(origin, direction)


func _on_request_pickup() -> void:
	if restarting or wave_transitioning:
		return
	if null_instance == null:
		return

	var player := player_root.get_child(0) as Node3D
	if player.global_position.distance_to(null_instance.global_position) > Run.pickup_radius:
		return

	if null_instance.has_method("pickup"):
		null_instance.pickup()

	null_instance = null
	Run.null_ready = true
	Signals.null_ready_changed.emit(true)


func _on_enemy_killed(enemy: Node) -> void:
	if restarting or wave_transitioning:
		return

	if is_instance_valid(enemy):
		enemy.queue_free()

	enemies_alive -= 1

	Run.null_ready = true
	Signals.null_ready_changed.emit(true)

	if enemies_alive <= 0:
		Run.depth += 1
		Run.grant_random_perk(rng)
		Signals.perk_granted.emit(Run.last_perk_title, Run.last_perk_desc)
		Signals.depth_changed.emit(Run.depth)

		call_deferred("_wave_transition")


func _wave_transition() -> void:
	if restarting or wave_transitioning:
		return

	wave_transitioning = true

	# freeze
	if player_root.get_child_count() > 0:
		player_root.get_child(0).set_physics_process(false)
	for e in enemies_root.get_children():
		e.set_physics_process(false)

	await get_tree().create_timer(0.25).timeout

	# fade to black
	if hud != null and hud.has_method("fade_out"):
		await hud.fade_out(0.25)

	# spawn in nero
	_spawn_wave()

	# congela anche i nuovi nemici appena spawnati
	if player_root.get_child_count() > 0:
		player_root.get_child(0).set_physics_process(false)
	for e2 in enemies_root.get_children():
		e2.set_physics_process(false)

	# fade back
	if hud != null and hud.has_method("fade_in"):
		await hud.fade_in(0.25)

	# unfreeze
	if player_root.get_child_count() > 0:
		player_root.get_child(0).set_physics_process(true)
	for e3 in enemies_root.get_children():
		e3.set_physics_process(true)

	wave_transitioning = false


func _on_player_died() -> void:
	if restarting:
		return
	restarting = true
	Run.reset()
	get_tree().call_deferred("reload_current_scene")
