extends Node2D
class_name ProceduralDeck

# The active environment art lives in the dedicated FloorTiles and WallTiles
# folders. The legacy floor_base / floor_grill / floor_light / hazard textures
# one directory above are intentionally no longer used by the procedural deck.
const FLOOR_TEXTURES: Array[Texture2D] = [
	preload("res://Sprites/Tiles/FloorTiles/floor_base_01.png"),
	preload("res://Sprites/Tiles/FloorTiles/floor_base_02.png"),
	preload("res://Sprites/Tiles/FloorTiles/floor_base_03.png"),
	preload("res://Sprites/Tiles/FloorTiles/floor_base_04.png"),
	preload("res://Sprites/Tiles/FloorTiles/floor_base_05.png"),
	preload("res://Sprites/Tiles/FloorTiles/floor_base_06.png"),
	preload("res://Sprites/Tiles/FloorTiles/floor_base_07.png"),
	preload("res://Sprites/Tiles/FloorTiles/floor_base_08.png"),
	preload("res://Sprites/Tiles/FloorTiles/floor_base_09.png"),
	preload("res://Sprites/Tiles/FloorTiles/floor_base_10.png"),
	preload("res://Sprites/Tiles/FloorTiles/floor_base_11.png"),
	preload("res://Sprites/Tiles/FloorTiles/floor_base_12.png"),
	preload("res://Sprites/Tiles/FloorTiles/floor_base_13.png"),
	preload("res://Sprites/Tiles/FloorTiles/floor_base_14.png"),
	preload("res://Sprites/Tiles/FloorTiles/floor_base_15.png"),
	preload("res://Sprites/Tiles/FloorTiles/floor_base_16.png"),
]

# FloorTiles are authored in rarity order. Earlier numbered tiles are the
# structural vocabulary of a deck; later numbered tiles are increasingly rare
# feature panels. The weights total 100 so they also read as percentages.
# 01: 32%, 02: 19%, 03: 12%, 04: 9%, then progressively rarer through 16.
const FLOOR_TILE_WEIGHTS: Array[float] = [
	45.0, 15.368, 9.706, 7.279, 5.662, 4.044, 3.235, 2.426,
	2.022, 1.618, 1.213, 0.809, 0.607, 0.404, 0.324, 0.283,
]
const FLOOR_FEATURE_START_INDEX := 8

const DECK_PALETTE_SHADER: Shader = preload("res://Shaders/deck_palette.gdshader")
const HAZARD_GAS_SCRIPT: GDScript = preload("res://Scripts/hazard_gas.gd")
# Walls are authored in deck pairs. The current five-deck run uses the first
# ten textures in order: 1-2, 3-4, 5-6, 7-8, 9-10. Additional wall art is
# preloaded and reserved for future decks or special-room variants.
const WALL_TEXTURES: Array[Texture2D] = [
	preload("res://Sprites/Tiles/WallTiles/wall_1.png"),
	preload("res://Sprites/Tiles/WallTiles/wall_2.png"),
	preload("res://Sprites/Tiles/WallTiles/wall_3.png"),
	preload("res://Sprites/Tiles/WallTiles/wall_4.png"),
	preload("res://Sprites/Tiles/WallTiles/wall_5.png"),
	preload("res://Sprites/Tiles/WallTiles/wall_6.png"),
	preload("res://Sprites/Tiles/WallTiles/wall_7.png"),
	preload("res://Sprites/Tiles/WallTiles/wall_8.png"),
	preload("res://Sprites/Tiles/WallTiles/wall_9.png"),
	preload("res://Sprites/Tiles/WallTiles/wall_10.png"),
	preload("res://Sprites/Tiles/WallTiles/wall_11.png"),
	preload("res://Sprites/Tiles/WallTiles/wall_12.png"),
	preload("res://Sprites/Tiles/WallTiles/wall_13.png"),
	preload("res://Sprites/Tiles/WallTiles/wall_14.png"),
	preload("res://Sprites/Tiles/WallTiles/wall_15.png"),
	preload("res://Sprites/Tiles/WallTiles/wall_16.png"),
]
const WALLS_PER_DECK := 2

# Five environment grades sampled from the palette references supplied for the
# authored SpaceMECHA floor, hazard, light and wall art. Deck 1 keeps the
# familiar steel language; later decks rotate through the stronger palette
# families so a deck change is immediately readable without changing tiles.
var DECK_PALETTES := [
	{
		"name": "STEEL",
		"colors": [
			Color8(0, 0, 1), Color8(0, 1, 2), Color8(23, 31, 41),
			Color8(33, 40, 47), Color8(54, 60, 64), Color8(94, 96, 97),
			Color8(64, 72, 75),
		],
	},
	{
		"name": "MOTOR",
		"colors": [
			Color8(0, 1, 4), Color8(13, 16, 19), Color8(28, 34, 50),
			Color8(85, 67, 17), Color8(114, 105, 66), Color8(226, 207, 128),
			Color8(238, 203, 85),
		],
	},
	{
		"name": "CRYO",
		"colors": [
			Color8(0, 0, 2), Color8(0, 2, 4), Color8(2, 4, 6),
			Color8(54, 60, 64), Color8(95, 174, 173), Color8(168, 199, 198),
			Color8(121, 192, 191),
		],
	},
	{
		"name": "VOID",
		"colors": [
			Color8(2, 2, 3), Color8(17, 16, 25), Color8(23, 22, 33),
			Color8(34, 30, 41), Color8(48, 50, 63), Color8(30, 47, 63),
			Color8(92, 161, 167),
		],
	},
	{
		"name": "MONO",
		"colors": [
			Color8(0, 2, 4), Color8(11, 13, 19), Color8(19, 25, 36),
			Color8(33, 40, 47), Color8(64, 72, 75), Color8(94, 96, 97),
			Color8(87, 91, 93),
		],
	},
]

