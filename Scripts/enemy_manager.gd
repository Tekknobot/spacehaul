extends Node2D
class_name SpacehaulEnemyManager

const ENEMY_SCENE = preload("res://Scenes/enemy.tscn")
const BROODMOTHER_SCENE = preload("res://Scenes/broodmother.tscn")
const SFX = preload("res://Scripts/sound_fx.gd")

const BROODMOTHER_TRIGGER_TIME := 8.0 * 60.0 + 10.0

@export var deck_path := NodePath("../ProceduralDeck")
@export var minimum_spawn_distance_cells := 8
@export var opening_grace_seconds := 7.0

@onready var deck: ProceduralDeck = get_node(deck_path) as ProceduralDeck

var enemies: Array[SpacehaulEnemy] = []
var total_kills := 0
var _rng := RandomNumberGenerator.new()
var _spawn_timer := 0.0
var _deck_grace := 0.0
var _spawning_enabled := true
var _next_elite_time := 180.0
var _broodmother_spawned := false
var _broodmother: SpacehaulBroodmother

func _ready() -> void:
	_rng.seed = deck.seed_value ^ 0xE11E5
	deck.regenerated.connect(_on_deck_regenerated)
	_deck_grace = opening_grace_seconds
	_spawn_timer = 0.8

func _process(delta: float) -> void:
	_cleanup_dead_references()
	if not _spawning_enabled:
		return

	var run_time := _get_run_time()
	if not _broodmother_spawned and run_time >= BROODMOTHER_TRIGGER_TIME and _get_deck_number() >= 3:
		_spawn_broodmother()
		return

	# During the boss encounter, the Broodmother's eggs are the source of adds.
	# Suspending the ordinary director keeps the fight readable and lets the egg
	# priority mechanic actually matter.
	if is_boss_active():
		return

	if _deck_grace > 0.0:
		_deck_grace = maxf(0.0, _deck_grace - delta)
		return

	if run_time < opening_grace_seconds:
		return

	_spawn_timer -= delta
	if _spawn_timer > 0.0:
		return

	var target_count := _target_active_count(run_time)
	var alive_count := get_alive_count()
	if alive_count < target_count:
		var batch := _spawn_batch_size(run_time)
		var to_spawn := mini(batch, target_count - alive_count)
		for i in range(to_spawn):
			var make_elite := run_time >= _next_elite_time and i == 0
			_spawn_one(run_time, make_elite)
			if make_elite:
				_next_elite_time += 75.0

	_spawn_timer = _spawn_interval(run_time)

func reset_run() -> void:
	total_kills = 0
	_next_elite_time = 180.0
	_spawning_enabled = true
	_broodmother_spawned = false
	_clear_boss_encounter()
	_clear_population()
	_deck_grace = opening_grace_seconds
	_spawn_timer = 0.8

func set_spawning_enabled(value: bool) -> void:
	_spawning_enabled = value

func prepare_video_capture_state(run_time: float) -> void:
	_spawning_enabled = true
	_clear_boss_encounter()
	_clear_population()
	_deck_grace = 0.0
	_spawn_timer = 0.0
	_broodmother_spawned = run_time >= BROODMOTHER_TRIGGER_TIME

	if run_time < 180.0:
		_next_elite_time = 180.0
	else:
		var elapsed_elite_windows := int(floor((run_time - 180.0) / 75.0)) + 1
		_next_elite_time = 180.0 + float(elapsed_elite_windows) * 75.0

func _on_deck_regenerated(_spawn: Vector2, seed_value: int) -> void:
	_rng.seed = seed_value ^ 0xE11E5 ^ int(_get_run_time() * 10.0)
	_clear_population()
	_deck_grace = 5.0
	_spawn_timer = 0.6

func _clear_population() -> void:
	for enemy in enemies:
		if enemy != null and is_instance_valid(enemy):
			enemy.queue_free()
	enemies.clear()
	for child in get_children():
		if child.is_in_group("salvage_pickups"):
			child.queue_free()

func _clear_boss_encounter() -> void:
	if _broodmother != null and is_instance_valid(_broodmother):
		_broodmother.queue_free()
	_broodmother = null
	for child in get_children():
		if child.is_in_group("boss_eggs"):
			child.queue_free()

func _cleanup_dead_references() -> void:
	if Engine.get_process_frames() % 45 != 0:
		return
	var alive: Array[SpacehaulEnemy] = []
	for enemy in enemies:
		if enemy != null and is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			alive.append(enemy)
	enemies = alive

func _spawn_one(run_time: float, make_elite: bool) -> void:
	if deck == null:
		return
	var player := get_tree().get_first_node_in_group("player_mecha") as MechaController
	if player == null:
		return
	var spawn_position := deck.get_random_enemy_spawn_position(player.global_position, minimum_spawn_distance_cells, _rng)
	if spawn_position == Vector2.ZERO:
		return
	_spawn_enemy_at(spawn_position, _choose_enemy_type(run_time), run_time, make_elite)

func _spawn_enemy_at(spawn_position: Vector2, enemy_type: String, run_time: float, make_elite: bool = false) -> SpacehaulEnemy:
	var enemy := ENEMY_SCENE.instantiate() as SpacehaulEnemy
	if enemy == null:
		return null
	enemy.enemy_type = enemy_type
	enemy.deck = deck
	enemy.position = spawn_position.round()
	add_child(enemy)
	enemy.apply_difficulty(run_time, _get_deck_number(), make_elite)
	enemy.defeated.connect(_on_enemy_defeated)
	enemies.append(enemy)
	return enemy

