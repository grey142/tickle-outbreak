extends Control
## Gallery / Compendium: zombie stats + tickle scene mockups.
## Unlock rule: a type is revealed when highest selectable mission >= unlock_mission
## (same frontier as mission replay). Locked entries show "???" placeholders.

@onready var tabs: TabContainer = $Margin/VBox/Tabs
@onready var compendium_list: VBoxContainer = $Margin/VBox/Tabs/Compendium/Scroll/List
@onready var scenes_list: VBoxContainer = $Margin/VBox/Tabs/TickleScenes/Scroll/List
@onready var back_btn: Button = $Margin/VBox/Back

const SCENE_FLAVOR := {
	"drone": "A shambling pile-on — slow fingers, relentless giggles.",
	"bolter": "Hit-and-fade tickle blitz: they dart in, poke, vanish.",
	"screamer": "No tickles — just a shriek that summons the horde.",
	"spider": "Low and clingy; sticky limbs slow every escape.",
	"tendril": "Whips from mid-range — you feel them before you see them.",
	"volatile": "Glass-cannon tickle storm. One wrong huddle and you're done.",
}

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var ret: String = GameState.gallery_return_scene
	if ret.is_empty():
		ret = "res://scenes/main/MainMenu.tscn"
	back_btn.pressed.connect(func(): get_tree().change_scene_to_file(ret))
	_rebuild()

func _rebuild() -> void:
	_clear(compendium_list)
	_clear(scenes_list)
	for t in DataManager.zombie_types:
		_add_compendium_entry(t)
		_add_scene_entry(t)

func _clear(box: VBoxContainer) -> void:
	for c in box.get_children():
		c.queue_free()

func _load_tex(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D

func _add_compendium_entry(t: Dictionary) -> void:
	var unlocked := GameState.is_zombie_gallery_unlocked(t)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.16, 0.22, 0.95)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", sb)
	compendium_list.add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	panel.add_child(root)

	var title := Label.new()
	title.add_theme_font_size_override("font_size", 22)
	if unlocked:
		title.text = String(t.get("name", "?"))
	else:
		title.text = "???"
	root.add_child(title)

	var sprites := HBoxContainer.new()
	sprites.add_theme_constant_override("separation", 8)
	root.add_child(sprites)
	var variants: Array = t.get("sprite_variants", [])
	for i in range(3):
		var tr := TextureRect.new()
		tr.custom_minimum_size = Vector2(72, 90)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		if unlocked and i < variants.size():
			tr.texture = _load_tex(String(variants[i]))
		else:
			tr.modulate = Color(0.2, 0.2, 0.25)
		sprites.add_child(tr)

	var body := Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if unlocked:
		var abilities: PackedStringArray = []
		abilities.append("behavior: %s" % t.get("behavior", "?"))
		abilities.append("tickle: %s" % t.get("tickle_mode", "?"))
		if t.has("flee_after_tickle_sec"):
			abilities.append("flee after %.1ss" % float(t.get("flee_after_tickle_sec")))
		if t.has("spawn_rate_multiplier_while_alive"):
			abilities.append("spawn x%.1f while alive" % float(t.get("spawn_rate_multiplier_while_alive")))
		if t.has("slow_player_while_tickling"):
			abilities.append("slow -%s while tickling" % t.get("slow_player_while_tickling"))
		body.text = "%s\nHP head %s / body %s | speed %s | tickle DPS %s | coins +%s | unlock mission %s\n%s" % [
			t.get("description", ""),
			t.get("head_hp"), t.get("body_hp"), t.get("speed"), t.get("tickle_dps"),
			t.get("bonus_coins"), t.get("unlock_mission"),
			" | ".join(abilities),
		]
	else:
		body.text = "Locked — reach mission %s to unlock this entry." % t.get("unlock_mission", "?")
		body.modulate = Color(0.7, 0.75, 0.85)
	root.add_child(body)

func _add_scene_entry(t: Dictionary) -> void:
	var unlocked := GameState.is_zombie_gallery_unlocked(t)
	var id := String(t.get("id", ""))
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.11, 0.16, 0.95)
	sb.border_color = Color(1.0, 0.75, 0.35, 0.55)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", sb)
	scenes_list.add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	panel.add_child(root)

	var title := Label.new()
	title.add_theme_font_size_override("font_size", 20)
	title.text = ("Tickle Scene — %s" % t.get("name", "?")) if unlocked else "Tickle Scene — ???"
	root.add_child(title)

	# Framed mock composition: 1–5 stacked/offset sprites
	var frame := Control.new()
	frame.custom_minimum_size = Vector2(0, 140)
	root.add_child(frame)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.1, 1)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_child(bg)

	var variants: Array = t.get("sprite_variants", [])
	var stack_n := 1
	match id:
		"drone":
			stack_n = 3
		"bolter":
			stack_n = 2
		"screamer":
			stack_n = 1
		"spider":
			stack_n = 4
		"tendril":
			stack_n = 3
		"volatile":
			stack_n = 5
		_:
			stack_n = 2

	if unlocked and variants.size() > 0:
		for i in range(stack_n):
			var tr := TextureRect.new()
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			tr.texture = _load_tex(String(variants[i % variants.size()]))
			tr.position = Vector2(24.0 + float(i) * 28.0, 18.0 - float(i) * 8.0)
			tr.size = Vector2(70.0 - float(i) * 2.0, 100.0 - float(i) * 2.0)
			tr.modulate = Color(1, 1, 1, 0.95 - float(i) * 0.08)
			frame.add_child(tr)
		var badge := Label.new()
		badge.text = "%d tickler%s" % [stack_n, "" if stack_n == 1 else "s"]
		badge.position = Vector2(8, 8)
		badge.add_theme_font_size_override("font_size", 12)
		badge.modulate = Color(1, 0.85, 0.45)
		frame.add_child(badge)
	else:
		var lock := Label.new()
		lock.text = "???"
		lock.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		lock.add_theme_font_size_override("font_size", 36)
		frame.add_child(lock)

	var flavor := Label.new()
	flavor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if unlocked:
		flavor.text = String(SCENE_FLAVOR.get(id, "A cinematic tickle pile-up."))
	else:
		flavor.text = "Reach mission %s to reveal this scene." % t.get("unlock_mission", "?")
		flavor.modulate = Color(0.7, 0.75, 0.85)
	root.add_child(flavor)