signal regenerated(new_spawn: Vector2, new_seed: int)

@export var grid_width := 45
@export var grid_height := 33
@export var tile_width := 64.0
@export var tile_height := 32.0
@export var wall_height := 30.0
@export var room_count := 13
@export var min_room_size := 4
@export var max_room_size := 9
@export var corridor_width := 4
@export var extra_connection_count := 5
@export var hazard_count := 10
@export_range(0.0, 1.0, 0.01) var floor_grill_chance := 0.18
@export_range(0.0, 1.0, 0.01) var floor_light_chance := 0.06
@export_range(0.0, 1.0, 0.01) var wall_vent_chance := 0.10

var seed_value := 0
var spawn_position := Vector2.ZERO
var deck_bounds := Rect2()

var _rng := RandomNumberGenerator.new()
var _walkable: Array[Array] = []
var _rooms: Array[Rect2i] = []
var _hazard_cells: Array[Vector2i] = []
var _accent_cells: Array[Vector2i] = []
var _floor_styles: Dictionary = {}
var _start_cell := Vector2i.ONE
var _floor_visual_root: Node2D
var _overlay_visual_root: Node2D
var _wall_visual_root: Node2D
var _path_grid := AStarGrid2D.new()
var _deck_palette_index := 0
var _deck_palette_material: ShaderMaterial
var _expedition_special_rooms: Array[Dictionary] = []

@onready var collision_root: Node2D = $CollisionRoot
@onready var hazard_root: Node2D = $HazardRoot

func _ready() -> void:
	z_as_relative = false
	z_index = -1000
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_floor_visual_root = get_node_or_null("FloorVisualRoot") as Node2D
	if _floor_visual_root == null:
		_floor_visual_root = Node2D.new()
		_floor_visual_root.name = "FloorVisualRoot"
		add_child(_floor_visual_root)
	_floor_visual_root.z_index = 0

	_overlay_visual_root = get_node_or_null("OverlayVisualRoot") as Node2D
	if _overlay_visual_root == null:
		_overlay_visual_root = Node2D.new()
		_overlay_visual_root.name = "OverlayVisualRoot"
		add_child(_overlay_visual_root)
	_overlay_visual_root.z_index = 1

	_wall_visual_root = get_node_or_null("WallVisualRoot") as Node2D
	if _wall_visual_root == null:
		_wall_visual_root = Node2D.new()
		_wall_visual_root.name = "WallVisualRoot"
		add_child(_wall_visual_root)
	set_deck_palette(1)
	generate_new_level()

func generate_new_level(requested_seed: int = -1) -> void:
	seed_value = requested_seed if requested_seed >= 0 else int(Time.get_unix_time_from_system() * 1000.0) ^ randi()
	_rng.seed = seed_value
	_normalize_generation_values()
	_build_room_and_hall_deck()
	_assign_expedition_rooms()
	_rebuild_path_grid()
	_select_decorations()
	_rebuild_floor_visuals()
	_rebuild_collisions()
	_rebuild_wall_visuals()
	_rebuild_hazards()
	_rebuild_overlay_visuals()
	_update_deck_bounds()
	spawn_position = _cell_center(_start_cell)

	# Rebind a fresh runtime material after all procedural visuals exist. This is
	# deliberate: walls are recreated during regeneration and must receive the
	# currently selected palette immediately, even while the scene tree is paused
	# for the cinematic deck transfer.
	refresh_deck_palette()
	queue_redraw()
	regenerated.emit(spawn_position, seed_value)

func _normalize_generation_values() -> void:
	grid_width = maxi(25, grid_width)
	grid_height = maxi(21, grid_height)
	min_room_size = maxi(4, min_room_size)
	max_room_size = maxi(min_room_size, max_room_size)
	corridor_width = maxi(4, corridor_width)
	room_count = maxi(6, room_count)

func _reset_walkable() -> void:
	_walkable.clear()
	for x in range(grid_width):
		var column: Array[bool] = []
		for _y in range(grid_height):
			column.append(false)
		_walkable.append(column)

func _build_room_and_hall_deck() -> void:
	_reset_walkable()
	_rooms.clear()

	var spawn_size := Vector2i(maxi(8, min_room_size + 3), maxi(8, min_room_size + 3))
	var spawn_pos := Vector2i(
		int((grid_width - spawn_size.x) / 2),
		int((grid_height - spawn_size.y) / 2)
	)
	var spawn_room := Rect2i(spawn_pos, spawn_size)
	_rooms.append(spawn_room)
	_carve_rect(spawn_room)
	_start_cell = _rect_center(spawn_room)

	var placement_attempts := room_count * 24
	while _rooms.size() < room_count and placement_attempts > 0:
		placement_attempts -= 1
		var width := _rng.randi_range(min_room_size, max_room_size)
		var height := _rng.randi_range(min_room_size, max_room_size)
		if width >= grid_width - 6 or height >= grid_height - 6:
			continue
		var x := _rng.randi_range(2, grid_width - width - 3)
		var y := _rng.randi_range(2, grid_height - height - 3)
		var candidate := Rect2i(x, y, width, height)
		if _room_has_clearance(candidate, 2):
			_rooms.append(candidate)
			_carve_rect(candidate)

	_connect_all_rooms()
	_add_extra_hall_connections()
	_add_service_bays()

