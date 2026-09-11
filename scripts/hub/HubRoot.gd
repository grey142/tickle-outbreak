extends Control
## Hub between missions: weapon shop + character upgrades + armor/consumables + start mission.

@onready var coins_label: Label = $Margin/VBox/TopBar/Coins
@onready var mission_label: Label = $Margin/VBox/TopBar/Mission
@onready var tabs: TabContainer = $Margin/VBox/Tabs
@onready var guns_list: VBoxContainer = $Margin/VBox/Tabs/Weapons/Scroll/List
@onready var melee_list: VBoxContainer = $Margin/VBox/Tabs/Melee/Scroll/List
@onready var armor_list: VBoxContainer = $Margin/VBox/Tabs/Armor/Scroll/List
@onready var upgrades_list: VBoxContainer = $Margin/VBox/Tabs/Upgrades/Scroll/List
@onready var consumables_list: VBoxContainer = $Margin/VBox/Tabs/Consumables/Scroll/List
@onready var loadout_label: Label = $Margin/VBox/Loadout
@onready var start_btn: Button = $Margin/VBox/StartMission
@onready var status_label: Label = $Margin/VBox/Status

var _outfit_portrait: TextureRect
var _outfit_caption: Label

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	start_btn.pressed.connect(_on_start)
	GameState.coins_changed.connect(func(_c): _refresh_header())
	GameState.equipment_changed.connect(_on_equipment_changed)
	_ensure_outfit_preview()
	_rebuild_all()
	_refresh_header()
	_refresh_loadout()
	_refresh_outfit_portrait()

func _ensure_outfit_preview() -> void:
	## Large Olivia Grace outfit portrait under the top bar (updates on equip).
	if has_node("Margin/VBox/OutfitPreview"):
		var existing := $Margin/VBox/OutfitPreview
		_outfit_portrait = existing.get_node("Portrait") as TextureRect
		_outfit_caption = existing.get_node("Caption") as Label
		return
	var row := HBoxContainer.new()
	row.name = "OutfitPreview"
	row.custom_minimum_size = Vector2(0, 180)
	var vbox := $Margin/VBox
	vbox.add_child(row)
	vbox.move_child(row, 1)  # after TopBar
	_outfit_portrait = TextureRect.new()
	_outfit_portrait.name = "Portrait"
	_outfit_portrait.custom_minimum_size = Vector2(140, 170)
	_outfit_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_outfit_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_outfit_portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_outfit_portrait)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var title := Label.new()
	title.text = "Survivor: Olivia Grace"
	title.add_theme_font_size_override("font_size", 20)
	info.add_child(title)
	_outfit_caption = Label.new()
	_outfit_caption.name = "Caption"
	_outfit_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(_outfit_caption)
	var hint := Label.new()
	hint.text = "Equip armor in the Armor tab — portrait swaps to the outfit sprite."
	hint.add_theme_font_size_override("font_size", 12)
	hint.modulate = Color(0.75, 0.8, 0.9)
	info.add_child(hint)

func _on_equipment_changed() -> void:
	_refresh_outfit_portrait()
	_refresh_loadout()

func _refresh_outfit_portrait() -> void:
	if _outfit_portrait == null:
		return
	var tex := DataManager.get_armor_texture(GameState.equipped_armor)
	_outfit_portrait.texture = tex
	var a := DataManager.get_armor(GameState.equipped_armor)
	if _outfit_caption:
		_outfit_caption.text = "Equipped: %s — +%s HP, +%s ammo\n%s" % [
			a.get("name", "?"), a.get("health_bonus", 0), a.get("ammo_bonus", 0), a.get("description", "")
		]

func _refresh_header() -> void:
	coins_label.text = "Coins: %d" % GameState.coins
	mission_label.text = "Next Mission: %d" % GameState.mission_number

