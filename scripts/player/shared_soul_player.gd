class_name SharedSoulPlayer
extends CharacterBody3D
## 2.5D Belt-Scroller Fighting-Game Player Controller with Zero-Cooldown Shared-Soul Morphing
## across Endor, Ir, Osiris, and Horus.

signal hp_changed(current_hp: float, max_hp: float)
signal meter_changed(current_meter: float, max_meter: float)
signal god_morphed(slot_index: int, profile: GodProfile)
signal player_ko
signal parry_triggered(world_pos: Vector3)
signal special_cast(move_title: String, color: Color)

const MAX_SHARED_HP := 1000.0
const MAX_PANTHEON_METER := 100.0
const CORRIDOR_Z_MIN := -3.2
const CORRIDOR_Z_MAX := 3.2
const GRAVITY := 28.0
const PERFECT_PARRY_WINDOW_FRAMES := 8

const SOCKET_BONES := [
	"hand.L",
	"hand.R",
	"foot.L",
	"foot.R",
	"weapon_socket.L",
	"weapon_socket.R",
]

var roster: Array[GodProfile] = []
var active_slot: int = 0
var shared_hp: float = MAX_SHARED_HP
var pantheon_meter: float = 50.0 # Start with 2 special bars ready for instant fun!
var facing_sign: float = 1.0
var hitstun_immunity_frames: int = 0
var invuln_timer: float = 0.0
var hitstun_timer: float = 0.0
var block_held_frames: int = 0
var is_blocking: bool = false
var air_jumps_used: int = 0
var surface_friction_scale: float = 1.0 # Modified by Moscow ice slicks in M2

var arena_x_min: float = -10000.0
var arena_x_max: float = 10000.0

var resonance: ResonanceTracker = ResonanceTracker.new()

var _visual_pivot: Node3D
var _hurtbox: HurtBox3D
var _aoe_hitbox: HitBox3D
var _god_rigs: Array[Dictionary] = [] # [{root, skeleton, anim, sockets: {bname -> HitBox3D}}]

var _current_attack: AttackData = null
var _attack_frame_cursor: float = 0.0
var _attack_hit_registry: Dictionary = {}
var _queued_chain_move: StringName = &""
var _air_combo_step: int = 0
var _is_dead: bool = false


func _ready() -> void:
	add_to_group("player")
	collision_layer = (1 << 1) # Layer 2: PlayerBody
	collision_mask = (1 << 0)  # Layer 1: WorldBounds

	var body_col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.36
	cap.height = 1.80
	body_col.shape = cap
	body_col.position = Vector3(0.0, 0.90, 0.0)
	add_child(body_col)

	_visual_pivot = Node3D.new()
	_visual_pivot.name = "VisualPivot"
	add_child(_visual_pivot)

	_hurtbox = HurtBox3D.new()
	_hurtbox.name = "PlayerHurtBox"
	add_child(_hurtbox)
	_hurtbox.setup(self, true, Vector3(0.76, 1.78, 0.78), 0.90)

	_aoe_hitbox = HitBox3D.new()
	_aoe_hitbox.name = "AoeHitBox"
	_aoe_hitbox.attacker = self
	_aoe_hitbox.configure_team_layers(true)
	_aoe_hitbox.strike_landed.connect(_on_strike_landed)
	add_child(_aoe_hitbox)

	roster = GodRosterCatalog.build_roster()
	_preload_all_4_god_rigs()

	var initial_slot := GameManager.starting_god_slot if GameManager else 0
	_activate_slot_visuals(clampi(initial_slot, 0, 3), false)
	_update_facing_visual()
	hp_changed.emit(shared_hp, MAX_SHARED_HP)
	meter_changed.emit(pantheon_meter, MAX_PANTHEON_METER)


