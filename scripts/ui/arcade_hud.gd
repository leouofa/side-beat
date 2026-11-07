class_name ArcadeHud
extends CanvasLayer
## Complete Arcade HUD: Shared-Soul 1000 HP, 4-Pip Pantheon Meter, 4-God Morph Strip,
## Cross-Pantheon Resonance (D -> GODLIKE), Boss HP + Super-Armor Bar, "GO! >>" Prompt,
## Slide-In "NOW PLAYING" Radio Toast, Pause/Controls Card, Continue Countdown, and Stage Clear Card.

signal continue_accepted
signal restart_stage_requested
signal next_stage_requested
signal exit_to_menu_requested

var _hp_bar: ProgressBar
var _hp_label: Label
var _meter_bar: ProgressBar
var _meter_label: Label
var _god_title_label: Label
var _slot_panels: Array[PanelContainer] = []

var _score_label: Label
var _hiscore_label: Label
var _stage_label: Label
var _biome_label: Label
var _banner_label: Label
var _go_label: Label

var _resonance_box: PanelContainer
var _res_rank_label: Label
var _res_hits_label: Label
var _res_mult_label: Label
var _callout_label: Label

var _boss_box: PanelContainer
var _boss_title_label: Label
var _boss_hp_bar: ProgressBar
var _boss_armor_bar: ProgressBar
var _boss_hint_label: Label

var _toast_box: PanelContainer
var _toast_track_label: Label
var _toast_ctx_label: Label
var _toast_tween: Tween

var _pause_panel: PanelContainer
var _pause_crt_btn: Button
var _pause_quit_btn: Button
var _continue_panel: PanelContainer
var _continue_timer_label: Label
var _clear_panel: PanelContainer
var _clear_details_label: Label
var _clear_rank_label: Label
var _next_stage_btn: Button
var _replay_stage_btn: Button

var _go_pulse_timer: float = 0.0
var _callout_timer: float = 0.0
var _continue_countdown: float = 0.0
var _in_continue_prompt: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_build_ui()
	if SoundtrackManager:
		SoundtrackManager.track_started.connect(_on_track_started)
	if GameManager:
		GameManager.score_changed.connect(_on_score_changed)
		GameManager.credits_changed.connect(_on_credits_changed)


func _make_box_style(bg: Color, border: Color, border_w: int = 2, corner_r: int = 4) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(corner_r)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s


