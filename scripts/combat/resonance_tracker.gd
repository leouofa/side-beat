class_name ResonanceTracker
extends RefCounted
## Tracks active combo hits, Cross-Pantheon Variety Multiplier (up to 4.0x across all 4 gods),
## and Resonance Rank progression (D -> C -> B -> A -> S -> GODLIKE).

signal combo_updated(hits: int, rank: String, variety_mult: float, gods_contributed: Array[String])
signal combo_dropped

const COMBO_DECAY_SECONDS := 2.6
const VARIETY_MULTIPLIERS := {
	0: 1.0,
	1: 1.0,
	2: 1.75,
	3: 2.75,
	4: 4.0,
}
const METER_GAIN_BY_RANK := {
	"D": 1.00,
	"C": 1.15,
	"B": 1.30,
	"A": 1.50,
	"S": 1.75,
	"GODLIKE": 2.10,
}

var combo_count: int = 0
var remaining_time: float = 0.0
var contributed_gods: Array[String] = []
var current_rank: String = "D"


func register_hit(god_id: String) -> Dictionary:
	combo_count += 1
	remaining_time = COMBO_DECAY_SECONDS
	if not god_id.is_empty() and not contributed_gods.has(god_id):
		contributed_gods.append(god_id)

	var v_mult := get_variety_multiplier()
	current_rank = _compute_rank(combo_count, contributed_gods.size())
	var bonus_score := int(round(50.0 * v_mult))
	var meter_mult := float(METER_GAIN_BY_RANK.get(current_rank, 1.0))

	combo_updated.emit(combo_count, current_rank, v_mult, contributed_gods.duplicate())
	return {
		"combo_count": combo_count,
		"rank": current_rank,
		"variety_multiplier": v_mult,
		"variety_count": contributed_gods.size(),
		"hit_score_bonus": bonus_score,
		"meter_multiplier": meter_mult,
	}


func tick(delta: float, paused_decay: bool = false) -> void:
	if combo_count <= 0 or paused_decay:
		return
	remaining_time -= delta
	if remaining_time <= 0.0:
		reset()


func reset() -> void:
	if combo_count == 0 and contributed_gods.is_empty():
		return
	combo_count = 0
	remaining_time = 0.0
	contributed_gods.clear()
	current_rank = "D"
	combo_dropped.emit()


func get_variety_multiplier() -> float:
	var n := clampi(contributed_gods.size(), 1, 4)
	return float(VARIETY_MULTIPLIERS[n])


func get_timer_ratio() -> float:
	if combo_count <= 0:
		return 0.0
	return clampf(remaining_time / COMBO_DECAY_SECONDS, 0.0, 1.0)


func _compute_rank(hits: int, unique_gods: int) -> String:
	var style_score := float(hits) * (0.75 + 0.45 * float(maxi(unique_gods, 1)))
	if style_score >= 52.0 and unique_gods >= 4:
		return "GODLIKE"
	elif style_score >= 36.0 and unique_gods >= 3:
		return "S"
	elif style_score >= 22.0 and unique_gods >= 2:
		return "A"
	elif style_score >= 12.0:
		return "B"
	elif style_score >= 5.0:
		return "C"
	return "D"
