extends CharacterBody3D
class_name Zombie
## Billboard sprite zombie with head/body hitboxes and behaviors.

signal died(zombie_id: String, by_melee: bool, bonus: int)

var def: Dictionary = {}
var zombie_id: String = "drone"
var head_hp: float = 1.0
var body_hp: float = 10.0
var tickle_dps: float = 3.0
var bonus_coins: int = 1
var behavior: String = "chase"
var tickle_mode: String = "melee"
var speed_stat: float = 25.0
var slow_on_tickle: float = 0.0
var flee_timer: float = 0.0
var is_fleeing: bool = false
var tickle_hold_timer: float = 0.0  ## time spent continuously tickling before flee
var _was_tickling: bool = false
var last_hit_melee: bool = false
var actively_tickling: bool = false
var label: Label3D
## Path of the randomly chosen sprite variant (for cinematic / debug).
var sprite_variant_path: String = ""
var sprite_texture: Texture2D = null

func setup(type_def: Dictionary) -> void:
	def = type_def
	zombie_id = String(type_def.get("id", "drone"))
	head_hp = float(type_def.get("head_hp", 1))
	body_hp = float(type_def.get("body_hp", 10))
	tickle_dps = float(type_def.get("tickle_dps", 3))
	bonus_coins = int(type_def.get("bonus_coins", 1))
	behavior = String(type_def.get("behavior", "chase"))
	tickle_mode = String(type_def.get("tickle_mode", "melee"))
	speed_stat = float(type_def.get("speed", 25))
	slow_on_tickle = float(type_def.get("slow_player_while_tickling", 0))
	name = "Zombie_%s" % zombie_id
	_pick_sprite_variant()
	_build_visual()

func _pick_sprite_variant() -> void:
	var variants: Array = def.get("sprite_variants", [])
	if variants.is_empty():
		sprite_variant_path = ""
		sprite_texture = null
		return
	var pick: String = String(variants[randi() % variants.size()])
	sprite_variant_path = pick
	if ResourceLoader.exists(pick):
		sprite_texture = load(pick) as Texture2D
	else:
		push_warning("Zombie sprite missing: %s" % pick)
		sprite_texture = null

func _build_visual() -> void:
	# Clear prior
	for c in get_children():
		c.queue_free()

	var scale_arr: Array = def.get("scale", [1.0, 1.65, 1.0])
	var body_h := float(scale_arr[1])
	var body_r := 0.35 * float(scale_arr[0])
	var col := Color(String(def.get("color", "#7ec850")))
	# Match MissionRoot player Head Y (1.6). Most types align art eyes here;
	# spider stays low; volatile towers via a higher head_height.
	var eye_default := float(DataManager.zombies.get("player_eye_height", 1.6))
	var head_y := float(def.get("head_height", eye_default))
	# Fraction from top of texture to eyes/upper-head (~bun/eyes in rembg art).
	var head_from_top := float(def.get("head_from_top", 0.13))

	# Billboard sprite (replaces colored capsule / head meshes)
	if sprite_texture != null:
		var spr := Sprite3D.new()
		spr.name = "Sprite"
		spr.texture = sprite_texture
		spr.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		spr.shaded = false
		spr.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		spr.transparent = true
		spr.double_sided = true
		spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		var tex_h := float(sprite_texture.get_height())
		# Size so eyes land on head_y and feet stay near ground (full-bleed art).
		var display_h := head_y / maxf(0.05, 1.0 - head_from_top)
		if def.has("display_height"):
			display_h = float(def.get("display_height"))
		if tex_h > 0.0:
			spr.pixel_size = display_h / tex_h
		spr.centered = true
		var eye_local := (0.5 - head_from_top) * display_h
		spr.position.y = head_y - eye_local
		add_child(spr)
	else:
		# Fallback capsule if textures fail to load
		var body_mesh := MeshInstance3D.new()
		var capsule := CapsuleMesh.new()
		capsule.radius = body_r
		capsule.height = body_h
		body_mesh.mesh = capsule
		var mat := StandardMaterial3D.new()
		mat.albedo_color = col
		body_mesh.material_override = mat
		body_mesh.position.y = body_h * 0.5
		add_child(body_mesh)
		var head_mesh := MeshInstance3D.new()
		var hm := SphereMesh.new()
		hm.radius = 0.25
		hm.height = 0.5
		head_mesh.mesh = hm
		var hmat := StandardMaterial3D.new()
		hmat.albedo_color = col.lightened(0.3)
		head_mesh.material_override = hmat
		head_mesh.position.y = head_y
		add_child(head_mesh)

	# Collision (invisible; keeps physics)
	var body_col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = body_r
	shape.height = body_h
	body_col.shape = shape
	body_col.position.y = body_h * 0.5
	add_child(body_col)

	# Body hitbox area
	var body_area := Area3D.new()
	body_area.name = "BodyHitbox"
	body_area.collision_layer = 4
	body_area.collision_mask = 0
	var body_area_shape := CollisionShape3D.new()
	var body_sphere := SphereShape3D.new()
	body_sphere.radius = 0.45 * float(scale_arr[0])
	body_area_shape.shape = body_sphere
	body_area_shape.position.y = minf(body_h * 0.45, head_y - 0.35)
	body_area.add_child(body_area_shape)
	add_child(body_area)

	# Head hitbox aligned to visual head / eye height
	var head_area := Area3D.new()
	head_area.name = "HeadHitbox"
	head_area.collision_layer = 4
	head_area.collision_mask = 0
	var head_shape := CollisionShape3D.new()
	var head_sphere := SphereShape3D.new()
	head_sphere.radius = 0.28
	head_shape.shape = head_sphere
	head_shape.position.y = head_y
	head_area.add_child(head_shape)
	add_child(head_area)

	label = Label3D.new()
	label.text = String(def.get("name", zombie_id))
	label.font_size = 48
	label.position.y = head_y + 0.55
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)

	collision_layer = 2
	collision_mask = 1  # world
	add_to_group("zombies")
	if behavior == "scream":
		add_to_group("screamers")

