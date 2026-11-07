class_name ProceduralCityGenerator
extends Node3D
## Generates a 7-chunk (7 x 24.0m = 168m) low-poly 2.5D belt-scroller urban stage
## bounded to corridor Z in [-3.2m, +3.2m], complete with sub-biome facades, neon signs,
## parallax skyline, destructible urban props, stage hazards, and lock-in battle zones.

const CHUNK_LENGTH_M := 24.0
const CHUNKS_COUNT := 7

var generated_zones: Array[Dictionary] = []
var total_stage_length_m: float = CHUNK_LENGTH_M * CHUNKS_COUNT


func generate_city_stage(stage_num: int, seed_val: int = 0) -> Dictionary:
	for c in get_children():
		c.queue_free()
	generated_zones.clear()

	var cfg: Dictionary = CityStageCatalog.STAGES.get(stage_num, CityStageCatalog.STAGES[1])
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val if seed_val != 0 else (stage_num * 1337 + 42)

	_build_world_environment_and_lights(cfg)
	_build_continuous_street_collider()

	var biomes: Array = cfg["sub_biomes"]
	var mid_boss_id := String(cfg.get("mid_boss_id", ""))
	var stage_boss_id := String(cfg.get("stage_boss_id", "beebo"))

	for idx in range(CHUNKS_COUNT):
		var x_start := float(idx) * CHUNK_LENGTH_M
		var x_center := x_start + CHUNK_LENGTH_M * 0.5
		var biome_idx := clampi(int(floor(float(idx) / 2.0)), 0, biomes.size() - 1)
		var biome_name := String(biomes[biome_idx])
		_build_chunk_geometry(idx, x_start, cfg, biome_idx, rng)

		# Encounter Zone Layout across chunks 1, 2, 3, 4, 6
		if idx == 1:
			generated_zones.append({
				"zone_type": "wave",
				"wave_index": 0,
				"sub_biome": biome_name,
				"trigger_x": x_center - 2.5,
				"center_x": x_center,
				"min_x": x_start + 1.2,
				"max_x": x_start + CHUNK_LENGTH_M - 1.2,
				"budget": ["thug", "thug", "thug", "bruiser"],
			})
		elif idx == 2:
			generated_zones.append({
				"zone_type": "wave",
				"wave_index": 1,
				"sub_biome": biome_name,
				"trigger_x": x_center - 2.5,
				"center_x": x_center,
				"min_x": x_start + 1.2,
				"max_x": x_start + CHUNK_LENGTH_M - 1.2,
				"budget": ["thug", "thug", "bruiser", "cult_elite", "thug"],
			})
		elif idx == 3:
			if not mid_boss_id.is_empty():
				generated_zones.append({
					"zone_type": "mid_boss",
					"boss_id": mid_boss_id,
					"sub_biome": biome_name,
					"trigger_x": x_center - 2.0,
					"center_x": x_center,
					"min_x": x_start + 1.5,
					"max_x": x_start + CHUNK_LENGTH_M - 1.5,
				})
			else:
				generated_zones.append({
					"zone_type": "wave",
					"wave_index": 1,
					"sub_biome": biome_name,
					"trigger_x": x_center - 2.5,
					"center_x": x_center,
					"min_x": x_start + 1.2,
					"max_x": x_start + CHUNK_LENGTH_M - 1.2,
					"budget": ["bruiser", "cult_elite", "bruiser", "cult_elite"],
				})
		elif idx == 4:
			generated_zones.append({
				"zone_type": "wave",
				"wave_index": 2,
				"sub_biome": biome_name,
				"trigger_x": x_center - 2.5,
				"center_x": x_center,
				"min_x": x_start + 1.2,
				"max_x": x_start + CHUNK_LENGTH_M - 1.2,
				"budget": ["thug", "bruiser", "cult_elite", "bruiser", "cult_elite"],
			})
		elif idx == 6:
			generated_zones.append({
				"zone_type": "stage_boss",
				"boss_id": stage_boss_id,
				"sub_biome": biome_name,
				"trigger_x": x_center - 2.0,
				"center_x": x_center,
				"min_x": x_start + 1.5,
				"max_x": x_start + CHUNK_LENGTH_M - 1.5,
			})

	return {
		"city": cfg["city"],
		"stage": stage_num,
		"zones": generated_zones,
		"length_m": total_stage_length_m,
		"city_tint": cfg["neon_a"],
	}


