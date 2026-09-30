extends Node2D

const InputSetupScript = preload("res://Scripts/input_setup.gd")
const SFX = preload("res://Scripts/sound_fx.gd")
const MECHA_SCENE = preload("res://Scenes/mecha.tscn")
const SpecialAbilityScript = preload("res://Scripts/special_ability_effect.gd")

const RUN_DURATION := 20.0 * 60.0
const DECK_DURATION := 4.0 * 60.0
const SECONDARY_UNLOCK_TIME := 60.0

# Recording helper. Enable this on the TestWorld root in the Inspector when you
# want to capture late-run footage without playing through the entire run.
# Disable it again before making the public build. No keyboard trigger is used.
@export_category("Video Capture")
@export var video_capture_mode := false
@export_range(1.0, 19.0, 0.5) var video_capture_start_minutes := 15.0
# Late-run showcase captures should include the build-defining Omega state that a
# normal player would almost certainly have hunted by this point. Disable this
# when recording the Tier III signature attack before its Legendary mutation.
@export var video_capture_include_omega := true
@export_range(0, 2, 1) var video_capture_omega_choice := 0
@export_range(5.0, 15.0, 0.5) var video_capture_omega_minute := 8.0

@onready var deck: ProceduralDeck = $ProceduralDeck
@onready var mecha_manager: MechaManager = $MechaManager
@onready var enemy_manager: SpacehaulEnemyManager = $EnemyManager
@onready var deck_banner: Control = $HUD/DeckBanner
@onready var deck_banner_text: Label = $HUD/DeckBanner/Panel/Margin/Text
@onready var hud: CanvasLayer = $HUD

var _banner_tween: Tween
var _hud_visible := true
var _run_time := 0.0
var _deck_number := 1
var _next_deck_time := DECK_DURATION
var _game_over := false
var _run_complete := false
var _secondary_announced := false

var _level := 1
var _salvage := 0
var _salvage_required := 6
var _salvage_magnet_radius := 86.0
var _upgrade_overlay: Control
var _upgrade_title: Label
var _upgrade_buttons: Array[Button] = []
var _upgrade_choices: Array[Dictionary] = []
var _omega_core_stored := false
var _omega_overlay: Control
var _omega_title: Label
var _omega_hint: Label
var _omega_buttons: Array[Button] = []
var _omega_choices: Array[Dictionary] = []
var _hud_omega: Label
var _omega_guide: Node2D
var _omega_guide_arrow: Polygon2D
var _omega_guide_glow: Polygon2D
var _omega_guide_label: Label
var _rng := RandomNumberGenerator.new()

var _top_hud: Control
var _hud_mecha: Label
var _hud_hull: Label
var _hud_level: Label
var _hud_salvage: Label
var _hud_time: Label
var _hud_deck: Label
var _hud_hostiles: Label
var _damage_overlay: ColorRect
var _damage_material: ShaderMaterial
var _damage_intensity := 0.0
var _last_hull := -1
var _low_hull_warned := false
var _run_summary_overlay: Control
var _run_summary_title: Label
var _run_summary_text: Label
var _run_summary_menu_button: Button
var _deck_transition_active := false
var _deck_transition_overlay: ColorRect
var _deck_transition_overlay_material: ShaderMaterial

var _mecha_select_overlay: Control
var _mecha_select_name: Label
var _mecha_select_primary: Label
var _mecha_select_secondary: Label
var _mecha_select_status: Label
var _mecha_select_deploy: Button
var _mecha_select_prev_label: Label
var _mecha_select_next_label: Label
var _showroom_demo_label: Label
var _showroom_viewport: SubViewport
var _showroom_stage: Node2D
var _showroom_fx_root: Node2D
var _showroom_mecha: MechaController
var _showroom_demo_state := 0
var _showroom_demo_timer := 0.0
var _showroom_active := false
var _selected_mecha_id := "M1"
var _menu_open := false

func _enter_tree() -> void:
	add_to_group("survival_manager")

func _ready() -> void:
	# The showroom must keep animating while the gameplay tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	InputSetupScript.ensure_actions()
	_rng.randomize()
	deck.regenerated.connect(_on_deck_regenerated)
	mecha_manager.active_mecha_changed.connect(_on_active_mecha_changed)

	_hide_legacy_hud()
	deck_banner.hide()
	deck_banner.z_index = 1100
	_build_compact_hud()
	_build_omega_guidance()
	_build_damage_overlay()
	_build_deck_transition_overlay()
	_build_upgrade_overlay()
	_build_omega_overlay()
	_build_run_summary_overlay()
	_build_mecha_select_overlay()
	_set_standard_hud_visible(false)
	deck.set_deck_palette(_deck_number)
	enemy_manager.set_spawning_enabled(false)
	_update_hud()

	# Video capture uses the same chassis showroom as a normal run. This keeps the
	# developer shortcut compatible with the title/menu flow and lets footage be
	# staged for whichever chassis is selected instead of silently forcing the
	# MechaManager fixed starter.
	if video_capture_mode and mecha_manager.fixed_starting_mecha in MechaManager.MECHA_IDS:
		_selected_mecha_id = mecha_manager.fixed_starting_mecha
	_show_mecha_select("VIDEO CAPTURE" if video_capture_mode else "SELECT A CHASSIS")

func _process(delta: float) -> void:
	_update_damage_overlay(delta)
	_update_omega_guidance()

	if _menu_open:
		_update_mecha_showroom(delta)
		return

	# Developer palette/deck test. P performs the real cinematic transfer but
	# advances immediately, so every runtime palette can be checked without
	# waiting four minutes. Do not allow it over the level-up chooser or while a
	# transfer is already active.
	if Input.is_action_just_pressed("cycle_deck_cheat"):
		var upgrade_open := _upgrade_overlay != null and _upgrade_overlay.visible
		if not upgrade_open and not _deck_transition_active and not _game_over and not _run_complete:
			_start_deck_transition(true)
			return

	if get_tree().paused or _game_over or _run_complete:
		_update_hud()
		return

	_run_time += delta
	_update_secondary_unlock()

	if _run_time >= RUN_DURATION:
		_complete_run()
	elif _run_time >= _next_deck_time and not _deck_transition_active:
		# A live boss owns the arena. Delay the scheduled deck transfer until the
		# encounter resolves so the Broodmother cannot be escaped or stranded by
		# procedural regeneration.
		if not enemy_manager.is_boss_active():
			_start_deck_transition()

	_update_hud()

func _unhandled_input(event: InputEvent) -> void:
	# The showroom uses the same left/right language as gameplay movement, but only
	# while the full-screen selector is active. ENTER / gamepad A deploys the
	# currently centered chassis; mouse users can click the arrows or DEPLOY.
	if _showroom_active and _mecha_select_overlay != null and _mecha_select_overlay.visible:
		if event is InputEventKey:
			var menu_key := event as InputEventKey
			if menu_key.pressed and not menu_key.echo and (menu_key.keycode == KEY_ENTER or menu_key.keycode == KEY_KP_ENTER):
				_start_selected_run()
				get_viewport().set_input_as_handled()
				return
		if event is InputEventJoypadButton:
			var menu_button := event as InputEventJoypadButton
			if menu_button.pressed and menu_button.button_index == JOY_BUTTON_A:
				_start_selected_run()
				get_viewport().set_input_as_handled()
				return

	var omega_open := _omega_overlay != null and _omega_overlay.visible
	var upgrade_open := _upgrade_overlay != null and _upgrade_overlay.visible
	if not omega_open and not upgrade_open:
		return
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return
		if key_event.keycode == KEY_1:
			if omega_open: _choose_omega_mutation(0)
			else: _choose_upgrade(0)
		elif key_event.keycode == KEY_2:
			if omega_open: _choose_omega_mutation(1)
			else: _choose_upgrade(1)
		elif key_event.keycode == KEY_3:
			if omega_open: _choose_omega_mutation(2)
			else: _choose_upgrade(2)

func get_run_time() -> float:
	return _run_time

func get_deck_number() -> int:
	return _deck_number

func get_salvage_magnet_radius() -> float:
	return _salvage_magnet_radius

func collect_salvage(amount: int) -> void:
	if _game_over or _run_complete:
		return
	_salvage += maxi(1, amount)
	SFX.play(self, "salvage", -18.0, clampf(0.94 + float(_salvage % 6) * 0.025, 0.94, 1.08))
	_update_hud()
	_check_level_up()

func can_receive_omega_core() -> bool:
	if _game_over or _run_complete or _omega_core_stored:
		return false
	var active := mecha_manager.get_active_mecha()
	if active == null:
		return false
	return not active.has_legendary_mutation() and active.has_omega_mutations()

func is_omega_seek_active() -> bool:
	if _game_over or _run_complete or _omega_core_stored or _menu_open:
		return false
	var active := mecha_manager.get_active_mecha()
	return active != null and active.can_accept_omega_mutation()

