extends CharacterBody3D
class_name PlayerController
## First-person controller: WASD, mouse look, jump, dash (stamina).
## Optional touch APIs for mobile landscape controls (move/look/fire).

@onready var camera: Camera3D = $Head/Camera3D
@onready var head: Node3D = $Head
@onready var gun_ray: RayCast3D = $Head/Camera3D/GunRay
@onready var melee_area: Area3D = $Head/Camera3D/MeleeArea
@onready var weapon_view: Node3D = $Head/Camera3D/WeaponView

var health: float = 100.0
var stamina: float = 100.0
var max_health: float = 100.0
var max_stamina: float = 100.0
var move_speed_stat: float = 100.0
var slow_penalty: float = 0.0  # from tickling elites

var ammo_reserve: int = 50
var clip: int = 12
var is_reloading: bool = false
var reload_timer: float = 0.0
var fire_cooldown: float = 0.0
var melee_cooldown: float = 0.0

var dash_timer: float = 0.0
var dash_dir: Vector3 = Vector3.ZERO
var mouse_captured: bool = true

## Touch / mobile control injection (used alongside keyboard/mouse)
var mobile_controls_active: bool = false
var touch_move: Vector2 = Vector2.ZERO
var touch_firing: bool = false

var _gun: Dictionary = {}
var _melee: Dictionary = {}
## One-shot melee request from mobile MELEE button (ignored InputMap mouse when mobile).
var touch_melee_queued: bool = false
var _look_smooth: Vector2 = Vector2.ZERO

func _ready() -> void:
	add_to_group("player")
	if not mobile_controls_active:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		mouse_captured = true
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		mouse_captured = false
	_apply_stats_from_state()
	_equip_from_state()
	EventBus.hud_refresh.emit()

func set_mobile_controls_active(active: bool) -> void:
	mobile_controls_active = active
	if active:
		mouse_captured = false
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		touch_move = Vector2.ZERO
		touch_firing = false
		touch_melee_queued = false
	else:
		# Restore desktop capture when leaving touch mode (unless paused UI)
		touch_firing = false
		touch_melee_queued = false
		mouse_captured = true
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func set_touch_move(v: Vector2) -> void:
	touch_move = v.limit_length(1.0)

func set_touch_firing(pressed: bool) -> void:
	touch_firing = pressed

func request_melee() -> void:
	## Called by MobileControls on MELEE button_down (one-shot).
	touch_melee_queued = true

func _apply_stats_from_state() -> void:
	max_health = GameState.get_max_health()
	max_stamina = GameState.get_max_stamina()
	move_speed_stat = GameState.get_speed()
	health = max_health
	stamina = max_stamina
	ammo_reserve = GameState.get_ammo_capacity()

func _equip_from_state() -> void:
	_gun = DataManager.get_gun(GameState.equipped_gun)
	_melee = DataManager.get_melee(GameState.equipped_melee)
	clip = int(_gun.get("clip_size", 12))
	_update_weapon_mesh()

func _update_weapon_mesh() -> void:
	for c in weapon_view.get_children():
		c.queue_free()
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.08, 0.12, 0.35)
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.2, 0.25)
	mesh.material_override = mat
	mesh.position = Vector3(0.25, -0.2, -0.4)
	weapon_view.add_child(mesh)
	# Simple FPS arm
	var arm := MeshInstance3D.new()
	var arm_box := BoxMesh.new()
	arm_box.size = Vector3(0.12, 0.12, 0.35)
	arm.mesh = arm_box
	var arm_mat := StandardMaterial3D.new()
	arm_mat.albedo_color = Color(0.85, 0.7, 0.55)
	arm.material_override = arm_mat
	arm.position = Vector3(0.28, -0.28, -0.25)
	weapon_view.add_child(arm)

func apply_look_delta(scaled: Vector2) -> void:
	## Shared look path for mouse + touch (scaled already includes sensitivity).
	_look_smooth = _look_smooth.lerp(scaled, 0.45)
	var apply := _look_smooth
	_look_smooth = _look_smooth.lerp(Vector2.ZERO, 0.35)
	head.rotate_y(-apply.x)
	camera.rotate_x(-apply.y)
	camera.rotation.x = clampf(camera.rotation.x, deg_to_rad(-85), deg_to_rad(85))

func apply_touch_look(relative_scaled: Vector2) -> void:
	## relative_scaled already includes touch sensitivity (radians-ish scale).
	apply_look_delta(relative_scaled)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and mouse_captured and not mobile_controls_active:
		var sens := float(DataManager.player_stats.get("mouse_sensitivity", 0.002))
		apply_look_delta(event.relative * sens)
	if event.is_action_pressed("ui_cancel"):
		if mobile_controls_active:
			# Esc toggles force-mobile off when forced from desktop; otherwise no-op capture
			if GameState.force_mobile_controls:
				GameState.force_mobile_controls = false
			return
		mouse_captured = not mouse_captured
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if mouse_captured else Input.MOUSE_MODE_VISIBLE)