func _room_has_clearance(candidate: Rect2i, clearance: int) -> bool:
	var expanded := candidate.grow(clearance)
	for room in _rooms:
		if expanded.intersects(room):
			return false
	return true

func _connect_all_rooms() -> void:
	if _rooms.size() <= 1:
		return

	var connected: Array[int] = [0]
	var remaining: Array[int] = []
	for i in range(1, _rooms.size()):
		remaining.append(i)

	while not remaining.is_empty():
		var best_connected := connected[0]
		var best_remaining_index := 0
		var best_distance := INF

		for connected_index in connected:
			var from_center := Vector2(_rect_center(_rooms[connected_index]))
			for remaining_index in range(remaining.size()):
				var room_index := remaining[remaining_index]
				var to_center := Vector2(_rect_center(_rooms[room_index]))
				var distance := from_center.distance_squared_to(to_center)
				if distance < best_distance:
					best_distance = distance
					best_connected = connected_index
					best_remaining_index = remaining_index

		var next_room_index := remaining[best_remaining_index]
		_carve_corridor(_rect_center(_rooms[best_connected]), _rect_center(_rooms[next_room_index]))
		connected.append(next_room_index)
		remaining.remove_at(best_remaining_index)

func _add_extra_hall_connections() -> void:
	if _rooms.size() < 3:
		return
	for _i in range(extra_connection_count):
		var a := _rng.randi_range(0, _rooms.size() - 1)
		var b := _rng.randi_range(0, _rooms.size() - 1)
		if a == b:
			b = (b + 1) % _rooms.size()
		_carve_corridor(_rect_center(_rooms[a]), _rect_center(_rooms[b]))

func _add_service_bays() -> void:
	# Add a few broad side spaces so the deck does not read like repeated rooms only.
	var bay_count := _rng.randi_range(2, 4)
	for _i in range(bay_count):
		var anchor_room := _rooms[_rng.randi_range(0, _rooms.size() - 1)]
		var anchor := _rect_center(anchor_room)
		var width := _rng.randi_range(4, 7)
		var height := _rng.randi_range(4, 7)
		var offset := Vector2i(
			_rng.randi_range(-10, 10),
			_rng.randi_range(-8, 8)
		)
		var center := anchor + offset
		var bay_position := center - Vector2i(int(width / 2), int(height / 2))
		bay_position.x = clampi(bay_position.x, 1, grid_width - width - 1)
		bay_position.y = clampi(bay_position.y, 1, grid_height - height - 1)
		var bay := Rect2i(bay_position, Vector2i(width, height))
		_carve_rect(bay)
		_carve_corridor(anchor, _rect_center(bay))

func _carve_rect(rect: Rect2i) -> void:
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			if x > 0 and y > 0 and x < grid_width - 1 and y < grid_height - 1:
				_walkable[x][y] = true

func _carve_corridor(from_cell: Vector2i, to_cell: Vector2i) -> void:
	if _rng.randf() < 0.5:
		_carve_horizontal_lane(from_cell.x, to_cell.x, from_cell.y)
		_carve_vertical_lane(from_cell.y, to_cell.y, to_cell.x)
	else:
		_carve_vertical_lane(from_cell.y, to_cell.y, from_cell.x)
		_carve_horizontal_lane(from_cell.x, to_cell.x, to_cell.y)

func _carve_horizontal_lane(from_x: int, to_x: int, center_y: int) -> void:
	var start_x := mini(from_x, to_x)
	var end_x := maxi(from_x, to_x)
	var offset_start := -int(corridor_width / 2)
	for x in range(start_x, end_x + 1):
		for offset in range(offset_start, offset_start + corridor_width):
			var y := center_y + offset
			if x > 0 and y > 0 and x < grid_width - 1 and y < grid_height - 1:
				_walkable[x][y] = true

func _carve_vertical_lane(from_y: int, to_y: int, center_x: int) -> void:
	var start_y := mini(from_y, to_y)
	var end_y := maxi(from_y, to_y)
	var offset_start := -int(corridor_width / 2)
	for y in range(start_y, end_y + 1):
		for offset in range(offset_start, offset_start + corridor_width):
			var x := center_x + offset
			if x > 0 and y > 0 and x < grid_width - 1 and y < grid_height - 1:
				_walkable[x][y] = true

func _rect_center(rect: Rect2i) -> Vector2i:
	return rect.position + Vector2i(int(rect.size.x / 2), int(rect.size.y / 2))

func _select_decorations() -> void:
	_hazard_cells.clear()
	_accent_cells.clear()
	_floor_styles.clear()

	var floor_cells: Array[Vector2i] = []

	for x in range(1, grid_width - 1):
		for y in range(1, grid_height - 1):
			if not _walkable[x][y]:
				continue

			var cell := Vector2i(x, y)
			var tile_index := _choose_floor_tile_index(cell)
			_floor_styles[cell] = tile_index

			# Later authored tiles are feature panels rather than general floor fill.
			if tile_index >= FLOOR_FEATURE_START_INDEX:
				_accent_cells.append(cell)

			if Vector2(cell).distance_to(Vector2(_start_cell)) >= 7.0:
				floor_cells.append(cell)

	# Hazards are gameplay metadata now, not a special floor texture. This keeps
	# the FloorTiles art intact and lets any floor design become dangerous.
	_shuffle_cells(floor_cells)
	for i in range(mini(hazard_count, floor_cells.size())):
		_hazard_cells.append(floor_cells[i])

