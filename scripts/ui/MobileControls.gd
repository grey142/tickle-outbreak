extends CanvasLayer
class_name MobileControls
## Landscape phone touch controls: D-pad move, swipe look, right action cluster.

signal mobile_visibility_changed(shown: bool)

@export var look_sensitivity: float = 0.002

var player: PlayerController
var _shown: bool = false

var _root: Control
var _look_zone: Control
var _hint: Label

var _look_touch_idx: int = -1
var _fwd_held: bool = false
var _back_held: bool = false
var _left_held: bool = false
var _right_held: bool = false
var _touch_move: Vector2 = Vector2.ZERO
var _look_avg: Vector2 = Vector2.ZERO
## Active real screen touches (web mouse-emulation must not fight these).
var _screen_touches: int = 0
const LOOK_DELTA_CLAMP := 48.0

const DPAD_BTN := Vector2(96, 96)
const ACTION_BIG := Vector2(116, 116)
const ACTION_MED := Vector2(106, 86)
const ACTION_SM := Vector2(96, 72)
const CONSUMABLE := Vector2(82, 62)

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
		_look_touch_idx = -1
		_look_avg = Vector2.ZERO
		_screen_touches = 0
		# Clear any queued melee / synthetic InputMap presses
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

	# Look zone avoids bottom-left D-pad and bottom-right actions so multitouch
	# move/fire fingers never start a look drag (fixes camera shake on phones/web).
	_look_zone = ColorRect.new()
	_look_zone.name = "LookZone"
	_look_zone.color = Color(0, 0, 0, 0)
	_look_zone.set_anchors_preset(Control.PRESET_FULL_RECT)
	_look_zone.anchor_left = 0.28
	_look_zone.anchor_right = 0.62
	_look_zone.anchor_top = 0.0
	_look_zone.anchor_bottom = 0.72
	_look_zone.offset_left = 0.0
	_look_zone.offset_right = 0.0
	_look_zone.offset_top = 0.0
	_look_zone.offset_bottom = 0.0
	_look_zone.mouse_filter = Control.MOUSE_FILTER_STOP
	_look_zone.gui_input.connect(_on_look_gui_input)
	fill.add_child(_look_zone)

	_build_dpad(fill)
	_build_actions(fill)

	_hint = Label.new()
	_hint.name = "TouchHint"
	_hint.text = "D-pad move · swipe look · FIRE / MELEE / DASH"
	_hint.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_hint.anchor_left = 1.0
	_hint.anchor_right = 1.0
	_hint.anchor_top = 0.0
	_hint.anchor_bottom = 0.0
	_hint.offset_left = -460.0
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
	# Fully circular (half of square button size)
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

func _build_actions(fill: Control) -> void:
	## Right / bottom-right: Dash above; Fire + Melee prominent; Reload smaller; consumables strip.
	var actions := VBoxContainer.new()
	actions.name = "Actions"
	actions.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	actions.anchor_left = 1.0
	actions.anchor_right = 1.0
	actions.anchor_top = 1.0
	actions.anchor_bottom = 1.0
	actions.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	actions.grow_vertical = Control.GROW_DIRECTION_BEGIN
	actions.offset_left = -400.0
	actions.offset_top = -440.0
	actions.offset_right = -6.0
	actions.offset_bottom = -6.0
	actions.add_theme_constant_override("separation", 10)
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.add_child(actions)

	# Dash above the fire/melee cluster
	var dash_row := HBoxContainer.new()
	dash_row.add_theme_constant_override("separation", 10)
	dash_row.alignment = BoxContainer.ALIGNMENT_END
	actions.add_child(dash_row)
	var btn_dash := _make_action_button("DASH", ACTION_MED, false)
	_wire_action_button(btn_dash, "dash")
	dash_row.add_child(btn_dash)

	# Fire + Melee prominent
	var combat_row := HBoxContainer.new()
	combat_row.add_theme_constant_override("separation", 12)
	combat_row.alignment = BoxContainer.ALIGNMENT_END
	actions.add_child(combat_row)
	var btn_fire := _make_action_button("FIRE", ACTION_BIG, true)
	btn_fire.button_down.connect(func(): _set_firing(true))
	btn_fire.button_up.connect(func(): _set_firing(false))
	combat_row.add_child(btn_fire)
	var btn_melee := _make_action_button("MELEE", ACTION_BIG, true)
	btn_melee.button_down.connect(_on_melee_pressed)
	combat_row.add_child(btn_melee)

	# Reload (+ small jump) near cluster
	var util_row := HBoxContainer.new()
	util_row.add_theme_constant_override("separation", 10)
	util_row.alignment = BoxContainer.ALIGNMENT_END
	actions.add_child(util_row)
	var btn_reload := _make_action_button("RELOAD", ACTION_SM, false)
	_wire_action_button(btn_reload, "reload")
	util_row.add_child(btn_reload)
	var btn_jump := _make_action_button("JUMP", ACTION_SM, false)
	_wire_action_button(btn_jump, "jump")
	util_row.add_child(btn_jump)

	# Compact consumables strip
	var cons_row := HBoxContainer.new()
	cons_row.add_theme_constant_override("separation", 8)
	cons_row.alignment = BoxContainer.ALIGNMENT_END
	actions.add_child(cons_row)
	for pair in [["HP", "use_health"], ["NRG", "use_energy"], ["AMMO", "use_ammo"], ["ALC", "use_alcohol"]]:
		var btn := _make_action_button(pair[0], CONSUMABLE, false)
		_wire_action_button(btn, pair[1])
		cons_row.add_child(btn)

