class_name HowToPlayScreen
extends Control
## Displays arcade moves, morph mechanics, and resonance bonus scoring.

@onready var _back_btn: Button = $MarginContainer/VBoxContainer/Header/BackBtn


func _ready() -> void:
	_back_btn.pressed.connect(_on_back_pressed)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
