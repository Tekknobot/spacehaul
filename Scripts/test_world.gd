extends Node2D

const InputSetupScript = preload("res://Scripts/input_setup.gd")

const RUN_DURATION := 20.0 * 60.0
const DECK_DURATION := 4.0 * 60.0
const SECONDARY_UNLOCK_TIME := 90.0

@onready var deck: ProceduralDeck = $ProceduralDeck
@onready var mecha_manager: MechaManager = $MechaManager
@onready var enemy_manager: SpacehaulEnemyManager = $EnemyManager
@onready var title_label: Label = $HUD/Title
@onready var subtitle_label: Label = $HUD/Subtitle
@onready var animation_label: Label = $HUD/TopLeft/Panel/Margin/VBox/Animation
@onready var speed_label: Label = $HUD/TopLeft/Panel/Margin/VBox/Speed
@onready var seed_label: Label = $HUD/TopLeft/Panel/Margin/VBox/Seed
@onready var controls_panel: Control = $HUD/Controls
@onready var controls_text: Label = $HUD/Controls/Margin/VBox/Text
@onready var status_label: Label = $HUD/BottomCenter/StatusPanel/Margin/Status
@onready var intro: Control = $HUD/Intro
@onready var deck_banner: Control = $HUD/DeckBanner
@onready var deck_banner_text: Label = $HUD/DeckBanner/Panel/Margin/Text
@onready var hud: CanvasLayer = $HUD

var _banner_tween: Tween
var _hud_visible := false
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

func _enter_tree() -> void:
	add_to_group("survival_manager")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	InputSetupScript.ensure_actions()
	_rng.randomize()
	deck.regenerated.connect(_on_deck_regenerated)
	mecha_manager.active_mecha_changed.connect(_on_active_mecha_changed)

	title_label.text = "SPACEMECHA"
	subtitle_label.text = "SURVIVAL DECK"
	controls_text.text = "WASD  LEFT STICK  MOVE\nSHIFT  LB  RUN\nHOLD LEFT MOUSE  RT  PRIMARY\nRIGHT MOUSE  LT  SECONDARY\nU  UI TOGGLE\nG  NEW RUN AFTER END"
	intro.hide()
	deck_banner.hide()
	_build_upgrade_overlay()
	_set_standard_hud_visible(false)

	var active := mecha_manager.get_active_mecha()
	if active != null:
		_on_active_mecha_changed(active)
	enemy_manager.reset_run()
	_update_hud()

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("toggle_ui") and (_upgrade_overlay == null or not _upgrade_overlay.visible):
		_set_standard_hud_visible(not _hud_visible)

	if (_game_over or _run_complete) and Input.is_action_just_pressed("regenerate_level"):
		_restart_run()
		return

	if get_tree().paused or _game_over or _run_complete:
		_update_hud()
		return

	_run_time += delta
	_update_secondary_unlock()

	if _run_time >= RUN_DURATION:
		_complete_run()
	elif _run_time >= _next_deck_time:
		_deck_number += 1
		_next_deck_time += DECK_DURATION
		deck.generate_new_level()

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
		_show_banner("SECONDARY ONLINE")

func _on_active_mecha_changed(mecha: MechaController) -> void:
	if mecha == null:
		return
	if not mecha.hull_changed.is_connected(_on_hull_changed):
		mecha.hull_changed.connect(_on_hull_changed)
	if not mecha.destroyed.is_connected(_on_player_destroyed):
		mecha.destroyed.connect(_on_player_destroyed)
	mecha.set_secondary_unlocked(_secondary_announced)
	_update_hud()

func _on_hull_changed(_current_hull: int, _max_hull: int) -> void:
	_update_hud()

func _on_player_destroyed(_mecha: MechaController) -> void:
	if _game_over:
		return
	_game_over = true
	enemy_manager.set_spawning_enabled(false)
	if _upgrade_overlay != null:
		_upgrade_overlay.hide()
	get_tree().paused = false
	_show_banner("MECHA LOST   G NEW RUN", 2.5)
	_update_hud()

func _complete_run() -> void:
	if _run_complete:
		return
	_run_complete = true
	enemy_manager.set_spawning_enabled(false)
	_show_banner("EXTRACTION COMPLETE   G NEW RUN", 3.0)
	_update_hud()

