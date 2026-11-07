class_name BossController
extends CharacterBody3D
## Fighting-Game Mythic Boss Opponent with Super-Armor thresholds, crimson ground telegraphs,
## 50% HP Enrage phase shifts, BoneAttachment3D hitboxes, and bespoke boss signature attacks.

signal boss_hp_updated(hp: float, max_hp: float, armor: float, max_armor: float)
signal boss_phase_shifted(boss_id: String, phase_num: int)
signal boss_defeated(boss_id: String, score_value: int, world_pos: Vector3)

const CORRIDOR_Z_MIN := -3.2
const CORRIDOR_Z_MAX := 3.2
const GRAVITY := 26.0

var boss_id: String = "chadzug"
var boss_name: String = "Chadzug"
var boss_title: String = "Tunnel King of the Under-Cobble"
var counter_hint: String = ""
var stage_num: int = 1
var is_mid_boss: bool = true
var max_hp: float = 1150.0
var hp: float = 1150.0
var max_armor: float = 140.0
var armor: float = 140.0
var move_speed: float = 5.4
var score_value: int = 6000
var accent_color: Color = Color("#FF1E42")
var facing_sign: float = -1.0
var phase: int = 1
var arena_x_min: float = -10000.0
var arena_x_max: float = 10000.0

var _visual_pivot: Node3D
var _rig_root: Node3D
var _anim: AnimationPlayer
var _hurtbox: HurtBox3D
var _aoe_hitbox: HitBox3D
var _socket_hitboxes: Array[HitBox3D] = []

var _state: StringName = &"intro"
var _state_timer: float = 0.0
var _decision_cooldown: float = 0.65
var _hit_registry: Dictionary = {}
var _current_move: AttackData = null
var _pattern_index: int = 0
var _burrowed: bool = false
var _is_dead: bool = false


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("bosses")
	collision_layer = (1 << 2)
	collision_mask = (1 << 0)

	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.42
	cap.height = 1.80
	col.shape = cap
	col.position = Vector3(0.0, 0.90, 0.0)
	add_child(col)

	_visual_pivot = Node3D.new()
	add_child(_visual_pivot)

	_hurtbox = HurtBox3D.new()
	add_child(_hurtbox)

	_aoe_hitbox = HitBox3D.new()
	_aoe_hitbox.attacker = self
	_aoe_hitbox.configure_team_layers(false)
	add_child(_aoe_hitbox)


func setup_boss(id: String, min_x: float, max_x: float) -> void:
	boss_id = id if BossRosterCatalog.BOSSES.has(id) else "chadzug"
	var cfg: Dictionary = BossRosterCatalog.BOSSES[boss_id]
	boss_name = String(cfg["name"])
	boss_title = String(cfg["title"])
	counter_hint = String(cfg.get("counter_hint", ""))
	stage_num = int(cfg["stage"])
	is_mid_boss = String(cfg["tier"]) == "Mid-Boss"
	max_hp = float(cfg["max_hp"])
	hp = max_hp
	max_armor = float(cfg["max_armor"])
	armor = max_armor
	move_speed = float(cfg["move_speed"])
	score_value = int(cfg["score"])
	accent_color = cfg["accent_color"]
	arena_x_min = min_x
	arena_x_max = max_x

	var glb_path := String(cfg["glb"])
	if not ResourceLoader.exists(glb_path) and not FileAccess.file_exists(ProjectSettings.globalize_path(glb_path)):
		glb_path = "res://assets/bosses/beebo.glb"
	_rig_root = GlbLoader.instantiate_glb(glb_path)
	_visual_pivot.add_child(_rig_root)
	_anim = GlbLoader.find_anim_player(_rig_root)

	var skel := GlbLoader.find_skeleton(_rig_root)
	_socket_hitboxes.clear()
	if skel:
		for bname in cfg.get("sockets", []):
			var b_idx := skel.find_bone(String(bname))
			if b_idx >= 0:
				var attach := BoneAttachment3D.new()
				attach.bone_name = String(bname)
				skel.add_child(attach)
				var hb := HitBox3D.new()
				hb.attacker = self
				hb.configure_team_layers(false)
				attach.add_child(hb)
				_socket_hitboxes.append(hb)

	var h_size: Vector3 = cfg["hurtbox_size"]
	_hurtbox.setup(self, false, h_size, h_size.y * 0.5)

	_update_facing_visual()
	_enter_state(&"intro")
	boss_hp_updated.emit(hp, max_hp, armor, max_armor)