func _refresh_loadout() -> void:
	var g := DataManager.get_gun(GameState.equipped_gun)
	var m := DataManager.get_melee(GameState.equipped_melee)
	var a := DataManager.get_armor(GameState.equipped_armor)
	var inv_bits: PackedStringArray = []
	for id in GameState.inventory_consumables.keys():
		var n := int(GameState.inventory_consumables[id])
		if n > 0:
			inv_bits.append("%s x%d" % [id, n])
	loadout_label.text = "Loadout: %s | %s | %s | HP %.0f | Stam %.0f | Spd %.0f | AmmoCap %d\nConsumables: %s" % [
		g.get("name", "?"), m.get("name", "?"), a.get("name", "?"),
		GameState.get_max_health(), GameState.get_max_stamina(), GameState.get_speed(), GameState.get_ammo_capacity(),
		", ".join(inv_bits) if inv_bits.size() > 0 else "(none)"
	]

func _rebuild_all() -> void:
	_clear(guns_list)
	_clear(melee_list)
	_clear(armor_list)
	_clear(upgrades_list)
	_clear(consumables_list)
	for g in DataManager.guns:
		_add_gun_row(g)
	for m in DataManager.melee:
		_add_melee_row(m)
	for a in DataManager.armor:
		_add_armor_row(a)
	for u in DataManager.character_upgrades.get("upgrades", []):
		_add_upgrade_row(u)
	for c in DataManager.consumables:
		_add_consumable_row(c)

func _clear(box: VBoxContainer) -> void:
	for c in box.get_children():
		c.queue_free()

func _add_gun_row(g: Dictionary) -> void:
	var id := String(g.get("id", ""))
	var row := HBoxContainer.new()
	var lbl := Label.new()
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.text = "%s — dmg %s | RoF %s/s | clip %s | reload %ss — %s" % [
		g.get("name"), g.get("damage"), g.get("rate_of_fire"), g.get("clip_size"), g.get("reload_time"), g.get("description")
	]
	row.add_child(lbl)
	var owned := id in GameState.owned_guns
	if not owned:
		var buy := Button.new()
		buy.text = "Buy (%d)" % int(g.get("shop_cost", 0))
		buy.pressed.connect(func(): _buy_gun(id, int(g.get("shop_cost", 0))))
		row.add_child(buy)
	else:
		var eq := Button.new()
		eq.text = "Equipped" if GameState.equipped_gun == id else "Equip"
		eq.disabled = GameState.equipped_gun == id
		eq.pressed.connect(func():
			GameState.equip_gun(id)
			status_label.text = "Equipped %s" % g.get("name")
			_rebuild_all()
			_refresh_loadout()
		)
		row.add_child(eq)
	guns_list.add_child(row)

func _buy_gun(id: String, cost: int) -> void:
	if cost > 0 and not GameState.spend_coins(cost):
		status_label.text = "Not enough coins."
		return
	GameState.own_gun(id)
	GameState.equip_gun(id)
	status_label.text = "Purchased gun."
	_rebuild_all()
	_refresh_loadout()

func _add_melee_row(m: Dictionary) -> void:
	var id := String(m.get("id", ""))
	var row := HBoxContainer.new()
	var lbl := Label.new()
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.text = "%s — dmg %s | recharge %ss — %s" % [m.get("name"), m.get("damage"), m.get("recharge"), m.get("description")]
	row.add_child(lbl)
	if id not in GameState.owned_melee:
		var buy := Button.new()
		buy.text = "Buy (%d)" % int(m.get("shop_cost", 0))
		buy.pressed.connect(func():
			if int(m.get("shop_cost", 0)) > 0 and not GameState.spend_coins(int(m.get("shop_cost", 0))):
				status_label.text = "Not enough coins."
				return
			GameState.own_melee(id)
			GameState.equip_melee(id)
			_rebuild_all()
			_refresh_loadout()
		)
		row.add_child(buy)
	else:
		var eq := Button.new()
		eq.text = "Equipped" if GameState.equipped_melee == id else "Equip"
		eq.disabled = GameState.equipped_melee == id
		eq.pressed.connect(func():
			GameState.equip_melee(id)
			_rebuild_all()
			_refresh_loadout()
		)
		row.add_child(eq)
	melee_list.add_child(row)