func _make_bar_styles(fill_color: Color, bg_color: Color = Color(0.08, 0.09, 0.14, 0.92)) -> Array[StyleBoxFlat]:
	var bg := StyleBoxFlat.new()
	bg.bg_color = bg_color
	bg.set_corner_radius_all(3)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill_color
	fg.set_corner_radius_all(3)
	return [bg, fg]


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# 1. TOP-LEFT: Shared-Soul HP, Pantheon Meter & 4-God Morph Strip
	var tl := PanelContainer.new()
	tl.position = Vector2(18, 14)
	tl.custom_minimum_size = Vector2(405, 136)
	tl.add_theme_stylebox_override("panel", _make_box_style(Color(0.05, 0.06, 0.11, 0.88), Color("#00D4FF")))
	root.add_child(tl)

	var tl_vbox := VBoxContainer.new()
	tl_vbox.add_theme_constant_override("separation", 5)
	tl.add_child(tl_vbox)

	_god_title_label = Label.new()
	_god_title_label.text = "[1] ENDOR — ASGARDIAN (NORSE)"
	_god_title_label.add_theme_font_size_override("font_size", 15)
	_god_title_label.add_theme_color_override("font_color", Color("#00D4FF"))
	tl_vbox.add_child(_god_title_label)

	_hp_bar = ProgressBar.new()
	_hp_bar.max_value = 1000.0
	_hp_bar.value = 1000.0
	_hp_bar.show_percentage = false
	_hp_bar.custom_minimum_size = Vector2(380, 20)
	var hp_styles := _make_bar_styles(Color("#32FF7E"))
	_hp_bar.add_theme_stylebox_override("background", hp_styles[0])
	_hp_bar.add_theme_stylebox_override("fill", hp_styles[1])
	tl_vbox.add_child(_hp_bar)

	_hp_label = Label.new()
	_hp_label.text = "SHARED SOUL HP: 1000 / 1000"
	_hp_label.add_theme_font_size_override("font_size", 12)
	_hp_label.add_theme_color_override("font_color", Color("#FFFFFF"))
	_hp_label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.06, 0.95))
	_hp_label.add_theme_constant_override("outline_size", 3)
	_hp_bar.add_child(_hp_label)
	_hp_label.position = Vector2(8, 1)

	_meter_bar = ProgressBar.new()
	_meter_bar.max_value = 100.0
	_meter_bar.value = 50.0
	_meter_bar.show_percentage = false
	_meter_bar.custom_minimum_size = Vector2(380, 18)
	var m_styles := _make_bar_styles(Color("#D4AC0D"))
	_meter_bar.add_theme_stylebox_override("background", m_styles[0])
	_meter_bar.add_theme_stylebox_override("fill", m_styles[1])
	tl_vbox.add_child(_meter_bar)

	_meter_label = Label.new()
	_meter_label.text = "PANTHEON METER: 50 / 100  [L: SPECIAL 25 | O: SUPER 100]"
	_meter_label.add_theme_font_size_override("font_size", 11)
	_meter_label.add_theme_color_override("font_color", Color("#FFFFFF"))
	_meter_label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.06, 0.95))
	_meter_label.add_theme_constant_override("outline_size", 3)
	_meter_bar.add_child(_meter_label)
	_meter_label.position = Vector2(8, 0)

	var slots_hbox := HBoxContainer.new()
	slots_hbox.add_theme_constant_override("separation", 6)
	tl_vbox.add_child(slots_hbox)

	var god_badges := [
		["1: ENDOR", Color("#00D4FF")],
		["2: IR", Color("#FFE066")],
		["3: OSIRIS", Color("#2CE8A2")],
		["4: HORUS", Color("#FF7A00")],
	]
	_slot_panels.clear()
	for idx in range(4):
		var sp := PanelContainer.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var col: Color = god_badges[idx][1]
		sp.add_theme_stylebox_override("panel", _make_box_style(Color(0.09, 0.11, 0.17, 0.95), col, 2 if idx == 0 else 1, 3))
		var lbl := Label.new()
		lbl.text = String(god_badges[idx][0])
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", col)
		sp.add_child(lbl)
		slots_hbox.add_child(sp)
		_slot_panels.append(sp)

	# 2. TOP-RIGHT: Score, Stage, Sub-Biome, Credits & "GO! >>"
	var top_right_panel := PanelContainer.new()
	top_right_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	top_right_panel.position = Vector2(-378, 14)
	top_right_panel.custom_minimum_size = Vector2(360, 108)
	top_right_panel.add_theme_stylebox_override("panel", _make_box_style(Color(0.05, 0.06, 0.11, 0.88), Color("#FFD700")))
	root.add_child(top_right_panel)

	var tr_vbox := VBoxContainer.new()
	tr_vbox.add_theme_constant_override("separation", 3)
	top_right_panel.add_child(tr_vbox)

	_score_label = Label.new()
	_score_label.text = "SCORE: 0000000"
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_score_label.add_theme_font_size_override("font_size", 20)
	_score_label.add_theme_color_override("font_color", Color("#FFE066"))
	tr_vbox.add_child(_score_label)

	_hiscore_label = Label.new()
	var top_sc := SaveManager.get_top_score() if SaveManager else 50000
	_hiscore_label.text = "TOP ARCADE: %07d   |   CREDITS: 3" % top_sc
	_hiscore_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hiscore_label.add_theme_font_size_override("font_size", 12)
	_hiscore_label.add_theme_color_override("font_color", Color("#C8D6E5"))
	tr_vbox.add_child(_hiscore_label)

	_stage_label = Label.new()
	_stage_label.text = "STAGE 1 — NEW YORK CITY"
	_stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_stage_label.add_theme_font_size_override("font_size", 14)
	_stage_label.add_theme_color_override("font_color", Color("#00D4FF"))
	tr_vbox.add_child(_stage_label)

	_biome_label = Label.new()
	_biome_label.text = "NEON TIMES SQUARE CROSSWALK   [ESC: CONTROLS]"
	_biome_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_biome_label.add_theme_font_size_override("font_size", 11)
	_biome_label.add_theme_color_override("font_color", Color("#A4B0BE"))
	tr_vbox.add_child(_biome_label)

	_banner_label = Label.new()
	_banner_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner_label.position = Vector2(-260, 18)
	_banner_label.custom_minimum_size = Vector2(520, 32)
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_label.add_theme_font_size_override("font_size", 16)
	_banner_label.add_theme_color_override("font_color", Color("#FF1E42"))
	root.add_child(_banner_label)

	_go_label = Label.new()
	_go_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_go_label.position = Vector2(-210, 134)
	_go_label.text = "GO! >>>"
	_go_label.visible = false
	_go_label.add_theme_font_size_override("font_size", 36)
	_go_label.add_theme_color_override("font_color", Color("#32FF7E"))
	root.add_child(_go_label)

	# 3. BOTTOM-RIGHT: Cross-Pantheon Resonance Widget (across from now-playing toast)
	_resonance_box = PanelContainer.new()
	_resonance_box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_resonance_box.position = Vector2(-268, -108)
	_resonance_box.custom_minimum_size = Vector2(250, 94)
	_resonance_box.visible = false
	_resonance_box.add_theme_stylebox_override("panel", _make_box_style(Color(0.07, 0.05, 0.14, 0.90), Color("#FF7A00"), 2, 6))
	root.add_child(_resonance_box)

	var res_vbox := VBoxContainer.new()
	_resonance_box.add_child(res_vbox)
	_res_rank_label = Label.new()
	_res_rank_label.text = "RESONANCE: D"
	_res_rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_res_rank_label.add_theme_font_size_override("font_size", 24)
	_res_rank_label.add_theme_color_override("font_color", Color("#FFD700"))
	res_vbox.add_child(_res_rank_label)

	_res_hits_label = Label.new()
	_res_hits_label.text = "1 HIT COMBO"
	_res_hits_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_res_hits_label.add_theme_font_size_override("font_size", 16)
	res_vbox.add_child(_res_hits_label)

	_res_mult_label = Label.new()
	_res_mult_label.text = "1/4 GODS — 1.00x SCORE"
	_res_mult_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_res_mult_label.add_theme_font_size_override("font_size", 12)
	_res_mult_label.add_theme_color_override("font_color", Color("#00D4FF"))
	res_vbox.add_child(_res_mult_label)

	_callout_label = Label.new()
	_callout_label.set_anchors_preset(Control.PRESET_CENTER)
	_callout_label.position = Vector2(-240, -145)
	_callout_label.custom_minimum_size = Vector2(480, 36)
	_callout_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_callout_label.visible = false
	_callout_label.add_theme_font_size_override("font_size", 22)
	_callout_label.add_theme_color_override("font_color", Color("#FFE066"))
	_callout_label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.05, 0.96))
	_callout_label.add_theme_constant_override("outline_size", 5)
	root.add_child(_callout_label)

	# 4. BOTTOM-CENTER: Mythic Boss HP & Super-Armor Bar
	_boss_box = PanelContainer.new()
	_boss_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_boss_box.position = Vector2(-265, -108)
	_boss_box.custom_minimum_size = Vector2(530, 92)
	_boss_box.visible = false
	_boss_box.add_theme_stylebox_override("panel", _make_box_style(Color(0.08, 0.04, 0.08, 0.92), Color("#FF1E42"), 2, 5))
	root.add_child(_boss_box)

	var b_vbox := VBoxContainer.new()
	b_vbox.add_theme_constant_override("separation", 4)
	_boss_box.add_child(b_vbox)

	_boss_title_label = Label.new()
	_boss_title_label.text = "CHADZUG — TUNNEL KING OF THE UNDER-COBBLE"
	_boss_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_title_label.add_theme_font_size_override("font_size", 15)
	_boss_title_label.add_theme_color_override("font_color", Color("#FF1E42"))
	b_vbox.add_child(_boss_title_label)

	_boss_hp_bar = ProgressBar.new()
	_boss_hp_bar.show_percentage = false
	_boss_hp_bar.custom_minimum_size = Vector2(500, 18)
	var bhp_s := _make_bar_styles(Color("#FF1E42"))
	_boss_hp_bar.add_theme_stylebox_override("background", bhp_s[0])
	_boss_hp_bar.add_theme_stylebox_override("fill", bhp_s[1])
	b_vbox.add_child(_boss_hp_bar)

	_boss_armor_bar = ProgressBar.new()
	_boss_armor_bar.show_percentage = false
	_boss_armor_bar.custom_minimum_size = Vector2(500, 10)
	var barm_s := _make_bar_styles(Color("#FFD700"))
	_boss_armor_bar.add_theme_stylebox_override("background", barm_s[0])
	_boss_armor_bar.add_theme_stylebox_override("fill", barm_s[1])
	b_vbox.add_child(_boss_armor_bar)

	_boss_hint_label = Label.new()
	_boss_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_hint_label.add_theme_font_size_override("font_size", 11)
	_boss_hint_label.add_theme_color_override("font_color", Color("#FFE066"))
	b_vbox.add_child(_boss_hint_label)

	# 5. BOTTOM-LEFT: Slide-In "NOW PLAYING" Radio Toast
	_toast_box = PanelContainer.new()
	_toast_box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_toast_box.position = Vector2(-420, -68)
	_toast_box.custom_minimum_size = Vector2(325, 54)
	_toast_box.add_theme_stylebox_override("panel", _make_box_style(Color(0.05, 0.07, 0.13, 0.94), Color("#2CE8A2"), 2, 4))
	root.add_child(_toast_box)

	var t_vbox := VBoxContainer.new()
	_toast_box.add_child(t_vbox)
	_toast_ctx_label = Label.new()
	_toast_ctx_label.text = "NOW PLAYING — STREET RADIO"
	_toast_ctx_label.add_theme_font_size_override("font_size", 10)
	_toast_ctx_label.add_theme_color_override("font_color", Color("#2CE8A2"))
	t_vbox.add_child(_toast_ctx_label)

	_toast_track_label = Label.new()
	_toast_track_label.text = "♫ Beat to a Masterpiece"
	_toast_track_label.add_theme_font_size_override("font_size", 14)
	_toast_track_label.add_theme_color_override("font_color", Color("#FFFFFF"))
	t_vbox.add_child(_toast_track_label)

	_build_modal_overlays(root)


