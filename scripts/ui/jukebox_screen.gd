class_name JukeboxScreen
extends Control
## 37-Track Interactive Arcade Sound Test & Visualizer.
## Lists and plays all curated tracks with animated VU spectrum bars and context info.

@onready var _track_list: ItemList = $MarginContainer/VBoxContainer/HSplitContainer/LeftPanel/TrackList
@onready var _now_playing_title: Label = $MarginContainer/VBoxContainer/HSplitContainer/RightPanel/PlayerCard/NowPlayingTitle
@onready var _now_playing_context: Label = $MarginContainer/VBoxContainer/HSplitContainer/RightPanel/PlayerCard/NowPlayingContext
@onready var _play_pause_btn: Button = $MarginContainer/VBoxContainer/HSplitContainer/RightPanel/PlayerCard/ControlsRow/PlayPauseBtn
@onready var _prev_btn: Button = $MarginContainer/VBoxContainer/HSplitContainer/RightPanel/PlayerCard/ControlsRow/PrevBtn
@onready var _next_btn: Button = $MarginContainer/VBoxContainer/HSplitContainer/RightPanel/PlayerCard/ControlsRow/NextBtn
@onready var _volume_slider: HSlider = $MarginContainer/VBoxContainer/HSplitContainer/RightPanel/PlayerCard/VolumeRow/VolumeSlider
@onready var _back_btn: Button = $MarginContainer/VBoxContainer/Header/BackBtn
@onready var _spectrum_container: HBoxContainer = $MarginContainer/VBoxContainer/HSplitContainer/RightPanel/PlayerCard/SpectrumContainer

var _all_tracks: Array[String] = []
var _current_index: int = 0
var _spectrum_bars: Array[ProgressBar] = []
var _is_paused: bool = false
var _vis_timer: float = 0.0


func _ready() -> void:
	if SoundtrackManager:
		_all_tracks = SoundtrackManager.get_all_37_tracks()

	_setup_spectrum_bars()
	_populate_track_list()

	_track_list.item_selected.connect(_on_track_selected)
	_play_pause_btn.pressed.connect(_on_play_pause_pressed)
	_prev_btn.pressed.connect(_on_prev_pressed)
	_next_btn.pressed.connect(_on_next_pressed)
	_back_btn.pressed.connect(_on_back_pressed)
	_volume_slider.value_changed.connect(_on_volume_changed)

	# Select current or first track
	if not _all_tracks.is_empty():
		var cur_path := SoundtrackManager.get_current_track_path() if SoundtrackManager else ""
		var found := _all_tracks.find(cur_path)
		_current_index = found if found >= 0 else 0
		_select_track(_current_index, false)


func _setup_spectrum_bars() -> void:
	for c in _spectrum_container.get_children():
		c.queue_free()
	_spectrum_bars.clear()

	for _i in range(18):
		var bar := ProgressBar.new()
		bar.fill_mode = ProgressBar.FILL_BOTTOM_TO_TOP
		bar.show_percentage = false
		bar.min_value = 0.0
		bar.max_value = 1.0
		bar.value = randf_range(0.2, 0.6)
		bar.custom_minimum_size = Vector2(16, 90)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_spectrum_container.add_child(bar)
		_spectrum_bars.append(bar)


func _populate_track_list() -> void:
	_track_list.clear()
	for i in range(_all_tracks.size()):
		var path := _all_tracks[i]
		var title := SoundtrackManager.format_track_title(path) if SoundtrackManager else path.get_file().get_basename()
		var is_unlocked := true
		if SaveManager and not SaveManager.is_track_unlocked(path):
			# If locked in campaign, still display with badge or full title
			is_unlocked = SaveManager.is_track_unlocked(path)
		_track_list.add_item("%02d. %s" % [i + 1, title])


func _select_track(idx: int, play_immediately: bool = true) -> void:
	if _all_tracks.is_empty():
		return
	_current_index = clampi(idx, 0, _all_tracks.size() - 1)
	_track_list.select(_current_index)
	_track_list.ensure_current_is_visible()

	var path := _all_tracks[_current_index]
	var title := SoundtrackManager.format_track_title(path) if SoundtrackManager else path.get_file().get_basename()
	_now_playing_title.text = title
	_now_playing_context.text = "TRACK #%02d / %02d  •  JUKEBOX STEREO" % [_current_index + 1, _all_tracks.size()]

	if play_immediately and SoundtrackManager:
		_is_paused = false
		_play_pause_btn.text = "PAUSE"
		SoundtrackManager.play_track(path, "ARCADE JUKEBOX", true)
		if SaveManager:
			SaveManager.unlock_track(path)


func _on_track_selected(idx: int) -> void:
	_select_track(idx, true)


func _on_play_pause_pressed() -> void:
	if _all_tracks.is_empty() or SoundtrackManager == null:
		return
	if _is_paused:
		_is_paused = false
		_play_pause_btn.text = "PAUSE"
		SoundtrackManager.play_track(_all_tracks[_current_index], "ARCADE JUKEBOX", true)
	else:
		_is_paused = true
		_play_pause_btn.text = "PLAY"
		SoundtrackManager.stop_all(0.4)


func _on_prev_pressed() -> void:
	var next_idx := posmod(_current_index - 1, _all_tracks.size())
	_select_track(next_idx, true)


func _on_next_pressed() -> void:
	var next_idx := posmod(_current_index + 1, _all_tracks.size())
	_select_track(next_idx, true)


func _on_volume_changed(val: float) -> void:
	var bus_idx := AudioServer.get_bus_index("Music")
	if bus_idx >= 0:
		var db := linear_to_db(val)
		AudioServer.set_bus_volume_db(bus_idx, db)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		_on_back_pressed()


func _process(delta: float) -> void:
	_vis_timer += delta
	var energy := 0.0 if _is_paused else 1.0
	for i in range(_spectrum_bars.size()):
		var bar := _spectrum_bars[i]
		var freq := 3.0 + float(i) * 1.5
		var target := (0.15 + 0.85 * absf(sin(_vis_timer * freq + float(i) * 0.4))) * energy
		bar.value = move_toward(bar.value, target, 4.0 * delta)
