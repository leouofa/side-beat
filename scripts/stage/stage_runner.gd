extends Node3D
## Assembles and runs an active procedural Urban World Tour City Stage.

const PLAYER_SCENE := preload("res://scenes/player/shared_soul_player.tscn")
const HUD_SCENE := preload("res://scenes/ui/arcade_hud.tscn")

var city_generator: ProceduralCityGenerator
var encounter_director: WaveEncounterDirector
var arcade_camera: ArcadeCamera3D
var player: SharedSoulPlayer
var hud: ArcadeHud
var vfx_container: Node3D
var _stage_cleared: bool = false


func _ready() -> void:
	vfx_container = Node3D.new()
	vfx_container.name = "VfxRoot"
	add_child(vfx_container)
	if HitstopManager:
		HitstopManager.register_vfx_root(vfx_container)

	city_generator = ProceduralCityGenerator.new()
	city_generator.name = "ProceduralCityGenerator"
	add_child(city_generator)

	var st_num := GameManager.current_stage if GameManager else 1
	var stage_info := city_generator.generate_city_stage(st_num)

	player = PLAYER_SCENE.instantiate() as SharedSoulPlayer
	add_child(player)
	player.global_position = Vector3(5.5, 0.25, 0.0)

	arcade_camera = ArcadeCamera3D.new()
	arcade_camera.name = "ArcadeCamera3D"
	arcade_camera.target_player = player
	arcade_camera.stage_max_x = float(stage_info["length_m"])
	add_child(arcade_camera)
	arcade_camera.snap_to_x(8.5)

	encounter_director = WaveEncounterDirector.new()
	encounter_director.name = "WaveEncounterDirector"
	add_child(encounter_director)
	encounter_director.setup_director(stage_info, player, arcade_camera)

	hud = HUD_SCENE.instantiate() as ArcadeHud
	add_child(hud)
	hud.bind_player(player)

	var biomes: Array = CityStageCatalog.STAGES[st_num]["sub_biomes"]
	hud.set_stage_header(st_num, String(stage_info["city"]), String(biomes[0]))

	# Wire director, player, and HUD events
	encounter_director.sub_biome_entered.connect(hud.set_biome_name)
	encounter_director.lock_state_changed.connect(hud.set_arena_banner)
	encounter_director.go_prompt_requested.connect(hud.trigger_go_prompt)
	encounter_director.boss_encounter_started.connect(hud.bind_boss)
	encounter_director.stage_boss_cleared.connect(_on_stage_boss_cleared)

	player.player_ko.connect(_on_player_ko)
	hud.continue_accepted.connect(_on_continue_accepted)
	hud.restart_stage_requested.connect(_on_restart_requested)
	hud.next_stage_requested.connect(_on_next_stage_requested)
	hud.exit_to_menu_requested.connect(_on_exit_to_menu_requested)

	if SoundtrackManager:
		SoundtrackManager.set_ducked_lowpass(false, 0.1)
		SoundtrackManager.start_stage_street_radio(st_num, 0)


func _process(delta: float) -> void:
	if not _stage_cleared and GameManager and not get_tree().paused:
		GameManager.stage_elapsed_sec += delta


func _on_player_ko() -> void:
	var credits := GameManager.credits_remaining if GameManager else 0
	hud.show_continue_overlay(credits)


func _on_continue_accepted() -> void:
	if GameManager and GameManager.use_continue_credit():
		player.revive_full_soul()
		var st_num := GameManager.current_stage
		if get_tree().get_nodes_in_group("bosses").size() > 0:
			var b := get_tree().get_nodes_in_group("bosses")[0] as BossController
			if SoundtrackManager:
				SoundtrackManager.play_boss_theme(st_num, b.is_mid_boss, b.phase >= 2, b.boss_name)
		else:
			if SoundtrackManager:
				SoundtrackManager.start_stage_street_radio(st_num, 0)


func _on_stage_boss_cleared() -> void:
	_stage_cleared = true
	var summary := GameManager.compute_stage_rank() if GameManager else {"stage": 1, "rank": "S", "stage_score": 10000, "run_score": 10000, "clear_time_sec": 90.0, "max_combo": 20, "damage_taken": 100, "max_variety": 4, "best_resonance": "GODLIKE"}
	var tw := create_tween()
	tw.tween_interval(1.25)
	tw.tween_callback(func(): hud.show_stage_clear_summary(summary))


func _on_restart_requested() -> void:
	if GameManager and GameManager.credits_remaining <= 0:
		get_tree().change_scene_to_file("res://scenes/ui/game_over_screen.tscn")
		return
	var st := GameManager.current_stage if GameManager else 1
	if GameManager:
		GameManager.start_new_tour(st, player.active_slot if is_instance_valid(player) else 0)
		GameManager.load_stage(st)


func _on_next_stage_requested() -> void:
	if GameManager == null:
		return
	var next_st := GameManager.current_stage + 1
	if next_st <= GameManager.max_implemented_stage:
		GameManager.load_stage(next_st)
	else:
		get_tree().change_scene_to_file("res://scenes/ui/victory_screen.tscn")


func _on_exit_to_menu_requested() -> void:
	if SoundtrackManager:
		SoundtrackManager.set_ducked_lowpass(false, 0.1)
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")