func _build_world_environment_and_lights(cfg: Dictionary) -> void:
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = cfg["sky_top"]
	sky_mat.sky_horizon_color = cfg["sky_horizon"]
	sky_mat.ground_horizon_color = cfg["sky_horizon"]
	sky_mat.ground_bottom_color = cfg["asphalt"]
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = (cfg["sky_horizon"] as Color).lightened(0.32)
	env.ambient_light_energy = 0.72
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.12
	env.fog_enabled = true
	env.fog_light_color = cfg["sky_horizon"]
	env.fog_density = 0.0045
	env_node.environment = env
	add_child(env_node)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color("#FFF4E0")
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
	add_child(sun)


func _build_continuous_street_collider() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.name = "StreetFloorBody"
	floor_body.collision_layer = (1 << 0)
	floor_body.collision_mask = 0
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(total_stage_length_m + 32.0, 1.0, 10.0)
	col.shape = box
	col.position = Vector3(total_stage_length_m * 0.5, -0.5, 0.0)
	floor_body.add_child(col)
	add_child(floor_body)


func _build_chunk_geometry(chunk_idx: int, x_start: float, cfg: Dictionary, biome_idx: int, rng: RandomNumberGenerator) -> void:
	var chunk_root := Node3D.new()
	chunk_root.name = "Chunk_%d" % chunk_idx
	chunk_root.position = Vector3(x_start, 0.0, 0.0)
	add_child(chunk_root)

	# Asphalt belt road [-3.3, +3.3]
	var road := MeshInstance3D.new()
	var rbox := BoxMesh.new()
	rbox.size = Vector3(CHUNK_LENGTH_M, 0.16, 6.8)
	road.mesh = rbox
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = (cfg["asphalt"] as Color).lightened(0.04 * float(biome_idx))
	rmat.roughness = 0.85
	road.material_override = rmat
	road.position = Vector3(CHUNK_LENGTH_M * 0.5, -0.08, 0.0)
	chunk_root.add_child(road)

	# Center dashed crosswalk/lane stripes
	for s in range(4):
		var stripe := MeshInstance3D.new()
		var sbox := BoxMesh.new()
		sbox.size = Vector3(2.8, 0.02, 0.20)
		stripe.mesh = sbox
		var smat := StandardMaterial3D.new()
		smat.albedo_color = Color("#F5C542")
		stripe.material_override = smat
		stripe.position = Vector3(3.0 + float(s) * 6.0, 0.01, 0.0)
		chunk_root.add_child(stripe)

	# Back & Front sidewalk curbs
	var sw_mat := StandardMaterial3D.new()
	sw_mat.albedo_color = cfg["sidewalk"]
	sw_mat.roughness = 0.78

	var back_walk := MeshInstance3D.new()
	var bw_box := BoxMesh.new()
	bw_box.size = Vector3(CHUNK_LENGTH_M, 0.24, 3.2)
	back_walk.mesh = bw_box
	back_walk.material_override = sw_mat
	back_walk.position = Vector3(CHUNK_LENGTH_M * 0.5, 0.04, -4.9)
	chunk_root.add_child(back_walk)

	var front_curb := MeshInstance3D.new()
	var fc_box := BoxMesh.new()
	fc_box.size = Vector3(CHUNK_LENGTH_M, 0.18, 1.2)
	front_curb.mesh = fc_box
	front_curb.material_override = sw_mat
	front_curb.position = Vector3(CHUNK_LENGTH_M * 0.5, 0.02, 3.95)
	chunk_root.add_child(front_curb)

	# Dark urban foreground apron so bottom viewport edge stays grounded
	var fg_apron := MeshInstance3D.new()
	var ap_box := BoxMesh.new()
	ap_box.size = Vector3(CHUNK_LENGTH_M, 2.0, 6.0)
	fg_apron.mesh = ap_box
	var ap_mat := StandardMaterial3D.new()
	ap_mat.albedo_color = (cfg["asphalt"] as Color).darkened(0.38)
	ap_mat.roughness = 0.95
	fg_apron.material_override = ap_mat
	fg_apron.position = Vector3(CHUNK_LENGTH_M * 0.5, -1.05, 7.2)
	chunk_root.add_child(fg_apron)

	# Stylized Low-Poly City Facades, Lit Window Grids & Neon Signs along background (-Z)
	var neon_colors: Array[Color] = [cfg["neon_a"], cfg["neon_b"]]
	var win_lit_mat := StandardMaterial3D.new()
	win_lit_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	win_lit_mat.albedo_color = Color("#FFE89E")
	var win_dim_mat := StandardMaterial3D.new()
	win_dim_mat.albedo_color = Color("#121722")

	for b_i in range(3):
		var bx := 4.0 + float(b_i) * 8.0
		var bw := rng.randf_range(6.4, 7.6)
		var bh := rng.randf_range(8.5, 13.5)
		var bldg := MeshInstance3D.new()
		var bbox := BoxMesh.new()
		bbox.size = Vector3(bw, bh, 3.8)
		bldg.mesh = bbox
		var bmat := StandardMaterial3D.new()
		bmat.albedo_color = cfg["facade_a"] if (b_i + chunk_idx) % 2 == 0 else cfg["facade_b"]
		bmat.roughness = 0.72
		bldg.material_override = bmat
		bldg.position = Vector3(bx, bh * 0.5, -7.8)
		chunk_root.add_child(bldg)

		# Lit low-poly apartment/office window rows
		for wy_i in range(3):
			var wy := 4.3 + float(wy_i) * 1.45
			if wy + 0.7 > bh:
				break
			for wx_i in range(-1, 2):
				var win := MeshInstance3D.new()
				var wbox := BoxMesh.new()
				wbox.size = Vector3(1.1, 0.78, 0.08)
				win.mesh = wbox
				win.material_override = win_lit_mat if rng.randf() > 0.35 else win_dim_mat
				win.position = Vector3(bx + float(wx_i) * 1.75, wy, -5.88)
				chunk_root.add_child(win)

		# Glowing neon storefront signboard
		var neon_c := neon_colors[(b_i + chunk_idx) % 2]
		var sign_mesh := MeshInstance3D.new()
		var sn_box := BoxMesh.new()
		sn_box.size = Vector3(bw * 0.62, 0.65, 0.18)
		sign_mesh.mesh = sn_box
		var nmat := StandardMaterial3D.new()
		nmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		nmat.albedo_color = neon_c
		sign_mesh.material_override = nmat
		sign_mesh.position = Vector3(bx, 3.1, -5.8)
		chunk_root.add_child(sign_mesh)

		# Spawn Doorway arch on middle facade
		if b_i == 1:
			var door := MeshInstance3D.new()
			var dbox := BoxMesh.new()
			dbox.size = Vector3(1.8, 2.5, 0.25)
			door.mesh = dbox
			var dmat := StandardMaterial3D.new()
			dmat.albedo_color = Color("#090B10")
			door.material_override = dmat
			door.position = Vector3(bx, 1.35, -5.85)
			chunk_root.add_child(door)

	# Distant Low-Poly Skyline Towers for urban depth
	for sk_i in range(2):
		var tower := MeshInstance3D.new()
		var tbox := BoxMesh.new()
		var th := rng.randf_range(18.0, 32.0)
		tbox.size = Vector3(9.0, th, 6.0)
		tower.mesh = tbox
		var tmat := StandardMaterial3D.new()
		tmat.albedo_color = (cfg["sky_top"] as Color).lightened(0.10)
		tower.material_override = tmat
		tower.position = Vector3(6.0 + float(sk_i) * 12.0, th * 0.45 - 3.0, -19.5 - float(sk_i) * 3.0)
		chunk_root.add_child(tower)

	# Streetlamps with warm/neon OmniLight3D pools
	for lx in [5.5, 18.5]:
		var pole := MeshInstance3D.new()
		var pcyl := CylinderMesh.new()
		pcyl.top_radius = 0.06
		pcyl.bottom_radius = 0.09
		pcyl.height = 4.2
		pcyl.radial_segments = 6
		pole.mesh = pcyl
		pole.material_override = sw_mat
		pole.position = Vector3(lx, 2.1, -3.55)
		chunk_root.add_child(pole)

		var omni := OmniLight3D.new()
		omni.light_color = neon_colors[chunk_idx % 2].lightened(0.35)
		omni.light_energy = 1.4
		omni.omni_range = 9.5
		omni.position = Vector3(lx, 4.1, -2.8)
		chunk_root.add_child(omni)

	# Destructible Urban Props (2 per chunk, guaranteed Feast before Stage Boss on chunk 5!)
	var props_list: Array = cfg["props"]
	for p_i in range(2):
		var prop := DestructibleProp.new()
		var kind := String(props_list[(p_i + chunk_idx) % props_list.size()])
		var force_drop := "feast" if (chunk_idx == 5 and p_i == 0) else ("sparks" if (chunk_idx == 5 and p_i == 1) else "")
		prop.setup_prop(kind, force_drop)
		prop.position = Vector3(6.5 + float(p_i) * 11.0, 0.0, -2.55 if p_i == 0 else 2.45)
		chunk_root.add_child(prop)

	# Environmental Stage Hazard on wave chunks (chunks 1, 2, 4)
	if chunk_idx in [1, 2, 4]:
		var haz := StageHazard.new()
		haz.setup_hazard(String(cfg["hazard"]), float(chunk_idx) * 0.9)
		haz.position = Vector3(12.0, 0.0, rng.randf_range(-1.4, 1.4))
		chunk_root.add_child(haz)
