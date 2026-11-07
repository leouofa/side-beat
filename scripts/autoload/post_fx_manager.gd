extends CanvasLayer
## Full-screen Arcade Post-Processing & Dynamic Glitch Controller (Layer 100).
## Manages:
##   - CRT Presets: 0 = OFF, 1 = CRISP ARCADE (Default), 2 = HEAVY RETRO CRT
##   - Dynamic Radial Shockwave Ripple & High-Contrast Impact Frame (Perfect Parry & Pantheon Super)
##   - Dynamic RGB Channel Split + Digital Scanline Roll Glitch (Shared-Soul Morph & Boss Phase Shift)

signal crt_preset_changed(mode: int, label: String)

enum CrtPreset {
	OFF = 0,
	CRISP_ARCADE = 1,
	HEAVY_RETRO = 2,
}

const PRESET_LABELS := {
	CrtPreset.OFF: "OFF",
	CrtPreset.CRISP_ARCADE: "CRISP ARCADE",
	CrtPreset.HEAVY_RETRO: "HEAVY RETRO CRT",
}

const POST_FX_SHADER := preload("res://shaders/arcade_post_fx.gdshader")

var current_preset: int = CrtPreset.CRISP_ARCADE
var _overlay_rect: ColorRect
var _shader_mat: ShaderMaterial

var _shader_time: float = 0.0
var _glitch_intensity: float = 0.0
var _glitch_decay_rate: float = 5.5
var _impact_flash: float = 0.0
var _ripple_progress: float = 1.0
var _ripple_duration: float = 0.36
var _ripple_strength: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100

	_shader_mat = ShaderMaterial.new()
	_shader_mat.shader = POST_FX_SHADER

	_overlay_rect = ColorRect.new()
	_overlay_rect.name = "PostFxOverlay"
	_overlay_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_rect.material = _shader_mat
	add_child(_overlay_rect)

	var saved_preset: int = CrtPreset.CRISP_ARCADE
	if SaveManager and SaveManager.data.has("crt_preset"):
		saved_preset = clampi(int(SaveManager.data["crt_preset"]), 0, 2)
	set_crt_preset(saved_preset, false)


func get_preset_label(mode: int = -1) -> String:
	var m := current_preset if mode < 0 else mode
	return String(PRESET_LABELS.get(m, "CRISP ARCADE"))


func set_crt_preset(mode: int, persist: bool = true) -> void:
	current_preset = posmod(mode, 3)
	if _shader_mat:
		_shader_mat.set_shader_parameter("crt_mode", current_preset)
		if current_preset == CrtPreset.CRISP_ARCADE:
			_shader_mat.set_shader_parameter("barrel_curvature", 0.0)
			_shader_mat.set_shader_parameter("scanline_opacity", 0.08)
			_shader_mat.set_shader_parameter("phosphor_mask_strength", 0.06)
			_shader_mat.set_shader_parameter("vignette_strength", 0.22)
		elif current_preset == CrtPreset.HEAVY_RETRO:
			_shader_mat.set_shader_parameter("barrel_curvature", 0.038)
			_shader_mat.set_shader_parameter("scanline_opacity", 0.24)
			_shader_mat.set_shader_parameter("phosphor_mask_strength", 0.18)
			_shader_mat.set_shader_parameter("vignette_strength", 0.38)
		else:
			_shader_mat.set_shader_parameter("barrel_curvature", 0.0)
			_shader_mat.set_shader_parameter("scanline_opacity", 0.0)
			_shader_mat.set_shader_parameter("phosphor_mask_strength", 0.0)
			_shader_mat.set_shader_parameter("vignette_strength", 0.0)

	if persist and SaveManager:
		SaveManager.data["crt_preset"] = current_preset
		SaveManager.write_save()

	crt_preset_changed.emit(current_preset, get_preset_label())


func cycle_crt_preset() -> int:
	var next_mode := (current_preset + 1) % 3
	set_crt_preset(next_mode, true)
	return current_preset


func trigger_morph_glitch(pantheon_color: Color, intensity: float = 0.58, duration: float = 0.18) -> void:
	_glitch_intensity = maxf(_glitch_intensity, clampf(intensity, 0.0, 1.0))
	_glitch_decay_rate = 1.0 / maxf(duration, 0.05)
	if _shader_mat:
		_shader_mat.set_shader_parameter("glitch_tint", pantheon_color)
		_shader_mat.set_shader_parameter("glitch_intensity", _glitch_intensity)


func trigger_boss_phase_glitch(boss_accent: Color, intensity: float = 0.92, duration: float = 0.42) -> void:
	_glitch_intensity = maxf(_glitch_intensity, clampf(intensity, 0.0, 1.0))
	_glitch_decay_rate = 1.0 / maxf(duration, 0.08)
	if _shader_mat:
		_shader_mat.set_shader_parameter("glitch_tint", boss_accent)
		_shader_mat.set_shader_parameter("glitch_intensity", _glitch_intensity)


func trigger_parry_or_super_impact(world_pos: Vector3, tint: Color = Color("#FFE066"), is_super: bool = false) -> void:
	var uv_center := _project_world_to_uv(world_pos)
	_ripple_progress = 0.01
	_ripple_duration = 0.44 if is_super else 0.34
	_ripple_strength = 0.036 if is_super else 0.026
	_impact_flash = 0.92 if is_super else 0.78
	if _shader_mat:
		_shader_mat.set_shader_parameter("ripple_center", uv_center)
		_shader_mat.set_shader_parameter("ripple_progress", _ripple_progress)
		_shader_mat.set_shader_parameter("ripple_strength", _ripple_strength)
		_shader_mat.set_shader_parameter("impact_flash_color", tint)
		_shader_mat.set_shader_parameter("impact_flash_strength", _impact_flash)


func _project_world_to_uv(world_pos: Vector3) -> Vector2:
	var vp := get_viewport()
	if vp == null:
		return Vector2(0.5, 0.5)
	var cam := vp.get_camera_3d()
	if cam == null or cam.is_position_behind(world_pos):
		return Vector2(0.5, 0.5)
	var screen_pt := cam.unproject_position(world_pos)
	var rect_sz := vp.get_visible_rect().size
	if rect_sz.x <= 1.0 or rect_sz.y <= 1.0:
		return Vector2(0.5, 0.5)
	return Vector2(
		clampf(screen_pt.x / rect_sz.x, 0.1, 0.9),
		clampf(screen_pt.y / rect_sz.y, 0.1, 0.9)
	)


func _process(delta: float) -> void:
	var unscaled_dt := delta / maxf(Engine.time_scale, 0.001)
	_shader_time += unscaled_dt
	if _shader_mat == null:
		return
	_shader_mat.set_shader_parameter("shader_time", _shader_time)

	if _glitch_intensity > 0.0:
		_glitch_intensity = maxf(0.0, _glitch_intensity - unscaled_dt * _glitch_decay_rate)
		_shader_mat.set_shader_parameter("glitch_intensity", _glitch_intensity)

	if _impact_flash > 0.0:
		_impact_flash = maxf(0.0, _impact_flash - unscaled_dt * 9.5)
		_shader_mat.set_shader_parameter("impact_flash_strength", _impact_flash)

	if _ripple_progress < 1.0:
		_ripple_progress = minf(1.0, _ripple_progress + unscaled_dt / maxf(_ripple_duration, 0.05))
		_shader_mat.set_shader_parameter("ripple_progress", _ripple_progress)
		if _ripple_progress >= 1.0:
			_ripple_strength = 0.0
			_shader_mat.set_shader_parameter("ripple_strength", 0.0)