func _build_modal_overlays(root: Control) -> void:
	# Pause & Controls Card
	_pause_panel = PanelContainer.new()
	_pause_panel.set_anchors_preset(Control.PRESET_CENTER)
	_pause_panel.position = Vector2(-270, -230)
	_pause_panel.custom_minimum_size = Vector2(540, 460)
	_pause_panel.visible = false
	_pause_panel.add_theme_stylebox_override(
		"panel",
		SynthwaveUI.make_card_style(SynthwaveUI.COLOR_CARD_BG, Color("#00D4FF"), 3, 8, Color(0, 0.83, 1, 0.4), 8)
	)
	root.add_child(_pause_panel)

	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 10)
	_pause_panel.add_child(pv)

	var ptitle := Label.new()
	ptitle.text = "PAUSED — SIDE BEAT ARCADE CONTROLS"
	ptitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ptitle.add_theme_font_size_override("font_size", 20)
	ptitle.add_theme_color_override("font_color", Color("#00D4FF"))
	pv.add_child(ptitle)

	var pbody := Label.new()
	pbody.text = (
		"MOVE (2.5D Belt):  WASD\n"
		+ "JUMP / DOUBLE JUMP (Horus):  Space\n"
		+ "HEAVY / GUARD-CRUSH / UP-LAUNCHER:  K (or W+K)\n"
		+ "AERIAL DIVE / SLAM:  K in Mid-Air\n"
		+ "PANTHEON SPECIAL 1 & 2 (25 Meter):  L (Neutral or Dir+L)\n"
		+ "PANTHEON SUPER (100 Meter):  O\n"
		+ "BLOCK / PERFECT PARRY (First 8f):  U\n"
		+ "SHARED-SOUL MORPH (0.0s Cooldown!):  Keys 1–4, Q / E\n\n"
		+ "TIP: Chain hits across all 4 Gods in one combo for 4.0x GODLIKE Resonance!"
	)
	pbody.add_theme_font_size_override("font_size", 13)
	pv.add_child(pbody)

	var resume_btn := Button.new()
	resume_btn.text = "RESUME BRAWL (ESC)"
	SynthwaveUI.apply_button_style(resume_btn)
	resume_btn.pressed.connect(_toggle_pause)
	pv.add_child(resume_btn)

	_pause_crt_btn = Button.new()
	var crt_lbl := PostFxManager.get_preset_label() if PostFxManager else "CRISP ARCADE"
	_pause_crt_btn.text = "CRT SHADER: %s" % crt_lbl
	SynthwaveUI.apply_button_style(_pause_crt_btn)
	_pause_crt_btn.pressed.connect(func():
		if PostFxManager:
			PostFxManager.cycle_crt_preset()
			_pause_crt_btn.text = "CRT SHADER: %s" % PostFxManager.get_preset_label()
			if SfxManager:
				SfxManager.play_2d("ui_confirm", 0.0, 0.0)
	)
	pv.add_child(_pause_crt_btn)

	var restart_btn := Button.new()
	restart_btn.text = "RESTART CITY STAGE"
	SynthwaveUI.apply_button_style(restart_btn)
	restart_btn.pressed.connect(func():
		_set_paused(false)
		restart_stage_requested.emit()
	)
	pv.add_child(restart_btn)

	_pause_quit_btn = Button.new()
	_pause_quit_btn.text = "QUIT TO MENU"
	SynthwaveUI.apply_button_style(_pause_quit_btn)
	_pause_quit_btn.pressed.connect(func():
		_set_paused(false)
		exit_to_menu_requested.emit()
	)
	pv.add_child(_pause_quit_btn)

	# Continue Countdown Overlay
	_continue_panel = PanelContainer.new()
	_continue_panel.set_anchors_preset(Control.PRESET_CENTER)
	_continue_panel.position = Vector2(-230, -130)
	_continue_panel.custom_minimum_size = Vector2(460, 250)
	_continue_panel.visible = false
	_continue_panel.add_theme_stylebox_override(
		"panel",
		SynthwaveUI.make_card_style(Color(0.08, 0.03, 0.08, 0.96), Color("#FF007F"), 3, 8, Color(1, 0, 0.5, 0.5), 10)
	)
	root.add_child(_continue_panel)

	var cv := VBoxContainer.new()
	cv.alignment = BoxContainer.ALIGNMENT_CENTER
	cv.add_theme_constant_override("separation", 12)
	_continue_panel.add_child(cv)

	var ctitle := Label.new()
	ctitle.text = "SHARED SOUL SHATTERED — CONTINUE?"
	ctitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ctitle.add_theme_font_size_override("font_size", 20)
	ctitle.add_theme_color_override("font_color", Color("#FF1E42"))
	cv.add_child(ctitle)

	_continue_timer_label = Label.new()
	_continue_timer_label.text = "10"
	_continue_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_continue_timer_label.add_theme_font_size_override("font_size", 52)
	_continue_timer_label.add_theme_color_override("font_color", Color("#FFE066"))
	cv.add_child(_continue_timer_label)

	var cont_btn := Button.new()
	cont_btn.text = "INSERT CREDIT & REVIVE [SPACE / ENTER]"
	SynthwaveUI.apply_button_style(cont_btn)
	cont_btn.pressed.connect(_accept_continue)
	cv.add_child(cont_btn)

	# Stage Clear Summary Overlay
	_clear_panel = PanelContainer.new()
	_clear_panel.set_anchors_preset(Control.PRESET_CENTER)
	_clear_panel.position = Vector2(-260, -175)
	_clear_panel.custom_minimum_size = Vector2(520, 350)
	_clear_panel.visible = false
	_clear_panel.add_theme_stylebox_override(
		"panel",
		SynthwaveUI.make_card_style(SynthwaveUI.COLOR_CARD_BG, Color("#FFD700"), 3, 8, Color(1, 0.84, 0, 0.5), 10)
	)
	root.add_child(_clear_panel)

	var clv := VBoxContainer.new()
	clv.alignment = BoxContainer.ALIGNMENT_CENTER
	clv.add_theme_constant_override("separation", 10)
	_clear_panel.add_child(clv)

	var cl_title := Label.new()
	cl_title.text = "CITY STAGE CLEAR!"
	cl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cl_title.add_theme_font_size_override("font_size", 24)
	cl_title.add_theme_color_override("font_color", Color("#32FF7E"))
	clv.add_child(cl_title)

	_clear_rank_label = Label.new()
	_clear_rank_label.text = "ARCADE GRADE: S"
	_clear_rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clear_rank_label.add_theme_font_size_override("font_size", 36)
	_clear_rank_label.add_theme_color_override("font_color", Color("#FFD700"))
	clv.add_child(_clear_rank_label)

	_clear_details_label = Label.new()
	_clear_details_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clear_details_label.add_theme_font_size_override("font_size", 14)
	clv.add_child(_clear_details_label)

	_next_stage_btn = Button.new()
	_next_stage_btn.text = "REPLAY STAGE FOR HIGHER RANK"
	SynthwaveUI.apply_button_style(_next_stage_btn)
	_next_stage_btn.pressed.connect(func(): next_stage_requested.emit())
	clv.add_child(_next_stage_btn)

	_replay_stage_btn = Button.new()
	_replay_stage_btn.text = "RESTART CURRENT CITY"
	SynthwaveUI.apply_button_style(_replay_stage_btn)
	_replay_stage_btn.pressed.connect(func(): restart_stage_requested.emit())
	clv.add_child(_replay_stage_btn)