func _enter_state(new_state: StringName) -> void:
	_state = new_state
	_state_timer = 0.0
	_deactivate_hitboxes()
	_hit_registry.clear()

	match new_state:
		&"intro":
			_play_anim(&"boss_intro_taunt", 1.0)
			if SfxManager:
				SfxManager.play_2d("boss_warning", -1.5, 0.02)
		&"phase_roar":
			armor = max_armor
			_play_anim(&"phase_2_roar", 1.1)
			if HitstopManager:
				HitstopManager.spawn_shockwave_ring(global_position, accent_color, 5.2, 0.42)
			if SfxManager:
				SfxManager.play_2d("armor_break", 0.5, 0.0)
			boss_hp_updated.emit(hp, max_hp, armor, max_armor)


func _physics_process(delta: float) -> void:
	if HitstopManager and HitstopManager.is_frozen():
		return
	if _is_dead:
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		velocity.x = move_toward(velocity.x, 0.0, 14.0 * delta)
		move_and_slide()
		return

	var speed_scale := 1.24 if phase >= 2 else 1.0
	_state_timer += delta * speed_scale

	match _state:
		&"intro":
			if _state_timer >= 0.85:
				_enter_state(&"pursue")
		&"phase_roar":
			if _state_timer >= 0.78:
				_enter_state(&"pursue")
		&"stunned":
			if not is_on_floor():
				velocity.y -= GRAVITY * 0.82 * delta
			else:
				velocity.x = move_toward(velocity.x, 0.0, 16.0 * delta)
				velocity.z = move_toward(velocity.z, 0.0, 16.0 * delta)
			if _state_timer >= 0.72:
				armor = max_armor
				boss_hp_updated.emit(hp, max_hp, armor, max_armor)
				_enter_state(&"pursue")
		&"pursue":
			_tick_pursue(delta, speed_scale)
		&"attack":
			_tick_signature_attack(delta, speed_scale)

	move_and_slide()
	_clamp_corridor()


