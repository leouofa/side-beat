class_name TitleScreen
extends Control
## Main Arcade Title Screen with mode selection, high score ticker, and attract theme.

@onready var _start_tour_btn: Button = $MarginContainer/VBoxContainer/MenuContainer/StartTourBtn
@onready var _leaderboard_btn: Button = $MarginContainer/VBoxContainer/MenuContainer/LeaderboardBtn
@onready var _jukebox_btn: Button = $MarginContainer/VBoxContainer/MenuContainer/JukeboxBtn
@onready var _how_to_play_btn: Button = $MarginContainer/VBoxContainer/MenuContainer/HowToPlayBtn
@onready var _quit_btn: Button = $MarginContainer/VBoxContainer/MenuContainer/QuitBtn
@onready var _high_score_label: Label = $MarginContainer/VBoxContainer/Header/HighScoreLabel
@onready var _prompt_label: Label = $MarginContainer/VBoxContainer/PromptLabel

var _blink_timer: float = 0.0


func _ready() -> void:
	if SoundtrackManager:
		SoundtrackManager.play_menu_track("title_theme", true)

	var top_score: int = SaveManager.get_top_score() if SaveManager else 50000
	_high_score_label.text = "TOP ARCADE: %07d" % top_score

	_start_tour_btn.pressed.connect(_on_start_tour_pressed)
	_leaderboard_btn.pressed.connect(_on_leaderboard_pressed)
	_jukebox_btn.pressed.connect(_on_jukebox_pressed)
	_how_to_play_btn.pressed.connect(_on_how_to_play_pressed)
	_quit_btn.pressed.connect(_on_quit_pressed)

	_start_tour_btn.grab_focus()


func _process(delta: float) -> void:
	_blink_timer += delta
	_prompt_label.modulate.a = 0.35 + 0.65 * absf(sin(_blink_timer * 4.0))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("attack_light") or event.is_action_pressed("jump"):
		if not _start_tour_btn.has_focus() and not _leaderboard_btn.has_focus() and not _jukebox_btn.has_focus() and not _how_to_play_btn.has_focus():
			_on_start_tour_pressed()


func _on_start_tour_pressed() -> void:
	if SfxManager:
		SfxManager.play_2d("ui_confirm", 0.0, 0.0)
	get_tree().change_scene_to_file("res://scenes/ui/god_select_screen.tscn")


func _on_leaderboard_pressed() -> void:
	if SfxManager:
		SfxManager.play_2d("ui_select", 0.0, 0.0)
	get_tree().change_scene_to_file("res://scenes/ui/leaderboard_screen.tscn")


func _on_jukebox_pressed() -> void:
	if SfxManager:
		SfxManager.play_2d("ui_select", 0.0, 0.0)
	get_tree().change_scene_to_file("res://scenes/ui/jukebox_screen.tscn")


func _on_how_to_play_pressed() -> void:
	if SfxManager:
		SfxManager.play_2d("ui_select", 0.0, 0.0)
	get_tree().change_scene_to_file("res://scenes/ui/how_to_play_screen.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit(0)
