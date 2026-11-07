extends Node
## Curated 37-track Stage & Boss Radio with 1.5s crossfades, "NOW PLAYING" HUD signal,
## and low-pass filter ducking during pause / KO slow-mo.
## Zero-cooldown character morphing NEVER restarts or chops tracks.

signal track_started(track_title: String, context_label: String, track_path: String)

const CROSSFADE_DURATION := 1.5
const NORMAL_LPF_HZ := 20500.0
const DUCKED_LPF_HZ := 880.0

const MENU_TRACKS := {
	"title_theme": "res://tracks/Pantheon in Neon.mp3",
	"character_and_tour_select": "res://tracks/Wake Up, Endor.mp3",
	"stage_clear_victory": "res://tracks/Sparkling After The War.mp3",
	"ending_credits": "res://tracks/Conquered Love.mp3",
	"game_over_continue": "res://tracks/The Mead Runs Out.mp3",
}

const STAGE_PLAYLISTS := {
	1: {
		"city": "New York City",
		"street_waves": [
			"res://tracks/Beat to a Masterpiece.mp3",
			"res://tracks/Immortal Are Not Bulletproof.mp3",
			"res://tracks/No Problem.mp3",
		],
		"mid_boss": "res://tracks/Widjet.mp3",
		"stage_boss": "res://tracks/Chump and the Thunder.mp3",
	},
	2: {
		"city": "Los Angeles",
		"street_waves": [
			"res://tracks/Silicon Smoke Signals.mp3",
			"res://tracks/Thunder in the Backseat.mp3",
			"res://tracks/Leotard.mp3",
		],
		"mid_boss": "res://tracks/Olaf's Broke Car.mp3",
		"stage_boss": "res://tracks/Big Zeus.mp3",
	},
	3: {
		"city": "Madrid",
		"street_waves": [
			"res://tracks/Myst Water Blessings.mp3",
			"res://tracks/Loki and the Bottle of Mead.mp3",
			"res://tracks/Mead in the Rug.mp3",
		],
		"mid_boss": "res://tracks/Stay Off Aphrodite's Bad Side.mp3",
		"stage_boss": "res://tracks/Lilith Reborn.mp3",
	},
	4: {
		"city": "Moscow",
		"street_waves": [
			"res://tracks/Iced Out.mp3",
			"res://tracks/I'm Not a Viking.mp3",
			"res://tracks/Thunder For Breakfast.mp3",
		],
		"mid_boss": "res://tracks/Paranoid Pharaoh.mp3",
		"stage_boss": "res://tracks/Exorcist.mp3",
	},
	5: {
		"city": "London",
		"street_waves": [
			"res://tracks/Remember Your Name.mp3",
			"res://tracks/Peaches for the Pharaoh.mp3",
		],
		"mid_boss": "res://tracks/Peaches in the Pyramid.mp3",
		"stage_boss": "res://tracks/Azrael.mp3",
	},
	6: {
		"city": "Tokyo",
		"street_waves": [
			"res://tracks/Olympus Mainframe.mp3",
			"res://tracks/Ninja Pharaoh.mp3",
			"res://tracks/Into The Temple.mp3",
		],
		"mid_boss": "",
		"stage_boss": "res://tracks/God Mode.mp3",
	},
	7: {
		"city": "Rome",
		"street_waves": [
			"res://tracks/The Wrath of Osiris.mp3",
			"res://tracks/Three Thrones, One Flame.mp3",
		],
		"mid_boss": "",
		"stage_boss": "res://tracks/Not Lucifer.mp3",
		"stage_boss_phase_2": "res://tracks/Armageddon.mp3",
	},
}

var _player_a: AudioStreamPlayer
var _player_b: AudioStreamPlayer
var _active_player: AudioStreamPlayer
var _current_track_path: String = ""
var _current_context: String = ""
var _fade_tween: Tween
var _lpf_tween: Tween
var _street_queue: Array[String] = []
var _street_index: int = 0
var _auto_cycle_street: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player_a = AudioStreamPlayer.new()
	_player_b = AudioStreamPlayer.new()
	for p in [_player_a, _player_b]:
		p.bus = &"Music"
		p.volume_db = -80.0
		add_child(p)
	_active_player = _player_a
	_player_a.finished.connect(_on_stream_finished.bind(_player_a))
	_player_b.finished.connect(_on_stream_finished.bind(_player_b))


func get_all_37_tracks() -> Array[String]:
	var all: Array[String] = []
	for k in MENU_TRACKS.keys():
		all.append(String(MENU_TRACKS[k]))
	for st in range(1, 8):
		var cfg: Dictionary = STAGE_PLAYLISTS[st]
		for sw in cfg.get("street_waves", []):
			all.append(String(sw))
		var mb := String(cfg.get("mid_boss", ""))
		if not mb.is_empty():
			all.append(mb)
		var sb := String(cfg.get("stage_boss", ""))
		if not sb.is_empty():
			all.append(sb)
		var sb2 := String(cfg.get("stage_boss_phase_2", ""))
		if not sb2.is_empty():
			all.append(sb2)
	return all


func format_track_title(track_path: String) -> String:
	return track_path.get_file().get_basename()


func get_current_track_path() -> String:
	return _current_track_path


