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
	elif boss_id == "chupar":
		_setup_chupar_pattern(player)
	elif boss_id == "bar":
		_setup_bar_pattern(player)
	elif boss_id == "dadur":
		_setup_dadur_pattern(player)
	elif boss_id == "baphomet":
		_setup_baphomet_pattern(player)
	elif boss_id == "andruas":
		_setup_andruas_pattern(player)
	elif boss_id == "beezelbub":
		_setup_beezelbub_pattern(player)
	elif boss_id == "baba":
		_setup_baba_pattern(player)
	elif boss_id == "devil":
		_setup_devil_pattern(player)
	elif boss_id == "satan":
		_setup_satan_pattern(player)
	elif boss_id == "lucifer":
		_setup_lucifer_pattern(player)
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
			if _hurtbox:
				_hurtbox.deactivate()
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


func _setup_chupar_pattern(_player: Node3D) -> void:
	match _pattern_index:
		0:
			# Hundred-Palm Buffet Rush
			_current_move.move_id = &"hundred_palm_rush"
			_current_move.damage = 65.0
			_current_move.hitstop_frames = 5
			_current_move.aoe_corridor_box = Vector3(3.2, 1.8, 2.2)
			_play_anim(&"signature_special_1", 1.25)
			if HitstopManager:
				HitstopManager.spawn_ground_telegraph(global_position + Vector3(facing_sign * 2.2, 0.0, 0.0), Vector2(4.5, 2.0), 0.32)
		1:
			# Belly-Elastic Strike & Projectile Bounce
			_current_move.move_id = &"belly_bounce"
			_current_move.damage = 76.0
			_current_move.hyper_armor = true
			_current_move.unblockable = true
			_current_move.hitstop_frames = 6
			_current_move.aoe_corridor_box = Vector3(2.8, 2.0, 2.5)
			_play_anim(&"heavy_armor_breaker", 1.1)
			if HitstopManager:
				HitstopManager.spawn_ground_telegraph(global_position + Vector3(facing_sign * 1.5, 0.0, 0.0), Vector2(3.0, 2.4), 0.38)
		2:
			# Tremor Cannonball Sit-Drop
			_current_move.move_id = &"cannonball_sit_drop"
			_current_move.damage = 88.0
			_current_move.unblockable = true
			_current_move.hitstop_frames = 7
			_current_move.aoe_corridor_box = Vector3(5.2, 2.0, 5.0)
			velocity = Vector3(facing_sign * 3.5, 11.5, 0.0)
			_play_anim(&"signature_special_2", 1.2)
			if HitstopManager:
				HitstopManager.spawn_ground_telegraph(global_position + Vector3(facing_sign * 3.0, 0.0, 0.0), Vector2(5.5, 5.0), 0.45)
		_:
			_current_move.move_id = &"heavy_strike"
			_current_move.damage = 60.0
			_current_move.hitstop_frames = 5
			_current_move.aoe_corridor_box = Vector3(2.6, 1.8, 2.0)
			_play_anim(&"light_combo", 1.1)


func _setup_bar_pattern(_player: Node3D) -> void:
	match _pattern_index:
		0:
			# Supersonic Screech Wave
			_current_move.move_id = &"screech_wave"
			_current_move.damage = 68.0
			_current_move.hitstop_frames = 5
			_current_move.aoe_corridor_box = Vector3(7.5, 2.6, 5.5)
			_play_anim(&"signature_special_1", 1.2)
			if HitstopManager:
				HitstopManager.spawn_ground_telegraph(global_position + Vector3(facing_sign * 3.8, 0.0, 0.0), Vector2(7.5, 5.5), 0.35)
		1:
			# Cross-Boulevard Cyclone Glide
			_current_move.move_id = &"cyclone_glide"
			_current_move.damage = 72.0
			_current_move.hitstop_frames = 6
			_current_move.aoe_corridor_box = Vector3(3.5, 2.2, 2.4)
			velocity = Vector3(facing_sign * 14.5, 0.0, 0.0)
			_play_anim(&"signature_special_2", 1.25)
			if HitstopManager:
				HitstopManager.spawn_ground_telegraph(global_position + Vector3(facing_sign * 5.0, 0.0, 0.0), Vector2(10.0, 2.2), 0.30)
		2:
			# Sky-Drop Talon Piledriver
			_current_move.move_id = &"talon_piledriver"
			_current_move.damage = 85.0
			_current_move.unblockable = true
			_current_move.hitstop_frames = 7
			_current_move.aoe_corridor_box = Vector3(3.8, 2.2, 3.2)
			velocity = Vector3(-facing_sign * 2.5, 11.0, 0.0)
			_play_anim(&"signature_special_2", 1.15)
			if HitstopManager:
				HitstopManager.spawn_ground_telegraph(global_position + Vector3(facing_sign * 4.0, 0.0, 0.0), Vector2(5.0, 3.5), 0.45)
		_:
			_current_move.move_id = &"heavy_strike"
			_current_move.damage = 56.0
			_current_move.hitstop_frames = 4
			_current_move.aoe_corridor_box = Vector3(2.8, 2.0, 2.2)
			_play_anim(&"light_combo", 1.15)