func _preload_all_4_god_rigs() -> void:
	_god_rigs.clear()
	for idx in range(roster.size()):
		var prof := roster[idx]
		var rig_root := GlbLoader.instantiate_glb(prof.glb_path)
		rig_root.name = "Rig_%s" % prof.id
		rig_root.visible = (idx == 0)
		_visual_pivot.add_child(rig_root)

		var skel := GlbLoader.find_skeleton(rig_root)
		var anim := GlbLoader.find_anim_player(rig_root)
		var fx_mat := FighterShaderHelper.attach_surface_fx(rig_root, prof.primary_color, 0.92, 0.0)
		var sockets: Dictionary = {}

		if skel:
			for bname in SOCKET_BONES:
				var b_idx := skel.find_bone(bname)
				if b_idx >= 0:
					var attach := BoneAttachment3D.new()
					attach.bone_name = bname
					skel.add_child(attach)
					var hb := HitBox3D.new()
					hb.attacker = self
					hb.configure_team_layers(true)
					hb.strike_landed.connect(_on_strike_landed)
					attach.add_child(hb)
					sockets[bname] = hb

		_god_rigs.append({
			"root": rig_root,
			"skeleton": skel,
			"anim": anim,
			"sockets": sockets,
			"fx_mat": fx_mat,
		})


func active_god() -> GodProfile:
	return roster[active_slot]


func set_arena_x_bounds(min_x: float, max_x: float) -> void:
	arena_x_min = min_x
	arena_x_max = max_x


func revive_full_soul() -> void:
	_is_dead = false
	shared_hp = MAX_SHARED_HP
	pantheon_meter = maxf(pantheon_meter, 50.0)
	invuln_timer = 2.2
	hitstun_timer = 0.0
	_cancel_active_attack()
	_play_anim(&"morph_entry_pose", 1.2)
	if HitstopManager:
		HitstopManager.spawn_morph_flash(global_position, active_god().primary_color)
	hp_changed.emit(shared_hp, MAX_SHARED_HP)
	meter_changed.emit(pantheon_meter, MAX_PANTHEON_METER)


func heal_shared_hp(amount: float) -> void:
	if _is_dead or amount <= 0.0:
		return
	shared_hp = minf(MAX_SHARED_HP, shared_hp + amount)
	hp_changed.emit(shared_hp, MAX_SHARED_HP)


func add_pantheon_meter(amount: float) -> void:
	if amount == 0.0:
		return
	pantheon_meter = clampf(pantheon_meter + amount, 0.0, MAX_PANTHEON_METER)
	meter_changed.emit(pantheon_meter, MAX_PANTHEON_METER)


func morph_to_slot(target_slot: int) -> bool:
	target_slot = posmod(target_slot, roster.size())
	if _is_dead or target_slot == active_slot:
		return false

	# Zero-cooldown Shared-Soul Morph: snapshot state explicitly per specs.yml
	var preserved_vel := velocity
	var preserved_facing := facing_sign
	var preserved_combo := resonance.combo_count

	_deactivate_all_hitboxes()
	_current_attack = null
	_queued_chain_move = &""
	hitstun_immunity_frames = 2

	_activate_slot_visuals(target_slot, true)

	velocity = preserved_vel
	facing_sign = preserved_facing
	resonance.combo_count = preserved_combo
	_update_facing_visual()

	var prof := active_god()
	var fx_mat: ShaderMaterial = _god_rigs[active_slot].get("fx_mat", null)
	FighterShaderHelper.trigger_hit_flash(self, fx_mat, prof.primary_color, 0.12)
	if PostFxManager:
		PostFxManager.trigger_morph_glitch(prof.primary_color, 0.58, 0.18)
	if HitstopManager:
		HitstopManager.spawn_morph_flash(global_position, prof.primary_color)
	if SfxManager:
		SfxManager.play_2d(prof.morph_sfx, -2.0, 0.04)
	god_morphed.emit(active_slot, prof)
	return true


