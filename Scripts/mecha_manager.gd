extends Node2D
class_name MechaManager

signal active_mecha_changed(mecha: MechaController)

const InputSetupScript = preload("res://Scripts/input_setup.gd")
const MECHA_SCENE = preload("res://Scenes/mecha.tscn")
const MECHA_IDS := ["M1", "M2", "M3", "R1", "R2", "R3", "R4", "S1", "S2", "S3"]

@export var deck_path := NodePath("../ProceduralDeck")
@export var randomize_each_run := true
@export var fixed_starting_mecha := "M1"
@export var auto_start := false

@onready var deck: ProceduralDeck = get_node(deck_path) as ProceduralDeck

var mechas: Array[MechaController] = []
var active_mecha: MechaController
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	InputSetupScript.ensure_actions()
	_rng.randomize()
	if auto_start:
		start_new_run(false)

func start_new_run(force_random: bool = true) -> void:
	_clear_mechas()
	var chosen_id := fixed_starting_mecha
	if randomize_each_run or force_random:
		chosen_id = MECHA_IDS[_rng.randi_range(0, MECHA_IDS.size() - 1)]
	_spawn_single_mecha(chosen_id)


func start_new_run_with_mecha(chosen_id: String) -> void:
	_clear_mechas()
	_spawn_single_mecha(chosen_id)

func _clear_mechas() -> void:
	for mecha in mechas:
		if mecha != null and is_instance_valid(mecha):
			mecha.queue_free()
	mechas.clear()
	active_mecha = null

func _spawn_single_mecha(chosen_id: String) -> void:
	var mecha := MECHA_SCENE.instantiate() as MechaController
	if mecha == null:
		return
	mecha.mecha_id = chosen_id if chosen_id in MECHA_IDS else "M1"
	mecha.position = deck.spawn_position
	add_child(mecha)
	mechas.append(mecha)
	_set_active_mecha(mecha)

func relocate_after_deck_regeneration() -> void:
	if active_mecha == null or not is_instance_valid(active_mecha):
		return
	active_mecha.teleport_to(deck.spawn_position)
	active_mecha.set_player_controlled(true)
	active_mecha_changed.emit(active_mecha)

func get_active_animation_name() -> String:
	if active_mecha == null or not is_instance_valid(active_mecha):
		return ""
	return active_mecha.get_animation_name()

func get_active_speed() -> float:
	if active_mecha == null or not is_instance_valid(active_mecha):
		return 0.0
	return active_mecha.get_speed()

func get_active_mecha_name() -> String:
	if active_mecha == null or not is_instance_valid(active_mecha):
		return "NONE"
	return active_mecha.get_display_name()

func get_active_mecha() -> MechaController:
	return active_mecha

func _set_active_mecha(mecha: MechaController) -> void:
	if mecha == null:
		return
	active_mecha = mecha
	active_mecha.set_player_controlled(true)
	active_mecha_changed.emit(active_mecha)
