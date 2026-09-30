extends Node2D
class_name SpacehaulEnemyManager

signal broodmother_defeated

const ENEMY_SCENE = preload("res://Scenes/enemy.tscn")
const BROODMOTHER_SCENE = preload("res://Scenes/broodmother.tscn")
const SFX = preload("res://Scripts/sound_fx.gd")
const OMEGA_CORE_SCRIPT = preload("res://Scripts/omega_core_pickup.gd")

const BROODMOTHER_TRIGGER_TIME := 8.0 * 60.0 + 10.0
const RUN_DURATION := 20.0 * 60.0

@export_category("Spawn Director")
@export var deck_path := NodePath("../ProceduralDeck")
@export var minimum_spawn_distance_cells := 8
@export var opening_grace_seconds := 7.0
@export var swarm_events_enabled := true
@export var announce_major_swarms := true
@export var expedition_boss_controlled := true
@export_range(64, 128, 1) var hard_active_enemy_cap := 96

@export_category("Omega Core")
@export var omega_core_drops_enabled := true
@export_range(90.0, 600.0, 15.0) var first_omega_core_time := 180.0
@export_range(120.0, 600.0, 15.0) var omega_core_interval := 180.0
@export_range(0.5, 5.0, 0.25) var omega_carrier_spawn_delay := 1.5
@export_range(1.10, 1.75, 0.05) var omega_carrier_health_multiplier := 1.35

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
var _next_omega_core_time := 180.0
var _omega_carrier: SpacehaulEnemy
var _omega_carrier_pending := false
var _omega_carrier_timer := 0.0
var _omega_core_in_world := false
# Expedition mode awards at most one OMEGA opportunity on Decks 1-3.
# Claimed deck ids persist across procedural deck regeneration for the run.
var _expedition_omega_claimed_decks: Dictionary = {}

# Encounter-director state. Ordinary population refill happens in same-species
# packs; the event layer periodically creates a more legible swarm from one,
# two, or three approach sectors instead of continuously drip-feeding random
# single enemies around the deck.
var _next_swarm_time := 52.0
var _swarm_active := false
var _swarm_enemy_type := "bug_1"
var _swarm_remaining := 0
var _swarm_spawn_timer := 0.0
var _swarm_burst_size := 2
var _swarm_pattern := "front"
var _swarm_anchors: Array[Vector2] = []
var _swarm_anchor_index := 0

func _ready() -> void:
	_rng.seed = deck.seed_value ^ 0xE11E5
	deck.regenerated.connect(_on_deck_regenerated)
	_deck_grace = opening_grace_seconds
	_spawn_timer = 0.8
	_next_swarm_time = 52.0
	_next_omega_core_time = first_omega_core_time

func _process(delta: float) -> void:
	_cleanup_dead_references()
	if not _spawning_enabled:
		return

	var run_time := _get_run_time()
	if not expedition_boss_controlled and not _broodmother_spawned and run_time >= BROODMOTHER_TRIGGER_TIME and _get_deck_number() >= 3:
		_cancel_swarm_event()
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

	_update_omega_carrier_director(delta, run_time)
	_update_swarm_director(delta, run_time)
	_update_population_director(delta, run_time)

func reset_run() -> void:
	total_kills = 0
	_next_elite_time = 180.0
	_next_omega_core_time = first_omega_core_time
	_omega_carrier = null
	_omega_carrier_pending = false
	_omega_carrier_timer = 0.0
	_omega_core_in_world = false
	_expedition_omega_claimed_decks.clear()
	_spawning_enabled = true
	_broodmother_spawned = false
	_clear_boss_encounter()
	_clear_population()
	_cancel_swarm_event()
	_deck_grace = opening_grace_seconds
	_spawn_timer = 0.8
	_next_swarm_time = 52.0

func set_spawning_enabled(value: bool) -> void:
	_spawning_enabled = value
	if not value:
		_cancel_swarm_event()

