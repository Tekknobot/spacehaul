extends Node2D
class_name PixelAbilityEffect

var mecha_id := "M1"
var direction := Vector2.RIGHT
var duration := 0.34
var elapsed := 0.0
var extent := 28.0
var _seed := 0

func setup(new_mecha_id: String, start_position: Vector2, travel_direction: Vector2) -> void:
	mecha_id = new_mecha_id
	global_position = start_position.round()
	direction = travel_direction.normalized()
	if direction.length_squared() <= 0.001:
		direction = Vector2.RIGHT
	_seed = int(Time.get_ticks_usec()) ^ int(round(start_position.x) * 17.0) ^ int(round(start_position.y) * 31.0)
	_configure_from_mecha()
	z_as_relative = false
	z_index = clampi(int(round(global_position.y)) + 18, -4000, 4000)
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive
	queue_redraw()

func _configure_from_mecha() -> void:
	match mecha_id:
		"M1":
			duration = 0.22
			extent = 32.0
		"M2":
			duration = 0.36
			extent = 34.0
		"M3":
			duration = 0.26
			extent = 26.0
		"R1":
			duration = 0.44
			extent = 26.0
		"R2":
			duration = 0.24
			extent = 42.0
		"R3":
			duration = 0.28
			extent = 38.0
		"R4":
			duration = 0.44
			extent = 22.0
		"S1":
			duration = 0.30
			extent = 34.0
		"S2":
			duration = 0.48
			extent = 22.0
		"S3":
			duration = 0.38
			extent = 26.0
		_:
			duration = 0.28
			extent = 24.0

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= duration:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var progress := clampf(elapsed / maxf(duration, 0.001), 0.0, 1.0)
	match mecha_id:
		"M1":
			_draw_arc_cut(progress)
		"M2":
			_draw_grapple_tentacle(progress)
		"M3":
			_draw_weld_sparks(progress)
		"R1":
			_draw_relay_pulse(progress)
		"R2":
			_draw_trigger_bolt(progress)
		"R3":
			_draw_splitter(progress)
		"R4":
			_draw_inverter_ring(progress)
		"S1":
			_draw_force_ram(progress)
		"S2":
			_draw_gravity_well(progress)
		"S3":
			_draw_phase_shift(progress)
		_:
			_draw_trigger_bolt(progress)

func _dir_normal() -> Vector2:
	return Vector2(-direction.y, direction.x)

func _fract(value: float) -> float:
	return value - floor(value)

func _rand01(index: int) -> float:
	var n := sin(float(_seed + index * 71) * 12.9898) * 43758.5453
	return absf(_fract(n))

func _draw_glow_block(center: Vector2, size: Vector2, core: Color, glow: Color) -> void:
	var pixel_size := Vector2.ONE
	var base := (center - pixel_size * 0.5).round()
	draw_rect(Rect2(base, pixel_size), Color(glow.r, glow.g, glow.b, glow.a * 0.32), true)
	draw_rect(Rect2(base, pixel_size), core, true)

func _draw_pixel_path(points: Array[Vector2], block_size: Vector2, core: Color, glow: Color) -> void:
	if points.size() < 2:
		return
	for segment_index in range(points.size() - 1):
		var a: Vector2 = points[segment_index]
		var b: Vector2 = points[segment_index + 1]
		var delta := b - a
		var steps := maxi(1, int(ceil(delta.length() / maxf(1.0, minf(block_size.x, block_size.y)))))
		for step in range(steps + 1):
			var t := float(step) / float(steps)
			_draw_glow_block(a.lerp(b, t), block_size, core, glow)

func _draw_diamond_ring(center: Vector2, radius: float, block_size: Vector2, core: Color, glow: Color) -> void:
	var points: Array[Vector2] = [
		center + Vector2(0.0, -radius),
		center + Vector2(radius, 0.0),
		center + Vector2(0.0, radius),
		center + Vector2(-radius, 0.0),
		center + Vector2(0.0, -radius)
	]
	_draw_pixel_path(points, block_size, core, glow)