func _physics_process(delta: float) -> void:
	if health <= 0.0:
		return

	var gravity: float = float(DataManager.player_stats.get("gravity", 9.8))
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Dash
	if dash_timer > 0.0:
		dash_timer -= delta
		var dash_mult := float(DataManager.player_stats.get("dash_speed_multiplier", 2.5))
		var speed_scale := float(DataManager.player_stats.get("speed_godot_scale", 0.08))
		var dash_spd := maxf(move_speed_stat - slow_penalty, 10.0) * speed_scale * dash_mult
		velocity.x = dash_dir.x * dash_spd
		velocity.z = dash_dir.z * dash_spd
		move_and_slide()
		_tick_combat(delta)
		return

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if touch_move.length_squared() > 0.0001:
		# Blend: touch wins when active (virtual stick), else keyboard
		input_dir = touch_move
	var basis_y := head.global_transform.basis
	var direction := (basis_y * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var speed_scale := float(DataManager.player_stats.get("speed_godot_scale", 0.08))
	var spd := maxf(move_speed_stat - slow_penalty, 10.0) * speed_scale

	if direction != Vector3.ZERO:
		velocity.x = direction.x * spd
		velocity.z = direction.z * spd
	else:
		velocity.x = move_toward(velocity.x, 0, spd)
		velocity.z = move_toward(velocity.z, 0, spd)

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = float(DataManager.player_stats.get("jump_velocity", 4.5))

	if Input.is_action_just_pressed("dash") and stamina >= float(DataManager.player_stats.get("dash_stamina_cost", 25)):
		var cost := float(DataManager.player_stats.get("dash_stamina_cost", 25))
		stamina -= cost
		dash_timer = float(DataManager.player_stats.get("dash_duration", 0.25))
		if direction != Vector3.ZERO:
			dash_dir = direction
		else:
			dash_dir = -head.global_transform.basis.z
		dash_dir.y = 0
		dash_dir = dash_dir.normalized()

	# Stamina regen when not being drained heavily
	var regen := float(DataManager.player_stats.get("stamina_regen_per_sec", 8))
	stamina = minf(stamina + regen * delta, max_stamina)

	move_and_slide()
	_tick_combat(delta)
	slow_penalty = 0.0  # elites re-apply each frame via TickleSystem
	EventBus.hud_refresh.emit()

func _tick_combat(delta: float) -> void:
	if fire_cooldown > 0.0:
		fire_cooldown -= delta
	if melee_cooldown > 0.0:
		melee_cooldown -= delta
	if is_reloading:
		reload_timer -= delta
		if reload_timer <= 0.0:
			_finish_reload()
		return

	# Mobile: only FIRE button (touch_firing). Desktop: mouse InputMap "fire".
	var firing: bool
	if mobile_controls_active:
		firing = touch_firing
	else:
		firing = Input.is_action_pressed("fire")
	if GameState.cheat_infinite_ammo and clip <= 0:
		clip = int(_gun.get("clip_size", 12))
		ammo_reserve = maxi(ammo_reserve, GameState.get_ammo_capacity())
	if firing and fire_cooldown <= 0.0 and clip > 0:
		_fire()
	elif firing and clip <= 0 and ammo_reserve > 0:
		_start_reload()

	if Input.is_action_just_pressed("reload") and not is_reloading:
		_start_reload()

	# Mobile: only MELEE button via request_melee(). Desktop: keyboard/mouse melee action.
	var want_melee := false
	if mobile_controls_active:
		want_melee = touch_melee_queued
		touch_melee_queued = false
	else:
		want_melee = Input.is_action_just_pressed("melee")
	if want_melee and melee_cooldown <= 0.0:
		_do_melee()

	# Consumables hotkeys 1-4
	if Input.is_action_just_pressed("use_health"):
		_try_consumable("health_potion")
	if Input.is_action_just_pressed("use_energy"):
		_try_consumable("energy_drink")
	if Input.is_action_just_pressed("use_ammo"):
		_try_consumable("bullets")
	if Input.is_action_just_pressed("use_alcohol"):
		_try_consumable("alcohol")

func _fire() -> void:
	var rof := float(_gun.get("rate_of_fire", 1.0))
	fire_cooldown = 1.0 / maxf(rof, 0.01)
	if not GameState.cheat_infinite_ammo:
		clip -= 1
	var aim_penalty := GameState.alcohol_aim_penalty
	var gun_type := String(_gun.get("type", "hitscan"))
	if gun_type == "shotgun":
		_fire_shotgun(aim_penalty)
	else:
		_hitscan_shot(float(_gun.get("damage", 1)), float(_gun.get("spread_degrees", 1)) + aim_penalty, float(_gun.get("range", 100)))

func _fire_shotgun(aim_penalty: float) -> void:
	var dmg := float(_gun.get("damage", 1))
	var max_range := float(_gun.get("range", 8))
	var center_n := int(_gun.get("center_pellets", 25))
	var outer_n := int(_gun.get("outer_pellets", 7))
	var center_spread := float(_gun.get("spread_degrees", 8)) + aim_penalty
	var outer_spread := float(_gun.get("outer_spread_degrees", 18)) + aim_penalty
	for i in center_n:
		_hitscan_shot(dmg, center_spread, max_range, true)
	for i in outer_n:
		_hitscan_shot(dmg, outer_spread, max_range, true)

func _hitscan_shot(damage: float, spread_deg: float, max_range: float, is_pellet: bool = false) -> void:
	var origin := camera.global_position
	var forward := -camera.global_transform.basis.z
	var spread_rad := deg_to_rad(spread_deg)
	var dir := (forward + Vector3(randf_range(-spread_rad, spread_rad), randf_range(-spread_rad, spread_rad), randf_range(-spread_rad, spread_rad))).normalized()
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * max_range)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = [self]
	var result := space.intersect_ray(query)
	if result.is_empty():
		return
	_apply_hitscan_hit(result, damage, is_pellet)