func prepare_video_capture_state(run_time: float) -> void:
	_spawning_enabled = true
	_clear_boss_encounter()
	_clear_population()
	_omega_carrier = null
	_omega_carrier_pending = false
	_omega_carrier_timer = 0.0
	_omega_core_in_world = false
	_cancel_swarm_event()
	_deck_grace = 0.0
	_spawn_timer = 0.0
	_broodmother_spawned = false if expedition_boss_controlled else run_time >= BROODMOTHER_TRIGGER_TIME
	_next_swarm_time = run_time + 8.0
	_next_omega_core_time = run_time + omega_core_interval

	if run_time < 180.0:
		_next_elite_time = 180.0
	else:
		var elapsed_elite_windows := int(floor((run_time - 180.0) / 75.0)) + 1
		_next_elite_time = 180.0 + float(elapsed_elite_windows) * 75.0

func _on_deck_regenerated(_spawn: Vector2, seed_value: int) -> void:
	var run_time := _get_run_time()
	_rng.seed = seed_value ^ 0xE11E5 ^ int(run_time * 10.0)
	_clear_population()
	if expedition_boss_controlled:
		_clear_boss_encounter()
		_broodmother_spawned = false
	_cancel_swarm_event()
	_deck_grace = 5.0
	_spawn_timer = 0.6
	# Deck transfers already reset spatial pressure. Give the player a short
	# orientation window before the next authored swarm can begin.
	_next_swarm_time = maxf(_next_swarm_time, run_time + 14.0)

func _clear_population() -> void:
	for enemy in enemies:
		if enemy != null and is_instance_valid(enemy):
			enemy.queue_free()
	enemies.clear()
	_omega_carrier = null
	_omega_carrier_pending = false
	_omega_carrier_timer = 0.0
	_omega_core_in_world = false
	for child in get_children():
		if child.is_in_group("salvage_pickups") or child.is_in_group("omega_core_pickups"):
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
	if _omega_carrier != null and (not is_instance_valid(_omega_carrier) or _omega_carrier.is_queued_for_deletion()):
		_omega_carrier = null

# -----------------------------------------------------------------------------
# Omega carrier director
# -----------------------------------------------------------------------------

func _update_omega_carrier_director(delta: float, run_time: float) -> void:
	if not omega_core_drops_enabled or not _omega_window_is_open(run_time):
		return
	if _omega_core_in_world or _has_omega_core_pickup():
		_omega_core_in_world = true
		return
	if _omega_carrier != null and is_instance_valid(_omega_carrier) and not _omega_carrier.is_queued_for_deletion():
		return
	if not _omega_seek_is_active():
		_omega_carrier_pending = false
		_omega_carrier_timer = 0.0
		return

	if not _omega_carrier_pending:
		_omega_carrier_pending = true
		_omega_carrier_timer = omega_carrier_spawn_delay
		_show_omega_banner("OMEGA SIGNATURE ACQUIRED", 0.76)
		return

	_omega_carrier_timer = maxf(0.0, _omega_carrier_timer - delta)
	if _omega_carrier_timer <= 0.0:
		_spawn_omega_carrier(run_time)

func _spawn_omega_carrier(run_time: float) -> void:
	_omega_carrier_pending = false
	_omega_carrier_timer = 0.0
	if deck == null or is_boss_active() or not _omega_seek_is_active():
		return
	var player := get_tree().get_first_node_in_group("player_mecha") as MechaController
	if player == null:
		return
	var spawn_position := deck.get_random_enemy_spawn_position(player.global_position, minimum_spawn_distance_cells + 2, _rng)
	if spawn_position == Vector2.ZERO:
		spawn_position = deck.get_random_walkable_position_near(player.global_position, minimum_spawn_distance_cells + 2, _rng)
	if spawn_position == Vector2.ZERO:
		_omega_carrier_pending = true
		_omega_carrier_timer = 1.0
		return

	var carrier_type := _choose_omega_carrier_type(run_time)
	var carrier := _spawn_enemy_at(spawn_position, carrier_type, run_time, true)
	if carrier == null:
		_omega_carrier_pending = true
		_omega_carrier_timer = 1.0
		return
	carrier.make_omega_carrier(omega_carrier_health_multiplier)
	_omega_carrier = carrier
	_next_elite_time = maxf(_next_elite_time, run_time + 45.0)
	_show_omega_banner("OMEGA CARRIER LOCATED", 1.05)
	SFX.play_ui(self, "warning", -8.0, 1.18)

