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
	_add_action("interact")
	_add_action("tool")
	_add_action("pickup")
	_add_action("hurt_test")
	_add_action("death_test")
	_add_action("respawn")
	_add_action("regenerate_level")
	_add_action("toggle_ui")

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

	_add_key("interact", KEY_E)
	_add_joy_button("interact", JOY_BUTTON_X)

	_add_key("tool", KEY_F)
	_add_joy_button("tool", JOY_BUTTON_Y)

	_add_key("pickup", KEY_Q)
	_add_joy_button("pickup", JOY_BUTTON_B)

	_add_key("hurt_test", KEY_H)
	_add_joy_button("hurt_test", JOY_BUTTON_RIGHT_STICK)

	_add_key("death_test", KEY_K)
	_add_joy_button("death_test", JOY_BUTTON_START)

	_add_key("respawn", KEY_R)
	_add_joy_button("respawn", JOY_BUTTON_BACK)

	_add_key("regenerate_level", KEY_G)
	_add_joy_button("regenerate_level", JOY_BUTTON_RIGHT_SHOULDER)

	# Survival runs use a single chassis. TAB now owns the compact HUD toggle;
	# the old switch-mecha binding is intentionally left unbound.
	_add_key("toggle_ui", KEY_TAB)

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