func _setup_dadur_pattern(_player: Node3D) -> void:
	match _pattern_index:
		0:
			# Iron-Horn Suplex Grab
			_current_move.move_id = &"horn_suplex"
			_current_move.damage = 75.0
			_current_move.unblockable = true
			_current_move.hitstop_frames = 6
			_current_move.aoe_corridor_box = Vector3(2.8, 2.0, 2.2)
			velocity = Vector3(facing_sign * 8.5, 0.0, 0.0)
			_play_anim(&"signature_special_1", 1.2)
			if HitstopManager:
				HitstopManager.spawn_ground_telegraph(global_position + Vector3(facing_sign * 2.0, 0.0, 0.0), Vector2(4.0, 2.2), 0.35)
		1:
			# Snorting Hoof Flurry
			_current_move.move_id = &"snorting_flurry"
			_current_move.damage = 64.0
			_current_move.hitstop_frames = 5
			_current_move.aoe_corridor_box = Vector3(3.2, 1.8, 2.4)
			_play_anim(&"light_combo", 1.25)
			if HitstopManager:
				HitstopManager.spawn_ground_telegraph(global_position + Vector3(facing_sign * 1.6, 0.0, 0.0), Vector2(3.2, 2.4), 0.30)
		2:
			# Courtyard Wall-Pin Tackle
			_current_move.move_id = &"wall_pin_tackle"
			_current_move.damage = 80.0
			_current_move.hyper_armor = true
			_current_move.hitstop_frames = 6
			_current_move.aoe_corridor_box = Vector3(3.4, 2.2, 2.6)
			velocity = Vector3(facing_sign * 13.0, 0.0, 0.0)
			_play_anim(&"heavy_armor_breaker", 1.15)
			if HitstopManager:
				HitstopManager.spawn_ground_telegraph(global_position + Vector3(facing_sign * 4.5, 0.0, 0.0), Vector2(9.0, 2.4), 0.32)
		_:
			_current_move.move_id = &"heavy_strike"
			_current_move.damage = 60.0
			_current_move.hitstop_frames = 5
			_current_move.aoe_corridor_box = Vector3(2.6, 2.0, 2.0)
			_play_anim(&"heavy_armor_breaker", 1.1)


func _setup_baphomet_pattern(_player: Node3D) -> void:
	match _pattern_index:
		0:
			# Gran Via Bull-Rush Charge
			_current_move.move_id = &"bull_rush_charge"
			_current_move.damage = 85.0
			_current_move.hyper_armor = true
			_current_move.hitstop_frames = 7
			_current_move.aoe_corridor_box = Vector3(3.8, 2.5, 3.2)
			velocity = Vector3(facing_sign * 14.0, 0.0, 0.0)
			_play_anim(&"heavy_armor_breaker", 1.2)
			if HitstopManager:
				HitstopManager.spawn_ground_telegraph(global_position + Vector3(facing_sign * 5.5, 0.0, 0.0), Vector2(11.0, 3.2), 0.34)
		1:
			# Molten Hoof Earthquake
			_current_move.move_id = &"molten_earthquake"
			_current_move.damage = 78.0
			_current_move.unblockable = true
			_current_move.hitstop_frames = 6
			_current_move.aoe_corridor_box = Vector3(6.5, 2.2, 6.2)
			_play_anim(&"signature_special_1", 1.15)
			if HitstopManager:
				HitstopManager.spawn_ground_telegraph(global_position, Vector2(6.5, 6.2), 0.40)
		2:
			# Brazen Horn Gore Throw
			_current_move.move_id = &"gore_throw"
			_current_move.damage = 72.0
			_current_move.hitstop_frames = 6
			_current_move.aoe_corridor_box = Vector3(3.2, 2.8, 2.6)
			velocity = Vector3(facing_sign * 4.0, 8.5, 0.0)
			_play_anim(&"signature_special_2", 1.25)
			if HitstopManager:
				HitstopManager.spawn_ground_telegraph(global_position + Vector3(facing_sign * 2.0, 0.0, 0.0), Vector2(3.5, 2.6), 0.36)
		_:
			_current_move.move_id = &"heavy_strike"
			_current_move.damage = 65.0
			_current_move.hitstop_frames = 5
			_current_move.aoe_corridor_box = Vector3(3.0, 2.2, 2.4)
			_play_anim(&"light_combo", 1.1)