func _activate_slot_visuals(slot_idx: int, play_entry_pose: bool) -> void:
	active_slot = slot_idx
	for i in range(_god_rigs.size()):
		var rig: Dictionary = _god_rigs[i]
		var rnode := rig["root"] as Node3D
		rnode.visible = (i == slot_idx)
	if play_entry_pose:
		if is_on_floor():
			_play_anim(&"morph_entry_pose", 1.35)
		else:
			_play_anim(&"jump_air_loop", 1.15)
	else:
		_play_anim(&"idle_fight_stance", 1.0)


func _physics_process(delta: float) -> void:
	if _is_dead:
		velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 18.0 * delta)
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		move_and_slide()
		_clamp_corridor()
		return

	var frozen := HitstopManager != null and HitstopManager.is_frozen()
	resonance.tick(delta, frozen or _current_attack != null)
	if invuln_timer > 0.0:
		invuln_timer = maxf(0.0, invuln_timer - delta)

	# Instant Zero-Cooldown Morph inputs are ALWAYS responsive (even during hitstop or mid-combo!)
	_poll_morph_inputs()

	if frozen:
		return

	if hitstun_immunity_frames > 0:
		hitstun_immunity_frames -= 1

	if is_on_floor():
		air_jumps_used = 0
		_air_combo_step = 0

	if hitstun_timer > 0.0:
		hitstun_timer -= delta
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		velocity.x = move_toward(velocity.x, 0.0, 14.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 14.0 * delta)
		move_and_slide()
		_clamp_corridor()
		return

	_handle_combat_and_locomotion(delta)
	move_and_slide()
	_clamp_corridor()


func _poll_morph_inputs() -> void:
	if Input.is_action_just_pressed("morph_1"):
		morph_to_slot(0)
	elif Input.is_action_just_pressed("morph_2"):
		morph_to_slot(1)
	elif Input.is_action_just_pressed("morph_3"):
		morph_to_slot(2)
	elif Input.is_action_just_pressed("morph_4"):
		morph_to_slot(3)
	elif Input.is_action_just_pressed("morph_next"):
		morph_to_slot(active_slot + 1)
	elif Input.is_action_just_pressed("morph_prev"):
		morph_to_slot(active_slot - 1)


func _handle_combat_and_locomotion(delta: float) -> void:
	var prof := active_god()
	var move_vec := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	# Update horizontal facing before actions so attacks and jumps turn toward input direction
	if absf(move_vec.x) > 0.12:
		facing_sign = 1.0 if move_vec.x > 0.0 else -1.0
		_update_facing_visual()

	# Block / Parry handling (grounded & not currently mid-swing)
	if _current_attack == null and is_on_floor() and Input.is_action_pressed("block_parry"):
		is_blocking = true
		block_held_frames += 1
		velocity.x = move_toward(velocity.x, 0.0, 26.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 26.0 * delta)
		_play_anim(&"block_high", 1.0)
		return
	else:
		is_blocking = false
		block_held_frames = 0

	# Active attack state machine
	if _current_attack != null:
		_tick_active_attack(delta, move_vec)
		return

	# Check new combat inputs
	if _try_trigger_attack_inputs(move_vec):
		return

	# Jump & Horus Double Jump
	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			velocity.y = prof.jump_velocity
			_play_anim(&"jump_start", 1.2)
		elif air_jumps_used < prof.max_air_jumps:
			air_jumps_used += 1
			velocity.y = prof.jump_velocity * 0.92
			if HitstopManager:
				HitstopManager.spawn_shockwave_ring(global_position, prof.primary_color, 1.2, 0.18)
			_play_anim(&"jump_start", 1.35)

	# Horizontal X & Corridor Z locomotion
	var target_vx := move_vec.x * prof.move_speed
	var target_vz := move_vec.y * (prof.move_speed * 0.74)
	var accel := 42.0 * surface_friction_scale if is_on_floor() else 22.0
	velocity.x = move_toward(velocity.x, target_vx, accel * delta)
	velocity.z = move_toward(velocity.z, target_vz, accel * delta)

	if not is_on_floor():
		var grav_mult := 1.0
		if prof.has_air_hover and Input.is_action_pressed("jump") and velocity.y < 0.0:
			grav_mult = 0.24 # Horus Air-Hover cancel!
		velocity.y -= GRAVITY * grav_mult * delta
		_play_anim(&"jump_air_loop", 1.0)
	else:
		if move_vec.length_squared() > 0.04:
			_play_anim(&"run_dash" if prof.move_speed >= 6.5 else &"walk_forward", 1.15)
		else:
			_play_anim(&"idle_fight_stance", 1.0)