func collect_omega_core() -> void:
	if not can_receive_omega_core():
		return
	_omega_core_stored = true
	if enemy_manager != null and enemy_manager.has_method("notify_omega_core_collected"):
		enemy_manager.notify_omega_core_collected()
	_update_hud()
	_show_banner("OMEGA CORE ACQUIRED", 0.82)
	call_deferred("_try_open_omega_mutation")

func _try_open_omega_mutation() -> void:
	if not _omega_core_stored or _game_over or _run_complete or _menu_open:
		return
	if _upgrade_overlay != null and _upgrade_overlay.visible:
		return
	if _omega_overlay != null and _omega_overlay.visible:
		return
	var active := mecha_manager.get_active_mecha()
	if active == null:
		return
	if not active.can_accept_omega_mutation():
		_show_banner("OMEGA CORE STORED\nMAX %s TO MUTATE" % active.get_omega_signature_name(), 0.95)
		return
	_present_omega_choices()

func _check_level_up() -> void:
	if _upgrade_overlay != null and _upgrade_overlay.visible:
		return
	if _salvage < _salvage_required:
		return
	_salvage -= _salvage_required
	_level += 1
	_salvage_required = 5 + _level * 4
	SFX.play_ui(self, "level", -8.0, 1.0)
	_present_upgrade_choices()

func _update_secondary_unlock() -> void:
	if _secondary_announced or _run_time < SECONDARY_UNLOCK_TIME:
		return
	_secondary_announced = true
	var active := mecha_manager.get_active_mecha()
	if active == null:
		return
	active.set_secondary_unlocked(true)
	if active.has_secondary_ability():
		SFX.play(self, "level", -8.0, 1.12)
		_show_banner("SECONDARY ONLINE   RMB")

func _on_active_mecha_changed(mecha: MechaController) -> void:
	if mecha == null:
		return
	if not mecha.hull_changed.is_connected(_on_hull_changed):
		mecha.hull_changed.connect(_on_hull_changed)
	if not mecha.destroyed.is_connected(_on_player_destroyed):
		mecha.destroyed.connect(_on_player_destroyed)
	if not mecha.omega_primary_mode_changed.is_connected(_on_omega_primary_mode_changed):
		mecha.omega_primary_mode_changed.connect(_on_omega_primary_mode_changed)
	mecha.set_secondary_unlocked(_secondary_announced)
	_last_hull = mecha.get_hull()
	_low_hull_warned = false
	_update_hud()

func _on_omega_primary_mode_changed(enabled: bool, display_name: String) -> void:
	var active := mecha_manager.get_active_mecha()
	if enabled:
		_show_banner("LMB OMEGA   %s" % display_name, 0.72)
	else:
		var standard_name := "PRIMARY" if active == null else active.get_primary_ability_name()
		_show_banner("LMB STANDARD   %s" % standard_name, 0.72)
	SFX.play_ui(self, "level", -13.5, 1.08 if enabled else 0.92)
	_update_hud()

func _on_hull_changed(current_hull: int, max_hull: int) -> void:
	if _last_hull >= 0 and current_hull < _last_hull:
		_trigger_damage_overlay(1.0)
	var ratio := float(current_hull) / float(maxi(1, max_hull))
	if ratio <= 0.30 and not _low_hull_warned and current_hull > 0:
		_low_hull_warned = true
		SFX.play(self, "warning", -7.0, 0.92)
	elif ratio > 0.42:
		_low_hull_warned = false
	_last_hull = current_hull
	_update_hud()

func _on_player_destroyed(_mecha: MechaController) -> void:
	if _game_over:
		return
	_game_over = true
	enemy_manager.set_spawning_enabled(false)
	if _upgrade_overlay != null:
		_upgrade_overlay.hide()
	if _omega_overlay != null:
		_omega_overlay.hide()
	_show_run_summary(false)

func _complete_run() -> void:
	if _run_complete:
		return
	_run_complete = true
	enemy_manager.set_spawning_enabled(false)
	_show_run_summary(true)

func _restart_run() -> void:
	_start_selected_run()

func _build_mecha_select_overlay() -> void:
	_mecha_select_overlay = ColorRect.new()
	_mecha_select_overlay.name = "MechaShowroom"
	_mecha_select_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mecha_select_overlay.color = Color(0.004, 0.008, 0.014, 0.985)
	_mecha_select_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_mecha_select_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	_mecha_select_overlay.z_index = 2000
	hud.add_child(_mecha_select_overlay)

	var outer_margin := MarginContainer.new()
	outer_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer_margin.add_theme_constant_override("margin_left", 18)
	outer_margin.add_theme_constant_override("margin_top", 9)
	outer_margin.add_theme_constant_override("margin_right", 18)
	outer_margin.add_theme_constant_override("margin_bottom", 8)
	_mecha_select_overlay.add_child(outer_margin)

	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 1)
	root_box.alignment = BoxContainer.ALIGNMENT_CENTER
	outer_margin.add_child(root_box)

	var title := Label.new()
	title.text = "SPACEMECHA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", load("res://Fonts/mago3.ttf") as Font)
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.72, 0.96, 1.0, 1.0))
	root_box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "CHASSIS SHOWROOM   LIVE SYSTEM PREVIEW"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_override("font", load("res://Fonts/mago1.ttf") as Font)
	subtitle.add_theme_font_size_override("font_size", 11)
	subtitle.add_theme_color_override("font_color", Color(0.38, 0.59, 0.66, 1.0))
	root_box.add_child(subtitle)

	_mecha_select_name = Label.new()
	_mecha_select_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mecha_select_name.add_theme_font_override("font", load("res://Fonts/mago2.ttf") as Font)
	_mecha_select_name.add_theme_font_size_override("font_size", 24)
	_mecha_select_name.add_theme_color_override("font_color", Color(0.65, 0.96, 1.0, 1.0))
	root_box.add_child(_mecha_select_name)

	var nav_row := HBoxContainer.new()
	nav_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	nav_row.add_theme_constant_override("separation", 8)
	root_box.add_child(nav_row)

	var left_stack := VBoxContainer.new()
	left_stack.custom_minimum_size = Vector2(46.0, 0.0)
	left_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	nav_row.add_child(left_stack)

	_mecha_select_prev_label = Label.new()
	_mecha_select_prev_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mecha_select_prev_label.add_theme_font_override("font", load("res://Fonts/mago1.ttf") as Font)
	_mecha_select_prev_label.add_theme_font_size_override("font_size", 9)
	_mecha_select_prev_label.add_theme_color_override("font_color", Color(0.27, 0.45, 0.51, 0.78))
	left_stack.add_child(_mecha_select_prev_label)

	var left_button := _make_showroom_arrow_button("LEFT")
	left_button.pressed.connect(_cycle_showroom_mecha.bind(-1))
	left_stack.add_child(left_button)

	var preview_panel := PanelContainer.new()
	preview_panel.custom_minimum_size = Vector2(480.0, 146.0)
	preview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var preview_style := StyleBoxFlat.new()
	preview_style.bg_color = Color(0.006, 0.014, 0.022, 0.96)
	preview_style.border_width_left = 1
	preview_style.border_width_top = 1
	preview_style.border_width_right = 1
	preview_style.border_width_bottom = 1
	preview_style.border_color = Color(0.12, 0.38, 0.46, 0.86)
	preview_style.corner_radius_top_left = 3
	preview_style.corner_radius_top_right = 3
	preview_style.corner_radius_bottom_left = 3
	preview_style.corner_radius_bottom_right = 3
	preview_panel.add_theme_stylebox_override("panel", preview_style)
	nav_row.add_child(preview_panel)

	var viewport_container := SubViewportContainer.new()
	viewport_container.stretch = true
	viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_panel.add_child(viewport_container)

	_showroom_viewport = SubViewport.new()
	_showroom_viewport.name = "ShowroomViewport"
	_showroom_viewport.size = Vector2i(480, 146)
	_showroom_viewport.transparent_bg = true
	_showroom_viewport.gui_disable_input = true
	_showroom_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_showroom_viewport.world_2d = World2D.new()
	viewport_container.add_child(_showroom_viewport)

	_build_showroom_backdrop()

	_showroom_stage = Node2D.new()
	_showroom_stage.name = "ShowroomStage"
	_showroom_stage.position = Vector2(240.0, 92.0)
	_showroom_stage.scale = Vector2.ONE
	_showroom_stage.process_mode = Node.PROCESS_MODE_ALWAYS
	_showroom_viewport.add_child(_showroom_stage)

	_showroom_fx_root = Node2D.new()
	_showroom_fx_root.name = "PreviewFX"
	_showroom_fx_root.process_mode = Node.PROCESS_MODE_ALWAYS
	_showroom_viewport.add_child(_showroom_fx_root)

	var right_stack := VBoxContainer.new()
	right_stack.custom_minimum_size = Vector2(46.0, 0.0)
	right_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	nav_row.add_child(right_stack)

	_mecha_select_next_label = Label.new()
	_mecha_select_next_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mecha_select_next_label.add_theme_font_override("font", load("res://Fonts/mago1.ttf") as Font)
	_mecha_select_next_label.add_theme_font_size_override("font_size", 9)
	_mecha_select_next_label.add_theme_color_override("font_color", Color(0.27, 0.45, 0.51, 0.78))
	right_stack.add_child(_mecha_select_next_label)

	var right_button := _make_showroom_arrow_button("RIGHT")
	right_button.pressed.connect(_cycle_showroom_mecha.bind(1))
	right_stack.add_child(right_button)

	_showroom_demo_label = Label.new()
	_showroom_demo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_showroom_demo_label.add_theme_font_override("font", load("res://Fonts/mago1.ttf") as Font)
	_showroom_demo_label.add_theme_font_size_override("font_size", 10)
	_showroom_demo_label.add_theme_color_override("font_color", Color(0.50, 0.75, 0.82, 1.0))
	root_box.add_child(_showroom_demo_label)

	var ability_row := HBoxContainer.new()
	ability_row.add_theme_constant_override("separation", 8)
	ability_row.alignment = BoxContainer.ALIGNMENT_CENTER
	root_box.add_child(ability_row)
	_mecha_select_primary = _make_showroom_ability_cell(ability_row, Color(0.45, 0.92, 1.0, 1.0))
	_mecha_select_secondary = _make_showroom_ability_cell(ability_row, Color(0.88, 0.58, 1.0, 1.0))

	_mecha_select_deploy = Button.new()
	_mecha_select_deploy.custom_minimum_size = Vector2(230.0, 32.0)
	_mecha_select_deploy.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_mecha_select_deploy.focus_mode = Control.FOCUS_NONE
	_mecha_select_deploy.add_theme_font_override("font", load("res://Fonts/mago2.ttf") as Font)
	_mecha_select_deploy.add_theme_font_size_override("font_size", 18)
	_mecha_select_deploy.add_theme_color_override("font_color", Color(0.68, 0.98, 1.0, 1.0))
	_mecha_select_deploy.add_theme_color_override("font_hover_color", Color(0.90, 1.0, 1.0, 1.0))
	_mecha_select_deploy.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var deploy_style := StyleBoxFlat.new()
	deploy_style.bg_color = Color(0.018, 0.055, 0.067, 0.98)
	deploy_style.border_width_left = 1
	deploy_style.border_width_top = 1
	deploy_style.border_width_right = 1
	deploy_style.border_width_bottom = 1
	deploy_style.border_color = Color(0.25, 0.74, 0.82, 0.94)
	deploy_style.corner_radius_top_left = 2
	deploy_style.corner_radius_top_right = 2
	deploy_style.corner_radius_bottom_left = 2
	deploy_style.corner_radius_bottom_right = 2
	_mecha_select_deploy.add_theme_stylebox_override("normal", deploy_style)
	var deploy_hover := deploy_style.duplicate() as StyleBoxFlat
	deploy_hover.bg_color = Color(0.03, 0.10, 0.12, 1.0)
	deploy_hover.border_color = Color(0.48, 0.95, 1.0, 1.0)
	_mecha_select_deploy.add_theme_stylebox_override("hover", deploy_hover)
	_mecha_select_deploy.add_theme_stylebox_override("pressed", deploy_style)
	_mecha_select_deploy.pressed.connect(_start_selected_run)
	root_box.add_child(_mecha_select_deploy)

	_mecha_select_status = Label.new()
	_mecha_select_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mecha_select_status.add_theme_font_override("font", load("res://Fonts/mago1.ttf") as Font)
	_mecha_select_status.add_theme_font_size_override("font_size", 10)
	_mecha_select_status.add_theme_color_override("font_color", Color(0.38, 0.58, 0.64, 1.0))
	root_box.add_child(_mecha_select_status)

	_select_mecha(_selected_mecha_id)
	_mecha_select_overlay.hide()

