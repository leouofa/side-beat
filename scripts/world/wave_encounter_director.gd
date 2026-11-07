class_name WaveEncounterDirector
extends Node3D
## Orchestrates "GO!" camera-lock street wave arenas, flanking enemy spawns,
## Mid-Boss encounters, Stage Boss showdowns, and stage completion.

signal sub_biome_entered(biome_name: String)
signal lock_state_changed(locked: bool, banner_text: String)
signal go_prompt_requested
signal boss_encounter_started(boss: BossController)
signal stage_boss_cleared

const WAVE_ENEMY_SCENE := preload("res://scenes/enemies/wave_enemy.tscn")
const BOSS_ACTOR_SCENE := preload("res://scenes/bosses/boss_actor.tscn")

var stage_num: int = 1
var city_tint: Color = Color.WHITE
var stage_length_m: float = 168.0
var player: SharedSoulPlayer = null
var camera: ArcadeCamera3D = null

var _zones: Array[Dictionary] = []
var _next_zone_idx: int = 0
var _active_zone: Dictionary = {}
var _zone_active: bool = false
var _pending_spawns: Array[String] = []
var _spawn_timer: float = 0.0
var _alive_count: int = 0
var _last_biome: String = ""


func setup_director(stage_info: Dictionary, ply: SharedSoulPlayer, cam: ArcadeCamera3D) -> void:
	stage_num = int(stage_info.get("stage", 1))
	city_tint = stage_info.get("city_tint", Color.WHITE)
	stage_length_m = float(stage_info.get("length_m", 168.0))
	player = ply
	camera = cam
	_zones.clear()
	for z in stage_info.get("zones", []):
		_zones.append(z)
	_next_zone_idx = 0
	_zone_active = false
	player.set_arena_x_bounds(1.0, stage_length_m - 1.0)


func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return

	if not _zone_active:
		if _next_zone_idx < _zones.size():
			var upcoming: Dictionary = _zones[_next_zone_idx]
			if player.global_position.x >= float(upcoming["trigger_x"]):
				_begin_zone(upcoming)
		return

	# Staggered flanking wave spawns inside active locked arena
	if not _pending_spawns.is_empty() and _alive_count < 4:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			var next_tier := _pending_spawns.pop_front() as String
			_spawn_wave_enemy(next_tier)
			_spawn_timer = 0.55


func _begin_zone(zone: Dictionary) -> void:
	_zone_active = true
	_active_zone = zone
	_next_zone_idx += 1

	var biome := String(zone.get("sub_biome", ""))
	if biome != _last_biome and not biome.is_empty():
		_last_biome = biome
		sub_biome_entered.emit(biome)

	var min_x := float(zone["min_x"])
	var max_x := float(zone["max_x"])
	var center_x := float(zone["center_x"])
	player.set_arena_x_bounds(min_x, max_x)
	if camera:
		camera.lock_at_arena(center_x)

	var ztype := String(zone["zone_type"])
	if ztype == "wave":
		var w_idx := int(zone.get("wave_index", 0))
		if SoundtrackManager:
			SoundtrackManager.advance_street_wave_track(stage_num, w_idx)
		_pending_spawns.clear()
		for t in zone.get("budget", []):
			_pending_spawns.append(String(t))
		_alive_count = 0
		_spawn_timer = 0.1
		lock_state_changed.emit(true, "BATTLE ZONE — CLEAR THE STREET!")
	elif ztype == "mid_boss" or ztype == "stage_boss":
		var b_id := String(zone["boss_id"])
		var is_mid := (ztype == "mid_boss")
		_spawn_boss(b_id, is_mid, min_x, max_x, center_x)


func _spawn_wave_enemy(tier: String) -> void:
	var enemy := WAVE_ENEMY_SCENE.instantiate() as WaveEnemy
	var min_x := float(_active_zone["min_x"])
	var max_x := float(_active_zone["max_x"])
	var from_right := (_alive_count % 2 == 0)
	var spawn_x := (max_x - 0.8) if from_right else (min_x + 0.8)
	var spawn_z := randf_range(-2.4, 2.4)
	enemy.arena_x_min = min_x
	enemy.arena_x_max = max_x
	enemy.flank_slot_offset = Vector3(0.0, 0.0, randf_range(-1.1, 1.1))
	add_child(enemy)
	enemy.global_position = Vector3(spawn_x, 0.15, spawn_z)
	enemy.configure_tier(tier, city_tint)
	enemy.defeated.connect(_on_wave_enemy_defeated)
	_alive_count += 1


func _spawn_boss(boss_id: String, is_mid: bool, min_x: float, max_x: float, center_x: float) -> void:
	var boss := BOSS_ACTOR_SCENE.instantiate() as BossController
	add_child(boss)
	boss.global_position = Vector3(center_x + 4.8, 0.2, 0.0)
	boss.setup_boss(boss_id, min_x, max_x)
	boss.boss_defeated.connect(_on_boss_defeated.bind(is_mid))
	_alive_count = 1

	if SoundtrackManager:
		SoundtrackManager.play_boss_theme(stage_num, is_mid, false, boss.boss_name)
	lock_state_changed.emit(true, "%s — %s" % [boss.boss_name.to_upper(), boss.boss_title.to_upper()])
	boss_encounter_started.emit(boss)


func _on_wave_enemy_defeated(_enemy: WaveEnemy, _pts: int, _pos: Vector3) -> void:
	_alive_count = maxi(0, _alive_count - 1)
	if _alive_count == 0 and _pending_spawns.is_empty():
		_complete_active_zone(false)


func _on_boss_defeated(_boss_id: String, _pts: int, _pos: Vector3, is_mid: bool) -> void:
	_alive_count = 0
	if is_mid:
		if SoundtrackManager:
			SoundtrackManager.advance_street_wave_track(stage_num, 2)
		_complete_active_zone(false)
	else:
		_complete_active_zone(true)


func _complete_active_zone(is_final_stage_boss: bool) -> void:
	_zone_active = false
	if is_final_stage_boss:
		lock_state_changed.emit(false, "STAGE CLEAR!")
		stage_boss_cleared.emit()
		return

	player.set_arena_x_bounds(1.0, stage_length_m - 1.0)
	if camera:
		camera.unlock_arena()
	if SfxManager:
		SfxManager.play_2d("go_siren", -1.5, 0.0)
	lock_state_changed.emit(false, "")
	go_prompt_requested.emit()
