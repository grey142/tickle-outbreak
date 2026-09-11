extends CanvasLayer
class_name GameOverUI

@onready var panel: PanelContainer = $Panel
@onready var title: Label = $Panel/Margin/VBox/Title
@onready var subtitle: Label = $Panel/Margin/VBox/Subtitle
@onready var retry_btn: Button = $Panel/Margin/VBox/Retry
@onready var hub_btn: Button = $Panel/Margin/VBox/Hub

var _cleared: bool = false

func _ready() -> void:
	panel.visible = false
	retry_btn.pressed.connect(_on_retry)
	hub_btn.pressed.connect(_on_hub)
	EventBus.player_died.connect(_on_died)
	EventBus.mission_cleared.connect(_on_cleared)

func _on_died(reason: String) -> void:
	_cleared = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	panel.visible = true
	title.text = reason
	subtitle.text = "You were tickled into infection. Mission failed."
	retry_btn.text = "Retry Mission"
	retry_btn.visible = true
	hub_btn.text = "Return to Hub"

func _on_cleared() -> void:
	_cleared = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	panel.visible = true
	title.text = "Mission Clear!"
	subtitle.text = "Quota met. Return to hub for shops & next mission."
	retry_btn.visible = false
	hub_btn.text = "Return to Hub"

func _on_retry() -> void:
	GameState.prepare_mission()
	get_tree().change_scene_to_file("res://scenes/mission/Mission.tscn")

func _on_hub() -> void:
	if _cleared:
		GameState.advance_mission()
	get_tree().change_scene_to_file("res://scenes/hub/Hub.tscn")