func _make_action_button(label: String, min_size: Vector2, emphasize: bool) -> Button:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.12, 0.14, 0.2, 0.58 if emphasize else 0.42)
	normal.border_color = Color(1, 1, 1, 0.6 if emphasize else 0.35)
	normal.set_border_width_all(2)
	# Pill / near-circle: radius = half of shorter side
	var radius := int(minf(min_size.x, min_size.y) * 0.5)
	normal.set_corner_radius_all(radius)
	normal.content_margin_left = 10
	normal.content_margin_right = 10
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.25, 0.45, 0.75, 0.78)
	var hover := normal.duplicate()
	hover.bg_color = Color(0.18, 0.22, 0.32, 0.65)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", normal)
	b.add_theme_font_size_override("font_size", 22 if emphasize else 16)
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
	# Prefer touch_firing only — do not synthesize InputMap "fire" (LookZone / mouse LMB shares that action).
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

func _on_look_gui_input(event: InputEvent) -> void:
	if not _shown:
		return
	# Real multitouch path — never mix with mouse emulation while fingers are down.
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_screen_touches = maxi(_screen_touches + 1, 1)
			# Cancel mouse-emulated look; finger index owns look exclusively.
			if _look_touch_idx == 1001:
				_look_touch_idx = -1
				_look_avg = Vector2.ZERO
			if _look_touch_idx < 0 and _point_allows_look(st.position):
				_look_touch_idx = st.index
				_look_avg = Vector2.ZERO
				_look_zone.accept_event()
		else:
			_screen_touches = maxi(_screen_touches - 1, 0)
			if st.index == _look_touch_idx:
				_look_touch_idx = -1
				_look_avg = Vector2.ZERO
				_look_zone.accept_event()
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if sd.index == _look_touch_idx:
			_apply_look(sd.relative)
			_look_zone.accept_event()
	# Mouse / single-finger desktop test only when no real screen touches.
	elif _screen_touches == 0 and event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and _look_touch_idx < 0 and _point_allows_look(mb.position):
				_look_touch_idx = 1001
				_look_avg = Vector2.ZERO
				_look_zone.accept_event()
			elif not mb.pressed and _look_touch_idx == 1001:
				_look_touch_idx = -1
				_look_avg = Vector2.ZERO
				_look_zone.accept_event()
	elif _screen_touches == 0 and event is InputEventMouseMotion and _look_touch_idx == 1001:
		var mm := event as InputEventMouseMotion
		_apply_look(mm.relative)
		_look_zone.accept_event()

func _point_allows_look(local_pos: Vector2) -> bool:
	## local_pos is in LookZone space; zone is already inset, so any press here is OK
	## unless a button is somehow on top (safety check via viewport).
	var global_pt := _look_zone.global_position + local_pos
	var hovered := get_viewport().gui_get_hovered_control()
	if hovered != null and hovered is BaseButton:
		return false
	# Also reject if clearly over D-pad / action clusters in screen space.
	var vp := get_viewport().get_visible_rect().size
	if vp.x <= 1.0 or vp.y <= 1.0:
		return true
	var nx := global_pt.x / vp.x
	var ny := global_pt.y / vp.y
	# Bottom-left D-pad
	if nx < 0.34 and ny > 0.55:
		return false
	# Bottom-right actions
	if nx > 0.66 and ny > 0.40:
		return false
	return true

func _apply_look(relative: Vector2) -> void:
	# Clamp spike deltas from multitouch / mouse-emulation jumps, then smooth.
	var clamped := relative.limit_length(LOOK_DELTA_CLAMP)
	_look_avg = _look_avg.lerp(clamped, 0.45)
	var smoothed := _look_avg
	_look_avg *= 0.55
	if player and is_instance_valid(player):
		player.apply_touch_look(smoothed * look_sensitivity)
