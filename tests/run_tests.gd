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
	_test_resonance_math()
	await _test_stage_1_runtime_and_morph_preservation()
	_test_save_persistence()

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