func _make_showroom_arrow_button(glyph: String) -> Button:
	var button := Button.new()
	button.text = glyph
	button.custom_minimum_size = Vector2(42.0, 70.0)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", load("res://Fonts/mago2.ttf") as Font)
	button.add_theme_font_size_override("font_size", 30)
	button.add_theme_color_override("font_color", Color(0.42, 0.78, 0.86, 0.92))
	button.add_theme_color_override("font_hover_color", Color(0.82, 1.0, 1.0, 1.0))
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return button

func _make_showroom_ability_cell(row: HBoxContainer, color: Color) -> Label:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(215.0, 34.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r * 0.035, color.g * 0.035, color.b * 0.035, 0.88)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(color.r * 0.36, color.g * 0.36, color.b * 0.36, 0.78)
	panel.add_theme_stylebox_override("panel", style)
	row.add_child(panel)
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", load("res://Fonts/mago1.ttf") as Font)
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", color)
	panel.add_child(label)
	return label

func _build_showroom_backdrop() -> void:
	if _showroom_viewport == null:
		return
	var backdrop := Node2D.new()
	backdrop.name = "HangarGrid"
	backdrop.process_mode = Node.PROCESS_MODE_ALWAYS
	_showroom_viewport.add_child(backdrop)
	# Sparse isometric deck lines give the live sprite a place to sit without
	# competing with the ability VFX.
	for y in range(3):
		var grid_line_a := Line2D.new()
		grid_line_a.width = 1.0
		grid_line_a.default_color = Color(0.10, 0.28, 0.32, 0.26)
		grid_line_a.antialiased = false
		grid_line_a.add_point(Vector2(72.0, 92.0 + float(y) * 10.0))
		grid_line_a.add_point(Vector2(240.0, 142.0 + float(y) * 10.0))
		grid_line_a.add_point(Vector2(408.0, 92.0 + float(y) * 10.0))
		backdrop.add_child(grid_line_a)
	for x in range(-3, 4):
		var grid_line_b := Line2D.new()
		grid_line_b.width = 1.0
		grid_line_b.default_color = Color(0.08, 0.23, 0.28, 0.22)
		grid_line_b.antialiased = false
		var base_x := 240.0 + float(x) * 44.0
		grid_line_b.add_point(Vector2(base_x - 74.0, 142.0))
		grid_line_b.add_point(Vector2(base_x, 92.0))
		grid_line_b.add_point(Vector2(base_x + 74.0, 142.0))
		backdrop.add_child(grid_line_b)
	var horizon := Line2D.new()
	horizon.width = 1.0
	horizon.default_color = Color(0.20, 0.58, 0.65, 0.25)
	horizon.add_point(Vector2(56.0, 92.0))
	horizon.add_point(Vector2(424.0, 92.0))
	backdrop.add_child(horizon)

func _select_mecha(mecha_id: String) -> void:
	if mecha_id not in MechaManager.MECHA_IDS:
		return
	_selected_mecha_id = mecha_id
	var display_name := String(MechaController.MECHA_DISPLAY_NAMES.get(mecha_id, mecha_id))
	var abilities: Dictionary = MechaController.ABILITY_NAMES.get(mecha_id, {})
	_mecha_select_name.text = "%s   %s" % [mecha_id, display_name]
	_mecha_select_primary.text = "LMB\n%s" % String(abilities.get("primary", "PRIMARY"))
	_mecha_select_secondary.text = "RMB\n%s" % String(abilities.get("secondary", "SECONDARY"))
	if _mecha_select_deploy != null:
		_mecha_select_deploy.text = "DEPLOY   %s" % display_name

	var index := MechaManager.MECHA_IDS.find(mecha_id)
	var count := MechaManager.MECHA_IDS.size()
	var prev_id = MechaManager.MECHA_IDS[(index - 1 + count) % count]
	var next_id = MechaManager.MECHA_IDS[(index + 1) % count]
	if _mecha_select_prev_label != null:
		_mecha_select_prev_label.text = String(MechaController.MECHA_DISPLAY_NAMES.get(prev_id, prev_id))
	if _mecha_select_next_label != null:
		_mecha_select_next_label.text = String(MechaController.MECHA_DISPLAY_NAMES.get(next_id, next_id))
	_rebuild_showroom_mecha()

func _cycle_showroom_mecha(step: int) -> void:
	var count := MechaManager.MECHA_IDS.size()
	if count <= 0:
		return
	var index := MechaManager.MECHA_IDS.find(_selected_mecha_id)
	if index < 0:
		index = 0
	index = (index + step + count) % count
	_select_mecha(String(MechaManager.MECHA_IDS[index]))
	SFX.play_ui(self, "level", -20.0, 1.18 if step > 0 else 0.94)

func _rebuild_showroom_mecha() -> void:
	_clear_showroom_fx()
	if _showroom_mecha != null and is_instance_valid(_showroom_mecha):
		_showroom_mecha.queue_free()
	_showroom_mecha = null
	if _showroom_stage == null:
		return
	var preview := MECHA_SCENE.instantiate() as MechaController
	if preview == null:
		return
	preview.mecha_id = _selected_mecha_id
	preview.position = Vector2.ZERO
	preview.scale = Vector2.ONE * 1.70
	preview.process_mode = Node.PROCESS_MODE_ALWAYS
	preview.collision_layer = 0
	preview.collision_mask = 0
	_showroom_stage.add_child(preview)
	preview.set_player_controlled(false)
	preview.remove_from_group("mechas")
	preview.animated_sprite.flip_h = true
	preview.animated_sprite.play("idle")
	_showroom_mecha = preview
	_showroom_demo_state = 0
	_showroom_demo_timer = 0.85
	if _showroom_demo_label != null:
		_showroom_demo_label.text = "LIVE PREVIEW   IDLE"

