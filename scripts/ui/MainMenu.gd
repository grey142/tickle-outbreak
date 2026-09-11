extends Control

@onready var start_btn: Button = $Center/VBox/Start
@onready var quit_btn: Button = $Center/VBox/Quit
@onready var title: Label = $Center/VBox/Title
@onready var blurb: Label = $Center/VBox/Blurb
@onready var touch_toggle: CheckButton = $Center/VBox/TouchControls

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	title.text = "TICKLE OUTBREAK"
	blurb.text = "A first-person tickle-zombie survival FPS.\nTongue-in-cheek vertical slice for Godot 4.3+."
	if touch_toggle:
		touch_toggle.button_pressed = GameState.force_mobile_controls
		touch_toggle.toggled.connect(func(on: bool):
			GameState.force_mobile_controls = on
		)
	start_btn.pressed.connect(func():
		GameState.reset_run()
		# Preserve touch toggle across reset_run
		var keep_touch := touch_toggle.button_pressed if touch_toggle else GameState.force_mobile_controls
		GameState.force_mobile_controls = keep_touch
		# Starter coins so shops are testable early
		GameState.add_coins(100)
		get_tree().change_scene_to_file("res://scenes/hub/Hub.tscn")
	)
	quit_btn.pressed.connect(func(): get_tree().quit())