func _try_trigger_attack_inputs(move_vec: Vector2) -> bool:
	if Input.is_action_just_pressed("attack_super") and pantheon_meter >= 100.0:
		start_attack(&"pantheon_super")
		return true
	if Input.is_action_just_pressed("attack_special") and pantheon_meter >= 25.0:
		var forward_or_down := (absf(move_vec.x) > 0.35) or (move_vec.y > 0.35)
		start_attack(&"pantheon_special_2" if forward_or_down else &"pantheon_special_1")
		return true
	if Input.is_action_just_pressed("attack_heavy"):
		if not is_on_floor():
			start_attack(&"air_dive_or_slam")
		elif move_vec.y < -0.35:
			start_attack(&"launcher_up")
		else:
			start_attack(&"heavy_ground")
		return true
	return false


func start_attack(move_key: StringName) -> bool:
	var prof := active_god()
	if not prof.moves.has(move_key):
		return false
	var move: AttackData = prof.moves[move_key]
	if move.meter_cost > 0.0:
		if pantheon_meter < move.meter_cost:
			return false
		add_pantheon_meter(-move.meter_cost)

	_deactivate_all_hitboxes()
	_current_attack = move
	_attack_frame_cursor = 0.0
	_queued_chain_move = &""
	_attack_hit_registry.clear()

	# Specials & Supers emit dramatic feedback
	if move.meter_cost >= 100.0:
		invuln_timer = maxf(invuln_timer, 0.75)
		var fx_mat: ShaderMaterial = _god_rigs[active_slot].get("fx_mat", null)
		FighterShaderHelper.trigger_hit_flash(self, fx_mat, Color("#FFFFFF"), 0.22)
		if PostFxManager:
			PostFxManager.trigger_parry_or_super_impact(global_position + Vector3(0.0, 1.0, 0.0), prof.primary_color, true)
		if SfxManager:
			SfxManager.play_2d("super_flash", 0.0, 0.0)
		if HitstopManager:
			HitstopManager.trigger_hitstop(5, 0.45)
			HitstopManager.spawn_morph_flash(global_position, prof.primary_color)
			if prof.id == "endor":
				for dx in [-4.5, -1.8, 1.8, 4.5]:
					HitstopManager.spawn_lightning_pillar(global_position + Vector3(dx, 0.0, 0.0), prof.primary_color)
			else:
				HitstopManager.spawn_shockwave_ring(global_position, prof.primary_color, 7.5, 0.42)
		special_cast.emit(move.display_name, prof.primary_color)
	elif move.meter_cost > 0.0:
		special_cast.emit(move.display_name, prof.primary_color)

	if move.dive_velocity.length_squared() > 0.01:
		velocity.x = move.dive_velocity.x * facing_sign
		velocity.y = move.dive_velocity.y
	elif move.forward_lunge_speed > 0.0:
		velocity.x = move.forward_lunge_speed * facing_sign
		if not is_on_floor():
			velocity.y = maxf(velocity.y, 2.8) # Aerial juggle hang boost!

	if move.teleport_cross_through:
		# Ir Flash-Step teleports cleanly across enemies while staying inside corridor bounds
		global_position.x = clampf(global_position.x + facing_sign * 2.8, arena_x_min + 0.6, arena_x_max - 0.6)
		if HitstopManager:
			HitstopManager.spawn_morph_flash(global_position, prof.primary_color)

	_play_anim(move.anim_name, prof.attack_speed_mult * 1.15)
	return true