func _tick_pursue(delta: float, speed_scale: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		_play_anim(&"idle_fight_stance")
		return

	var to_ply := player.global_position - global_position
	facing_sign = 1.0 if to_ply.x >= 0.0 else -1.0
	_update_facing_visual()

	_decision_cooldown -= delta * speed_scale
	if _decision_cooldown <= 0.0:
		_choose_next_boss_attack(player)
		return

	var ideal_x := player.global_position.x - facing_sign * (2.6 if boss_id == "beebo" else 1.65)
	var diff := Vector2(ideal_x - global_position.x, player.global_position.z - global_position.z)
	if diff.length() > 0.3:
		var dir := diff.normalized()
		velocity.x = move_toward(velocity.x, dir.x * move_speed * speed_scale, 24.0 * delta)
		velocity.z = move_toward(velocity.z, dir.y * move_speed * 0.82 * speed_scale, 24.0 * delta)
		_play_anim(&"run_dash" if move_speed >= 6.0 else &"walk_forward", 1.1)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
		_play_anim(&"idle_fight_stance", 1.0)

	if not is_on_floor():
		velocity.y -= GRAVITY * delta


func _choose_next_boss_attack(player: Node3D) -> void:
	_state = &"attack"
	_state_timer = 0.0
	_hit_registry.clear()
	_current_move = AttackData.new()
	_pattern_index = (_pattern_index + 1) % 4

	var to_ply := player.global_position - global_position
	facing_sign = 1.0 if to_ply.x >= 0.0 else -1.0
	_update_facing_visual()

	if boss_id == "chadzug":
		_setup_chadzug_pattern(player)
	elif boss_id == "beebo":
		_setup_beebo_pattern(player)
	else:
		_setup_generic_mythic_pattern(player)


func _setup_chadzug_pattern(player: Node3D) -> void:
	match _pattern_index:
		0:
			# Ankle-Biter Pickaxe Spin (low hurtbox sweep)
			_current_move.move_id = &"pickaxe_spin"
			_current_move.damage = 58.0
			_current_move.hitstop_frames = 5
			_current_move.aoe_corridor_box = Vector3(2.8, 1.1, 2.4)
			_play_anim(&"signature_special_1", 1.2)
			if HitstopManager:
				HitstopManager.spawn_ground_telegraph(global_position + Vector3(facing_sign * 1.8, 0.0, 0.0), Vector2(4.2, 2.2), 0.34)
		1:
			# Subway Grate Burrow Ambush (unblockable ground eruption under player!)
			_current_move.move_id = &"burrow_ambush"
			_current_move.damage = 74.0
			_current_move.unblockable = true
			_current_move.hitstop_frames = 6
			_current_move.aoe_corridor_box = Vector3(2.6, 2.2, 2.4)
			_burrowed = true
			_rig_root.visible = false
			_hurtbox.monitorable = false
			global_position.x = clampf(player.global_position.x, arena_x_min + 1.0, arena_x_max - 1.0)
			global_position.z = clampf(player.global_position.z, CORRIDOR_Z_MIN + 0.4, CORRIDOR_Z_MAX - 0.4)
			if HitstopManager:
				HitstopManager.spawn_ground_telegraph(global_position, Vector2(2.6, 2.4), 0.52)
		2:
			# Gnome Cap Ricochet Dive across locked arena
			_current_move.move_id = &"ricochet_dive"
			_current_move.damage = 64.0
			_current_move.hitstop_frames = 5
			_current_move.aoe_corridor_box = Vector3(2.2, 1.4, 1.9)
			velocity = Vector3(facing_sign * 12.5, 5.5, 0.0)
			_play_anim(&"signature_special_2", 1.25)
			if HitstopManager:
				HitstopManager.spawn_ground_telegraph(global_position + Vector3(facing_sign * 4.0, 0.0, 0.0), Vector2(8.0, 1.8), 0.30)
		_:
			_current_move.move_id = &"heavy_pickaxe"
			_current_move.damage = 68.0
			_current_move.unblockable = true
			_current_move.hitstop_frames = 6
			_current_move.aoe_corridor_box = Vector3(2.6, 1.6, 2.0)
			_play_anim(&"heavy_armor_breaker", 1.1)
			if HitstopManager:
				HitstopManager.spawn_ground_telegraph(global_position + Vector3(facing_sign * 1.4, 0.0, 0.0), Vector2(2.8, 2.0), 0.40)


func _setup_beebo_pattern(_player: Node3D) -> void:
	match _pattern_index:
		0:
			# Skyline Talon Swoop (aerial rise -> corridor dive-bomb; parryable by Ir or contestable by Horus!)
			_current_move.move_id = &"talon_swoop"
			_current_move.damage = 72.0
			_current_move.hitstop_frames = 6
			_current_move.aoe_corridor_box = Vector3(3.2, 2.2, 2.4)
			velocity = Vector3(-facing_sign * 2.0, 9.8, 0.0)
			_play_anim(&"signature_special_2", 1.15)
			if HitstopManager:
				HitstopManager.spawn_ground_telegraph(global_position + Vector3(facing_sign * 4.5, 0.0, 0.0), Vector2(9.5, 2.2), 0.46)
		1:
			# Razor Feather Fan (3-way projectile spread across Z-lanes)
			_current_move.move_id = &"feather_fan"
			_current_move.damage = 46.0
			_play_anim(&"signature_special_1", 1.2)
			if HitstopManager:
				HitstopManager.spawn_ground_telegraph(global_position + Vector3(facing_sign * 4.5, 0.0, 0.0), Vector2(8.5, 4.8), 0.36)
		2:
			# Gale-Force Wing Gust (pushback wind + shockwave)
			_current_move.move_id = &"wing_gust"
			_current_move.damage = 62.0
			_current_move.hitstop_frames = 5
			_current_move.aoe_corridor_box = Vector3(5.6, 2.5, 5.2)
			_play_anim(&"heavy_armor_breaker", 1.1)
			if HitstopManager:
				HitstopManager.spawn_ground_telegraph(global_position + Vector3(facing_sign * 2.8, 0.0, 0.0), Vector2(5.6, 5.0), 0.42)
		_:
			_current_move.move_id = &"beak_flurry"
			_current_move.damage = 54.0
			_current_move.hitstop_frames = 4
			_current_move.aoe_corridor_box = Vector3(2.6, 2.0, 2.0)
			_play_anim(&"light_combo", 1.15)


func _setup_generic_mythic_pattern(_player: Node3D) -> void:
	_current_move.move_id = &"heavy_strike"
	_current_move.damage = 68.0
	_current_move.hitstop_frames = 6
	_current_move.aoe_corridor_box = Vector3(3.2, 2.2, 2.6)
	_play_anim(&"heavy_armor_breaker", 1.05)
	if HitstopManager:
		HitstopManager.spawn_ground_telegraph(global_position + Vector3(facing_sign * 1.6, 0.0, 0.0), Vector2(3.2, 2.4), 0.40)


func _tick_signature_attack(delta: float, _speed_scale: float) -> void:
	if _current_move == null:
		_enter_state(&"pursue")
		return

	var mid := _current_move.move_id
	if mid == &"burrow_ambush":
		velocity = Vector3.ZERO
		if _state_timer >= 0.52 and _burrowed:
			_burrowed = false
			_rig_root.visible = true
			_hurtbox.monitorable = true
			velocity.y = 8.2
			_play_anim(&"signature_special_2", 1.35)
			if HitstopManager:
				HitstopManager.spawn_shockwave_ring(global_position, accent_color, 2.8, 0.28)
		if _state_timer >= 0.54 and _state_timer < 0.74:
			_activate_aoe(Vector3.ZERO)
		else:
			_deactivate_hitboxes()
		if not _burrowed and not is_on_floor():
			velocity.y -= GRAVITY * delta
		if _state_timer >= 0.98:
			_finish_boss_attack(0.80)
		return

	if mid == &"ricochet_dive":
		if not is_on_floor():
			velocity.y -= GRAVITY * 0.75 * delta
		if (global_position.x <= arena_x_min + 0.6 and velocity.x < 0.0) or (global_position.x >= arena_x_max - 0.6 and velocity.x > 0.0):
			velocity.x = -velocity.x
			facing_sign = signf(velocity.x)
			_update_facing_visual()
		if _state_timer >= 0.22 and _state_timer < 0.78:
			_activate_aoe(Vector3(facing_sign * 0.6, 0.7, 0.0))
		else:
			_deactivate_hitboxes()
		if _state_timer >= 0.95:
			_finish_boss_attack(0.85)
		return

	if mid == &"talon_swoop":
		if _state_timer < 0.36:
			velocity.y -= GRAVITY * 0.35 * delta
		elif _state_timer < 0.80:
			velocity.x = facing_sign * 13.8
			velocity.y = -7.5 if not is_on_floor() else 0.0
			_activate_aoe(Vector3(facing_sign * 1.1, 1.0, 0.0))
		else:
			_deactivate_hitboxes()
			velocity.x = move_toward(velocity.x, 0.0, 24.0 * delta)
			if not is_on_floor():
				velocity.y -= GRAVITY * delta
		if _state_timer >= 1.05:
			_finish_boss_attack(0.82)
		return

	if mid == &"feather_fan":
		velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		if _state_timer >= 0.36 and not _hit_registry.has("fan_fired"):
			_hit_registry["fan_fired"] = true
			for vz in [-2.6, 0.0, 2.6]:
				var proj := EnemyProjectile.new()
				proj.attacker = self
				proj.damage = _current_move.damage
				proj.velocity = Vector3(facing_sign * 10.5, 0.0, vz)
				get_parent().add_child(proj)
				proj.global_position = global_position + Vector3(facing_sign * 0.8, 1.25, 0.0)
			if SfxManager:
				SfxManager.play_3d("hit_blade", global_position, 0.0, 0.08)
		if _state_timer >= 0.75:
			_finish_boss_attack(0.78)
		return

	# Standard boss melee / shockwave timing (pickaxe_spin, wing_gust, heavy, light_combo)
	if mid == &"pickaxe_spin":
		velocity.x = facing_sign * 7.2
	else:
		velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	if _state_timer >= 0.36 and _state_timer < 0.62:
		_activate_aoe(Vector3(facing_sign * 1.4, 1.0, 0.0))
		if mid == &"wing_gust":
			var ply := get_tree().get_first_node_in_group("player") as CharacterBody3D
			if ply:
				ply.velocity.x += facing_sign * 22.0 * delta
	else:
		_deactivate_hitboxes()

	if _state_timer >= 0.88:
		_finish_boss_attack(0.85)


func _activate_aoe(local_offset: Vector3) -> void:
	_aoe_hitbox.position = local_offset + Vector3(0.0, 0.9, 0.0)
	if not _aoe_hitbox.monitoring:
		_aoe_hitbox.activate(_current_move, 1.0, facing_sign, accent_color, _hit_registry)


func _deactivate_hitboxes() -> void:
	if _aoe_hitbox:
		_aoe_hitbox.deactivate()
	for hb in _socket_hitboxes:
		hb.deactivate()


func _finish_boss_attack(cd: float) -> void:
	_burrowed = false
	if _rig_root:
		_rig_root.visible = true
	if _hurtbox:
		_hurtbox.monitorable = true
	_deactivate_hitboxes()
	_decision_cooldown = cd * (0.76 if phase >= 2 else 1.0)
	_enter_state(&"pursue")


func on_parried(armor_shatter: float) -> void:
	armor = maxf(0.0, armor - armor_shatter)
	boss_hp_updated.emit(hp, max_hp, armor, max_armor)
	if armor <= 0.0:
		_trigger_armor_break_stun(Vector3(-facing_sign * 3.5, 3.0, 0.0))


func receive_throw(dir_sign: float, dmg: float) -> void:
	if armor <= 0.0:
		var fake_move := AttackData.new()
		fake_move.launches_airborne = true
		fake_move.knockback_vel = Vector3(6.5, 5.0, 0.0)
		receive_hit({"attack_data": fake_move, "raw_damage": dmg, "armor_damage": 40.0, "facing_sign": dir_sign})
	else:
		receive_hit({"raw_damage": dmg * 0.65, "armor_damage": 55.0, "facing_sign": dir_sign})


func receive_hit(payload: Dictionary) -> Dictionary:
	if _is_dead or _burrowed or _state == &"phase_roar":
		return {"connected": false}

	var move: AttackData = payload.get("attack_data", null)
	var dmg := float(payload.get("raw_damage", 40.0))
	var armor_dmg := float(payload.get("armor_damage", 25.0))
	var dir_sign := float(payload.get("facing_sign", 1.0))

	hp = maxf(0.0, hp - dmg)
	if armor > 0.0:
		armor = maxf(0.0, armor - armor_dmg)
		if armor <= 0.0:
			if SfxManager:
				SfxManager.play_2d("armor_break", 1.0, 0.03)
			_trigger_armor_break_stun(Vector3(dir_sign * 4.2, 5.2, 0.0))
	elif _state == &"stunned":
		var kb := move.knockback_vel if move else Vector3(2.8, 2.0, 0.0)
		velocity.x = kb.x * dir_sign * 0.65
		if move and move.launches_airborne:
			velocity.y = maxf(kb.y * 0.78, 6.2)
			_play_anim(&"hit_launch_arc", 1.05)

	boss_hp_updated.emit(hp, max_hp, armor, max_armor)

	if hp <= 0.0:
		_die(dir_sign)
		return {"connected": true, "damage_dealt": dmg, "ko": true}

	# 50% HP Enrage Phase Shift!
	if phase == 1 and hp <= max_hp * 0.5:
		phase = 2
		_burrowed = false
		_rig_root.visible = true
		_hurtbox.monitorable = true
		_enter_state(&"phase_roar")
		if boss_id == "lucifer" and SoundtrackManager:
			SoundtrackManager.play_boss_theme(7, false, true, boss_name)
		boss_phase_shifted.emit(boss_id, 2)

	return {"connected": true, "damage_dealt": dmg}


func _trigger_armor_break_stun(kb_vel: Vector3) -> void:
	_burrowed = false
	if _rig_root:
		_rig_root.visible = true
	if _hurtbox:
		_hurtbox.monitorable = true
	_deactivate_hitboxes()
	_state = &"stunned"
	_state_timer = 0.0
	velocity = kb_vel
	_play_anim(&"hit_light", 0.9)


func _die(dir_sign: float) -> void:
	_is_dead = true
	_burrowed = false
	if _rig_root:
		_rig_root.visible = true
	_deactivate_hitboxes()
	collision_layer = 0
	if _hurtbox:
		_hurtbox.monitorable = false
	velocity = Vector3(dir_sign * 4.5, 4.5, 0.0)
	_play_anim(&"ko_collapse", 0.85)

	if SfxManager:
		SfxManager.play_2d("ko_boom", 2.0, 0.0)
	if HitstopManager:
		HitstopManager.trigger_slow_mo(0.24, 0.55, true)
		HitstopManager.spawn_shockwave_ring(global_position, accent_color, 7.0, 0.55)
	if GameManager:
		GameManager.add_score(score_value)

	boss_defeated.emit(boss_id, score_value, global_position)
	var tw := create_tween()
	tw.tween_interval(1.4)
	tw.tween_callback(queue_free)


func _update_facing_visual() -> void:
	if _visual_pivot:
		_visual_pivot.rotation.y = PI * 0.5 if facing_sign >= 0.0 else -PI * 0.5


func _play_anim(anim_name: StringName, speed: float = 1.0) -> void:
	if _anim and _anim.has_animation(anim_name):
		if _anim.current_animation != anim_name:
			_anim.play(anim_name, 0.06, speed)
		else:
			_anim.speed_scale = speed


func _clamp_corridor() -> void:
	global_position.z = clampf(global_position.z, CORRIDOR_Z_MIN, CORRIDOR_Z_MAX)
	global_position.x = clampf(global_position.x, arena_x_min, arena_x_max)
