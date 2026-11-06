class_name GodRosterCatalog
extends RefCounted
## Builds the complete data-driven Pantheon Roster & Movesets per specs.yml.


static func _mk_move(cfg: Dictionary) -> AttackData:
	var m := AttackData.new()
	for k in cfg.keys():
		m.set(k, cfg[k])
	return m


static func build_roster() -> Array[GodProfile]:
	return [
		_build_endor(),
		_build_ir(),
		_build_osiris(),
		_build_horus(),
	]


static func _add_common_normals(g: GodProfile, hit_sfx: String, weapon_sockets: PackedStringArray, reach: float) -> void:
	g.moves[&"light_1"] = _mk_move({
		"move_id": &"light_1", "display_name": "Light Strike I", "anim_name": &"light_1",
		"startup_frames": 4, "active_frames": 5, "recovery_frames": 8, "cancel_window_start": 6,
		"damage": 36.0, "armor_damage": 18.0, "meter_gain": 5.0, "hitstop_frames": 3,
		"forward_lunge_speed": 2.4, "knockback_vel": Vector3(2.5, 0.0, 0.0),
		"active_sockets": PackedStringArray(["hand.L", weapon_sockets[0]]),
		"hitbox_extents": Vector3(reach, 0.9, 0.95), "sfx_hit": hit_sfx,
	})
	g.moves[&"light_2"] = _mk_move({
		"move_id": &"light_2", "display_name": "Light Strike II", "anim_name": &"light_2",
		"startup_frames": 5, "active_frames": 5, "recovery_frames": 10, "cancel_window_start": 7,
		"damage": 44.0, "armor_damage": 24.0, "meter_gain": 6.0, "hitstop_frames": 4,
		"forward_lunge_speed": 3.0, "knockback_vel": Vector3(3.2, 0.0, 0.0),
		"active_sockets": weapon_sockets,
		"hitbox_extents": Vector3(reach * 1.1, 0.95, 1.0), "sfx_hit": hit_sfx,
	})
	g.moves[&"light_3"] = _mk_move({
		"move_id": &"light_3", "display_name": "Combo Finisher", "anim_name": &"light_3",
		"startup_frames": 6, "active_frames": 6, "recovery_frames": 13, "cancel_window_start": 9,
		"damage": 62.0, "armor_damage": 38.0, "meter_gain": 8.5, "hitstop_frames": 5,
		"forward_lunge_speed": 4.2, "knockback_vel": Vector3(6.8, 2.8, 0.0),
		"active_sockets": weapon_sockets,
		"hitbox_extents": Vector3(reach * 1.25, 1.05, 1.2), "sfx_hit": hit_sfx, "spark_scale": 1.25,
	})
	g.moves[&"heavy_ground"] = _mk_move({
		"move_id": &"heavy_ground", "display_name": "Armor Crusher", "anim_name": &"heavy_ground",
		"startup_frames": 9, "active_frames": 7, "recovery_frames": 14, "cancel_window_start": 12,
		"damage": 84.0, "armor_damage": 70.0, "meter_gain": 10.0, "hitstop_frames": 6,
		"forward_lunge_speed": 4.0, "knockback_vel": Vector3(7.5, 3.2, 0.0),
		"crumples_block": true, "hyper_armor": g.heavy_poise_armor,
		"active_sockets": weapon_sockets,
		"hitbox_extents": Vector3(reach * 1.35, 1.25, 1.25), "sfx_hit": "hit_heavy", "spark_scale": 1.45,
	})
	g.moves[&"launcher_up"] = _mk_move({
		"move_id": &"launcher_up", "display_name": "Pantheon Launcher", "anim_name": &"launcher_up",
		"startup_frames": 7, "active_frames": 6, "recovery_frames": 12, "cancel_window_start": 9,
		"damage": 58.0, "armor_damage": 42.0, "meter_gain": 8.0, "hitstop_frames": 5,
		"forward_lunge_speed": 2.2, "knockback_vel": Vector3(2.2, 9.8, 0.0),
		"launches_airborne": true, "hyper_armor": g.heavy_poise_armor,
		"active_sockets": weapon_sockets,
		"hitbox_extents": Vector3(reach * 1.2, 1.45, 1.15), "sfx_hit": "hit_heavy", "spark_scale": 1.3,
	})
	g.moves[&"air_combo_1"] = _mk_move({
		"move_id": &"air_combo_1", "display_name": "Aerial Strike I", "anim_name": &"air_combo_1",
		"startup_frames": 4, "active_frames": 5, "recovery_frames": 8, "cancel_window_start": 6,
		"damage": 38.0, "armor_damage": 20.0, "meter_gain": 5.5, "hitstop_frames": 4,
		"forward_lunge_speed": 1.8, "knockback_vel": Vector3(1.8, 4.6, 0.0),
		"launches_airborne": true, "active_sockets": weapon_sockets,
		"hitbox_extents": Vector3(reach * 1.15, 1.1, 1.05), "sfx_hit": hit_sfx,
	})
	g.moves[&"air_combo_2"] = _mk_move({
		"move_id": &"air_combo_2", "display_name": "Aerial Strike II", "anim_name": &"air_combo_2",
		"startup_frames": 5, "active_frames": 6, "recovery_frames": 10, "cancel_window_start": 7,
		"damage": 48.0, "armor_damage": 28.0, "meter_gain": 7.0, "hitstop_frames": 5,
		"forward_lunge_speed": 2.2, "knockback_vel": Vector3(2.6, 5.2, 0.0),
		"launches_airborne": true, "active_sockets": weapon_sockets,
		"hitbox_extents": Vector3(reach * 1.2, 1.15, 1.1), "sfx_hit": hit_sfx, "spark_scale": 1.2,
	})


