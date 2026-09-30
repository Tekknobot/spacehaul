extends Node2D
class_name SpacehaulAbilityParticles

const IsoVfx = preload("res://Scripts/isometric_vfx.gd")

const PIXEL_SIZE := 2.0
const MAX_PARTICLES := 96

var _particles: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _profile := "ion"
var _core := Color.WHITE
var _glow := Color.CYAN
var _follow_target_id := 0
var _follow_emit_time := 0.0
var _follow_elapsed := 0.0
var _emit_interval := 0.02
var _emit_accumulator := 0.0
var _last_target_position := Vector2.ZERO
var _last_motion := Vector2.RIGHT
var _active := true

func _ready() -> void:
	z_as_relative = false
	z_index = 1760
	_rng.seed = int(Time.get_ticks_usec()) ^ get_instance_id()
	set_process(true)

func setup_follow(
	target_node: Node2D,
	core: Color,
	glow: Color,
	profile: String,
	emit_time: float,
	emit_rate: float = 52.0
) -> void:
	_core = core
	_glow = glow if glow.a > 0.0 else Color(core.r * 0.55, core.g * 0.55, core.b * 0.55, core.a)
	_profile = profile
	_follow_target_id = target_node.get_instance_id() if target_node != null else 0
	_follow_emit_time = maxf(0.01, emit_time)
	_emit_interval = 1.0 / maxf(1.0, emit_rate)
	if target_node != null:
		_last_target_position = target_node.global_position.round()
		global_position = Vector2.ZERO

func setup_path(
	points: PackedVector2Array,
	core: Color,
	glow: Color,
	profile: String,
	count: int = 8,
	life: float = 0.22
) -> void:
	_core = core
	_glow = glow if glow.a > 0.0 else Color(
		core.r * 0.55,
		core.g * 0.55,
		core.b * 0.55,
		core.a
	)
	_profile = profile
	global_position = Vector2.ZERO

	if points.size() < 2:
		queue_free()
		return

	var safe_count := clampi(count, 2, 18)
	var segment_lengths: Array[float] = []
	var total_length := 0.0

	for i in range(points.size() - 1):
		var length := points[i].distance_to(points[i + 1])
		segment_lengths.append(length)
		total_length += length

	if total_length <= 0.01:
		queue_free()
		return

	for i in range(safe_count):
		var distance_along := total_length * (
			(float(i) + _rng.randf_range(0.15, 0.85))
			/ float(safe_count)
		)

		var segment_index := 0
		var remaining := distance_along

		for s in range(segment_lengths.size()):
			if remaining <= segment_lengths[s]:
				segment_index = s
				break

			remaining -= segment_lengths[s]

		var a := points[segment_index]
		var b := points[segment_index + 1]

		var segment_length := maxf(
			0.001,
			segment_lengths[segment_index]
		)

		var t := clampf(
			remaining / segment_length,
			0.0,
			1.0
		)

		var tangent := (b - a).normalized()
		var normal := IsoVfx.ground_perpendicular(tangent)
		var position := a.lerp(b, t).round()
		var velocity := _path_velocity(tangent, normal)

		_add_particle(
			position,
			velocity,
			_profile_life(),
			i
		)
		
func setup_burst(
	at: Vector2,
	core: Color,
	glow: Color,
	profile: String,
	count: int = 9,
	speed: float = 28.0,
	life: float = 0.26
) -> void:
	_core = core
	_glow = glow if glow.a > 0.0 else Color(
		core.r * 0.55,
		core.g * 0.55,
		core.b * 0.55,
		core.a
	)
	_profile = profile
	global_position = Vector2.ZERO

	var safe_count := clampi(count, 3, 20)

	for i in range(safe_count):
		var angle := (
			TAU * float(i) / float(safe_count)
			+ _rng.randf_range(-0.22, 0.22)
		)

		var dir := IsoVfx.ground_offset(angle, 1.0)

		var velocity := (
			dir
			* speed
			* _rng.randf_range(0.55, 1.1)
		)

		velocity = _profile_velocity(
			velocity,
			dir
		)

		_add_particle(
			at.round(),
			velocity,
			_profile_life(),
			i
		)
		
