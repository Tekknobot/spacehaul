extends RefCounted
class_name SpacehaulEnemyAttackVfx

const AbilityParticleScript = preload("res://Scripts/ability_particle_emitter.gd")
const IsoVfx = preload("res://Scripts/isometric_vfx.gd")

const CORE_PIXEL := 1.0
const BLOOM_PIXEL := 2.0

static func spawn_burst(
	root: Node,
	at: Vector2,
	core: Color,
	glow: Color,
	profile: String = "bio",
	count: int = 8,
	speed: float = 26.0
) -> void:
	if root == null:
		return
	var emitter := AbilityParticleScript.new() as SpacehaulAbilityParticles
	root.add_child(emitter)
	emitter.setup_burst(at.round(), core, glow, profile, count, speed, 0.26)

static func spawn_path(
	root: Node,
	from: Vector2,
	to: Vector2,
	core: Color,
	glow: Color,
	profile: String = "bio",
	count: int = 6
) -> void:
	if root == null or from.distance_squared_to(to) <= 1.0:
		return
	var emitter := AbilityParticleScript.new() as SpacehaulAbilityParticles
	root.add_child(emitter)
	emitter.setup_path(PackedVector2Array([from.round(), to.round()]), core, glow, profile, count, 0.22)

static func spawn_follow(
	root: Node,
	target: Node2D,
	core: Color,
	glow: Color,
	profile: String,
	emit_time: float,
	emit_rate: float = 42.0
) -> void:
	if root == null or target == null:
		return
	var emitter := AbilityParticleScript.new() as SpacehaulAbilityParticles
	root.add_child(emitter)
	emitter.setup_follow(target, core, glow, profile, emit_time, emit_rate)

static func spawn_ring(
	root: Node,
	center: Vector2,
	radius: float,
	core: Color,
	glow: Color,
	life: float = 0.20,
	segments: int = 24,
	expand_scale: float = 1.0
) -> void:
	if root == null:
		return
	var container := Node2D.new()
	container.global_position = center.round()
	container.z_as_relative = false
	container.z_index = clampi(int(round(center.y)) + 58, -3000, 3000)
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	container.material = additive
	root.add_child(container)

	var points := PackedVector2Array()
	var safe_segments := maxi(12, segments)
	for i in range(safe_segments + 1):
		var angle := TAU * float(i) / float(safe_segments)
		points.append(IsoVfx.ground_offset(angle, radius).round())

	var bloom := Line2D.new()
	bloom.width = BLOOM_PIXEL
	bloom.default_color = Color(glow.r, glow.g, glow.b, minf(glow.a, 0.42))
	bloom.antialiased = false
	bloom.points = points
	bloom.use_parent_material = true
	container.add_child(bloom)

	var line := Line2D.new()
	line.width = CORE_PIXEL
	line.default_color = core
	line.antialiased = false
	line.points = points
	line.use_parent_material = true
	container.add_child(line)

	var tween := container.create_tween()
	tween.set_parallel(true)
	if not is_equal_approx(expand_scale, 1.0):
		tween.tween_property(container, "scale", Vector2.ONE * expand_scale, life)
	tween.tween_property(container, "modulate:a", 0.0, life)
	tween.set_parallel(false)
	tween.tween_callback(container.queue_free)

static func spawn_slash(
	root: Node,
	center: Vector2,
	direction: Vector2,
	core: Color,
	glow: Color,
	heavy: bool = false
) -> void:
	if root == null:
		return
	var dir := direction.normalized()
	if dir.length_squared() <= 0.001:
		dir = Vector2.RIGHT
	var normal := Vector2(-dir.y, dir.x)
	var reach := 17.0 if heavy else 12.0
	var width := 9.0 if heavy else 6.0
	var points := PackedVector2Array([
		(center - normal * width * 0.70).round(),
		(center + dir * reach * 0.42 + normal * width).round(),
		(center + dir * reach).round(),
	])
	_spawn_polyline(root, points, core, glow, 0.12 if not heavy else 0.17)
	spawn_path(root, points[0], points[points.size() - 1], core, glow, "sparks", 5 if not heavy else 8)
	spawn_burst(root, center + dir * reach, core, glow, "sparks", 5 if not heavy else 9, 22.0 if not heavy else 34.0)
	if heavy:
		spawn_ring(root, center + dir * 7.0, 9.0, core, glow, 0.18, 20, 1.45)

