extends Node
## Loads all balance JSON from res://data/ — single source of truth for numbers.

var player_stats: Dictionary = {}
var currency: Dictionary = {}
var guns: Array = []
var melee: Array = []
var armor: Array = []
var consumables: Array = []
var alcohol_aim_penalty: float = 3.0
var zombies: Dictionary = {}
var zombie_types: Array = []
var character_upgrades: Dictionary = {}
var missions: Dictionary = {}

func _ready() -> void:
	player_stats = _load_json("res://data/player_stats.json")
	currency = _load_json("res://data/currency.json")
	var g := _load_json("res://data/guns.json")
	guns = g.get("guns", [])
	var m := _load_json("res://data/melee.json")
	melee = m.get("melee", [])
	var a := _load_json("res://data/armor.json")
	armor = a.get("armor", [])
	var c := _load_json("res://data/consumables.json")
	consumables = c.get("consumables", [])
	alcohol_aim_penalty = float(c.get("alcohol_aim_penalty_degrees_per_stack", 3.0))
	zombies = _load_json("res://data/zombies.json")
	zombie_types = zombies.get("types", [])
	character_upgrades = _load_json("res://data/character_upgrades.json")
	missions = _load_json("res://data/missions.json")

func _load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("DataManager: failed to open %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("DataManager: invalid JSON at %s" % path)
		return {}
	return parsed

func get_gun(id: String) -> Dictionary:
	for g in guns:
		if g.get("id") == id:
			return g
	return {}

func get_melee(id: String) -> Dictionary:
	for m in melee:
		if m.get("id") == id:
			return m
	return {}

func get_armor(id: String) -> Dictionary:
	for a in armor:
		if a.get("id") == id:
			return a
	return {}

func get_consumable(id: String) -> Dictionary:
	for c in consumables:
		if c.get("id") == id:
			return c
	return {}

func get_zombie(id: String) -> Dictionary:
	for z in zombie_types:
		if z.get("id") == id:
			return z
	return {}

func upgrade_cost(upgrade_id: String, current_level: int) -> int:
	for u in character_upgrades.get("upgrades", []):
		if u.get("id") == upgrade_id:
			var base := float(u.get("base_cost", 100))
			var scale := float(u.get("cost_scale", 1.5))
			return int(round(base * pow(scale, current_level)))
	return 999999

func get_armor_sprite_path(id: String) -> String:
	var a := get_armor(id)
	return String(a.get("sprite", ""))

func get_armor_texture(id: String) -> Texture2D:
	var path := get_armor_sprite_path(id)
	if path.is_empty():
		return null
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	push_warning("Armor sprite missing: %s" % path)
	return null