func bind_player(ply: SharedSoulPlayer) -> void:
	ply.hp_changed.connect(_on_player_hp_changed)
	ply.meter_changed.connect(_on_player_meter_changed)
	ply.god_morphed.connect(_on_god_morphed)
	ply.parry_triggered.connect(func(_p): show_callout("PERFECT PARRY! +20 METER", Color("#FFE066")))
	ply.special_cast.connect(func(title: String, col: Color): show_callout(title.to_upper() + "!", col))
	ply.resonance.combo_updated.connect(_on_combo_updated)
	ply.resonance.combo_dropped.connect(func(): _resonance_box.visible = false)
	_on_player_hp_changed(ply.shared_hp, SharedSoulPlayer.MAX_SHARED_HP)
	_on_player_meter_changed(ply.pantheon_meter, SharedSoulPlayer.MAX_PANTHEON_METER)
	_on_god_morphed(ply.active_slot, ply.active_god())


func bind_boss(boss: BossController) -> void:
	_boss_box.visible = true
	_boss_title_label.text = "%s — %s" % [boss.boss_name.to_upper(), boss.boss_title.to_upper()]
	_boss_hint_label.text = boss.counter_hint
	_update_boss_bars(boss.hp, boss.max_hp, boss.armor, boss.max_armor)
	boss.boss_hp_updated.connect(_update_boss_bars)
	boss.boss_phase_shifted.connect(func(_id: String, p: int):
		show_callout("%s ENRAGED — PHASE %d!" % [boss.boss_name.to_upper(), p], Color("#FF1E42"))
	)
	boss.boss_defeated.connect(func(_id: String, pts: int, _pos: Vector3):
		show_callout("%s DEFEATED! +%d PTS" % [boss.boss_name.to_upper(), pts], Color("#FFD700"))
		_boss_box.visible = false
	)


