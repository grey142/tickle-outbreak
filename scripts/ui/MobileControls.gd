extends CanvasLayer
class_name MobileControls
## Landscape phone touch controls: large move + look virtual joysticks, right-edge actions.

signal mobile_visibility_changed(shown: bool)

## Radians per second at full look-stick deflection (from player_stats touch_look_sensitivity).
@export var look_sensitivity: float = 2.8

var player: PlayerController
var _shown: bool = false

var _root: Control
var _hint: Label
var _fill: Control

var _touch_move: Vector2 = Vector2.ZERO

## Shared stick geometry (computed from viewport — ~1/4 of bottom each).
var _stick_radius: float = 140.0
const STICK_DEADZONE := 0.13

## Move joystick
var _move_stick_active: bool = false
var _move_stick_touch_idx: int = -1
var _move_stick_vec: Vector2 = Vector2.ZERO
var _move_base: Control
var _move_knob: Control
var _move_hit: Control
var _move_base_center: Vector2 = Vector2.ZERO
var _move_wrap: Control

## Look joystick
var _look_stick_active: bool = false
var _look_stick_touch_idx: int = -1
var _look_stick_vec: Vector2 = Vector2.ZERO
var _look_base: Control
var _look_knob: Control
var _look_hit: Control
var _look_base_center: Vector2 = Vector2.ZERO
var _look_wrap: Control

## Synthetic mouse indices when emulating touch from mouse on desktop.
const MOVE_MOUSE_IDX := 1000
const LOOK_MOUSE_IDX := 1001
## Active real screen touches (web mouse-emulation must not fight these).
var _screen_touches: int = 0

const ACTION_BIG := Vector2(100, 52)
const ACTION_MED := Vector2(96, 44)
const ACTION_SM := Vector2(92, 40)
const CONSUMABLE := Vector2(84, 34)

func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	if DataManager and DataManager.player_stats:
		look_sensitivity = float(DataManager.player_stats.get("touch_look_sensitivity", look_sensitivity))
	_build_ui()
	_refresh_visibility()
	set_process(true)
	get_viewport().size_changed.connect(_on_viewport_resized)

func bind_player(p: PlayerController) -> void:
	player = p
	_apply_player_mobile_mode()

func _process(delta: float) -> void:
	var want := _should_show()
	if want != _shown:
		_set_shown(want)
	# Rate-based look while stick is deflected (works with move stick + buttons multitouch).
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
			if _move_stick_touch_idx == MOVE_MOUSE_IDX:
				_reset_move_stick()
		else:
			_screen_touches = maxi(_screen_touches - 1, 0)
			if st.index == _look_stick_touch_idx:
				_reset_look_stick()
			if st.index == _move_stick_touch_idx:
				_reset_move_stick()

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
		player.set_touch_move(Vector2.ZERO)
		player.set_touch_firing(false)
		_reset_look_stick()
		_reset_move_stick()
		_screen_touches = 0
		_release_all_actions()

func _compute_stick_radius() -> float:
	## Each stick ≈ quarter of the bottom: diameter ~min(28% width, 48% height).
	var vp := get_viewport().get_visible_rect().size
	if vp.x < 1.0 or vp.y < 1.0:
		vp = Vector2(1280, 720)
	var r := minf(vp.x * 0.14, vp.y * 0.24)
	return clampf(r, 96.0, 200.0)

func _on_viewport_resized() -> void:
	var new_r := _compute_stick_radius()
	if absf(new_r - _stick_radius) < 1.0:
		return
	_stick_radius = new_r
	# Rebuild stick visuals in place by updating wrap sizes / styles.
	_apply_stick_geometry(_move_wrap, _move_base, _move_knob, true)
	_apply_stick_geometry(_look_wrap, _look_base, _look_knob, false)
	_layout_action_strip()

