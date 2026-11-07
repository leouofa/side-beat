class_name LeaderboardScreen
extends Control
## Top-10 Arcade Leaderboard display with persistence via SaveManager.

@onready var _table_container: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/TableContainer
@onready var _back_btn: Button = $MarginContainer/VBoxContainer/Header/BackBtn


func _ready() -> void:
	SynthwaveUI.apply_to_tree(self)
	_back_btn.pressed.connect(_on_back_pressed)
	_populate_leaderboard()


func _populate_leaderboard() -> void:
	for c in _table_container.get_children():
		c.queue_free()

	var entries: Array = SaveManager.data.get("leaderboard", []) if SaveManager else []

	# Header Row
	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 32)
	_add_cell(header, "RANK", 100, Color(0.0, 0.85, 1.0))
	_add_cell(header, "INITIALS", 140, Color(0.0, 0.85, 1.0))
	_add_cell(header, "SCORE", 180, Color(0.0, 0.85, 1.0))
	_add_cell(header, "STAGE", 140, Color(0.0, 0.85, 1.0))
	_add_cell(header, "RESONANCE", 160, Color(0.0, 0.85, 1.0))
	_table_container.add_child(header)

	var separator := HSeparator.new()
	_table_container.add_child(separator)

	for i in range(10):
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 36)

		var rank_color := Color(1.0, 0.84, 0.0) if i == 0 else (Color(0.85, 0.85, 0.9) if i == 1 else (Color(0.8, 0.5, 0.2) if i == 2 else Color(0.9, 0.9, 0.9)))
		var rank_str := "%02d." % (i + 1)
		var initials_str := "---"
		var score_str := "-----"
		var stage_str := "-"
		var resonance_str := "-"

		if i < entries.size():
			var e: Dictionary = entries[i]
			initials_str = String(e.get("initials", "---")).to_upper()
			score_str = "%07d" % int(e.get("score", 0))
			stage_str = "STAGE %d" % int(e.get("stage", 1))
			resonance_str = String(e.get("resonance", "D")).to_upper()

		_add_cell(row, rank_str, 100, rank_color)
		_add_cell(row, initials_str, 140, Color(1, 1, 1))
		_add_cell(row, score_str, 180, Color(1.0, 0.84, 0.0))
		_add_cell(row, stage_str, 140, Color(0.7, 0.8, 0.9))
		_add_cell(row, resonance_str, 160, Color(1.0, 0.2, 0.5))

		_table_container.add_child(row)


func _add_cell(parent: HBoxContainer, text: String, min_w: int, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.custom_minimum_size = Vector2(min_w, 0)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", 18)
	parent.add_child(lbl)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
