class_name VictoryScreen
extends Control
## Campaign Ending Victory Roll and Credits screen after defeating Lucifer in Rome.

@onready var _score_label: Label = $MarginContainer/VBoxContainer/StatsRow/ScoreVal
@onready var _rank_label: Label = $MarginContainer/VBoxContainer/StatsRow/RankVal
@onready var _credits_used_label: Label = $MarginContainer/VBoxContainer/StatsRow/CreditsVal
@onready var _return_btn: Button = $MarginContainer/VBoxContainer/ReturnBtn
@onready var _credits_scroll: ScrollContainer = $MarginContainer/VBoxContainer/CreditsScroll

var _scroll_speed: float = 38.0


func _ready() -> void:
	SynthwaveUI.apply_to_tree(self)
	if SoundtrackManager:
		# Play the triumphant Big Zeus track!
		SoundtrackManager.play_track("res://tracks/Big Zeus.mp3", "WORLD TOUR CONQUEST VICTORY", true)

	var run_sc: int = GameManager.run_score if GameManager else 125000
	var best_res: String = GameManager.stage_best_resonance if GameManager else "GODLIKE"
	var credits_left: int = GameManager.credits_remaining if GameManager else 2
	var credits_used: int = (GameManager.STARTING_CREDITS - credits_left) if GameManager else 1

	_score_label.text = "%07d" % run_sc
	_rank_label.text = best_res
	_credits_used_label.text = "%d CONTINUES" % credits_used

	_return_btn.pressed.connect(_on_return_pressed)


func _process(delta: float) -> void:
	_credits_scroll.scroll_vertical += int(round(_scroll_speed * delta))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("jump") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		_on_return_pressed()


func _on_return_pressed() -> void:
	if SfxManager:
		SfxManager.play_2d("ui_confirm", 0.0, 0.0)
	get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")