func _build_ui() -> void:
	_stick_radius = _compute_stick_radius()

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
	var pad_l := 16
	var pad_r := 16
	var pad_b := 12
	var pad_t := 8
	if win.x > 0 and win.y > 0 and sa.size.x > 0:
		pad_l = maxi(16, sa.position.x)
		pad_t = maxi(8, sa.position.y)
		pad_r = maxi(16, win.x - (sa.position.x + sa.size.x))
		pad_b = maxi(12, win.y - (sa.position.y + sa.size.y))
	margin.add_theme_constant_override("margin_left", pad_l)
	margin.add_theme_constant_override("margin_right", pad_r)
	margin.add_theme_constant_override("margin_top", pad_t)
	margin.add_theme_constant_override("margin_bottom", pad_b)
	_root.add_child(margin)

	_fill = Control.new()
	_fill.name = "Fill"
	_fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(_fill)

	_build_move_joystick(_fill)
	_build_look_joystick(_fill)
	_build_action_strip(_fill)

	_hint = Label.new()
	_hint.name = "TouchHint"
	_hint.text = "Move stick (BL) · Look stick (BR) · actions above look"
	_hint.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_hint.anchor_left = 1.0
	_hint.anchor_right = 1.0
	_hint.anchor_top = 0.0
	_hint.anchor_bottom = 0.0
	_hint.offset_left = -520.0
	_hint.offset_top = 8.0
	_hint.offset_right = -8.0
	_hint.offset_bottom = 36.0
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.modulate = Color(1, 1, 1, 0.55)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill.add_child(_hint)

func _stick_wrap_size() -> float:
	return _stick_radius * 2.0 + 12.0

func _build_move_joystick(fill: Control) -> void:
	## Bottom-left ~quarter: large virtual move stick.
	var sz := _stick_wrap_size()
	_move_wrap = Control.new()
	_move_wrap.name = "MoveJoystick"
	_move_wrap.custom_minimum_size = Vector2(sz, sz)
	_move_wrap.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_move_wrap.anchor_left = 0.0
	_move_wrap.anchor_right = 0.0
	_move_wrap.anchor_top = 1.0
	_move_wrap.anchor_bottom = 1.0
	_move_wrap.offset_left = 4.0
	_move_wrap.offset_top = -sz - 4.0
	_move_wrap.offset_right = sz + 4.0
	_move_wrap.offset_bottom = -4.0
	_move_wrap.mouse_filter = Control.MOUSE_FILTER_STOP
	fill.add_child(_move_wrap)

	_move_base = _make_stick_base("MoveBase")
	_move_wrap.add_child(_move_base)
	_move_knob = _make_stick_knob("MoveKnob", Color(0.4, 0.85, 0.55, 0.78))
	_move_wrap.add_child(_move_knob)

	_move_hit = Control.new()
	_move_hit.name = "Hit"
	_move_hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_move_hit.mouse_filter = Control.MOUSE_FILTER_STOP
	_move_hit.gui_input.connect(_on_move_stick_gui_input)
	_move_wrap.add_child(_move_hit)

	_move_wrap.resized.connect(func():
		_move_base_center = _move_wrap.size * 0.5
		_center_knob(_move_knob, _move_base_center)
	)
	call_deferred("_deferred_center_move")

func _build_look_joystick(fill: Control) -> void:
	## Bottom-right ~quarter: large virtual look stick (same size family as move).
	var sz := _stick_wrap_size()
	_look_wrap = Control.new()
	_look_wrap.name = "LookJoystick"
	_look_wrap.custom_minimum_size = Vector2(sz, sz)
	_look_wrap.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_look_wrap.anchor_left = 1.0
	_look_wrap.anchor_right = 1.0
	_look_wrap.anchor_top = 1.0
	_look_wrap.anchor_bottom = 1.0
	_look_wrap.offset_left = -sz - 4.0
	_look_wrap.offset_top = -sz - 4.0
	_look_wrap.offset_right = -4.0
	_look_wrap.offset_bottom = -4.0
	_look_wrap.mouse_filter = Control.MOUSE_FILTER_STOP
	fill.add_child(_look_wrap)

	_look_base = _make_stick_base("LookBase")
	_look_wrap.add_child(_look_base)
	_look_knob = _make_stick_knob("LookKnob", Color(0.35, 0.55, 0.9, 0.78))
	_look_wrap.add_child(_look_knob)

	_look_hit = Control.new()
	_look_hit.name = "Hit"
	_look_hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_look_hit.mouse_filter = Control.MOUSE_FILTER_STOP
	_look_hit.gui_input.connect(_on_look_stick_gui_input)
	_look_wrap.add_child(_look_hit)

	_look_wrap.resized.connect(func():
		_look_base_center = _look_wrap.size * 0.5
		_center_knob(_look_knob, _look_base_center)
	)
	call_deferred("_deferred_center_look")

