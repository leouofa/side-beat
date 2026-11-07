extends Node
## Programmatically registers simplified Keyboard InputMap bindings for Side Beat
## (WASD locomotion, Space jump, K/L/O/U combat, 1-4/Q/E zero-cooldown morphs, ESC pause, Enter/Space UI accept).


func _init() -> void:
	_register_all_actions()


static func _add_key(action: StringName, keycode: Key) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action, ev)


static func _ensure_action(action: StringName, deadzone: float = 0.2) -> void:
	if InputMap.has_action(action):
		InputMap.action_erase_events(action)
	else:
		InputMap.add_action(action, deadzone)


static func _register_all_actions() -> void:
	# 2.5D Belt Movement (WASD only)
	_ensure_action(&"move_left")
	_add_key(&"move_left", KEY_A)

	_ensure_action(&"move_right")
	_add_key(&"move_right", KEY_D)

	_ensure_action(&"move_up")
	_add_key(&"move_up", KEY_W)

	_ensure_action(&"move_down")
	_add_key(&"move_down", KEY_S)

	# Jump / Double Jump / Hover
	_ensure_action(&"jump")
	_add_key(&"jump", KEY_SPACE)

	# Combat Buttons (Heavy Attack, Specials, Super, Block/Parry)
	_ensure_action(&"attack_heavy")
	_add_key(&"attack_heavy", KEY_K)

	_ensure_action(&"attack_special")
	_add_key(&"attack_special", KEY_L)

	_ensure_action(&"attack_super")
	_add_key(&"attack_super", KEY_O)

	_ensure_action(&"block_parry")
	_add_key(&"block_parry", KEY_U)

	# Zero-Cooldown Shared-Soul Morphing (Keys 1-4 / Q & E)
	_ensure_action(&"morph_1")
	_add_key(&"morph_1", KEY_1)

	_ensure_action(&"morph_2")
	_add_key(&"morph_2", KEY_2)

	_ensure_action(&"morph_3")
	_add_key(&"morph_3", KEY_3)

	_ensure_action(&"morph_4")
	_add_key(&"morph_4", KEY_4)

	_ensure_action(&"morph_prev")
	_add_key(&"morph_prev", KEY_Q)

	_ensure_action(&"morph_next")
	_add_key(&"morph_next", KEY_E)

	# Pause / Menu
	_ensure_action(&"pause")
	_add_key(&"pause", KEY_ESCAPE)

	# UI Navigation / Accept
	_ensure_action(&"ui_accept")
	_add_key(&"ui_accept", KEY_ENTER)
	_add_key(&"ui_accept", KEY_KP_ENTER)
	_add_key(&"ui_accept", KEY_SPACE)