func _spawn_broodmother() -> void:
	if deck == null:
		return
	var player := get_tree().get_first_node_in_group("player_mecha") as MechaController
	if player == null:
		return

	# Trim the normal swarm rather than deleting the arena completely. A small
	# escort survives the boss arrival, but the encounter immediately becomes
	# readable and subsequent adds come from eggs instead of the global spawner.
	_trim_population_for_boss(10)

	var spawn_position := deck.get_random_enemy_spawn_position(player.global_position, minimum_spawn_distance_cells + 2, _rng)
	if spawn_position == Vector2.ZERO:
		spawn_position = deck.get_random_walkable_position_near(player.global_position, minimum_spawn_distance_cells + 2, _rng)

	var boss := BROODMOTHER_SCENE.instantiate() as SpacehaulBroodmother
	if boss == null:
		return
	boss.deck = deck
	boss.position = spawn_position.round()
	add_child(boss)
	boss.defeated.connect(_on_broodmother_defeated)
	_broodmother = boss
	_broodmother_spawned = true

	SFX.play_ui(self, "warning", -5.5, 0.72)
	var managers := get_tree().get_nodes_in_group("survival_manager")
	if not managers.is_empty() and managers[0].has_method("_show_banner"):
		managers[0].call("_show_banner", "BIO-SIGNATURE   BROODMOTHER", 1.65)

func _trim_population_for_boss(keep_count: int) -> void:
	_cleanup_dead_references()
	var kept := 0
	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		if kept < keep_count:
			kept += 1
			continue
		enemy.queue_free()
	_cleanup_dead_references()

func spawn_brood_hatchling(world_position: Vector2, boss_phase: int) -> void:
	if not is_boss_active():
		return
	var pool: Array[String] = ["spider_1", "bug_1", "bug_2"]
	if boss_phase >= 2:
		pool.append_array(["spider_2", "beetle_2"])
	if boss_phase >= 3:
		pool.append_array(["bug_3", "spider_3"])
	var enemy_type := pool[_rng.randi_range(0, pool.size() - 1)]
	_spawn_enemy_at(world_position, enemy_type, _get_run_time(), false)

func _on_broodmother_defeated() -> void:
	total_kills += 1
	_broodmother = null
	_spawn_timer = 1.25
	_deck_grace = 2.0
	var managers := get_tree().get_nodes_in_group("survival_manager")
	if not managers.is_empty() and managers[0].has_method("_show_banner"):
		managers[0].call("_show_banner", "BROODMOTHER ELIMINATED", 1.25)

func is_boss_active() -> bool:
	return _broodmother != null and is_instance_valid(_broodmother) and not _broodmother.is_queued_for_deletion()

func _choose_enemy_type(run_time: float) -> String:
	var pool: Array[String] = []
	if run_time < 40.0:
		pool = ["bug_1", "bug_1", "alien_1"]
	elif run_time < 90.0:
		pool = ["bug_1", "alien_1", "bug_2", "spider_1"]
	elif run_time < 150.0:
		pool = ["bug_1", "bug_2", "spider_1", "beetle_2", "spider_2"]
	elif run_time < 240.0:
		pool = ["alien_1", "bug_2", "spider_1", "beetle_2", "spider_2", "beetle_1", "bug_3"]
	elif run_time < 480.0:
		pool = ["bug_2", "spider_1", "beetle_2", "spider_2", "beetle_1", "bug_3", "bug_4"]
	else:
		pool = ["alien_1", "beetle_1", "beetle_2", "bug_1", "bug_2", "bug_3", "bug_4", "spider_1", "spider_2", "spider_3"]
	return pool[_rng.randi_range(0, pool.size() - 1)]

func _target_active_count(run_time: float) -> int:
	if run_time < 30.0:
		return 5
	if run_time < 60.0:
		return 8
	if run_time < 90.0:
		return 12
	if run_time < 120.0:
		return 16
	if run_time < 180.0:
		return 21
	if run_time < 240.0:
		return 27
	var scaled := 27 + int((run_time - 240.0) / 18.0) + (_get_deck_number() - 1) * 3
	return clampi(scaled, 27, 78)

func _spawn_batch_size(run_time: float) -> int:
	if run_time < 120.0:
		return 1
	if run_time < 360.0:
		return 2
	if run_time < 720.0:
		return 3
	return 4

func _spawn_interval(run_time: float) -> float:
	var interval := 1.55 - run_time * 0.00135 - float(_get_deck_number() - 1) * 0.06
	return clampf(interval, 0.24, 1.55)

func _on_enemy_defeated(_salvage_value: int) -> void:
	total_kills += 1

func _get_run_time() -> float:
	var managers := get_tree().get_nodes_in_group("survival_manager")
	if managers.is_empty():
		return 0.0
	if managers[0].has_method("get_run_time"):
		return float(managers[0].call("get_run_time"))
	return 0.0

func _get_deck_number() -> int:
	var managers := get_tree().get_nodes_in_group("survival_manager")
	if managers.is_empty():
		return 1
	if managers[0].has_method("get_deck_number"):
		return int(managers[0].call("get_deck_number"))
	return 1

func get_alive_count() -> int:
	var count := 0
	for enemy in enemies:
		if enemy != null and is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			count += 1
	return count

func get_total_kills() -> int:
	return total_kills
