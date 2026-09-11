extends Node3D
## Mission scene root: builds arena, spawns player, wires systems.

const PlayerScript := preload("res://scripts/player/PlayerController.gd")

func _ready() -> void:
	GameState.prepare_mission()
	var arena := ArenaBuilder.new()
	arena.name = "Arena"
	add_child(arena)
	arena.build()

	var player := _spawn_player()
	var tickle := TickleSystem.new()
	tickle.name = "TickleSystem"
	add_child(tickle)
	tickle.setup(player)

	var mission := MissionManager.new()
	mission.name = "MissionManager"
	add_child(mission)
	mission.start_mission(self, arena.spawn_points)

	# HUD / overlays are child scenes in Mission.tscn
	var hud := get_node_or_null("HUD")
	if hud and hud.has_method("bind_player"):
		hud.bind_player(player)

func _spawn_player() -> PlayerController:
	var p := CharacterBody3D.new()
	p.set_script(PlayerScript)
	p.name = "Player"
	# Build node tree expected by PlayerController
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 1.6, 0)
	p.add_child(head)
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.current = true
	head.add_child(cam)
	var ray := RayCast3D.new()
	ray.name = "GunRay"
	ray.target_position = Vector3(0, 0, -100)
	ray.enabled = true
	cam.add_child(ray)
	var melee := Area3D.new()
	melee.name = "MeleeArea"
	cam.add_child(melee)
	var wv := Node3D.new()
	wv.name = "WeaponView"
	cam.add_child(wv)
	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = 1.6
	col.shape = shape
	col.position.y = 0.9
	p.add_child(col)
	add_child(p)
	p.global_position = Vector3(0, 0.1, 0)
	return p as PlayerController
