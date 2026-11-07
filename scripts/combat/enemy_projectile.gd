class_name EnemyProjectile
extends Area3D
## Crimson high-contrast arcade projectile used by Cult Elites and ranged/zoner Bosses.

var velocity: Vector3 = Vector3(-8.5, 0.0, 0.0)
var lifetime: float = 3.2
var damage: float = 42.0
var attacker: Node = null
var _attack_data: AttackData


func _init() -> void:
	collision_layer = (1 << 4)
	collision_mask = (1 << 3)
	monitoring = true
	monitorable = false


func _ready() -> void:
	set_deferred(&"monitoring", true)
	set_deferred(&"monitorable", false)

	var col := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.34
	col.shape = sph
	add_child(col)

	var mesh_inst := MeshInstance3D.new()
	var ico := SphereMesh.new()
	ico.radius = 0.28
	ico.height = 0.56
	ico.radial_segments = 8
	ico.rings = 4
	mesh_inst.mesh = ico
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("#FF1E42")
	mesh_inst.material_override = mat
	add_child(mesh_inst)

	_attack_data = AttackData.new()
	_attack_data.damage = damage
	_attack_data.hitstop_frames = 3
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	if HitstopManager and HitstopManager.is_frozen():
		return
	global_position += velocity * delta
	rotation.y += 9.0 * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_area_entered(area: Area3D) -> void:
	if not (area is HurtBox3D):
		return
	var hurt := area as HurtBox3D
	if hurt.team != &"player":
		return
	_attack_data.damage = damage
	var res := hurt.receive_strike({
		"attacker": attacker,
		"attack_data": _attack_data,
		"raw_damage": damage,
		"armor_damage": 20.0,
		"facing_sign": signf(velocity.x),
		"hit_position": global_position,
		"spark_color": Color("#FF1E42"),
	})
	if res.get("connected", false) or res.get("parried", false):
		queue_free()