func _tick_active_attack(delta: float, move_vec: Vector2) -> void:
	var prof := active_god()
	var move := _current_attack
	_attack_frame_cursor += delta * 60.0 * prof.attack_speed_mult

	# Buffer next chain input during attack
	if _attack_frame_cursor >= float(move.cancel_window_start) * 0.65:
		if Input.is_action_just_pressed("attack_super") and pantheon_meter >= 100.0:
			_queued_chain_move = &"pantheon_super"
		elif Input.is_action_just_pressed("attack_special") and pantheon_meter >= 25.0:
			var fwd := (absf(move_vec.x) > 0.35) or (move_vec.y > 0.35)
			_queued_chain_move = &"pantheon_special_2" if fwd else &"pantheon_special_1"
		elif Input.is_action_just_pressed("attack_heavy"):
			if not is_on_floor():
				_queued_chain_move = &"air_dive_or_slam"
			elif move_vec.y < -0.35:
				_queued_chain_move = &"launcher_up"
			else:
				_queued_chain_move = &"heavy_ground"

	var in_active := _attack_frame_cursor >= float(move.startup_frames) and _attack_frame_cursor < float(move.startup_frames + move.active_frames)
	if in_active:
		_enable_move_hitboxes(move)
	else:
		_deactivate_all_hitboxes()

	# Execute buffered chain once inside cancel window
	if _queued_chain_move != &"" and _attack_frame_cursor >= float(move.cancel_window_start):
		var next_m := _queued_chain_move
		_queued_chain_move = &""
		start_attack(next_m)
		return

	# Movement physics during attack
	if move.dive_velocity.length_squared() > 0.01:
		if is_on_floor() and move.dive_velocity.y < 0.0 and _attack_frame_cursor > float(move.startup_frames + 2):
			velocity.x = move_toward(velocity.x, 0.0, 28.0 * delta)
			if HitstopManager:
				HitstopManager.spawn_shockwave_ring(global_position, prof.primary_color, 2.5, 0.22)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
		velocity.z = move_toward(velocity.z, move_vec.y * 2.2, 16.0 * delta)
		if not is_on_floor():
			velocity.y -= GRAVITY * 0.52 * delta

	if _attack_frame_cursor >= float(move.total_frames()):
		_cancel_active_attack()


func _enable_move_hitboxes(move: AttackData) -> void:
	var prof := active_god()
	if move.aoe_corridor_box.length_squared() > 0.01:
		var offset_x := facing_sign * (move.aoe_corridor_box.x * 0.35) if move.aoe_corridor_box.x < 10.0 else 0.0
		_aoe_hitbox.position = Vector3(offset_x, move.aoe_corridor_box.y * 0.5, 0.0)
		if not _aoe_hitbox.monitoring:
			_aoe_hitbox.activate(move, prof.damage_mult, facing_sign, prof.primary_color, _attack_hit_registry)
			if HitstopManager and move.aoe_corridor_box.x < 10.0:
				HitstopManager.spawn_shockwave_ring(global_position + Vector3(offset_x, 0.0, 0.0), prof.primary_color, move.aoe_corridor_box.x * 0.45, 0.22)
		return

	var rig: Dictionary = _god_rigs[active_slot]
	var sockets: Dictionary = rig["sockets"]
	for sname in move.active_sockets:
		if sockets.has(sname):
			var hb := sockets[sname] as HitBox3D
			if not hb.monitoring:
				hb.activate(move, prof.damage_mult, facing_sign, prof.primary_color, _attack_hit_registry)


func _deactivate_all_hitboxes() -> void:
	if _aoe_hitbox:
		_aoe_hitbox.deactivate()
	for rig in _god_rigs:
		var sockets: Dictionary = rig["sockets"]
		for hb in sockets.values():
			(hb as HitBox3D).deactivate()


func _cancel_active_attack() -> void:
	_deactivate_all_hitboxes()
	_current_attack = null
	_queued_chain_move = &""


