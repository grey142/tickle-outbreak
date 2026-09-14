extends CanvasLayer
class_name GameOverUI

@onready var defeat_art: TextureRect = $DefeatArt
@onready var panel: PanelContainer = $Panel
@onready var title: Label = $Panel/Margin/VBox/Title
@onready var subtitle: Label = $Panel/Margin/VBox/Subtitle
@onready var retry_btn: Button = $Panel/Margin/VBox/Retry
@onready var hub_btn: Button = $Panel/Margin/VBox/Hub

const SCENES_PATH := "res://data/gameover_scenes.json"

var _cleared: bool = false
var _defeat_scenes: Array = []

func _ready() -> void:
	panel.visible = false
	defeat_art.visible = false
	_load_defeat_scenes()
	retry_btn.pressed.connect(_on_retry)
	hub_btn.pressed.connect(_on_hub)
	EventBus.player_died.connect(_on_died)
	EventBus.mission_cleared.connect(_on_cleared)

func _load_defeat_scenes() -> void:
	_defeat_scenes.clear()
	var f := FileAccess.open(SCENES_PATH, FileAccess.READ)
	if f == null:
		push_warning("GameOverUI: missing %s" % SCENES_PATH)
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("GameOverUI: invalid JSON at %s" % SCENES_PATH)
		return
	var scenes: Array = parsed.get("scenes", [])
	for s in scenes:
		_defeat_scenes.append(String(s))

func _pick_defeat_texture() -> Texture2D:
	if _defeat_scenes.is_empty():
		return null
	var pick: String = String(_defeat_scenes[randi() % _defeat_scenes.size()])
	if ResourceLoader.exists(pick):
		return load(pick) as Texture2D
	push_warning("GameOverUI: defeat scene missing: %s" % pick)
	return null

func _show_defeat_art() -> void:
	var tex := _pick_defeat_texture()
	defeat_art.texture = tex
	defeat_art.visible = tex != null

func _hide_defeat_art() -> void:
	defeat_art.visible = false
	defeat_art.texture = null

func _on_died(reason: String) -> void:
	_cleared = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_show_defeat_art()
	panel.visible = true
	title.text = reason
	subtitle.text = "You were tickled into infection. Mission failed."
	retry_btn.text = "Retry Mission"
	retry_btn.visible = true
	hub_btn.text = "Return to Hub"

func _on_cleared() -> void:
	_cleared = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_hide_defeat_art()
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
