class_name HitBox3D
extends Area3D
## Active-frame Strike Volume attached to BoneAttachment3D sockets or AOE emitters.

signal strike_landed(target_owner: Node, hit_result: Dictionary)

var attacker: Node = null
var team: StringName = &"player"
var attack_data: AttackData = null
var damage_scale: float = 1.0
var facing_sign: float = 1.0
var spark_color: Color = Color("#FFE066")
var _already_hit: Dictionary = {}
var _shape_node: CollisionShape3D
var _box_shape: BoxShape3D


func _init() -> void:
	monitoring = false
	monitorable = false


func _ready() -> void:
	_shape_node = CollisionShape3D.new()
	_box_shape = BoxShape3D.new()
	_box_shape.size = Vector3(1.1, 0.9, 1.0)
	_shape_node.shape = _box_shape
	_shape_node.disabled = true
	add_child(_shape_node)
	area_entered.connect(_on_area_entered)


func configure_team_layers(is_player_team: bool) -> void:
	team = &"player" if is_player_team else &"enemy"
	collision_layer = (1 << 3) if is_player_team else (1 << 4)
	# Player hitboxes scan EnemyHurtBox (layer 5 -> bit 4) + DestructibleProp (layer 6 -> bit 5)
	if is_player_team:
		collision_mask = (1 << 4) | (1 << 5)
	else:
		collision_mask = (1 << 3)


func activate(move: AttackData, dmg_mult: float, dir_sign: float, color: Color, shared_hit_registry: Dictionary) -> void:
	attack_data = move
	damage_scale = dmg_mult
	facing_sign = dir_sign
	spark_color = color
	_already_hit = shared_hit_registry
	if _box_shape and move:
		_box_shape.size = move.aoe_corridor_box if move.aoe_corridor_box.length_squared() > 0.01 else move.hitbox_extents
	if _shape_node:
		_shape_node.disabled = false
	monitoring = true
	# Immediate overlap sweep in case target is already inside volume on frame 1 of Active
	call_deferred("_check_initial_overlaps")


func deactivate() -> void:
	monitoring = false
	if _shape_node:
		_shape_node.disabled = true


func _check_initial_overlaps() -> void:
	if not monitoring:
		return
	for area in get_overlapping_areas():
		_on_area_entered(area)


func _on_area_entered(area: Area3D) -> void:
	if not monitoring or attack_data == null:
		return
	if not (area is HurtBox3D):
		return
	var hurt := area as HurtBox3D
	if hurt.team == team or hurt.owner_actor == null or hurt.owner_actor == attacker:
		return
	var id := hurt.owner_actor.get_instance_id()
	if _already_hit.has(id):
		return
	_already_hit[id] = true

	var hit_pos := (global_position + hurt.global_position) * 0.5
	var payload := {
		"attacker": attacker,
		"attack_data": attack_data,
		"raw_damage": attack_data.damage * damage_scale,
		"armor_damage": attack_data.armor_damage * damage_scale,
		"facing_sign": facing_sign,
		"hit_position": hit_pos,
		"spark_color": spark_color,
	}
	var res: Dictionary = hurt.receive_strike(payload)
	if res.get("connected", false):
		strike_landed.emit(hurt.owner_actor, res)