func _on_strike_landed(target_owner: Node, hit_result: Dictionary) -> void:
	if _current_attack == null:
		return
	var dealt := float(hit_result.get("damage_dealt", _current_attack.damage))
	var hit_pos: Vector3 = hit_result.get("hit_position", target_owner.global_position + Vector3(0, 1, 0) if target_owner is Node3D else global_position)
	var is_prop := (target_owner is DestructibleProp) or bool(hit_result.get("is_prop", false))
	var is_ko := bool(hit_result.get("ko", false)) or (is_prop and bool(hit_result.get("destroyed", false)))
	_register_successful_player_hit(_current_attack, hit_pos, dealt, is_prop, is_ko)

	# Osiris Crook Vortex Z-Corridor Pull
	if _current_attack.pulls_z_corridor and target_owner is Node3D and not is_prop:
		var t3 := target_owner as Node3D
		var cluster_pos := global_position + Vector3(facing_sign * 1.65, t3.global_position.y - global_position.y, 0.0)
		t3.global_position.z = lerpf(t3.global_position.z, global_position.z, 0.82)
		t3.global_position.x = lerpf(t3.global_position.x, cluster_pos.x, 0.55)


func _register_successful_player_hit(move: AttackData, hit_pos: Vector3, dealt_damage: float, is_prop: bool = false, is_ko: bool = false) -> void:
	var prof := active_god()
	var res_info := resonance.register_hit(prof.id)
	var meter_mult := float(res_info.get("meter_multiplier", 1.0))
	if move.meter_gain > 0.0:
		add_pantheon_meter(move.meter_gain * meter_mult)
	if move.leeches_hp_ratio > 0.0 and dealt_damage > 0.0:
		heal_shared_hp(dealt_damage * move.leeches_hp_ratio)

	if GameManager and not is_prop:
		GameManager.add_score(int(res_info.get("hit_score_bonus", 50)))
		GameManager.record_combo_stats(
			int(res_info.get("combo_count", 1)),
			int(res_info.get("variety_count", 1)),
			String(res_info.get("rank", "D"))
		)

	if HitstopManager:
		var hitstop_f := move.hitstop_frames
		var shake_trauma := 0.16 * move.spark_scale
		if is_prop:
			hitstop_f = 0
			shake_trauma = 0.08
		elif is_ko:
			hitstop_f = 2

		if hitstop_f > 0 or shake_trauma > 0.0:
			HitstopManager.trigger_hitstop(hitstop_f, shake_trauma)
		HitstopManager.spawn_hit_spark(hit_pos, prof.primary_color, move.spark_scale)
	if SfxManager:
		SfxManager.play_3d(move.sfx_hit, hit_pos, 0.0, 0.07)