func _apply_hitscan_hit(result: Dictionary, damage: float, is_pellet: bool = false) -> void:
	var collider: Object = result.collider
	var hit_pos: Vector3 = result.get("position", Vector3.ZERO)
	if collider is Area3D and collider.get_parent() and collider.get_parent().has_method("take_damage"):
		var is_head := String(collider.name).to_lower().contains("head")
		collider.get_parent().take_damage(damage, is_head, false, not is_pellet)
		return
	if collider is Node and collider.has_method("take_damage"):
		# Body collider hit — treat upper third as head
		var is_head := false
		if collider is Node3D:
			var n3 := collider as Node3D
			var local_y := hit_pos.y - n3.global_position.y
			is_head = local_y > 1.4
		collider.take_damage(damage, is_head, false, not is_pellet)

func _start_reload() -> void:
	if is_reloading:
		return
	var clip_size := int(_gun.get("clip_size", 12))
	if clip >= clip_size or ammo_reserve <= 0:
		return
	is_reloading = true
	reload_timer = float(_gun.get("reload_time", 3.0))

func _finish_reload() -> void:
	is_reloading = false
	var clip_size := int(_gun.get("clip_size", 12))
	if GameState.cheat_infinite_ammo:
		clip = clip_size
		ammo_reserve = maxi(ammo_reserve, GameState.get_ammo_capacity())
		return
	var need := clip_size - clip
	var take := mini(need, ammo_reserve)
	clip += take
	ammo_reserve -= take

func _do_melee() -> void:
	melee_cooldown = float(_melee.get("recharge", 0.5))
	var dmg := float(_melee.get("damage", 3))
	var range_m := float(_melee.get("range", 2.0))
	var origin := camera.global_position
	var forward := -camera.global_transform.basis.z
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, origin + forward * range_m)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = [self]
	var result := space.intersect_ray(query)
	if result.is_empty():
		# Sphere fallback for melee forgiveness
		_melee_sphere(dmg, range_m)
		return
	var collider: Object = result.collider
	if collider is Area3D and collider.get_parent() and collider.get_parent().has_method("take_damage"):
		var is_head := String(collider.name).to_lower().contains("head")
		collider.get_parent().take_damage(dmg, is_head, true)
	elif collider is Node and collider.has_method("take_damage"):
		collider.take_damage(dmg, false, true)

func _melee_sphere(dmg: float, range_m: float) -> void:
	var origin := camera.global_position + (-camera.global_transform.basis.z) * (range_m * 0.5)
	for z in get_tree().get_nodes_in_group("zombies"):
		if not is_instance_valid(z):
			continue
		if origin.distance_to(z.global_position) <= range_m:
			z.take_damage(dmg, false, true)
			break

func _try_consumable(id: String) -> void:
	if not GameState.consume_from_inventory(id):
		return
	var def := DataManager.get_consumable(id)
	match String(def.get("effect", "")):
		"heal_percent_max":
			health = minf(health + max_health * float(def.get("value", 0.5)), max_health)
		"refill_stamina":
			stamina = max_stamina
		"refill_ammo":
			ammo_reserve = GameState.get_ammo_capacity()
			var clip_size := int(_gun.get("clip_size", 12))
			clip = clip_size
		"alcohol_rng":
			GameState.apply_alcohol_drink()
	EventBus.hud_refresh.emit()

func apply_tickle_damage(dps: float, delta: float) -> void:
	if GameState.cheat_infinite_health:
		health = max_health
		return
	var amount := dps * delta * GameState.alcohol_tickle_multiplier
	if stamina > 0.0:
		var to_stam := amount
		var to_hp := amount * 0.5
		stamina = maxf(stamina - to_stam, 0.0)
		health = maxf(health - to_hp, 0.0)
	else:
		health = maxf(health - amount, 0.0)
	if health <= 0.0:
		EventBus.player_died.emit("Tickle Infected")

func apply_slow(amount: float) -> void:
	slow_penalty = maxf(slow_penalty, amount)

func get_weapon_name() -> String:
	return String(_gun.get("name", "Gun"))

func is_alive() -> bool:
	return health > 0.0