func set_stage_header(stage_num: int, city_name: String, biome_name: String) -> void:
	_stage_label.text = "STAGE %d — %s" % [stage_num, city_name.to_upper()]
	_biome_label.text = "%s   [ESC: CONTROLS]" % biome_name.to_upper()


func set_biome_name(biome_name: String) -> void:
	_biome_label.text = "%s   [ESC: CONTROLS]" % biome_name.to_upper()


func set_arena_banner(locked: bool, text: String) -> void:
	_banner_label.text = text
	if locked:
		_go_label.visible = false


func trigger_go_prompt() -> void:
	_go_label.visible = true
	_go_pulse_timer = 3.6


func show_callout(msg: String, color: Color) -> void:
	_callout_label.text = msg
	_callout_label.add_theme_color_override("font_color", color)
	_callout_label.visible = true
	_callout_timer = 1.35


func show_continue_overlay(credits: int) -> void:
	if credits <= 0:
		_banner_label.text = "GAME OVER — RESTARTING STAGE..."
		var tw := create_tween()
		tw.tween_interval(2.5)
		tw.tween_callback(func(): restart_stage_requested.emit())
		return
	_in_continue_prompt = true
	_continue_countdown = 10.0
	_continue_panel.visible = true
	if SoundtrackManager:
		SoundtrackManager.play_menu_track("game_over_continue", false)