func receive_hit(payload: Dictionary) -> Dictionary:
	if _is_dead or invuln_timer > 0.0:
		return {"connected": false}

	var move: AttackData = payload.get("attack_data", null)
	var raw_dmg := float(payload.get("raw_damage", 35.0))
	var attacker: Node = payload.get("attacker", null)
	var unblockable := move != null and move.unblockable

	# Ir Aegis Riposte Counter-Stance OR Frame-Tight Perfect Parry!
	var in_counter_stance := _current_attack != null and _current_attack.counter_stance
	var in_perfect_parry := is_blocking and block_held_frames <= PERFECT_PARRY_WINDOW_FRAMES and not unblockable
	if in_counter_stance or in_perfect_parry:
		invuln_timer = 0.45
		add_pantheon_meter(20.0)
		var p_fx_mat: ShaderMaterial = _god_rigs[active_slot].get("fx_mat", null)
		FighterShaderHelper.trigger_hit_flash(self, p_fx_mat, Color("#FFE066"), 0.16)
		if PostFxManager:
			PostFxManager.trigger_parry_or_super_impact(global_position + Vector3(0.0, 1.1, 0.0), Color("#FFE066"), false)
		if SfxManager:
			SfxManager.play_2d("parry_clang", 1.5, 0.02)
		if HitstopManager:
			HitstopManager.trigger_slow_mo(0.28, 0.30, false)
			HitstopManager.spawn_morph_flash(global_position, Color("#FFE066"))
		if attacker and attacker.has_method("on_parried"):
			attacker.on_parried(75.0)
		parry_triggered.emit(global_position + Vector3(0.0, 1.1, 0.0))
		return {"connected": false, "parried": true}

	# Standard Block
	if is_blocking and not unblockable:
		var chip := raw_dmg * 0.18
		shared_hp = maxf(1.0, shared_hp - chip)
		velocity.x = -facing_sign * 3.5
		if SfxManager:
			SfxManager.play_3d("block_thud", global_position, -1.0, 0.05)
		if HitstopManager:
			HitstopManager.spawn_hit_spark(global_position + Vector3(facing_sign * 0.4, 1.1, 0.0), Color("#C8D6E5"), 0.75)
		hp_changed.emit(shared_hp, MAX_SHARED_HP)
		return {"connected": true, "blocked": true, "damage_dealt": chip}

	# Full Damage Application
	shared_hp = maxf(0.0, shared_hp - raw_dmg)
	if GameManager:
		GameManager.record_player_damage(raw_dmg)
	hp_changed.emit(shared_hp, MAX_SHARED_HP)

	if SfxManager:
		SfxManager.play_3d("hit_heavy", global_position, 0.0, 0.06)
	var hit_fx_mat: ShaderMaterial = _god_rigs[active_slot].get("fx_mat", null)
	FighterShaderHelper.trigger_hit_flash(self, hit_fx_mat, Color("#FF1E42"), 0.13)
	if HitstopManager:
		HitstopManager.trigger_hitstop(4, 0.30)
		HitstopManager.spawn_hit_spark(global_position + Vector3(0.0, 1.0, 0.0), Color("#FF1E42"), 1.2)

	if shared_hp <= 0.0:
		_is_dead = true
		_cancel_active_attack()
		resonance.reset()
		_play_anim(&"knockdown_getup", 0.65)
		player_ko.emit()
		return {"connected": true, "damage_dealt": raw_dmg, "ko": true}

	# Check hyper-armor or morph 2-frame hitstun immunity
	var has_poise := (_current_attack != null and _current_attack.hyper_armor) or hitstun_immunity_frames > 0
	if not has_poise:
		_cancel_active_attack()
		hitstun_timer = 0.24
		var push_dir := float(payload.get("facing_sign", -facing_sign))
		velocity.x = push_dir * 4.5
		_play_anim(&"hit_light", 1.15)

	return {"connected": true, "damage_dealt": raw_dmg}


func _update_facing_visual() -> void:
	if _visual_pivot:
		# glTF importer with Y-up maps Blender -Y (Front) to +Z.
		# Godot rotation around +Y: +PI/2 faces +X (Right), -PI/2 faces -X (Left).
		_visual_pivot.rotation.y = PI * 0.5 if facing_sign >= 0.0 else -PI * 0.5


func _play_anim(anim_name: StringName, speed: float = 1.0) -> void:
	if active_slot < 0 or active_slot >= _god_rigs.size():
		return
	var anim: AnimationPlayer = _god_rigs[active_slot]["anim"]
	if anim == null:
		return
	var resolved := anim_name
	if not anim.has_animation(resolved) and String(resolved).ends_with("_loop"):
		resolved = StringName(String(resolved).trim_suffix("_loop"))
	if not anim.has_animation(resolved):
		return
	if anim.current_animation != resolved:
		anim.play(resolved, 0.06, speed)
	else:
		anim.speed_scale = speed


func _clamp_corridor() -> void:
	global_position.z = clampf(global_position.z, CORRIDOR_Z_MIN, CORRIDOR_Z_MAX)
	global_position.x = clampf(global_position.x, arena_x_min, arena_x_max)
	if global_position.y < -4.0:
		global_position.y = 0.2
		velocity.y = 0.0
