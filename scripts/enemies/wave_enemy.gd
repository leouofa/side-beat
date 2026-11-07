class_name WaveEnemy
extends CharacterBody3D
## Lean Wave Enemy controller driving res://assets/enemies/enemy_base.glb across
## Street Thugs (+250 pts), Bruisers/Enforcers (+600 pts), and Cult Elites (+1,200 pts).

signal defeated(enemy: WaveEnemy, score_value: int, world_pos: Vector3)

const CORRIDOR_Z_MIN := -3.2
const CORRIDOR_Z_MAX := 3.2
const GRAVITY := 26.0

const TIER_CONFIGS := {
	"thug": {
		"title": "Street Thug",
		"scale": 1.0,
		"max_hp": 165.0,
		"poise_max": 0.0,
		"move_speed": 3.8,
		"attack_damage": 32.0,
		"score": 250,
		"jacket_color": Color("#2E86DE"),
		"pants_color": Color("#222F3E"),
		"accent_color": Color("#FF1E42"),
	},
	"bruiser": {
		"title": "Enforcer Bruiser",
		"scale": 1.28,
		"max_hp": 330.0,
		"poise_max": 45.0,
		"move_speed": 2.9,
		"attack_damage": 52.0,
		"score": 600,
		"jacket_color": Color("#B33939"),
		"pants_color": Color("#1E272E"),
		"accent_color": Color("#FFA801"),
	},
	"cult_elite": {
		"title": "Cult Elite",
		"scale": 1.06,
		"max_hp": 265.0,
		"poise_max": 25.0,
		"move_speed": 4.5,
		"attack_damage": 44.0,
		"score": 1200,
		"jacket_color": Color("#6C3483"),
		"pants_color": Color("#191324"),
		"accent_color": Color("#FF1E42"),
	},
	"drone": {
		"title": "Plague Drone",
		"scale": 1.45,
		"max_hp": 95.0,
		"poise_max": 0.0,
		"move_speed": 5.4,
		"attack_damage": 24.0,
		"score": 180,
		"glb": "res://assets/enemies/drone_fly.glb",
		"jacket_color": Color("#1E272E"),
		"pants_color": Color("#1E272E"),
		"accent_color": Color("#A3CB38"),
	},
}

var tier_id: String = "thug"
var max_hp: float = 165.0
var hp: float = 165.0
var max_poise: float = 0.0
var poise: float = 0.0
var move_speed: float = 3.8
var attack_damage: float = 32.0
var score_value: int = 250
var facing_sign: float = -1.0
var arena_x_min: float = -10000.0
var arena_x_max: float = 10000.0
var flank_slot_offset: Vector3 = Vector3(1.3, 0.0, 0.0)

var _visual_pivot: Node3D
var _rig_root: Node3D
var _anim: AnimationPlayer
var _hurtbox: HurtBox3D
var _hitbox: HitBox3D
var _hp_bar_fill: MeshInstance3D
var _hp_bar_root: Node3D

var _hitstun_timer: float = 0.0
var _attack_cooldown: float = 0.8
var _attack_timer: float = 0.0
var _is_attacking: bool = false
var _is_dead: bool = false
var _death_landed: bool = false
var _death_ground_timer: float = 0.0
var _death_safety_timer: float = 0.0
var _ground_bounced: bool = false
var _wall_bounced: bool = false
var _hit_registry: Dictionary = {}
var _enemy_move: AttackData


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = (1 << 2) # Layer 3: EnemyBody
	collision_mask = (1 << 0)  # Layer 1: WorldBounds

	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.36
	cap.height = 1.78
	col.shape = cap
	col.position = Vector3(0.0, 0.89, 0.0)
	add_child(col)

	_visual_pivot = Node3D.new()
	add_child(_visual_pivot)

	_rig_root = GlbLoader.instantiate_glb("res://assets/enemies/enemy_base.glb")
	_visual_pivot.add_child(_rig_root)
	_anim = GlbLoader.find_anim_player(_rig_root)

	_hurtbox = HurtBox3D.new()
	add_child(_hurtbox)

	_hitbox = HitBox3D.new()
	_hitbox.attacker = self
	_hitbox.configure_team_layers(false)
	add_child(_hitbox)

	_enemy_move = AttackData.new()
	_build_overhead_hp_bar()
	configure_tier(tier_id)
	_update_facing_visual()


