extends Node
## Frame-accurate arcade Hitstop (3-7 frames @ 60Hz), slow-mo (Perfect Parry / Boss KO),
## camera trauma shake, and crisp low-poly 3D hit-sparks, morph bursts, and telegraph decals.

signal camera_shake_requested(trauma: float)

var _hitstop_timer: float = 0.0
var _slowmo_timer: float = 0.0
var _vfx_root: Node3D = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func register_vfx_root(node: Node3D) -> void:
	_vfx_root = node


func is_frozen() -> bool:
	return _hitstop_timer > 0.0


func trigger_hitstop(frames_60hz: int, shake_trauma: float = 0.22) -> void:
	var dur := clampf(float(frames_60hz) / 60.0, 0.0, 0.20)
	_hitstop_timer = maxf(_hitstop_timer, dur)
	if shake_trauma > 0.0:
		camera_shake_requested.emit(shake_trauma)


func trigger_camera_shake(trauma: float = 0.35, _intensity: float = 0.0) -> void:
	if trauma > 0.0:
		camera_shake_requested.emit(trauma)


func trigger_slow_mo(scale: float = 0.28, real_seconds: float = 0.35, duck_music: bool = false) -> void:
	Engine.time_scale = clampf(scale, 0.08, 1.0)
	_slowmo_timer = maxf(_slowmo_timer, real_seconds)
	if duck_music and SoundtrackManager:
		SoundtrackManager.set_ducked_lowpass(true, 0.06)


func _process(delta: float) -> void:
	var unscaled_dt := delta / maxf(Engine.time_scale, 0.001)
	if _hitstop_timer > 0.0:
		_hitstop_timer = maxf(0.0, _hitstop_timer - unscaled_dt)
	if _slowmo_timer > 0.0:
		_slowmo_timer -= unscaled_dt
		if _slowmo_timer <= 0.0:
			Engine.time_scale = 1.0
			if SoundtrackManager and not get_tree().paused:
				SoundtrackManager.set_ducked_lowpass(false, 0.22)


func _ensure_vfx_parent() -> Node:
	if is_instance_valid(_vfx_root):
		return _vfx_root
	return get_tree().current_scene


func _make_emissive_mat(color: Color, alpha: float = 1.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(color.r, color.g, color.b, alpha)
	if alpha < 0.999:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


func spawn_hit_spark(world_pos: Vector3, color: Color = Color("#FFE066"), scale_mult: float = 1.0) -> void:
	var parent := _ensure_vfx_parent()
	if parent == null:
		return
	var holder := Node3D.new()
	parent.add_child(holder)
	holder.global_position = world_pos

	var mat := _make_emissive_mat(color, 0.95)
	for i in range(5):
		var shard := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(0.11, 0.48, 0.08) * scale_mult
		shard.mesh = prism
		shard.material_override = mat
		shard.rotation = Vector3(randf_range(-1.2, 1.2), randf_range(0.0, TAU), float(i) * TAU / 5.0)
		holder.add_child(shard)

	var tw := holder.create_tween().set_parallel(true)
	tw.tween_property(holder, "scale", Vector3.ONE * (1.85 * scale_mult), 0.14).from(Vector3.ONE * 0.35)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.14)
	tw.chain().tween_callback(holder.queue_free)


func spawn_morph_flash(world_pos: Vector3, pantheon_color: Color) -> void:
	var parent := _ensure_vfx_parent()
	if parent == null:
		return
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.55
	torus.outer_radius = 0.78
	torus.rings = 10
	torus.ring_segments = 6
	ring.mesh = torus
	var mat := _make_emissive_mat(pantheon_color, 0.92)
	ring.material_override = mat
	parent.add_child(ring)
	ring.global_position = world_pos + Vector3(0.0, 0.95, 0.0)

	var pillar := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.35
	cyl.bottom_radius = 0.55
	cyl.height = 2.2
	cyl.radial_segments = 8
	pillar.mesh = cyl
	var pmat := _make_emissive_mat(pantheon_color.lightened(0.25), 0.55)
	pillar.material_override = pmat
	ring.add_child(pillar)

	var tw := ring.create_tween().set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(2.1, 1.35, 2.1), 0.20).from(Vector3(0.45, 0.6, 0.45))
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.20)
	tw.tween_property(pmat, "albedo_color:a", 0.0, 0.18)
	tw.chain().tween_callback(ring.queue_free)


func spawn_shockwave_ring(world_pos: Vector3, color: Color, radius: float = 2.8, duration: float = 0.28) -> void:
	var parent := _ensure_vfx_parent()
	if parent == null:
		return
	var mesh_inst := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.0
	cyl.height = 0.12
	cyl.radial_segments = 12
	mesh_inst.mesh = cyl
	var mat := _make_emissive_mat(color, 0.78)
	mesh_inst.material_override = mat
	parent.add_child(mesh_inst)
	mesh_inst.global_position = Vector3(world_pos.x, 0.08, world_pos.z)
	var tw := mesh_inst.create_tween().set_parallel(true)
	tw.tween_property(mesh_inst, "scale", Vector3(radius, 1.0, radius), duration).from(Vector3(0.25, 1.0, 0.25))
	tw.tween_property(mat, "albedo_color:a", 0.0, duration)
	tw.chain().tween_callback(mesh_inst.queue_free)


func spawn_lightning_pillar(world_pos: Vector3, color: Color = Color("#00D4FF"), height: float = 7.0, width: float = 0.55) -> void:
	var parent := _ensure_vfx_parent()
	if parent == null:
		return
	var bolt := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = width * 0.55
	cyl.bottom_radius = width
	cyl.height = height
	cyl.radial_segments = 6
	bolt.mesh = cyl
	var mat := _make_emissive_mat(color, 0.92)
	bolt.material_override = mat
	parent.add_child(bolt)
	bolt.global_position = Vector3(world_pos.x, height * 0.5, world_pos.z)
	spawn_shockwave_ring(world_pos, color, width * 3.4, 0.30)
	var tw := bolt.create_tween().set_parallel(true)
	tw.tween_property(bolt, "scale", Vector3(0.15, 1.0, 0.15), 0.28).from(Vector3(1.3, 1.0, 1.3))
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.28)
	tw.chain().tween_callback(bolt.queue_free)


func spawn_ground_telegraph(world_pos: Vector3, size_xz: Vector2, warning_duration: float) -> MeshInstance3D:
	var parent := _ensure_vfx_parent()
	if parent == null:
		return null
	var quad := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(size_xz.x, 0.04, size_xz.y)
	quad.mesh = box
	var mat := _make_emissive_mat(Color("#FF1E42"), 0.46)
	quad.material_override = mat
	parent.add_child(quad)
	quad.global_position = Vector3(world_pos.x, 0.03, clampf(world_pos.z, -3.1, 3.1))
	var tw := quad.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.78, warning_duration * 0.7)
	tw.tween_property(mat, "albedo_color:a", 0.0, warning_duration * 0.3)
	tw.tween_callback(quad.queue_free)
	return quad