func _process(delta: float) -> void:
	if not _active:
		return

	_follow_elapsed += delta
	_update_follow_emission(delta)

	for i in range(_particles.size() - 1, -1, -1):
		var p: Dictionary = _particles[i]
		p["age"] = float(p["age"]) + delta
		if float(p["age"]) >= float(p["life"]):
			_particles.remove_at(i)
			continue

		_apply_profile_motion(p, delta)
		p["position"] = Vector2(p["position"]) + Vector2(p["velocity"]) * delta
		_particles[i] = p

	queue_redraw()

	var still_emitting := _follow_target_id != 0 and _follow_elapsed < _follow_emit_time
	if not still_emitting and _particles.is_empty():
		_active = false
		queue_free()

func _update_follow_emission(delta: float) -> void:
	if _follow_target_id == 0 or _follow_elapsed >= _follow_emit_time:
		return

	var obj := instance_from_id(_follow_target_id)
	var target_node := obj as Node2D
	if target_node == null or not is_instance_valid(target_node) or not target_node.is_inside_tree():
		_follow_target_id = 0
		return

	var current := target_node.global_position.round()
	var motion := current - _last_target_position
	if motion.length_squared() > 0.01:
		_last_motion = motion.normalized()
	_last_target_position = current

	_emit_accumulator += delta
	while _emit_accumulator >= _emit_interval:
		_emit_accumulator -= _emit_interval
		_emit_follow_particle(current)

func _emit_follow_particle(at: Vector2) -> void:
	if _particles.size() >= MAX_PARTICLES:
		return
	var tangent := _last_motion.normalized()
	if tangent.length_squared() <= 0.001:
		tangent = Vector2.RIGHT
	var backward := IsoVfx.ground_vector(tangent, -1.0)
	var velocity := (
		IsoVfx.ground_vector(tangent, -_rng.randf_range(14.0, 34.0))
		+ IsoVfx.ground_perpendicular_offset(tangent, _rng.randf_range(-12.0, 12.0))
	)
	velocity = _profile_velocity(velocity, backward)
	var offset := (
		IsoVfx.ground_perpendicular_offset(tangent, _rng.randf_range(-2.0, 2.0))
		+ IsoVfx.ground_vector(tangent, -_rng.randf_range(0.0, 3.0))
	)
	_add_particle((at + offset).round(), velocity, _profile_life(), _particles.size())

func _add_particle(position: Vector2, velocity: Vector2, life: float, index: int) -> void:
	if _particles.size() >= MAX_PARTICLES:
		return
	_particles.append({
		"position": position.round(),
		"anchor": position.round(),
		"velocity": velocity,
		"age": 0.0,
		"life": maxf(0.05, life),
		"phase": _rng.randf_range(0.0, TAU),
		"index": index,
	})

func _profile_life() -> float:
	match _profile:
		"exhaust":
			return _rng.randf_range(0.9, 1.4)

		"sparks":
			return _rng.randf_range(0.8, 1.1)

		"ember":
			return _rng.randf_range(1.0, 1.5)

		"solar":
			return _rng.randf_range(1.1, 1.6)

		"electric":
			return _rng.randf_range(0.8, 1.2)

		"gravity":
			return _rng.randf_range(1.3, 1.8)

		"phase":
			return _rng.randf_range(1.1, 1.7)

		"prism":
			return _rng.randf_range(0.9, 1.4)

		"bio":
			return _rng.randf_range(0.72, 1.08)

		"venom":
			return _rng.randf_range(0.88, 1.28)

		_:
			return _rng.randf_range(1.0, 1.5)