func configure_tier(new_tier: String, city_tint: Color = Color.WHITE) -> void:
	tier_id = new_tier if TIER_CONFIGS.has(new_tier) else "thug"
	var cfg: Dictionary = TIER_CONFIGS[tier_id]
	var sc := float(cfg["scale"])
	max_hp = float(cfg["max_hp"])
	hp = max_hp
	max_poise = float(cfg["poise_max"])
	poise = max_poise
	move_speed = float(cfg["move_speed"])
	attack_damage = float(cfg["attack_damage"])
	score_value = int(cfg["score"])

	var custom_glb := String(cfg.get("glb", ""))
	if not custom_glb.is_empty():
		if _rig_root:
			_rig_root.queue_free()
		_rig_root = GlbLoader.instantiate_glb(custom_glb)
		_visual_pivot.add_child(_rig_root)
		_anim = GlbLoader.find_anim_player(_rig_root)

	if _visual_pivot:
		_visual_pivot.scale = Vector3.ONE * sc
	if _hurtbox:
		_hurtbox.setup(self, false, Vector3(0.86 * sc, 1.85 * sc, 0.90 * sc), 0.92 * sc)

	_enemy_move.damage = attack_damage
	_enemy_move.hitstop_frames = 5 if tier_id == "bruiser" else 3
	_enemy_move.aoe_corridor_box = Vector3(1.55 * sc, 1.3 * sc, 1.15 * sc)

	# Recolor shared enemy_base.glb surfaces cleanly per tier + subtle city tint
	var jacket_c: Color = (cfg["jacket_color"] as Color).lerp(city_tint, 0.18)
	var pants_c: Color = cfg["pants_color"]
	var accent_c: Color = cfg["accent_color"]
	_apply_palette_override(jacket_c, pants_c, accent_c)


func _apply_palette_override(jacket_c: Color, pants_c: Color, accent_c: Color) -> void:
	if _rig_root == null:
		return
	for child in _rig_root.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi.mesh == null:
			continue
		for s_idx in range(mi.mesh.get_surface_count()):
			var orig_mat := mi.mesh.surface_get_material(s_idx)
			var mname := orig_mat.resource_name if orig_mat else ""
			var mat := StandardMaterial3D.new()
			mat.roughness = 0.58
			if "Jacket" in mname:
				mat.albedo_color = jacket_c
			elif "Pants" in mname:
				mat.albedo_color = pants_c
			elif "Accent" in mname:
				mat.albedo_color = accent_c
				mat.emission_enabled = true
				mat.emission = accent_c
				mat.emission_energy_multiplier = 1.35
			else:
				continue
			mi.set_surface_override_material(s_idx, mat)


func _build_overhead_hp_bar() -> void:
	_hp_bar_root = Node3D.new()
	_hp_bar_root.position = Vector3(0.0, 2.25, 0.0)
	_hp_bar_root.visible = false
	add_child(_hp_bar_root)

	var bg := MeshInstance3D.new()
	var bg_box := BoxMesh.new()
	bg_box.size = Vector3(0.95, 0.09, 0.03)
	bg.mesh = bg_box
	var bg_mat := StandardMaterial3D.new()
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_mat.albedo_color = Color(0.08, 0.08, 0.12, 0.9)
	bg.material_override = bg_mat
	_hp_bar_root.add_child(bg)

	_hp_bar_fill = MeshInstance3D.new()
	var fg_box := BoxMesh.new()
	fg_box.size = Vector3(0.91, 0.065, 0.04)
	_hp_bar_fill.mesh = fg_box
	var fg_mat := StandardMaterial3D.new()
	fg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fg_mat.albedo_color = Color("#FF1E42")
	_hp_bar_fill.material_override = fg_mat
	_hp_bar_root.add_child(_hp_bar_fill)


func _update_hp_bar() -> void:
	if _hp_bar_root == null:
		return
	_hp_bar_root.visible = hp < max_hp and hp > 0.0
	var ratio := clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0)
	_hp_bar_fill.scale.x = maxf(ratio, 0.001)
	_hp_bar_fill.position.x = -0.455 * (1.0 - ratio)


