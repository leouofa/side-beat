class_name GlbLoader
extends RefCounted
## Loads rigged .glb assets reliably in both imported runtime and raw headless test modes.


static func instantiate_glb(res_path: String) -> Node3D:
	if ResourceLoader.exists(res_path):
		var res := load(res_path)
		if res is PackedScene:
			var inst := (res as PackedScene).instantiate()
			if inst is Node3D:
				return inst as Node3D
	var abs_path := ProjectSettings.globalize_path(res_path)
	if FileAccess.file_exists(abs_path):
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		var err := doc.append_from_file(abs_path, state)
		if err == OK:
			var gen := doc.generate_scene(state)
			if gen is Node3D:
				return gen as Node3D
	push_warning("GlbLoader: Failed to instantiate %s" % res_path)
	return Node3D.new()


static func find_skeleton(root: Node) -> Skeleton3D:
	if root is Skeleton3D:
		return root as Skeleton3D
	for c in root.find_children("*", "Skeleton3D", true, false):
		return c as Skeleton3D
	return null


static func find_anim_player(root: Node) -> AnimationPlayer:
	var ap: AnimationPlayer = null
	if root is AnimationPlayer:
		ap = root as AnimationPlayer
	else:
		for c in root.find_children("*", "AnimationPlayer", true, false):
			ap = c as AnimationPlayer
			break
	if ap != null:
		_configure_looping_clips(ap)
	return ap


static func _configure_looping_clips(ap: AnimationPlayer) -> void:
	var loop_names := [
		"idle_fight_stance",
		"walk_forward",
		"walk_back_guard",
		"run_dash",
		"jump_air",
		"jump_air_loop",
		"block_high",
	]
	for nm in loop_names:
		if ap.has_animation(nm):
			var anim := ap.get_animation(nm)
			if anim:
				anim.loop_mode = Animation.LOOP_LINEAR