func _path_velocity(tangent: Vector2, _normal: Vector2) -> Vector2:
	var lateral := _rng.randf_range(-16.0, 16.0)
	var backward := _rng.randf_range(2.0, 14.0)
	var velocity := (
		IsoVfx.ground_perpendicular_offset(tangent, lateral)
		+ IsoVfx.ground_vector(tangent, -backward)
	)
	return _profile_velocity(velocity, IsoVfx.ground_perpendicular(tangent))

func _profile_velocity(base: Vector2, radial_dir: Vector2) -> Vector2:
	match _profile:
		"sparks":
			return base * 1.45 + radial_dir * _rng.randf_range(10.0, 24.0)
		"exhaust":
			return base * 0.90
		"ember":
			return base * 0.75 + Vector2(0.0, -_rng.randf_range(5.0, 13.0))
		"solar":
			return base * 0.85 + radial_dir * _rng.randf_range(5.0, 15.0)
		"electric":
			return base * 0.55
		"gravity":
			return base * 0.45
		"phase":
			return base * 0.35
		"prism":
			return base * 0.50
		"bio":
			return base * 0.68 + Vector2(0.0, -_rng.randf_range(2.0, 7.0))
		"venom":
			return base * 0.54 + radial_dir * _rng.randf_range(2.0, 8.0)
		_:
			return base * 0.60

func _apply_profile_motion(p: Dictionary, delta: float) -> void:
	var position := Vector2(p["position"])
	var velocity := Vector2(p["velocity"])
	var age := float(p["age"])
	var phase := float(p["phase"])

	match _profile:
		"sparks":
			velocity.y += 34.0 * delta
		"ember", "solar":
			velocity.y -= 8.0 * delta
		"electric":
			position += Vector2(
				_rng.randi_range(-1, 1),
				_rng.randi_range(-1, 1)
			)
		"gravity":
			var anchor := Vector2(p["anchor"])
			var to_center := (anchor - position).normalized()
			velocity += IsoVfx.ground_vector(to_center, 22.0 * delta)
			velocity = IsoVfx.rotate_ground_vector(velocity, 1.2 * delta)
		"phase":
			position.x += sin(phase + age * 18.0) * 4.0 * delta
		"prism":
			position += Vector2(
				signf(sin(phase + age * 24.0)),
				0.0
			) * 3.0 * delta
		"bio":
			velocity.y -= 3.0 * delta
			position.x += sin(phase + age * 7.0) * 2.0 * delta
		"venom":
			velocity *= maxf(0.0, 1.0 - 0.28 * delta)
			position += Vector2(
				sin(phase + age * 9.0),
				cos(phase * 0.8 + age * 7.0) * 0.45
			) * 2.4 * delta

	p["position"] = position
	p["velocity"] = velocity

func _particle_color(p: Dictionary) -> Color:
	var age := float(p["age"])
	var life := maxf(float(p["life"]), 0.001)
	var index := int(p["index"])
	var t := clampf(age / life, 0.0, 1.0)
	var fade := 1.0 - t
	var color := _core.lerp(_glow, clampf(t * 0.75, 0.0, 0.75))
	match _profile:
		"electric":
			if int(floor(age * 45.0)) % 2 == 0:
				color = Color.WHITE.lerp(_core, 0.35)
		"phase":
			if int(floor(age * 24.0 + float(index))) % 3 == 0:
				fade *= 0.28
		"prism":
			var shift := fmod(float(index) * 0.17 + t, 1.0)
			color = _core.lerp(Color(0.95, 0.55 + shift * 0.35, 1.0, 1.0), 0.28)
	return Color(color.r, color.g, color.b, color.a * fade)

func _gas_profile_scale() -> float:
	# Keep each cloud only a few world pixels wider than its 2x2 source pixel.
	# Hot / exhaust-style abilities carry a little more body, while sparks and
	# electricity stay tight so the gas never swallows the authored pixel.
	match _profile:
		"sparks", "electric":
			return 0.78
		"exhaust":
			return 1.28
		"ember", "solar":
			return 1.16
		"gravity":
			return 1.22
		"phase", "prism":
			return 0.94
		"bio":
			return 1.18
		"venom":
			return 1.34
		_:
			return 1.0

