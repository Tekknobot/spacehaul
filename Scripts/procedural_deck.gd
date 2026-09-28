extends Node2D
class_name ProceduralDeck

const FLOOR_BASE_TEXTURE = preload("res://Sprites/Tiles/floor_base_01.png")
const FLOOR_GRILL_TEXTURES: Array[Texture2D] = [
	preload("res://Sprites/Tiles/floor_grill_01.png"),
	preload("res://Sprites/Tiles/floor_grill_02.png"),
	preload("res://Sprites/Tiles/floor_grill_03.png"),
]
const FLOOR_LIGHT_TEXTURE = preload("res://Sprites/Tiles/floor_light_01.png")
const FLOOR_HAZARD_TEXTURE = preload("res://Sprites/Tiles/floor_hazardzone_01.png")
const WALL_TEXTURES: Array[Texture2D] = [
	preload("res://Sprites/Tiles/wall_1.png"),
	preload("res://Sprites/Tiles/wall_2.png"),
]

enum FloorStyle {
	BASE,
	GRILL_1,
	GRILL_2,
	GRILL_3,
	LIGHT,
	HAZARD,
}

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
var _wall_visual_root: Node2D
var _path_grid := AStarGrid2D.new()

@onready var collision_root: Node2D = $CollisionRoot
@onready var hazard_root: Node2D = $HazardRoot

func _ready() -> void:
	z_as_relative = false
	z_index = -1000
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_wall_visual_root = get_node_or_null("WallVisualRoot") as Node2D
	if _wall_visual_root == null:
		_wall_visual_root = Node2D.new()
		_wall_visual_root.name = "WallVisualRoot"
		add_child(_wall_visual_root)
	generate_new_level()

func generate_new_level(requested_seed: int = -1) -> void:
	seed_value = requested_seed if requested_seed >= 0 else int(Time.get_unix_time_from_system() * 1000.0) ^ randi()
	_rng.seed = seed_value
	_normalize_generation_values()
	_build_room_and_hall_deck()
	_rebuild_path_grid()
	_select_decorations()
	_rebuild_collisions()
	_rebuild_wall_visuals()
	_rebuild_hazards()
	_update_deck_bounds()
	spawn_position = _cell_center(_start_cell)
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
			var style := FloorStyle.BASE

			# Keep the spawn room visually calm while the rest of the deck gains
			# occasional vents, grilles and embedded light strips.
			if cell != _start_cell:
				var detail_roll := _rng.randf()
				if detail_roll < floor_light_chance:
					style = FloorStyle.LIGHT
				elif detail_roll < floor_light_chance + floor_grill_chance:
					style = FloorStyle.GRILL_1 + _rng.randi_range(0, 2)

			_floor_styles[cell] = style
			if style != FloorStyle.BASE:
				_accent_cells.append(cell)

			if Vector2(cell).distance_to(Vector2(_start_cell)) >= 7.0:
				floor_cells.append(cell)

	_shuffle_cells(floor_cells)
	for i in range(mini(hazard_count, floor_cells.size())):
		var hazard_cell := floor_cells[i]
		_hazard_cells.append(hazard_cell)
		_floor_styles[hazard_cell] = FloorStyle.HAZARD

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

	# The supplied wall art is 64x64. Positioning the texture so its bottom
	# lands on the bottom point of the 64x32 floor diamond preserves the same
	# visual envelope as the original 30px procedural wall extrusion.
	var texture := WALL_TEXTURES[1] if _rng.randf() < wall_vent_chance else WALL_TEXTURES[0]
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = true
	sprite.position = Vector2(0.0, tile_height * 0.5 - texture.get_height() * 0.5)

	# Mirroring the common wall panel adds variation without resampling it.
	if texture == WALL_TEXTURES[0] and _rng.randf() < 0.5:
		sprite.flip_h = true

	block.add_child(sprite)

func _rebuild_hazards() -> void:
	_clear_children(hazard_root)
	for cell in _hazard_cells:
		var area := Area2D.new()
		area.name = "ElectricalHazard_%d_%d" % [cell.x, cell.y]
		area.position = _cell_center(cell)
		area.monitoring = true
		area.collision_layer = 0
		area.collision_mask = 1
		var shape := ConvexPolygonShape2D.new()
		shape.points = _diamond_points_local(tile_width * 0.40, tile_height * 0.55)
		var collision := CollisionShape2D.new()
		collision.shape = shape
		area.add_child(collision)
		area.body_entered.connect(_on_hazard_body_entered)
		hazard_root.add_child(area)

func _on_hazard_body_entered(body: Node) -> void:
	if body.has_method("take_hurt"):
		body.call_deferred("take_hurt")

func _draw() -> void:
	draw_rect(deck_bounds.grow(900.0), Color("05070b"))

	for diagonal in range(grid_width + grid_height - 1):
		for x in range(grid_width):
			var y := diagonal - x
			if y < 0 or y >= grid_height:
				continue
			if _walkable[x][y]:
				_draw_floor_cell(Vector2i(x, y))

	# Hazards now use the authored hazard floor PNG. Keep a restrained
	# one-pixel outline so dangerous cells still read clearly during play.
	for cell in _hazard_cells:
		_draw_hazard_outline(cell)

	_draw_spawn_pad()

func _draw_floor_cell(cell: Vector2i) -> void:
	var center := _cell_center(cell)
	var style := int(_floor_styles.get(cell, FloorStyle.BASE))
	var texture := _floor_texture_for_style(style)
	if texture == null:
		texture = FLOOR_BASE_TEXTURE

	var texture_size := texture.get_size()
	draw_texture(texture, (center - texture_size * 0.5).round())

func _floor_texture_for_style(style: int) -> Texture2D:
	match style:
		FloorStyle.GRILL_1:
			return FLOOR_GRILL_TEXTURES[0]
		FloorStyle.GRILL_2:
			return FLOOR_GRILL_TEXTURES[1]
		FloorStyle.GRILL_3:
			return FLOOR_GRILL_TEXTURES[2]
		FloorStyle.LIGHT:
			return FLOOR_LIGHT_TEXTURE
		FloorStyle.HAZARD:
			return FLOOR_HAZARD_TEXTURE
		_:
			return FLOOR_BASE_TEXTURE

func _draw_hazard_outline(cell: Vector2i) -> void:
	var center := _cell_center(cell)
	var points := _diamond_points(center, tile_width - 2.0, tile_height - 1.0)
	draw_polyline(_closed_polygon(points), Color(1.45, 0.56, 0.18, 0.72), 1.0, false)

func _draw_spawn_pad() -> void:
	var center := _cell_center(_start_cell)
	var outer := _diamond_points(center, 34.0, 18.0)
	var inner := _diamond_points(center, 24.0, 12.0)
	draw_colored_polygon(outer, Color("17353c"))
	draw_polyline(_closed_polygon(outer), Color("59d4e8"), 2.0, false)
	draw_polyline(_closed_polygon(inner), Color("2e7f8c"), 1.0, false)
	draw_line(center + Vector2(-7.0, 0.0), center + Vector2(7.0, 0.0), Color("59d4e8"), 1.0, false)
	draw_line(center + Vector2(0.0, -4.0), center + Vector2(0.0, 4.0), Color("59d4e8"), 1.0, false)

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
