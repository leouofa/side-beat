class_name GodSelectScreen
extends Control
## Starting God & Stage Select Screen before entering the Urban World Tour.

const GOD_INFO := [
	{
		"slot": 0,
		"name": "ENDOR",
		"pantheon": "ASGARDIAN (NORSE)",
		"title": "Thunderclad Heavy Brawler",
		"weapon": "Mythic Thunder Hammer",
		"preview": "res://assets/previews/endor_profile.png",
		"color": Color("#00D4FF"),
		"power": "★★★★★",
		"speed": "★★☆☆☆",
		"reach": "★★★★☆",
		"aerial": "★★☆☆☆",
		"super_name": "VALHALLA SMITE",
		"desc": "Heavy armor-breaker with uninterruptible ground slams and catastrophic area shockwaves.",
	},
	{
		"slot": 1,
		"name": "IR",
		"pantheon": "OLYMPIAN (GREEK)",
		"title": "High-Speed Flash Striker",
		"weapon": "Electrified Lightning Rapier",
		"preview": "res://assets/previews/ir_profile.png",
		"color": Color("#FFE066"),
		"power": "★★★☆☆",
		"speed": "★★★★★",
		"reach": "★★★☆☆",
		"aerial": "★★★☆☆",
		"super_name": "AEGIS STORM BLITZ",
		"desc": "Rapid thrust flurries, flash-step lane crossing, and instantaneous Aegis parry counter-attacks.",
	},
	{
		"slot": 2,
		"name": "OSIRIS",
		"pantheon": "DUAT (EGYPTIAN)",
		"title": "Underworld Crowd Controller",
		"weapon": "Ceremonial Crook & Flail",
		"preview": "res://assets/previews/osiris_profile.png",
		"color": Color("#2ECC71"),
		"power": "★★★★☆",
		"speed": "★★★☆☆",
		"reach": "★★★★★",
		"aerial": "★★☆☆☆",
		"super_name": "DUAT SOUL HARVEST",
		"desc": "Wide-arc sweeps controlling entire lanes, pulling distant enemies and siphoning HP to restore soul health.",
	},
	{
		"slot": 3,
		"name": "HORUS",
		"pantheon": "SOLAR (EGYPTIAN)",
		"title": "Falcon God Aerial Juggler",
		"weapon": "Dual Golden Khopeshes",
		"preview": "res://assets/previews/horus_profile.png",
		"color": Color("#FF7A00"),
		"power": "★★★☆☆",
		"speed": "★★★★☆",
		"reach": "★★★☆☆",
		"aerial": "★★★★★",
		"super_name": "SOLAR FALCON DIVE",
		"desc": "Master of airborne combat with double-jump hovering, launcher spirals, and devastating dive slams.",
	},
]

@onready var _god_cards_container: HBoxContainer = $MarginContainer/VBoxContainer/GodCardsContainer
@onready var _god_name_label: Label = $MarginContainer/VBoxContainer/DetailPanel/VBoxContainer/GodName
@onready var _god_title_label: Label = $MarginContainer/VBoxContainer/DetailPanel/VBoxContainer/GodTitle
@onready var _god_desc_label: RichTextLabel = $MarginContainer/VBoxContainer/DetailPanel/VBoxContainer/GodDesc
@onready var _god_stats_label: Label = $MarginContainer/VBoxContainer/DetailPanel/VBoxContainer/GodStats
@onready var _detail_panel: PanelContainer = $MarginContainer/VBoxContainer/DetailPanel
@onready var _stage_select_btn: OptionButton = $MarginContainer/VBoxContainer/BottomRow/StageSelectBtn
@onready var _start_btn: Button = $MarginContainer/VBoxContainer/BottomRow/StartTourBtn
@onready var _back_btn: Button = $MarginContainer/VBoxContainer/Header/BackBtn

var _selected_slot: int = 0
var _hovered_slot: int = -1
var _card_panels: Array[PanelContainer] = []


func _ready() -> void:
	SynthwaveUI.apply_to_tree(self)
	_detail_panel.add_theme_stylebox_override(
		"panel",
		SynthwaveUI.make_card_style(SynthwaveUI.COLOR_CARD_BG, Color("#00D4FF"), 2, 8, Color(0, 0.8, 1.0, 0.25), 6)
	)

	_setup_god_cards()
	_setup_stage_selector()
	_update_selection()

	_start_btn.pressed.connect(_on_start_tour_pressed)
	_back_btn.pressed.connect(_on_back_pressed)
	_stage_select_btn.item_selected.connect(_on_stage_selected)


