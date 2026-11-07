extends Node
## Automated Headless Verification Suite for Side Beat (Milestone 1).
## Runs inside the real SceneTree with all Autoloads, AudioBuses, and Jolt Physics active.

var _failures: int = 0
var _assertions: int = 0


func _assert(cond: bool, msg: String) -> void:
	_assertions += 1
	if not cond:
		_failures += 1
		printerr("[FAIL] ", msg)
	else:
		print("[PASS] ", msg)


func _ready() -> void:
	print("=== SIDE BEAT AUTOMATED VERIFICATION SUITE ===")
	_test_37_soundtracks_and_sfx()
	_test_glb_rigs_and_nla_clips()
	_test_m2_bosses_and_drone()
	_test_m3_bosses()
	_test_resonance_math()
	await _test_stage_1_runtime_and_morph_preservation()
	_test_stages_2_to_4_generation()
	_test_stages_5_to_7_generation()
	_test_hitstop_manager_camera_shake()
	_test_arcade_menus_and_ui()
	_test_synthwave_ui_styling()
	_test_stage_grading_math()
	_test_continue_credit_fairness()
	_test_save_persistence()
	_test_combat_hurtbox_deferred_deactivation()
	_test_simplified_controls_and_instruction_screens()
	_test_battle_arena_on_screen_containment()
	await _test_shader_effects_and_post_fx()
	_test_snappy_prop_and_ko_hitstop()

	print("==============================================")
	print("Assertions: %d | Failures: %d" % [_assertions, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _test_37_soundtracks_and_sfx() -> void:
	_assert(SoundtrackManager != null, "SoundtrackManager autoload is active")
	var tracks: Array[String] = SoundtrackManager.get_all_37_tracks()
	_assert(tracks.size() == 37, "Soundtrack catalog maps all 37 tracks (got %d)" % tracks.size())

	var missing_tracks := 0
	for t in tracks:
		if not ResourceLoader.exists(t) or load(t) == null:
			printerr("  Missing or unimportable track: ", t)
			missing_tracks += 1
	_assert(missing_tracks == 0, "All 37 MP3 tracks load cleanly as AudioStreams")

	var sfx_samples := ["hit_light", "hit_thunder", "hit_blade", "parry_clang", "morph_endor", "go_siren", "ko_boom"]
	var missing_sfx := 0
	for s in sfx_samples:
		var sp := "res://assets/sfx/%s.wav" % s
		if not ResourceLoader.exists(sp) or load(sp) == null:
			missing_sfx += 1
	_assert(missing_sfx == 0, "Synthesized WAV SFX bank loads cleanly")


func _test_glb_rigs_and_nla_clips() -> void:
	var required_god_anims := [
		"idle_fight_stance", "walk_forward", "walk_back_guard", "run_dash",
		"jump_start", "jump_air_loop", "land", "block_high",
		"hit_light", "hit_launch_arc", "knockdown_getup",
		"light_1", "light_2", "light_3", "heavy_ground", "launcher_up",
		"air_combo_1", "air_combo_2", "air_dive_or_slam",
		"pantheon_special_1", "pantheon_special_2", "pantheon_super", "morph_entry_pose",
	]
	var required_bones := [
		"root", "hips", "spine_01", "spine_02", "chest", "neck", "head", "back_socket",
		"clavicle.L", "clavicle.R", "upper_arm.L", "upper_arm.R", "lower_arm.L", "lower_arm.R",
		"hand.L", "hand.R", "weapon_socket.L", "weapon_socket.R",
		"thigh.L", "thigh.R", "shin.L", "shin.R", "foot.L", "foot.R",
	]

	for gid in ["endor", "ir", "osiris", "horus"]:
		var inst := GlbLoader.instantiate_glb("res://assets/characters/%s.glb" % gid)
		var skel := GlbLoader.find_skeleton(inst)
		var anim := GlbLoader.find_anim_player(inst)
		_assert(skel != null and anim != null, "God '%s' GLB has Skeleton3D and AnimationPlayer" % gid)
		if skel:
			var missing_b := 0
			for b in required_bones:
				if skel.find_bone(b) < 0:
					missing_b += 1
			_assert(missing_b == 0, "God '%s' has all 24 required humanoid bones" % gid)
		if anim:
			var missing_list: Array[String] = []
			for a in required_god_anims:
				var anim_str := String(a)
				var stripped := anim_str.trim_suffix("_loop")
				if not anim.has_animation(anim_str) and not anim.has_animation(stripped):
					missing_list.append(anim_str)
			if not missing_list.is_empty():
				print("  [%s] Missing anims: %s | Present: %s" % [gid, str(missing_list), str(anim.get_animation_list())])
			_assert(missing_list.is_empty(), "God '%s' has all 23 fighting-game NLA animations" % gid)
		inst.free()

	var beebo := GlbLoader.instantiate_glb("res://assets/bosses/beebo.glb")
	var b_skel := GlbLoader.find_skeleton(beebo)
	var b_anim := GlbLoader.find_anim_player(beebo)
	_assert(
		b_skel != null and b_skel.find_bone("wing_tip.L") >= 0 and b_skel.find_bone("talon_foot.R") >= 0 and b_skel.find_bone("beak_jaw") >= 0,
		"Beebo GLB contains avian extension bones (wing_tip.L, talon_foot.R, beak_jaw)"
	)
	_assert(
		b_anim != null and b_anim.has_animation("boss_intro_taunt") and b_anim.has_animation("phase_2_roar") and b_anim.has_animation("ko_collapse"),
		"Beebo GLB contains required per_boss_combat NLA animations"
	)
	beebo.free()

	var chad := GlbLoader.instantiate_glb("res://assets/bosses/chadzug.glb")
	var c_skel := GlbLoader.find_skeleton(chad)
	_assert(c_skel != null and c_skel.find_bone("weapon_socket.R") >= 0, "Chadzug GLB has rigged pickaxe weapon_socket.R")
	chad.free()


func _test_m2_bosses_and_drone() -> void:
	# Chupar
	var chupar := GlbLoader.instantiate_glb("res://assets/bosses/chupar.glb")
	var ch_skel := GlbLoader.find_skeleton(chupar)
	_assert(ch_skel != null and ch_skel.find_bone("belly_jiggle") >= 0, "Chupar GLB has belly_jiggle bone")
	chupar.free()

	# Bar
	var bar := GlbLoader.instantiate_glb("res://assets/bosses/bar.glb")
	var bar_skel := GlbLoader.find_skeleton(bar)
	_assert(bar_skel != null and bar_skel.find_bone("wing_tip.L") >= 0 and bar_skel.find_bone("talon_foot.R") >= 0, "Bar GLB has avian wing_tip.L and talon_foot.R bones")
	bar.free()

	# Dadur
	var dadur := GlbLoader.instantiate_glb("res://assets/bosses/dadur.glb")
	var d_skel := GlbLoader.find_skeleton(dadur)
	_assert(d_skel != null and d_skel.find_bone("horn.L") >= 0 and d_skel.find_bone("horn.R") >= 0, "Dadur GLB has bovine horn.L and horn.R bones")
	dadur.free()

	# Baphomet
	var baph := GlbLoader.instantiate_glb("res://assets/bosses/baphomet.glb")
	var baph_skel := GlbLoader.find_skeleton(baph)
	_assert(baph_skel != null and baph_skel.find_bone("horn.L") >= 0 and baph_skel.find_bone("horn.R") >= 0 and baph_skel.find_bone("foot.L") >= 0, "Baphomet GLB has demon horn.L/R and humanoid foot.L bones")
	baph.free()

	# Andruas
	var andruas := GlbLoader.instantiate_glb("res://assets/bosses/andruas.glb")
	var a_skel := GlbLoader.find_skeleton(andruas)
	_assert(a_skel != null and a_skel.find_bone("tail_01") >= 0 and a_skel.find_bone("tail_08") >= 0, "Andruas GLB has 8-segment serpentine tail bones")
	andruas.free()

	# Beezelbub
	var beezel := GlbLoader.instantiate_glb("res://assets/bosses/beezelbub.glb")
	var bz_skel := GlbLoader.find_skeleton(beezel)
	_assert(bz_skel != null and bz_skel.find_bone("dorsal_wing_upper.L") >= 0 and bz_skel.find_bone("mandible.L") >= 0, "Beezelbub GLB has dorsal_wing_upper.L and mandible.L bones")
	beezel.free()

	# Drone Fly
	var drone := GlbLoader.instantiate_glb("res://assets/enemies/drone_fly.glb")
	var dr_skel := GlbLoader.find_skeleton(drone)
	_assert(dr_skel != null and dr_skel.find_bone("wing.L") >= 0 and dr_skel.find_bone("wing.R") >= 0, "Drone Fly minion GLB has wing.L and wing.R bones")
	drone.free()


func _test_m3_bosses() -> void:
	# Baba
	var baba := GlbLoader.instantiate_glb("res://assets/bosses/baba.glb")
	var bb_skel := GlbLoader.find_skeleton(baba)
	_assert(bb_skel != null and bb_skel.find_bone("mortar_base") >= 0 and bb_skel.find_bone("pestle_staff") >= 0 and bb_skel.find_bone("claw_toe.L") >= 0, "Baba GLB has mortar_base, pestle_staff, and chicken claw bones")
	baba.free()

	# Devil
	var devil := GlbLoader.instantiate_glb("res://assets/bosses/devil.glb")
	var dv_skel := GlbLoader.find_skeleton(devil)
	_assert(dv_skel != null and dv_skel.find_bone("horn.L") >= 0 and dv_skel.find_bone("wing_bat.L") >= 0 and dv_skel.find_bone("tail_03") >= 0 and dv_skel.find_bone("pitchfork") >= 0, "Devil GLB has demon horn.L, bat wings, barbed tail, and golden pitchfork")
	devil.free()

	# Satan
	var satan := GlbLoader.instantiate_glb("res://assets/bosses/satan.glb")
	var st_skel := GlbLoader.find_skeleton(satan)
	_assert(st_skel != null and st_skel.find_bone("horn_jagged.L") >= 0 and st_skel.find_bone("plasma_claw.L") >= 0 and st_skel.find_bone("dorsal_fin.01") >= 0, "Satan GLB has jagged thunder horns, plasma claws, and dorsal conductor fins")
	satan.free()

	# Lucifer
	var luci := GlbLoader.instantiate_glb("res://assets/bosses/lucifer.glb")
	var lc_skel := GlbLoader.find_skeleton(luci)
	_assert(lc_skel != null and lc_skel.find_bone("halo") >= 0 and lc_skel.find_bone("seraph_upper.L") >= 0 and lc_skel.find_bone("seraph_lower.R") >= 0 and lc_skel.find_bone("celestial_blade") >= 0, "Lucifer GLB has radiant halo, 6 Seraphic wings, and celestial blade")
	luci.free()


func _test_resonance_math() -> void:
	var rt := ResonanceTracker.new()
	var r1 := rt.register_hit("endor")
	_assert(is_equal_approx(float(r1["variety_multiplier"]), 1.0), "1-God combo multiplier == 1.0x")
	var r2 := rt.register_hit("ir")
	_assert(is_equal_approx(float(r2["variety_multiplier"]), 1.75), "2-God combo multiplier == 1.75x")
	var r3 := rt.register_hit("osiris")
	_assert(is_equal_approx(float(r3["variety_multiplier"]), 2.75), "3-God combo multiplier == 2.75x")
	var r4 := rt.register_hit("horus")
	_assert(is_equal_approx(float(r4["variety_multiplier"]), 4.0), "4-God Cross-Pantheon multiplier == 4.0x")
	for _i in range(20):
		rt.register_hit("endor")
	_assert(rt.current_rank == "GODLIKE", "Sustained 4-God combo reaches GODLIKE resonance rank")


func _test_stage_1_runtime_and_morph_preservation() -> void:
	var runner_scene := load("res://scenes/stage/stage_runner.tscn") as PackedScene
	var runner := runner_scene.instantiate()
	add_child(runner)
	await get_tree().process_frame
	await get_tree().physics_frame

	var ply := runner.get("player") as SharedSoulPlayer
	var gen := runner.get("city_generator") as ProceduralCityGenerator

	_assert(ply != null and gen != null, "StageRunner instantiated SharedSoulPlayer and ProceduralCityGenerator")
	_assert(is_equal_approx(gen.total_stage_length_m, 168.0) and gen.generated_zones.size() == 5, "NYC stage generated 7 x 24m chunks with 3 street waves + Chadzug + Beebo")

	var playing_before: String = SoundtrackManager.get_current_track_path()
	_assert(is_equal_approx(ply.facing_sign, 1.0) and is_equal_approx(ply.get("_visual_pivot").rotation.y, PI * 0.5), "Player spawns facing right (+X) with visual rotation +PI/2")

	ply.global_position = Vector3(12.0, 2.5, -1.4)
	ply.velocity = Vector3(6.4, 4.8, -0.9)
	ply.facing_sign = -1.0
	ply._update_facing_visual()
	_assert(is_equal_approx(ply.get("_visual_pivot").rotation.y, -PI * 0.5), "Player visual rotation correctly updates to -PI/2 when facing left (-X)")
	ply.resonance.register_hit("endor")

	# Zero-cooldown rapid morph across all 4 gods in the same frame!
	var m1 := ply.morph_to_slot(1)
	var m2 := ply.morph_to_slot(2)
	var m3 := ply.morph_to_slot(3)
	_assert(m1 and m2 and m3, "Zero-cooldown Shared-Soul Morphing succeeds across all 4 gods instantaneously")
	_assert(ply.velocity.is_equal_approx(Vector3(6.4, 4.8, -0.9)), "Morph preserves linear velocity")
	_assert(is_equal_approx(ply.facing_sign, -1.0), "Morph preserves left/right facing direction")
	_assert(is_equal_approx(ply.get("_visual_pivot").rotation.y, -PI * 0.5), "Morph preserves left/right visual rotation")
	_assert(ply.resonance.combo_count == 1, "Morph preserves active combo count")
	_assert(ply.hitstun_immunity_frames == 2, "Morph grants 2 frames of hitstun immunity")
	_assert(SoundtrackManager.get_current_track_path() == playing_before, "Morph does NOT chop or restart active music track")

	# Verify heavy melee attack posture (forward lean, forward weapon reach, planar profile)
	ply.morph_to_slot(0)
	ply.facing_sign = 1.0
	ply._update_facing_visual()
	var rig_dict: Dictionary = ply.get("_god_rigs")[0]
	var anim: AnimationPlayer = rig_dict["anim"]
	var skel: Skeleton3D = rig_dict["skeleton"]
	anim.play(&"heavy_ground")
	anim.seek(15.0 / 60.0, true)
	var head_idx := skel.find_bone("head")
	var ws_idx := skel.find_bone("weapon_socket.R")
	var vp: Node3D = ply.get("_visual_pivot")
	var head_pos: Vector3 = (vp.transform * skel.get_bone_global_pose(head_idx)).origin
	var ws_pos: Vector3 = (vp.transform * skel.get_bone_global_pose(ws_idx)).origin
	_assert(head_pos.x > 0.3, "Heavy attack slam leans forward (+X) in front of player origin (got %.2f)" % head_pos.x)
	_assert(ws_pos.x > 0.5, "Heavy attack weapon extends forward into target lane (got %.2f)" % ws_pos.x)
	_assert(absf(head_pos.z) < 0.15, "Heavy attack maintains 2.5D planar profile without screen tilt (got Z=%.2f)" % head_pos.z)

	runner.queue_free()
	await get_tree().process_frame


func _test_stages_2_to_4_generation() -> void:
	_assert(GameManager.max_implemented_stage >= 4, "GameManager.max_implemented_stage is at least 4")

	var gen := ProceduralCityGenerator.new()
	add_child(gen)

	# Stage 2: Los Angeles (Chupar mid-boss, Bar stage-boss)
	var st2 := gen.generate_city_stage(2, 2001)
	_assert(gen.generated_zones.size() == 5, "Stage 2 (LA) generated 5 encounter zones")
	_assert(String(st2.get("city", "")) == "Los Angeles", "Stage 2 city is Los Angeles")
	_assert(String(gen.generated_zones[2].get("boss_id", "")) == "chupar", "Stage 2 has mid-boss Chupar")
	_assert(String(gen.generated_zones[4].get("boss_id", "")) == "bar", "Stage 2 has stage-boss Bar")

	# Stage 3: Madrid (Dadur mid-boss, Baphomet stage-boss)
	var st3 := gen.generate_city_stage(3, 3001)
	_assert(gen.generated_zones.size() == 5, "Stage 3 (Madrid) generated 5 encounter zones")
	_assert(String(st3.get("city", "")) == "Madrid", "Stage 3 city is Madrid")
	_assert(String(gen.generated_zones[2].get("boss_id", "")) == "dadur", "Stage 3 has mid-boss Dadur")
	_assert(String(gen.generated_zones[4].get("boss_id", "")) == "baphomet", "Stage 3 has stage-boss Baphomet")

	# Stage 4: Moscow (Andruas mid-boss, Beezelbub stage-boss, ice_slick hazard)
	var st4 := gen.generate_city_stage(4, 4001)
	_assert(gen.generated_zones.size() == 5, "Stage 4 (Moscow) generated 5 encounter zones")
	_assert(String(st4.get("city", "")) == "Moscow", "Stage 4 city is Moscow")
	_assert(String(gen.generated_zones[2].get("boss_id", "")) == "andruas", "Stage 4 has mid-boss Andruas")
	_assert(String(gen.generated_zones[4].get("boss_id", "")) == "beezelbub", "Stage 4 has stage-boss Beezelbub")
	_assert(String(CityStageCatalog.STAGES[4]["hazard"]) == "ice_slick", "Stage 4 features ice_slick hazard")

	gen.free()


func _test_stages_5_to_7_generation() -> void:
	_assert(GameManager.max_implemented_stage == 7, "GameManager.max_implemented_stage is 7 for Milestone 3")

	var gen := ProceduralCityGenerator.new()
	add_child(gen)

	# Stage 5: London (Baba mid-boss, Devil stage-boss)
	var st5 := gen.generate_city_stage(5, 5001)
	_assert(gen.generated_zones.size() == 5, "Stage 5 (London) generated 5 encounter zones")
	_assert(String(st5.get("city", "")) == "London", "Stage 5 city is London")
	_assert(String(gen.generated_zones[2].get("boss_id", "")) == "baba", "Stage 5 has mid-boss Baba")
	_assert(String(gen.generated_zones[4].get("boss_id", "")) == "devil", "Stage 5 has stage-boss Devil")
	_assert(String(CityStageCatalog.STAGES[5]["hazard"]) == "steam_vent", "Stage 5 features steam_vent hazard")

	# Stage 6: Tokyo (Satan stage-boss, electric_arc hazard)
	var st6 := gen.generate_city_stage(6, 6001)
	_assert(gen.generated_zones.size() == 5, "Stage 6 (Tokyo) generated 5 encounter zones")
	_assert(String(st6.get("city", "")) == "Tokyo", "Stage 6 city is Tokyo")
	_assert(String(gen.generated_zones[4].get("boss_id", "")) == "satan", "Stage 6 has stage-boss Satan")
	_assert(String(CityStageCatalog.STAGES[6]["hazard"]) == "electric_arc", "Stage 6 features electric_arc hazard")

	# Stage 7: Rome (Lucifer final boss, lava_brazier hazard)
	var st7 := gen.generate_city_stage(7, 7001)
	_assert(gen.generated_zones.size() == 5, "Stage 7 (Rome) generated 5 encounter zones")
	_assert(String(st7.get("city", "")) == "Rome", "Stage 7 city is Rome")
	_assert(String(gen.generated_zones[4].get("boss_id", "")) == "lucifer", "Stage 7 has stage-boss Lucifer")
	_assert(String(CityStageCatalog.STAGES[7]["hazard"]) == "lava_brazier", "Stage 7 features lava_brazier hazard")

	gen.free()


func _test_hitstop_manager_camera_shake() -> void:
	_assert(HitstopManager != null, "HitstopManager autoload is active")
	_assert(HitstopManager.has_method("trigger_camera_shake"), "HitstopManager implements trigger_camera_shake")

	var received := [-1.0]
	var handler := func(trauma: float) -> void:
		received[0] = trauma

	HitstopManager.camera_shake_requested.connect(handler)
	# Test 2-arg signature used by BossController slams (e.g. Chupar cannonball sit drop)
	HitstopManager.trigger_camera_shake(0.42, 11.0)
	_assert(is_equal_approx(received[0], 0.42), "trigger_camera_shake(0.42, 11.0) emits camera_shake_requested(0.42)")

	# Test 1-arg signature
	HitstopManager.trigger_camera_shake(0.35)
	_assert(is_equal_approx(received[0], 0.35), "trigger_camera_shake(0.35) emits camera_shake_requested(0.35)")

	HitstopManager.camera_shake_requested.disconnect(handler)


func _test_arcade_menus_and_ui() -> void:
	# Title Screen
	var title_scene := load("res://scenes/ui/title_screen.tscn") as PackedScene
	_assert(title_scene != null, "title_screen.tscn loads cleanly")
	var title_inst := title_scene.instantiate()
	add_child(title_inst)
	_assert(title_inst.has_node("Background"), "Title screen has Background node")
	var bg_rect := title_inst.get_node("Background") as ColorRect
	_assert(bg_rect != null and bg_rect.material is ShaderMaterial, "Title screen Background has ShaderMaterial")
	var shader_mat := bg_rect.material as ShaderMaterial
	_assert(shader_mat.shader != null, "ShaderMaterial has valid shader")
	_assert(shader_mat.shader.resource_path.ends_with("synthwave_cityline.gdshader"), "Background uses synthwave_cityline shader")
	_assert(title_inst.get("_card_style") != null, "Title screen initialized menu glass backdrop style")
	_assert(title_inst.has_node("MarginContainer/VBoxContainer/MenuContainer/StartTourBtn"), "Title screen has StartTourBtn")
	var start_btn := title_inst.get_node("MarginContainer/VBoxContainer/MenuContainer/StartTourBtn") as Button
	var lead_btn := title_inst.get_node("MarginContainer/VBoxContainer/MenuContainer/LeaderboardBtn") as Button
	var juke_btn := title_inst.get_node("MarginContainer/VBoxContainer/MenuContainer/JukeboxBtn") as Button
	var how_btn := title_inst.get_node("MarginContainer/VBoxContainer/MenuContainer/HowToPlayBtn") as Button
	var quit_btn := title_inst.get_node("MarginContainer/VBoxContainer/MenuContainer/QuitBtn") as Button
	_assert(start_btn.text == "START WORLD TOUR", "StartTourBtn text has no number prefix")
	_assert(lead_btn.text == "TOP-10 LEADERBOARD", "LeaderboardBtn text has no number prefix")
	_assert(juke_btn.text == "JUKEBOX", "JukeboxBtn renamed to JUKEBOX without track count")
	_assert(how_btn.text == "HOW TO PLAY", "HowToPlayBtn renamed to HOW TO PLAY without controls suffix")
	_assert(quit_btn.text == "QUIT TO DESKTOP", "QuitBtn text has no number prefix")
	var uniform_font_sizes := (
		start_btn.get_theme_font_size("font_size") == 16
		and lead_btn.get_theme_font_size("font_size") == 16
		and juke_btn.get_theme_font_size("font_size") == 16
		and how_btn.get_theme_font_size("font_size") == 16
		and quit_btn.get_theme_font_size("font_size") == 16
	)
	_assert(uniform_font_sizes, "All title screen menu buttons have uniform 16px font size")
	var uniform_heights := (
		start_btn.custom_minimum_size == Vector2(360, 44)
		and lead_btn.custom_minimum_size == Vector2(360, 44)
		and juke_btn.custom_minimum_size == Vector2(360, 44)
		and how_btn.custom_minimum_size == Vector2(360, 44)
		and quit_btn.custom_minimum_size == Vector2(360, 44)
	)
	_assert(uniform_heights, "All title screen menu buttons have uniform 360x44 minimum size")
	title_inst.free()

	# God Select Screen
	var godsel_scene := load("res://scenes/ui/god_select_screen.tscn") as PackedScene
	_assert(godsel_scene != null, "god_select_screen.tscn loads cleanly")
	var godsel_inst := godsel_scene.instantiate()
	add_child(godsel_inst)
	_assert(godsel_inst.has_node("MarginContainer/VBoxContainer/BottomRow/StartTourBtn"), "God select screen has StartTourBtn")
	godsel_inst.free()

	# Jukebox Screen
	var juke_scene := load("res://scenes/ui/jukebox_screen.tscn") as PackedScene
	_assert(juke_scene != null, "jukebox_screen.tscn loads cleanly")
	var juke_inst := juke_scene.instantiate()
	add_child(juke_inst)
	var tracks: Array = juke_inst.get("_all_tracks")
	_assert(tracks != null and tracks.size() == 37, "Jukebox maps all 37 tracks")
	juke_inst.free()

	# Leaderboard Screen
	var lead_scene := load("res://scenes/ui/leaderboard_screen.tscn") as PackedScene
	_assert(lead_scene != null, "leaderboard_screen.tscn loads cleanly")
	var lead_inst := lead_scene.instantiate()
	add_child(lead_inst)
	_assert(lead_inst.has_node("MarginContainer/VBoxContainer/ScrollContainer/TableContainer"), "Leaderboard screen has TableContainer")
	lead_inst.free()

	# How To Play Screen
	var htp_scene := load("res://scenes/ui/how_to_play_screen.tscn") as PackedScene
	_assert(htp_scene != null, "how_to_play_screen.tscn loads cleanly")
	var htp_inst := htp_scene.instantiate()
	add_child(htp_inst)
	_assert(htp_inst.has_node("MarginContainer/VBoxContainer/Header/BackBtn"), "How to Play screen has BackBtn")
	htp_inst.free()

	# Game Over Screen
	var go_scene := load("res://scenes/ui/game_over_screen.tscn") as PackedScene
	_assert(go_scene != null, "game_over_screen.tscn loads cleanly")
	var go_inst := go_scene.instantiate()
	add_child(go_inst)
	_assert(go_inst.has_node("MarginContainer/VBoxContainer/TitleBtn"), "Game Over screen has TitleBtn")
	go_inst.free()

	# Victory Screen
	var vic_scene := load("res://scenes/ui/victory_screen.tscn") as PackedScene
	_assert(vic_scene != null, "victory_screen.tscn loads cleanly")
	var vic_inst := vic_scene.instantiate()
	add_child(vic_inst)
	_assert(vic_inst.has_node("MarginContainer/VBoxContainer/ReturnBtn"), "Victory screen has ReturnBtn")
	vic_inst.free()

	# Stage Clear Screen behavior on Intermediate vs Final Stage
	var hud := ArcadeHud.new()
	add_child(hud)
	var stage_1_summary: Dictionary = {
		"stage": 1,
		"rank": "S",
		"stage_score": 10000,
		"run_score": 10000,
		"clear_time_sec": 45.0,
		"max_combo": 30,
		"damage_taken": 20,
		"max_variety": 4,
		"best_resonance": "GODLIKE",
	}
	hud.show_stage_clear_summary(stage_1_summary)
	_assert(hud._next_stage_btn.text == "ADVANCE TO STAGE 2 >>", "Intermediate stage clear button advances to next stage")
	_assert(hud._replay_stage_btn.visible, "Intermediate stage keeps restart current city button visible")

	var final_stage_summary: Dictionary = {
		"stage": GameManager.max_implemented_stage,
		"rank": "S",
		"stage_score": 50000,
		"run_score": 250000,
		"clear_time_sec": 90.0,
		"max_combo": 65,
		"damage_taken": 100,
		"max_variety": 4,
		"best_resonance": "GODLIKE",
	}
	hud.show_stage_clear_summary(final_stage_summary)
	_assert(hud._next_stage_btn.text == "COMPLETE TOUR & VIEW CREDITS", "Final stage clear button displays 'COMPLETE TOUR & VIEW CREDITS'")
	_assert(not hud._replay_stage_btn.visible, "Final stage clear hides restart current city button")
	hud.free()


func _test_synthwave_ui_styling() -> void:
	# 1. Custom Synthwave Theme Resource
	var theme := load("res://assets/synthwave_theme.tres") as Theme
	_assert(theme != null, "synthwave_theme.tres loads cleanly")

	var hover_sb := theme.get_stylebox("hover", "Button") as StyleBoxFlat
	_assert(hover_sb != null, "Theme defines Button hover StyleBoxFlat")
	_assert(hover_sb.border_color.is_equal_approx(SynthwaveUI.COLOR_BORDER_HOVER), "Button hover border is neon magenta #FF007F")
	_assert(hover_sb.shadow_size > 0, "Button hover style has neon cyan shadow glow")
	_assert(theme.get_color("font_hover_color", "Button").is_equal_approx(SynthwaveUI.COLOR_TEXT_HOVER), "Button hover text is neon cyan")

	# 2. Title Screen buttons have pointing hand cursor
	var title_scene := load("res://scenes/ui/title_screen.tscn") as PackedScene
	var title_inst := title_scene.instantiate()
	add_child(title_inst)
	var start_btn := title_inst.get_node("MarginContainer/VBoxContainer/MenuContainer/StartTourBtn") as Button
	var quit_btn := title_inst.get_node("MarginContainer/VBoxContainer/MenuContainer/QuitBtn") as Button
	_assert(start_btn.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND, "StartTourBtn has pointing hand cursor")
	_assert(quit_btn.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND, "QuitBtn has pointing hand cursor")
	title_inst.free()

	# 3. God Select Screen cards and buttons have pointing hand cursor
	var godsel_scene := load("res://scenes/ui/god_select_screen.tscn") as PackedScene
	var godsel_inst := godsel_scene.instantiate()
	add_child(godsel_inst)
	var cards: Array = godsel_inst.get("_card_panels")
	_assert(cards.size() == 4, "God select screen generated 4 god cards")
	var all_cards_pointer := true
	for c in cards:
		if c.mouse_default_cursor_shape != Control.CURSOR_POINTING_HAND:
			all_cards_pointer = false
	_assert(all_cards_pointer, "All god select cards have pointing hand cursor")
	var back_btn := godsel_inst.get_node("MarginContainer/VBoxContainer/Header/BackBtn") as Button
	_assert(back_btn.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND, "God select BackBtn has pointing hand cursor")
	godsel_inst.free()

	# 4. Arcade HUD modal cards and buttons have pointing hand cursor & synthwave styles
	var hud := ArcadeHud.new()
	add_child(hud)
	var pause_p := hud.get("_pause_panel") as PanelContainer
	_assert(pause_p != null and pause_p.has_theme_stylebox_override("panel"), "Pause card has synthwave StyleBox override")
	_assert(hud._pause_quit_btn != null, "Pause card has quit button")
	_assert(hud._pause_quit_btn.text == "QUIT TO MENU", "Pause quit button is labeled 'QUIT TO MENU'")
	_assert(hud._pause_quit_btn.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND, "Pause quit button has pointing hand cursor")
	var quit_emitted := [false]
	hud.exit_to_menu_requested.connect(func(): quit_emitted[0] = true)
	get_tree().paused = true
	hud._pause_quit_btn.pressed.emit()
	_assert(quit_emitted[0], "Pressing pause quit button emits exit_to_menu_requested signal")
	_assert(not get_tree().paused, "Pressing pause quit button unpauses scene tree")
	_assert(hud._next_stage_btn.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND, "Next stage button has pointing hand cursor")
	_assert(hud._replay_stage_btn.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND, "Replay stage button has pointing hand cursor")

	var res_b := hud.get("_resonance_box") as PanelContainer
	_assert(res_b != null, "ArcadeHud instantiated _resonance_box")
	_assert(res_b.anchor_left == 1.0 and res_b.anchor_top == 1.0, "Resonance box is anchored to bottom-right (PRESET_BOTTOM_RIGHT)")
	_assert(res_b.offset_left == -268.0 and res_b.offset_top == -108.0, "Resonance box is positioned at bottom-right across from soundtrack toast (offsets %s, %s)" % [res_b.offset_left, res_b.offset_top])
	_assert(res_b.custom_minimum_size == Vector2(250, 94), "Resonance box has compact 250x94 minimum size")

	hud.free()


func _test_stage_grading_math() -> void:
	GameManager.reset_stage_metrics()
	GameManager.stage_elapsed_sec = 120.0
	GameManager.stage_max_combo = 40
	GameManager.stage_damage_taken = 150.0
	GameManager.stage_max_variety = 4
	var s_rank := GameManager.compute_stage_rank()
	_assert(s_rank["rank"] == "S", "120s clear, 40-hit combo, 150 dmg, 4 gods achieves S-Rank (got %s)" % s_rank["rank"])

	GameManager.reset_stage_metrics()
	GameManager.stage_elapsed_sec = 320.0
	GameManager.stage_max_combo = 5
	GameManager.stage_damage_taken = 980.0
	GameManager.stage_max_variety = 1
	var c_rank := GameManager.compute_stage_rank()
	_assert(c_rank["rank"] == "C" or c_rank["rank"] == "B", "Slow clear, low combo, high damage yields B/C-Rank (got %s)" % c_rank["rank"])


func _test_continue_credit_fairness() -> void:
	GameManager.credits_remaining = 3
	GameManager.run_score = 50000
	var success := GameManager.use_continue_credit()
	_assert(success, "use_continue_credit returns true when credits remain")
	_assert(GameManager.credits_remaining == 2, "Continue consumes 1 credit (now 2)")
	_assert(GameManager.run_score == 0, "Continue resets run score to 0 for leaderboard fairness")


func _test_save_persistence() -> void:
	SaveManager.save_path_override = "user://test_side_beat_save.json"
	SaveManager.reset_to_defaults()
	SaveManager.record_stage_clear(1, "A", 18500)
	SaveManager.record_stage_clear(1, "S", 24200)
	SaveManager.unlock_track("res://tracks/Widjet.mp3")
	var rank_idx: int = SaveManager.submit_high_score("LEO", 99999, 1, "GODLIKE")
	_assert(rank_idx == 0, "High score 99999 takes #1 spot on Top-10 Arcade Leaderboard")

	SaveManager.load_save()
	_assert(SaveManager.get_top_score() == 99999, "Reloaded leaderboard persists #1 high score")
	_assert(SaveManager.data["city_best_ranks"].get("1", "") == "S", "Reloaded save persists Stage 1 S-Rank")
	_assert(SaveManager.is_track_unlocked("res://tracks/Widjet.mp3"), "Reloaded save persists unlocked Jukebox track")

	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_side_beat_save.json"))
	SaveManager.save_path_override = ""
	SaveManager.load_save()


func _test_combat_hurtbox_deferred_deactivation() -> void:
	# WaveEnemy lethal KO test
	var enemy := WaveEnemy.new()
	add_child(enemy)
	enemy.configure_tier("thug")
	var enemy_hit_res: Dictionary = enemy.receive_hit({"raw_damage": 999.0, "facing_sign": 1.0})
	_assert(enemy_hit_res.get("ko", false) == true, "WaveEnemy KO'd on lethal strike")
	_assert(enemy.get("_is_dead") == true, "WaveEnemy marked dead cleanly")

	# Check ko_collapse bone ground contact
	var enemy_glb := GlbLoader.instantiate_glb("res://assets/enemies/enemy_base.glb")
	add_child(enemy_glb)
	var e_anim := GlbLoader.find_anim_player(enemy_glb)
	var e_skel := GlbLoader.find_skeleton(enemy_glb)
	_assert(e_anim != null and e_anim.has_animation("ko_collapse"), "EnemyBase GLB has ko_collapse clip")
	if e_anim and e_skel:
		e_anim.play("ko_collapse")
		e_anim.advance(0.5)
		var h_idx := e_skel.find_bone("hips")
		var hd_idx := e_skel.find_bone("head")
		var hips_y := e_skel.get_bone_global_pose(h_idx).origin.y if h_idx >= 0 else 99.0
		var head_y := e_skel.get_bone_global_pose(hd_idx).origin.y if hd_idx >= 0 else 99.0
		_assert(hips_y <= 0.25, "Enemy ko_collapse hips touch ground (got Y=%.2f <= 0.25)" % hips_y)
		_assert(head_y <= 0.25, "Enemy ko_collapse head rests on ground (got Y=%.2f <= 0.25)" % head_y)
	enemy_glb.queue_free()

	# Airborne enemy death and ground landing test
	var test_floor := StaticBody3D.new()
	test_floor.collision_layer = (1 << 0)
	var f_col := CollisionShape3D.new()
	var f_box := BoxShape3D.new()
	f_box.size = Vector3(50.0, 1.0, 10.0)
	f_col.shape = f_box
	f_col.position = Vector3(0.0, -0.5, 0.0)
	test_floor.add_child(f_col)
	add_child(test_floor)

	var air_enemy := WaveEnemy.new()
	add_child(air_enemy)
	air_enemy.global_position = Vector3(10.0, 3.5, 0.0)
	air_enemy.configure_tier("thug")
	air_enemy.receive_hit({"raw_damage": 999.0, "facing_sign": 1.0})
	_assert(air_enemy.get("_is_dead") == true, "Airborne WaveEnemy marked dead")
	_assert(air_enemy.get("_death_landed") == false, "Airborne WaveEnemy not yet landed immediately on hit")
	for _f in range(80):
		if not is_instance_valid(air_enemy) or air_enemy.is_queued_for_deletion():
			break
		air_enemy._physics_process(1.0 / 60.0)
	_assert(air_enemy.get("_death_landed") == true, "Airborne WaveEnemy lands on floor before despawning")
	air_enemy.queue_free()
	test_floor.queue_free()

	# DestructibleProp shatter test
	var prop := DestructibleProp.new()
	add_child(prop)
	prop.setup_prop("fire_hydrant")
	var prop_hit_res: Dictionary = prop.receive_hit({"raw_damage": 999.0, "facing_sign": 1.0})
	_assert(prop_hit_res.get("connected", false) == true, "DestructibleProp receives strike")
	_assert(prop.get("_destroyed") == true, "DestructibleProp shatters cleanly")
	var found_pickup := false
	for child in get_children():
		if child is PickupItem:
			found_pickup = true
			child.queue_free()
			break
	_assert(found_pickup, "DestructibleProp spawned PickupItem without query flush error")

	# BossController lethal KO test
	var boss := BossController.new()
	add_child(boss)
	boss.setup_boss("chadzug", 0.0, 20.0)
	var boss_hit_res: Dictionary = boss.receive_hit({"raw_damage": 9999.0, "facing_sign": 1.0})
	_assert(boss_hit_res.get("ko", false) == true, "BossController KO'd on lethal strike")

	enemy.queue_free()
	prop.queue_free()
	boss.queue_free()


func _test_simplified_controls_and_instruction_screens() -> void:
	# 1. Action map checks
	_assert(not InputMap.has_action(&"attack_light") or InputMap.action_get_events(&"attack_light").is_empty(), "attack_light action is removed")
	_assert(not InputMap.has_action(&"grab") or InputMap.action_get_events(&"grab").is_empty(), "grab action is removed")

	# Check WASD only on movement
	var move_left_events := InputMap.action_get_events(&"move_left")
	_assert(move_left_events.size() == 1 and (move_left_events[0] as InputEventKey).physical_keycode == KEY_A, "move_left mapped strictly to KEY_A")
	var move_right_events := InputMap.action_get_events(&"move_right")
	_assert(move_right_events.size() == 1 and (move_right_events[0] as InputEventKey).physical_keycode == KEY_D, "move_right mapped strictly to KEY_D")
	var move_up_events := InputMap.action_get_events(&"move_up")
	_assert(move_up_events.size() == 1 and (move_up_events[0] as InputEventKey).physical_keycode == KEY_W, "move_up mapped strictly to KEY_W")
	var move_down_events := InputMap.action_get_events(&"move_down")
	_assert(move_down_events.size() == 1 and (move_down_events[0] as InputEventKey).physical_keycode == KEY_S, "move_down mapped strictly to KEY_S")

	# Check combat buttons are strictly K, L, O, U
	var heavy_events := InputMap.action_get_events(&"attack_heavy")
	_assert(heavy_events.size() == 1 and (heavy_events[0] as InputEventKey).physical_keycode == KEY_K, "attack_heavy mapped strictly to KEY_K")
	var special_events := InputMap.action_get_events(&"attack_special")
	_assert(special_events.size() == 1 and (special_events[0] as InputEventKey).physical_keycode == KEY_L, "attack_special mapped strictly to KEY_L")
	var super_events := InputMap.action_get_events(&"attack_super")
	_assert(super_events.size() == 1 and (super_events[0] as InputEventKey).physical_keycode == KEY_O, "attack_super mapped strictly to KEY_O")
	var parry_events := InputMap.action_get_events(&"block_parry")
	_assert(parry_events.size() == 1 and (parry_events[0] as InputEventKey).physical_keycode == KEY_U, "block_parry mapped strictly to KEY_U")

	# Jump is strictly Space
	var jump_events := InputMap.action_get_events(&"jump")
	_assert(jump_events.size() == 1 and (jump_events[0] as InputEventKey).physical_keycode == KEY_SPACE, "jump mapped strictly to KEY_SPACE")

	# Verify no joypad events across all mapped game actions
	var game_actions := [
		&"move_left", &"move_right", &"move_up", &"move_down", &"jump",
		&"attack_heavy", &"attack_special", &"attack_super", &"block_parry",
		&"morph_1", &"morph_2", &"morph_3", &"morph_4", &"morph_prev", &"morph_next", &"pause"
	]
	var joypad_event_count := 0
	for act in game_actions:
		for ev in InputMap.action_get_events(act):
			if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
				joypad_event_count += 1
	_assert(joypad_event_count == 0, "All gamepad joypad events stripped from game InputMap actions (0 found)")

	# Verify How To Play screen text
	var htp_scene := load("res://scenes/ui/how_to_play_screen.tscn") as PackedScene
	var htp_inst := htp_scene.instantiate()
	var controls_body := htp_inst.get_node("MarginContainer/VBoxContainer/HSplitContainer/LeftCol/ControlsBody") as RichTextLabel
	var morph_body := htp_inst.get_node("MarginContainer/VBoxContainer/HSplitContainer/RightCol/MorphBody") as RichTextLabel
	_assert(not controls_body.text.to_lower().contains("light attack"), "HowToPlay text does not contain 'light attack'")
	_assert(not controls_body.text.to_lower().contains("bowling"), "HowToPlay text does not contain 'bowling'")
	_assert(not controls_body.text.to_lower().contains("left stick"), "HowToPlay text does not contain 'left stick'")
	_assert(not controls_body.text.to_lower().contains("arrow keys"), "HowToPlay text does not contain 'arrow keys'")
	_assert(not morph_body.text.to_lower().contains("d-pad"), "HowToPlay morph text does not contain 'd-pad'")
	htp_inst.free()

	# Verify HUD pause card text
	var hud := ArcadeHud.new()
	add_child(hud)
	var pause_panel := hud.get("_pause_panel") as PanelContainer
	var pbody := pause_panel.get_child(0).get_child(1) as Label
	_assert(not pbody.text.to_lower().contains("light attack"), "Pause card does not contain 'light attack'")
	_assert(not pbody.text.to_lower().contains("lane throw"), "Pause card does not contain 'lane throw'")
	_assert(not pbody.text.to_lower().contains("left stick"), "Pause card does not contain 'left stick'")
	_assert(not pbody.text.to_lower().contains("d-pad"), "Pause card does not contain 'd-pad'")
	hud.queue_free()


func _test_battle_arena_on_screen_containment() -> void:
	var gen := ProceduralCityGenerator.new()
	add_child(gen)
	var stage_data := gen.generate_city_stage(1, 1337)
	var zones: Array = stage_data.get("zones", [])
	_assert(zones.size() == 5, "Battle arena containment test: stage 1 has 5 encounter zones")

	var all_7m_half_width := true
	for z in zones:
		var c_x := float(z["center_x"])
		var min_x := float(z["min_x"])
		var max_x := float(z["max_x"])
		if not is_equal_approx(min_x, c_x - 7.0) or not is_equal_approx(max_x, c_x + 7.0):
			all_7m_half_width = false
			printerr("Zone min/max mismatch: center=%.2f min=%.2f max=%.2f" % [c_x, min_x, max_x])
	_assert(all_7m_half_width, "All locked battle zones have uniform 7.0m visible on-screen half-width")
	gen.queue_free()

	# Test WaveEnemy entrance and clamping
	var enemy_scene := load("res://scenes/enemies/wave_enemy.tscn") as PackedScene
	var enemy := enemy_scene.instantiate() as WaveEnemy
	add_child(enemy)
	enemy.arena_x_min = 29.0
	enemy.arena_x_max = 43.0
	enemy.has_entered_arena = false
	enemy.global_position = Vector3(43.8, 0.15, 0.0)

	# Before entering, _clamp_corridor does not clamp X
	enemy._clamp_corridor()
	_assert(is_equal_approx(enemy.global_position.x, 43.8), "WaveEnemy spawned 0.8m off-screen is not clamped before entering arena")

	# Once crossed into bounds, has_entered_arena becomes true and clamps
	enemy.global_position.x = 42.5
	enemy._physics_process(0.016)
	_assert(enemy.has_entered_arena, "WaveEnemy marks has_entered_arena = true once crossing within [min_x, max_x]")

	# Subsequent attempt to go past max_x is clamped strictly
	enemy.global_position.x = 45.0
	enemy._clamp_corridor()
	_assert(is_equal_approx(enemy.global_position.x, 43.0), "WaveEnemy is strictly clamped to arena_x_max once entered")

	# WaveEnemy wall bounce at screen boundary
	enemy.global_position.x = 42.8
	enemy.velocity = Vector3(10.0, 0.0, 0.0)
	enemy.set("_wall_bounced", true)
	enemy._check_wall_and_ground_bounces()
	_assert(enemy.velocity.x < 0.0 and enemy.velocity.y > 5.0, "WaveEnemy bounces off screen boundary with inverted X and vertical pop")
	enemy.queue_free()

	# Test Player arena bounds clamping
	var ply_scene := load("res://scenes/player/shared_soul_player.tscn") as PackedScene
	var ply := ply_scene.instantiate() as SharedSoulPlayer
	add_child(ply)
	ply.set_arena_x_bounds(29.0, 43.0)
	ply.global_position = Vector3(20.0, 0.2, 0.0)
	ply._clamp_corridor()
	_assert(is_equal_approx(ply.global_position.x, 29.0), "Player cannot move past left battle arena boundary (clamped to 29.0)")

	ply.global_position = Vector3(50.0, 0.2, 0.0)
	ply._clamp_corridor()
	_assert(is_equal_approx(ply.global_position.x, 43.0), "Player cannot move past right battle arena boundary (clamped to 43.0)")
	ply.queue_free()


func _test_shader_effects_and_post_fx() -> void:
	# 1. Verify all 6 new shader files load cleanly
	var shader_paths := [
		"res://shaders/arcade_post_fx.gdshader",
		"res://shaders/fighter_surface_fx.gdshader",
		"res://shaders/fighter_ko_dissolve.gdshader",
		"res://shaders/combat_hit_slash.gdshader",
		"res://shaders/energy_shockwave.gdshader",
		"res://shaders/danger_telegraph.gdshader",
		"res://shaders/wet_neon_asphalt.gdshader",
		"res://shaders/skyline_cyber_rim.gdshader",
	]
	for sp in shader_paths:
		var sh := load(sp) as Shader
		_assert(sh != null, "Shader loads and compiles cleanly: %s" % sp)

	# 2. Verify PostFxManager autoload, CRT preset cycling, and dynamic triggers
	_assert(PostFxManager != null, "PostFxManager autoload is active")
	PostFxManager.set_crt_preset(PostFxManager.CrtPreset.CRISP_ARCADE, false)
	_assert(PostFxManager.current_preset == 1 and PostFxManager.get_preset_label() == "CRISP ARCADE", "Default CRT preset is CRISP ARCADE")
	PostFxManager.cycle_crt_preset()
	_assert(PostFxManager.current_preset == 2 and PostFxManager.get_preset_label() == "HEAVY RETRO CRT", "Cycled CRT preset to HEAVY RETRO CRT")
	PostFxManager.cycle_crt_preset()
	_assert(PostFxManager.current_preset == 0 and PostFxManager.get_preset_label() == "OFF", "Cycled CRT preset to OFF")
	PostFxManager.cycle_crt_preset()
	_assert(PostFxManager.current_preset == 1, "Cycled CRT preset back to CRISP ARCADE")

	PostFxManager.trigger_morph_glitch(Color("#00D4FF"), 0.65, 0.20)
	_assert(PostFxManager.get("_glitch_intensity") > 0.5, "trigger_morph_glitch activates screen-space glitch intensity")
	PostFxManager.trigger_parry_or_super_impact(Vector3.ZERO, Color("#FFE066"), true)
	_assert(PostFxManager.get("_impact_flash") > 0.7 and PostFxManager.get("_ripple_progress") < 1.0, "trigger_parry_or_super_impact activates radial shockwave ripple and impact flash")

	# 3. Verify FighterShaderHelper on Player, WaveEnemy, and BossController
	var ply_scene := load("res://scenes/player/shared_soul_player.tscn") as PackedScene
	var ply := ply_scene.instantiate() as SharedSoulPlayer
	add_child(ply)
	var god_rigs: Array = ply.get("_god_rigs")
	_assert(god_rigs.size() == 4 and god_rigs[0].get("fx_mat") is ShaderMaterial, "SharedSoulPlayer attaches fighter_surface_fx ShaderMaterial to all 4 God rigs")
	ply.free()

	var enemy := WaveEnemy.new()
	add_child(enemy)
	enemy.configure_tier("bruiser")
	var e_fx := enemy.get("_fx_mat") as ShaderMaterial
	_assert(e_fx != null and is_equal_approx(float(e_fx.get_shader_parameter("armor_ratio")), 1.0), "Bruiser WaveEnemy initializes surface FX shader with super-armor pulse")
	enemy.receive_hit({"raw_damage": 30.0, "armor_damage": 10.0, "facing_sign": 1.0, "spark_color": Color("#00D4FF")})
	_assert(float(e_fx.get_shader_parameter("hit_flash_amount")) > 0.0, "WaveEnemy triggers surface hit-flash on strike")
	enemy.receive_hit({"raw_damage": 999.0, "facing_sign": 1.0})
	_assert(enemy.get("_dissolve_mat") is ShaderMaterial, "WaveEnemy triggers neon voxel KO dissolve shader on defeat")
	enemy.free()

	var boss := BossController.new()
	add_child(boss)
	boss.setup_boss("chadzug", 0.0, 20.0)
	var b_fx := boss.get("_fx_mat") as ShaderMaterial
	_assert(b_fx != null and is_equal_approx(float(b_fx.get_shader_parameter("armor_ratio")), 1.0), "BossController initializes surface FX shader with active super-armor rim")
	boss.receive_hit({"raw_damage": 700.0, "armor_damage": 50.0, "facing_sign": 1.0})
	_assert(boss.phase == 2 and is_equal_approx(float(b_fx.get_shader_parameter("enrage_factor")), 1.0), "BossController Phase 2 shift activates crimson enrage shader strobe")
	boss._enter_state(&"pursue")
	boss.receive_hit({"raw_damage": 9999.0, "facing_sign": 1.0})
	_assert(boss.get("_dissolve_mat") is ShaderMaterial, "BossController triggers neon voxel KO dissolve shader on defeat")
	boss.free()

	# 4. Verify HitstopManager shader VFX and ProceduralCityGenerator stage shaders
	var vfx_holder := Node3D.new()
	add_child(vfx_holder)
	HitstopManager.register_vfx_root(vfx_holder)
	HitstopManager.spawn_hit_spark(Vector3.ZERO, Color("#00D4FF"), 1.0)
	HitstopManager.spawn_shockwave_ring(Vector3.ZERO, Color("#FFE066"), 3.0, 0.25)
	HitstopManager.spawn_lightning_pillar(Vector3.ZERO, Color("#00D4FF"), 5.0, 0.5)
	var tele := HitstopManager.spawn_ground_telegraph(Vector3.ZERO, Vector2(2.0, 2.0), 0.35)
	_assert(tele != null and tele.material_override is ShaderMaterial, "HitstopManager ground telegraph uses danger_telegraph ShaderMaterial")
	vfx_holder.free()

	var gen := ProceduralCityGenerator.new()
	add_child(gen)
	gen.generate_city_stage(1, 1337)
	var chunk0 := gen.get_node_or_null("Chunk_0")
	var road_mesh := chunk0.get_node_or_null("RoadMesh") as MeshInstance3D if chunk0 else null
	var tower_mesh := chunk0.get_node_or_null("SkylineTower_0") as MeshInstance3D if chunk0 else null
	_assert(road_mesh != null and road_mesh.material_override is ShaderMaterial, "ProceduralCityGenerator road uses wet_neon_asphalt ShaderMaterial")
	_assert(tower_mesh != null and tower_mesh.material_override is ShaderMaterial, "ProceduralCityGenerator skyline tower uses skyline_cyber_rim ShaderMaterial")
	gen.free()
	await get_tree().process_frame
	await get_tree().process_frame


func _test_snappy_prop_and_ko_hitstop() -> void:
	# 1. Verify DestructibleProp receive_hit payload tags is_prop and destroyed
	var prop := DestructibleProp.new()
	add_child(prop)
	prop.hp = 100.0
	var res1 := prop.receive_hit({"raw_damage": 30.0})
	_assert(res1["is_prop"] == true and res1["destroyed"] == false, "DestructibleProp non-lethal strike sets is_prop=true and destroyed=false")
	var res2 := prop.receive_hit({"raw_damage": 100.0})
	_assert(res2["is_prop"] == true and res2["destroyed"] == true, "DestructibleProp lethal strike sets is_prop=true and destroyed=true")

	# 2. Verify SharedSoulPlayer _register_successful_player_hit triggers 0 frames on prop
	var ply_scene := load("res://scenes/player/shared_soul_player.tscn") as PackedScene
	var ply := ply_scene.instantiate() as SharedSoulPlayer
	add_child(ply)
	var move := AttackData.new()
	move.hitstop_frames = 6
	move.spark_scale = 1.0

	HitstopManager.set("_hitstop_timer", 0.0)
	ply._register_successful_player_hit(move, Vector3.ZERO, 50.0, true, true)
	_assert(is_equal_approx(float(HitstopManager.get("_hitstop_timer")), 0.0), "Prop destruction applies 0 hitstop frames to HitstopManager (snappy flow)")

	# 3. Verify lethal enemy KO triggers exactly 2 frames of hitstop (~0.0333s)
	HitstopManager.set("_hitstop_timer", 0.0)
	ply._register_successful_player_hit(move, Vector3.ZERO, 50.0, false, true)
	var ko_timer: float = HitstopManager.get("_hitstop_timer")
	_assert(is_equal_approx(ko_timer, 2.0 / 60.0), "Enemy lethal KO applies exactly 2 hitstop frames (got %f, expected %f)" % [ko_timer, 2.0 / 60.0])

	# 4. Verify non-lethal hit against living enemy applies full move.hitstop_frames
	HitstopManager.set("_hitstop_timer", 0.0)
	ply._register_successful_player_hit(move, Vector3.ZERO, 50.0, false, false)
	var normal_timer: float = HitstopManager.get("_hitstop_timer")
	_assert(is_equal_approx(normal_timer, 6.0 / 60.0), "Non-lethal hit on enemy applies full move.hitstop_frames (got %f, expected %f)" % [normal_timer, 6.0 / 60.0])

	HitstopManager.set("_hitstop_timer", 0.0)
	ply.free()