var _actions_root: Control

func _build_action_strip(fill: Control) -> void:
	## Right-edge actions clustered upper-right / above the look stick (joysticks stay large).
	_actions_root = Control.new()
	_actions_root.name = "ActionStrip"
	_actions_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.add_child(_actions_root)

	var actions := VBoxContainer.new()
	actions.name = "Actions"
	actions.add_theme_constant_override("separation", 3)
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.size_flags_horizontal = Control.SIZE_SHRINK_END
	actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_actions_root.add_child(actions)

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

	_layout_action_strip()

func _layout_action_strip() -> void:
	if _actions_root == null or not is_instance_valid(_actions_root):
		return
	var sz := _stick_wrap_size()
	var strip_w := 112.0
	# Sit above look stick on the right edge; leave ~stick height free at bottom.
	_actions_root.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_actions_root.anchor_left = 1.0
	_actions_root.anchor_right = 1.0
	_actions_root.anchor_top = 1.0
	_actions_root.anchor_bottom = 1.0
	_actions_root.offset_left = -strip_w - 4.0
	_actions_root.offset_right = -4.0
	_actions_root.offset_bottom = -sz - 8.0
	_actions_root.offset_top = -sz - 8.0 - 420.0
	var actions := _actions_root.get_node_or_null("Actions") as Control
	if actions:
		actions.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		actions.anchor_top = 0.0
		actions.anchor_bottom = 1.0
		actions.offset_top = 0.0
		actions.offset_bottom = 0.0

func _make_stick_base(p_name: String) -> Panel:
	var base := Panel.new()
	base.name = p_name
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var base_style := StyleBoxFlat.new()
	base_style.bg_color = Color(0.1, 0.12, 0.18, 0.5)
	base_style.border_color = Color(1, 1, 1, 0.38)
	base_style.set_border_width_all(2)
	base_style.set_corner_radius_all(int(_stick_radius + 6.0))
	base.add_theme_stylebox_override("panel", base_style)
	return base

func _make_stick_knob(p_name: String, color: Color) -> Panel:
	var knob_r := _stick_radius * 0.4
	var knob := Panel.new()
	knob.name = p_name
	knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	knob.custom_minimum_size = Vector2(knob_r * 2.0, knob_r * 2.0)
	knob.size = Vector2(knob_r * 2.0, knob_r * 2.0)
	var knob_style := StyleBoxFlat.new()
	knob_style.bg_color = color
	knob_style.border_color = Color(1, 1, 1, 0.65)
	knob_style.set_border_width_all(2)
	knob_style.set_corner_radius_all(int(knob_r))
	knob.add_theme_stylebox_override("panel", knob_style)
	return knob

func _apply_stick_geometry(wrap: Control, base: Control, knob: Control, is_move: bool) -> void:
	if wrap == null or not is_instance_valid(wrap):
		return
	var sz := _stick_wrap_size()
	wrap.custom_minimum_size = Vector2(sz, sz)
	if is_move:
		wrap.offset_left = 4.0
		wrap.offset_top = -sz - 4.0
		wrap.offset_right = sz + 4.0
		wrap.offset_bottom = -4.0
	else:
		wrap.offset_left = -sz - 4.0
		wrap.offset_top = -sz - 4.0
		wrap.offset_right = -4.0
		wrap.offset_bottom = -4.0
	if base is Panel:
		var bs := (base as Panel).get_theme_stylebox("panel") as StyleBoxFlat
		if bs:
			bs.set_corner_radius_all(int(_stick_radius + 6.0))
	if knob is Panel:
		var knob_r := _stick_radius * 0.4
		knob.custom_minimum_size = Vector2(knob_r * 2.0, knob_r * 2.0)
		knob.size = Vector2(knob_r * 2.0, knob_r * 2.0)
		var ks := (knob as Panel).get_theme_stylebox("panel") as StyleBoxFlat
		if ks:
			ks.set_corner_radius_all(int(knob_r))
	var center := wrap.size * 0.5
	if center.length_squared() < 1.0:
		center = Vector2(_stick_radius + 6.0, _stick_radius + 6.0)
	if is_move:
		_move_base_center = center
		_center_knob(_move_knob, _move_base_center)
	else:
		_look_base_center = center
		_center_knob(_look_knob, _look_base_center)