func show_stage_clear_summary(summary: Dictionary) -> void:
	_clear_panel.visible = true
	_clear_rank_label.text = "ARCADE GRADE: %s" % String(summary.get("rank", "A"))
	_clear_details_label.text = (
		"STAGE SCORE: %d   |   TOTAL RUN SCORE: %d\n" % [int(summary["stage_score"]), int(summary["run_score"])]
		+ "CLEAR TIME: %.1fs   |   MAX COMBO: %d HITS\n" % [float(summary["clear_time_sec"]), int(summary["max_combo"])]
		+ "DAMAGE TAKEN: %d   |   PANTHEON VARIETY: %d/4 GODS (%s)" % [
			int(summary["damage_taken"]),
			int(summary["max_variety"]),
			String(summary["best_resonance"]),
		]
	)
	var cur_st := int(summary.get("stage", 1))
	var max_impl := GameManager.max_implemented_stage if GameManager else 1
	if cur_st < max_impl:
		_next_stage_btn.text = "ADVANCE TO STAGE %d >>" % (cur_st + 1)
		if is_instance_valid(_replay_stage_btn):
			_replay_stage_btn.visible = true
	else:
		_next_stage_btn.text = "COMPLETE TOUR & VIEW CREDITS"
		if is_instance_valid(_replay_stage_btn):
			_replay_stage_btn.visible = false
	if SoundtrackManager:
		SoundtrackManager.play_menu_track("stage_clear_victory", false)


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("pause") and not _in_continue_prompt and not _clear_panel.visible:
		_toggle_pause()

	if _go_pulse_timer > 0.0:
		_go_pulse_timer -= delta
		_go_label.modulate.a = 0.45 + 0.55 * absf(sin(_go_pulse_timer * 7.5))
		if _go_pulse_timer <= 0.0:
			_go_label.visible = false

	if _callout_timer > 0.0:
		_callout_timer -= delta
		if _callout_timer <= 0.0:
			_callout_label.visible = false

	if _in_continue_prompt:
		var prev_sec := int(ceil(_continue_countdown))
		_continue_countdown -= delta
		var cur_sec := maxi(0, int(ceil(_continue_countdown)))
		_continue_timer_label.text = str(cur_sec)
		if cur_sec != prev_sec and SfxManager:
			SfxManager.play_2d("continue_tick", -2.0, 0.0)
		if Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("ui_accept"):
			_accept_continue()
		elif _continue_countdown <= 0.0:
			_in_continue_prompt = false
			_continue_panel.visible = false
			restart_stage_requested.emit()


