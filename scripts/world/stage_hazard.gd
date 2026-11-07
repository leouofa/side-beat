class_name StageHazard
extends Area3D
## Environmental city hazards (NYC steam vents, Moscow ice slicks, Tokyo high-voltage arcs, Rome braziers).

var hazard_kind: String = "steam_vent"
var cycle_period: float = 3.8
var _timer: float = 0.0
var _telegraphed: bool = false


func setup_hazard(kind: String, phase_offset: float = 0.0) -> void:
	hazard_kind = kind
	_timer = phase_offset


func _ready() -> void:
	collision_layer = (1 << 7)
	collision_mask = (1 << 1) | (1 << 2)
	monitoring = true
	monitorable = false

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.4, 1.4, 2.2) if hazard_kind == "ice_slick" else Vector3(1.5, 1.8, 1.5)
	col.shape = box
	col.position = Vector3(0.0, 0.7, 0.0)
	add_child(col)

	var grate := MeshInstance3D.new()
	var gmesh := BoxMesh.new()
	gmesh.size = Vector3(2.4, 0.05, 2.2) if hazard_kind == "ice_slick" else Vector3(1.35, 0.06, 1.35)
	grate.mesh = gmesh
	var mat := StandardMaterial3D.new()
	if hazard_kind == "ice_slick":
		mat.albedo_color = Color(0.55, 0.88, 1.0, 0.65)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.roughness = 0.08
	else:
		mat.albedo_color = Color("#3D3D3D")
		mat.metallic = 0.65
	grate.material_override = mat
	grate.position = Vector3(0.0, 0.03, 0.0)
	add_child(grate)

	if hazard_kind == "ice_slick":
		body_entered.connect(_on_ice_entered)
		body_exited.connect(_on_ice_exited)


func _physics_process(delta: float) -> void:
	if hazard_kind == "ice_slick":
		return
	if HitstopManager and HitstopManager.is_frozen():
		return
	_timer += delta
	if _timer >= cycle_period - 0.55 and not _telegraphed:
		_telegraphed = true
		if HitstopManager:
			HitstopManager.spawn_ground_telegraph(global_position, Vector2(1.5, 1.5), 0.52)
	if _timer >= cycle_period:
		_timer = 0.0
		_telegraphed = false
		_erupt_jet()


func _erupt_jet() -> void:
	var jet_color := Color("#C8D6E5") if hazard_kind == "steam_vent" else Color("#00D4FF")
	if HitstopManager:
		HitstopManager.spawn_lightning_pillar(global_position, jet_color, 3.4, 0.42)
	for body in get_overlapping_bodies():
		if body is SharedSoulPlayer:
			var m := AttackData.new()
			m.damage = 28.0
			body.receive_hit({"attack_data": m, "raw_damage": 28.0, "facing_sign": -1.0})
		elif body.has_method("receive_hit"):
			var em := AttackData.new()
			em.launches_airborne = true
			em.knockback_vel = Vector3(1.5, 8.2, 0.0)
			body.receive_hit({"attack_data": em, "raw_damage": 40.0, "armor_damage": 35.0, "facing_sign": 1.0})


func _on_ice_entered(body: Node3D) -> void:
	if body is SharedSoulPlayer:
		(body as SharedSoulPlayer).surface_friction_scale = 0.22


func _on_ice_exited(body: Node3D) -> void:
	if body is SharedSoulPlayer:
		(body as SharedSoulPlayer).surface_friction_scale = 1.0
