extends Node
## Persists arcade leaderboard, per-city best ranks, highest combo, cleared cities,
## and unlocked jukebox tracks in user://game_save.json.

signal save_updated

const SAVE_PATH := "user://game_save.json"
const RANK_ORDER := {"": 0, "C": 1, "B": 2, "A": 3, "S": 4}

var save_path_override: String = ""

var data: Dictionary = {}


func _ready() -> void:
	load_save()


func _active_path() -> String:
	return save_path_override if not save_path_override.is_empty() else SAVE_PATH


func reset_to_defaults() -> void:
	data = {
		"version": 1,
		"crt_preset": 1,
		"highest_combo": 0,
		"highest_resonance": "D",
		"unlocked_max_stage": 1,
		"city_best_ranks": {},
		"city_best_scores": {},
		"unlocked_tracks": [
			"res://tracks/Pantheon in Neon.mp3",
			"res://tracks/Wake Up, Endor.mp3",
		],
		"leaderboard": [
			{"initials": "END", "score": 50000, "stage": 3, "resonance": "S"},
			{"initials": "IRX", "score": 38000, "stage": 2, "resonance": "A"},
			{"initials": "OSR", "score": 25000, "stage": 2, "resonance": "B"},
			{"initials": "HRS", "score": 15000, "stage": 1, "resonance": "B"},
			{"initials": "NYC", "score": 10000, "stage": 1, "resonance": "C"},
		],
	}


func load_save() -> void:
	reset_to_defaults()
	var p := _active_path()
	if not FileAccess.file_exists(p):
		return
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) == TYPE_DICTIONARY:
		for k in parsed.keys():
			data[k] = parsed[k]


func write_save() -> void:
	var p := _active_path()
	var f := FileAccess.open(p, FileAccess.WRITE)
	if f == null:
		push_warning("SaveManager: Could not open %s for writing" % p)
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	save_updated.emit()


func unlock_track(track_path: String) -> void:
	var tracks: Array = data.get("unlocked_tracks", [])
	if not tracks.has(track_path):
		tracks.append(track_path)
		data["unlocked_tracks"] = tracks
		write_save()


func is_track_unlocked(track_path: String) -> bool:
	var tracks: Array = data.get("unlocked_tracks", [])
	return tracks.has(track_path)


func record_combo(combo_hits: int, resonance_label: String) -> void:
	var changed := false
	if combo_hits > int(data.get("highest_combo", 0)):
		data["highest_combo"] = combo_hits
		changed = true
	var res_rank := ["D", "C", "B", "A", "S", "GODLIKE"]
	var cur_idx := res_rank.find(String(data.get("highest_resonance", "D")))
	var new_idx := res_rank.find(resonance_label)
	if new_idx > cur_idx:
		data["highest_resonance"] = resonance_label
		changed = true
	if changed:
		write_save()


func record_stage_clear(stage_num: int, rank: String, stage_score: int) -> void:
	var key := str(stage_num)
	var ranks: Dictionary = data.get("city_best_ranks", {})
	var prev_rank: String = String(ranks.get(key, ""))
	if int(RANK_ORDER.get(rank, 0)) > int(RANK_ORDER.get(prev_rank, 0)):
		ranks[key] = rank
	data["city_best_ranks"] = ranks

	var scores: Dictionary = data.get("city_best_scores", {})
	if stage_score > int(scores.get(key, 0)):
		scores[key] = stage_score
	data["city_best_scores"] = scores

	var next_unlock := clampi(stage_num + 1, 1, 7)
	if next_unlock > int(data.get("unlocked_max_stage", 1)):
		data["unlocked_max_stage"] = next_unlock
	write_save()


func qualifies_for_leaderboard(score: int) -> bool:
	if score <= 0:
		return false
	var board: Array = data.get("leaderboard", [])
	if board.size() < 10:
		return true
	return score > int(board[board.size() - 1].get("score", 0))


func submit_high_score(initials: String, score: int, stage_num: int, resonance: String) -> int:
	var clean := initials.strip_edges().to_upper().substr(0, 3)
	if clean.is_empty():
		clean = "GOD"
	var board: Array = data.get("leaderboard", []).duplicate(true)
	var entry := {
		"initials": clean,
		"score": score,
		"stage": stage_num,
		"resonance": resonance,
	}
	board.append(entry)
	board.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("score", 0)) > int(b.get("score", 0))
	)
	if board.size() > 10:
		board.resize(10)
	data["leaderboard"] = board
	write_save()
	return board.find(entry)


func get_top_score() -> int:
	var board: Array = data.get("leaderboard", [])
	if board.is_empty():
		return 0
	return int(board[0].get("score", 0))
