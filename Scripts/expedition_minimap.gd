extends Control
class_name ExpeditionMinimap

# Compact room-only map for the expedition prototype. Rooms remain hidden until
# the player physically enters them, which gives the deck a basic fog-of-war
# without requiring a second TileMap or a texture render pass.

var _rooms: Array = []
var _special_rooms: Array = []
var _walkable_lookup: Dictionary = {}
var _revealed_cells: Dictionary = {}
var _discovered: Dictionary = {}
var _player_cell := Vector2i(-9999, -9999)
var _grid_size := Vector2i.ONE
var _boss_active := false
var _extraction_unlocked := false

func set_map_data(rooms: Array, special_rooms: Array, grid_size: Vector2i, walkable_cells: Array) -> void:
	_rooms = rooms.duplicate(true)
	_special_rooms = special_rooms.duplicate(true)
	_grid_size = Vector2i(maxi(1, grid_size.x), maxi(1, grid_size.y))
	_walkable_lookup.clear()
	for cell in walkable_cells:
		_walkable_lookup[cell] = true
	_revealed_cells.clear()
	_discovered.clear()
	queue_redraw()

func discover_room(room_index: int) -> void:
	if room_index < 0:
		return
	if not _discovered.has(room_index):
		_discovered[room_index] = true
		queue_redraw()

func set_player_cell(cell: Vector2i) -> void:
	if cell == _player_cell:
		return
	_player_cell = cell
	queue_redraw()

func reveal_around(cell: Vector2i, radius: int = 2) -> void:
	var changed := false
	var reveal_radius := maxi(0, radius)
	for x in range(cell.x - reveal_radius, cell.x + reveal_radius + 1):
		for y in range(cell.y - reveal_radius, cell.y + reveal_radius + 1):
			var candidate := Vector2i(x, y)
			if not _walkable_lookup.has(candidate) or _revealed_cells.has(candidate):
				continue
			_revealed_cells[candidate] = true
			changed = true
	if changed:
		queue_redraw()

func set_expedition_state(boss_active: bool, extraction_unlocked: bool) -> void:
	if _boss_active == boss_active and _extraction_unlocked == extraction_unlocked:
		return
	_boss_active = boss_active
	_extraction_unlocked = extraction_unlocked
	queue_redraw()

func reset_fog() -> void:
	_discovered.clear()
	_revealed_cells.clear()
	_player_cell = Vector2i(-9999, -9999)
	_boss_active = false
	_extraction_unlocked = false
	queue_redraw()

func _draw() -> void:
	if _rooms.is_empty():
		return

	var padding := 7.0
	var available := Vector2(maxf(1.0, size.x - padding * 2.0), maxf(1.0, size.y - padding * 2.0))
	var scale_value := minf(
		available.x / float(maxi(1, _grid_size.x)),
		available.y / float(maxi(1, _grid_size.y))
	)
	var map_size := Vector2(float(_grid_size.x), float(_grid_size.y)) * scale_value
	var origin := (size - map_size) * 0.5

	# A faint bounding field keeps the minimap legible without turning it into a
	# heavy HUD panel. Only cells actually scanned near the player are revealed.
	draw_rect(Rect2(origin, map_size), Color(0.04, 0.07, 0.085, 0.30), true)

	for cell in _revealed_cells.keys():
		var cell_rect := Rect2(
			origin + Vector2(cell) * scale_value,
			Vector2.ONE * maxf(1.0, scale_value)
		)
		draw_rect(cell_rect, Color(0.18, 0.28, 0.31, 0.78), true)

	for room_index in range(_rooms.size()):
		if not _discovered.has(room_index):
			continue
		var room: Rect2i = _rooms[room_index]
		var room_rect := Rect2(
			origin + Vector2(room.position) * scale_value,
			Vector2(room.size) * scale_value
		)
		var fill := Color(0.30, 0.39, 0.43, 0.72)
		var outline := Color(0.60, 0.77, 0.82, 0.82)
		draw_rect(room_rect, fill, true)
		draw_rect(room_rect, outline, false, 1.0)

	for special in _special_rooms:
		var room_index := int(special.get("room_index", -1))
		if room_index < 0 or not _discovered.has(room_index):
			continue
		var role := String(special.get("role", ""))
		var center_cell: Vector2i = special.get("center_cell", Vector2i.ZERO)
		var marker_pos := origin + (Vector2(center_cell) + Vector2(0.5, 0.5)) * scale_value
		var marker_color := _role_color(role)
		var radius := 2.2
		if role == "HIVE" and _boss_active:
			radius = 3.2
		if role == "EXTRACTION" and _extraction_unlocked:
			marker_color = Color(0.55, 1.0, 0.74, 1.0)
			radius = 3.2
		draw_circle(marker_pos, radius, marker_color)

	if _player_cell.x > -9000:
		var player_pos := origin + (Vector2(_player_cell) + Vector2(0.5, 0.5)) * scale_value
		draw_circle(player_pos, 2.7, Color.WHITE)
		draw_circle(player_pos, 4.0, Color(1.0, 1.0, 1.0, 0.30), false, 1.0)

func _role_color(role: String) -> Color:
	match role:
		"ARMORY":
			return Color(0.35, 0.92, 1.0, 1.0)
		"REPAIR BAY":
			return Color(0.40, 1.0, 0.58, 1.0)
		"DATA CACHE":
			return Color(0.80, 0.56, 1.0, 1.0)
		"REACTOR":
			return Color(1.0, 0.76, 0.30, 1.0)
		"HIVE":
			return Color(1.0, 0.30, 0.46, 1.0)
		"EXTRACTION":
			return Color(0.35, 0.72, 1.0, 1.0)
		_:
			return Color(0.75, 0.82, 0.86, 1.0)
