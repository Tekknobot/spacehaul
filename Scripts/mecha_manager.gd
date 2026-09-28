extends Node2D
class_name MechaManager

signal active_mecha_changed(mecha: MechaController)

const InputSetupScript = preload("res://Scripts/input_setup.gd")
const MECHA_SCENE = preload("res://Scenes/mecha.tscn")
const MECHA_IDS := ["M1", "M2", "M3", "R1", "R2", "R3", "R4", "S1", "S2", "S3"]

@export var deck_path := NodePath("../ProceduralDeck")

@onready var deck: ProceduralDeck = get_node(deck_path) as ProceduralDeck

var mechas: Array[MechaController] = []
var active_mecha: MechaController
var _visited_ids: Dictionary = {}
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	InputSetupScript.ensure_actions()
	_rng.randomize()
	_spawn_all_mechas()
	_choose_random_starting_mecha()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("switch_mecha"):
		switch_to_next_closest()
		get_viewport().set_input_as_handled()

func _spawn_all_mechas() -> void:
	for child in get_children():
		child.queue_free()
	mechas.clear()

	var spawn_positions := deck.get_mecha_spawn_positions(MECHA_IDS.size())
	for index in range(MECHA_IDS.size()):
		var mecha := MECHA_SCENE.instantiate() as MechaController
		mecha.mecha_id = MECHA_IDS[index]
		if index < spawn_positions.size():
			mecha.position = spawn_positions[index]
		else:
			mecha.position = deck.spawn_position + Vector2(index * 12.0, 0.0)
		add_child(mecha)
		mecha.set_ai_home(mecha.global_position)
		mechas.append(mecha)

func _choose_random_starting_mecha() -> void:
	if mechas.is_empty():
		return
	var index := _rng.randi_range(0, mechas.size() - 1)
	_set_active_mecha(mechas[index], true)

func switch_to_next_closest() -> void:
	if active_mecha == null or mechas.size() <= 1:
		return

	var candidate: MechaController
	var candidate_distance := INF
	for mecha in mechas:
		if mecha == active_mecha:
			continue
		if _visited_ids.has(mecha.get_instance_id()):
			continue
		var distance := active_mecha.global_position.distance_squared_to(mecha.global_position)
		if distance < candidate_distance:
			candidate_distance = distance
			candidate = mecha

	if candidate == null:
		_visited_ids.clear()
		_visited_ids[active_mecha.get_instance_id()] = true
		for mecha in mechas:
			if mecha == active_mecha:
				continue
			var distance := active_mecha.global_position.distance_squared_to(mecha.global_position)
			if distance < candidate_distance:
				candidate_distance = distance
				candidate = mecha

	if candidate != null:
		_set_active_mecha(candidate, false)

func relocate_after_deck_regeneration() -> void:
	var positions := deck.get_mecha_spawn_positions(mechas.size())
	for index in range(mechas.size()):
		if index < positions.size():
			mechas[index].teleport_to(positions[index])
		else:
			mechas[index].teleport_to(deck.spawn_position + Vector2(index * 12.0, 0.0))
	_visited_ids.clear()
	if active_mecha != null:
		_visited_ids[active_mecha.get_instance_id()] = true
		active_mecha.set_player_controlled(true)
		active_mecha_changed.emit(active_mecha)

func get_active_animation_name() -> String:
	if active_mecha == null:
		return ""
	return active_mecha.get_animation_name()

func get_active_speed() -> float:
	if active_mecha == null:
		return 0.0
	return active_mecha.get_speed()

func get_active_mecha_name() -> String:
	if active_mecha == null:
		return "NONE"
	return active_mecha.get_display_name()

func _set_active_mecha(mecha: MechaController, reset_visit_chain: bool) -> void:
	if mecha == null:
		return
	if active_mecha != null:
		active_mecha.set_player_controlled(false)
	active_mecha = mecha
	active_mecha.set_player_controlled(true)
	if reset_visit_chain:
		_visited_ids.clear()
	_visited_ids[active_mecha.get_instance_id()] = true
	active_mecha_changed.emit(active_mecha)