func get_playback_position() -> float:
	if _active_player and _active_player.playing:
		return _active_player.get_playback_position()
	return 0.0


func play_menu_track(menu_key: String, loop_track: bool = true) -> void:
	_auto_cycle_street = false
	var path := String(MENU_TRACKS.get(menu_key, ""))
	if path.is_empty():
		return
	var label := menu_key.replace("_", " ").to_upper()
	play_track(path, label, loop_track)


func start_stage_street_radio(stage_num: int, wave_index: int = 0) -> void:
	var cfg: Dictionary = STAGE_PLAYLISTS.get(stage_num, STAGE_PLAYLISTS[1])
	_street_queue.clear()
	for t in cfg.get("street_waves", []):
		_street_queue.append(String(t))
	if _street_queue.is_empty():
		return
	_auto_cycle_street = true
	_street_index = posmod(wave_index, _street_queue.size())
	var city_name := String(cfg.get("city", "City")).to_upper()
	play_track(_street_queue[_street_index], "%s — STREET RADIO" % city_name, false)


func advance_street_wave_track(stage_num: int, wave_index: int) -> void:
	var cfg: Dictionary = STAGE_PLAYLISTS.get(stage_num, STAGE_PLAYLISTS[1])
	var waves: Array = cfg.get("street_waves", [])
	if waves.is_empty():
		return
	_street_queue.clear()
	for t in waves:
		_street_queue.append(String(t))
	_auto_cycle_street = true
	var next_idx := posmod(wave_index, _street_queue.size())
	var next_path := _street_queue[next_idx]
	if next_path != _current_track_path:
		_street_index = next_idx
		var city_name := String(cfg.get("city", "City")).to_upper()
		play_track(next_path, "%s — WAVE %d" % [city_name, wave_index + 1], false)


func play_boss_theme(stage_num: int, is_mid_boss: bool, phase_2: bool = false, boss_display_name: String = "") -> void:
	_auto_cycle_street = false
	var cfg: Dictionary = STAGE_PLAYLISTS.get(stage_num, STAGE_PLAYLISTS[1])
	var path := ""
	if is_mid_boss:
		path = String(cfg.get("mid_boss", ""))
	elif phase_2 and cfg.has("stage_boss_phase_2"):
		path = String(cfg.get("stage_boss_phase_2", ""))
	else:
		path = String(cfg.get("stage_boss", ""))
	if path.is_empty():
		return
	var ctx := "MID-BOSS THEME" if is_mid_boss else ("AWAKENED BOSS THEME" if phase_2 else "STAGE BOSS THEME")
	if not boss_display_name.is_empty():
		ctx = "%s — %s" % [boss_display_name.to_upper(), ctx]
	play_track(path, ctx, true)


func play_track(track_path: String, context_label: String = "ARCADE JUKEBOX", loop_stream: bool = true) -> void:
	if track_path == _current_track_path and _active_player and _active_player.playing:
		return
	if not ResourceLoader.exists(track_path):
		push_warning("SoundtrackManager: Missing track %s" % track_path)
		return
	var stream := load(track_path) as AudioStream
	if stream == null:
		return
	# Configure MP3 loop without mutating shared disk import permanently if cloned
	if stream is AudioStreamMP3:
		stream = stream.duplicate()
		(stream as AudioStreamMP3).loop = loop_stream

	var outgoing := _active_player
	var incoming := _player_b if _active_player == _player_a else _player_a
	_active_player = incoming
	_current_track_path = track_path
	_current_context = context_label

	incoming.stream = stream
	incoming.volume_db = -42.0
	incoming.play()

	if _fade_tween and _fade_tween.is_running():
		_fade_tween.kill()
	_fade_tween = create_tween().set_parallel(true)
	_fade_tween.tween_property(incoming, "volume_db", 0.0, CROSSFADE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if outgoing.playing:
		_fade_tween.tween_property(outgoing, "volume_db", -50.0, CROSSFADE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		_fade_tween.chain().tween_callback(outgoing.stop)

	if SaveManager:
		SaveManager.unlock_track(track_path)
	track_started.emit(format_track_title(track_path), context_label, track_path)


func set_ducked_lowpass(enabled: bool, duration: float = 0.18) -> void:
	var bus_idx := AudioServer.get_bus_index(&"Music")
	if bus_idx < 0 or AudioServer.get_bus_effect_count(bus_idx) == 0:
		return
	var lpf := AudioServer.get_bus_effect(bus_idx, 0) as AudioEffectLowPassFilter
	if lpf == null:
		return
	var target_hz := DUCKED_LPF_HZ if enabled else NORMAL_LPF_HZ
	if _lpf_tween and _lpf_tween.is_running():
		_lpf_tween.kill()
	_lpf_tween = create_tween()
	_lpf_tween.tween_property(lpf, "cutoff_hz", target_hz, duration)


func _on_stream_finished(player: AudioStreamPlayer) -> void:
	if player != _active_player:
		return
	if _auto_cycle_street and not _street_queue.is_empty():
		_street_index = (_street_index + 1) % _street_queue.size()
		var next_track := _street_queue[_street_index]
		_current_track_path = "" # force play even if 1-track queue
		play_track(next_track, _current_context, false)
