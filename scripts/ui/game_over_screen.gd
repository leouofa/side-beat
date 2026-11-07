class_name GameOverScreen
extends Control
## Retro Game Over Screen with 3-character arcade Initial Entry into Top-10 Leaderboard.

@onready var _score_label: Label = $MarginContainer/VBoxContainer/FinalScoreLabel
@onready var _entry_container: VBoxContainer = $MarginContainer/VBoxContainer/InitialEntryContainer
@onready var _initial_1: Label = $MarginContainer/VBoxContainer/InitialEntryContainer/LetterRow/Letter1
@onready var _initial_2: Label = $MarginContainer/VBoxContainer/InitialEntryContainer/LetterRow/Letter2
@onready var _initial_3: Label = $MarginContainer/VBoxContainer/InitialEntryContainer/LetterRow/Letter3
@onready var _submit_btn: Button = $MarginContainer/VBoxContainer/InitialEntryContainer/SubmitBtn
@onready var _title_btn: Button = $MarginContainer/VBoxContainer/TitleBtn

const LETTERS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!?"

var _char_indices := [0, 0, 0] # A, A, A
var _cursor_pos: int = 0
var _qualifies: bool = false


func _ready() -> void:
	var final_score := GameManager.run_score if GameManager else 25000
	_score_label.text = "FINAL SCORE: %07d" % final_score

	_qualifies = SaveManager.qualifies_for_leaderboard(final_score) if SaveManager else false
	_entry_container.visible = _qualifies

	_update_letter_display()

	_submit_btn.pressed.connect(_on_submit_pressed)
	_title_btn.pressed.connect(_on_title_pressed)

	if SoundtrackManager:
		SoundtrackManager.play_menu_track("game_over", false)


func _update_letter_display() -> void:
	var labels := [_initial_1, _initial_2, _initial_3]
	for i in range(3):
		var lbl: Label = labels[i]
		lbl.text = LETTERS[_char_indices[i]]
		if i == _cursor_pos:
			lbl.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
		else:
			lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))


func _unhandled_input(event: InputEvent) -> void:
	if not _qualifies:
		if event.is_action_pressed("attack_light") or event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
			_on_title_pressed()
		return

	if event.is_action_pressed("move_left"):
		_cursor_pos = posmod(_cursor_pos - 1, 3)
		_update_letter_display()
		if SfxManager:
			SfxManager.play_2d("ui_select", 0.0, 0.0)
	elif event.is_action_pressed("move_right"):
		_cursor_pos = posmod(_cursor_pos + 1, 3)
		_update_letter_display()
		if SfxManager:
			SfxManager.play_2d("ui_select", 0.0, 0.0)
	elif event.is_action_pressed("move_up"):
		_char_indices[_cursor_pos] = posmod(_char_indices[_cursor_pos] + 1, LETTERS.length())
		_update_letter_display()
		if SfxManager:
			SfxManager.play_2d("ui_select", 0.0, 0.0)
	elif event.is_action_pressed("move_down"):
		_char_indices[_cursor_pos] = posmod(_char_indices[_cursor_pos] - 1, LETTERS.length())
		_update_letter_display()
		if SfxManager:
			SfxManager.play_2d("ui_select", 0.0, 0.0)
	elif event.is_action_pressed("attack_light") or event.is_action_pressed("jump"):
		if _cursor_pos < 2:
			_cursor_pos += 1
			_update_letter_display()
		else:
			_on_submit_pressed()


func _on_submit_pressed() -> void:
	var inits := "%s%s%s" % [
		LETTERS[_char_indices[0]],
		LETTERS[_char_indices[1]],
		LETTERS[_char_indices[2]],
	]
	var sc := GameManager.run_score if GameManager else 25000
	var st := GameManager.current_stage if GameManager else 1
	var res := GameManager.stage_best_resonance if GameManager else "B"

	if SaveManager:
		SaveManager.submit_high_score(inits, sc, st, res)
	if SfxManager:
		SfxManager.play_2d("ui_confirm", 0.0, 0.0)

	get_tree().change_scene_to_file("res://scenes/ui/leaderboard_screen.tscn")


func _on_title_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")
