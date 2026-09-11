extends CanvasLayer
class_name MobileControls
## Landscape phone touch controls: D-pad move, vertical right action strip, look joystick.

signal mobile_visibility_changed(shown: bool)

## Radians per second at full look-stick deflection (from player_stats touch_look_sensitivity).
@export var look_sensitivity: float = 2.8

var player: PlayerController
var _shown: bool = false

var _root: Control
var _hint: Label

var _fwd_held: bool = false
var _back_held: bool = false
var _left_held: bool = false
var _right_held: bool = false
var _touch_move: Vector2 = Vector2.ZERO

## Look joystick state (separate touch index from D-pad / actions).
var _look_stick_active: bool = false
var _look_stick_touch_idx: int = -1
var _look_stick_vec: Vector2 = Vector2.ZERO
var _look_base: Control
var _look_knob: Control
var _look_hit: Control
var _look_base_center: Vector2 = Vector2.ZERO
const LOOK_STICK_RADIUS := 72.0
const LOOK_DEADZONE := 0.15
## Synthetic mouse index when emulating touch from mouse on desktop.
const LOOK_MOUSE_IDX := 1001
## Active real screen touches (web mouse-emulation must not fight these).
var _screen_touches: int = 0

const DPAD_BTN := Vector2(88, 88)
const ACTION_BIG := Vector2(100, 56)
const ACTION_MED := Vector2(96, 48)
const ACTION_SM := Vector2(92, 44)
const CONSUMABLE := Vector2(84, 36)

func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	if DataManager and DataManager.player_stats:
		look_sensitivity = float(DataManager.player_stats.get("touch_look_sensitivity", look_sensitivity))
	_build_ui()
	_refresh_visibility()
	set_process(true)

func bind_player(p: PlayerController) -> void:
	player = p
	_apply_player_mobile_mode()

func _process(delta: float) -> void:
	var want := _should_show()
	if want != _shown:
		_set_shown(want)
	# Rate-based look while stick is deflected (works with D-pad multitouch).
	if _shown and _look_stick_active and _look_stick_vec.length_squared() > 0.0001:
		if player and is_instance_valid(player):
			player.apply_touch_look(_look_stick_vec * look_sensitivity * delta)

func _input(event: InputEvent) -> void:
	## Count real screen touches globally so web mouse-emulation cannot yank the camera.
	if not _shown:
		return
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_screen_touches += 1
			if _look_stick_touch_idx == LOOK_MOUSE_IDX:
				_reset_look_stick()
		else:
			_screen_touches = maxi(_screen_touches - 1, 0)
			if st.index == _look_stick_touch_idx:
				_reset_look_stick()

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
	mobile_visibility_changed.emit(shown)

func _apply_player_mobile_mode() -> void:
	if player == null or not is_instance_valid(player):
		return
	player.set_mobile_controls_active(_shown)
	if not _shown:
		_touch_move = Vector2.ZERO
		_fwd_held = false
		_back_held = false
		_left_held = false
		_right_held = false
		player.set_touch_move(Vector2.ZERO)
		player.set_touch_firing(false)
		_reset_look_stick()
		_screen_touches = 0
		_release_all_actions()

func _build_ui() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var margin := MarginContainer.new()
	margin.name = "SafeMargin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sa := DisplayServer.get_display_safe_area()
	var win := DisplayServer.window_get_size()
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

	# Full-screen LookZone removed as primary look — inert leftover omitted.
	# Look is exclusively via the bottom-right look joystick.

	_build_dpad(fill)
	_build_right_strip(fill)

	_hint = Label.new()
	_hint.name = "TouchHint"
	_hint.text = "D-pad move · look stick (BR) · right-edge actions"
	_hint.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_hint.anchor_left = 1.0
	_hint.anchor_right = 1.0
	_hint.anchor_top = 0.0
	_hint.anchor_bottom = 0.0
	_hint.offset_left = -480.0
	_hint.offset_top = 8.0
	_hint.offset_right = -8.0
	_hint.offset_bottom = 36.0
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.modulate = Color(1, 1, 1, 0.55)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.add_child(_hint)

