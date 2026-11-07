class_name DestructibleProp
extends StaticBody3D
## Smashable low-poly urban prop (fire hydrants, taxi barricades, arcade cabinets, cafe tables,
## oil drums, phone booths, vending machines, marble columns) dropping pickups & hazard bursts.

var prop_kind: String = "fire_hydrant"
var hp: float = 55.0
var drop_kind: String = "bullion"
var _hurtbox: HurtBox3D
var _mesh_root: Node3D
var _destroyed: bool = false


func setup_prop(kind: String, guaranteed_drop: String = "") -> void:
	prop_kind = kind
	if not guaranteed_drop.is_empty():
		drop_kind = guaranteed_drop
	else:
		var r := randf()
		if r < 0.30:
			drop_kind = "feast"
		elif r < 0.65:
			drop_kind = "sparks"
		else:
			drop_kind = "bullion"


func _ready() -> void:
	collision_layer = (1 << 5)
	collision_mask = 0

	_mesh_root = Node3D.new()
	add_child(_mesh_root)
	_build_prop_visual()

	_hurtbox = HurtBox3D.new()
	add_child(_hurtbox)
	_hurtbox.setup(self, false, Vector3(1.15, 1.4, 1.15), 0.7, true)


func _build_prop_visual() -> void:
	var primary := Color("#E74C3C")
	var accent := Color("#F1C40F")
	var sz := Vector3(0.55, 0.95, 0.55)
	var use_cyl := false

	match prop_kind:
		"fire_hydrant":
			primary = Color("#E74C3C")
			accent = Color("#BDC3C7")
			sz = Vector3(0.42, 0.85, 0.42)
			use_cyl = true
		"taxi_barricade":
			primary = Color("#F1C40F")
			accent = Color("#1E272E")
			sz = Vector3(1.25, 0.78, 0.45)
		"arcade_cabinet":
			primary = Color("#2E86DE")
			accent = Color("#FF1E8A")
			sz = Vector3(0.75, 1.55, 0.68)
		"cafe_table":
			primary = Color("#D35400")
			accent = Color("#F5CBA7")
			sz = Vector3(0.85, 0.78, 0.85)
			use_cyl = true
		"oil_drum":
			primary = Color("#C0392B")
			accent = Color("#F39C12")
			sz = Vector3(0.58, 1.05, 0.58)
			use_cyl = true
		"phone_booth":
			primary = Color("#C0392B")
			accent = Color("#ECF0F1")
			sz = Vector3(0.82, 1.85, 0.82)
		"vending_machine":
			primary = Color("#00D4FF")
			accent = Color("#FFFFFF")
			sz = Vector3(0.85, 1.72, 0.65)
		"marble_column":
			primary = Color("#DCDDE1")
			accent = Color("#D4AC0D")
			sz = Vector3(0.66, 1.45, 0.66)
			use_cyl = true
		_:
			primary = Color("#8E44AD")
			accent = Color("#00D4FF")

	var mi := MeshInstance3D.new()
	if use_cyl:
		var c := CylinderMesh.new()
		c.top_radius = sz.x * 0.5
		c.bottom_radius = sz.x * 0.54
		c.height = sz.y
		c.radial_segments = 8
		mi.mesh = c
	else:
		var b := BoxMesh.new()
		b.size = sz
		mi.mesh = b
	var mat := StandardMaterial3D.new()
	mat.albedo_color = primary
	mat.roughness = 0.55
	mi.material_override = mat
	mi.position = Vector3(0.0, sz.y * 0.5, 0.0)
	_mesh_root.add_child(mi)

	var cap := MeshInstance3D.new()
	var cap_box := BoxMesh.new()
	cap_box.size = Vector3(sz.x * 1.08, 0.14, sz.z * 1.08)
	cap.mesh = cap_box
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = accent
	cmat.emission_enabled = (prop_kind == "arcade_cabinet" or prop_kind == "vending_machine")
	cmat.emission = accent
	cap.material_override = cmat
	cap.position = Vector3(0.0, sz.y * 0.78, 0.0)
	_mesh_root.add_child(cap)


func receive_hit(payload: Dictionary) -> Dictionary:
	if _destroyed:
		return {"connected": false}
	var dmg := float(payload.get("raw_damage", 40.0))
	hp -= dmg
	if HitstopManager:
		HitstopManager.spawn_hit_spark(global_position + Vector3(0.0, 0.7, 0.0), Color("#FFE066"), 0.85)
	if hp <= 0.0:
		_shatter()
	else:
		var tw := create_tween()
		tw.tween_property(_mesh_root, "scale", Vector3(1.18, 0.85, 1.18), 0.05)
		tw.tween_property(_mesh_root, "scale", Vector3.ONE, 0.07)
	return {"connected": true, "damage_dealt": dmg}


func _shatter() -> void:
	_destroyed = true
	if _hurtbox:
		_hurtbox.deactivate()
	if SfxManager:
		SfxManager.play_3d("prop_smash", global_position, 0.0, 0.08)

	# Special urban prop reactions per specs.yml!
	if prop_kind == "fire_hydrant":
		if HitstopManager:
			HitstopManager.spawn_lightning_pillar(global_position, Color("#00D4FF"), 4.2, 0.42)
		_knockback_nearby_enemies(3.0, 45.0, 9.5)
	elif prop_kind == "oil_drum":
		if HitstopManager:
			HitstopManager.spawn_shockwave_ring(global_position, Color("#FF7A00"), 3.8, 0.35)
		_knockback_nearby_enemies(3.8, 110.0, 8.5)
	else:
		if HitstopManager:
			HitstopManager.spawn_shockwave_ring(global_position, Color("#FFE066"), 1.6, 0.20)

	var drop := PickupItem.new()
	drop.setup_pickup(drop_kind)
	get_parent().add_child(drop)
	drop.global_position = Vector3(global_position.x, 0.05, clampf(global_position.z, -2.8, 2.8))
	queue_free()


func _knockback_nearby_enemies(radius: float, bonus_dmg: float, up_vel: float) -> void:
	var fake_move := AttackData.new()
	fake_move.launches_airborne = true
	fake_move.knockback_vel = Vector3(3.5, up_vel, 0.0)
	for n in get_tree().get_nodes_in_group("enemies"):
		if n is Node3D and is_instance_valid(n) and n.global_position.distance_to(global_position) <= radius:
			if n.has_method("receive_hit"):
				var dir_s := signf(n.global_position.x - global_position.x)
				if dir_s == 0.0:
					dir_s = 1.0
				n.receive_hit({"attack_data": fake_move, "raw_damage": bonus_dmg, "armor_damage": 50.0, "facing_sign": dir_s})