static func _build_endor() -> GodProfile:
	var g := GodProfile.new()
	g.id = "endor"
	g.display_name = "Endor"
	g.pantheon = "Asgardian (Norse)"
	g.input_slot = 1
	g.archetype = "Heavy Armor-Breaker / Thunder Brawler"
	g.signature_weapon = "Runic War-Hammer & Thunder Gauntlets"
	g.glb_path = "res://assets/characters/endor.glb"
	g.primary_color = Color("#00D4FF")
	g.secondary_color = Color("#1E3A5F")
	g.accent_color = Color("#C8D6E5")
	g.move_speed = 5.2
	g.attack_speed_mult = 0.85
	g.damage_mult = 1.35
	g.heavy_poise_armor = true
	g.morph_sfx = "morph_endor"

	_add_common_normals(g, "hit_thunder", PackedStringArray(["weapon_socket.R", "hand.R"]), 1.35)

	g.moves[&"air_dive_or_slam"] = _mk_move({
		"move_id": &"air_dive_or_slam", "display_name": "Anvil Drop Slam", "anim_name": &"air_dive_or_slam",
		"startup_frames": 6, "active_frames": 12, "recovery_frames": 12, "cancel_window_start": 14,
		"damage": 82.0, "armor_damage": 75.0, "meter_gain": 9.0, "hitstop_frames": 6,
		"dive_velocity": Vector3(3.0, -16.0, 0.0), "knockback_vel": Vector3(4.5, 6.2, 0.0),
		"ground_bounces": true, "hyper_armor": true,
		"aoe_corridor_box": Vector3(3.2, 1.6, 3.0), "sfx_hit": "hit_thunder", "spark_scale": 1.5,
	})
	# Special 1: Mjolnir Ground Shatter (Z-corridor lightning shockwave, crumples block + hits low hurtboxes like Chadzug)
	g.moves[&"pantheon_special_1"] = _mk_move({
		"move_id": &"pantheon_special_1", "display_name": "Mjolnir Ground Shatter", "anim_name": &"pantheon_special_1",
		"startup_frames": 8, "active_frames": 10, "recovery_frames": 12, "cancel_window_start": 15,
		"damage": 105.0, "armor_damage": 95.0, "meter_cost": 25.0, "meter_gain": 0.0, "hitstop_frames": 7,
		"knockback_vel": Vector3(5.2, 6.8, 0.0), "crumples_block": true, "ground_bounces": true, "hyper_armor": true,
		"aoe_corridor_box": Vector3(5.4, 1.8, 6.4), "sfx_hit": "hit_thunder", "spark_scale": 1.7,
	})
	# Special 2: Thunderclap Charge (Hyper-armor shoulder tackle + hammer wall-bounce)
	g.moves[&"pantheon_special_2"] = _mk_move({
		"move_id": &"pantheon_special_2", "display_name": "Thunderclap Charge", "anim_name": &"pantheon_special_2",
		"startup_frames": 5, "active_frames": 13, "recovery_frames": 11, "cancel_window_start": 14,
		"damage": 98.0, "armor_damage": 90.0, "meter_cost": 25.0, "meter_gain": 0.0, "hitstop_frames": 6,
		"forward_lunge_speed": 13.5, "knockback_vel": Vector3(11.5, 5.4, 0.0),
		"wall_bounces": true, "hyper_armor": true,
		"aoe_corridor_box": Vector3(2.8, 1.9, 2.2), "sfx_hit": "hit_thunder", "spark_scale": 1.6,
	})
	# Super: Asgard's Verdict (Bifrost lightning pillars across locked arena)
	g.moves[&"pantheon_super"] = _mk_move({
		"move_id": &"pantheon_super", "display_name": "Asgard's Verdict", "anim_name": &"pantheon_super",
		"startup_frames": 10, "active_frames": 18, "recovery_frames": 14, "cancel_window_start": 24,
		"damage": 240.0, "armor_damage": 180.0, "meter_cost": 100.0, "meter_gain": 0.0, "hitstop_frames": 7,
		"knockback_vel": Vector3(6.5, 9.5, 0.0), "launches_airborne": true, "unblockable": true, "hyper_armor": true,
		"aoe_corridor_box": Vector3(16.0, 4.5, 6.8), "sfx_hit": "hit_thunder", "spark_scale": 2.1,
	})
	return g