func _choose_omega_carrier_type(run_time: float) -> String:
	var candidates: Array = []
	if run_time < 480.0:
		candidates = ["beetle_1", "bug_3", "spider_2"]
	elif run_time < 900.0:
		candidates = ["beetle_1", "bug_4", "spider_2", "spider_3"]
	else:
		candidates = ["beetle_1", "bug_4", "spider_3", "bug_3"]
	return candidates[_rng.randi_range(0, candidates.size() - 1)]

func _omega_seek_is_active() -> bool:
	var managers := get_tree().get_nodes_in_group("survival_manager")
	if managers.is_empty():
		return false
	if managers[0].has_method("is_omega_seek_active"):
		return bool(managers[0].call("is_omega_seek_active"))
	return false

func _has_omega_core_pickup() -> bool:
	for child in get_children():
		if child.is_in_group("omega_core_pickups") and not child.is_queued_for_deletion():
			return true
	return false

func _show_omega_banner(message: String, hold_time: float) -> void:
	var managers := get_tree().get_nodes_in_group("survival_manager")
	if not managers.is_empty() and managers[0].has_method("_show_banner"):
		managers[0].call("_show_banner", message, hold_time)

# -----------------------------------------------------------------------------
# Population director
# -----------------------------------------------------------------------------

func _update_population_director(delta: float, run_time: float) -> void:
	_spawn_timer -= delta
	if _spawn_timer > 0.0:
		return

	var target_count := _target_active_count(run_time)
	var alive_count := get_alive_count()
	if alive_count < target_count:
		var deficit := target_count - alive_count
		var enemy_type := _choose_pack_enemy_type(run_time)
		var desired_pack := mini(_pack_size_for_type(enemy_type, run_time), deficit)
		if desired_pack > 0:
			_spawn_pack(enemy_type, desired_pack, run_time)

	_spawn_timer = _spawn_interval(run_time)

func _spawn_pack(enemy_type: String, count: int, run_time: float, anchor: Vector2 = Vector2.ZERO) -> int:
	if count <= 0 or deck == null:
		return 0
	var player := get_tree().get_first_node_in_group("player_mecha") as MechaController
	if player == null:
		return 0

	if anchor == Vector2.ZERO:
		anchor = deck.get_random_enemy_spawn_position(player.global_position, minimum_spawn_distance_cells, _rng)
	if anchor == Vector2.ZERO:
		return 0

	var spawned := 0
	var used_positions: Array[Vector2] = []
	for i in range(count):
		if get_alive_count() >= hard_active_enemy_cap:
			break
		var spawn_position := anchor
		if i > 0:
			spawn_position = _cluster_position_near(anchor, player.global_position, used_positions)
		if spawn_position == Vector2.ZERO:
			continue

		var make_elite := run_time >= _next_elite_time
		var enemy := _spawn_enemy_at(spawn_position, enemy_type, run_time, make_elite)
		if enemy != null:
			spawned += 1
			used_positions.append(spawn_position)
			if make_elite:
				_next_elite_time += 75.0
	return spawned

func _cluster_position_near(anchor: Vector2, player_position: Vector2, used_positions: Array[Vector2]) -> Vector2:
	# Radius 2 keeps a pack visually recognizable while still letting Godot's
	# character bodies/pathfinding fan it out naturally after spawning.
	for attempt in range(10):
		var candidate := deck.get_random_walkable_position_near(anchor, 2, _rng)
		if candidate == Vector2.ZERO:
			continue
		if not _is_far_enough_from_player(candidate, player_position, minimum_spawn_distance_cells - 1):
			continue
		var too_close := false
		for used in used_positions:
			if used.distance_squared_to(candidate) < 36.0:
				too_close = true
				break
		if too_close:
			continue
		return candidate.round()
	return anchor.round()

func _is_far_enough_from_player(candidate: Vector2, player_position: Vector2, minimum_cells: int) -> bool:
	if deck == null:
		return true
	var a := deck.world_to_cell(candidate)
	var b := deck.world_to_cell(player_position)
	return Vector2(a).distance_to(Vector2(b)) >= float(maxi(1, minimum_cells))

# -----------------------------------------------------------------------------
# Swarm event director
# -----------------------------------------------------------------------------