static func spawn_muzzle(
	root: Node,
	origin: Vector2,
	direction: Vector2,
	core: Color,
	glow: Color,
	profile: String = "bio",
	strong: bool = false
) -> void:
	var dir := direction.normalized()
	if dir.length_squared() <= 0.001:
		dir = Vector2.RIGHT
	var reach := 13.0 if strong else 9.0
	_spawn_polyline(
		root,
		PackedVector2Array([origin.round(), (origin + dir * reach).round()]),
		core,
		glow,
		0.10 if not strong else 0.14
	)
	spawn_burst(root, (origin + dir * reach).round(), core, glow, profile, 5 if not strong else 9, 20.0 if not strong else 30.0)

static func spawn_charge_telegraph(
	root: Node,
	origin: Vector2,
	direction: Vector2,
	length: float,
	core: Color,
	glow: Color
) -> void:
	if root == null:
		return
	var dir := direction.normalized()
	if dir.length_squared() <= 0.001:
		dir = Vector2.RIGHT
	var destination := (origin + dir * length).round()
	_spawn_polyline(root, PackedVector2Array([origin.round(), destination]), core, glow, 0.42)
	spawn_path(root, origin, destination, core, glow, "sparks", clampi(int(round(length / 8.0)), 5, 11))
	spawn_ring(root, origin, 6.0, core, glow, 0.24, 16, 1.55)

static func spawn_shock_warning(
	root: Node,
	center: Vector2,
	radius: float,
	core: Color,
	glow: Color,
	life: float = 0.34
) -> void:
	spawn_ring(root, center, radius * 0.30, core, glow, life, 24, 3.2)
	spawn_burst(root, center, core, glow, "electric", 7, 18.0)

static func spawn_shock_pulse(
	root: Node,
	center: Vector2,
	radius: float,
	core: Color,
	glow: Color
) -> void:
	spawn_ring(root, center, radius * 0.55, core, glow, 0.22, 28, 1.65)
	spawn_ring(root, center, radius, Color(core.r * 0.82, core.g * 0.92, core.b * 1.05, core.a), glow, 0.28, 32, 1.12)
	spawn_burst(root, center, core, glow, "electric", 12, 42.0)
	for i in range(8):
		var angle := TAU * float(i) / 8.0
		var edge := center + IsoVfx.ground_offset(angle, radius)
		_spawn_polyline(root, PackedVector2Array([center.round(), edge.round()]), core, glow, 0.16)

static func spawn_impact(
	root: Node,
	at: Vector2,
	core: Color,
	glow: Color,
	profile: String = "bio",
	strong: bool = false
) -> void:
	spawn_burst(root, at, core, glow, profile, 6 if not strong else 11, 26.0 if not strong else 42.0)
	spawn_ring(root, at, 4.0 if not strong else 7.0, core, glow, 0.14 if not strong else 0.20, 16 if not strong else 20, 1.55)

static func _spawn_polyline(
	root: Node,
	points: PackedVector2Array,
	core: Color,
	glow: Color,
	life: float
) -> void:
	if root == null or points.size() < 2:
		return
	var container := Node2D.new()
	container.z_as_relative = false
	container.z_index = 1730
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	container.material = additive
	root.add_child(container)

	var bloom := Line2D.new()
	bloom.width = BLOOM_PIXEL
	bloom.default_color = Color(glow.r, glow.g, glow.b, minf(glow.a, 0.40))
	bloom.antialiased = false
	bloom.points = points
	bloom.use_parent_material = true
	container.add_child(bloom)

	var line := Line2D.new()
	line.width = CORE_PIXEL
	line.default_color = core
	line.antialiased = false
	line.points = points
	line.use_parent_material = true
	container.add_child(line)

	var tween := container.create_tween()
	tween.tween_property(container, "modulate:a", 0.0, life)
	tween.tween_callback(container.queue_free)