func _build_dpad(fill: Control) -> void:
	## Bottom-left 4 discrete movement buttons (not a joystick). Diagonals if two held.
	var dpad := Control.new()
	dpad.name = "DPad"
	dpad.custom_minimum_size = Vector2(DPAD_BTN.x * 3.0 + 16.0, DPAD_BTN.y * 3.0 + 16.0)
	dpad.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	dpad.anchor_left = 0.0
	dpad.anchor_right = 0.0
	dpad.anchor_top = 1.0
	dpad.anchor_bottom = 1.0
	var w := DPAD_BTN.x * 3.0 + 16.0
	var h := DPAD_BTN.y * 3.0 + 16.0
	dpad.offset_left = 4.0
	dpad.offset_top = -h - 4.0
	dpad.offset_right = w + 4.0
	dpad.offset_bottom = -4.0
	dpad.mouse_filter = Control.MOUSE_FILTER_STOP
	fill.add_child(dpad)

	var btn_f := _make_dpad_button("▲", "F")
	btn_f.position = Vector2(DPAD_BTN.x + 8.0, 4.0)
	_wire_dpad(btn_f, "fwd")
	dpad.add_child(btn_f)

	var btn_l := _make_dpad_button("◀", "L")
	btn_l.position = Vector2(4.0, DPAD_BTN.y + 8.0)
	_wire_dpad(btn_l, "left")
	dpad.add_child(btn_l)

	var btn_r := _make_dpad_button("▶", "R")
	btn_r.position = Vector2(DPAD_BTN.x * 2.0 + 12.0, DPAD_BTN.y + 8.0)
	_wire_dpad(btn_r, "right")
	dpad.add_child(btn_r)

	var btn_b := _make_dpad_button("▼", "B")
	btn_b.position = Vector2(DPAD_BTN.x + 8.0, DPAD_BTN.y * 2.0 + 12.0)
	_wire_dpad(btn_b, "back")
	dpad.add_child(btn_b)

func _make_dpad_button(symbol: String, _tag: String) -> Button:
	var b := Button.new()
	b.text = symbol
	b.custom_minimum_size = DPAD_BTN
	b.size = DPAD_BTN
	b.focus_mode = Control.FOCUS_NONE
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.1, 0.12, 0.18, 0.55)
	normal.border_color = Color(1, 1, 1, 0.45)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(int(DPAD_BTN.x * 0.5))
	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.28, 0.48, 0.8, 0.8)
	var hover := normal.duplicate()
	hover.bg_color = Color(0.16, 0.2, 0.3, 0.65)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", normal)
	b.add_theme_font_size_override("font_size", 32)
	return b

func _wire_dpad(btn: Button, dir: String) -> void:
	btn.button_down.connect(func():
		match dir:
			"fwd":
				_fwd_held = true
			"back":
				_back_held = true
			"left":
				_left_held = true
			"right":
				_right_held = true
		_recompute_move()
	)
	btn.button_up.connect(func():
		match dir:
			"fwd":
				_fwd_held = false
			"back":
				_back_held = false
			"left":
				_left_held = false
			"right":
				_right_held = false
		_recompute_move()
	)

func _recompute_move() -> void:
	# Matches Input.get_vector("move_left","move_right","move_forward","move_back"):
	# forward = -y, back = +y, left = -x, right = +x
	var v := Vector2.ZERO
	if _left_held:
		v.x -= 1.0
	if _right_held:
		v.x += 1.0
	if _fwd_held:
		v.y -= 1.0
	if _back_held:
		v.y += 1.0
	if v.length_squared() > 0.0001:
		v = v.normalized()
	_touch_move = v
	_push_move()