func _update_swarm_director(delta: float, run_time: float) -> void:
	if not swarm_events_enabled:
		return

	if not _swarm_active:
		if run_time >= _next_swarm_time and run_time < RUN_DURATION - 10.0:
			_begin_swarm_event(run_time)
		return

	_swarm_spawn_timer -= delta
	if _swarm_spawn_timer > 0.0:
		return

	if _swarm_remaining <= 0:
		_finish_swarm_event(run_time)
		return

	var event_cap := mini(hard_active_enemy_cap, _target_active_count(run_time) + _swarm_headroom(run_time))
	if get_alive_count() >= event_cap:
		# The event budget is intentionally allowed to exceed the ambient target,
		# but it waits rather than creating an unreadable pile-up.
		_swarm_spawn_timer = 0.35
		return

	var burst := mini(_swarm_burst_size, _swarm_remaining)
	burst = mini(burst, event_cap - get_alive_count())
	if burst <= 0:
		_swarm_spawn_timer = 0.25
		return

	var anchor := _next_swarm_anchor()
	var spawned := _spawn_pack(_swarm_enemy_type, burst, run_time, anchor)
	_swarm_remaining -= spawned
	_swarm_spawn_timer = _swarm_burst_interval(run_time)

	if spawned <= 0:
		# A generated deck can occasionally make one approach sector invalid.
		# Refresh the anchors rather than stalling the whole event.
		_swarm_anchors = _build_swarm_anchors(_swarm_pattern)
		_swarm_spawn_timer = 0.45

func _begin_swarm_event(run_time: float) -> void:
	_swarm_enemy_type = _choose_swarm_enemy_type(run_time)
	_swarm_pattern = _choose_swarm_pattern(run_time)
	_swarm_remaining = _swarm_size(run_time, _swarm_enemy_type)
	_swarm_burst_size = _swarm_burst_count(run_time, _swarm_enemy_type)
	_swarm_spawn_timer = 0.05
	_swarm_anchors = _build_swarm_anchors(_swarm_pattern)
	_swarm_anchor_index = 0

	if _swarm_anchors.is_empty():
		_schedule_next_swarm(run_time)
		return

	_swarm_active = true
	if announce_major_swarms and run_time >= 120.0:
		SFX.play_ui(self, "warning", -12.0, 0.92)
		_show_swarm_banner(_swarm_pattern)

func _finish_swarm_event(run_time: float) -> void:
	_swarm_active = false
	_swarm_remaining = 0
	_swarm_anchors.clear()
	_swarm_anchor_index = 0
	_schedule_next_swarm(run_time)

func _cancel_swarm_event() -> void:
	_swarm_active = false
	_swarm_remaining = 0
	_swarm_spawn_timer = 0.0
	_swarm_anchors.clear()
	_swarm_anchor_index = 0

func _schedule_next_swarm(run_time: float) -> void:
	var interval := 56.0
	if run_time < 120.0:
		interval = _rng.randf_range(52.0, 64.0)
	elif run_time < 300.0:
		interval = _rng.randf_range(44.0, 56.0)
	elif run_time < 600.0:
		interval = _rng.randf_range(37.0, 49.0)
	elif run_time < 900.0:
		interval = _rng.randf_range(31.0, 42.0)
	else:
		interval = _rng.randf_range(25.0, 35.0)
	_next_swarm_time = run_time + interval

func _build_swarm_anchors(pattern: String) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if deck == null:
		return result
	var player := get_tree().get_first_node_in_group("player_mecha") as MechaController
	if player == null:
		return result

	var desired := 1
	match pattern:
		"pincer": desired = 2
		"surround": desired = 3
		_: desired = 1

	for i in range(desired):
		var best := Vector2.ZERO
		for attempt in range(18):
			var candidate := deck.get_random_enemy_spawn_position(player.global_position, minimum_spawn_distance_cells + 1, _rng)
			if candidate == Vector2.ZERO:
				continue
			var separated := true
			for existing in result:
				if candidate.distance_squared_to(existing) < 140.0 * 140.0:
					separated = false
					break
			if separated:
				best = candidate
				break
		if best != Vector2.ZERO:
			result.append(best.round())

	# Never discard a valid event because a compact procedural deck could not
	# satisfy the ideal sector separation.
	if result.is_empty():
		var fallback := deck.get_random_enemy_spawn_position(player.global_position, minimum_spawn_distance_cells, _rng)
		if fallback != Vector2.ZERO:
			result.append(fallback.round())
	return result