func _physics_process(delta: float) -> void:
	if not is_inside_tree():
		return
	var player := _get_player()
	if player == null or not player.is_alive():
		velocity = Vector3.ZERO
		move_and_slide()
		return

	var gravity := 9.8
	if not is_on_floor():
		velocity.y -= gravity * delta

	var to_player: Vector3 = player.global_position - global_position
	to_player.y = 0
	var dist := to_player.length()
	var dir := to_player.normalized() if dist > 0.01 else Vector3.ZERO
	var speed_scale := float(DataManager.zombies.get("speed_godot_scale", 0.08))
	var spd := speed_stat * speed_scale

	if behavior == "tickle_and_run":
		# Stay on the player and tickle for flee_after_tickle_sec, THEN run away.
		if is_fleeing:
			flee_timer -= delta
			dir = -dir
			tickle_hold_timer = 0.0
			_was_tickling = false
			if flee_timer <= 0.0:
				is_fleeing = false
		elif actively_tickling:
			if not _was_tickling:
				tickle_hold_timer = 0.0
			_was_tickling = true
			tickle_hold_timer += delta
			# Stick to the player while tickling (don't back off yet).
			if dist > 0.35:
				spd *= 0.55  # ease in if slightly out of range
			else:
				dir = Vector3.ZERO  # stand on them and tickle
				spd = 0.0
			var hold := float(def.get("flee_after_tickle_sec", 1.5))
			if tickle_hold_timer >= hold:
				is_fleeing = true
				flee_timer = float(def.get("flee_duration_sec", 2.0))
				tickle_hold_timer = 0.0
				_was_tickling = false
		else:
			# Broke contact — reset hold so they must tickle a full 1.5s next time.
			tickle_hold_timer = 0.0
			_was_tickling = false

	if behavior == "scream":
		# Lurk slowly toward player but prioritize presence
		spd *= 0.6

	if dir != Vector3.ZERO:
		velocity.x = dir.x * spd
		velocity.z = dir.z * spd
		look_at(global_position + dir, Vector3.UP)
	else:
		velocity.x = 0
		velocity.z = 0

	move_and_slide()

func take_damage(amount: float, is_head: bool, by_melee: bool, award_hit_coins: bool = true) -> void:
	last_hit_melee = by_melee
	if is_head:
		head_hp -= amount
		if award_hit_coins:
			GameState.add_coins(int(DataManager.currency.get("head_shot", 20)))
		EventBus.hit_registered.emit(true, by_melee, amount)
	else:
		body_hp -= amount
		if award_hit_coins:
			if by_melee:
				GameState.add_coins(int(DataManager.currency.get("melee_hit", 5)))
			else:
				GameState.add_coins(int(DataManager.currency.get("body_shot", 3)))
		EventBus.hit_registered.emit(false, by_melee, amount)

	if head_hp <= 0.0 or body_hp <= 0.0:
		_die()

func _die() -> void:
	if by_melee_kill():
		GameState.add_coins(int(DataManager.currency.get("melee_kill", 20)))
	else:
		GameState.add_coins(int(DataManager.currency.get("gun_kill", 5)))
	GameState.add_coins(bonus_coins)
	EventBus.zombie_killed.emit(zombie_id, last_hit_melee, bonus_coins)
	died.emit(zombie_id, last_hit_melee, bonus_coins)
	queue_free()

func by_melee_kill() -> bool:
	return last_hit_melee

func get_tickle_range() -> float:
	if tickle_mode == "mid_range":
		return float(DataManager.zombies.get("mid_range_tickle", 6.0))
	if tickle_mode == "none":
		return 0.0
	return float(DataManager.zombies.get("tickle_range", 2.2))

func _get_player() -> PlayerController:
	var nodes := get_tree().get_nodes_in_group("player")
	if nodes.is_empty():
		return null
	return nodes[0] as PlayerController