func _choose_floor_tile_index(cell: Vector2i) -> int:
	# The spawn pad always uses the most common structural tile so the player
	# enters each deck on a calm, immediately readable surface.
	if cell == _start_cell:
		return 0

	var chosen := _weighted_floor_tile_index(FLOOR_TEXTURES.size() - 1)

	# Rare feature panels look authored when they have breathing room. If a late
	# tile would touch another late tile, usually reroll from the first eight
	# structural variants instead of creating a noisy patchwork cluster.
	if chosen >= FLOOR_FEATURE_START_INDEX and _has_adjacent_feature_tile(cell):
		if _rng.randf() < 0.88:
			chosen = _weighted_floor_tile_index(FLOOR_FEATURE_START_INDEX - 1)

	return chosen

func _weighted_floor_tile_index(max_index: int) -> int:
	var upper := clampi(max_index, 0, mini(FLOOR_TEXTURES.size(), FLOOR_TILE_WEIGHTS.size()) - 1)
	var total_weight := 0.0
	for i in range(upper + 1):
		total_weight += FLOOR_TILE_WEIGHTS[i]

	if total_weight <= 0.0:
		return 0

	var roll := _rng.randf() * total_weight
	var accumulated := 0.0
	for i in range(upper + 1):
		accumulated += FLOOR_TILE_WEIGHTS[i]
		if roll <= accumulated:
			return i

	return upper

func _has_adjacent_feature_tile(cell: Vector2i) -> bool:
	# Selection runs left-to-right through columns, so only already-authored
	# neighbours are considered. This is enough to break up obvious feature clumps
	# while keeping generation deterministic for a given deck seed.
	for neighbor in [cell + Vector2i.LEFT, cell + Vector2i.UP]:
		if _floor_styles.has(neighbor):
			var neighbor_index := int(_floor_styles[neighbor])
			if neighbor_index >= FLOOR_FEATURE_START_INDEX:
				return true
	return false

func _rebuild_floor_visuals() -> void:
	if _floor_visual_root == null:
		return
	_clear_children(_floor_visual_root)

	# Floor tiles are real Sprite2D CanvasItems instead of texture calls inside
	# ProceduralDeck._draw(). A canvas_item shader attached to a Sprite2D always
	# receives that sprite texture as TEXTURE, so runtime palette changes are
	# explicit and reliable in Godot 4.6.
	for diagonal in range(grid_width + grid_height - 1):
		for x in range(grid_width):
			var y := diagonal - x
			if y < 0 or y >= grid_height or not _walkable[x][y]:
				continue
			var cell := Vector2i(x, y)
			var tile_index := clampi(int(_floor_styles.get(cell, 0)), 0, FLOOR_TEXTURES.size() - 1)
			var texture := FLOOR_TEXTURES[tile_index]
			var sprite := Sprite2D.new()
			sprite.name = "Floor_%d_%d" % [x, y]
			sprite.texture = texture
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.centered = true
			sprite.position = _cell_center(cell).round()
			if _deck_palette_material != null:
				sprite.material = _deck_palette_material
			_floor_visual_root.add_child(sprite)

func _rebuild_collisions() -> void:
	_clear_children(collision_root)
	var body := StaticBody2D.new()
	body.name = "DeckWalls"
	body.collision_layer = 1
	body.collision_mask = 1
	collision_root.add_child(body)

	for x in range(grid_width):
		for y in range(grid_height):
			if _walkable[x][y]:
				continue
			var cell := Vector2i(x, y)
			if not _wall_touches_floor(cell):
				continue
			var shape := ConvexPolygonShape2D.new()
			shape.points = _diamond_points_local(tile_width * 0.86, tile_height * 0.82)
			var collider := CollisionShape2D.new()
			collider.position = _cell_center(cell)
			collider.shape = shape
			body.add_child(collider)

func _rebuild_wall_visuals() -> void:
	_clear_children(_wall_visual_root)
	for x in range(grid_width):
		for y in range(grid_height):
			if _walkable[x][y]:
				continue
			var cell := Vector2i(x, y)
			if not _wall_touches_floor(cell):
				continue
			_create_wall_block(cell)

func _create_wall_block(cell: Vector2i) -> void:
	var center := _cell_center(cell)
	var block := Node2D.new()
	block.name = "Wall_%d_%d" % [cell.x, cell.y]
	block.position = center
	block.z_as_relative = false
	block.z_index = clampi(int(round(center.y)), -3000, 3000)
	_wall_visual_root.add_child(block)

	# Each deck owns a dedicated pair of authored walls. The first texture in
	# the pair is the common structural wall; the second is the detail variant.
	# This keeps wall identity stable within a deck instead of drawing from the
	# entire wall library at random.
	var pair_start := _wall_pair_start_index()
	var common_texture := WALL_TEXTURES[pair_start]
	var detail_texture := WALL_TEXTURES[pair_start + 1]
	var texture := detail_texture if _rng.randf() < wall_vent_chance else common_texture

	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if _deck_palette_material != null:
		sprite.material = _deck_palette_material
	sprite.centered = true
	sprite.position = Vector2(0.0, tile_height * 0.5 - texture.get_height() * 0.5)

	# Mirroring only the common wall gives repetition some variation without
	# flipping distinctive authored details such as doors, terminals, or pipes.
	if texture == common_texture and _rng.randf() < 0.5:
		sprite.flip_h = true

	block.add_child(sprite)

func _wall_pair_start_index() -> int:
	if WALL_TEXTURES.size() < WALLS_PER_DECK:
		return 0

	# Deck palette index is zero based. With five current decks this resolves to
	# 0, 2, 4, 6, 8 and therefore wall pairs 1-2 through 9-10.
	var pair_count := maxi(1, int(WALL_TEXTURES.size() / WALLS_PER_DECK))
	var deck_pair := _deck_palette_index % pair_count
	return clampi(deck_pair * WALLS_PER_DECK, 0, WALL_TEXTURES.size() - WALLS_PER_DECK)

