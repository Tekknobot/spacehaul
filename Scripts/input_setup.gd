extends RefCounted
class_name InputSetup

static func ensure_actions() -> void:
	_add_action("move_left", 0.22)
	_add_action("move_right", 0.22)
	_add_action("move_up", 0.22)
	_add_action("move_down", 0.22)
	_add_action("run")
	_add_action("dash")
	_add_action("aim", 0.15)
	_add_action("shoot", 0.15)
	_add_action("secondary_ability", 0.15)
	_add_action("cycle_omega_primary_next")
	_add_action("cycle_omega_primary_prev")
	_add_action("interact")
	_add_action("tool")
	_add_action("pickup")
	_add_action("hurt_test")
	_add_action("death_test")
	_add_action("respawn")
	_add_action("regenerate_level")
	_add_action("toggle_ui")
	_add_action("cycle_deck_cheat")
	_add_action("ui_accept")
	_add_action("ui_up")
	_add_action("ui_down")
	_add_action("ui_left")
	_add_action("ui_right")

	_add_key("move_left", KEY_A)
	_add_key("move_left", KEY_LEFT)
	_add_key("move_right", KEY_D)
	_add_key("move_right", KEY_RIGHT)
	_add_key("move_up", KEY_W)
	_add_key("move_up", KEY_UP)
	_add_key("move_down", KEY_S)
	_add_key("move_down", KEY_DOWN)

	_add_joy_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_joy_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_add_joy_axis("move_up", JOY_AXIS_LEFT_Y, -1.0)
	_add_joy_axis("move_down", JOY_AXIS_LEFT_Y, 1.0)
	_add_joy_button("move_left", JOY_BUTTON_DPAD_LEFT)
	_add_joy_button("move_right", JOY_BUTTON_DPAD_RIGHT)
	_add_joy_button("move_up", JOY_BUTTON_DPAD_UP)
	_add_joy_button("move_down", JOY_BUTTON_DPAD_DOWN)

	_add_key("run", KEY_SHIFT)
	_add_joy_button("run", JOY_BUTTON_LEFT_SHOULDER)

	_add_key("dash", KEY_SPACE)
	_add_joy_button("dash", JOY_BUTTON_A)

	# Mouse aim is implicit from the cursor/right stick. Right click is now a
	# standalone secondary-ability trigger rather than a modifier for LMB.
	_add_mouse_button("shoot", MOUSE_BUTTON_LEFT)
	_add_joy_axis("shoot", JOY_AXIS_TRIGGER_RIGHT, 1.0)

	_add_mouse_button("secondary_ability", MOUSE_BUTTON_RIGHT)
	_add_joy_axis("secondary_ability", JOY_AXIS_TRIGGER_LEFT, 1.0)

	# OMEGA loadout cycling. STANDARD remains slot zero; successive Core pickups
	# add up to three OMEGA primaries to the wheel in acquisition order.
	_add_mouse_button("cycle_omega_primary_next", MOUSE_BUTTON_WHEEL_DOWN)
	_add_mouse_button("cycle_omega_primary_prev", MOUSE_BUTTON_WHEEL_UP)
	# Gamepad face buttons mirror wheel cycling. X walks backward, Y forward.
	# These actions are intentionally separate from movement/boost so changing an
	# OMEGA primary never produces an accidental combat action.
	_add_joy_button("cycle_omega_primary_prev", JOY_BUTTON_X)
	_add_joy_button("cycle_omega_primary_next", JOY_BUTTON_Y)

	_add_key("interact", KEY_E)
	_add_key("tool", KEY_F)
	_add_key("pickup", KEY_Q)
	_add_joy_button("pickup", JOY_BUTTON_B)

	_add_key("hurt_test", KEY_H)
	_add_joy_button("hurt_test", JOY_BUTTON_RIGHT_STICK)

	_add_key("death_test", KEY_K)

	_add_key("respawn", KEY_R)

	_add_key("regenerate_level", KEY_G)

	# Runtime deck/palette test. Press P repeatedly to cycle 1 -> 2 -> 3 -> 4 -> 5 -> 1.
	_add_key("cycle_deck_cheat", KEY_P)

	# Expedition map is optional during combat. Back/View mirrors TAB on gamepad.
	_add_key("toggle_ui", KEY_TAB)
	_add_joy_button("toggle_ui", JOY_BUTTON_BACK)

	# Explicit UI navigation keeps pause/menu overlays controller-safe even on
	# platforms whose default project InputMap differs from the editor defaults.
	_add_key("ui_accept", KEY_ENTER)
	_add_key("ui_accept", KEY_KP_ENTER)
	_add_key("ui_accept", KEY_SPACE)
	_add_key("ui_up", KEY_UP)
	_add_key("ui_down", KEY_DOWN)
	_add_key("ui_left", KEY_LEFT)
	_add_key("ui_right", KEY_RIGHT)
	_add_joy_button("ui_accept", JOY_BUTTON_A)
	_add_joy_button("ui_up", JOY_BUTTON_DPAD_UP)
	_add_joy_button("ui_down", JOY_BUTTON_DPAD_DOWN)
	_add_joy_button("ui_left", JOY_BUTTON_DPAD_LEFT)
	_add_joy_button("ui_right", JOY_BUTTON_DPAD_RIGHT)
	_add_joy_axis("ui_up", JOY_AXIS_LEFT_Y, -1.0)
	_add_joy_axis("ui_down", JOY_AXIS_LEFT_Y, 1.0)
	_add_joy_axis("ui_left", JOY_AXIS_LEFT_X, -1.0)
	_add_joy_axis("ui_right", JOY_AXIS_LEFT_X, 1.0)

static func _add_action(action: StringName, deadzone: float = 0.2) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, deadzone)

static func _add_key(action: StringName, keycode: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	_add_event_if_missing(action, event)

static func _add_mouse_button(action: StringName, button: int) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	_add_event_if_missing(action, event)

static func _add_joy_button(action: StringName, button: int) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	_add_event_if_missing(action, event)

static func _add_joy_axis(action: StringName, axis: int, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	_add_event_if_missing(action, event)

static func _add_event_if_missing(action: StringName, event: InputEvent) -> void:
	for existing in InputMap.action_get_events(action):
		if existing.as_text() == event.as_text():
			return
	InputMap.action_add_event(action, event)
