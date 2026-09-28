extends Node2D

const InputSetupScript = preload("res://Scripts/input_setup.gd")

@onready var deck: ProceduralDeck = $ProceduralDeck
@onready var mecha_manager: MechaManager = $MechaManager
@onready var animation_label: Label = $HUD/TopLeft/Panel/Margin/VBox/Animation
@onready var speed_label: Label = $HUD/TopLeft/Panel/Margin/VBox/Speed
@onready var seed_label: Label = $HUD/TopLeft/Panel/Margin/VBox/Seed
@onready var status_label: Label = $HUD/BottomCenter/StatusPanel/Margin/Status
@onready var intro: Control = $HUD/Intro
@onready var deck_banner: Control = $HUD/DeckBanner
@onready var deck_banner_text: Label = $HUD/DeckBanner/Panel/Margin/Text
@onready var hud: CanvasLayer = $HUD

var _banner_tween: Tween
var _hud_visible := true

func _ready() -> void:
	InputSetupScript.ensure_actions()
	deck.regenerated.connect(_on_deck_regenerated)
	mecha_manager.active_mecha_changed.connect(_on_active_mecha_changed)
	_update_seed_label(deck.seed_value)
	_update_active_mecha_labels()
	_play_intro()

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("toggle_ui"):
		_hud_visible = not _hud_visible
		hud.visible = _hud_visible

	_update_active_mecha_labels()

	if Input.is_action_just_pressed("regenerate_level"):
		deck.generate_new_level()

func _update_active_mecha_labels() -> void:
	var mecha_name := mecha_manager.get_active_mecha_name()
	var animation_name := mecha_manager.get_active_animation_name().to_upper()
	animation_label.text = "MECHA %s  ANIMATION %s" % [mecha_name, animation_name]
	speed_label.text = "SPEED      %03d" % int(round(mecha_manager.get_active_speed()))
	status_label.text = "ACTIVE %s  TAB SWITCH  LEFT MOUSE ABILITY" % mecha_name

func _on_active_mecha_changed(_mecha: MechaController) -> void:
	_update_active_mecha_labels()

func _on_deck_regenerated(_new_spawn: Vector2, new_seed: int) -> void:
	mecha_manager.relocate_after_deck_regeneration()
	_update_seed_label(new_seed)
	_show_deck_banner(new_seed)

func _update_seed_label(value: int) -> void:
	seed_label.text = "DECK SEED  %d" % value

func _play_intro() -> void:
	intro.show()
	intro.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(0.85)
	tween.tween_property(intro, "modulate:a", 0.0, 0.35)
	tween.tween_callback(intro.hide)

func _show_deck_banner(new_seed: int) -> void:
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	deck_banner_text.text = "DECK %d" % new_seed
	deck_banner.show()
	deck_banner.modulate.a = 1.0
	_banner_tween = create_tween()
	_banner_tween.tween_interval(0.55)
	_banner_tween.tween_property(deck_banner, "modulate:a", 0.0, 0.28)
	_banner_tween.tween_callback(deck_banner.hide)
