extends Node
## Persistent run state: coins, unlocks, upgrades, mission number, equipment.

signal coins_changed(amount: int)
signal equipment_changed
signal mission_changed(n: int)

var coins: int = 0
var mission_number: int = 1
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

func reset_run() -> void:
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

func spend_coins(n: int) -> bool:
	if coins < n:
		return false
	coins -= n
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

func advance_mission() -> void:
	mission_number += 1
	mission_changed.emit(mission_number)

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