func _rebuild_hazards() -> void:
	_clear_children(hazard_root)
	for cell in _hazard_cells:
		var area := Area2D.new()
		area.name = "ElectricalHazard_%d_%d" % [cell.x, cell.y]
		area.position = _cell_center(cell)
		area.monitoring = true
		area.collision_layer = 0
		# Layer 1 = player, layer 2 = enemies. Hazards are environmental threats to both.
		area.collision_mask = 3
		var shape := ConvexPolygonShape2D.new()
		shape.points = _diamond_points_local(tile_width * 0.40, tile_height * 0.55)
		var collision := CollisionShape2D.new()
		collision.shape = shape
		area.add_child(collision)
		area.body_entered.connect(_on_hazard_body_entered)
		hazard_root.add_child(area)

func _rebuild_overlay_visuals() -> void:
	if _overlay_visual_root == null:
		return
	_clear_children(_overlay_visual_root)

	var accent := Color("59d4e8")
	if _deck_palette_index > 0 and _deck_palette_index < DECK_PALETTES.size():
		var palette: Dictionary = DECK_PALETTES[_deck_palette_index]
		var colors: Array = palette.get("colors", [])
		if colors.size() >= 7:
			accent = colors[6]

	for cell in _hazard_cells:
		var hazard_center := _cell_center(cell)
		var gas := Node2D.new()
		gas.set_script(HAZARD_GAS_SCRIPT)
		gas.name = "HazardGas_%d_%d" % [cell.x, cell.y]
		gas.position = hazard_center
		_overlay_visual_root.add_child(gas)
		if gas.has_method("setup"):
			gas.call("setup", tile_width, tile_height, seed_value ^ int(cell.x * 92821 + cell.y * 68917))

	var center := _cell_center(_start_cell)
	var outer_points := _diamond_points(Vector2.ZERO, 34.0, 18.0)
	var inner_points := _diamond_points(Vector2.ZERO, 24.0, 12.0)

	var pad := Polygon2D.new()
	pad.name = "SpawnPadFill"
	pad.position = center
	pad.polygon = outer_points
	pad.color = accent.darkened(0.68)
	_overlay_visual_root.add_child(pad)

	var outer_line := Line2D.new()
	outer_line.name = "SpawnPadOuter"
	outer_line.position = center
	outer_line.points = _closed_polygon(outer_points)
	outer_line.width = 2.0
	outer_line.default_color = accent.lightened(0.18)
	outer_line.antialiased = false
	_overlay_visual_root.add_child(outer_line)

	var inner_line := Line2D.new()
	inner_line.name = "SpawnPadInner"
	inner_line.position = center
	inner_line.points = _closed_polygon(inner_points)
	inner_line.width = 1.0
	inner_line.default_color = accent.darkened(0.20)
	inner_line.antialiased = false
	_overlay_visual_root.add_child(inner_line)

	for segment in [
		PackedVector2Array([Vector2(-7.0, 0.0), Vector2(7.0, 0.0)]),
		PackedVector2Array([Vector2(0.0, -4.0), Vector2(0.0, 4.0)]),
	]:
		var cross := Line2D.new()
		cross.position = center
		cross.points = segment
		cross.width = 1.0
		cross.default_color = accent.lightened(0.18)
		cross.antialiased = false
		_overlay_visual_root.add_child(cross)

	_rebuild_expedition_room_markers()


# -----------------------------------------------------------------------------
# Expedition room metadata / floor markers
# -----------------------------------------------------------------------------

func _assign_expedition_rooms() -> void:
	_expedition_special_rooms.clear()
	if _rooms.size() < 7:
		return

	var available: Array[int] = []
	for i in range(1, _rooms.size()):
		available.append(i)

	# Put the HIVE as far from the deployment room as possible. Extraction is then
	# chosen far from the hive, encouraging an actual escape traversal after the
	# boss instead of ending the run in the boss chamber.
	var hive_index := _farthest_room_index(_start_cell, available)
	available.erase(hive_index)
	var hive_cell := _rect_center(_rooms[hive_index])
	var extraction_index := _farthest_room_index(hive_cell, available)
	available.erase(extraction_index)

	var chosen_objectives: Array[int] = []
	var anchors: Array[Vector2i] = [_start_cell, hive_cell, _rect_center(_rooms[extraction_index])]
	while chosen_objectives.size() < 4 and not available.is_empty():
		var best_index := available[0]
		var best_score := -1.0
		for room_index in available:
			var center := _rect_center(_rooms[room_index])
			var nearest_anchor := INF
			for anchor in anchors:
				nearest_anchor = minf(nearest_anchor, Vector2(center).distance_to(Vector2(anchor)))
			if nearest_anchor > best_score:
				best_score = nearest_anchor
				best_index = room_index
		chosen_objectives.append(best_index)
		anchors.append(_rect_center(_rooms[best_index]))
		available.erase(best_index)

	var objective_roles := ["ARMORY", "REPAIR BAY", "DATA CACHE", "REACTOR"]
	for i in range(mini(objective_roles.size(), chosen_objectives.size())):
		_add_expedition_room(String(objective_roles[i]), chosen_objectives[i])

	_add_expedition_room("HIVE", hive_index)
	_add_expedition_room("EXTRACTION", extraction_index)