func _deferred_center_move() -> void:
	if not is_instance_valid(_move_wrap):
		return
	_move_base_center = _move_wrap.size * 0.5
	if _move_base_center.length_squared() < 1.0:
		_move_base_center = Vector2(_stick_radius + 6.0, _stick_radius + 6.0)
	_center_knob(_move_knob, _move_base_center)

func _deferred_center_look() -> void:
	if not is_instance_valid(_look_wrap):
		return
	_look_base_center = _look_wrap.size * 0.5
	if _look_base_center.length_squared() < 1.0:
		_look_base_center = Vector2(_stick_radius + 6.0, _stick_radius + 6.0)
	_center_knob(_look_knob, _look_base_center)

func _center_knob(knob: Control, center: Vector2) -> void:
	if knob == null:
		return
	var half := knob.size * 0.5
	knob.position = center - half

func _reset_move_stick() -> void:
	_move_stick_active = false
	_move_stick_touch_idx = -1
	_move_stick_vec = Vector2.ZERO
	_touch_move = Vector2.ZERO
	_center_knob(_move_knob, _move_base_center)
	_push_move()

func _reset_look_stick() -> void:
	_look_stick_active = false
	_look_stick_touch_idx = -1
	_look_stick_vec = Vector2.ZERO
	_center_knob(_look_knob, _look_base_center)

func _on_move_stick_gui_input(event: InputEvent) -> void:
	if not _shown:
		return
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			if _move_stick_touch_idx == MOVE_MOUSE_IDX:
				_reset_move_stick()
			if _move_stick_touch_idx < 0:
				_move_stick_touch_idx = st.index
				_move_stick_active = true
				_update_move_stick_from_local(st.position)
				_move_hit.accept_event()
		elif st.index == _move_stick_touch_idx:
			_reset_move_stick()
			_move_hit.accept_event()
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if sd.index == _move_stick_touch_idx:
			_update_move_stick_from_local(sd.position)
			_move_hit.accept_event()
	elif _screen_touches == 0 and event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and _move_stick_touch_idx < 0:
				_move_stick_touch_idx = MOVE_MOUSE_IDX
				_move_stick_active = true
				_update_move_stick_from_local(mb.position)
				_move_hit.accept_event()
			elif not mb.pressed and _move_stick_touch_idx == MOVE_MOUSE_IDX:
				_reset_move_stick()
				_move_hit.accept_event()
	elif _screen_touches == 0 and event is InputEventMouseMotion and _move_stick_touch_idx == MOVE_MOUSE_IDX:
		var mm := event as InputEventMouseMotion
		_update_move_stick_from_local(mm.position)
		_move_hit.accept_event()

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

func _update_move_stick_from_local(local_pos: Vector2) -> void:
	var n := _stick_normalized(local_pos, _move_base_center, _move_knob)
	_move_stick_vec = n
	# Input.get_vector convention: forward=-y, back=+y, left=-x, right=+x
	_touch_move = n
	_push_move()

func _update_look_stick_from_local(local_pos: Vector2) -> void:
	_look_stick_vec = _stick_normalized(local_pos, _look_base_center, _look_knob)

func _stick_normalized(local_pos: Vector2, center: Vector2, knob: Control) -> Vector2:
	var offset := local_pos - center
	var max_r := _stick_radius
	if offset.length() > max_r:
		offset = offset.limit_length(max_r)
	if knob:
		var half := knob.size * 0.5
		knob.position = center + offset - half
	var n := offset / max_r
	var mag := n.length()
	if mag < STICK_DEADZONE:
		return Vector2.ZERO
	var remapped := (mag - STICK_DEADZONE) / (1.0 - STICK_DEADZONE)
	return n.normalized() * clampf(remapped, 0.0, 1.0)

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
	b.add_theme_font_size_override("font_size", 17 if emphasize else 12)
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
