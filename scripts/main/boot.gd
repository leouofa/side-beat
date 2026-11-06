extends Node
## Boot entry scene launching Milestone 1's New York City Urban World Tour stage
## (In Milestone 4, transitions to the Title Screen & World Tour / Jukebox Menu).


func _ready() -> void:
	GameManager.start_new_tour(1, 0)
	call_deferred("_enter_initial_scene")


func _enter_initial_scene() -> void:
	GameManager.load_stage(1)