static func _build_ir() -> GodProfile:
	var g := GodProfile.new()
	g.id = "ir"
	g.display_name = "Ir"
	g.pantheon = "Greek (Olympian)"
	g.input_slot = 2
	g.archetype = "High-Speed Rushdown / Parry & Flash-Step Striker"
	g.signature_weapon = "Twin Olympic Blades & Aegis Cestus"
	g.glb_path = "res://assets/characters/ir.glb"
	g.primary_color = Color("#FFE066")
	g.secondary_color = Color("#FFFFFF")
	g.accent_color = Color("#2E5EAA")
	g.move_speed = 7.4
	g.attack_speed_mult = 1.30
	g.damage_mult = 0.90
	g.heavy_poise_armor = false
	g.morph_sfx = "morph_ir"

	_add_common_normals(g, "hit_blade", PackedStringArray(["weapon_socket.L", "weapon_socket.R"]), 1.25)

	g.moves[&"air_dive_or_slam"] = _mk_move({
		"move_id": &"air_dive_or_slam", "display_name": "Olympic Cross-Slash", "anim_name": &"air_dive_or_slam",
		"startup_frames": 4, "active_frames": 10, "recovery_frames": 9, "cancel_window_start": 10,
		"damage": 64.0, "armor_damage": 35.0, "meter_gain": 8.0, "hitstop_frames": 4,
		"dive_velocity": Vector3(8.5, -11.5, 0.0), "knockback_vel": Vector3(4.2, 4.0, 0.0),
		"active_sockets": PackedStringArray(["weapon_socket.L", "weapon_socket.R"]),
		"hitbox_extents": Vector3(1.6, 1.3, 1.3), "sfx_hit": "hit_blade", "spark_scale": 1.3,
	})
	# Special 1: Flash-Step Flurry (Teleporting cross-through multi-blade rush)
	g.moves[&"pantheon_special_1"] = _mk_move({
		"move_id": &"pantheon_special_1", "display_name": "Flash-Step Flurry", "anim_name": &"pantheon_special_1",
		"startup_frames": 4, "active_frames": 14, "recovery_frames": 9, "cancel_window_start": 14,
		"damage": 112.0, "armor_damage": 55.0, "meter_cost": 25.0, "meter_gain": 0.0, "hitstop_frames": 5,
		"forward_lunge_speed": 15.5, "teleport_cross_through": true,
		"knockback_vel": Vector3(3.2, 6.2, 0.0), "launches_airborne": true,
		"aoe_corridor_box": Vector3(4.2, 1.9, 2.4), "sfx_hit": "hit_blade", "spark_scale": 1.5,
	})
	# Special 2: Aegis Riposte (Instant counter-stance + lightning stun burst)
	g.moves[&"pantheon_special_2"] = _mk_move({
		"move_id": &"pantheon_special_2", "display_name": "Aegis Riposte", "anim_name": &"pantheon_special_2",
		"startup_frames": 2, "active_frames": 16, "recovery_frames": 9, "cancel_window_start": 12,
		"damage": 115.0, "armor_damage": 100.0, "meter_cost": 25.0, "meter_gain": 0.0, "hitstop_frames": 6,
		"counter_stance": true, "crumples_block": true,
		"knockback_vel": Vector3(5.0, 7.2, 0.0), "launches_airborne": true,
		"aoe_corridor_box": Vector3(3.8, 2.1, 3.6), "sfx_hit": "parry_clang", "spark_scale": 1.65,
	})
	# Super: Wrath of Olympus (Blinding prism barrage of light spears pinning foes)
	g.moves[&"pantheon_super"] = _mk_move({
		"move_id": &"pantheon_super", "display_name": "Wrath of Olympus", "anim_name": &"pantheon_super",
		"startup_frames": 8, "active_frames": 18, "recovery_frames": 12, "cancel_window_start": 20,
		"damage": 225.0, "armor_damage": 140.0, "meter_cost": 100.0, "meter_gain": 0.0, "hitstop_frames": 6,
		"knockback_vel": Vector3(2.0, 8.2, 0.0), "launches_airborne": true, "unblockable": true, "hyper_armor": true,
		"aoe_corridor_box": Vector3(14.0, 3.8, 6.4), "sfx_hit": "hit_blade", "spark_scale": 2.0,
	})
	return g


