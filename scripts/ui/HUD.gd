extends CanvasLayer
class_name HUD

@onready var health_bar: ProgressBar = $Root/VBox/HealthBar
@onready var stamina_bar: ProgressBar = $Root/VBox/StaminaBar
@onready var ammo_label: Label = $Root/VBox/AmmoLabel
@onready var coins_label: Label = $Root/VBox/CoinsLabel
@onready var weapon_label: Label = $Root/VBox/WeaponLabel
@onready var mission_label: Label = $Root/VBox/MissionLabel
@onready var crosshair: Label = $Root/Crosshair
@onready var hint_label: Label = $Root/HintLabel

var player: PlayerController

func _ready() -> void:
	EventBus.hud_refresh.connect(_refresh)
	EventBus.mission_progress.connect(_on_progress)
	GameState.coins_changed.connect(func(_c): _refresh())

func bind_player(p: PlayerController) -> void:
	player = p
	_refresh()

func _refresh() -> void:
	if player == null or not is_instance_valid(player):
		return
	health_bar.max_value = player.max_health
	health_bar.value = player.health
	stamina_bar.max_value = player.max_stamina
	stamina_bar.value = player.stamina
	if has_node("Root/VBox/HealthCaption"):
		$Root/VBox/HealthCaption.text = "Health: %.0f / %.0f" % [player.health, player.max_health]
	if has_node("Root/VBox/StaminaCaption"):
		$Root/VBox/StaminaCaption.text = "Stamina: %.0f / %.0f" % [player.stamina, player.max_stamina]
	ammo_label.text = "Ammo: %d / %d  (reserve %d)%s" % [
		player.clip,
		int(player._gun.get("clip_size", 12)),
		player.ammo_reserve,
		"  [RELOADING...]" if player.is_reloading else ""
	]
	coins_label.text = "Coins: %d" % GameState.coins
	weapon_label.text = "Weapon: %s | Melee: %s" % [player.get_weapon_name(), String(player._melee.get("name", "Knife"))]
	hint_label.text = "LMB Fire | R Reload | F Melee | Shift Dash | Space Jump | 1-4 Consumables | Esc Mouse"

func _on_progress(kills: int, quota: int) -> void:
	mission_label.text = "Mission %d — Kills %d / %d" % [GameState.mission_number, kills, quota]