func _next_swarm_anchor() -> Vector2:
	if _swarm_anchors.is_empty():
		return Vector2.ZERO
	var anchor := _swarm_anchors[_swarm_anchor_index % _swarm_anchors.size()]
	_swarm_anchor_index = (_swarm_anchor_index + 1) % _swarm_anchors.size()
	return anchor

func _choose_swarm_pattern(run_time: float) -> String:
	if run_time < 180.0:
		return "front"
	if run_time < 480.0:
		return "pincer" if _rng.randf() < 0.46 else "front"
	if run_time < 780.0:
		var roll := _rng.randf()
		if roll < 0.24:
			return "surround"
		if roll < 0.67:
			return "pincer"
		return "front"
	var late_roll := _rng.randf()
	if late_roll < 0.42:
		return "surround"
	if late_roll < 0.80:
		return "pincer"
	return "front"

func _choose_swarm_enemy_type(run_time: float) -> String:
	# Swarms favor mobile organisms. Ranged/shock/heavy archetypes still arrive
	# in ordinary squads, where their attacks remain readable instead of turning
	# a swarm event into projectile spam.
	var pool: Array[String] = []
	if run_time < 70.0:
		pool = ["bug_1", "bug_1", "alien_1"]
	elif run_time < 180.0:
		pool = ["bug_1", "bug_2", "spider_1", "alien_1"]
	elif run_time < 420.0:
		pool = ["bug_1", "bug_2", "bug_2", "spider_1", "spider_1", "alien_1"]
	elif run_time < 780.0:
		pool = ["bug_2", "bug_2", "spider_1", "spider_1", "alien_1", "bug_1"]
	else:
		pool = ["bug_2", "bug_2", "spider_1", "spider_1", "alien_1", "bug_1", "bug_4"]
	return pool[_rng.randi_range(0, pool.size() - 1)]

func _swarm_size(run_time: float, enemy_type: String) -> int:
	var amount := 7
	if run_time < 120.0:
		amount = _rng.randi_range(6, 8)
	elif run_time < 240.0:
		amount = _rng.randi_range(8, 11)
	elif run_time < 480.0:
		amount = _rng.randi_range(11, 15)
	elif run_time < 720.0:
		amount = _rng.randi_range(14, 18)
	elif run_time < 960.0:
		amount = _rng.randi_range(17, 22)
	else:
		amount = _rng.randi_range(20, 27)

	# Deeper decks add a modest event budget independent of elapsed time.
	amount += maxi(0, _get_deck_number() - 1) * 2
	if enemy_type == "bug_4":
		amount = maxi(8, int(round(float(amount) * 0.60)))
	return amount

func _swarm_burst_count(run_time: float, enemy_type: String) -> int:
	var amount := 2
	if run_time >= 240.0:
		amount = 3
	if run_time >= 720.0:
		amount = 4
	if enemy_type == "bug_4":
		amount = mini(amount, 2)
	return amount

func _swarm_burst_interval(run_time: float) -> float:
	return clampf(0.42 - run_time * 0.00018, 0.18, 0.42)

func _swarm_headroom(run_time: float) -> int:
	if run_time < 180.0:
		return 5
	if run_time < 480.0:
		return 8
	if run_time < 900.0:
		return 12
	return 16

func _show_swarm_banner(pattern: String) -> void:
	var managers := get_tree().get_nodes_in_group("survival_manager")
	if managers.is_empty() or not managers[0].has_method("_show_banner"):
		return
	var label := "BIO-SWARM DETECTED"
	if pattern == "pincer":
		label = "BIO-SWARM   MULTIPLE CONTACTS"
	elif pattern == "surround":
		label = "BIO-SWARM   ENCIRCLEMENT"
	managers[0].call("_show_banner", label, 0.72)

# -----------------------------------------------------------------------------
# Enemy creation / boss integration
# -----------------------------------------------------------------------------