static func _build_osiris() -> GodProfile:
	var g := GodProfile.new()
	g.id = "osiris"
	g.display_name = "Osiris"
	g.pantheon = "Egyptian (Underworld / Duat)"
	g.input_slot = 3
	g.archetype = "Mid-Range Crowd Controller / Soul-Binder & Sustain"
	g.signature_weapon = "Spectral Crook & Flail"
	g.glb_path = "res://assets/characters/osiris.glb"
	g.primary_color = Color("#2CE8A2")
	g.secondary_color = Color("#6C3483")
	g.accent_color = Color("#D4AC0D")
	g.move_speed = 5.8
	g.attack_speed_mult = 1.00
	g.damage_mult = 1.05
	g.heavy_poise_armor = false
	g.morph_sfx = "morph_osiris"

	_add_common_normals(g, "hit_flail", PackedStringArray(["weapon_socket.R", "weapon_socket.L"]), 1.65)

	g.moves[&"air_dive_or_slam"] = _mk_move({
		"move_id": &"air_dive_or_slam", "display_name": "Duat Pendulum Sweep", "anim_name": &"air_dive_or_slam",
		"startup_frames": 5, "active_frames": 10, "recovery_frames": 10, "cancel_window_start": 11,
		"damage": 68.0, "armor_damage": 42.0, "meter_gain": 8.0, "hitstop_frames": 5,
		"dive_velocity": Vector3(3.5, -13.0, 0.0), "knockback_vel": Vector3(-2.5, 5.0, 0.0),
		"pulls_z_corridor": true,
		"aoe_corridor_box": Vector3(3.8, 1.8, 4.2), "sfx_hit": "hit_flail", "spark_scale": 1.35,
	})
	# Special 1: Crook Vortex (Extended hook sweep pulling scattered Z-lane enemies into tight front cluster)
	g.moves[&"pantheon_special_1"] = _mk_move({
		"move_id": &"pantheon_special_1", "display_name": "Crook Vortex", "anim_name": &"pantheon_special_1",
		"startup_frames": 6, "active_frames": 12, "recovery_frames": 10, "cancel_window_start": 13,
		"damage": 88.0, "armor_damage": 60.0, "meter_cost": 25.0, "meter_gain": 0.0, "hitstop_frames": 5,
		"pulls_z_corridor": true, "knockback_vel": Vector3(-3.8, 3.6, 0.0),
		"aoe_corridor_box": Vector3(6.8, 2.2, 6.4), "sfx_hit": "hit_flail", "spark_scale": 1.5,
	})
	# Special 2: Soul Harvest (Spectral flail spin leeching HP directly into Shared HP Pool)
	g.moves[&"pantheon_special_2"] = _mk_move({
		"move_id": &"pantheon_special_2", "display_name": "Soul Harvest", "anim_name": &"pantheon_special_2",
		"startup_frames": 6, "active_frames": 14, "recovery_frames": 11, "cancel_window_start": 15,
		"damage": 94.0, "armor_damage": 52.0, "meter_cost": 25.0, "meter_gain": 0.0, "hitstop_frames": 5,
		"leeches_hp_ratio": 0.42, "knockback_vel": Vector3(3.6, 4.5, 0.0),
		"aoe_corridor_box": Vector3(4.6, 2.2, 4.8), "sfx_hit": "hit_flail", "spark_scale": 1.55,
	})
	# Super: Scales of Ma'at (Underworld obelisks & spectral hands rooting all enemies on screen + leech)
	g.moves[&"pantheon_super"] = _mk_move({
		"move_id": &"pantheon_super", "display_name": "Scales of Ma'at", "anim_name": &"pantheon_super",
		"startup_frames": 9, "active_frames": 18, "recovery_frames": 13, "cancel_window_start": 21,
		"damage": 215.0, "armor_damage": 150.0, "meter_cost": 100.0, "meter_gain": 0.0, "hitstop_frames": 7,
		"pulls_z_corridor": true, "leeches_hp_ratio": 0.25, "unblockable": true, "hyper_armor": true,
		"knockback_vel": Vector3(0.5, 7.5, 0.0), "launches_airborne": true,
		"aoe_corridor_box": Vector3(16.5, 4.2, 6.8), "sfx_hit": "hit_flail", "spark_scale": 2.0,
	})
	return g