func _clear_showroom_fx() -> void:
	if _showroom_fx_root == null:
		return
	for child in _showroom_fx_root.get_children():
		child.queue_free()

func _trigger_showroom_ability(alternate: bool) -> void:
	if _showroom_mecha == null or not is_instance_valid(_showroom_mecha) or _showroom_fx_root == null:
		return
	_clear_showroom_fx()
	_showroom_mecha.animated_sprite.flip_h = true
	_showroom_mecha.animated_sprite.play("attack")
	var effect := SpecialAbilityScript.new() as SpacehaulSpecialAbility
	effect.process_mode = Node.PROCESS_MODE_ALWAYS
	_showroom_fx_root.add_child(effect)
	# Preview-space coordinates are intentionally compact so even the widest Tier-0
	# attacks remain readable inside the 480x158 showroom viewport.
	var showroom_center := Vector2(240.0, 92.0)
	var origin := showroom_center + Vector2(8.0, -18.0)
	var owner_center := showroom_center + Vector2(0.0, -18.0)
	var owner_ground := showroom_center
	var target := showroom_center + Vector2(112.0, -18.0)
	effect.preview_mode = true
	effect.setup(
		_selected_mecha_id,
		origin,
		owner_center,
		owner_ground,
		target,
		RID(),
		alternate,
		1.0,
		0,
		0,
		""
	)
	# setup() normally targets the gameplay scene. The showroom deliberately
	# redirects every generated line, projectile, explosion and particle into the
	# isolated SubViewport before the deferred ability sequence begins.
	effect.root = _showroom_fx_root
	if _showroom_demo_label != null:
		var ability_name := _mecha_select_secondary.text.replace("RMB\n", "") if alternate else _mecha_select_primary.text.replace("LMB\n", "")
		_showroom_demo_label.text = "%s   %s" % ["RMB" if alternate else "LMB", ability_name]

func _update_mecha_showroom(delta: float) -> void:
	if not _showroom_active or _showroom_mecha == null or not is_instance_valid(_showroom_mecha):
		return
	if Input.is_action_just_pressed("move_left"):
		_cycle_showroom_mecha(-1)
		return
	if Input.is_action_just_pressed("move_right"):
		_cycle_showroom_mecha(1)
		return
	_showroom_demo_timer = maxf(0.0, _showroom_demo_timer - delta)
	if _showroom_demo_timer > 0.0:
		return
	match _showroom_demo_state:
		0:
			_trigger_showroom_ability(false)
			_showroom_demo_state = 1
			_showroom_demo_timer = 1.45
		1:
			_showroom_mecha.animated_sprite.play("idle")
			_showroom_demo_state = 2
			_showroom_demo_timer = 0.72
			if _showroom_demo_label != null:
				_showroom_demo_label.text = "LIVE PREVIEW   IDLE"
		2:
			_trigger_showroom_ability(true)
			_showroom_demo_state = 3
			_showroom_demo_timer = 2.10
		3:
			_showroom_mecha.animated_sprite.play("idle")
			_showroom_demo_state = 0
			_showroom_demo_timer = 1.05
			if _showroom_demo_label != null:
				_showroom_demo_label.text = "LIVE PREVIEW   IDLE"

func _show_mecha_select(status_text: String = "SELECT A CHASSIS") -> void:
	_menu_open = true
	get_tree().paused = true
	enemy_manager.set_spawning_enabled(false)
	if _upgrade_overlay != null:
		_upgrade_overlay.hide()
	if _omega_overlay != null:
		_omega_overlay.hide()
	if _run_summary_overlay != null:
		_run_summary_overlay.hide()
	if deck_banner != null:
		deck_banner.hide()
	_set_standard_hud_visible(false)
	if _mecha_select_status != null:
		if video_capture_mode:
			_mecha_select_status.text = "VIDEO CAPTURE  %02d:%02d   //   LEFT RIGHT CYCLE   ENTER A DEPLOY" % [
				int(video_capture_start_minutes),
				int(round(fmod(video_capture_start_minutes, 1.0) * 60.0))
			]
		else:
			_mecha_select_status.text = "LEFT RIGHT   CYCLE CHASSIS      ENTER A   DEPLOY"
	if _mecha_select_overlay != null:
		_mecha_select_overlay.show()
		_showroom_active = true
		_select_mecha(_selected_mecha_id)

func _start_selected_run() -> void:
	_showroom_active = false
	_clear_showroom_fx()
	if _showroom_mecha != null and is_instance_valid(_showroom_mecha):
		_showroom_mecha.queue_free()
	_showroom_mecha = null
	_menu_open = false
	get_tree().paused = false
	if _mecha_select_overlay != null:
		_mecha_select_overlay.hide()
	if _run_summary_overlay != null:
		_run_summary_overlay.hide()
	_damage_intensity = 0.0
	if _damage_material != null:
		_damage_material.set_shader_parameter("intensity", 0.0)
	_last_hull = -1
	_low_hull_warned = false
	_run_time = 0.0
	_deck_number = 1
	_next_deck_time = DECK_DURATION
	_game_over = false
	_run_complete = false
	_secondary_announced = false
	_deck_transition_active = false
	_set_deck_transition_overlay_amount(0.0)
	_level = 1
	_salvage = 0
	_salvage_required = 6
	_salvage_magnet_radius = 86.0
	_omega_core_stored = false
	if _omega_overlay != null:
		_omega_overlay.hide()
	deck.set_deck_palette(_deck_number)
	deck.generate_new_level()
	mecha_manager.start_new_run_with_mecha(_selected_mecha_id)
	enemy_manager.reset_run()
	_set_standard_hud_visible(true)
	_update_hud()

	# Stage the capture state only after the menu-selected chassis has actually
	# been spawned. Deferred execution also lets the new mecha finish its normal
	# _ready() setup before tiers, stats, Omega state and enemy pressure are applied.
	# This path is used on first deploy and on any later re-deploy from the menu.
	if video_capture_mode:
		call_deferred("_apply_video_capture_state")

func _apply_video_capture_state() -> void:
	# Stage a believable run state for recording. The clock, deck, enemy pressure,
	# secondary unlock and EVERY level-up choice accumulated by the requested time
	# advance together. Ability evolution is deliberately protected from generic
	# stat choices so capture mode cannot accidentally show an under-developed
	# chassis at a late timestamp.
	get_tree().paused = false
	_game_over = false
	_run_complete = false
	_deck_transition_active = false

	var requested_seconds := video_capture_start_minutes * 60.0
	_run_time = clampf(requested_seconds, 0.0, RUN_DURATION - 1.0)

	var palette_count := maxi(1, deck.get_deck_palette_count())
	_deck_number = clampi(
		int(floor(_run_time / DECK_DURATION)) + 1,
		1,
		palette_count
	)
	_next_deck_time = minf(RUN_DURATION, float(_deck_number) * DECK_DURATION)

	# Approximate a healthy run's number of salvage level-ups. The important part
	# is that level - 1 is treated as an exact choice budget below: every simulated
	# choice is spent on either a chassis ability or a real generic upgrade.
	_level = clampi(2 + int(floor(video_capture_start_minutes * 0.8)), 2, 18)
	_salvage_required = 5 + _level * 4
	_salvage = int(floor(float(_salvage_required) * 0.35))
	_salvage_magnet_radius = 86.0

	_secondary_announced = _run_time >= SECONDARY_UNLOCK_TIME

	deck.set_deck_palette(_deck_number)
	deck.generate_new_level()

	var active := mecha_manager.get_active_mecha()
	if active != null:
		active.set_secondary_unlocked(_secondary_announced)
		_apply_video_capture_upgrades(active, maxi(0, _level - 1), video_capture_start_minutes)
		_apply_video_capture_omega(active, video_capture_start_minutes)
		active.repair_hull(active.get_max_hull())

	# generate_new_level() intentionally displays the deck banner during normal
	# play. Hide it here so recording can begin on a clean gameplay frame.
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	deck_banner.hide()

	enemy_manager.prepare_video_capture_state(_run_time)
	_update_hud()

