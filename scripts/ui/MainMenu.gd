extends Control

@onready var start_btn: Button = $Center/VBox/Start
@onready var quit_btn: Button = $Center/VBox/Quit
@onready var title: Label = $Center/VBox/Title
@onready var blurb: Label = $Center/VBox/Blurb
@onready var touch_toggle: CheckButton = $Center/VBox/TouchControls

var _cheats_panel: PanelContainer
var _audio_unlocked: bool = false

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# Web browsers mute until a user gesture — prime AudioServer on first click/tap.
	set_process_unhandled_input(true)
	title.text = "TICKLE OUTBREAK"
	blurb.text = "A first-person tickle-zombie survival FPS.\nTongue-in-cheek vertical slice for Godot 4.3+."
	if touch_toggle:
		touch_toggle.button_pressed = GameState.force_mobile_controls
		touch_toggle.toggled.connect(func(on: bool):
			GameState.force_mobile_controls = on
		)
	_ensure_extra_buttons()
	start_btn.pressed.connect(func():
		_unlock_web_audio()
		GameState.reset_run()
		# Preserve touch toggle across reset_run
		var keep_touch := touch_toggle.button_pressed if touch_toggle else GameState.force_mobile_controls
		GameState.force_mobile_controls = keep_touch
		# Starter coins so shops are testable early
		GameState.add_coins(100)
		get_tree().change_scene_to_file("res://scenes/hub/Hub.tscn")
	)
	quit_btn.pressed.connect(func(): get_tree().quit())

func _ensure_extra_buttons() -> void:
	var vbox := $Center/VBox
	if not vbox.has_node("Gallery"):
		var gal := Button.new()
		gal.name = "Gallery"
		gal.text = "Gallery / Compendium"
		vbox.add_child(gal)
		vbox.move_child(gal, start_btn.get_index() + 1)
		gal.pressed.connect(_open_gallery)
	else:
		vbox.get_node("Gallery").pressed.connect(_open_gallery)

	if not vbox.has_node("CheatsBtn"):
		var ch := Button.new()
		ch.name = "CheatsBtn"
		ch.text = "CHEATS"
		ch.modulate = Color(1.0, 0.75, 0.4)
		vbox.add_child(ch)
		vbox.move_child(ch, quit_btn.get_index())
		ch.pressed.connect(_toggle_cheats)
	else:
		vbox.get_node("CheatsBtn").pressed.connect(_toggle_cheats)

func _toggle_cheats() -> void:
	if _cheats_panel and is_instance_valid(_cheats_panel):
		_cheats_panel.visible = not _cheats_panel.visible
		return
	_cheats_panel = _build_cheats_panel()
	add_child(_cheats_panel)

func _build_cheats_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "CheatsPanel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(420, 280)
	panel.position = Vector2(0, 0)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -210
	panel.offset_top = -140
	panel.offset_right = 210
	panel.offset_bottom = 140
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.1, 0.08, 0.96)
	sb.border_color = Color(1.0, 0.55, 0.2, 0.9)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", sb)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var hdr := Label.new()
	hdr.text = "⚠ CHEATS (prototype)"
	hdr.add_theme_font_size_override("font_size", 22)
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hdr)
	var note := Label.new()
	note.text = "Toggles persist for this browser/session (saved lightly)."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 12)
	v.add_child(note)

	_add_cheat_toggle(v, "Infinite health", "infinite_health", GameState.cheat_infinite_health)
	_add_cheat_toggle(v, "Infinite ammo", "infinite_ammo", GameState.cheat_infinite_ammo)
	_add_cheat_toggle(v, "All items free", "all_items_free", GameState.cheat_all_items_free)
	_add_cheat_toggle(v, "Unlock all levels", "unlock_all_levels", GameState.cheat_unlock_all_levels)

	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(func(): panel.visible = false)
	v.add_child(close)
	return panel

func _add_cheat_toggle(parent: VBoxContainer, label: String, flag: String, initial: bool) -> void:
	var cb := CheckButton.new()
	cb.text = label
	cb.button_pressed = initial
	cb.toggled.connect(func(on: bool): GameState.set_cheat(flag, on))
	parent.add_child(cb)


func _open_gallery() -> void:
	GameState.gallery_return_scene = "res://scenes/main/MainMenu.tscn"
	get_tree().change_scene_to_file("res://scenes/ui/Gallery.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_unlock_web_audio()
	elif event is InputEventScreenTouch and event.pressed:
		_unlock_web_audio()
	elif event is InputEventKey and event.pressed:
		_unlock_web_audio()

func _unlock_web_audio() -> void:
	# Any play() after a user gesture unlocks the Web Audio context.
	if _audio_unlocked or not is_inside_tree():
		return
	_audio_unlocked = true
	var p := AudioStreamPlayer.new()
	p.bus = "Master"
	p.volume_db = -80.0
	var stream := load("res://assets/audio/giggle_01.ogg") as AudioStream
	if stream:
		p.stream = stream
		add_child(p)
		p.play()
		get_tree().create_timer(0.05).timeout.connect(func():
			if is_instance_valid(p):
				p.stop()
				p.queue_free()
		)
	set_process_unhandled_input(false)