func _draw_arc_cut(progress: float) -> void:
	var normal := _dir_normal()
	var core := Color(2.7, 1.48, 0.55, 1.0)
	var glow := Color(2.3, 0.95, 0.28, 1.0)
	var points: Array[Vector2] = []
	for i in range(6):
		var t := float(i) / 5.0
		var dist := lerpf(4.0, extent, t)
		var spread := sin(t * PI) * 8.0 * (1.0 - progress * 0.5)
		points.append(direction * dist + normal * spread)
	_draw_pixel_path(points, Vector2.ONE, core, glow)
	for spark in range(8):
		var spark_t := _rand01(spark)
		var spark_pos := direction * lerpf(8.0, extent + 6.0, spark_t) + normal * lerpf(-10.0, 10.0, _rand01(50 + spark)) * (1.0 - progress)
		var spark_size := Vector2.ONE
		_draw_glow_block(spark_pos, spark_size, Color(2.8, 2.0, 1.0, 0.95), glow)

func _draw_grapple_tentacle(progress: float) -> void:
	var normal := _dir_normal()
	var core := Color(1.18, 2.8, 2.95, 1.0)
	var glow := Color(0.28, 1.5, 1.85, 1.0)
	var anchor := direction * extent
	var points: Array[Vector2] = [Vector2.ZERO]
	for i in range(1, 9):
		var t := float(i) / 8.0
		var sway := sin(t * TAU * 1.2 + progress * 12.0) * 6.0 * (1.0 - t)
		points.append(direction * lerpf(0.0, extent, t) + normal * sway)
	_draw_pixel_path(points, Vector2.ONE, core, glow)
	_draw_glow_block(anchor + normal * 4.0, Vector2.ONE, Color(1.5, 3.0, 3.0, 1.0), glow)
	_draw_glow_block(anchor - normal * 4.0, Vector2.ONE, Color(1.5, 3.0, 3.0, 1.0), glow)
	_draw_glow_block(anchor + direction * 3.0, Vector2.ONE, Color(2.3, 3.1, 3.2, 1.0), glow)

func _draw_weld_sparks(progress: float) -> void:
	var normal := _dir_normal()
	var core := Color(3.0, 2.1, 0.95, 1.0)
	var glow := Color(2.6, 1.18, 0.35, 1.0)
	var origin := direction * 8.0
	_draw_glow_block(origin, Vector2.ONE, Color(3.2, 2.4, 1.25, 1.0), glow)
	for spark in range(12):
		var spread := lerpf(-0.7, 0.7, _rand01(spark))
		var spark_dir := direction.rotated(spread)
		var dist := lerpf(6.0, extent, progress) * lerpf(0.55, 1.0, _rand01(80 + spark))
		var pos := origin + spark_dir * dist + normal * lerpf(-3.0, 3.0, _rand01(140 + spark))
		_draw_glow_block(pos, Vector2.ONE, core, glow)

func _draw_relay_pulse(progress: float) -> void:
	var core := Color(1.3, 2.9, 3.2, 1.0)
	var glow := Color(0.25, 1.2, 1.75, 1.0)
	_draw_diamond_ring(Vector2.ZERO, 7.0 + progress * 6.0, Vector2.ONE, core, glow)
	_draw_diamond_ring(Vector2.ZERO, 13.0 + progress * 5.0, Vector2.ONE, Color(0.9, 1.9, 2.6, 0.9), glow)
	for i in range(4):
		var pos := direction * (10.0 + float(i) * 6.0) + _dir_normal() * sin(progress * 8.0 + float(i)) * 1.4
		_draw_glow_block(pos, Vector2.ONE, core, glow)

func _draw_trigger_bolt(progress: float) -> void:
	var core := Color(1.65, 3.0, 3.25, 1.0)
	var glow := Color(0.32, 1.45, 1.9, 1.0)
	var end_point := direction * extent
	var segments := 8
	for i in range(segments):
		if i % 2 == 1:
			continue
		var t0 := float(i) / float(segments)
		var t1 := float(i + 1) / float(segments)
		var a := direction * lerpf(4.0, extent, t0)
		var b := direction * lerpf(4.0, extent, t1)
		_draw_pixel_path([a, b], Vector2.ONE, core, glow)
	var normal := _dir_normal()
	_draw_pixel_path([end_point + normal * 5.0, end_point - normal * 5.0], Vector2.ONE, core, glow)
	_draw_pixel_path([end_point - direction * 5.0, end_point + direction * 5.0], Vector2.ONE, core, glow)
	_draw_glow_block(end_point, Vector2.ONE, Color(2.3, 3.2, 3.4, 1.0), glow)