func _build_right_strip(fill: Control) -> void:
	## Right-edge vertical action wall + look joystick under it (bottom-right).
	var stick_size := LOOK_STICK_RADIUS * 2.0 + 8.0
	var strip_w := 120.0

	var column := VBoxContainer.new()
	column.name = "RightStrip"
	column.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	column.anchor_left = 1.0
	column.anchor_right = 1.0
	column.anchor_top = 1.0
	column.anchor_bottom = 1.0
	column.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	column.grow_vertical = Control.GROW_DIRECTION_BEGIN
	column.offset_left = -strip_w - 4.0
	column.offset_top = -520.0
	column.offset_right = -4.0
	column.offset_bottom = -4.0
	column.add_theme_constant_override("separation", 4)
	column.alignment = BoxContainer.ALIGNMENT_END
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.add_child(column)

	# Action buttons stacked along the right edge (thumb-reachable).
	var actions := VBoxContainer.new()
	actions.name = "Actions"
	actions.add_theme_constant_override("separation", 4)
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.size_flags_horizontal = Control.SIZE_SHRINK_END
	actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(actions)

	var btn_fire := _make_action_button("FIRE", ACTION_BIG, true)
	btn_fire.button_down.connect(func(): _set_firing(true))
	btn_fire.button_up.connect(func(): _set_firing(false))
	actions.add_child(btn_fire)

	var btn_melee := _make_action_button("MELEE", ACTION_BIG, true)
	btn_melee.button_down.connect(_on_melee_pressed)
	actions.add_child(btn_melee)

	var btn_dash := _make_action_button("DASH", ACTION_MED, false)
	_wire_action_button(btn_dash, "dash")
	actions.add_child(btn_dash)

	var btn_reload := _make_action_button("RELOAD", ACTION_SM, false)
	_wire_action_button(btn_reload, "reload")
	actions.add_child(btn_reload)

	var btn_jump := _make_action_button("JUMP", ACTION_SM, false)
	_wire_action_button(btn_jump, "jump")
	actions.add_child(btn_jump)

	for pair in [["HP", "use_health"], ["NRG", "use_energy"], ["AMMO", "use_ammo"], ["ALC", "use_alcohol"]]:
		var btn := _make_action_button(pair[0], CONSUMABLE, false)
		_wire_action_button(btn, pair[1])
		actions.add_child(btn)

	# Look joystick under the wall strip (bottom-right).
	_build_look_joystick(column, stick_size)

func _build_look_joystick(parent: Control, stick_size: float) -> void:
	var wrap := Control.new()
	wrap.name = "LookJoystick"
	wrap.custom_minimum_size = Vector2(stick_size, stick_size)
	wrap.size_flags_horizontal = Control.SIZE_SHRINK_END
	wrap.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(wrap)

	# Rounded base (ColorRect/Panel with proper mouse_filter IGNORE — hit layer catches input).
	_look_base = Panel.new()
	_look_base.name = "Base"
	_look_base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_look_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var base_style := StyleBoxFlat.new()
	base_style.bg_color = Color(0.1, 0.12, 0.18, 0.55)
	base_style.border_color = Color(1, 1, 1, 0.4)
	base_style.set_border_width_all(2)
	base_style.set_corner_radius_all(int(LOOK_STICK_RADIUS))
	_look_base.add_theme_stylebox_override("panel", base_style)
	wrap.add_child(_look_base)

	var knob_r := LOOK_STICK_RADIUS * 0.42
	_look_knob = Panel.new()
	_look_knob.name = "Knob"
	_look_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_look_knob.custom_minimum_size = Vector2(knob_r * 2.0, knob_r * 2.0)
	_look_knob.size = Vector2(knob_r * 2.0, knob_r * 2.0)
	var knob_style := StyleBoxFlat.new()
	knob_style.bg_color = Color(0.35, 0.55, 0.9, 0.75)
	knob_style.border_color = Color(1, 1, 1, 0.65)
	knob_style.set_border_width_all(2)
	knob_style.set_corner_radius_all(int(knob_r))
	_look_knob.add_theme_stylebox_override("panel", knob_style)
	wrap.add_child(_look_knob)

	# Hit target receives multitouch / mouse for look stick only.
	_look_hit = Control.new()
	_look_hit.name = "Hit"
	_look_hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_look_hit.mouse_filter = Control.MOUSE_FILTER_STOP
	_look_hit.gui_input.connect(_on_look_stick_gui_input)
	wrap.add_child(_look_hit)

	# Center knob after layout
	wrap.resized.connect(func():
		_look_base_center = wrap.size * 0.5
		_center_look_knob()
	)
	# Initial center once in tree
	call_deferred("_deferred_center_look_knob", wrap)

