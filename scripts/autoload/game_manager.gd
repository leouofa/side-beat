extends Node
## Manages World Tour campaign state, Arcade Score, Credits/Continues, Stage Clear grading,
## and scene transitions.

signal score_changed(new_score: int, delta: int)
signal credits_changed(remaining_credits: int)
signal stage_rank_computed(summary: Dictionary)

const STARTING_CREDITS := 3
const STAGE_RUNNER_SCENE := "res://scenes/stage/stage_runner.tscn"

var current_stage: int = 1
var starting_god_slot: int = 0
var run_score: int = 0
var stage_score: int = 0
var credits_remaining: int = STARTING_CREDITS
var stage_elapsed_sec: float = 0.0
var stage_damage_taken: float = 0.0
var stage_max_combo: int = 0
var stage_max_variety: int = 1
var stage_best_resonance: String = "D"
var max_implemented_stage: int = 4 # Advances M1 (1) -> M2 (4) -> M3/M4 (7)


func start_new_tour(stage_num: int = 1, god_slot: int = 0) -> void:
	current_stage = clampi(stage_num, 1, 7)
	starting_god_slot = clampi(god_slot, 0, 3)
	run_score = 0
	credits_remaining = STARTING_CREDITS
	reset_stage_metrics()
	score_changed.emit(run_score, 0)
	credits_changed.emit(credits_remaining)


func reset_stage_metrics() -> void:
	stage_score = 0
	stage_elapsed_sec = 0.0
	stage_damage_taken = 0.0
	stage_max_combo = 0
	stage_max_variety = 1
	stage_best_resonance = "D"


func add_score(points: int) -> void:
	if points <= 0:
		return
	run_score += points
	stage_score += points
	score_changed.emit(run_score, points)


func record_player_damage(amount: float) -> void:
	stage_damage_taken += maxf(0.0, amount)


func record_combo_stats(hits: int, variety_count: int, resonance_rank: String) -> void:
	if hits > stage_max_combo:
		stage_max_combo = hits
	if variety_count > stage_max_variety:
		stage_max_variety = variety_count
	var order := ["D", "C", "B", "A", "S", "GODLIKE"]
	if order.find(resonance_rank) > order.find(stage_best_resonance):
		stage_best_resonance = resonance_rank
	if SaveManager:
		SaveManager.record_combo(hits, resonance_rank)


func use_continue_credit() -> bool:
	if credits_remaining <= 0:
		return false
	credits_remaining -= 1
	# Reset run score to 0 on Continue for leaderboard fairness per design alignment
	run_score = 0
	score_changed.emit(run_score, 0)
	credits_changed.emit(credits_remaining)
	return true


func compute_stage_rank() -> Dictionary:
	# Grade C / B / A / S based on clear time, max combo, damage taken, and morph variety
	var grade_pts := 0
	if stage_elapsed_sec <= 165.0:
		grade_pts += 30
	elif stage_elapsed_sec <= 240.0:
		grade_pts += 20
	else:
		grade_pts += 10

	if stage_max_combo >= 35:
		grade_pts += 25
	elif stage_max_combo >= 18:
		grade_pts += 16
	elif stage_max_combo >= 8:
		grade_pts += 8

	if stage_damage_taken <= 250.0:
		grade_pts += 25
	elif stage_damage_taken <= 600.0:
		grade_pts += 15
	elif stage_damage_taken <= 950.0:
		grade_pts += 8

	grade_pts += stage_max_variety * 5 # Up to +20 pts for using all 4 gods in a combo

	var rank := "C"
	if grade_pts >= 82:
		rank = "S"
	elif grade_pts >= 62:
		rank = "A"
	elif grade_pts >= 40:
		rank = "B"

	var summary := {
		"stage": current_stage,
		"rank": rank,
		"grade_points": grade_pts,
		"stage_score": stage_score,
		"run_score": run_score,
		"clear_time_sec": stage_elapsed_sec,
		"max_combo": stage_max_combo,
		"damage_taken": int(round(stage_damage_taken)),
		"max_variety": stage_max_variety,
		"best_resonance": stage_best_resonance,
	}
	if SaveManager:
		SaveManager.record_stage_clear(current_stage, rank, stage_score)
	stage_rank_computed.emit(summary)
	return summary


func load_stage(stage_num: int) -> void:
	current_stage = clampi(stage_num, 1, 7)
	reset_stage_metrics()
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().change_scene_to_file(STAGE_RUNNER_SCENE)
