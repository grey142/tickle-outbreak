extends CanvasLayer
class_name MobileControls
## Landscape phone touch controls: left joystick, right look-drag, action buttons.

signal visibility_changed(shown: bool)

@export var look_sensitivity: float = 0.004
@export var joystick_radius: float = 72.0
@export var joystick_deadzone: float = 0.15

var player: PlayerController
var _shown: bool = false

var _root: Control
var _joy_base: Control
var _joy_knob: Control
var _look_zone: Control
var _btn_fire: Button
var _hint: Label

var _joy_touch_idx: int = -1
var _joy_center: Vector2 = Vector2.ZERO
var _look_touch_idx: int = -1
var _look_last_pos: Vector2 = Vector2.ZERO
var _touch_move: Vector2 = Vector2.ZERO

func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	if DataManager and DataManager.player_stats:
		look_sensitivity = float(DataManager.player_stats.get("touch_look_sensitivity", look_sensitivity))
	_build_ui()
	_refresh_visibility()
	# Re-check if GameState toggles force flag at runtime
	set_process(true)

func bind_player(p: PlayerController) -> void:
	player = p
	_apply_player_mobile_mode()

func _process(_delta: float) -> void:
	var want := _should_show()
	if want != _shown:
		_set_shown(want)

func is_active() -> bool:
	return _shown

func _should_show() -> bool:
	if GameState.force_mobile_controls:
		return true
	if DisplayServer.is_touchscreen_available():
		return true
	var osn := OS.get_name()
	return osn == "Android" or osn == "iOS"

func _refresh_visibility() -> void:
	_set_shown(_should_show())

func _set_shown(shown: bool) -> void:
	_shown = shown
	visible = shown
	if _root:
		_root.visible = shown
	_apply_player_mobile_mode()
	visibility_changed.emit(shown)

func _apply_player_mobile_mode() -> void:
	if player == null or not is_instance_valid(player):
		return
	player.set_mobile_controls_active(_shown)
	if not _shown:
		_touch_move = Vector2.ZERO
		player.set_touch_move(Vector2.ZERO)
		player.set_touch_firing(false)
		_release_all_actions()