func _apply_video_capture_upgrades(active: MechaController, upgrade_budget: int, capture_minutes: float) -> void:
	var budget := maxi(0, upgrade_budget)

	# Simulate a primary-biased real build instead of perfectly alternating LMB
	# and RMB. Primary is available from the opening seconds, whereas secondary is
	# not online until 01:00. By a normal late showcase (7+ minutes) both ability
	# trees are guaranteed Tier III before generic stat picks consume the rest of
	# the accumulated level-up budget.
	var primary_target := 0
	if capture_minutes >= 1.0:
		primary_target = 1
	if capture_minutes >= 2.0:
		primary_target = 2
	if capture_minutes >= 4.0:
		primary_target = 3

	var secondary_target := 0
	if _secondary_announced:
		if capture_minutes >= 3.0:
			secondary_target = 1
		if capture_minutes >= 5.0:
			secondary_target = 2
		if capture_minutes >= 7.0:
			secondary_target = 3

	# Ability choices always win over generic upgrades. Primary receives first
	# claim on the budget, which creates the intended early LMB > RMB progression.
	while budget > 0 and active.get_primary_ability_tier() < primary_target and active.can_upgrade_primary_ability():
		active.upgrade_primary_ability()
		budget -= 1

	while budget > 0 and active.get_secondary_ability_tier() < secondary_target and active.can_upgrade_secondary_ability():
		active.upgrade_secondary_ability()
		budget -= 1

	# Once the time-appropriate ability tiers are present, spend every remaining
	# historical choice on a deterministic chassis-flavoured build. This keeps
	# capture starts reproducible while avoiding the old identical generic build
	# across all ten mechas.
	var generic_plan: Array = _get_video_capture_generic_plan(active.mecha_id)
	var generic_step := 0
	while budget > 0 and not generic_plan.is_empty():
		var choice_id := String(generic_plan[generic_step % generic_plan.size()])
		_apply_video_capture_generic_upgrade(active, choice_id)
		generic_step += 1
		budget -= 1

func _get_video_capture_generic_plan(mecha_id: String) -> Array:
	# These are not extra upgrades: they are the simulated choices left over after
	# ability evolution. Different chassis lean into different plausible priorities
	# so a capture of every mecha does not produce the exact same stat build.
	match mecha_id:
		"M1": return ["primary_cooling", "impact", "hull", "servo", "secondary_cooling", "magnet", "impact", "primary_cooling", "hull", "secondary_cooling"]
		"M2": return ["servo", "primary_cooling", "impact", "hull", "magnet", "secondary_cooling", "servo", "impact", "hull", "primary_cooling"]
		"M3": return ["impact", "primary_cooling", "secondary_cooling", "hull", "magnet", "impact", "servo", "primary_cooling", "hull", "secondary_cooling"]
		"R1": return ["primary_cooling", "impact", "secondary_cooling", "servo", "hull", "magnet", "primary_cooling", "impact", "secondary_cooling", "hull"]
		"R2": return ["impact", "hull", "primary_cooling", "secondary_cooling", "servo", "impact", "magnet", "hull", "primary_cooling", "secondary_cooling"]
		"R3": return ["primary_cooling", "secondary_cooling", "impact", "magnet", "servo", "hull", "primary_cooling", "impact", "secondary_cooling", "magnet"]
		"R4": return ["primary_cooling", "impact", "secondary_cooling", "magnet", "hull", "servo", "impact", "primary_cooling", "secondary_cooling", "hull"]
		"S1": return ["impact", "primary_cooling", "secondary_cooling", "servo", "magnet", "hull", "impact", "primary_cooling", "secondary_cooling", "servo"]
		"S2": return ["impact", "hull", "secondary_cooling", "primary_cooling", "magnet", "servo", "impact", "hull", "primary_cooling", "secondary_cooling"]
		"S3": return ["primary_cooling", "servo", "impact", "secondary_cooling", "magnet", "hull", "primary_cooling", "servo", "impact", "secondary_cooling"]
		_: return ["primary_cooling", "impact", "hull", "servo", "secondary_cooling", "magnet"]

func _apply_video_capture_generic_upgrade(active: MechaController, choice_id: String) -> void:
	match choice_id:
		"primary_cooling":
			active.apply_primary_cooling(0.85)
		"secondary_cooling":
			if active.is_secondary_unlocked():
				active.apply_secondary_cooling(0.85)
			else:
				active.apply_primary_cooling(0.85)
		"impact":
			active.apply_impact_multiplier(1.18)
		"hull":
			active.add_max_hull(20, 20)
		"servo":
			active.apply_move_speed_multiplier(1.08)
		"magnet":
			_salvage_magnet_radius = minf(220.0, _salvage_magnet_radius * 1.20)

func _apply_video_capture_omega(active: MechaController, capture_minutes: float) -> void:
	if not video_capture_include_omega:
		return
	if capture_minutes < video_capture_omega_minute:
		return
	if not active.can_accept_omega_mutation():
		return
	var choices: Array = active.get_omega_mutation_choices()
	if choices.is_empty():
		return
	var choice_index := clampi(video_capture_omega_choice, 0, choices.size() - 1)
	var mutation_id := String(choices[choice_index].get("id", ""))
	if not mutation_id.is_empty():
		active.set_legendary_mutation(mutation_id)

func _on_deck_regenerated(_new_spawn: Vector2, new_seed: int) -> void:
	mecha_manager.relocate_after_deck_regeneration()
	var active := mecha_manager.get_active_mecha()
	if active != null and _run_time > 1.0:
		active.repair_hull(10)
	if _run_time > 1.0 and not _deck_transition_active:
		_show_banner("DECK %d" % _deck_number)
	_update_hud()

func _start_deck_transition(cheat_cycle: bool = false) -> void:
	if _deck_transition_active or _game_over or _run_complete:
		return
	var active := mecha_manager.get_active_mecha()
	if active == null:
		_deck_number = _next_deck_number(cheat_cycle)
		_update_next_deck_time_after_transition(cheat_cycle)
		deck.set_deck_palette(_deck_number)
		deck.generate_new_level()
		return

	_deck_transition_active = true
	enemy_manager.set_spawning_enabled(false)
	get_tree().paused = true
	active.begin_deck_transition()
	_show_banner("DECK TRANSFER", 0.62)
	SFX.play_ui(self, "boost", -12.5, 0.72)

	var out_tween := create_tween()
	out_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	out_tween.set_parallel(true)
	out_tween.tween_method(Callable(active, "set_deck_transition_amount"), 0.0, 1.0, 0.64).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	out_tween.tween_method(Callable(active, "set_transition_camera_zoom"), 1.0, 1.22, 0.64).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	out_tween.tween_method(Callable(self, "_set_deck_transition_overlay_amount"), 0.0, 0.72, 0.64).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if _top_hud != null:
		out_tween.tween_property(_top_hud, "modulate:a", 0.18, 0.34)
	await out_tween.finished

	_deck_number = _next_deck_number(cheat_cycle)
	_update_next_deck_time_after_transition(cheat_cycle)
	deck.set_deck_palette(_deck_number)
	# generate_new_level() performs a second, post-generation runtime bind after
	# every new wall/floor visual exists, so the selected palette is guaranteed
	# to be attached to the newly generated deck before the overlay clears.
	deck.generate_new_level()

	active = mecha_manager.get_active_mecha()
	if active != null:
		active.prepare_deck_materialize()
		active.set_transition_camera_zoom(1.22)
		active.set_deck_transition_scale(0.0)

	_set_deck_transition_overlay_amount(0.92)
	SFX.play_ui(self, "boost", -14.0, 1.12)
	_show_banner("DECK %d   %s" % [_deck_number, deck.get_deck_palette_name(_deck_number)], 0.95)

	var in_tween := create_tween()
	in_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	in_tween.set_parallel(true)
	if active != null:
		in_tween.tween_method(Callable(active, "set_deck_transition_amount"), 1.0, 0.0, 0.76).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		in_tween.tween_method(Callable(active, "set_transition_camera_zoom"), 1.22, 1.0, 0.92).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		in_tween.tween_method(Callable(active, "set_deck_transition_scale"), 0.0, 1.0, 0.76).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	in_tween.tween_method(Callable(self, "_set_deck_transition_overlay_amount"), 0.92, 0.0, 0.84).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if _top_hud != null:
		in_tween.tween_property(_top_hud, "modulate:a", 1.0, 0.52)
	await in_tween.finished

	if active != null:
		active.end_deck_transition()
	_set_deck_transition_overlay_amount(0.0)
	get_tree().paused = false
	enemy_manager.set_spawning_enabled(true)
	_deck_transition_active = false
	_update_hud()

func _next_deck_number(cheat_cycle: bool) -> int:
	if not cheat_cycle:
		return _deck_number + 1
	var palette_count := maxi(1, deck.get_deck_palette_count())
	return (_deck_number % palette_count) + 1

func _update_next_deck_time_after_transition(cheat_cycle: bool) -> void:
	if cheat_cycle:
		# Give the player a full four minutes from the cheat-selected deck instead
		# of immediately tripping the scheduled transition afterwards.
		_next_deck_time = _run_time + DECK_DURATION
	else:
		_next_deck_time += DECK_DURATION