static func _build_horus() -> GodProfile:
	var g := GodProfile.new()
	g.id = "horus"
	g.display_name = "Horus"
	g.pantheon = "Egyptian (Sky & Sun)"
	g.input_slot = 4
	g.archetype = "Aerial Juggler / Dive-Kick & Solar Lance Specialist"
	g.signature_weapon = "Winged Solar Spear & Falcon Talons"
	g.glb_path = "res://assets/characters/horus.glb"
	g.primary_color = Color("#FF7A00")
	g.secondary_color = Color("#FFD700")
	g.accent_color = Color("#8E1600")
	g.move_speed = 6.8
	g.attack_speed_mult = 1.15
	g.damage_mult = 1.00
	g.jump_velocity = 11.6
	g.max_air_jumps = 1
	g.has_air_hover = true
	g.heavy_poise_armor = false
	g.morph_sfx = "morph_horus"

	_add_common_normals(g, "hit_solar", PackedStringArray(["weapon_socket.R", "foot.R"]), 1.75)

	# Steep 45-deg Falcon Talon dive-kick on air_dive_or_slam as well
	g.moves[&"air_dive_or_slam"] = _mk_move({
		"move_id": &"air_dive_or_slam", "display_name": "Solar Talon Dive", "anim_name": &"air_dive_or_slam",
		"startup_frames": 4, "active_frames": 14, "recovery_frames": 8, "cancel_window_start": 10,
		"damage": 74.0, "armor_damage": 50.0, "meter_gain": 9.0, "hitstop_frames": 5,
		"dive_velocity": Vector3(11.0, -11.5, 0.0), "knockback_vel": Vector3(3.8, 7.6, 0.0),
		"ground_bounces": true, "launches_airborne": true,
		"aoe_corridor_box": Vector3(2.8, 1.8, 2.4), "sfx_hit": "hit_solar", "spark_scale": 1.45,
	})
	# Special 1: Skyward Ascent (Rising winged-spear launcher lifting Horus & targets into extended air-combo)
	g.moves[&"pantheon_special_1"] = _mk_move({
		"move_id": &"pantheon_special_1", "display_name": "Skyward Ascent", "anim_name": &"pantheon_special_1",
		"startup_frames": 5, "active_frames": 12, "recovery_frames": 10, "cancel_window_start": 11,
		"damage": 96.0, "armor_damage": 65.0, "meter_cost": 25.0, "meter_gain": 0.0, "hitstop_frames": 6,
		"dive_velocity": Vector3(4.2, 11.2, 0.0), "knockback_vel": Vector3(2.6, 11.4, 0.0),
		"launches_airborne": true,
		"aoe_corridor_box": Vector3(3.8, 3.2, 3.0), "sfx_hit": "hit_solar", "spark_scale": 1.55,
	})
	# Special 2: Falcon Meteor Dive (Blazing 45-deg talon dive-kick ground-bouncing enemies for Endor/Osiris)
	g.moves[&"pantheon_special_2"] = _mk_move({
		"move_id": &"pantheon_special_2", "display_name": "Falcon Meteor Dive", "anim_name": &"pantheon_special_2",
		"startup_frames": 5, "active_frames": 14, "recovery_frames": 9, "cancel_window_start": 12,
		"damage": 108.0, "armor_damage": 75.0, "meter_cost": 25.0, "meter_gain": 0.0, "hitstop_frames": 6,
		"dive_velocity": Vector3(13.0, -13.0, 0.0), "knockback_vel": Vector3(4.5, 8.8, 0.0),
		"ground_bounces": true, "launches_airborne": true,
		"aoe_corridor_box": Vector3(3.6, 2.2, 3.2), "sfx_hit": "hit_solar", "spark_scale": 1.65,
	})
	# Super: Eye of Ra-Horakhty (Hovering mid-air solar beam sweep scorching the entire street lane)
	g.moves[&"pantheon_super"] = _mk_move({
		"move_id": &"pantheon_super", "display_name": "Eye of Ra-Horakhty", "anim_name": &"pantheon_super",
		"startup_frames": 8, "active_frames": 18, "recovery_frames": 12, "cancel_window_start": 20,
		"damage": 235.0, "armor_damage": 165.0, "meter_cost": 100.0, "meter_gain": 0.0, "hitstop_frames": 7,
		"dive_velocity": Vector3(0.0, 3.5, 0.0), "knockback_vel": Vector3(7.5, 8.5, 0.0),
		"launches_airborne": true, "unblockable": true, "hyper_armor": true,
		"aoe_corridor_box": Vector3(16.0, 4.0, 6.4), "sfx_hit": "hit_solar", "spark_scale": 2.05,
	})
	return g