func _gas_tint(particle_color: Color) -> Color:
	# Ability colors are often HDR (>1.0) for bloom. Hazard gas is intentionally
	# translucent, so normalize that energy before using it as a cloud tint.
	var source := _glow if _glow.a > 0.0 else particle_color
	var peak := maxf(source.r, maxf(source.g, source.b))
	if peak > 1.0:
		source.r /= peak
		source.g /= peak
		source.b /= peak
	return Color(
		clampf(source.r, 0.0, 1.0),
		clampf(source.g, 0.0, 1.0),
		clampf(source.b, 0.0, 1.0),
		1.0
	)

func _even_pixel_size(value: float, minimum: float, maximum: float) -> float:
	return clampf(round(value * 0.5) * 2.0, minimum, maximum)

func _draw_particle_gas(p: Dictionary, pos: Vector2, particle_color: Color) -> void:
	var life := maxf(float(p["life"]), 0.001)
	var age := float(p["age"])
	var t := clampf(age / life, 0.0, 1.0)
	var fade := 1.0 - t
	if fade <= 0.001:
		return

	var scale_factor := _gas_profile_scale()
	var phase := float(p["phase"])
	var pulse := 0.92 + sin(phase + age * 4.0) * 0.08
	var gas_color := _gas_tint(particle_color)

	# Trail the gas by a pixel or two behind the moving particle. This keeps the
	# cloud visually attached to its source while echoing the hazard-tile puffs.
	var velocity := Vector2(p["velocity"])
	var tail := Vector2.ZERO
	if velocity.length_squared() > 0.01:
		tail = -velocity.normalized() * minf(2.0, 0.7 + velocity.length() * 0.018)
	tail = tail.round()

	var outer_size := Vector2(
		_even_pixel_size(PIXEL_SIZE * 2.7 * scale_factor * pulse, 4.0, 8.0),
		_even_pixel_size(PIXEL_SIZE * 2.0 * scale_factor * pulse, 4.0, 6.0)
	)
	var mid_size := Vector2(
		_even_pixel_size(PIXEL_SIZE * 2.0 * scale_factor, 4.0, 6.0),
		_even_pixel_size(PIXEL_SIZE * 1.5 * scale_factor, 2.0, 4.0)
	)
	var core_size := Vector2(
		_even_pixel_size(PIXEL_SIZE * 1.45 * scale_factor, 2.0, 4.0),
		_even_pixel_size(PIXEL_SIZE * 1.15 * scale_factor, 2.0, 4.0)
	)

	var wobble := Vector2(
		round(sin(phase + age * 3.2)),
		round(cos(phase * 0.7 + age * 2.4))
	)
	var outer_center := pos + tail
	var mid_center := pos + (tail * 0.5).round() + wobble
	var core_center := pos - wobble

	# Opacity is in the same restrained range as the hazard tile cloud. Three
	# overlapping hard-edged puffs give the impression of gas without blurring
	# the 2x2 floating pixel at the center.
	draw_rect(
		Rect2((outer_center - outer_size * 0.5).round(), outer_size),
		Color(gas_color.r, gas_color.g, gas_color.b, 0.075 * fade),
		true
	)
	draw_rect(
		Rect2((mid_center - mid_size * 0.5).round(), mid_size),
		Color(gas_color.r, gas_color.g, gas_color.b, 0.11 * fade),
		true
	)
	draw_rect(
		Rect2((core_center - core_size * 0.5).round(), core_size),
		Color(gas_color.r, gas_color.g, gas_color.b, 0.15 * fade),
		true
	)

func _draw() -> void:
	for p in _particles:
		var pos: Vector2 = Vector2(p["position"]).round()
		var color := _particle_color(p)
		_draw_particle_gas(p, pos, color)
		# Strict hard-edged world-pixel square remains the brightest focal point.
		draw_rect(
			Rect2(pos - Vector2.ONE, Vector2(PIXEL_SIZE, PIXEL_SIZE)),
			color,
			true
		)
