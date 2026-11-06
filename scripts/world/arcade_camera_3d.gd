class_name ArcadeCamera3D
extends Camera3D
## 2.5D Belt-Scroller Arcade Camera:
##   - FOV 52.0 (spec: 50-55), pitched downward 12 deg
##   - Smooth X tracking with directional look-ahead
##   - Locks cleanly during "GO!" wave arenas and Mythic Boss showdowns

var target_player: SharedSoulPlayer = null
var stage_max_x: float = 168.0
var is_locked: bool = false
var locked_x: float = 12.0
var camera_z_offset: float = 9.8
var camera_y_height: float = 3.55

var _smooth_x: float = 8.0
var _trauma: float = 0.0


func _ready() -> void:
	fov = 52.0
	rotation_degrees = Vector3(-12.0, 0.0, 0.0)
	current = true
	if HitstopManager:
		HitstopManager.camera_shake_requested.connect(add_trauma)


func snap_to_x(x_pos: float) -> void:
	_smooth_x = x_pos
	global_position = Vector3(_smooth_x, camera_y_height, camera_z_offset)


func lock_at_arena(center_x: float) -> void:
	is_locked = true
	locked_x = center_x


func unlock_arena() -> void:
	is_locked = false


func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


func _process(delta: float) -> void:
	var desired_x := _smooth_x
	if is_locked:
		desired_x = locked_x
	elif is_instance_valid(target_player):
		var look_ahead := target_player.facing_sign * 1.65
		desired_x = clampf(target_player.global_position.x + look_ahead, 8.5, maxf(8.5, stage_max_x - 8.5))

	_smooth_x = lerpf(_smooth_x, desired_x, 1.0 - exp(-6.5 * delta))

	var shake_offset := Vector3.ZERO
	if _trauma > 0.0:
		var shake := _trauma * _trauma * 0.28
		shake_offset = Vector3(randf_range(-shake, shake), randf_range(-shake, shake), 0.0)
		_trauma = maxf(0.0, _trauma - delta * 3.4)

	global_position = Vector3(_smooth_x, camera_y_height, camera_z_offset) + shake_offset