func _farthest_room_index(reference_cell: Vector2i, candidates: Array[int]) -> int:
	if candidates.is_empty():
		return -1
	var best_index := candidates[0]
	var best_distance := -1.0
	for room_index in candidates:
		var center := _rect_center(_rooms[room_index])
		var distance := Vector2(center).distance_squared_to(Vector2(reference_cell))
		if distance > best_distance:
			best_distance = distance
			best_index = room_index
	return best_index

func _add_expedition_room(role: String, room_index: int) -> void:
	if room_index < 0 or room_index >= _rooms.size():
		return
	var room := _rooms[room_index]
	var center_cell := _rect_center(room)
	_expedition_special_rooms.append({
		"role": role,
		"room_index": room_index,
		"room": room,
		"center_cell": center_cell,
		"center_world": _cell_center(center_cell),
	})

func _rebuild_expedition_room_markers() -> void:
	if _overlay_visual_root == null:
		return
	for special in _expedition_special_rooms:
		var role := String(special.get("role", ""))
		var center_world: Vector2 = special.get("center_world", Vector2.ZERO)
		var color := _expedition_role_color(role)

		# Floor-projected diamonds stay beneath actors and read like diegetic deck
		# signage rather than floating UI. The minimap supplies the text identity.
		var marker := Node2D.new()
		marker.name = "Expedition_%s" % role.replace(" ", "_")
		marker.position = center_world.round()
		marker.z_as_relative = false
		marker.z_index = clampi(int(round(center_world.y)) - 3, -3000, 3000)
		_overlay_visual_root.add_child(marker)

		var outer := Line2D.new()
		outer.points = _closed_polygon(_diamond_points(Vector2.ZERO, 29.0, 15.0))
		outer.width = 2.0
		outer.default_color = color
		outer.antialiased = false
		marker.add_child(outer)

		var inner := Line2D.new()
		inner.points = _closed_polygon(_diamond_points(Vector2.ZERO, 17.0, 9.0))
		inner.width = 1.0
		inner.default_color = Color(color.r, color.g, color.b, 0.58)
		inner.antialiased = false
		marker.add_child(inner)

		var dot := Polygon2D.new()
		dot.polygon = PackedVector2Array([Vector2(-2.0, 0.0), Vector2(0.0, -1.5), Vector2(2.0, 0.0), Vector2(0.0, 1.5)])
		dot.color = color
		marker.add_child(dot)

		var label := Label.new()
		label.position = Vector2(-42.0, -26.0)
		label.size = Vector2(84.0, 14.0)
		label.text = role
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_override("font", load("res://Fonts/mago1.ttf") as Font)
		label.add_theme_font_size_override("font_size", 9)
		label.add_theme_color_override("font_color", color)
		label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.88))
		label.add_theme_constant_override("outline_size", 2)
		marker.add_child(label)

func _expedition_role_color(role: String) -> Color:
	match role:
		"ARMORY":
			return Color(0.35, 0.92, 1.0, 0.90)
		"REPAIR BAY":
			return Color(0.40, 1.0, 0.58, 0.90)
		"DATA CACHE":
			return Color(0.80, 0.56, 1.0, 0.90)
		"REACTOR":
			return Color(1.0, 0.76, 0.30, 0.90)
		"HIVE":
			return Color(1.0, 0.30, 0.46, 0.90)
		"EXTRACTION":
			return Color(0.35, 0.72, 1.0, 0.90)
		_:
			return Color(0.75, 0.82, 0.86, 0.90)

func get_room_rects() -> Array:
	return _rooms.duplicate(true)

func get_walkable_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in range(grid_width):
		for y in range(grid_height):
			if _walkable[x][y]:
				cells.append(Vector2i(x, y))
	return cells

func get_expedition_special_rooms() -> Array:
	return _expedition_special_rooms.duplicate(true)

func get_room_index_at_world(world_position: Vector2) -> int:
	var cell := world_to_cell(world_position)
	for i in range(_rooms.size()):
		if _rooms[i].has_point(cell):
			return i
	return -1

func get_room_center_world(room_index: int) -> Vector2:
	if room_index < 0 or room_index >= _rooms.size():
		return Vector2.ZERO
	return _cell_center(_rect_center(_rooms[room_index]))

func get_expedition_room(role: String) -> Dictionary:
	for special in _expedition_special_rooms:
		if String(special.get("role", "")) == role:
			return special.duplicate(true)
	return {}

func _on_hazard_body_entered(body: Node) -> void:
	if body.has_method("take_hurt"):
		body.call_deferred("take_hurt")

func set_deck_palette(deck_number: int) -> void:
	if DECK_PALETTES.is_empty():
		return
	_deck_palette_index = (maxi(1, deck_number) - 1) % DECK_PALETTES.size()
	refresh_deck_palette()

func refresh_deck_palette() -> void:
	if DECK_PALETTES.is_empty():
		return

	# Always create a fresh material instance when the palette changes or the
	# procedural deck is rebuilt. This makes runtime palette switching explicit
	# instead of depending on an older ShaderMaterial remaining attached to
	# regenerated CanvasItems.
	_build_deck_palette_shader()
	_apply_current_palette_uniforms()
	_apply_palette_material_to_visuals()
	queue_redraw()

