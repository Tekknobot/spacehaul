extends Node2D
class_name HazardGasEffect

var tile_width: float = 64.0
var tile_height: float = 32.0
var seed_value: int = 0

var _rng := RandomNumberGenerator.new()
var _pixel_texture: Texture2D
var _particles: Array = []
var _built := false

func setup(width: float, height: float, seed: int = 0) -> void:
	tile_width = width
	tile_height = height
	seed_value = seed
	if is_inside_tree():
		_rebuild()

func _ready() -> void:
	if not _built:
		_rebuild()
	set_process(true)

func _rebuild() -> void:
	_built = true
	_clear_children()
	_rng.seed = seed_value if seed_value != 0 else int(Time.get_ticks_usec()) ^ get_instance_id()
	_pixel_texture = _make_pixel_texture()
	_build_cloud()
	_build_particles()

func _build_cloud() -> void:
	z_as_relative = false
	z_index = 3
	var puff_count := 6
	for i in range(puff_count):
		var puff := Polygon2D.new()
		var width_scale := _rng.randf_range(0.18, 0.34)
		var height_scale := _rng.randf_range(0.12, 0.22)
		var rx := tile_width * width_scale
		var ry := tile_height * height_scale
		puff.polygon = _ellipse_points(rx, ry, 12)
		puff.position = Vector2(
			_rng.randf_range(-tile_width * 0.16, tile_width * 0.16),
			_rng.randf_range(-tile_height * 0.08, tile_height * 0.14)
		)
		var alpha := _rng.randf_range(0.10, 0.20)
		puff.color = Color(0.95, _rng.randf_range(0.10, 0.20), _rng.randf_range(0.13, 0.20), alpha)
		add_child(puff)
	
	# a slightly denser center mass keeps the hazard readable even in motion
	for i in range(2):
		var core := Polygon2D.new()
		core.polygon = _ellipse_points(tile_width * _rng.randf_range(0.18, 0.26), tile_height * _rng.randf_range(0.10, 0.16), 12)
		core.position = Vector2(_rng.randf_range(-6.0, 6.0), _rng.randf_range(-2.0, 5.0))
		core.color = Color(1.0, 0.16, 0.18, _rng.randf_range(0.18, 0.24))
		add_child(core)

func _build_particles() -> void:
	_particles.clear()
	var particle_count := 18
	for i in range(particle_count):
		var sprite := Sprite2D.new()
		sprite.texture = _pixel_texture
		sprite.centered = true
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(sprite)
		var particle := {
			"sprite": sprite,
			"pos": Vector2.ZERO,
			"velocity": Vector2.ZERO,
			"lifetime": 1.0,
			"age": 0.0,
			"wobble": 0.0,
			"phase": 0.0,
		}
		_particles.append(particle)
		_respawn_particle(i, true)

func _process(delta: float) -> void:
	for i in range(_particles.size()):
		var particle: Dictionary = _particles[i]
		particle["age"] += delta
		var lifetime: float = particle["lifetime"]
		if particle["age"] >= lifetime:
			_particles[i] = particle
			_respawn_particle(i, false)
			continue
		var pos: Vector2 = particle["pos"]
		var velocity: Vector2 = particle["velocity"]
		var phase: float = particle["phase"]
		var wobble: float = particle["wobble"]
		pos += velocity * delta
		pos.x += sin(phase + particle["age"] * 3.2) * wobble * delta
		particle["pos"] = pos
		var sprite: Sprite2D = particle["sprite"]
		sprite.position = pos
		var t := clampf(particle["age"] / lifetime, 0.0, 1.0)
		var alpha := sin(t * PI)
		sprite.modulate = Color(1.0, 0.26 + (1.0 - t) * 0.06, 0.26, 0.25 + alpha * 0.50)
		_particles[i] = particle

func _respawn_particle(index: int, initial: bool) -> void:
	var particle: Dictionary = _particles[index]
	particle["lifetime"] = _rng.randf_range(0.9, 1.7)
	particle["age"] = _rng.randf_range(0.0, particle["lifetime"]) if initial else 0.0
	particle["pos"] = _random_iso_point()
	particle["velocity"] = Vector2(_rng.randf_range(-4.0, 4.0), -_rng.randf_range(8.0, 15.0))
	particle["wobble"] = _rng.randf_range(2.0, 6.0)
	particle["phase"] = _rng.randf_range(0.0, TAU)
	var sprite: Sprite2D = particle["sprite"]
	sprite.position = particle["pos"]
	sprite.scale = Vector2.ONE
	sprite.rotation = 0.0
	sprite.z_as_relative = false
	sprite.z_index = 4
	sprite.modulate = Color(1.0, 0.28, 0.28, 0.42)
	_particles[index] = particle

func _random_iso_point() -> Vector2:
	var half_w := tile_width * 0.24
	var half_h := tile_height * 0.16
	var x := _rng.randf_range(-half_w, half_w)
	var y_limit := half_h * (1.0 - absf(x) / maxf(half_w, 0.001))
	var y := _rng.randf_range(-y_limit * 0.65, y_limit * 0.90)
	return Vector2(x, y)

func _ellipse_points(rx: float, ry: float, steps: int = 12) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(steps):
		var angle := TAU * float(i) / float(steps)
		points.append(Vector2(cos(angle) * rx, sin(angle) * ry))
	return points

func _make_pixel_texture() -> Texture2D:
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color(1.0, 1.0, 1.0, 1.0))
	return ImageTexture.create_from_image(image)

func _clear_children() -> void:
	for child in get_children():
		child.queue_free()
