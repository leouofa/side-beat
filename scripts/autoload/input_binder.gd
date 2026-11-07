extends Node
## Programmatically registers all Keyboard (WASD + Arrows + J/K/L/U/I/O + 1-4 + Q/E)
## and Gamepad InputMap bindings for Side Beat so controls work identically in runtime and tests.


func _init() -> void:
	_register_all_actions()


static func _add_key(action: StringName, keycode: Key) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action, ev)


static func _add_joy_btn(action: StringName, btn: JoyButton) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = btn
	InputMap.action_add_event(action, ev)


static func _add_joy_axis(action: StringName, axis: JoyAxis, axis_val: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = axis_val
	InputMap.action_add_event(action, ev)


static func _ensure_action(action: StringName, deadzone: float = 0.2) -> void:
	if InputMap.has_action(action):
		InputMap.action_erase_events(action)
	else:
		InputMap.add_action(action, deadzone)


static func _register_all_actions() -> void:
	# 2.5D Belt Movement (WASD + Arrow Keys + Left Stick)
	_ensure_action(&"move_left")
	_add_key(&"move_left", KEY_A)
	_add_key(&"move_left", KEY_LEFT)
	_add_joy_axis(&"move_left", JOY_AXIS_LEFT_X, -1.0)

	_ensure_action(&"move_right")
	_add_key(&"move_right", KEY_D)
	_add_key(&"move_right", KEY_RIGHT)
	_add_joy_axis(&"move_right", JOY_AXIS_LEFT_X, 1.0)

	_ensure_action(&"move_up")
	_add_key(&"move_up", KEY_W)
	_add_key(&"move_up", KEY_UP)
	_add_joy_axis(&"move_up", JOY_AXIS_LEFT_Y, -1.0)

	_ensure_action(&"move_down")
	_add_key(&"move_down", KEY_S)
	_add_key(&"move_down", KEY_DOWN)
	_add_joy_axis(&"move_down", JOY_AXIS_LEFT_Y, 1.0)

	# Jump / Double Jump / Hover
	_ensure_action(&"jump")
	_add_key(&"jump", KEY_SPACE)
	_add_joy_btn(&"jump", JOY_BUTTON_A)

	# Fighting-Game Combat Buttons
	_ensure_action(&"attack_light")
	_add_key(&"attack_light", KEY_J)
	_add_key(&"attack_light", KEY_Z)
	_add_joy_btn(&"attack_light", JOY_BUTTON_X)

	_ensure_action(&"attack_heavy")
	_add_key(&"attack_heavy", KEY_K)
	_add_key(&"attack_heavy", KEY_X)
	_add_joy_btn(&"attack_heavy", JOY_BUTTON_Y)

	_ensure_action(&"attack_special")
	_add_key(&"attack_special", KEY_L)
	_add_key(&"attack_special", KEY_C)
	_add_joy_btn(&"attack_special", JOY_BUTTON_B)

	_ensure_action(&"attack_super")
	_add_key(&"attack_super", KEY_O)
	_add_key(&"attack_super", KEY_V)
	_add_joy_axis(&"attack_super", JOY_AXIS_TRIGGER_RIGHT, 1.0)

	_ensure_action(&"block_parry")
	_add_key(&"block_parry", KEY_U)
	_add_key(&"block_parry", KEY_SHIFT)
	_add_joy_axis(&"block_parry", JOY_AXIS_TRIGGER_LEFT, 1.0)

	_ensure_action(&"grab")
	_add_key(&"grab", KEY_I)
	_add_key(&"grab", KEY_G)
	_add_joy_btn(&"grab", JOY_BUTTON_RIGHT_SHOULDER)

	# Zero-Cooldown Shared-Soul Morphing (Keys 1-4 / D-Pad / Q & E / L1)
	_ensure_action(&"morph_1")
	_add_key(&"morph_1", KEY_1)
	_add_joy_btn(&"morph_1", JOY_BUTTON_DPAD_UP)

	_ensure_action(&"morph_2")
	_add_key(&"morph_2", KEY_2)
	_add_joy_btn(&"morph_2", JOY_BUTTON_DPAD_RIGHT)

	_ensure_action(&"morph_3")
	_add_key(&"morph_3", KEY_3)
	_add_joy_btn(&"morph_3", JOY_BUTTON_DPAD_DOWN)

	_ensure_action(&"morph_4")
	_add_key(&"morph_4", KEY_4)
	_add_joy_btn(&"morph_4", JOY_BUTTON_DPAD_LEFT)

	_ensure_action(&"morph_prev")
	_add_key(&"morph_prev", KEY_Q)

	_ensure_action(&"morph_next")
	_add_key(&"morph_next", KEY_E)
	_add_joy_btn(&"morph_next", JOY_BUTTON_LEFT_SHOULDER)

	# Pause / Menu
	_ensure_action(&"pause")
	_add_key(&"pause", KEY_ESCAPE)
	_add_joy_btn(&"pause", JOY_BUTTON_START)
