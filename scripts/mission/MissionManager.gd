extends Node
class_name MissionManager
## Spawns zombies, tracks kill quota, handles screamers doubling spawn rate.

signal quota_updated(kills: int, quota: int)
signal cleared
signal failed(reason: String)

var kills: int = 0
var quota: int = 15
var spawn_timer: float = 0.0
var spawn_interval: float = 2.5
var max_alive: int = 8
var arena_spawns: Array[Vector3] = []
var zombie_scene_script := preload("res://scripts/zombies/Zombie.gd")
var running: bool = false
var parent_world: Node3D

func start_mission(world: Node3D, spawn_points: Array[Vector3]) -> void:
	parent_world = world
	arena_spawns = spawn_points
	kills = 0
	var m := DataManager.missions
	var n := GameState.mission_number
	quota = int(m.get("base_kill_quota", 15)) + (n - 1) * int(m.get("kills_per_mission_scale", 5))
	spawn_interval = float(m.get("base_spawn_interval", 2.5)) * pow(float(m.get("spawn_interval_scale", 0.92)), n - 1)
	spawn_interval = maxf(spawn_interval, float(m.get("min_spawn_interval", 0.7)))
	max_alive = mini(int(m.get("max_alive_base", 8)) + (n - 1) * int(m.get("max_alive_per_mission", 1)), int(m.get("max_alive_cap", 20)))
	running = true
	spawn_timer = 0.5
	quota_updated.emit(kills, quota)
	EventBus.mission_progress.emit(kills, quota)
	if not EventBus.zombie_killed.is_connected(_on_zombie_killed):
		EventBus.zombie_killed.connect(_on_zombie_killed)
	if not EventBus.player_died.is_connected(_on_player_died):
		EventBus.player_died.connect(_on_player_died)

func _process(delta: float) -> void:
	if not running:
		return
	spawn_timer -= delta
	var interval := spawn_interval
	# Screamer doubles spawn rates while active
	var screamers := get_tree().get_nodes_in_group("screamers")
	if not screamers.is_empty():
		interval *= 0.5  # double rate = half interval
	if spawn_timer <= 0.0:
		spawn_timer = interval
		_try_spawn()

func _try_spawn() -> void:
	var alive := get_tree().get_nodes_in_group("zombies").size()
	if alive >= max_alive:
		return
	if arena_spawns.is_empty():
		return
	var pos: Vector3 = arena_spawns[randi() % arena_spawns.size()]
	var type_def := _pick_type()
	if type_def.is_empty():
		return
	var z := CharacterBody3D.new()
	z.set_script(zombie_scene_script)
	parent_world.add_child(z)
	z.global_position = pos
	z.setup(type_def)

func _pick_type() -> Dictionary:
	var mission_n := GameState.mission_number
	var pool: Array = []
	var total_w := 0
	for t in DataManager.zombie_types:
		var unlock := int(t.get("unlock_mission", 1))
		if mission_n >= unlock:
			var w := int(t.get("spawn_weight", 1))
			pool.append({"def": t, "w": w})
			total_w += w
	if total_w <= 0 or pool.is_empty():
		return {}
	var roll := randi() % total_w
	var acc := 0
	for entry in pool:
		acc += int(entry.w)
		if roll < acc:
			return entry.def
	return pool[0].def

func _on_zombie_killed(_id: String, _melee: bool, _bonus: int) -> void:
	if not running:
		return
	kills += 1
	quota_updated.emit(kills, quota)
	EventBus.mission_progress.emit(kills, quota)
	if kills >= quota:
		running = false
		EventBus.mission_cleared.emit()
		cleared.emit()

func _on_player_died(reason: String) -> void:
	running = false
	failed.emit(reason)

func stop() -> void:
	running = false
