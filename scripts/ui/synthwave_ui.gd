class_name SynthwaveUI
extends RefCounted
## Utility class providing Synthwave UI styling, cursor configurations, and hover effects.

const COLOR_BG_NORMAL := Color("#0E081A")
const COLOR_BG_HOVER := Color("#1A0F33")
const COLOR_BG_PRESSED := Color("#0B1B2B")
const COLOR_BG_DISABLED := Color("#08060D")

const COLOR_BORDER_NORMAL := Color("#3D1B63")
const COLOR_BORDER_HOVER := Color("#FF007F")
const COLOR_BORDER_PRESSED := Color("#00E5FF")
const COLOR_BORDER_FOCUS := Color("#FF007F")
const COLOR_BORDER_DISABLED := Color("#201530")

const COLOR_GLOW_HOVER := Color(0.0, 0.9, 1.0, 0.5)
const COLOR_TEXT_NORMAL := Color("#E0E8FF")
const COLOR_TEXT_HOVER := Color("#00FFFF")
const COLOR_TEXT_PRESSED := Color("#FFFFFF")
const COLOR_TEXT_DISABLED := Color("#606075")

const COLOR_CARD_BG := Color(0.06, 0.04, 0.12, 0.96)
const COLOR_CARD_BORDER := Color("#3D1B63")
const COLOR_CARD_HOVER_BORDER := Color("#FF007F")


static func create_box_style(
	bg: Color,
	border_color: Color,
	border_width: int = 2,
	corner_radius: int = 6,
	shadow_color: Color = Color.TRANSPARENT,
	shadow_size: int = 0,
	content_margin_h: int = 14,
	content_margin_v: int = 8
) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border_color
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(corner_radius)
	if shadow_size > 0 and shadow_color.a > 0.0:
		sb.shadow_color = shadow_color
		sb.shadow_size = shadow_size
	sb.content_margin_left = content_margin_h
	sb.content_margin_right = content_margin_h
	sb.content_margin_top = content_margin_v
	sb.content_margin_bottom = content_margin_v
	return sb


static func make_button_normal_style() -> StyleBoxFlat:
	return create_box_style(COLOR_BG_NORMAL, COLOR_BORDER_NORMAL, 2, 6)


static func make_button_hover_style() -> StyleBoxFlat:
	return create_box_style(COLOR_BG_HOVER, COLOR_BORDER_HOVER, 3, 6, COLOR_GLOW_HOVER, 8)


static func make_button_pressed_style() -> StyleBoxFlat:
	return create_box_style(COLOR_BG_PRESSED, COLOR_BORDER_PRESSED, 3, 6, Color(0.0, 0.9, 1.0, 0.7), 6)


static func make_button_focus_style() -> StyleBoxFlat:
	var sb := create_box_style(Color.TRANSPARENT, COLOR_BORDER_FOCUS, 2, 6)
	sb.draw_center = false
	return sb


static func make_button_disabled_style() -> StyleBoxFlat:
	return create_box_style(COLOR_BG_DISABLED, COLOR_BORDER_DISABLED, 1, 6)


static func make_card_style(
	bg: Color = COLOR_CARD_BG,
	border_color: Color = COLOR_CARD_BORDER,
	border_width: int = 2,
	corner_radius: int = 8,
	glow_color: Color = Color.TRANSPARENT,
	glow_size: int = 0
) -> StyleBoxFlat:
	return create_box_style(bg, border_color, border_width, corner_radius, glow_color, glow_size, 16, 16)


static func make_card_hover_style(glow_col: Color = COLOR_GLOW_HOVER) -> StyleBoxFlat:
	return create_box_style(COLOR_BG_HOVER, COLOR_BORDER_HOVER, 3, 8, glow_col, 10, 16, 16)


static func create_synthwave_theme() -> Theme:
	var th := Theme.new()

	# Button styling
	th.set_stylebox("normal", "Button", make_button_normal_style())
	th.set_stylebox("hover", "Button", make_button_hover_style())
	th.set_stylebox("pressed", "Button", make_button_pressed_style())
	th.set_stylebox("focus", "Button", make_button_focus_style())
	th.set_stylebox("disabled", "Button", make_button_disabled_style())

	th.set_color("font_color", "Button", COLOR_TEXT_NORMAL)
	th.set_color("font_hover_color", "Button", COLOR_TEXT_HOVER)
	th.set_color("font_pressed_color", "Button", COLOR_TEXT_PRESSED)
	th.set_color("font_focus_color", "Button", COLOR_TEXT_HOVER)
	th.set_color("font_disabled_color", "Button", COLOR_TEXT_DISABLED)

	# OptionButton styling
	th.set_stylebox("normal", "OptionButton", make_button_normal_style())
	th.set_stylebox("hover", "OptionButton", make_button_hover_style())
	th.set_stylebox("pressed", "OptionButton", make_button_pressed_style())
	th.set_stylebox("focus", "OptionButton", make_button_focus_style())
	th.set_stylebox("disabled", "OptionButton", make_button_disabled_style())

	th.set_color("font_color", "OptionButton", COLOR_TEXT_NORMAL)
	th.set_color("font_hover_color", "OptionButton", COLOR_TEXT_HOVER)
	th.set_color("font_pressed_color", "OptionButton", COLOR_TEXT_PRESSED)
	th.set_color("font_focus_color", "OptionButton", COLOR_TEXT_HOVER)

	# PanelContainer styling
	th.set_stylebox("panel", "PanelContainer", make_card_style())

	return th


static func apply_button_style(btn: Button) -> void:
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if not btn.mouse_entered.is_connected(_on_btn_mouse_entered):
		btn.mouse_entered.connect(_on_btn_mouse_entered)


static func apply_to_tree(node: Node) -> void:
	if node is Button:
		apply_button_style(node)
	for child in node.get_children():
		apply_to_tree(child)


static func _on_btn_mouse_entered() -> void:
	if Engine.has_singleton("SfxManager"):
		var mgr = Engine.get_singleton("SfxManager")
		if mgr and mgr.has_method("play_2d"):
			mgr.play_2d("ui_move")
	elif ResourceLoader.exists("res://scripts/autoload/sfx_manager.gd"):
		# Autoload in scene tree
		var tree := Engine.get_main_loop() as SceneTree
		if tree and tree.root and tree.root.has_node("SfxManager"):
			var mgr = tree.root.get_node("SfxManager")
			if mgr and mgr.has_method("play_2d"):
				mgr.play_2d("ui_move")
