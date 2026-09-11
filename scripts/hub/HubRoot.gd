extends Control
## Hub between missions: mission replay list, shops, upgrades, gallery/cheats.

@onready var coins_label: Label = $Margin/VBox/TopBar/Coins
@onready var mission_label: Label = $Margin/VBox/TopBar/Mission
@onready var tabs: TabContainer = $Margin/VBox/Tabs
@onready var missions_list: VBoxContainer = $Margin/VBox/Tabs/Missions/Scroll/List
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
var _cheats_panel: PanelContainer

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	start_btn.pressed.connect(_on_start)
	GameState.coins_changed.connect(func(_c): _refresh_header())
	GameState.equipment_changed.connect(_on_equipment_changed)
	GameState.mission_changed.connect(func(_n): _refresh_header(); _rebuild_missions())
	GameState.cheats_changed.connect(func(): _rebuild_all(); _refresh_header())
	_wire_nav()
	_ensure_outfit_preview()
	_rebuild_all()
	_refresh_header()
	_refresh_loadout()
	_refresh_outfit_portrait()
	# Prefer Missions tab first
	if tabs:
		tabs.current_tab = 0

func _wire_nav() -> void:
	if has_node("Margin/VBox/NavRow/Gallery"):
		$Margin/VBox/NavRow/Gallery.pressed.connect(func():
			GameState.gallery_return_scene = "res://scenes/hub/Hub.tscn"
			get_tree().change_scene_to_file("res://scenes/ui/Gallery.tscn")
		)
	if has_node("Margin/VBox/NavRow/Cheats"):
		$Margin/VBox/NavRow/Cheats.pressed.connect(_toggle_cheats)

func _toggle_cheats() -> void:
	if _cheats_panel and is_instance_valid(_cheats_panel):
		_cheats_panel.visible = not _cheats_panel.visible
		return
	_cheats_panel = PanelContainer.new()
	_cheats_panel.name = "CheatsPanel"
	_cheats_panel.set_anchors_preset(Control.PRESET_CENTER)
	_cheats_panel.anchor_left = 0.5
	_cheats_panel.anchor_top = 0.5
	_cheats_panel.anchor_right = 0.5
	_cheats_panel.anchor_bottom = 0.5
	_cheats_panel.offset_left = -210
	_cheats_panel.offset_top = -150
	_cheats_panel.offset_right = 210
	_cheats_panel.offset_bottom = 150
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.1, 0.08, 0.96)
	sb.border_color = Color(1.0, 0.55, 0.2, 0.9)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	_cheats_panel.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_cheats_panel.add_child(v)
	var hdr := Label.new()
	hdr.text = "⚠ CHEATS"
	hdr.add_theme_font_size_override("font_size", 22)
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hdr)
	_add_cheat_toggle(v, "Infinite health", "infinite_health", GameState.cheat_infinite_health)
	_add_cheat_toggle(v, "Infinite ammo", "infinite_ammo", GameState.cheat_infinite_ammo)
	_add_cheat_toggle(v, "All items free", "all_items_free", GameState.cheat_all_items_free)
	_add_cheat_toggle(v, "Unlock all levels", "unlock_all_levels", GameState.cheat_unlock_all_levels)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(func(): _cheats_panel.visible = false)
	v.add_child(close)
	add_child(_cheats_panel)

func _add_cheat_toggle(parent: VBoxContainer, label: String, flag: String, initial: bool) -> void:
	var cb := CheckButton.new()
	cb.text = label
	cb.button_pressed = initial
	cb.toggled.connect(func(on: bool): GameState.set_cheat(flag, on))
	parent.add_child(cb)

func _cost_label(raw: int) -> String:
	var c := GameState.shop_cost(raw)
	if GameState.cheat_all_items_free:
		return "FREE"
	return str(c)

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
	mission_label.text = "Selected: M%d  |  Unlocked: 1–%d" % [
		GameState.mission_number, GameState.get_max_selectable_mission()
	]
	start_btn.text = "Deploy → Mission %d" % GameState.mission_number

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
	_rebuild_missions()
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

