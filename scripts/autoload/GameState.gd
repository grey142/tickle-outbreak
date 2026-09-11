extends Node
## Persistent run state: coins, unlocks, upgrades, mission number, equipment, cheats.

signal coins_changed(amount: int)
signal equipment_changed
signal mission_changed(n: int)
signal cheats_changed

const SAVE_PATH := "user://tickle_outbreak_meta.cfg"
const UNLOCK_ALL_MISSIONS := 20

var coins: int = 0
## Selected mission for the next deploy (difficulty / quota / spawn table).
var mission_number: int = 1
## Campaign frontier: highest mission index the player may select (1..N).
var highest_mission_unlocked: int = 1

var owned_guns: Array[String] = ["senas_pistol_1"]
var owned_melee: Array[String] = ["kitchen_knife"]
var owned_armor: Array[String] = ["bikini"]
var equipped_gun: String = "senas_pistol_1"
var equipped_melee: String = "kitchen_knife"
var equipped_armor: String = "bikini"

## Permanent character upgrade levels (0–10)
var upgrade_levels: Dictionary = {
	"ammo_capacity": 0,
	"speed": 0,
	"health": 0,
	"stamina": 0,
}

## Mission inventory (reset / limited per mission)
var mission_consumable_uses: Dictionary = {}
var inventory_consumables: Dictionary = {}  # id -> count bought for next mission

var alcohol_stacks: int = 0  # net stacks this mission (+ half or *2 each drink)
var alcohol_tickle_multiplier: float = 1.0
var alcohol_aim_penalty: float = 0.0

## Desktop/editor testing: force landscape touch UI on
var force_mobile_controls: bool = false
var gallery_return_scene: String = "res://scenes/main/MainMenu.tscn"

## CHEATS (session + light disk persist)
var cheat_infinite_health: bool = false
var cheat_infinite_ammo: bool = false
var cheat_all_items_free: bool = false
var cheat_unlock_all_levels: bool = false

func _ready() -> void:
	load_meta()

func reset_run() -> void:
	## Fresh gear/coins; keep campaign unlocks + cheats (meta progress).
	coins = 0
	mission_number = 1
	owned_guns = ["senas_pistol_1"]
	owned_melee = ["kitchen_knife"]
	owned_armor = ["bikini"]
	equipped_gun = "senas_pistol_1"
	equipped_melee = "kitchen_knife"
	equipped_armor = "bikini"
	upgrade_levels = {"ammo_capacity": 0, "speed": 0, "health": 0, "stamina": 0}
	inventory_consumables = {}
	_reset_mission_flags()
	if cheat_unlock_all_levels:
		highest_mission_unlocked = maxi(highest_mission_unlocked, UNLOCK_ALL_MISSIONS)
	mission_changed.emit(mission_number)

func _reset_mission_flags() -> void:
	mission_consumable_uses = {}
	alcohol_stacks = 0
	alcohol_tickle_multiplier = 1.0
	alcohol_aim_penalty = 0.0

func prepare_mission() -> void:
	_reset_mission_flags()

func add_coins(n: int) -> void:
	coins += n
	coins_changed.emit(coins)

func shop_cost(raw_cost: int) -> int:
	if cheat_all_items_free:
		return 0
	return maxi(raw_cost, 0)

func spend_coins(n: int) -> bool:
	var cost := shop_cost(n)
	if coins < cost:
		return false
	coins -= cost
	coins_changed.emit(coins)
	return true

func get_max_health() -> float:
	var base := float(DataManager.player_stats.get("base_health", 100))
	var armor := DataManager.get_armor(equipped_armor)
	base += float(armor.get("health_bonus", 0))
	base += float(upgrade_levels.get("health", 0)) * 10.0
	return base

func get_max_stamina() -> float:
	var base := float(DataManager.player_stats.get("base_stamina", 100))
	base += float(upgrade_levels.get("stamina", 0)) * 20.0
	return base

func get_speed() -> float:
	var base := float(DataManager.player_stats.get("base_speed", 100))
	base += float(upgrade_levels.get("speed", 0)) * 5.0
	return base

func get_ammo_capacity() -> int:
	var base := int(DataManager.player_stats.get("base_ammo_capacity", 50))
	var armor := DataManager.get_armor(equipped_armor)
	base += int(armor.get("ammo_bonus", 0))
	base += int(upgrade_levels.get("ammo_capacity", 0)) * 25
	return base

func select_mission(n: int) -> void:
	n = clampi(n, 1, get_max_selectable_mission())
	mission_number = n
	mission_changed.emit(mission_number)

func get_max_selectable_mission() -> int:
	if cheat_unlock_all_levels:
		return maxi(highest_mission_unlocked, UNLOCK_ALL_MISSIONS)
	return maxi(highest_mission_unlocked, 1)

func is_mission_unlocked(n: int) -> bool:
	return n >= 1 and n <= get_max_selectable_mission()