func _spawn_enemy_at(spawn_position: Vector2, enemy_type: String, run_time: float, make_elite: bool = false) -> SpacehaulEnemy:
	var enemy := ENEMY_SCENE.instantiate() as SpacehaulEnemy
	if enemy == null:
		return null
	enemy.enemy_type = enemy_type
	enemy.deck = deck
	enemy.position = spawn_position.round()
	add_child(enemy)
	enemy.apply_difficulty(run_time, _get_deck_number(), make_elite)
	enemy.defeated.connect(_on_enemy_defeated.bind(enemy))
	enemies.append(enemy)
	return enemy

func spawn_broodmother_at(world_position: Vector2, expedition_variant: int = 1) -> void:
	if _broodmother_spawned or is_boss_active():
		return
	_cancel_swarm_event()
	_spawn_broodmother(world_position, expedition_variant)

func _spawn_broodmother(forced_position: Vector2 = Vector2.ZERO, expedition_variant: int = 1) -> void:
	if deck == null:
		return
	var player := get_tree().get_first_node_in_group("player_mecha") as MechaController
	if player == null:
		return

	# Trim the normal swarm rather than deleting the arena completely. A small
	# escort survives the boss arrival, but the encounter immediately becomes
	# readable and subsequent adds come from eggs instead of the global spawner.
	_trim_population_for_boss(10)

	var spawn_position := forced_position
	if spawn_position == Vector2.ZERO:
		spawn_position = deck.get_random_enemy_spawn_position(player.global_position, minimum_spawn_distance_cells + 2, _rng)
	if spawn_position == Vector2.ZERO:
		spawn_position = deck.get_random_walkable_position_near(player.global_position, minimum_spawn_distance_cells + 2, _rng)

	var boss := BROODMOTHER_SCENE.instantiate() as SpacehaulBroodmother
	if boss == null:
		return
	boss.deck = deck
	boss.position = spawn_position.round()
	boss.configure_expedition_variant(expedition_variant)
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
		if enemy == _omega_carrier:
			kept += 1
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
	var boss_position := Vector2.ZERO
	if _broodmother != null and is_instance_valid(_broodmother):
		boss_position = _broodmother.global_position
	_broodmother = null
	# A boss can satisfy the currently active OMEGA opportunity. In Expedition
	# Mode that opportunity is deck-driven (Decks 1-3 after the first secured
	# system); in Survival Mode it retains the original clock-driven window.
	if (
		boss_position != Vector2.ZERO
		and _omega_window_is_open(_get_run_time())
		and not _omega_core_in_world
		and _omega_carrier == null
		and _omega_seek_is_active()
	):
		_spawn_omega_core(boss_position)
	_spawn_timer = 1.25
	_deck_grace = 2.0
	_next_swarm_time = maxf(_next_swarm_time, _get_run_time() + 12.0)
	var managers := get_tree().get_nodes_in_group("survival_manager")
	if not managers.is_empty() and managers[0].has_method("_show_banner"):
		managers[0].call("_show_banner", "BROODMOTHER ELIMINATED", 1.25)
	broodmother_defeated.emit()

func is_boss_active() -> bool:
	return _broodmother != null and is_instance_valid(_broodmother) and not _broodmother.is_queued_for_deletion()

# -----------------------------------------------------------------------------
# Run pacing / composition
# -----------------------------------------------------------------------------

func _choose_pack_enemy_type(run_time: float) -> String:
	var pool := _enemy_pool(run_time)
	return pool[_rng.randi_range(0, pool.size() - 1)]

func _enemy_pool(run_time: float) -> Array[String]:
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
	return pool

func _pack_size_for_type(enemy_type: String, run_time: float) -> int:
	var amount := 2
	if run_time >= 60.0:
		amount = 3
	if run_time >= 240.0:
		amount = 4
	if run_time >= 600.0:
		amount = 5
	if run_time >= 960.0:
		amount = 6

	# Specialists and heavies work better as squads embedded between larger
	# organism packs. This also prevents simultaneous ranged telegraphs from
	# becoming visual noise.
	match enemy_type:
		"beetle_1", "bug_4", "spider_3":
			amount = mini(amount, 2 if run_time < 720.0 else 3)
		"beetle_2", "bug_3", "spider_2":
			amount = mini(amount, 3 if run_time < 720.0 else 4)
		_:
			pass
	return maxi(1, amount)