func _apply_current_palette_uniforms() -> void:
	if _deck_palette_material == null:
		return
	var palette: Dictionary = DECK_PALETTES[_deck_palette_index]
	var colors: Array = palette.get("colors", [])
	if colors.size() < 7:
		return

	_deck_palette_material.set_shader_parameter("palette_0", colors[0])
	_deck_palette_material.set_shader_parameter("palette_1", colors[1])
	_deck_palette_material.set_shader_parameter("palette_2", colors[2])
	_deck_palette_material.set_shader_parameter("palette_3", colors[3])
	_deck_palette_material.set_shader_parameter("palette_4", colors[4])
	_deck_palette_material.set_shader_parameter("palette_5", colors[5])
	_deck_palette_material.set_shader_parameter("palette_accent", colors[6])

	# Deck 1 is the untouched authored palette. Subsequent decks are intentionally
	# strong enough to read instantly while preserving source-pixel brightness.
	var grade_strength := 0.0 if _deck_palette_index == 0 else 1.0
	_deck_palette_material.set_shader_parameter("grade_strength", grade_strength)
	_deck_palette_material.set_shader_parameter("accent_strength", 1.0)
	print("[SPACEMECHA] Runtime deck palette DECK %d %s grade %.2f" % [
		_deck_palette_index + 1, get_deck_palette_name(), grade_strength
	])

func _deck_fallback_modulate() -> Color:
	# A light root-level tint backs up the shader and makes a palette change
	# visible even on a renderer that handles custom canvas materials differently.
	# Values above 1.0 intentionally preserve brightness instead of dimming art.
	match _deck_palette_index:
		1:
			return Color(1.24, 1.10, 0.72, 1.0)
		2:
			return Color(0.78, 1.18, 1.18, 1.0)
		3:
			return Color(0.94, 0.82, 1.16, 1.0)
		4:
			return Color(0.96, 0.98, 1.02, 1.0)
		_:
			return Color.WHITE

func _apply_palette_material_to_visuals() -> void:
	# Keep ProceduralDeck itself unshaded. It only draws the deep background now.
	# The actual textured environment uses Sprite2D nodes with an explicit
	# ShaderMaterial, which makes runtime texture sampling deterministic.
	material = null
	var fallback_tint := _deck_fallback_modulate()

	if _floor_visual_root != null:
		_floor_visual_root.modulate = fallback_tint
		for child in _floor_visual_root.get_children():
			var canvas_child := child as CanvasItem
			if canvas_child != null:
				canvas_child.material = _deck_palette_material

	if _wall_visual_root != null:
		_wall_visual_root.modulate = fallback_tint
		for block in _wall_visual_root.get_children():
			for child in block.get_children():
				var canvas_child := child as CanvasItem
				if canvas_child != null:
					canvas_child.material = _deck_palette_material

	# Vector overlays do not need the shader. Rebuild them so their hazard and
	# spawn-pad accent follows the currently selected deck palette as well.
	if _overlay_visual_root != null and not _walkable.is_empty():
		_rebuild_overlay_visuals()

func get_deck_palette_name(deck_number: int = -1) -> String:
	if DECK_PALETTES.is_empty():
		return "DECK"
	var index := _deck_palette_index
	if deck_number > 0:
		index = (deck_number - 1) % DECK_PALETTES.size()
	var palette: Dictionary = DECK_PALETTES[index]
	return String(palette.get("name", "DECK"))

func get_deck_palette_count() -> int:
	return DECK_PALETTES.size()

func _build_deck_palette_shader() -> void:
	_deck_palette_material = ShaderMaterial.new()
	_deck_palette_material.shader = DECK_PALETTE_SHADER

func _draw() -> void:
	# The parent now draws only the void below the deck. Textured floor tiles are
	# Sprite2D children so the palette shader is guaranteed to receive TEXTURE.
	draw_rect(deck_bounds.grow(900.0), Color("05070b"))


func _wall_touches_floor(cell: Vector2i) -> bool:
	for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var neighbor = cell + direction
		if _inside(neighbor) and _walkable[neighbor.x][neighbor.y]:
			return true
	return false

func _inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < grid_width and cell.y < grid_height

