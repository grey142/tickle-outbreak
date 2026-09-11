extends Node
## Call from GameOverUI when clearing: advances mission once.

static func on_clear_return_to_hub(tree: SceneTree) -> void:
	GameState.advance_mission()
	tree.change_scene_to_file("res://scenes/hub/Hub.tscn")