func _target_active_count(run_time: float) -> int:
	# Expedition depth now matters from the moment a new deck begins. Time still
	# increases pressure, while each deeper deck adds a persistent population step.
	var baseline := 5
	if run_time < 30.0:
		baseline = 5
	elif run_time < 60.0:
		baseline = 8
	elif run_time < 90.0:
		baseline = 11
	elif run_time < 120.0:
		baseline = 14
	elif run_time < 180.0:
		baseline = 19
	elif run_time < 240.0:
		baseline = 24
	else:
		baseline = 24 + int((run_time - 240.0) / 20.0)
	baseline += maxi(0, _get_deck_number() - 1) * 3
	return clampi(baseline, 5, 72)

func _spawn_interval(run_time: float) -> float:
	# Packs replace the old single-enemy drip feed, so ordinary refill can be a
	# little slower while still rebuilding pressure quickly after a kill streak.
	var interval := 2.15 - run_time * 0.00115 - float(_get_deck_number() - 1) * 0.055
	if _swarm_active:
		interval += 0.55
	return clampf(interval, 0.62, 2.15)

func _on_enemy_defeated(_salvage_value: int, _was_elite: bool, death_position: Vector2, enemy: SpacehaulEnemy) -> void:
	total_kills += 1
	if enemy == null or not enemy.is_omega_carrier():
		return
	if enemy == _omega_carrier:
		_omega_carrier = null
	if not omega_core_drops_enabled or not _omega_drop_is_useful():
		return
	_spawn_omega_core(death_position)

func _omega_drop_is_useful() -> bool:
	var managers := get_tree().get_nodes_in_group("survival_manager")
	if managers.is_empty():
		return false
	if managers[0].has_method("can_receive_omega_core"):
		return bool(managers[0].call("can_receive_omega_core"))
	return false

func _spawn_omega_core(world_position: Vector2) -> void:
	if _omega_core_in_world or _has_omega_core_pickup():
		return
	var core := OMEGA_CORE_SCRIPT.new() as SpaceMechaOmegaCorePickup
	if core == null:
		return
	add_child(core)
	core.setup(world_position + Vector2(0.0, -7.0))
	_omega_core_in_world = true
	_show_omega_banner("OMEGA CORE RELEASED", 0.95)

func notify_omega_core_collected() -> void:
	_omega_core_in_world = false
	_omega_carrier_pending = false
	_omega_carrier_timer = 0.0

	if _is_expedition_omega_mode():
		# One Core opportunity per expedition deck, specifically Decks 1-3. Once
		# collected, this deck cannot immediately produce another carrier/Core.
		var deck_number := _get_deck_number()
		if deck_number >= 1 and deck_number <= 3:
			_expedition_omega_claimed_decks[deck_number] = true
		return

	# Classic survival mode keeps the original clock-driven three-Core pacing.
	_next_omega_core_time = _get_run_time() + omega_core_interval

func _is_expedition_omega_mode() -> bool:
	var managers := get_tree().get_nodes_in_group("survival_manager")
	if managers.is_empty():
		return false
	if managers[0].has_method("is_expedition_mode"):
		return bool(managers[0].call("is_expedition_mode"))
	return false

func _omega_window_is_open(run_time: float) -> bool:
	if _is_expedition_omega_mode():
		var deck_number := _get_deck_number()
		if deck_number < 1 or deck_number > 3:
			return false
		if _expedition_omega_claimed_decks.has(deck_number):
			return false

		# The first secured ship system is the trigger. This makes the OMEGA hunt
		# part of exploration rather than something that appears just for waiting.
		var managers := get_tree().get_nodes_in_group("survival_manager")
		if managers.is_empty():
			return false
		if managers[0].has_method("is_expedition_omega_ready"):
			return bool(managers[0].call("is_expedition_omega_ready"))
		return false

	return run_time >= _next_omega_core_time

func get_omega_guidance_target() -> Node2D:
	if _omega_carrier != null and is_instance_valid(_omega_carrier) and not _omega_carrier.is_queued_for_deletion():
		return _omega_carrier
	for child in get_children():
		if child is Node2D and child.is_in_group("omega_core_pickups") and not child.is_queued_for_deletion():
			return child as Node2D
	return null

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