func _shuffle_cells(cells: Array[Vector2i]) -> void:
	for i in range(cells.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var temp := cells[i]
		cells[i] = cells[j]
		cells[j] = temp

func _cell_center(cell: Vector2i) -> Vector2:
	var gx := float(cell.x)
	var gy := float(cell.y)
	return Vector2(
		(gx - gy) * tile_width * 0.5,
		(gx + gy) * tile_height * 0.5
	)

func _diamond_points(center: Vector2, width: float, height: float) -> PackedVector2Array:
	return PackedVector2Array([
		center + Vector2(0.0, -height * 0.5),
		center + Vector2(width * 0.5, 0.0),
		center + Vector2(0.0, height * 0.5),
		center + Vector2(-width * 0.5, 0.0),
	])

func _diamond_points_local(width: float, height: float) -> PackedVector2Array:
	return _diamond_points(Vector2.ZERO, width, height)

func _closed_polygon(points: PackedVector2Array) -> PackedVector2Array:
	var closed := PackedVector2Array(points)
	if not points.is_empty():
		closed.append(points[0])
	return closed

func _update_deck_bounds() -> void:
	var centers := PackedVector2Array([
		_cell_center(Vector2i(0, 0)),
		_cell_center(Vector2i(grid_width - 1, 0)),
		_cell_center(Vector2i(0, grid_height - 1)),
		_cell_center(Vector2i(grid_width - 1, grid_height - 1)),
	])
	var min_point := centers[0]
	var max_point := centers[0]
	for point in centers:
		min_point.x = minf(min_point.x, point.x)
		min_point.y = minf(min_point.y, point.y)
		max_point.x = maxf(max_point.x, point.x)
		max_point.y = maxf(max_point.y, point.y)
	deck_bounds = Rect2(
		min_point - Vector2(tile_width, tile_height + wall_height),
		(max_point - min_point) + Vector2(tile_width * 2.0, tile_height * 2.0 + wall_height)
	)

func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.free()

func get_mecha_spawn_positions(count: int) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if count <= 0:
		return result

	var cells: Array[Vector2i] = []
	for x in range(1, grid_width - 1):
		for y in range(1, grid_height - 1):
			if not _walkable[x][y]:
				continue
			var cell := Vector2i(x, y)
			if cell in _hazard_cells:
				continue
			cells.append(cell)

	var local_rng := RandomNumberGenerator.new()
	local_rng.seed = seed_value ^ 0x5A17C3
	for i in range(cells.size() - 1, 0, -1):
		var j := local_rng.randi_range(0, i)
		var temp := cells[i]
		cells[i] = cells[j]
		cells[j] = temp

	var chosen: Array[Vector2i] = []
	if _start_cell in cells:
		chosen.append(_start_cell)

	for cell in cells:
		if chosen.size() >= count:
			break
		var far_enough := true
		for existing in chosen:
			if Vector2(cell).distance_to(Vector2(existing)) < 3.0:
				far_enough = false
				break
		if far_enough:
			chosen.append(cell)

	if chosen.size() < count:
		for cell in cells:
			if chosen.size() >= count:
				break
			if cell not in chosen:
				chosen.append(cell)

	for cell in chosen:
		result.append(_cell_center(cell))
	return result


func _rebuild_path_grid() -> void:
	_path_grid = AStarGrid2D.new()
	_path_grid.region = Rect2i(0, 0, grid_width, grid_height)
	_path_grid.cell_size = Vector2.ONE
	_path_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_path_grid.update()
	for x in range(grid_width):
		for y in range(grid_height):
			if not _walkable[x][y]:
				_path_grid.set_point_solid(Vector2i(x, y), true)

func world_to_cell(world_position: Vector2) -> Vector2i:
	# Inverse of the 2:1 isometric projection used by _cell_center().
	var grid_x := world_position.x / tile_width + world_position.y / tile_height
	var grid_y := world_position.y / tile_height - world_position.x / tile_width
	return Vector2i(roundi(grid_x), roundi(grid_y))

func get_next_path_step(from_world: Vector2, to_world: Vector2) -> Vector2:
	var from_cell := world_to_cell(from_world)
	var to_cell := world_to_cell(to_world)
	if not _inside(from_cell) or not _inside(to_cell):
		return to_world
	if not _walkable[from_cell.x][from_cell.y] or not _walkable[to_cell.x][to_cell.y]:
		return to_world
	var path := _path_grid.get_id_path(from_cell, to_cell)
	if path.size() >= 2:
		var next_cell: Vector2i = path[1]
		return _cell_center(next_cell)
	return to_world

func get_random_walkable_position_near(center_world: Vector2, radius_cells: int, rng: RandomNumberGenerator) -> Vector2:
	var center_cell := world_to_cell(center_world)
	var candidates: Array[Vector2i] = []
	var radius := maxi(1, radius_cells)
	for x in range(center_cell.x - radius, center_cell.x + radius + 1):
		for y in range(center_cell.y - radius, center_cell.y + radius + 1):
			var cell := Vector2i(x, y)
			if not _inside(cell):
				continue
			if not _walkable[x][y] or cell in _hazard_cells:
				continue
			candidates.append(cell)
	if candidates.is_empty():
		return center_world
	var chosen := candidates[rng.randi_range(0, candidates.size() - 1)]
	return _cell_center(chosen)

func get_enemy_spawn_positions(count: int, minimum_distance_cells: int = 7) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if count <= 0:
		return result

	var candidates: Array[Vector2i] = []
	for x in range(1, grid_width - 1):
		for y in range(1, grid_height - 1):
			if not _walkable[x][y]:
				continue
			var cell := Vector2i(x, y)
			if cell in _hazard_cells:
				continue
			if Vector2(cell).distance_to(Vector2(_start_cell)) < float(minimum_distance_cells):
				continue
			candidates.append(cell)

	var local_rng := RandomNumberGenerator.new()
	local_rng.seed = seed_value ^ 0xE11E5
	for i in range(candidates.size() - 1, 0, -1):
		var j := local_rng.randi_range(0, i)
		var temp := candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = temp

	var limit := mini(count, candidates.size())
	for i in range(limit):
		var center := _cell_center(candidates[i])
		# Small isometric-safe jitter keeps swarms from looking snapped to a grid.
		center += Vector2(local_rng.randf_range(-5.0, 5.0), local_rng.randf_range(-2.0, 2.0))
		result.append(center.round())
	return result

func get_random_enemy_spawn_position(reference_world: Vector2, minimum_distance_cells: int, rng: RandomNumberGenerator) -> Vector2:
	var reference_cell := world_to_cell(reference_world)
	var candidates: Array[Vector2i] = []
	var minimum_distance := float(maxi(1, minimum_distance_cells))
	for x in range(1, grid_width - 1):
		for y in range(1, grid_height - 1):
			if not _walkable[x][y]:
				continue
			var cell := Vector2i(x, y)
			if cell in _hazard_cells:
				continue
			if Vector2(cell).distance_to(Vector2(reference_cell)) < minimum_distance:
				continue
			candidates.append(cell)

	if candidates.is_empty():
		return Vector2.ZERO

	var chosen := candidates[rng.randi_range(0, candidates.size() - 1)]
	var center := _cell_center(chosen)
	center += Vector2(rng.randf_range(-5.0, 5.0), rng.randf_range(-2.0, 2.0))
	return center.round()