func _build_deck_transition_overlay() -> void:
	_deck_transition_overlay = ColorRect.new()
	_deck_transition_overlay.name = "DeckTransitionOverlay"
	_deck_transition_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_deck_transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_deck_transition_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	_deck_transition_overlay.z_index = 850
	_deck_transition_overlay.color = Color.WHITE
	hud.add_child(_deck_transition_overlay)

	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float amount : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(17.13, 91.77))) * 43758.5453);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float edge = smoothstep(0.18, 1.05, max(abs(p.x), abs(p.y)));
	float scan = step(0.72, fract(FRAGCOORD.y * 0.125 + TIME * 5.0));
	float pixel_noise = hash(floor(FRAGCOORD.xy / 4.0));
	float breakup = step(0.86, pixel_noise) * amount * 0.11;
	vec3 cyan = vec3(0.20, 0.78, 0.88);
	vec3 deep = vec3(0.005, 0.012, 0.020);
	float glow = edge * amount * 0.30 + scan * edge * amount * 0.08;
	float alpha = amount * 0.78 + breakup;
	COLOR = vec4(mix(deep, cyan, glow), clamp(alpha, 0.0, 0.92));
}
"""
	_deck_transition_overlay_material = ShaderMaterial.new()
	_deck_transition_overlay_material.shader = shader
	_deck_transition_overlay_material.set_shader_parameter("amount", 0.0)
	_deck_transition_overlay.material = _deck_transition_overlay_material

func _set_deck_transition_overlay_amount(value: float) -> void:
	if _deck_transition_overlay_material != null:
		_deck_transition_overlay_material.set_shader_parameter("amount", clampf(value, 0.0, 1.0))

func _update_hud() -> void:
	if _hud_mecha == null:
		return

	var active := mecha_manager.get_active_mecha()

	if active == null:
		_hud_mecha.text = "NO MECHA"
		_hud_hull.text = "HULL: NA"
		_hud_level.text = "LV: %02d" % _level
		_hud_salvage.text = "SALV: %02d/%02d" % [_salvage, _salvage_required]
		_hud_omega.text = "OMEGA --"
		_hud_time.text = _format_time(_run_time)
		_hud_deck.text = "DECK: %d %s" % [
			_deck_number,
			deck.get_deck_palette_name(_deck_number)
		]
		_hud_hostiles.text = "FOES: %02d" % enemy_manager.get_alive_count()
		return

	_hud_mecha.text = mecha_manager.get_active_mecha_name()
	_hud_hull.text = "HULL %03d/%03d" % [
		active.get_hull(),
		active.get_max_hull()
	]
	_hud_level.text = "LV %02d" % _level
	_hud_salvage.text = "SALV %02d/%02d" % [
		_salvage,
		_salvage_required
	]
	if active.has_legendary_mutation():
		if active.is_omega_primary_selected():
			_hud_omega.text = "OMEGA %s" % active.get_legendary_mutation_hud_name()
		else:
			_hud_omega.text = "OMEGA NORM"
	elif _omega_core_stored:
		_hud_omega.text = "OMEGA HELD"
	elif active.get_primary_ability_tier() >= 3 and active.has_omega_mutations():
		# Tier III means this chassis is eligible for a Core; it does not mean a Core has dropped.
		_hud_omega.text = "OMEGA SEEK"
	else:
		_hud_omega.text = "OMEGA --"
	_hud_time.text = _format_time(_run_time)
	_hud_deck.text = "DECK %d %s" % [
		_deck_number,
		deck.get_deck_palette_name(_deck_number)
	]
	_hud_hostiles.text = "FOES %02d" % enemy_manager.get_alive_count()

	var hull_ratio := float(active.get_hull()) / float(maxi(1, active.get_max_hull()))

	if hull_ratio <= 0.30:
		_hud_hull.add_theme_color_override(
			"font_color",
			Color(1.0, 0.34, 0.28, 1.0)
		)
	elif hull_ratio <= 0.60:
		_hud_hull.add_theme_color_override(
			"font_color",
			Color(1.0, 0.72, 0.28, 1.0)
		)
	else:
		_hud_hull.add_theme_color_override(
			"font_color",
			Color(0.45, 1.0, 0.72, 1.0)
		)
		
func _format_time(seconds: float) -> String:
	var total := maxi(0, int(floor(seconds)))
	return "%02d:%02d" % [int(total / 60), total % 60]
	
func _hide_legacy_hud() -> void:
	# Keep the old scene nodes as harmless placeholders so existing scene UIDs stay
	# stable, but never show them. A dedicated menu can reuse them later.
	$HUD/Title.hide()
	$HUD/Subtitle.hide()
	$HUD/TopLeft.hide()
	$HUD/Controls.hide()
	$HUD/BottomCenter.hide()
	$HUD/Intro.hide()

func _build_omega_guidance() -> void:
	_omega_guide = Node2D.new()
	_omega_guide.name = "OmegaGuidance"
	_omega_guide.z_as_relative = false
	_omega_guide.z_index = 1450
	_omega_guide.visible = false
	hud.add_child(_omega_guide)

	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	_omega_guide_glow = Polygon2D.new()
	_omega_guide_glow.polygon = PackedVector2Array([
		Vector2(15.0, 0.0), Vector2(-7.0, -9.0), Vector2(-2.0, 0.0), Vector2(-7.0, 9.0)
	])
	_omega_guide_glow.color = Color(1.15, 0.12, 1.75, 0.22)
	_omega_guide_glow.material = additive
	_omega_guide.add_child(_omega_guide_glow)

	_omega_guide_arrow = Polygon2D.new()
	_omega_guide_arrow.polygon = PackedVector2Array([
		Vector2(11.0, 0.0), Vector2(-5.0, -5.0), Vector2(-1.0, 0.0), Vector2(-5.0, 5.0)
	])
	_omega_guide_arrow.color = Color(3.2, 0.72, 3.8, 0.96)
	_omega_guide_arrow.material = additive
	_omega_guide.add_child(_omega_guide_arrow)

	_omega_guide_label = Label.new()
	_omega_guide_label.text = "OMEGA"
	_omega_guide_label.position = Vector2(-30.0, 10.0)
	_omega_guide_label.size = Vector2(60.0, 18.0)
	_omega_guide_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_omega_guide_label.add_theme_font_override("font", load("res://Fonts/mago1.ttf") as Font)
	_omega_guide_label.add_theme_font_size_override("font_size", 12)
	_omega_guide_label.add_theme_color_override("font_color", Color(1.0, 0.56, 1.0, 1.0))
	_omega_guide.add_child(_omega_guide_label)

func _update_omega_guidance() -> void:
	if _omega_guide == null or enemy_manager == null or _menu_open or _game_over or _run_complete:
		if _omega_guide != null:
			_omega_guide.visible = false
		return
	var target := enemy_manager.get_omega_guidance_target()
	if target == null or not is_instance_valid(target) or not target.is_inside_tree():
		_omega_guide.visible = false
		return

	var viewport_size := get_viewport().get_visible_rect().size
	var target_screen := target.get_global_transform_with_canvas().origin
	var safe_rect := Rect2(Vector2(34.0, 54.0), Vector2(maxf(1.0, viewport_size.x - 68.0), maxf(1.0, viewport_size.y - 88.0)))
	if safe_rect.has_point(target_screen):
		_omega_guide.visible = false
		return

	var center := safe_rect.position + safe_rect.size * 0.5
	var direction := target_screen - center
	if direction.length_squared() <= 0.01:
		_omega_guide.visible = false
		return
	var half := safe_rect.size * 0.5
	var scale_to_edge := 99999.0
	if absf(direction.x) > 0.001:
		scale_to_edge = minf(scale_to_edge, half.x / absf(direction.x))
	if absf(direction.y) > 0.001:
		scale_to_edge = minf(scale_to_edge, half.y / absf(direction.y))
	var edge_position := center + direction * scale_to_edge * 0.92
	_omega_guide.position = edge_position.round()
	_omega_guide_arrow.rotation = direction.angle()
	_omega_guide_glow.rotation = direction.angle()
	var pulse := 0.78 + sin(float(Time.get_ticks_msec()) * 0.008) * 0.18
	_omega_guide.modulate.a = pulse
	_omega_guide_label.text = "OMEGA CORE" if target.is_in_group("omega_core_pickups") else "OMEGA"
	_omega_guide.visible = true

func _build_compact_hud() -> void:
	_top_hud = MarginContainer.new()
	_top_hud.name = "TopStats"
	_top_hud.anchor_left = 0.0
	_top_hud.anchor_top = 0.0
	_top_hud.anchor_right = 1.0
	_top_hud.anchor_bottom = 0.0
	_top_hud.offset_left = 8.0
	_top_hud.offset_top = 7.0
	_top_hud.offset_right = -8.0
	_top_hud.offset_bottom = 41.0
	_top_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_top_hud)

	var outer_panel := PanelContainer.new()
	var outer_style := StyleBoxFlat.new()
	outer_style.bg_color = Color(0.018, 0.027, 0.039, 0.92)
	outer_style.border_width_left = 1
	outer_style.border_width_top = 1
	outer_style.border_width_right = 1
	outer_style.border_width_bottom = 1
	outer_style.border_color = Color(0.16, 0.30, 0.36, 0.95)
	outer_style.corner_radius_top_left = 3
	outer_style.corner_radius_top_right = 3
	outer_style.corner_radius_bottom_left = 3
	outer_style.corner_radius_bottom_right = 3
	outer_panel.add_theme_stylebox_override("panel", outer_style)
	_top_hud.add_child(outer_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_top", 3)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_bottom", 3)
	outer_panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	margin.add_child(row)

	_hud_mecha = _make_stat_cell(row, Color(0.48, 0.92, 1.0, 1.0))
	_hud_hull = _make_stat_cell(row, Color(0.45, 1.0, 0.72, 1.0))
	_hud_level = _make_stat_cell(row, Color(0.80, 0.62, 1.0, 1.0))
	_hud_salvage = _make_stat_cell(row, Color(1.0, 0.80, 0.38, 1.0))
	_hud_omega = _make_stat_cell(row, Color(0.96, 0.44, 1.0, 1.0))
	_hud_omega.add_theme_font_size_override("font_size", 13)
	_hud_time = _make_stat_cell(row, Color(0.72, 0.88, 0.96, 1.0))
	_hud_deck = _make_stat_cell(row, Color(0.47, 0.76, 1.0, 1.0))
	_hud_hostiles = _make_stat_cell(row, Color(1.0, 0.48, 0.34, 1.0))

func _make_stat_cell(row: HBoxContainer, color: Color) -> Label:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r * 0.055, color.g * 0.055, color.b * 0.055, 0.72)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(color.r * 0.42, color.g * 0.42, color.b * 0.42, 0.72)
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	panel.add_theme_stylebox_override("panel", style)
	row.add_child(panel)

	var label := Label.new()
	label.custom_minimum_size = Vector2(0.0, 22.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", load("res://Fonts/mago1.ttf") as Font)
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", color)
	panel.add_child(label)
	return label

func _set_standard_hud_visible(value: bool) -> void:
	_hud_visible = value
	if _top_hud != null:
		_top_hud.visible = value

func _build_damage_overlay() -> void:
	_damage_overlay = ColorRect.new()
	_damage_overlay.name = "DamageOverlay"
	_damage_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_damage_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_damage_overlay.z_index = 900
	_damage_overlay.color = Color.WHITE
	hud.add_child(_damage_overlay)

	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float edge = smoothstep(0.26, 1.02, max(abs(p.x), abs(p.y)));
	float corner = smoothstep(0.48, 1.22, length(p));
	float scan = step(0.58, fract(FRAGCOORD.y * 0.25));
	float alpha = max(edge * 0.54, corner * 0.36) * intensity;
	alpha += scan * edge * intensity * 0.08;
	COLOR = vec4(0.92, 0.055, 0.025, clamp(alpha, 0.0, 0.68));
}
"""
	_damage_material = ShaderMaterial.new()
	_damage_material.shader = shader
	_damage_material.set_shader_parameter("intensity", 0.0)
	_damage_overlay.material = _damage_material