func _accept_continue() -> void:
	if not _in_continue_prompt:
		return
	_in_continue_prompt = false
	_continue_panel.visible = false
	if SfxManager:
		SfxManager.play_2d("ui_confirm", 0.0, 0.0)
	continue_accepted.emit()


func _toggle_pause() -> void:
	_set_paused(not get_tree().paused)


func _set_paused(paused_state: bool) -> void:
	get_tree().paused = paused_state
	_pause_panel.visible = paused_state
	if SoundtrackManager:
		SoundtrackManager.set_ducked_lowpass(paused_state, 0.15)


func _on_player_hp_changed(cur_hp: float, max_hp: float) -> void:
	_hp_bar.max_value = max_hp
	_hp_bar.value = cur_hp
	_hp_label.text = "SHARED SOUL HP: %d / %d" % [int(ceil(cur_hp)), int(max_hp)]


func _on_player_meter_changed(cur_m: float, max_m: float) -> void:
	_meter_bar.max_value = max_m
	_meter_bar.value = cur_m
	var tag := "SUPER READY! [PRESS O]" if cur_m >= 100.0 else ("SPECIAL READY [PRESS L]" if cur_m >= 25.0 else "BUILD COMBO FOR METER")
	_meter_label.text = "PANTHEON: %d/100 — %s" % [int(cur_m), tag]


