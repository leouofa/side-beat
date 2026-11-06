class_name PickupItem
extends Area3D
## Low-poly urban drop pickup with rotating halo ring:
##   - "feast"   : Lush Jade (#32FF7E), +30% Shared HP (+300 HP)
##   - "sparks"  : Royal Gold (#FFD700), +25% Pantheon Meter (+25 Meter)
##   - "bullion" : Arcade Cyan-Gold (#FFE066), +500 Score pts

var pickup_kind: String = "feast"
var _visual_root: Node3D
var _halo: MeshInstance3D
var _bob_time: float = 0.0


func setup_pickup(kind: String) -> void:
	pickup_kind = kind


func _ready() -> void:
	collision_layer = (1 << 6) # Layer 7: Pickup
	collision_mask = (1 << 1)  # Layer 2: PlayerBody
	monitoring = true
	monitorable = false

	var col := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.72
	col.shape = sph
	col.position = Vector3(0.0, 0.55, 0.0)
	add_child(col)

	_visual_root = Node3D.new()
	_visual_root.position = Vector3(0.0, 0.55, 0.0)
	add_child(_visual_root)

	var main_color := Color("#32FF7E")
	if pickup_kind == "sparks":
		main_color = Color("#FFD700")
	elif pickup_kind == "bullion":
		main_color = Color("#00D4FF")

	var core := MeshInstance3D.new()
	if pickup_kind == "feast":
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.28
		cyl.bottom_radius = 0.24
		cyl.height = 0.24
		cyl.radial_segments = 8
		core.mesh = cyl
	else:
		var prism := PrismMesh.new()
		prism.size = Vector3(0.42, 0.48, 0.42)
		core.mesh = prism

	var mat := StandardMaterial3D.new()
	mat.albedo_color = main_color
	mat.roughness = 0.28
	mat.emission_enabled = true
	mat.emission = main_color
	mat.emission_energy_multiplier = 1.6
	core.material_override = mat
	_visual_root.add_child(core)

	# Rotating low-poly halo ring per specs.yml
	_halo = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.38
	torus.outer_radius = 0.46
	torus.rings = 8
	torus.ring_segments = 5
	_halo.mesh = torus
	var hmat := StandardMaterial3D.new()
	hmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hmat.albedo_color = main_color.lightened(0.25)
	_halo.material_override = hmat
	_halo.rotation_degrees.x = 65.0
	_visual_root.add_child(_halo)

	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_bob_time += delta * 3.2
	if _visual_root:
		_visual_root.position.y = 0.55 + sin(_bob_time) * 0.10
		_visual_root.rotation.y += delta * 2.4
	if _halo:
		_halo.rotation.z += delta * 3.8


func _on_body_entered(body: Node3D) -> void:
	if not (body is SharedSoulPlayer):
		return
	var ply := body as SharedSoulPlayer
	match pickup_kind:
		"feast":
			ply.heal_shared_hp(SharedSoulPlayer.MAX_SHARED_HP * 0.30)
			if SfxManager:
				SfxManager.play_2d("pickup_hp", 0.0, 0.03)
			if HitstopManager:
				HitstopManager.spawn_shockwave_ring(global_position, Color("#32FF7E"), 1.5, 0.22)
		"sparks":
			ply.add_pantheon_meter(SharedSoulPlayer.MAX_PANTHEON_METER * 0.25)
			if SfxManager:
				SfxManager.play_2d("pickup_meter", 0.0, 0.03)
			if HitstopManager:
				HitstopManager.spawn_shockwave_ring(global_position, Color("#FFD700"), 1.5, 0.22)
		_:
			if GameManager:
				GameManager.add_score(500)
			if SfxManager:
				SfxManager.play_2d("pickup_gold", 0.0, 0.03)
			if HitstopManager:
				HitstopManager.spawn_shockwave_ring(global_position, Color("#00D4FF"), 1.3, 0.20)
	queue_free()