func _setup_god_cards() -> void:
	for c in _god_cards_container.get_children():
		c.queue_free()
	_card_panels.clear()

	for i in range(GOD_INFO.size()):
		var slot_idx := i
		var info: Dictionary = GOD_INFO[i]
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(240, 220)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.mouse_filter = Control.MOUSE_FILTER_STOP

		var vbox := VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 8)
		vbox.mouse_filter = Control.MOUSE_FILTER_PASS

		var img := TextureRect.new()
		img.custom_minimum_size = Vector2(160, 140)
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.mouse_filter = Control.MOUSE_FILTER_PASS
		var p_path: String = info["preview"]
		if ResourceLoader.exists(p_path):
			img.texture = load(p_path)
		vbox.add_child(img)

		var name_lbl := Label.new()
		name_lbl.text = "[%d] %s" % [i + 1, info["name"]]
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_color_override("font_color", info["color"])
		name_lbl.add_theme_font_size_override("font_size", 18)
		name_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
		vbox.add_child(name_lbl)

		var arche_lbl := Label.new()
		arche_lbl.text = info["pantheon"]
		arche_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		arche_lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
		arche_lbl.add_theme_font_size_override("font_size", 12)
		arche_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
		vbox.add_child(arche_lbl)

		card.add_child(vbox)

		card.mouse_entered.connect(func():
			_hovered_slot = slot_idx
			_update_card_style(slot_idx)
			if SfxManager:
				SfxManager.play_2d("ui_move")
		)
		card.mouse_exited.connect(func():
			if _hovered_slot == slot_idx:
				_hovered_slot = -1
				_update_card_style(slot_idx)
		)
		card.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				if _selected_slot != slot_idx:
					_selected_slot = slot_idx
					_update_selection()
					if SfxManager:
						SfxManager.play_2d("ui_confirm")
		)

		_god_cards_container.add_child(card)
		_card_panels.append(card)


func _setup_stage_selector() -> void:
	_stage_select_btn.clear()
	var max_unlocked := int(SaveManager.data.get("unlocked_max_stage", 1)) if SaveManager else 1
	var cities := [
		"Stage 1: New York City",
		"Stage 2: Los Angeles",
		"Stage 3: Madrid",
		"Stage 4: Moscow",
		"Stage 5: London",
		"Stage 6: Tokyo",
		"Stage 7: Rome",
	]
	for i in range(max_unlocked):
		_stage_select_btn.add_item(cities[i], i + 1)
	_stage_select_btn.selected = 0


func _update_card_style(slot: int) -> void:
	if slot < 0 or slot >= _card_panels.size():
		return
	var card := _card_panels[slot]
	var info: Dictionary = GOD_INFO[slot]
	var is_selected := (slot == _selected_slot)
	var is_hovered := (slot == _hovered_slot)

	if is_selected:
		card.modulate = Color(1.2, 1.2, 1.2)
		var sel_color: Color = info["color"]
		card.add_theme_stylebox_override(
			"panel",
			SynthwaveUI.make_card_style(
				Color("#180F30"),
				sel_color,
				3,
				8,
				Color(sel_color.r, sel_color.g, sel_color.b, 0.65),
				10
			)
		)
	elif is_hovered:
		card.modulate = Color(1.1, 1.1, 1.1)
		card.add_theme_stylebox_override(
			"panel",
			SynthwaveUI.make_card_hover_style(SynthwaveUI.COLOR_GLOW_HOVER)
		)
	else:
		card.modulate = Color(0.75, 0.75, 0.75)
		card.add_theme_stylebox_override(
			"panel",
			SynthwaveUI.make_card_style(
				SynthwaveUI.COLOR_CARD_BG,
				SynthwaveUI.COLOR_CARD_BORDER,
				2,
				8
			)
		)


func _update_selection() -> void:
	for i in range(_card_panels.size()):
		_update_card_style(i)

	var info: Dictionary = GOD_INFO[_selected_slot]
	_god_name_label.text = "%s — %s" % [info["name"], info["pantheon"]]
	_god_name_label.add_theme_color_override("font_color", info["color"])
	_god_title_label.text = "%s   |   WEAPON: %s" % [info["title"], info["weapon"]]
	_god_stats_label.text = "POWER: %s   SPEED: %s   REACH: %s   AERIAL: %s" % [
		info["power"], info["speed"], info["reach"], info["aerial"]
	]
	_god_desc_label.text = "%s\nPANTHEON SUPER: [b]%s[/b]" % [info["desc"], info["super_name"]]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("move_left"):
		_selected_slot = posmod(_selected_slot - 1, GOD_INFO.size())
		_update_selection()
		if SfxManager:
			SfxManager.play_2d("ui_select", 0.0, 0.0)
	elif event.is_action_pressed("move_right"):
		_selected_slot = posmod(_selected_slot + 1, GOD_INFO.size())
		_update_selection()
		if SfxManager:
			SfxManager.play_2d("ui_select", 0.0, 0.0)
	elif event.is_action_pressed("attack_light") or event.is_action_pressed("jump"):
		_on_start_tour_pressed()
	elif event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		_on_back_pressed()


func _on_stage_selected(_idx: int) -> void:
	if SfxManager:
		SfxManager.play_2d("ui_select", 0.0, 0.0)


func _on_start_tour_pressed() -> void:
	if SfxManager:
		SfxManager.play_2d("ui_confirm", 0.0, 0.0)
	var stage_num := _stage_select_btn.selected + 1
	if GameManager:
		GameManager.start_new_tour(stage_num, _selected_slot)
		GameManager.load_stage(stage_num)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")