func _add_armor_row(a: Dictionary) -> void:
	var id := String(a.get("id", ""))
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 72)
	# Outfit thumbnail preview
	var thumb := TextureRect.new()
	thumb.custom_minimum_size = Vector2(56, 68)
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	thumb.texture = DataManager.get_armor_texture(id)
	row.add_child(thumb)
	var lbl := Label.new()
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.text = "%s — +%s HP, +%s ammo — %s" % [a.get("name"), a.get("health_bonus"), a.get("ammo_bonus"), a.get("description")]
	row.add_child(lbl)
	if id not in GameState.owned_armor:
		var buy := Button.new()
		buy.text = "Buy (%d)" % int(a.get("shop_cost", 0))
		buy.pressed.connect(func():
			if int(a.get("shop_cost", 0)) > 0 and not GameState.spend_coins(int(a.get("shop_cost", 0))):
				status_label.text = "Not enough coins."
				return
			GameState.own_armor(id)
			GameState.equip_armor(id)
			status_label.text = "Purchased & equipped %s" % a.get("name")
			_rebuild_all()
			_refresh_loadout()
			_refresh_outfit_portrait()
		)
		row.add_child(buy)
	else:
		var eq := Button.new()
		eq.text = "Equipped" if GameState.equipped_armor == id else "Equip"
		eq.disabled = GameState.equipped_armor == id
		eq.pressed.connect(func():
			GameState.equip_armor(id)
			status_label.text = "Equipped %s" % a.get("name")
			_rebuild_all()
			_refresh_loadout()
			_refresh_outfit_portrait()
		)
		row.add_child(eq)
	armor_list.add_child(row)

func _add_upgrade_row(u: Dictionary) -> void:
	var id := String(u.get("id", ""))
	var lvl := int(GameState.upgrade_levels.get(id, 0))
	var max_lvl := int(DataManager.character_upgrades.get("max_level", 10))
	var cost := DataManager.upgrade_cost(id, lvl)
	var row := HBoxContainer.new()
	var lbl := Label.new()
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.text = "%s — L%d/%d (next +%s) — cost %d — %s" % [
		u.get("name"), lvl, max_lvl, u.get("per_level"), cost if lvl < max_lvl else 0, u.get("description")
	]
	row.add_child(lbl)
	var buy := Button.new()
	buy.text = "Maxed" if lvl >= max_lvl else "Upgrade (%d)" % cost
	buy.disabled = lvl >= max_lvl
	buy.pressed.connect(func():
		if lvl >= max_lvl:
			return
		if not GameState.spend_coins(cost):
			status_label.text = "Not enough coins."
			return
		GameState.upgrade_levels[id] = lvl + 1
		status_label.text = "Upgraded %s to L%d" % [u.get("name"), lvl + 1]
		_rebuild_all()
		_refresh_loadout()
	)
	row.add_child(buy)
	upgrades_list.add_child(row)

func _add_consumable_row(c: Dictionary) -> void:
	var id := String(c.get("id", ""))
	var row := HBoxContainer.new()
	var have := int(GameState.inventory_consumables.get(id, 0))
	var lbl := Label.new()
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.text = "%s — owned %d — max/mission %s — %s" % [
		c.get("name"), have, c.get("max_per_mission"), c.get("description")
	]
	row.add_child(lbl)
	var buy := Button.new()
	buy.text = "Buy (%d)" % int(c.get("shop_cost", 0))
	buy.pressed.connect(func():
		if not GameState.spend_coins(int(c.get("shop_cost", 0))):
			status_label.text = "Not enough coins."
			return
		GameState.buy_consumable(id)
		status_label.text = "Bought %s" % c.get("name")
		_rebuild_all()
		_refresh_loadout()
	)
	row.add_child(buy)
	consumables_list.add_child(row)

func _on_start() -> void:
	# Advance happens after clear; first mission starts at 1
	get_tree().change_scene_to_file("res://scenes/mission/Mission.tscn")
