extends Control
## Title screen. Per the GDD, New Game always shows; Continue / Manage Save
## appear only once a campaign autosave exists (no save system yet).

const GAMEPLAY_SCENE := "res://scenes/main/main.tscn"

@onready var _new_game_button: Button = $CenterContainer/MenuColumn/NewGameButton


func _ready() -> void:
	_new_game_button.pressed.connect(_on_new_game_pressed)
	_new_game_button.grab_focus()


func _on_new_game_pressed() -> void:
	get_tree().change_scene_to_file(GAMEPLAY_SCENE)
