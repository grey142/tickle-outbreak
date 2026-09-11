extends Node3D
class_name ArenaBuilder
## Builds a simple city-block / streets arena with CSG.

var spawn_points: Array[Vector3] = []

func build() -> void:
	# Floor
	var floor_csg := CSGBox3D.new()
	floor_csg.size = Vector3(80, 1, 80)
	floor_csg.position = Vector3(0, -0.5, 0)
	floor_csg.use_collision = true
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.25, 0.25, 0.28)
	floor_csg.material = floor_mat
	add_child(floor_csg)

	# Street cross
	_street(Vector3(0, 0.01, 0), Vector3(80, 0.05, 10), Color(0.15, 0.15, 0.16))
	_street(Vector3(0, 0.01, 0), Vector3(10, 0.05, 80), Color(0.15, 0.15, 0.16))

	# Buildings in a city-block grid
	var positions := [
		Vector3(-20, 0, -20), Vector3(20, 0, -20),
		Vector3(-20, 0, 20), Vector3(20, 0, 20),
		Vector3(-30, 0, 0), Vector3(30, 0, 0),
		Vector3(0, 0, -30), Vector3(0, 0, 30),
		Vector3(-25, 0, -10), Vector3(25, 0, 10),
	]
	var heights := [6.0, 10.0, 8.0, 12.0, 7.0, 9.0, 5.0, 11.0, 8.0, 6.0]
	for i in positions.size():
		_building(positions[i], heights[i], Color(0.35 + 0.05 * (i % 3), 0.38, 0.42))

	# Perimeter walls
	_wall(Vector3(0, 2, -40), Vector3(80, 4, 1))
	_wall(Vector3(0, 2, 40), Vector3(80, 4, 1))
	_wall(Vector3(-40, 2, 0), Vector3(1, 4, 80))
	_wall(Vector3(40, 2, 0), Vector3(1, 4, 80))

	# Spawn points around streets
	spawn_points = [
		Vector3(-15, 0.1, -15), Vector3(15, 0.1, -15),
		Vector3(-15, 0.1, 15), Vector3(15, 0.1, 15),
		Vector3(-28, 0.1, 5), Vector3(28, 0.1, -5),
		Vector3(5, 0.1, -28), Vector3(-5, 0.1, 28),
		Vector3(-18, 0.1, 0), Vector3(18, 0.1, 0),
		Vector3(0, 0.1, -18), Vector3(0, 0.1, 18),
	]

	# Lighting
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 30, 0)
	sun.light_energy = 1.2
	add_child(sun)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.45, 0.55, 0.7)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.4, 0.45, 0.5)
	e.ambient_light_energy = 0.6
	env.environment = e
	add_child(env)

func _street(pos: Vector3, size: Vector3, color: Color) -> void:
	var s := CSGBox3D.new()
	s.size = size
	s.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	s.material = mat
	add_child(s)

func _building(pos: Vector3, height: float, color: Color) -> void:
	var b := CSGBox3D.new()
	b.size = Vector3(8, height, 8)
	b.position = pos + Vector3(0, height * 0.5, 0)
	b.use_collision = true
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	b.material = mat
	add_child(b)

func _wall(pos: Vector3, size: Vector3) -> void:
	var w := CSGBox3D.new()
	w.size = size
	w.position = pos
	w.use_collision = true
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.3, 0.32)
	w.material = mat
	add_child(w)