func _setup_andruas_pattern(_player: Node3D) -> void:
	match _pattern_index:
		0:
			# Full-Corridor Tail Whip Sweep (low full Z sweep - must jump!)
			_current_move.move_id = &"tail_whip_sweep"
			_current_move.damage = 70.0
			_current_move.hitstop_frames = 5
			_current_move.aoe_corridor_box = Vector3(6.0, 0.75, 6.4)
			_play_anim(&"signature_special_1", 1.2)
			if HitstopManager:
				HitstopManager.spawn_ground_telegraph(global_position + Vector3(facing_sign * 2.8, 0.0, 0.0), Vector2(5.8, 6.4), 0.38)
		1:
			# Coiling Crush Bind
			_current_move.move_id = &"coiling_bind"
			_current_move.damage = 76.0
			_current_move.unblockable = true
			_current_move.hitstop_frames = 6
			_current_move.aoe_corridor_box = Vector3(3.2, 2.0, 2.4)
			velocity = Vector3(facing_sign * 11.5, 0.0, 0.0)
			_play_anim(&"signature_special_2", 1.25)
			if HitstopManager:
				HitstopManager.spawn_ground_telegraph(global_position + Vector3(facing_sign * 3.5, 0.0, 0.0), Vector2(7.0, 2.4), 0.32)
		2:
			# Venom Fang Lunge
			_current_move.move_id = &"venom_lunge"
			_current_move.damage = 65.0
			_current_move.hitstop_frames = 5
			_current_move.aoe_corridor_box = Vector3(3.6, 2.0, 2.2)
			_play_anim(&"heavy_armor_breaker", 1.15)
			if HitstopManager:
				HitstopManager.spawn_ground_telegraph(global_position + Vector3(facing_sign * 2.0, 0.0, 0.0), Vector2(4.0, 2.2), 0.35)
		_:
			_current_move.move_id = &"heavy_strike"
			_current_move.damage = 58.0
			_current_move.hitstop_frames = 4
			_current_move.aoe_corridor_box = Vector3(2.8, 2.0, 2.0)
			_play_anim(&"light_combo", 1.15)


func _setup_beezelbub_pattern(_player: Node3D) -> void:
	match _pattern_index:
		0:
			# Drone Fly Swarm Call
			_current_move.move_id = &"drone_swarm_call"
			_current_move.damage = 50.0
			_current_move.hitstop_frames = 4
			_current_move.aoe_corridor_box = Vector3(3.0, 2.0, 3.0)
			_play_anim(&"signature_special_1", 1.2)
			if HitstopManager:
				HitstopManager.spawn_ground_telegraph(global_position, Vector2(3.5, 3.5), 0.40)
		1:
			# Corrosive Venom Spit Pools (3 toxic projectiles)
			_current_move.move_id = &"venom_spit"
			_current_move.damage = 52.0
			_current_move.hitstop_frames = 4
			_play_anim(&"signature_special_2", 1.2)
			if HitstopManager:
				HitstopManager.spawn_ground_telegraph(global_position + Vector3(facing_sign * 4.0, 0.0, 0.0), Vector2(8.0, 5.0), 0.35)
		2:
			# Compound-Eye Strobe Evade (teleport buzz-dash)
			_current_move.move_id = &"strobe_evade"
			_current_move.damage = 45.0
			_current_move.hitstop_frames = 4
			_current_move.aoe_corridor_box = Vector3(2.5, 1.8, 2.5)
			_play_anim(&"signature_special_2", 1.3)
		_:
			_current_move.move_id = &"mandible_strike"
			_current_move.damage = 56.0
			_current_move.hitstop_frames = 4
			_current_move.aoe_corridor_box = Vector3(2.8, 2.0, 2.2)
			_play_anim(&"light_combo", 1.15)


