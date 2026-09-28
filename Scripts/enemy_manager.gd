extends Node2D
class_name SpacehaulEnemyManager

const ENEMY_SCENE = preload("res://Scenes/enemy.tscn")
const ENEMY_TYPES := [
	"alien_1",
	"beetle_1",
	"beetle_2",
	"bug_1",
	"bug_2",
	"bug_3",
	"bug_4",
	"spider_1",
	"spider_2",
	"spider_3",
]

@export var deck_path := NodePath("../ProceduralDeck")
@export var enemy_count := 60
@export var minimum_spawn_distance_cells := 7

@onready var deck: ProceduralDeck = get_node(deck_path) as ProceduralDeck

var enemies: Array[SpacehaulEnemy] = []
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = deck.seed_value ^ 0xE11E5
	deck.regenerated.connect(_on_deck_regenerated)
	_spawn_population()

func _process(_delta: float) -> void:
	# Compact dead references periodically without doing per-enemy bookkeeping.
	if Engine.get_process_frames() % 90 == 0:
		var alive: Array[SpacehaulEnemy] = []
		for enemy in enemies:
			if enemy != null and is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
				alive.append(enemy)
		enemies = alive

func _on_deck_regenerated(_spawn: Vector2, seed_value: int) -> void:
	_rng.seed = seed_value ^ 0xE11E5
	_respawn_population()

func _respawn_population() -> void:
	for enemy in enemies:
		if enemy != null and is_instance_valid(enemy):
			enemy.queue_free()
	enemies.clear()
	call_deferred("_spawn_population")

func _spawn_population() -> void:
	if deck == null or enemy_count <= 0:
		return
	var positions := deck.get_enemy_spawn_positions(enemy_count, minimum_spawn_distance_cells)
	for index in range(positions.size()):
		var enemy := ENEMY_SCENE.instantiate() as SpacehaulEnemy
		if enemy == null:
			continue
		enemy.enemy_type = ENEMY_TYPES[index % ENEMY_TYPES.size()]
		enemy.deck = deck
		enemy.position = positions[index]
		add_child(enemy)
		enemies.append(enemy)

func get_alive_count() -> int:
	var count := 0
	for enemy in enemies:
		if enemy != null and is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			count += 1
	return count