func _build_ui() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# Safe-area margins via nested margin
	var margin := MarginContainer.new()
	margin.name = "SafeMargin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sa := DisplayServer.get_display_safe_area()
	var win := DisplayServer.window_get_size()
	# Approximate safe insets relative to window; fall back to fixed padding
	var pad_l := 24
	var pad_r := 24
	var pad_b := 20
	var pad_t := 12
	if win.x > 0 and win.y > 0 and sa.size.x > 0:
		pad_l = maxi(24, sa.position.x)
		pad_t = maxi(12, sa.position.y)
		pad_r = maxi(24, win.x - (sa.position.x + sa.size.x))
		pad_b = maxi(20, win.y - (sa.position.y + sa.size.y))
	margin.add_theme_constant_override("margin_left", pad_l)
	margin.add_theme_constant_override("margin_right", pad_r)
	margin.add_theme_constant_override("margin_top", pad_t)
	margin.add_theme_constant_override("margin_bottom", pad_b)
	_root.add_child(margin)

	var fill := Control.new()
	fill.name = "Fill"
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(fill)

	# Right-half look zone (behind buttons so buttons receive clicks first)
	_look_zone = Control.new()
	_look_zone.name = "LookZone"
	_look_zone.set_anchors_preset(Control.PRESET_FULL_RECT)
	_look_zone.anchor_left = 0.42
	_look_zone.anchor_right = 1.0
	_look_zone.anchor_top = 0.0
	_look_zone.anchor_bottom = 1.0
	_look_zone.offset_left = 0
	_look_zone.offset_right = 0
	_look_zone.offset_top = 0
	_look_zone.offset_bottom = 0
	_look_zone.mouse_filter = Control.MOUSE_FILTER_STOP
	_look_zone.gui_input.connect(_on_look_gui_input)
	fill.add_child(_look_zone)

	# Joystick (bottom-left)
	_joy_base = Control.new()
	_joy_base.name = "Joystick"
	_joy_base.custom_minimum_size = Vector2(joystick_radius * 2.0 + 16.0, joystick_radius * 2.0 + 16.0)
	_joy_base.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_joy_base.anchor_left = 0.0
	_joy_base.anchor_right = 0.0
	_joy_base.anchor_top = 1.0
	_joy_base.anchor_bottom = 1.0
	_joy_base.offset_left = 8.0
	_joy_base.offset_top = -(joystick_radius * 2.0 + 32.0)
	_joy_base.offset_right = joystick_radius * 2.0 + 24.0
	_joy_base.offset_bottom = -8.0
	_joy_base.mouse_filter = Control.MOUSE_FILTER_STOP
	_joy_base.gui_input.connect(_on_joy_gui_input)
	fill.add_child(_joy_base)

	var joy_ring := _make_circle_panel(Color(1, 1, 1, 0.18), Color(1, 1, 1, 0.35))
	joy_ring.name = "Ring"
	joy_ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	joy_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_joy_base.add_child(joy_ring)

	_joy_knob = _make_circle_panel(Color(1, 1, 1, 0.45), Color(1, 1, 1, 0.7))
	_joy_knob.name = "Knob"
	_joy_knob.custom_minimum_size = Vector2(56, 56)
	_joy_knob.size = Vector2(56, 56)
	_joy_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_joy_base.add_child(_joy_knob)
	_reset_knob()

	# Action buttons cluster (right side, above bottom safe area, clear of top HUD)
	var actions := VBoxContainer.new()
	actions.name = "Actions"
	actions.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	actions.anchor_left = 1.0
	actions.anchor_right = 1.0
	actions.anchor_top = 1.0
	actions.anchor_bottom = 1.0
	actions.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	actions.grow_vertical = Control.GROW_DIRECTION_BEGIN
	actions.offset_left = -340.0
	actions.offset_top = -250.0
	actions.offset_right = -8.0
	actions.offset_bottom = -8.0
	actions.add_theme_constant_override("separation", 10)
	actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.add_child(actions)

	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 10)
	row1.alignment = BoxContainer.ALIGNMENT_END
	actions.add_child(row1)

	_btn_fire = _make_action_button("FIRE", Vector2(110, 72), true)
	_btn_fire.button_down.connect(func(): _set_firing(true))
	_btn_fire.button_up.connect(func(): _set_firing(false))
	row1.add_child(_btn_fire)

	var btn_reload := _make_action_button("RELOAD", Vector2(96, 72), false)
	_wire_action_button(btn_reload, "reload")
	row1.add_child(btn_reload)

	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 10)
	row2.alignment = BoxContainer.ALIGNMENT_END
	actions.add_child(row2)

	var btn_melee := _make_action_button("MELEE", Vector2(88, 64), false)
	_wire_action_button(btn_melee, "melee")
	row2.add_child(btn_melee)

	var btn_dash := _make_action_button("DASH", Vector2(88, 64), false)
	_wire_action_button(btn_dash, "dash")
	row2.add_child(btn_dash)

	var btn_jump := _make_action_button("JUMP", Vector2(88, 64), false)
	_wire_action_button(btn_jump, "jump")
	row2.add_child(btn_jump)

	var row3 := HBoxContainer.new()
	row3.add_theme_constant_override("separation", 8)
	row3.alignment = BoxContainer.ALIGNMENT_END
	actions.add_child(row3)

	var btn_hp := _make_action_button("HP", Vector2(64, 48), false)
	_wire_action_button(btn_hp, "use_health")
	row3.add_child(btn_hp)

	var btn_en := _make_action_button("NRG", Vector2(64, 48), false)
	_wire_action_button(btn_en, "use_energy")
	row3.add_child(btn_en)

	var btn_ammo := _make_action_button("AMMO", Vector2(64, 48), false)
	_wire_action_button(btn_ammo, "use_ammo")
	row3.add_child(btn_ammo)

	var btn_alc := _make_action_button("ALC", Vector2(64, 48), false)
	_wire_action_button(btn_alc, "use_alcohol")
	row3.add_child(btn_alc)

	_hint = Label.new()
	_hint.name = "TouchHint"
	_hint.text = "Touch: stick move · drag right look · hold FIRE"
	_hint.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_hint.anchor_left = 1.0
	_hint.anchor_right = 1.0
	_hint.anchor_top = 0.0
	_hint.anchor_bottom = 0.0
	_hint.offset_left = -420.0
	_hint.offset_top = 8.0
	_hint.offset_right = -8.0
	_hint.offset_bottom = 36.0
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.modulate = Color(1, 1, 1, 0.65)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.add_child(_hint)

func _make_circle_panel(fill: Color, border: Color) -> Panel:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(999)
	p.add_theme_stylebox_override("panel", sb)
	return p

func _make_action_button(label: String, min_size: Vector2, emphasize: bool) -> Button:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.12, 0.14, 0.2, 0.55 if emphasize else 0.42)
	normal.border_color = Color(1, 1, 1, 0.55 if emphasize else 0.35)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(12)
	normal.content_margin_left = 8
	normal.content_margin_right = 8
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6
	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.25, 0.45, 0.75, 0.75)
	var hover := normal.duplicate()
	hover.bg_color = Color(0.18, 0.22, 0.32, 0.65)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", normal)
	b.add_theme_font_size_override("font_size", 16 if emphasize else 14)
	return b

