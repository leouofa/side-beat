class_name FighterShaderHelper
extends RefCounted
## Attaches and drives Layer 2 3D Fighter Surface Shaders:
##   - Hit-Strike Emission Flash (2-3 frames during hitstop)
##   - Pantheon Fresnel Rim Aura & Boss Super-Armor / Enrage Pulse
##   - Neon Voxel / Cyber-Ember KO Dissolve

const SURFACE_FX_SHADER := preload("res://shaders/fighter_surface_fx.gdshader")
const KO_DISSOLVE_SHADER := preload("res://shaders/fighter_ko_dissolve.gdshader")


static func attach_surface_fx(
	rig_root: Node3D,
	rim_color: Color,
	rim_strength: float = 0.85,
	armor_ratio: float = 0.0
) -> ShaderMaterial:
	var fx_mat := ShaderMaterial.new()
	fx_mat.shader = SURFACE_FX_SHADER
	fx_mat.set_shader_parameter("rim_color", rim_color)
	fx_mat.set_shader_parameter("rim_strength", rim_strength)
	fx_mat.set_shader_parameter("armor_ratio", clampf(armor_ratio, 0.0, 1.0))
	fx_mat.set_shader_parameter("enrage_factor", 0.0)
	fx_mat.set_shader_parameter("hit_flash_amount", 0.0)

	if rig_root == null:
		return fx_mat

	for child in rig_root.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi.mesh == null:
			continue
		mi.material_overlay = fx_mat

	return fx_mat


static func trigger_hit_flash(
	owner_node: Node,
	fx_mat: ShaderMaterial,
	flash_color: Color = Color(1.0, 0.96, 0.82, 1.0),
	duration: float = 0.11
) -> void:
	if fx_mat == null or owner_node == null or not owner_node.is_inside_tree():
		return
	fx_mat.set_shader_parameter("hit_flash_color", flash_color)
	fx_mat.set_shader_parameter("hit_flash_amount", 1.0)
	var tw := owner_node.create_tween()
	tw.tween_method(
		func(val: float) -> void:
			if fx_mat:
				fx_mat.set_shader_parameter("hit_flash_amount", val),
		1.0,
		0.0,
		duration
	)


static func update_armor_and_enrage(
	fx_mat: ShaderMaterial,
	armor: float,
	max_armor: float,
	enraged: bool = false
) -> void:
	if fx_mat == null:
		return
	var ratio := clampf(armor / maxf(max_armor, 1.0), 0.0, 1.0) if max_armor > 0.0 else 0.0
	fx_mat.set_shader_parameter("armor_ratio", ratio)
	fx_mat.set_shader_parameter("enrage_factor", 1.0 if enraged else 0.0)


static func trigger_ko_dissolve(
	owner_node: Node,
	rig_root: Node3D,
	burn_color: Color = Color("#FF1E8A"),
	duration: float = 0.65
) -> ShaderMaterial:
	var dis_mat := ShaderMaterial.new()
	dis_mat.shader = KO_DISSOLVE_SHADER
	dis_mat.set_shader_parameter("burn_color", burn_color)
	dis_mat.set_shader_parameter("dissolve_progress", 0.0)

	if rig_root != null:
		for child in rig_root.find_children("*", "MeshInstance3D", true, false):
			var mi := child as MeshInstance3D
			if mi.mesh == null:
				continue
			var active_mat := mi.get_active_material(0)
			if active_mat is StandardMaterial3D:
				dis_mat.set_shader_parameter("base_color", (active_mat as StandardMaterial3D).albedo_color)
			for s_idx in range(mi.mesh.get_surface_count()):
				mi.set_surface_override_material(s_idx, null)
			mi.material_overlay = null
			mi.material_override = dis_mat

	if owner_node != null and owner_node.is_inside_tree():
		var tw := owner_node.create_tween()
		tw.tween_method(
			func(val: float) -> void:
				if dis_mat:
					dis_mat.set_shader_parameter("dissolve_progress", val),
			0.0,
			1.0,
			duration
		)

	return dis_mat


static func clear_surface_fx(rig_root: Node3D) -> void:
	if rig_root == null:
		return
	for child in rig_root.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi == null:
			continue
		if mi.mesh:
			for s_idx in range(mi.mesh.get_surface_count()):
				mi.set_surface_override_material(s_idx, null)
		mi.material_overlay = null
		mi.material_override = null
