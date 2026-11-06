extends Node
## Polyphonic Retro Arcade SFX Pool playing res://assets/sfx/*.wav with subtle pitch variation.

const POOL_SIZE_2D := 10
const POOL_SIZE_3D := 14

var _streams: Dictionary = {}
var _pool_2d: Array[AudioStreamPlayer] = []
var _pool_3d: Array[AudioStreamPlayer3D] = []
var _idx_2d: int = 0
var _idx_3d: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in range(POOL_SIZE_2D):
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_pool_2d.append(p)
	for i in range(POOL_SIZE_3D):
		var p3 := AudioStreamPlayer3D.new()
		p3.bus = &"SFX"
		p3.unit_size = 14.0
		p3.max_db = 2.0
		p3.panning_strength = 0.45
		add_child(p3)
		_pool_3d.append(p3)


func _get_stream(sfx_name: String) -> AudioStream:
	if _streams.has(sfx_name):
		return _streams[sfx_name]
	var path := "res://assets/sfx/%s.wav" % sfx_name
	if not ResourceLoader.exists(path):
		return null
	var s := load(path) as AudioStream
	_streams[sfx_name] = s
	return s


func play_2d(sfx_name: String, volume_db: float = 0.0, pitch_jitter: float = 0.05) -> void:
	var stream := _get_stream(sfx_name)
	if stream == null or _pool_2d.is_empty():
		return
	var p := _pool_2d[_idx_2d]
	_idx_2d = (_idx_2d + 1) % _pool_2d.size()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter) if pitch_jitter > 0.0 else 1.0
	p.play()


func play_3d(sfx_name: String, world_pos: Vector3, volume_db: float = 0.0, pitch_jitter: float = 0.08) -> void:
	var stream := _get_stream(sfx_name)
	if stream == null or _pool_3d.is_empty():
		return
	var p := _pool_3d[_idx_3d]
	_idx_3d = (_idx_3d + 1) % _pool_3d.size()
	p.global_position = world_pos
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter) if pitch_jitter > 0.0 else 1.0
	p.play()