func _draw_splitter(progress: float) -> void:
	var core := Color(1.35, 2.9, 3.3, 1.0)
	var glow := Color(0.38, 1.42, 2.0, 1.0)
	var normal := _dir_normal()
	var split_point := direction * 12.0
	_draw_pixel_path([Vector2.ZERO, split_point], Vector2.ONE, core, glow)
	var branch_a := split_point + direction * (extent * 0.65) + normal * 10.0
	var branch_b := split_point + direction * (extent * 0.65) - normal * 10.0
	_draw_pixel_path([split_point, branch_a], Vector2.ONE, core, glow)
	_draw_pixel_path([split_point, branch_b], Vector2.ONE, core, glow)
	_draw_glow_block(branch_a, Vector2.ONE, Color(2.0, 3.0, 3.35, 1.0), glow)
	_draw_glow_block(branch_b, Vector2.ONE, Color(2.0, 3.0, 3.35, 1.0), glow)
	_draw_glow_block(split_point + normal * sin(progress * 12.0) * 2.0, Vector2.ONE, Color(2.1, 3.1, 3.4, 1.0), glow)

func _draw_inverter_ring(progress: float) -> void:
	var core := Color(2.5, 1.25, 3.2, 1.0)
	var glow := Color(1.25, 0.35, 2.4, 1.0)
	var radius := 12.0 + sin(progress * PI) * 4.0
	_draw_diamond_ring(Vector2.ZERO, radius, Vector2.ONE, core, glow)
	var orbit := [0.0, PI * 0.5, PI, PI * 1.5]
	for index in range(orbit.size()):
		var angle = orbit[index] + progress * TAU * 0.75
		var pos := Vector2(cos(angle), sin(angle)) * radius
		_draw_glow_block(pos, Vector2.ONE, Color(2.8, 1.8, 3.4, 1.0), glow)
	var n := _dir_normal()
	_draw_pixel_path([direction * 5.0 + n * 5.0, direction * 10.0 + n * 5.0, direction * 8.0 + n * 3.0], Vector2.ONE, core, glow)
	_draw_pixel_path([-direction * 5.0 - n * 5.0, -direction * 10.0 - n * 5.0, -direction * 8.0 - n * 3.0], Vector2.ONE, core, glow)

func _draw_force_ram(progress: float) -> void:
	var core := Color(2.6, 2.65, 1.1, 1.0)
	var glow := Color(1.5, 1.4, 0.4, 1.0)
	var normal := _dir_normal()
	for band in range(3):
		var dist := 8.0 + float(band) * 7.0 + progress * 6.0
		var width := 14.0 - float(band) * 3.0
		for slice in range(5):
			var t := (float(slice) / 4.0) - 0.5
			var pos := direction * dist + normal * width * t
			_draw_glow_block(pos, Vector2.ONE, core, glow)

func _draw_gravity_well(progress: float) -> void:
	var core := Color(1.2, 2.3, 3.2, 1.0)
	var glow := Color(0.35, 0.95, 2.1, 1.0)
	var center := direction * (12.0 + progress * 3.0)
	_draw_diamond_ring(center, 14.0 - progress * 8.0, Vector2.ONE, core, glow)
	_draw_diamond_ring(center, 8.0 + sin(progress * PI) * 3.0, Vector2.ONE, Color(2.0, 2.9, 3.4, 0.95), glow)
	_draw_glow_block(center, Vector2.ONE, Color(2.4, 3.0, 3.6, 1.0), glow)
	for i in range(4):
		var offset_angle := progress * TAU + float(i) * PI * 0.5
		var orbit_pos := center + Vector2(cos(offset_angle), sin(offset_angle)) * (10.0 - progress * 5.0)
		_draw_glow_block(orbit_pos, Vector2.ONE, core, glow)

func _draw_phase_shift(progress: float) -> void:
	var core := Color(1.9, 2.5, 3.25, 1.0)
	var glow := Color(0.75, 1.15, 2.25, 1.0)
	var normal := _dir_normal()
	for i in range(6):
		var trail_t := float(i) / 5.0
		var pos := -direction * trail_t * extent * 0.65 + normal * sin(progress * 10.0 + float(i)) * 2.0
		var alpha := (1.0 - trail_t) * (1.0 - progress * 0.5)
		_draw_glow_block(pos, Vector2.ONE, Color(core.r, core.g, core.b, alpha), Color(glow.r, glow.g, glow.b, alpha))
	for x in range(-3, 4):
		for y in range(-2, 3):
			if (x + y) % 2 == 0:
				continue
			var pos := Vector2(float(x) * 4.0, float(y) * 4.0) + direction * 4.0
			_draw_glow_block(pos, Vector2.ONE, Color(2.4, 3.1, 3.5, 0.75), glow)