func _trigger_damage_overlay(strength: float = 1.0) -> void:
	_damage_intensity = maxf(_damage_intensity, clampf(strength, 0.0, 1.0))
	if _damage_material != null:
		_damage_material.set_shader_parameter("intensity", _damage_intensity)

func _update_damage_overlay(delta: float) -> void:
	if _damage_intensity <= 0.0:
		return
	_damage_intensity = maxf(0.0, _damage_intensity - delta * 5.8)
	if _damage_material != null:
		_damage_material.set_shader_parameter("intensity", _damage_intensity)

func _build_run_summary_overlay() -> void:
	_run_summary_overlay = CenterContainer.new()
	_run_summary_overlay.name = "RunSummary"
	_run_summary_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_run_summary_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_run_summary_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	_run_summary_overlay.z_index = 700
	_run_summary_overlay.visible = false
	hud.add_child(_run_summary_overlay)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(330.0, 218.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.014, 0.021, 0.032, 0.96)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.24, 0.72, 0.82, 0.92)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override("panel", style)
	_run_summary_overlay.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	margin.add_child(box)

	_run_summary_title = Label.new()
	_run_summary_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_run_summary_title.add_theme_font_override("font", load("res://Fonts/mago2.ttf") as Font)
	_run_summary_title.add_theme_font_size_override("font_size", 32)
	_run_summary_title.add_theme_color_override("font_color", Color(0.62, 0.94, 1.0, 1.0))
	box.add_child(_run_summary_title)

	_run_summary_text = Label.new()
	_run_summary_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_run_summary_text.add_theme_font_override("font", load("res://Fonts/mago1.ttf") as Font)
	_run_summary_text.add_theme_font_size_override("font_size", 18)
	_run_summary_text.add_theme_color_override("font_color", Color(0.82, 0.89, 0.93, 1.0))
	box.add_child(_run_summary_text)

	_run_summary_menu_button = Button.new()
	_run_summary_menu_button.custom_minimum_size = Vector2(0.0, 42.0)
	_run_summary_menu_button.text = "MAIN MENU"
	_run_summary_menu_button.focus_mode = Control.FOCUS_ALL
	_run_summary_menu_button.add_theme_font_override("font", load("res://Fonts/mago2.ttf") as Font)
	_run_summary_menu_button.add_theme_font_size_override("font_size", 20)
	_run_summary_menu_button.add_theme_color_override("font_color", Color(0.68, 0.96, 1.0, 1.0))
	_run_summary_menu_button.add_theme_color_override("font_hover_color", Color(0.82, 1.0, 1.0, 1.0))
	_run_summary_menu_button.add_theme_color_override("font_pressed_color", Color(0.52, 0.82, 0.88, 1.0))

	var button_normal := StyleBoxFlat.new()
	button_normal.bg_color = Color(0.018, 0.035, 0.046, 0.96)
	button_normal.border_width_left = 1
	button_normal.border_width_top = 1
	button_normal.border_width_right = 1
	button_normal.border_width_bottom = 1
	button_normal.border_color = Color(0.18, 0.48, 0.56, 0.92)
	button_normal.corner_radius_top_left = 3
	button_normal.corner_radius_top_right = 3
	button_normal.corner_radius_bottom_left = 3
	button_normal.corner_radius_bottom_right = 3
	_run_summary_menu_button.add_theme_stylebox_override("normal", button_normal)

	var button_hover := button_normal.duplicate() as StyleBoxFlat
	button_hover.bg_color = Color(0.026, 0.060, 0.074, 0.98)
	button_hover.border_color = Color(0.28, 0.76, 0.84, 0.98)
	_run_summary_menu_button.add_theme_stylebox_override("hover", button_hover)

	var button_pressed := button_normal.duplicate() as StyleBoxFlat
	button_pressed.bg_color = Color(0.012, 0.027, 0.036, 1.0)
	button_pressed.border_color = Color(0.22, 0.62, 0.70, 0.98)
	_run_summary_menu_button.add_theme_stylebox_override("pressed", button_pressed)
	_run_summary_menu_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_run_summary_menu_button.pressed.connect(_return_to_main_menu)
	box.add_child(_run_summary_menu_button)

func _show_run_summary(completed: bool) -> void:
	if _run_summary_overlay == null:
		return
	_menu_open = true
	get_tree().paused = true
	enemy_manager.set_spawning_enabled(false)
	if _upgrade_overlay != null:
		_upgrade_overlay.hide()
	if _omega_overlay != null:
		_omega_overlay.hide()
	if _mecha_select_overlay != null:
		_mecha_select_overlay.hide()
	if deck_banner != null:
		deck_banner.hide()
	_set_standard_hud_visible(false)

	var active := mecha_manager.get_active_mecha()
	var chassis := mecha_manager.get_active_mecha_name()
	if active == null and chassis == "NONE":
		chassis = "MECHA"
	var best := _record_and_get_best_time(_run_time)
	_run_summary_title.text = "RUN COMPLETE" if completed else "GAME OVER   //   MECHA LOST"
	_run_summary_text.text = "SURVIVED   %s\nKILLS      %03d\nLEVEL      %02d\nDECK       %02d\nCHASSIS    %s\nBEST       %s" % [
		_format_time(_run_time), enemy_manager.get_total_kills(), _level, _deck_number, chassis, _format_time(best)
	]
	_run_summary_overlay.show()
	if _run_summary_menu_button != null:
		_run_summary_menu_button.grab_focus()

func _return_to_main_menu() -> void:
	_show_mecha_select("SELECT A CHASSIS")

func _record_and_get_best_time(value: float) -> float:
	var config := ConfigFile.new()
	var path := "user://spacemecha_stats.cfg"
	var best := 0.0
	if config.load(path) == OK:
		best = float(config.get_value("survival", "best_seconds", 0.0))
	if value > best:
		best = value
		config.set_value("survival", "best_seconds", best)
		config.save(path)
	return best

func _show_banner(message: String, hold_time: float = 0.8) -> void:
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	deck_banner_text.text = message
	deck_banner.show()
	deck_banner.modulate.a = 1.0
	_banner_tween = create_tween()
	_banner_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_banner_tween.tween_interval(hold_time)
	_banner_tween.tween_property(deck_banner, "modulate:a", 0.0, 0.28)
	_banner_tween.tween_callback(deck_banner.hide)