func mission_kill_quota(n: int = -1) -> int:
	if n < 1:
		n = mission_number
	var m := DataManager.missions
	return int(m.get("base_kill_quota", 15)) + (n - 1) * int(m.get("kills_per_mission_scale", 5))

func mission_clear_reward_hint(n: int = -1) -> String:
	## Rough coin farming hint (kills * typical payout).
	if n < 1:
		n = mission_number
	var q := mission_kill_quota(n)
	var gun_kill := int(DataManager.currency.get("gun_kill", 5))
	var body := int(DataManager.currency.get("body_shot", 3))
	var approx := q * (gun_kill + body)
	return "~%d+ coins (quota %d)" % [approx, q]

func advance_mission() -> void:
	## Called after clearing the currently selected mission.
	var cleared := mission_number
	highest_mission_unlocked = maxi(highest_mission_unlocked, cleared + 1)
	if cheat_unlock_all_levels:
		highest_mission_unlocked = maxi(highest_mission_unlocked, UNLOCK_ALL_MISSIONS)
	# Advance selection toward next unlocked (replay does not shrink frontier).
	if cleared + 1 <= get_max_selectable_mission():
		mission_number = cleared + 1
	mission_changed.emit(mission_number)
	save_meta()

func set_cheat(flag: String, on: bool) -> void:
	match flag:
		"infinite_health":
			cheat_infinite_health = on
		"infinite_ammo":
			cheat_infinite_ammo = on
		"all_items_free":
			cheat_all_items_free = on
		"unlock_all_levels":
			cheat_unlock_all_levels = on
			if on:
				highest_mission_unlocked = maxi(highest_mission_unlocked, UNLOCK_ALL_MISSIONS)
		_:
			return
	cheats_changed.emit()
	save_meta()

func is_zombie_gallery_unlocked(type_def: Dictionary) -> bool:
	## Unlock when campaign frontier reaches that type's unlock_mission.
	var need := int(type_def.get("unlock_mission", 1))
	return get_max_selectable_mission() >= need

func own_gun(id: String) -> void:
	if id not in owned_guns:
		owned_guns.append(id)
	equipment_changed.emit()

func own_melee(id: String) -> void:
	if id not in owned_melee:
		owned_melee.append(id)
	equipment_changed.emit()

func own_armor(id: String) -> void:
	if id not in owned_armor:
		owned_armor.append(id)
	equipment_changed.emit()

func equip_armor(id: String) -> void:
	if equipped_armor == id:
		return
	equipped_armor = id
	equipment_changed.emit()

func equip_gun(id: String) -> void:
	if equipped_gun == id:
		return
	equipped_gun = id
	equipment_changed.emit()

func equip_melee(id: String) -> void:
	if equipped_melee == id:
		return
	equipped_melee = id
	equipment_changed.emit()

func buy_consumable(id: String) -> void:
	inventory_consumables[id] = int(inventory_consumables.get(id, 0)) + 1

func can_use_consumable(id: String) -> bool:
	var def := DataManager.get_consumable(id)
	var max_uses := int(def.get("max_per_mission", 99))
	var used := int(mission_consumable_uses.get(id, 0))
	var have := int(inventory_consumables.get(id, 0))
	return have > 0 and used < max_uses

func consume_from_inventory(id: String) -> bool:
	if not can_use_consumable(id):
		return false
	inventory_consumables[id] = int(inventory_consumables.get(id, 0)) - 1
	mission_consumable_uses[id] = int(mission_consumable_uses.get(id, 0)) + 1
	return true

func apply_alcohol_drink() -> void:
	# 50/50 halves OR doubles tickle DPS; stacks/negates across drinks
	var roll := randf() < 0.5
	if roll:
		alcohol_tickle_multiplier *= 0.5
		alcohol_stacks -= 1
	else:
		alcohol_tickle_multiplier *= 2.0
		alcohol_stacks += 1
	alcohol_aim_penalty = abs(alcohol_stacks) * DataManager.alcohol_aim_penalty

func save_meta() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "highest_mission_unlocked", highest_mission_unlocked)
	cfg.set_value("cheats", "infinite_health", cheat_infinite_health)
	cfg.set_value("cheats", "infinite_ammo", cheat_infinite_ammo)
	cfg.set_value("cheats", "all_items_free", cheat_all_items_free)
	cfg.set_value("cheats", "unlock_all_levels", cheat_unlock_all_levels)
	cfg.save(SAVE_PATH)

func load_meta() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	highest_mission_unlocked = maxi(1, int(cfg.get_value("progress", "highest_mission_unlocked", 1)))
	cheat_infinite_health = bool(cfg.get_value("cheats", "infinite_health", false))
	cheat_infinite_ammo = bool(cfg.get_value("cheats", "infinite_ammo", false))
	cheat_all_items_free = bool(cfg.get_value("cheats", "all_items_free", false))
	cheat_unlock_all_levels = bool(cfg.get_value("cheats", "unlock_all_levels", false))
	if cheat_unlock_all_levels:
		highest_mission_unlocked = maxi(highest_mission_unlocked, UNLOCK_ALL_MISSIONS)
