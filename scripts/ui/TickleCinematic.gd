extends CanvasLayer
class_name TickleCinematic
## Cinematic panel when 1–5 zombies are actively dealing tickle damage.

@onready var panel: PanelContainer = $Panel
@onready var title: Label = $Panel/Margin/VBox/Title
@onready var body: Label = $Panel/Margin/VBox/Body
@onready var count_label: Label = $Panel/Margin/VBox/Count

var placeholders := {
	1: "A lone tickler latches on — toes and ribs under siege!",
	2: "Two ticklers tag-team. Soft stomach lore intensifies.",
	3: "Triple threat! Laughter infection spreading...",
	4: "Four active ticklers — cinematic chaos mode!",
	5: "FIVE ticklers! Maximum giggle overload (placeholder art)."
}

func _ready() -> void:
	panel.visible = false
	EventBus.active_ticklers_changed.connect(_on_ticklers)

func _on_ticklers(count: int) -> void:
	if count >= 1 and count <= 5:
		panel.visible = true
		title.text = "TICKLE CINEMATIC"
		count_label.text = "Active ticklers: %d" % count
		body.text = placeholders.get(count, "Tickle frenzy!")
		# Slight scale pulse by count
		panel.modulate = Color(1, 1, 1, 0.85 + 0.03 * count)
	else:
		panel.visible = false