func _deferred_center_look_knob(wrap: Control) -> void:
	if not is_instance_valid(wrap):
		return
	_look_base_center = wrap.size * 0.5
	if _look_base_center.length_squared() < 1.0:
		_look_base_center = Vector2(LOOK_STICK_RADIUS + 4.0, LOOK_STICK_RADIUS + 4.0)
	_center_look_knob()

func _center_look_knob() -> void:
	if _look_knob == null:
		return
	var half := _look_knob.size * 0.5
	_look_knob.position = _look_base_center - half

func _reset_look_stick() -> void:
	_look_stick_active = false
	_look_stick_touch_idx = -1
	_look_stick_vec = Vector2.ZERO
	_center_look_knob()

func _on_look_stick_gui_input(event: InputEvent) -> void:
	if not _shown:
		return
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			if _look_stick_touch_idx == LOOK_MOUSE_IDX:
				_reset_look_stick()
			if _look_stick_touch_idx < 0:
				_look_stick_touch_idx = st.index
				_look_stick_active = true
				_update_look_stick_from_local(st.position)
				_look_hit.accept_event()
		elif st.index == _look_stick_touch_idx:
			_reset_look_stick()
			_look_hit.accept_event()
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if sd.index == _look_stick_touch_idx:
			_update_look_stick_from_local(sd.position)
			_look_hit.accept_event()
	elif _screen_touches == 0 and event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and _look_stick_touch_idx < 0:
				_look_stick_touch_idx = LOOK_MOUSE_IDX
				_look_stick_active = true
				_update_look_stick_from_local(mb.position)
				_look_hit.accept_event()
			elif not mb.pressed and _look_stick_touch_idx == LOOK_MOUSE_IDX:
				_reset_look_stick()
				_look_hit.accept_event()
	elif _screen_touches == 0 and event is InputEventMouseMotion and _look_stick_touch_idx == LOOK_MOUSE_IDX:
		var mm := event as InputEventMouseMotion
		_update_look_stick_from_local(mm.position)
		_look_hit.accept_event()

func _update_look_stick_from_local(local_pos: Vector2) -> void:
	var offset := local_pos - _look_base_center
	var max_r := LOOK_STICK_RADIUS
	if offset.length() > max_r:
		offset = offset.limit_length(max_r)
	# Visual knob follows finger within radius
	if _look_knob:
		var half := _look_knob.size * 0.5
		_look_knob.position = _look_base_center + offset - half
	var n := offset / max_r
	var mag := n.length()
	if mag < LOOK_DEADZONE:
		_look_stick_vec = Vector2.ZERO
	else:
		# Remap deadzone → 1.0 so leaving deadzone starts from 0
		var remapped := (mag - LOOK_DEADZONE) / (1.0 - LOOK_DEADZONE)
		_look_stick_vec = n.normalized() * clampf(remapped, 0.0, 1.0)

func _make_action_button(label: String, min_size: Vector2, emphasize: bool) -> Button:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_SHRINK_END
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.12, 0.14, 0.2, 0.58 if emphasize else 0.42)
	normal.border_color = Color(1, 1, 1, 0.6 if emphasize else 0.35)
	normal.set_border_width_all(2)
	var radius := int(minf(min_size.x, min_size.y) * 0.5)
	normal.set_corner_radius_all(radius)
	normal.content_margin_left = 8
	normal.content_margin_right = 8
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6
	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.25, 0.45, 0.75, 0.78)
	var hover := normal.duplicate()
	hover.bg_color = Color(0.18, 0.22, 0.32, 0.65)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", normal)
	b.add_theme_font_size_override("font_size", 18 if emphasize else 13)
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
	# Prefer touch_firing only — do not synthesize InputMap "fire".
	if player and is_instance_valid(player):
		player.set_touch_firing(pressed)

func _on_melee_pressed() -> void:
	if player and is_instance_valid(player):
		player.request_melee()

func _release_all_actions() -> void:
	for a in ["fire", "reload", "melee", "dash", "jump", "use_health", "use_energy", "use_ammo", "use_alcohol"]:
		if InputMap.has_action(a):
			Input.action_release(a)

func _push_move() -> void:
	if player and is_instance_valid(player):
		player.set_touch_move(_touch_move)