func _setup_baba_pattern(_player: Node3D) -> void:
	match _pattern_index:
		0:
			# Heavy Pestle Ground Pound
			_current_move.move_id = &"pestle_pound"
			_current_move.damage = 72.0
			_current_move.unblockable = true
			_current_move.hitstop_frames = 6
			_current_move.aoe_corridor_box = Vector3(4.2, 2.0, 4.0)
			_play_anim(&"heavy_armor_breaker", 1.2)
			if HitstopManager:
				HitstopManager.spawn_ground_telegraph(global_position + Vector3(facing_sign * 2.2, 0.0, 0.0), Vector2(4.5, 4.0), 0.38)
		1:
			# Toxic Potion Brew Spread
			_current_move.move_id = &"potion_toxic_cloud"
			_current_move.damage = 58.0
			_current_move.hitstop_frames = 4
			_play_anim(&"signature_special_1", 1.2)
			if HitstopManager:
				HitstopManager.spawn_ground_telegraph(global_position + Vector3(facing_sign * 3.5, 0.0, 0.0), Vector2(7.0, 4.5), 0.35)
		2:
			# Cackling Mortar Dash
			_current_move.move_id = &"cackle_dash"
			_current_move.damage = 54.0
			_current_move.hitstop_frames = 5
			_current_move.aoe_corridor_box = Vector3(3.2, 1.8, 2.2)
			_play_anim(&"signature_special_2", 1.25)
		_:
			_current_move.move_id = &"pestle_strike"
			_current_move.damage = 52.0
			_current_move.hitstop_frames = 4
			_current_move.aoe_corridor_box = Vector3(2.6, 1.8, 2.0)
			_play_anim(&"light_combo", 1.15)


func _setup_devil_pattern(_player: Node3D) -> void:
	match _pattern_index:
		0:
			# Trident Skewer Thrust
			_current_move.move_id = &"pitchfork_skewer"
			_current_move.damage = 78.0
			_current_move.hyper_armor = true
			_current_move.hitstop_frames = 6
			_current_move.aoe_corridor_box = Vector3(3.8, 2.2, 2.5)
			_play_anim(&"heavy_armor_breaker", 1.25)
			if HitstopManager:
				HitstopManager.spawn_ground_telegraph(global_position + Vector3(facing_sign * 3.0, 0.0, 0.0), Vector2(6.0, 2.5), 0.34)
		1:
			# Brimstone Hellfire Puddle
			_current_move.move_id = &"hellfire_puddle"
			_current_move.damage = 74.0
			_current_move.unblockable = true
			_current_move.hitstop_frames = 6
			_current_move.aoe_corridor_box = Vector3(6.5, 2.0, 5.5)
			_play_anim(&"signature_special_1", 1.2)
			if HitstopManager:
				HitstopManager.spawn_ground_telegraph(global_position, Vector2(6.5, 5.5), 0.38)
		2:
			# Bat-Wing Hell Dive
			_current_move.move_id = &"dive_bomb_hell"
			_current_move.damage = 84.0
			_current_move.unblockable = true
			_current_move.hitstop_frames = 7
			_current_move.aoe_corridor_box = Vector3(4.8, 2.2, 4.5)
			velocity = Vector3(facing_sign * 3.0, 11.0, 0.0)
			_play_anim(&"signature_special_2", 1.2)
			if HitstopManager:
				HitstopManager.spawn_ground_telegraph(global_position + Vector3(facing_sign * 4.0, 0.0, 0.0), Vector2(5.5, 4.5), 0.44)
		_:
			_current_move.move_id = &"trident_slash"
			_current_move.damage = 58.0
			_current_move.hitstop_frames = 4
			_current_move.aoe_corridor_box = Vector3(2.8, 2.0, 2.2)
			_play_anim(&"light_combo", 1.15)


func _setup_satan_pattern(_player: Node3D) -> void:
	match _pattern_index:
		0:
			# High-Voltage Screen Wipe
			_current_move.move_id = &"electric_screen_wipe"
			_current_move.damage = 88.0
			_current_move.unblockable = true
			_current_move.hitstop_frames = 7
			_current_move.aoe_corridor_box = Vector3(8.5, 2.8, 6.0)
			_play_anim(&"signature_special_1", 1.25)
			if HitstopManager:
				HitstopManager.spawn_ground_telegraph(global_position + Vector3(facing_sign * 4.2, 0.0, 0.0), Vector2(8.5, 6.0), 0.40)
		1:
			# Plasma Teleport Dive
			_current_move.move_id = &"plasma_teleport_dive"
			_current_move.damage = 82.0
			_current_move.hyper_armor = true
			_current_move.hitstop_frames = 6
			_current_move.aoe_corridor_box = Vector3(4.5, 2.2, 4.0)
			velocity = Vector3(facing_sign * 2.5, 10.5, 0.0)
			_play_anim(&"signature_special_2", 1.2)
			if HitstopManager:
				HitstopManager.spawn_ground_telegraph(global_position + Vector3(facing_sign * 3.5, 0.0, 0.0), Vector2(5.0, 4.0), 0.42)
		2:
			# Electric Shockwave Grid
			_current_move.move_id = &"thunder_trap_grid"
			_current_move.damage = 65.0
			_current_move.hitstop_frames = 5
			_play_anim(&"heavy_armor_breaker", 1.2)
			if HitstopManager:
				HitstopManager.spawn_ground_telegraph(global_position + Vector3(facing_sign * 4.0, 0.0, 0.0), Vector2(7.5, 4.5), 0.35)
		_:
			_current_move.move_id = &"plasma_claw_combo"
			_current_move.damage = 62.0
			_current_move.hitstop_frames = 4
			_current_move.aoe_corridor_box = Vector3(3.0, 2.0, 2.2)
			_play_anim(&"light_combo", 1.2)


