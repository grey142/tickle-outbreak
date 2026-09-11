extends CanvasLayer
class_name TickleCinematic
## Square top-left viewport: stacked tickler silhouettes (1–5) + short lore line.

@onready var panel: PanelContainer = $Panel
@onready var title: Label = $Panel/Margin/VBox/Title
@onready var body: Label = $Panel/Margin/VBox/Body
@onready var count_label: Label = $Panel/Margin/VBox/Count
@onready var stack: Control = $Panel/Margin/VBox/Stack

var placeholders := {
	1: "A lone tickler latches on!",
	2: "Two ticklers tag-team.",
	3: "Triple threat!",
	4: "Four — cinematic chaos!",
	5: "FIVE — giggle overload!"
}

var _silhouettes: Array[ColorRect] = []
const MAX_STACK := 5
const SQUARE := 132.0

func _ready() -> void:
	_ensure_square_layout()
	_build_stack_slots()
	panel.visible = false
	EventBus.active_ticklers_changed.connect(_on_ticklers)

func _ensure_square_layout() -> void:
	## Clear square frame, top-left — leaves room for health bar to the right.
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = 10.0
	panel.offset_top = 10.0
	panel.offset_right = 10.0 + SQUARE
	panel.offset_bottom = 10.0 + SQUARE
	panel.custom_minimum_size = Vector2(SQUARE, SQUARE)
	panel.grow_horizontal = Control.GROW_DIRECTION_END
	panel.grow_vertical = Control.GROW_DIRECTION_END
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.1, 0.78)
	sb.border_color = Color(1.0, 0.75, 0.35, 0.85)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", sb)
	if title:
		title.add_theme_font_size_override("font_size", 11)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if count_label:
		count_label.add_theme_font_size_override("font_size", 10)
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if body:
		body.add_theme_font_size_override("font_size", 9)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _build_stack_slots() -> void:
	if stack == null:
		return
	for c in stack.get_children():
		c.queue_free()
	_silhouettes.clear()
	stack.custom_minimum_size = Vector2(0, 48)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Layered silhouette slots that "stack up" visually
	var colors := [
		Color(0.55, 0.85, 0.45, 0.9),
		Color(0.45, 0.75, 0.55, 0.9),
		Color(0.7, 0.9, 0.4, 0.9),
		Color(0.4, 0.7, 0.5, 0.9),
		Color(0.85, 0.95, 0.35, 0.95),
	]
	for i in range(MAX_STACK):
		var sil := ColorRect.new()
		sil.name = "Silhouette%d" % (i + 1)
		sil.color = colors[i]
		sil.visible = false
		sil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Offset each layer so they read as a stack
		var base_x := 18.0 + float(i) * 8.0
		var base_y := 28.0 - float(i) * 5.0
		sil.position = Vector2(base_x, base_y)
		sil.size = Vector2(28.0 - float(i) * 1.5, 36.0 - float(i) * 1.0)
		# Round-ish via clip isn't available on ColorRect; keep rectangular placeholders
		stack.add_child(sil)
		_silhouettes.append(sil)

func _on_ticklers(count: int) -> void:
	if count >= 1 and count <= 5:
		panel.visible = true
		title.text = "TICKLE"
		count_label.text = "%d / 5" % count
		body.text = placeholders.get(count, "Tickle frenzy!")
		panel.modulate = Color(1, 1, 1, 0.88 + 0.02 * count)
		for i in range(_silhouettes.size()):
			_silhouettes[i].visible = i < count
	else:
		panel.visible = false
		for s in _silhouettes:
			s.visible = false
