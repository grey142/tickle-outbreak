extends CanvasLayer
class_name TickleCinematic
## Top-left Olivia Grace face reaction panel driven by active ticklers + stamina.

@onready var panel: PanelContainer = $Panel
@onready var face: TextureRect = $Panel/Face

const PANEL_SIZE := 200.0
const MAX_FACE := 5

var _face_tex: Array[Texture2D] = []
var _tired_tex: Array[Texture2D] = []
var _last_count: int = -1
var _last_tired: bool = false

func _ready() -> void:
	_load_faces()
	_ensure_layout()
	panel.visible = false
	EventBus.active_ticklers_changed.connect(_on_ticklers)

func _load_faces() -> void:
	_face_tex.clear()
	_tired_tex.clear()
	for i in range(1, MAX_FACE + 1):
		var normal_path := "res://assets/survivor/faces/face_%d.png" % i
		var tired_path := "res://assets/survivor/faces/face_%d_tired.png" % i
		_face_tex.append(load(normal_path) as Texture2D)
		_tired_tex.append(load(tired_path) as Texture2D)

func _ensure_layout() -> void:
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = 8.0
	panel.offset_top = 8.0
	panel.offset_right = 8.0 + PANEL_SIZE
	panel.offset_bottom = 8.0 + PANEL_SIZE
	panel.custom_minimum_size = Vector2(PANEL_SIZE, PANEL_SIZE)
	panel.grow_horizontal = Control.GROW_DIRECTION_END
	panel.grow_vertical = Control.GROW_DIRECTION_END
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.08, 0.82)
	sb.border_color = Color(1.0, 0.72, 0.38, 0.9)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 4
	sb.content_margin_top = 4
	sb.content_margin_right = 4
	sb.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", sb)
	if face:
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		face.size_flags_vertical = Control.SIZE_EXPAND_FILL

func _on_ticklers(count: int, stamina_depleted: bool = false) -> void:
	if count <= 0:
		panel.visible = false
		_last_count = 0
		_last_tired = stamina_depleted
		return
	var n := clampi(count, 1, MAX_FACE)
	var tired := stamina_depleted
	if n == _last_count and tired == _last_tired and panel.visible:
		return
	_last_count = n
	_last_tired = tired
	var tex: Texture2D = null
	if tired and n - 1 < _tired_tex.size():
		tex = _tired_tex[n - 1]
	elif n - 1 < _face_tex.size():
		tex = _face_tex[n - 1]
	if tex == null:
		panel.visible = false
		return
	face.texture = tex
	panel.visible = true
	# Soft pulse as intensity rises
	panel.modulate = Color(1, 1, 1, 0.92 + 0.015 * float(n))