func _wire_action_button(btn: Button, action: String) -> void:
	btn.button_down.connect(func():
		if not InputMap.has_action(action):
			return
		Input.action_press(action)
	)
	btn.button_up.connect(func():
		if not InputMap.has_action(action):
			return
		Input.action_release(action)
	)

func _set_firing(pressed: bool) -> void:
	if player and is_instance_valid(player):
		player.set_touch_firing(pressed)
	# Also mirror into InputMap so desktop+touch coexist cleanly
	if InputMap.has_action("fire"):
		if pressed:
			Input.action_press("fire")
		else:
			Input.action_release("fire")

func _release_all_actions() -> void:
	for a in ["fire", "reload", "melee", "dash", "jump", "use_health", "use_energy", "use_ammo", "use_alcohol"]:
		if InputMap.has_action(a):
			Input.action_release(a)

func _reset_knob() -> void:
	if _joy_knob == null or _joy_base == null:
		return
	# Defer until sized after first layout pass
	call_deferred("_reset_knob_immediate")

func _on_joy_gui_input(event: InputEvent) -> void:
	if not _shown:
		return
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed and _joy_touch_idx < 0:
			_joy_touch_idx = st.index
			_joy_center = _joy_base.size * 0.5
			_update_joy(st.position)
			_joy_base.accept_event()
		elif not st.pressed and st.index == _joy_touch_idx:
			_joy_touch_idx = -1
			_touch_move = Vector2.ZERO
			_push_move()
			_reset_knob_immediate()
			_joy_base.accept_event()
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if sd.index == _joy_touch_idx:
			_update_joy(sd.position)
			_joy_base.accept_event()
	# Emulate Touch From Mouse / desktop testing
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and _joy_touch_idx < 0:
				_joy_touch_idx = 1000
				_joy_center = _joy_base.size * 0.5
				_update_joy(mb.position)
				_joy_base.accept_event()
			elif not mb.pressed and _joy_touch_idx == 1000:
				_joy_touch_idx = -1
				_touch_move = Vector2.ZERO
				_push_move()
				_reset_knob_immediate()
				_joy_base.accept_event()
	elif event is InputEventMouseMotion and _joy_touch_idx == 1000:
		var mm := event as InputEventMouseMotion
		_update_joy(mm.position)
		_joy_base.accept_event()

func _update_joy(local_pos: Vector2) -> void:
	var delta := local_pos - _joy_center
	var max_r := joystick_radius
	if delta.length() > max_r:
		delta = delta.normalized() * max_r
	_joy_knob.position = _joy_center + delta - _joy_knob.size * 0.5
	var v := delta / max_r
	# Godot move: x = strafe, y = forward/back (negative y is forward in get_vector)
	if v.length() < joystick_deadzone:
		_touch_move = Vector2.ZERO
	else:
		var mag := (v.length() - joystick_deadzone) / (1.0 - joystick_deadzone)
		_touch_move = Vector2(v.x, v.y).normalized() * clampf(mag, 0.0, 1.0)
	_push_move()

func _reset_knob_immediate() -> void:
	var c := _joy_base.size * 0.5
	_joy_center = c
	_joy_knob.position = c - _joy_knob.size * 0.5

func _push_move() -> void:
	if player and is_instance_valid(player):
		player.set_touch_move(_touch_move)

func _on_look_gui_input(event: InputEvent) -> void:
	if not _shown:
		return
	# Ignore events that hit buttons — buttons are siblings drawn later so they get priority,
	# but also skip if event was already handled.
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed and _look_touch_idx < 0:
			_look_touch_idx = st.index
			_look_last_pos = st.position
			_look_zone.accept_event()
		elif not st.pressed and st.index == _look_touch_idx:
			_look_touch_idx = -1
			_look_zone.accept_event()
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if sd.index == _look_touch_idx:
			_apply_look(sd.relative)
			_look_zone.accept_event()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and _look_touch_idx < 0:
				_look_touch_idx = 1001
				_look_last_pos = mb.position
				_look_zone.accept_event()
			elif not mb.pressed and _look_touch_idx == 1001:
				_look_touch_idx = -1
				_look_zone.accept_event()
	elif event is InputEventMouseMotion and _look_touch_idx == 1001:
		var mm := event as InputEventMouseMotion
		_apply_look(mm.relative)
		_look_zone.accept_event()

func _apply_look(relative: Vector2) -> void:
	if player and is_instance_valid(player):
		player.apply_touch_look(relative * look_sensitivity)
