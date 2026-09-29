extends Node2D

const InputSetupScript = preload("res://Scripts/input_setup.gd")
const SFX = preload("res://Scripts/sound_fx.gd")

const RUN_DURATION := 20.0 * 60.0
const DECK_DURATION := 4.0 * 60.0
const SECONDARY_UNLOCK_TIME := 60.0

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
var _deck_transition_active := false
var _deck_transition_overlay: ColorRect
var _deck_transition_overlay_material: ShaderMaterial

func _enter_tree() -> void:
	add_to_group("survival_manager")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	InputSetupScript.ensure_actions()
	_rng.randomize()
	deck.regenerated.connect(_on_deck_regenerated)
	mecha_manager.active_mecha_changed.connect(_on_active_mecha_changed)

	_hide_legacy_hud()
	deck_banner.hide()
	deck_banner.z_index = 1100
	_build_compact_hud()
	_build_damage_overlay()
	_build_deck_transition_overlay()
	_build_upgrade_overlay()
	_build_run_summary_overlay()
	_set_standard_hud_visible(true)
	deck.set_deck_palette(_deck_number)

	var active := mecha_manager.get_active_mecha()
	if active != null:
		_on_active_mecha_changed(active)
	enemy_manager.reset_run()
	_update_hud()

func _process(delta: float) -> void:
	_update_damage_overlay(delta)

	if (_game_over or _run_complete) and Input.is_action_just_pressed("regenerate_level"):
		_restart_run()
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
		_start_deck_transition()

	_update_hud()

func _unhandled_input(event: InputEvent) -> void:
	if _upgrade_overlay == null or not _upgrade_overlay.visible:
		return
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return
		if key_event.keycode == KEY_1:
			_choose_upgrade(0)
		elif key_event.keycode == KEY_2:
			_choose_upgrade(1)
		elif key_event.keycode == KEY_3:
			_choose_upgrade(2)

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

func _check_level_up() -> void:
	if _upgrade_overlay != null and _upgrade_overlay.visible:
		return
	if _salvage < _salvage_required:
		return
	_salvage -= _salvage_required
	_level += 1
	_salvage_required = 5 + _level * 4
	SFX.play(self, "level", -8.0, 1.0)
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
	mecha.set_secondary_unlocked(_secondary_announced)
	_last_hull = mecha.get_hull()
	_low_hull_warned = false
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
	get_tree().paused = false
	_show_banner("MECHA LOST", 1.2)
	_show_run_summary(false)
	_update_hud()

func _complete_run() -> void:
	if _run_complete:
		return
	_run_complete = true
	enemy_manager.set_spawning_enabled(false)
	_show_banner("EXTRACTION COMPLETE", 1.5)
	_show_run_summary(true)
	_update_hud()

func _restart_run() -> void:
	get_tree().paused = false
	if _upgrade_overlay != null:
		_upgrade_overlay.hide()
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
	deck.set_deck_palette(_deck_number)
	deck.generate_new_level()
	mecha_manager.start_new_run(true)
	enemy_manager.reset_run()
	_update_hud()

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
	SFX.play(self, "boost", -12.5, 0.72)

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
	SFX.play(self, "boost", -14.0, 1.12)
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
		_hud_hull.text = "HULL NA"
		_hud_level.text = "LV %02d" % _level
		_hud_salvage.text = "SALV %02d OF %02d" % [_salvage, _salvage_required]
		_hud_time.text = _format_time(_run_time)
		_hud_deck.text = "DECK %d  %s" % [_deck_number, deck.get_deck_palette_name(_deck_number)]
		_hud_hostiles.text = "FOES %02d" % enemy_manager.get_alive_count()
		return

	_hud_mecha.text = mecha_manager.get_active_mecha_name()
	_hud_hull.text = "HULL %03d OF %03d" % [active.get_hull(), active.get_max_hull()]
	_hud_level.text = "LV %02d" % _level
	_hud_salvage.text = "SALV %02d OF %02d" % [_salvage, _salvage_required]
	_hud_time.text = _format_time(_run_time)
	_hud_deck.text = "DECK %d  %s" % [_deck_number, deck.get_deck_palette_name(_deck_number)]
	_hud_hostiles.text = "FOES %02d" % enemy_manager.get_alive_count()

	var hull_ratio := float(active.get_hull()) / float(maxi(1, active.get_max_hull()))
	if hull_ratio <= 0.30:
		_hud_hull.add_theme_color_override("font_color", Color(1.0, 0.34, 0.28, 1.0))
	elif hull_ratio <= 0.60:
		_hud_hull.add_theme_color_override("font_color", Color(1.0, 0.72, 0.28, 1.0))
	else:
		_hud_hull.add_theme_color_override("font_color", Color(0.45, 1.0, 0.72, 1.0))

func _format_time(seconds: float) -> String:
	var total := maxi(0, int(floor(seconds)))
	return "%02d %02d" % [int(total / 60), total % 60]

func _hide_legacy_hud() -> void:
	# Keep the old scene nodes as harmless placeholders so existing scene UIDs stay
	# stable, but never show them. A dedicated menu can reuse them later.
	$HUD/Title.hide()
	$HUD/Subtitle.hide()
	$HUD/TopLeft.hide()
	$HUD/Controls.hide()
	$HUD/BottomCenter.hide()
	$HUD/Intro.hide()

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
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", color)
	panel.add_child(label)
	return label

func _set_standard_hud_visible(_value: bool) -> void:
	# HULL, salvage/level and run state are core combat information and stay visible.
	_hud_visible = true
	if _top_hud != null:
		_top_hud.visible = true

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

	var hint := Label.new()
	hint.text = "G RB   NEW RUN"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_override("font", load("res://Fonts/mago1.ttf") as Font)
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(0.52, 0.72, 0.78, 1.0))
	box.add_child(hint)

func _show_run_summary(completed: bool) -> void:
	if _run_summary_overlay == null:
		return
	var active := mecha_manager.get_active_mecha()
	var chassis := mecha_manager.get_active_mecha_name()
	if active == null and chassis == "NONE":
		chassis = "MECHA"
	var best := _record_and_get_best_time(_run_time)
	_run_summary_title.text = "EXTRACTION COMPLETE" if completed else "MECHA LOST"
	_run_summary_text.text = "SURVIVED   %s\nKILLS      %03d\nLEVEL      %02d\nDECK       %02d\nCHASSIS    %s\nBEST       %s" % [
		_format_time(_run_time), enemy_manager.get_total_kills(), _level, _deck_number, chassis, _format_time(best)
	]
	_run_summary_overlay.show()

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
	call_deferred("_check_level_up")