func _restart_run() -> void:
	get_tree().paused = false
	if _upgrade_overlay != null:
		_upgrade_overlay.hide()
	_run_time = 0.0
	_deck_number = 1
	_next_deck_time = DECK_DURATION
	_game_over = false
	_run_complete = false
	_secondary_announced = false
	_level = 1
	_salvage = 0
	_salvage_required = 6
	_salvage_magnet_radius = 86.0
	deck.generate_new_level()
	mecha_manager.start_new_run(true)
	enemy_manager.reset_run()
	_update_hud()

func _on_deck_regenerated(_new_spawn: Vector2, new_seed: int) -> void:
	mecha_manager.relocate_after_deck_regeneration()
	var active := mecha_manager.get_active_mecha()
	if active != null and _run_time > 1.0:
		active.repair_hull(10)
	if _run_time > 1.0:
		_show_banner("DECK %d" % _deck_number)
	_update_hud()

func _update_hud() -> void:
	var active := mecha_manager.get_active_mecha()
	var mecha_name := mecha_manager.get_active_mecha_name()
	if active == null:
		animation_label.text = "MECHA NONE"
		speed_label.text = "LEVEL %02d" % _level
		seed_label.text = "TIME %s  DECK %d" % [_format_time(_run_time), _deck_number]
		status_label.text = "NO ACTIVE CHASSIS"
		return

	animation_label.text = "%s  HULL %03d/%03d" % [mecha_name, active.get_hull(), active.get_max_hull()]
	speed_label.text = "LEVEL %02d  SALVAGE %02d/%02d" % [_level, _salvage, _salvage_required]
	seed_label.text = "TIME %s  DECK %d" % [_format_time(_run_time), _deck_number]

	var primary_text := "READY" if active.get_primary_cooldown_left() <= 0.0 else "%.1fs" % active.get_primary_cooldown_left()
	var secondary_text := "NONE"
	if active.has_secondary_ability():
		if not active.is_secondary_unlocked():
			secondary_text = "LOCKED"
		elif active.get_secondary_cooldown_left() <= 0.0:
			secondary_text = "READY"
		else:
			secondary_text = "%.1fs" % active.get_secondary_cooldown_left()

	status_label.text = "HOSTILES %02d  KILLS %03d  PRIMARY %s  SECONDARY %s" % [
		enemy_manager.get_alive_count(),
		enemy_manager.get_total_kills(),
		primary_text,
		secondary_text,
	]

func _format_time(seconds: float) -> String:
	var total := maxi(0, int(floor(seconds)))
	return "%02d:%02d" % [int(total / 60), total % 60]

func _set_standard_hud_visible(value: bool) -> void:
	_hud_visible = value
	title_label.visible = value
	subtitle_label.visible = value
	$HUD/TopLeft.visible = value
	controls_panel.visible = value
	$HUD/BottomCenter.visible = value

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

	var pool: Array[Dictionary] = [
		{"id": "primary", "label": "PRIMARY COOLING   -15% PRIMARY COOLDOWN"},
		{"id": "impact", "label": "IMPACT AMPLIFIER   +18% IMPACT RADIUS"},
		{"id": "hull", "label": "HULL PLATING   +20 MAX HULL AND REPAIR"},
		{"id": "servo", "label": "SERVO BOOST   +8% MOVE SPEED"},
		{"id": "magnet", "label": "SALVAGE MAGNET   +20% PICKUP RANGE"},
	]
	if active.get_hull() < active.get_max_hull():
		pool.append({"id": "repair", "label": "FIELD REPAIR   RESTORE 30 HULL"})
	if active.is_secondary_unlocked():
		pool.append({"id": "secondary", "label": "SECONDARY COOLING   -15% SECONDARY COOLDOWN"})

	for i in range(pool.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var temp := pool[i]
		pool[i] = pool[j]
		pool[j] = temp

	_upgrade_choices.clear()
	for i in range(mini(3, pool.size())):
		_upgrade_choices.append(pool[i])
		_upgrade_buttons[i].text = "%d   %s" % [i + 1, String(pool[i]["label"])]
		_upgrade_buttons[i].disabled = false

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
		"secondary":
			active.apply_secondary_cooling(0.85)
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