func _rebuild_missions() -> void:
	_clear(missions_list)
	var intro := Label.new()
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.text = "Replay cleared missions to farm coins. Selecting a past mission does not wipe gear/upgrades/coins. Frontier unlock stays at mission %d." % GameState.get_max_selectable_mission()
	missions_list.add_child(intro)
	var max_m := GameState.get_max_selectable_mission()
	for n in range(1, max_m + 1):
		_add_mission_row(n)

func _add_mission_row(n: int) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var lbl := Label.new()
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var quota := GameState.mission_kill_quota(n)
	var hint := GameState.mission_clear_reward_hint(n)
	var tag := "SELECTED" if n == GameState.mission_number else ("Replay" if n < GameState.highest_mission_unlocked or n < GameState.get_max_selectable_mission() else "Deploy")
	# Cleared/replayable if below frontier (highest unlocked means you can play it; missions < highest are cleared)
	var cleared := n < GameState.highest_mission_unlocked or (GameState.cheat_unlock_all_levels and n < GameState.UNLOCK_ALL_MISSIONS)
	if n == GameState.get_max_selectable_mission() and n == GameState.highest_mission_unlocked and not GameState.cheat_unlock_all_levels:
		tag = "Frontier"
	elif cleared:
		tag = "Replay"
	if n == GameState.mission_number:
		tag = "SELECTED"
	lbl.text = "Mission %d — kill quota %d — %s — [%s]" % [n, quota, hint, tag]
	row.add_child(lbl)
	var btn := Button.new()
	if n == GameState.mission_number:
		btn.text = "Selected"
		btn.disabled = true
	elif cleared or n < GameState.highest_mission_unlocked:
		btn.text = "Replay"
	else:
		btn.text = "Select"
	btn.pressed.connect(func():
		GameState.select_mission(n)
		status_label.text = "Selected Mission %d (quota %d). Meta progress kept." % [n, quota]
		_rebuild_missions()
		_refresh_header()
	)
	row.add_child(btn)
	var deploy := Button.new()
	deploy.text = "Deploy"
	deploy.pressed.connect(func():
		GameState.select_mission(n)
		_on_start()
	)
	row.add_child(deploy)
	missions_list.add_child(row)

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
	var raw_cost := int(g.get("shop_cost", 0))
	if not owned:
		var buy := Button.new()
		buy.text = "Buy (%s)" % _cost_label(raw_cost)
		buy.pressed.connect(func(): _buy_gun(id, raw_cost))
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
	var raw_cost := int(m.get("shop_cost", 0))
	if id not in GameState.owned_melee:
		var buy := Button.new()
		buy.text = "Buy (%s)" % _cost_label(raw_cost)
		buy.pressed.connect(func():
			if raw_cost > 0 and not GameState.spend_coins(raw_cost):
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
	var raw_cost := int(a.get("shop_cost", 0))
	if id not in GameState.owned_armor:
		var buy := Button.new()
		buy.text = "Buy (%s)" % _cost_label(raw_cost)
		buy.pressed.connect(func():
			if raw_cost > 0 and not GameState.spend_coins(raw_cost):
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
	lbl.text = "%s — L%d/%d (next +%s) — cost %s — %s" % [
		u.get("name"), lvl, max_lvl, u.get("per_level"),
		_cost_label(cost) if lvl < max_lvl else "0", u.get("description")
	]
	row.add_child(lbl)
	var buy := Button.new()
	buy.text = "Maxed" if lvl >= max_lvl else "Upgrade (%s)" % _cost_label(cost)
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
	var raw_cost := int(c.get("shop_cost", 0))
	var buy := Button.new()
	buy.text = "Buy (%s)" % _cost_label(raw_cost)
	buy.pressed.connect(func():
		if not GameState.spend_coins(raw_cost):
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
	GameState.prepare_mission()
	get_tree().change_scene_to_file("res://scenes/mission/Mission.tscn")