func _build_upgrade_overlay() -> void:
	_upgrade_overlay = CenterContainer.new()
	_upgrade_overlay.name = "UpgradeOverlay"
	_upgrade_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_upgrade_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_upgrade_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	_upgrade_overlay.visible = false
	hud.add_child(_upgrade_overlay)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(470.0, 238.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.026, 0.038, 0.96)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.25, 0.78, 0.88, 0.95)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override("panel", style)
	_upgrade_overlay.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	var font_large := load("res://Fonts/mago2.ttf") as Font
	var font_small := load("res://Fonts/mago1.ttf") as Font

	_upgrade_title = Label.new()
	_upgrade_title.text = "SALVAGE LEVEL %02d" % _level
	_upgrade_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_upgrade_title.add_theme_font_override("font", font_large)
	_upgrade_title.add_theme_font_size_override("font_size", 32)
	_upgrade_title.add_theme_color_override("font_color", Color(0.62, 0.94, 1.0, 1.0))
	box.add_child(_upgrade_title)

	var hint := Label.new()
	hint.text = "SELECT ONE UPGRADE   1  2  3"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_override("font", font_small)
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(0.62, 0.7, 0.76, 1.0))
	box.add_child(hint)

	for index in range(3):
		var button := Button.new()
		button.custom_minimum_size = Vector2(430.0, 46.0)
		button.add_theme_font_override("font", font_small)
		button.add_theme_font_size_override("font_size", 16)
		button.focus_mode = Control.FOCUS_ALL
		
		button.pressed.connect(_choose_upgrade.bind(index))
		box.add_child(button)
		_upgrade_buttons.append(button)

func _build_omega_overlay() -> void:
	_omega_overlay = CenterContainer.new()
	_omega_overlay.name = "OmegaMutationOverlay"
	_omega_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_omega_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_omega_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	_omega_overlay.visible = false
	hud.add_child(_omega_overlay)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560.0, 304.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.012, 0.052, 0.975)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.88, 0.22, 1.0, 0.95)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override("panel", style)
	_omega_overlay.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 9)
	margin.add_child(box)
	var font_large := load("res://Fonts/mago2.ttf") as Font
	var font_small := load("res://Fonts/mago1.ttf") as Font

	_omega_title = Label.new()
	_omega_title.text = "OMEGA MUTATION"
	_omega_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_omega_title.add_theme_font_override("font", font_large)
	_omega_title.add_theme_font_size_override("font_size", 34)
	_omega_title.add_theme_color_override("font_color", Color(1.0, 0.55, 1.0, 1.0))
	box.add_child(_omega_title)

	_omega_hint = Label.new()
	_omega_hint.text = "SIGNATURE PRIMARY // SELECT ONE LEGENDARY EVOLUTION   1  2  3"
	_omega_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_omega_hint.add_theme_font_override("font", font_small)
	_omega_hint.add_theme_font_size_override("font_size", 15)
	_omega_hint.add_theme_color_override("font_color", Color(0.78, 0.62, 0.82, 1.0))
	box.add_child(_omega_hint)

	for index in range(3):
		var button := Button.new()
		button.custom_minimum_size = Vector2(510.0, 58.0)
		button.add_theme_font_override("font", font_small)
		button.add_theme_font_size_override("font_size", 15)
		button.focus_mode = Control.FOCUS_ALL
		button.pressed.connect(_choose_omega_mutation.bind(index))
		box.add_child(button)
		_omega_buttons.append(button)

func _present_omega_choices() -> void:
	var active := mecha_manager.get_active_mecha()
	if active == null:
		return

	_omega_choices.assign(active.get_omega_mutation_choices())

	if _omega_choices.is_empty():
		return

	_omega_title.text = "OMEGA MUTATION   %s" % active.get_display_name()

	if _omega_hint != null:
		_omega_hint.text = "%s // SELECT ONE LEGENDARY EVOLUTION   1  2  3" % active.get_omega_signature_name()

	for i in range(_omega_buttons.size()):
		if i < _omega_choices.size():
			_omega_buttons[i].text = "%d   %s" % [
				i + 1,
				String(_omega_choices[i].get("label", "OMEGA MUTATION"))
			]
			_omega_buttons[i].disabled = false
		else:
			_omega_buttons[i].text = "%d   --" % [i + 1]
			_omega_buttons[i].disabled = true

	if _omega_guide != null:
		_omega_guide.visible = false
	_omega_overlay.show()
	_omega_buttons[0].grab_focus()
	SFX.play_ui(self, "level", -4.0, 0.66)
	get_tree().paused = true
	
func _choose_omega_mutation(index: int) -> void:
	if _omega_overlay == null or not _omega_overlay.visible:
		return
	if index < 0 or index >= _omega_choices.size():
		return
	var active := mecha_manager.get_active_mecha()
	if active == null:
		return
	var mutation_id := String(_omega_choices[index]["id"])
	if not active.set_legendary_mutation(mutation_id):
		return
	_omega_core_stored = false
	_omega_overlay.hide()
	get_tree().paused = false
	SFX.play_ui(self, "secondary", -4.0, 0.72)
	_show_banner("LEGENDARY ONLINE   %s\nMOUSE WHEEL   SWITCH LMB / OMEGA" % active.get_legendary_mutation_display_name(), 1.35)
	_update_hud()
	call_deferred("_check_level_up")

func _present_upgrade_choices() -> void:
	var active := mecha_manager.get_active_mecha()
	if active == null:
		return

	var generic_pool: Array[Dictionary] = [
		{"id": "primary", "label": "PRIMARY COOLING   REDUCE PRIMARY COOLDOWN 15"},
		{"id": "impact", "label": "IMPACT AMPLIFIER   INCREASE IMPACT RADIUS 18"},
		{"id": "hull", "label": "HULL PLATING   ADD 20 MAX HULL AND REPAIR"},
		{"id": "servo", "label": "SERVO BOOST   INCREASE MOVE SPEED 8"},
		{"id": "magnet", "label": "SALVAGE MAGNET   INCREASE PICKUP RANGE 20"},
	]
	if active.get_hull() < active.get_max_hull():
		generic_pool.append({"id": "repair", "label": "FIELD REPAIR   RESTORE 30 HULL"})
	if active.is_secondary_unlocked():
		generic_pool.append({"id": "secondary", "label": "SECONDARY COOLING   REDUCE SECONDARY COOLDOWN 15"})

	var ability_pool: Array[Dictionary] = []
	if active.can_upgrade_primary_ability():
		ability_pool.append({"id": "primary_ability", "label": active.get_primary_upgrade_label()})
	if active.can_upgrade_secondary_ability():
		ability_pool.append({"id": "secondary_ability", "label": active.get_secondary_upgrade_label()})

	# Keep the chassis identity moving forward: until its ability trees are
	# capped, every level-up offers at least one chassis-specific evolution.
	for i in range(ability_pool.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var temp := ability_pool[i]
		ability_pool[i] = ability_pool[j]
		ability_pool[j] = temp
	for i in range(generic_pool.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var temp := generic_pool[i]
		generic_pool[i] = generic_pool[j]
		generic_pool[j] = temp

	_upgrade_choices.clear()
	if not ability_pool.is_empty():
		_upgrade_choices.append(ability_pool[0])
	for option in generic_pool:
		if _upgrade_choices.size() >= 3:
			break
		_upgrade_choices.append(option)
	if _upgrade_choices.size() < 3 and ability_pool.size() > 1:
		_upgrade_choices.append(ability_pool[1])

	for i in range(_upgrade_buttons.size()):
		if i < _upgrade_choices.size():
			_upgrade_buttons[i].text = "%d   %s" % [i + 1, String(_upgrade_choices[i]["label"])]
			_upgrade_buttons[i].disabled = false
		else:
			_upgrade_buttons[i].text = ""
			_upgrade_buttons[i].disabled = true

	_upgrade_title.text = "SALVAGE LEVEL %02d" % _level
	if _omega_guide != null:
		_omega_guide.visible = false
	_upgrade_overlay.show()
	_upgrade_buttons[0].grab_focus()
	get_tree().paused = true

func _choose_upgrade(index: int) -> void:
	if _upgrade_overlay == null or not _upgrade_overlay.visible:
		return
	if index < 0 or index >= _upgrade_choices.size():
		return
	var active := mecha_manager.get_active_mecha()
	if active == null:
		return

	var choice_id := String(_upgrade_choices[index]["id"])
	match choice_id:
		"primary":
			active.apply_primary_cooling(0.85)
		"primary_ability":
			active.upgrade_primary_ability()
		"secondary":
			active.apply_secondary_cooling(0.85)
		"secondary_ability":
			active.upgrade_secondary_ability()
		"impact":
			active.apply_impact_multiplier(1.18)
		"hull":
			active.add_max_hull(20, 20)
		"servo":
			active.apply_move_speed_multiplier(1.08)
		"repair":
			active.repair_hull(30)
		"magnet":
			_salvage_magnet_radius = minf(220.0, _salvage_magnet_radius * 1.20)

	_upgrade_overlay.hide()
	get_tree().paused = false
	_update_hud()
	if _omega_core_stored:
		call_deferred("_try_open_omega_mutation")
	else:
		call_deferred("_check_level_up")
