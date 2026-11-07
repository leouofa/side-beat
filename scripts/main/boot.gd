extends Node
## Boot entry scene transitioning to the Arcade Title Screen & World Tour / Jukebox Menu.

const TITLE_SCREEN_SCENE := "res://scenes/ui/title_screen.tscn"


func _ready() -> void:
	call_deferred("_enter_initial_scene")


func _enter_initial_scene() -> void:
	get_tree().change_scene_to_file(TITLE_SCREEN_SCENE)