func _physics_process(delta: float) -> void:
	if HitstopManager and HitstopManager.is_frozen():
		return

	if _is_dead:
		_death_safety_timer += delta
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		else:
			if not _death_landed:
				_death_landed = true
			velocity.y = 0.0
			velocity.x = move_toward(velocity.x, 0.0, 24.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 24.0 * delta)
		move_and_slide()
		if _death_landed:
			_death_ground_timer += delta
			if _death_ground_timer >= 0.70:
				queue_free()
		elif _death_safety_timer >= 3.0:
			queue_free()
		return

	if _attack_cooldown > 0.0:
		_attack_cooldown -= delta

	if _hitstun_timer > 0.0:
		_hitstun_timer -= delta
		if not is_on_floor():
			velocity.y -= GRAVITY * 0.78 * delta # Floatier juggle gravity for juicy aerial combos!
		else:
			velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 18.0 * delta)
		move_and_slide()
		_check_wall_and_ground_bounces()
		_clamp_corridor()
		return

	_ground_bounced = false
	_wall_bounced = false

	if _is_attacking:
		_tick_attack(delta)
		move_and_slide()
		_clamp_corridor()
		return

	_tick_ai_pursuit(delta)
	move_and_slide()
	_clamp_corridor()


func _tick_ai_pursuit(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		_play_anim(&"idle_fight_stance")
		return

	var to_ply := player.global_position - global_position
	facing_sign = 1.0 if to_ply.x >= 0.0 else -1.0
	_update_facing_visual()

	var desired_dist_x := 4.8 if tier_id == "cult_elite" else 1.35
	var target_pos := Vector3(
		player.global_position.x - facing_sign * desired_dist_x,
		global_position.y,
		clampf(player.global_position.z + flank_slot_offset.z, CORRIDOR_Z_MIN + 0.3, CORRIDOR_Z_MAX - 0.3)
	)
	var diff := target_pos - global_position
	var dist_x := absf(to_ply.x)
	var dist_z := absf(to_ply.z)

	if _attack_cooldown <= 0.0 and dist_z < 0.85:
		if tier_id == "cult_elite" and dist_x >= 2.8 and dist_x <= 7.8:
			_begin_ranged_cast()
			return
		elif dist_x <= 1.85:
			_begin_melee_attack()
			return

	var dir_xz := Vector2(diff.x, diff.z)
	if dir_xz.length() > 0.25:
		dir_xz = dir_xz.normalized()
		velocity.x = move_toward(velocity.x, dir_xz.x * move_speed, 22.0 * delta)
		velocity.z = move_toward(velocity.z, dir_xz.y * move_speed * 0.8, 22.0 * delta)
		_play_anim(&"walk_forward", 1.05)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
		_play_anim(&"idle_fight_stance", 1.0)

	if not is_on_floor():
		velocity.y -= GRAVITY * delta


func _begin_melee_attack() -> void:
	_is_attacking = true
	_attack_timer = 0.0
	_hit_registry.clear()
	velocity.x = facing_sign * (3.8 if tier_id == "bruiser" else 1.8)
	if tier_id == "bruiser":
		_play_anim(&"heavy_ground", 0.95)
		if HitstopManager:
			HitstopManager.spawn_ground_telegraph(global_position + Vector3(facing_sign * 1.1, 0.0, 0.0), Vector2(1.8, 1.2), 0.24)
	else:
		_play_anim(&"light_1", 1.05)


func _begin_ranged_cast() -> void:
	_is_attacking = true
	_attack_timer = 0.0
	_hit_registry.clear()
	velocity = Vector3.ZERO
	_play_anim(&"ranged_cast", 1.05)
	if HitstopManager:
		HitstopManager.spawn_ground_telegraph(global_position + Vector3(facing_sign * 3.0, 0.0, 0.0), Vector2(5.5, 0.65), 0.28)


func _tick_attack(delta: float) -> void:
	_attack_timer += delta
	velocity.x = move_toward(velocity.x, 0.0, 16.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 16.0 * delta)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	if tier_id == "cult_elite" and _anim and _anim.current_animation == &"ranged_cast":
		if _attack_timer >= 0.30 and not _hit_registry.has("shot"):
			_hit_registry["shot"] = true
			var orb := EnemyProjectile.new()
			orb.attacker = self
			orb.damage = attack_damage
			orb.velocity = Vector3(facing_sign * 8.6, 0.0, 0.0)
			get_parent().add_child(orb)
			orb.global_position = global_position + Vector3(facing_sign * 0.7, 1.15, 0.0)
		if _attack_timer >= 0.62:
			_finish_attack(1.35)
		return

	var windup := 0.28 if tier_id == "bruiser" else 0.18
	var active_end := windup + 0.14
	if _attack_timer >= windup and _attack_timer < active_end:
		_hitbox.position = Vector3(facing_sign * 0.95, 1.0, 0.0)
		if not _hitbox.monitoring:
			_hitbox.activate(_enemy_move, 1.0, facing_sign, Color("#FF1E42"), _hit_registry)
	else:
		_hitbox.deactivate()

	if _attack_timer >= active_end + 0.22:
		_finish_attack(randf_range(0.85, 1.35))


func _finish_attack(cd: float) -> void:
	_hitbox.deactivate()
	_is_attacking = false
	_attack_cooldown = cd


func on_parried(armor_shatter: float) -> void:
	_finish_attack(1.5)
	poise = maxf(0.0, poise - armor_shatter)
	_hitstun_timer = 0.85
	velocity = Vector3(-facing_sign * 4.5, 2.5, 0.0)
	_play_anim(&"hit_light", 0.85)


func receive_hit(payload: Dictionary) -> Dictionary:
	if _is_dead:
		return {"connected": false}
	var move: AttackData = payload.get("attack_data", null)
	var dmg := float(payload.get("raw_damage", 35.0))
	var armor_dmg := float(payload.get("armor_damage", 25.0))
	var dir_sign := float(payload.get("facing_sign", 1.0))

	hp = maxf(0.0, hp - dmg)
	poise = maxf(0.0, poise - armor_dmg)
	_update_hp_bar()

	if hp <= 0.0:
		_die(dir_sign)
		return {"connected": true, "damage_dealt": dmg, "ko": true}

	if poise <= 0.0 or (move and (move.launches_airborne or move.crumples_block)):
		_finish_attack(0.95)
		poise = max_poise if poise <= 0.0 and not is_on_floor() else poise
		var kb := move.knockback_vel if move else Vector3(3.2, 0.0, 0.0)
		velocity.x = kb.x * dir_sign
		if move and move.launches_airborne:
			velocity.y = maxf(kb.y, 7.6 if is_on_floor() else 5.2)
			_hitstun_timer = 0.62
			_play_anim(&"hit_launch_arc", 1.1)
		elif not is_on_floor():
			velocity.y = maxf(kb.y, 4.4)
			_hitstun_timer = 0.50
			_play_anim(&"hit_launch_arc", 1.1)
		else:
			velocity.y = kb.y
			_hitstun_timer = 0.34
			_play_anim(&"hit_light", 1.15)
		if move and move.ground_bounces:
			_ground_bounced = true
		if move and move.wall_bounces:
			_wall_bounced = true

	return {"connected": true, "damage_dealt": dmg}


func _check_wall_and_ground_bounces() -> void:
	if _ground_bounced and is_on_floor() and velocity.y <= 0.0:
		_ground_bounced = false
		velocity.y = 7.8
		if HitstopManager:
			HitstopManager.spawn_shockwave_ring(global_position, Color("#FFD700"), 1.3, 0.20)
	if _wall_bounced and (global_position.x <= arena_x_min + 0.45 or global_position.x >= arena_x_max - 0.45):
		_wall_bounced = false
		velocity.x = -velocity.x * 0.72
		velocity.y = 6.2


func _die(dir_sign: float) -> void:
	_is_dead = true
	_death_landed = false
	_death_ground_timer = 0.0
	_death_safety_timer = 0.0
	_hitbox.deactivate()
	_hp_bar_root.visible = false
	set_deferred(&"collision_layer", 0)
	if _hurtbox:
		_hurtbox.deactivate()
	velocity = Vector3(dir_sign * 5.8, 4.2, 0.0)
	_play_anim(&"ko_collapse", 1.1)
	if SfxManager:
		SfxManager.play_3d("ko_boom", global_position, -2.5, 0.08)
	if GameManager:
		GameManager.add_score(score_value)
	defeated.emit(self, score_value, global_position)


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