func _on_god_morphed(slot_idx: int, prof: GodProfile) -> void:
	_god_title_label.text = "[%d] %s — %s" % [prof.input_slot, prof.display_name.to_upper(), prof.pantheon.to_upper()]
	_god_title_label.add_theme_color_override("font_color", prof.primary_color)
	var colors := [Color("#00D4FF"), Color("#FFE066"), Color("#2CE8A2"), Color("#FF7A00")]
	for i in range(_slot_panels.size()):
		var bg := Color(0.18, 0.22, 0.32, 0.98) if i == slot_idx else Color(0.07, 0.09, 0.14, 0.88)
		_slot_panels[i].add_theme_stylebox_override("panel", _make_box_style(bg, colors[i], 3 if i == slot_idx else 1, 3))


func _on_combo_updated(hits: int, rank: String, variety_mult: float, gods_used: Array[String]) -> void:
	_resonance_box.visible = true
	_res_rank_label.text = "RESONANCE: %s" % rank
	_res_hits_label.text = "%d HIT COMBO" % hits
	_res_mult_label.text = "%d/4 GODS — %.2fx BONUS" % [gods_used.size(), variety_mult]


func _update_boss_bars(hp: float, max_hp: float, armor: float, max_armor: float) -> void:
	_boss_hp_bar.max_value = max_hp
	_boss_hp_bar.value = hp
	_boss_armor_bar.max_value = maxf(max_armor, 1.0)
	_boss_armor_bar.value = armor


func _on_score_changed(new_score: int, _delta: int) -> void:
	_score_label.text = "SCORE: %07d" % new_score
	_refresh_hiscore_line()


func _on_credits_changed(_rem: int) -> void:
	_refresh_hiscore_line()


func _refresh_hiscore_line() -> void:
	var top_sc := maxi(SaveManager.get_top_score() if SaveManager else 0, GameManager.run_score if GameManager else 0)
	var cred := GameManager.credits_remaining if GameManager else 3
	_hiscore_label.text = "TOP ARCADE: %07d   |   CREDITS: %d" % [top_sc, cred]


func _on_track_started(track_title: String, context_label: String, _path: String) -> void:
	_toast_ctx_label.text = "NOW PLAYING — %s" % context_label
	_toast_track_label.text = "♫ %s" % track_title
	if _toast_tween and _toast_tween.is_running():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast_box, "position:x", 18.0, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_toast_tween.tween_interval(3.8)
	_toast_tween.tween_property(_toast_box, "position:x", -420.0, 0.30).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
