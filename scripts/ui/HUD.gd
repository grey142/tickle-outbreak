extends CanvasLayer
class_name HUD

@onready var root: Control = $Root
@onready var vbox: VBoxContainer = $Root/VBox
@onready var health_bar: ProgressBar = $Root/VBox/HealthBar
@onready var stamina_bar: ProgressBar = $Root/VBox/StaminaBar
@onready var ammo_label: Label = $Root/VBox/AmmoLabel
@onready var coins_label: Label = $Root/VBox/CoinsLabel
@onready var weapon_label: Label = $Root/VBox/WeaponLabel
@onready var mission_label: Label = $Root/VBox/MissionLabel
@onready var crosshair: Label = $Root/Crosshair
@onready var hint_label: Label = $Root/HintLabel

var player: PlayerController
var _mobile_hints: bool = false

const CINEMATIC_GAP := 150.0  # leave room for top-left tickle square

func _ready() -> void:
	EventBus.hud_refresh.connect(_refresh)
	EventBus.mission_progress.connect(_on_progress)
	GameState.coins_changed.connect(func(_c): _refresh())

func bind_player(p: PlayerController) -> void:
	player = p
	_refresh()

func set_mobile_mode(active: bool) -> void:
	_mobile_hints = active
	if hint_label:
		hint_label.visible = not active
	_apply_layout(active)
	_refresh()

func _apply_layout(mobile: bool) -> void:
	if vbox == null:
		return
	if mobile:
		# Top strip: health primary (full-width-ish), leave left gap for cinematic square
		vbox.set_anchors_preset(Control.PRESET_TOP_WIDE)
		vbox.anchor_left = 0.0
		vbox.anchor_right = 1.0
		vbox.anchor_top = 0.0
		vbox.anchor_bottom = 0.0
		vbox.offset_left = CINEMATIC_GAP
		vbox.offset_top = 8.0
		vbox.offset_right = -12.0
		vbox.offset_bottom = 120.0
		vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
		health_bar.custom_minimum_size = Vector2(0, 22)
		stamina_bar.custom_minimum_size = Vector2(0, 12)
		if has_node("Root/VBox/HealthCaption"):
			$Root/VBox/HealthCaption.visible = false
		if has_node("Root/VBox/StaminaCaption"):
			$Root/VBox/StaminaCaption.visible = false
		# Compact secondary labels
		for lab in [ammo_label, coins_label, weapon_label, mission_label]:
			if lab:
				lab.add_theme_font_size_override("font_size", 12)
	else:
		vbox.set_anchors_preset(Control.PRESET_TOP_LEFT)
		vbox.anchor_left = 0.0
		vbox.anchor_right = 0.0
		vbox.anchor_top = 0.0
		vbox.anchor_bottom = 0.0
		vbox.offset_left = 16.0
		vbox.offset_top = 16.0
		vbox.offset_right = 420.0
		vbox.offset_bottom = 220.0
		health_bar.custom_minimum_size = Vector2(0, 0)
		stamina_bar.custom_minimum_size = Vector2(0, 14)
		if has_node("Root/VBox/HealthCaption"):
			$Root/VBox/HealthCaption.visible = true
		if has_node("Root/VBox/StaminaCaption"):
			$Root/VBox/StaminaCaption.visible = true
		for lab in [ammo_label, coins_label, weapon_label, mission_label]:
			if lab:
				lab.remove_theme_font_size_override("font_size")

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
	if _mobile_hints or (player != null and player.mobile_controls_active):
		hint_label.visible = false
	else:
		hint_label.visible = true
		hint_label.text = "LMB Fire | R Reload | F Melee | Shift Dash | Space Jump | 1-4 Consumables | Esc Mouse"

func _on_progress(kills: int, quota: int) -> void:
	mission_label.text = "Mission %d — Kills %d / %d" % [GameState.mission_number, kills, quota]