func _setup_lucifer_pattern(player: Node3D) -> void:
	if phase == 1:
		match _pattern_index:
			0:
				# Light Pillar Celestial Beam
				_current_move.move_id = &"light_pillar_beam"
				_current_move.damage = 90.0
				_current_move.unblockable = true
				_current_move.hitstop_frames = 7
				_current_move.aoe_corridor_box = Vector3(4.8, 4.5, 4.8)
				_play_anim(&"signature_special_1", 1.2)
				if HitstopManager:
					HitstopManager.spawn_ground_telegraph(player.global_position, Vector2(5.0, 5.0), 0.42)
			1:
				# 6-Wing Seraph Feather Barrage
				_current_move.move_id = &"feather_barrage"
				_current_move.damage = 75.0
				_current_move.hitstop_frames = 5
				_play_anim(&"signature_special_2", 1.25)
				if HitstopManager:
					HitstopManager.spawn_ground_telegraph(global_position + Vector3(facing_sign * 4.5, 0.0, 0.0), Vector2(9.0, 5.5), 0.36)
			2:
				# Radiant Colosseum Sweep
				_current_move.move_id = &"radiant_sweep"
				_current_move.damage = 80.0
				_current_move.hyper_armor = true
				_current_move.hitstop_frames = 6
				_current_move.aoe_corridor_box = Vector3(4.0, 2.2, 2.8)
				_play_anim(&"heavy_armor_breaker", 1.2)
				if HitstopManager:
					HitstopManager.spawn_ground_telegraph(global_position + Vector3(facing_sign * 3.5, 0.0, 0.0), Vector2(7.0, 2.8), 0.32)
			_:
				_current_move.move_id = &"celestial_slash"
				_current_move.damage = 66.0
				_current_move.hitstop_frames = 4
				_current_move.aoe_corridor_box = Vector3(3.2, 2.0, 2.2)
				_play_anim(&"light_combo", 1.2)
	else:
		# Phase 2: Infernal Shadow Metamorphosis
		match _pattern_index:
			0:
				# Dark Matter Colosseum Implosion
				_current_move.move_id = &"dark_matter_implosion"
				_current_move.damage = 95.0
				_current_move.unblockable = true
				_current_move.hitstop_frames = 8
				_current_move.aoe_corridor_box = Vector3(7.5, 3.2, 7.5)
				_play_anim(&"signature_special_1", 1.3)
				if HitstopManager:
					HitstopManager.spawn_ground_telegraph(global_position, Vector2(8.0, 8.0), 0.45)
			1:
				# Shadow Teleport Dash Flurry
				_current_move.move_id = &"shadow_dash_flurry"
				_current_move.damage = 85.0
				_current_move.hyper_armor = true
				_current_move.hitstop_frames = 6
				_current_move.aoe_corridor_box = Vector3(3.8, 2.2, 2.8)
				_play_anim(&"heavy_armor_breaker", 1.3)
				if HitstopManager:
					HitstopManager.spawn_ground_telegraph(global_position + Vector3(facing_sign * 5.0, 0.0, 0.0), Vector2(10.0, 3.0), 0.30)
			2:
				# Crimson Rain
				_current_move.move_id = &"crimson_rain"
				_current_move.damage = 82.0
				_current_move.hitstop_frames = 5
				_play_anim(&"signature_special_2", 1.3)
				if HitstopManager:
					HitstopManager.spawn_ground_telegraph(global_position + Vector3(facing_sign * 4.0, 0.0, 0.0), Vector2(8.0, 5.0), 0.35)
			_:
				_current_move.move_id = &"void_rapier_thrust"
				_current_move.damage = 72.0
				_current_move.hitstop_frames = 5
				_current_move.aoe_corridor_box = Vector3(3.4, 2.0, 2.4)
				_play_anim(&"light_combo", 1.25)


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
			if _hurtbox:
				_hurtbox.activate()
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

	# Chupar: Cannonball Sit-Drop & Bar: Talon Piledriver
	if mid == &"cannonball_sit_drop" or mid == &"talon_piledriver":
		if _state_timer < 0.36:
			velocity.y -= GRAVITY * 0.45 * delta
		elif _state_timer < 0.72:
			velocity.y = -20.0
			velocity.x = facing_sign * (2.2 if mid == &"cannonball_sit_drop" else 5.5)
			if is_on_floor() and not _hit_registry.has("slam_landed"):
				_hit_registry["slam_landed"] = true
				if HitstopManager:
					HitstopManager.trigger_camera_shake(0.42, 11.0)
					HitstopManager.spawn_shockwave_ring(global_position, accent_color, 5.5, 0.45)
				if SfxManager:
					SfxManager.play_3d("heavy_thud", global_position, 0.0, 0.05)
				_activate_aoe(Vector3.ZERO)
		else:
			_deactivate_hitboxes()
			velocity.x = move_toward(velocity.x, 0.0, 22.0 * delta)
		if not is_on_floor() and _state_timer >= 0.72:
			velocity.y -= GRAVITY * delta
		if _state_timer >= 0.98:
			_finish_boss_attack(0.85)
		return

	# Bar: Cyclone Glide
	if mid == &"cyclone_glide":
		if _state_timer >= 0.18 and _state_timer < 0.65:
			velocity.x = facing_sign * 14.5
			_activate_aoe(Vector3(facing_sign * 1.5, 1.0, 0.0))
		else:
			_deactivate_hitboxes()
			velocity.x = move_toward(velocity.x, 0.0, 24.0 * delta)
		if not is_on_floor():
			velocity.y -= GRAVITY * 0.5 * delta
		if _state_timer >= 0.88:
			_finish_boss_attack(0.80)
		return

	# Dadur: Wall-Pin Tackle & Baphomet: Bull Rush Charge
	if mid == &"wall_pin_tackle" or mid == &"bull_rush_charge":
		var spd := 14.0 if mid == &"bull_rush_charge" else 13.0
		if _state_timer >= 0.18 and _state_timer < 0.68:
			velocity.x = facing_sign * spd
			_activate_aoe(Vector3(facing_sign * 1.5, 1.0, 0.0))
			if (global_position.x <= arena_x_min + 0.6 and velocity.x < 0.0) or (global_position.x >= arena_x_max - 0.6 and velocity.x > 0.0):
				if not _hit_registry.has("wall_impact"):
					_hit_registry["wall_impact"] = true
					if HitstopManager:
						HitstopManager.trigger_camera_shake(0.35, 9.5)
						HitstopManager.spawn_shockwave_ring(global_position, accent_color, 3.5, 0.35)
					if SfxManager:
						SfxManager.play_3d("heavy_thud", global_position, 0.0, 0.05)
		else:
			_deactivate_hitboxes()
			velocity.x = move_toward(velocity.x, 0.0, 24.0 * delta)
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		if _state_timer >= 0.90:
			_finish_boss_attack(0.85)
		return

	# Dadur: Horn Suplex & Andruas: Coiling Bind
	if mid == &"horn_suplex" or mid == &"coiling_bind":
		var spd := 11.5 if mid == &"coiling_bind" else 8.5
		if _state_timer >= 0.15 and _state_timer < 0.55:
			velocity.x = facing_sign * spd
			_activate_aoe(Vector3(facing_sign * 1.3, 0.9, 0.0))
		else:
			_deactivate_hitboxes()
			velocity.x = move_toward(velocity.x, 0.0, 22.0 * delta)
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		if _state_timer >= 0.82:
			_finish_boss_attack(0.78)
		return

	# Bar: Supersonic Screech Wave & Baphomet: Molten Earthquake
	if mid == &"screech_wave" or mid == &"molten_earthquake":
		velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		if _state_timer >= 0.34 and _state_timer < 0.65:
			_activate_aoe(Vector3(facing_sign * 1.8, 0.5, 0.0))
			if not _hit_registry.has("earthquake_quake"):
				_hit_registry["earthquake_quake"] = true
				if HitstopManager:
					HitstopManager.trigger_camera_shake(0.38, 11.0)
					HitstopManager.spawn_shockwave_ring(global_position, accent_color, 6.2, 0.42)
				if SfxManager:
					SfxManager.play_3d("groan_demon" if mid == &"screech_wave" else "heavy_thud", global_position, 0.0, 0.05)
		else:
			_deactivate_hitboxes()
		if _state_timer >= 0.88:
			_finish_boss_attack(0.85)
		return

	# Andruas: Tail Whip Sweep (low corridor sweep requiring jump)
	if mid == &"tail_whip_sweep":
		velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		if _state_timer >= 0.32 and _state_timer < 0.58:
			_activate_aoe(Vector3(facing_sign * 2.2, 0.35, 0.0))
			if not _hit_registry.has("sweep_sfx"):
				_hit_registry["sweep_sfx"] = true
				if SfxManager:
					SfxManager.play_3d("special_whoosh", global_position, 0.0, 0.05)
		else:
			_deactivate_hitboxes()
		if _state_timer >= 0.82:
			_finish_boss_attack(0.75)
		return

	# Beezelbub: Corrosive Venom Spit Pools (3 toxic projectiles)
	if mid == &"venom_spit":
		velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		if _state_timer >= 0.32 and not _hit_registry.has("spit_fired"):
			_hit_registry["spit_fired"] = true
			for vz in [-2.4, 0.0, 2.4]:
				var proj := EnemyProjectile.new()
				proj.attacker = self
				proj.damage = _current_move.damage
				proj.velocity = Vector3(facing_sign * 11.0, 0.0, vz)
				get_parent().add_child(proj)
				proj.global_position = global_position + Vector3(facing_sign * 0.9, 1.15, 0.0)
			if SfxManager:
				SfxManager.play_3d("special_whoosh", global_position, 0.0, 0.06)
		if _state_timer >= 0.75:
			_finish_boss_attack(0.75)
		return

	# Beezelbub: Drone Fly Swarm Call
	if mid == &"drone_swarm_call":
		velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		if _state_timer >= 0.36 and not _hit_registry.has("swarm_called"):
			_hit_registry["swarm_called"] = true
			if HitstopManager:
				HitstopManager.spawn_shockwave_ring(global_position, accent_color, 4.0, 0.35)
			if SfxManager:
				SfxManager.play_3d("groan_demon", global_position, 0.0, 0.05)
			var enemies := get_tree().get_nodes_in_group("enemies")
			if enemies.size() < 4:
				const DRONE_SCENE = preload("res://scenes/enemies/wave_enemy.tscn")
				for offset_z in [-1.5, 1.5]:
					var drone := DRONE_SCENE.instantiate() as WaveEnemy
					drone.arena_x_min = arena_x_min
					drone.arena_x_max = arena_x_max
					get_parent().add_child(drone)
					drone.global_position = global_position + Vector3(-facing_sign * 1.8, 0.2, offset_z)
					drone.configure_tier("drone", accent_color)
			else:
				for ang in [-3.2, 0.0, 3.2]:
					var proj := EnemyProjectile.new()
					proj.attacker = self
					proj.damage = _current_move.damage * 0.7
					proj.velocity = Vector3(facing_sign * 9.5, 0.0, ang)
					get_parent().add_child(proj)
					proj.global_position = global_position + Vector3(facing_sign * 0.8, 1.2, 0.0)
		if _state_timer >= 0.80:
			_finish_boss_attack(0.80)
		return

	# Beezelbub: Compound-Eye Strobe Evade
	if mid == &"strobe_evade":
		if _state_timer < 0.22:
			velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
		elif _state_timer < 0.45:
			velocity.x = -facing_sign * 16.5
			_activate_aoe(Vector3.ZERO)
		else:
			_deactivate_hitboxes()
			velocity.x = move_toward(velocity.x, 0.0, 24.0 * delta)
			if not _hit_registry.has("turned"):
				_hit_registry["turned"] = true
				facing_sign = -facing_sign
				_update_facing_visual()
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		if _state_timer >= 0.78:
			_finish_boss_attack(0.70)
		return

	# Devil: Bat-Wing Hell Dive & Satan: Plasma Teleport Dive
	if mid == &"dive_bomb_hell" or mid == &"plasma_teleport_dive":
		if _state_timer < 0.35:
			velocity.y -= GRAVITY * 0.45 * delta
		elif _state_timer < 0.72:
			velocity.y = -21.0
			velocity.x = facing_sign * (3.5 if mid == &"dive_bomb_hell" else 2.5)
			if is_on_floor() and not _hit_registry.has("slam_landed"):
				_hit_registry["slam_landed"] = true
				if HitstopManager:
					HitstopManager.trigger_camera_shake(0.45, 12.0)
					HitstopManager.spawn_shockwave_ring(global_position, accent_color, 5.8, 0.45)
				if SfxManager:
					SfxManager.play_3d("heavy_thud", global_position, 0.0, 0.05)
				_activate_aoe(Vector3.ZERO)
		else:
			_deactivate_hitboxes()
			velocity.x = move_toward(velocity.x, 0.0, 22.0 * delta)
		if not is_on_floor() and _state_timer >= 0.72:
			velocity.y -= GRAVITY * delta
		if _state_timer >= 0.98:
			_finish_boss_attack(0.85)
		return

	# Satan: High-Voltage Electric Screen Wipe & Lucifer: Light Pillar Beam & Dark Matter Implosion
	if mid == &"electric_screen_wipe" or mid == &"light_pillar_beam" or mid == &"dark_matter_implosion":
		velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		if _state_timer >= 0.34 and _state_timer < 0.68:
			_activate_aoe(Vector3(facing_sign * 2.0, 1.0, 0.0))
			if not _hit_registry.has("wipe_triggered"):
				_hit_registry["wipe_triggered"] = true
				if HitstopManager:
					HitstopManager.trigger_camera_shake(0.48, 14.0)
					HitstopManager.spawn_shockwave_ring(global_position, accent_color, 8.5, 0.50)
					if mid == &"light_pillar_beam":
						HitstopManager.spawn_lightning_pillar(global_position + Vector3(facing_sign * 2.0, 0.0, 0.0), accent_color, 5.0, 0.5)
				if SfxManager:
					SfxManager.play_3d("hit_thunder" if mid != &"dark_matter_implosion" else "ko_boom", global_position, 0.0, 0.05)
		else:
			_deactivate_hitboxes()
		if _state_timer >= 0.95:
			_finish_boss_attack(0.85)
		return

	# Baba: Potion Toxic Cloud & Satan: Thunder Trap Grid & Lucifer: Feather Barrage & Crimson Rain
	if mid == &"potion_toxic_cloud" or mid == &"thunder_trap_grid" or mid == &"feather_barrage" or mid == &"crimson_rain":
		velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		if _state_timer >= 0.32 and not _hit_registry.has("proj_barrage_fired"):
			_hit_registry["proj_barrage_fired"] = true
			var spreads := [-3.5, -1.8, 0.0, 1.8, 3.5] if (mid == &"feather_barrage" or mid == &"crimson_rain") else [-2.8, 0.0, 2.8]
			for vz in spreads:
				var proj := EnemyProjectile.new()
				proj.attacker = self
				proj.damage = _current_move.damage
				proj.velocity = Vector3(facing_sign * 11.5, 0.0, vz)
				get_parent().add_child(proj)
				proj.global_position = global_position + Vector3(facing_sign * 0.9, 1.25, 0.0)
			if SfxManager:
				SfxManager.play_3d("hit_blade" if mid == &"feather_barrage" else "hit_thunder", global_position, 0.0, 0.06)
		if _state_timer >= 0.78:
			_finish_boss_attack(0.78)
		return

	# High-Speed Charges: Devil Pitchfork Skewer, Baba Cackle Dash, Lucifer Radiant Sweep & Shadow Dash Flurry
	if mid == &"pitchfork_skewer" or mid == &"cackle_dash" or mid == &"radiant_sweep" or mid == &"shadow_dash_flurry":
		var spd := 16.0 if mid == &"shadow_dash_flurry" else (13.5 if mid == &"radiant_sweep" else 11.8)
		if _state_timer >= 0.16 and _state_timer < 0.62:
			velocity.x = facing_sign * spd
			_activate_aoe(Vector3(facing_sign * 1.5, 0.9, 0.0))
		else:
			_deactivate_hitboxes()
			velocity.x = move_toward(velocity.x, 0.0, 24.0 * delta)
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		if _state_timer >= 0.88:
			_finish_boss_attack(0.80)
		return

	# Ground Shockwaves: Baba Pestle Pound & Devil Hellfire Puddle
	if mid == &"pestle_pound" or mid == &"hellfire_puddle":
		velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		if _state_timer >= 0.35 and _state_timer < 0.65:
			_activate_aoe(Vector3(facing_sign * 1.6, 0.5, 0.0))
			if not _hit_registry.has("slam_shockwave"):
				_hit_registry["slam_shockwave"] = true
				if HitstopManager:
					HitstopManager.trigger_camera_shake(0.40, 11.0)
					HitstopManager.spawn_shockwave_ring(global_position, accent_color, 6.0, 0.42)
				if SfxManager:
					SfxManager.play_3d("heavy_thud", global_position, 0.0, 0.05)
		else:
			_deactivate_hitboxes()
		if _state_timer >= 0.88:
			_finish_boss_attack(0.85)
		return

	# Standard boss melee / shockwave timing (pickaxe_spin, hundred_palm_rush, wing_gust, heavy, light_combo)
	if mid == &"pickaxe_spin":
		velocity.x = facing_sign * 7.2
	elif mid == &"hundred_palm_rush":
		velocity.x = facing_sign * 5.2
	else:
		velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	var act_start := 0.22 if mid == &"hundred_palm_rush" else 0.36
	var act_end := 0.65 if mid == &"hundred_palm_rush" else 0.62
	if _state_timer >= act_start and _state_timer < act_end:
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
		_hurtbox.activate()
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
		if _hurtbox:
			_hurtbox.activate()
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
		_hurtbox.activate()
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
	set_deferred(&"collision_layer", 0)
	if _hurtbox:
		_hurtbox.deactivate()
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
