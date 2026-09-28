extends Node2D
class_name SpacehaulSpecialAbility

const ExplosionScript = preload("res://Scripts/special_explosion.gd")
const ProjectileFxScript = preload("res://Scripts/special_projectile.gd")

var mecha_id := "M1"
var origin := Vector2.ZERO
var target := Vector2.ZERO
var direction := Vector2.RIGHT
var shooter_rid: RID
var alternate := false
var impact_scale := 1.0
var root: Node
var _rng := RandomNumberGenerator.new()

func setup(new_mecha_id: String, start_position: Vector2, target_position: Vector2, source_rid: RID, use_alternate: bool = false, new_impact_scale: float = 1.0) -> void:
	mecha_id = new_mecha_id
	origin = start_position.round()
	target = target_position.round()
	shooter_rid = source_rid
	alternate = use_alternate
	impact_scale = clampf(new_impact_scale, 0.75, 3.0)
	direction = (target - origin).normalized()
	if direction.length_squared() <= 0.001:
		direction = Vector2.RIGHT
	_rng.seed = mecha_id.hash() ^ int(Time.get_ticks_usec())
	root = get_tree().current_scene
	if root == null:
		root = get_parent()
	call_deferred("_run")

func _run() -> void:
	match mecha_id:
		"M1":
			if alternate: await _m1_slam()
			else: await _m1_sunder()
		"M2": await _m2_pounce()
		"M3":
			if alternate: await _m3_laser_sweep()
			else: await _m3_artillery()
		"S1":
			if alternate: await _s1_overcharge()
			else: await _s1_laser_grid()
		"S2": await _s2_quake()
		"S3":
			if alternate: await _s3_web()
			else: await _s3_nova()
		"R1": await _r1_volley()
		"R2": await _r2_cannon()
		"R3":
			if alternate: await _r3_railgun()
			else: await _r3_barrage()
		"R4":
			if alternate: await _r4_storm()
			else: await _r4_malfunction()
		_: await _simple_shot(target, Color(0.75, 2.4, 2.8, 1.0), Color(0.2, 1.0, 1.5, 1.0), 0.22)
	queue_free()

func _sleep(seconds: float) -> void:
	await get_tree().create_timer(maxf(seconds, 0.001)).timeout

func _line(from: Vector2, to: Vector2, color: Color, width: float = 1.0, glow_color: Color = Color.TRANSPARENT, glow_width: float = 0.0) -> Node2D:
	var container := Node2D.new()
	container.z_as_relative = false
	container.z_index = 1700
	root.add_child(container)
	if glow_width > 0.0:
		var glow := Line2D.new()
		glow.width = glow_width
		glow.default_color = glow_color
		glow.antialiased = false
		glow.add_point(from.round())
		glow.add_point(to.round())
		container.add_child(glow)
	var core := Line2D.new()
	core.width = width
	core.default_color = color
	core.antialiased = false
	core.add_point(from.round())
	core.add_point(to.round())
	container.add_child(core)
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	container.material = additive
	return container

func _polyline(points: PackedVector2Array, color: Color, width: float = 1.0, glow_color: Color = Color.TRANSPARENT, glow_width: float = 0.0) -> Node2D:
	var container := Node2D.new()
	container.z_as_relative = false
	container.z_index = 1700
	root.add_child(container)
	if glow_width > 0.0:
		var glow := Line2D.new()
		glow.width = glow_width
		glow.default_color = glow_color
		glow.antialiased = false
		for p in points:
			glow.add_point(p.round())
		container.add_child(glow)
	var core := Line2D.new()
	core.width = width
	core.default_color = color
	core.antialiased = false
	for p in points:
		core.add_point(p.round())
	container.add_child(core)
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	container.material = additive
	return container

func _fade_free(node: Node2D, seconds: float = 0.12) -> void:
	if node == null or not is_instance_valid(node):
		return
	var tw := root.create_tween()
	tw.tween_property(node, "modulate:a", 0.0, seconds)
	tw.tween_callback(node.queue_free)

func _explode(at: Vector2, core: Color = Color(3.0, 1.5, 0.45, 1.0), glow: Color = Color(1.6, 0.45, 0.1, 1.0), radius: float = 18.0, hit_radius: float = 16.0) -> void:
	var fx := ExplosionScript.new() as SpacehaulSpecialExplosion
	root.add_child(fx)
	fx.setup(at, core, glow, radius * impact_scale)
	_damage_radius(at, hit_radius * impact_scale, (at - origin).normalized())

func _damage_radius(at: Vector2, radius: float, push_dir: Vector2) -> void:
	if get_world_2d() == null:
		return
	var shape := CircleShape2D.new()
	shape.radius = radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, at)
	# Layer 1 is deck/mechas; layer 2 is hostile fauna.
	query.collision_mask = 3
	query.collide_with_bodies = true
	query.collide_with_areas = true
	if shooter_rid.is_valid():
		query.exclude = [shooter_rid]
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 16):
		var collider := hit.get("collider") as Object
		if collider != null and collider.has_method("take_projectile_hit"):
			collider.call("take_projectile_hit", push_dir)

func _simple_shot(dest: Vector2, core: Color, glow: Color, travel_time: float = 0.25, explode_radius: float = 16.0) -> void:
	var projectile := ProjectileFxScript.new() as SpacehaulSpecialProjectile
	root.add_child(projectile)
	projectile.setup(origin, core, glow, 1.0)
	var tw := root.create_tween()
	tw.tween_property(projectile, "global_position", dest.round(), travel_time)
	await tw.finished
	if is_instance_valid(projectile): projectile.queue_free()
	_explode(dest, core, glow, explode_radius, explode_radius)

func _arc_shot(dest: Vector2, arc_height: float, travel_time: float, core: Color, glow: Color) -> void:
	var projectile := ProjectileFxScript.new() as SpacehaulSpecialProjectile
	root.add_child(projectile)
	projectile.setup(origin, core, glow, 2.0)
	var trail := Line2D.new()
	trail.width = 1.0
	trail.default_color = Color(core.r, core.g, core.b, 0.72)
	trail.antialiased = false
	trail.z_as_relative = false
	trail.z_index = 1699
	root.add_child(trail)
	var elapsed := 0.0
	while elapsed < travel_time:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		var t := clampf(elapsed / maxf(travel_time, 0.001), 0.0, 1.0)
		var p := origin.lerp(dest, t)
		p.y -= sin(t * PI) * arc_height
		projectile.global_position = p.round()
		trail.add_point(p.round())
		if trail.get_point_count() > 22:
			trail.remove_point(0)
	if is_instance_valid(projectile): projectile.queue_free()
	_fade_free(trail, 0.16)
	_explode(dest, core, glow, 22.0, 22.0)

func _target_clamped(max_range: float) -> Vector2:
	var delta := target - origin
	if delta.length() > max_range:
		return origin + delta.normalized() * max_range
	return target

# M1: SUNDER - sequential explosions in a line behind the clicked target.
func _m1_sunder() -> void:
	var first := _target_clamped(150.0)
	var beam := _line(origin, first, Color(3.0, 1.9, 0.7, 1.0), 1.0, Color(1.6, 0.55, 0.12, 0.35), 2.0)
	_fade_free(beam, 0.18)
	for i in range(5):
		var p := first + direction * float(i) * 20.0
		_explode(p, Color(3.0, 1.6, 0.55, 1.0), Color(1.5, 0.45, 0.1, 1.0), 14.0, 14.0)
		await _sleep(0.08)

# M1 ALT: SLAM - forward half-box ripple, layer by layer.
func _m1_slam() -> void:
	var perp := Vector2(-direction.y, direction.x)
	for layer in range(4):
		var depth := 22.0 + float(layer) * 18.0
		var half_width := maxf(8.0, 42.0 - float(layer) * 9.0)
		for j in range(5):
			var u := lerpf(-half_width, half_width, float(j) / 4.0)
			_explode(origin + direction * depth + perp * u, Color(2.7, 1.35, 0.45, 1.0), Color(1.35, 0.38, 0.1, 1.0), 11.0, 12.0)
		await _sleep(0.05)

# M2: POUNCE - visual lunge line, hit, and knockback impulse.
func _m2_pounce() -> void:
	var dest := _target_clamped(150.0)
	var slash := _line(origin, dest, Color(1.4, 3.0, 3.1, 1.0), 2.0, Color(0.2, 1.1, 1.6, 0.5), 4.0)
	await _sleep(0.10)
	_explode(dest, Color(1.7, 3.0, 3.0, 1.0), Color(0.25, 1.0, 1.4, 1.0), 16.0, 20.0)
	_fade_free(slash, 0.12)

# M3: ARTILLERY STRIKE - source 0.6s high parabolic arc and explosive impact.
func _m3_artillery() -> void:
	await _arc_shot(_target_clamped(240.0), 80.0, 0.6, Color(3.0, 1.15, 0.25, 1.0), Color(1.6, 0.32, 0.08, 1.0))

# M3 ALT: LASER SWEEP - angled multi-strand sky laser with chained impacts.
func _m3_laser_sweep() -> void:
	var base := _target_clamped(260.0)
	var side := -1.0 if direction.x < 0.0 else 1.0
	for i in range(4):
		var hit := base + direction * float(i) * 28.0
		var start := hit + Vector2(140.0 * side, -220.0)
		var strand_a := _line(start, hit, Color(0.3, 2.8, 3.3, 1.0), 1.0, Color(0.2, 1.1, 1.8, 0.45), 4.0)
		var strand_b := _line(start + Vector2(2, 0), hit + Vector2(2, 0), Color(0.8, 3.2, 3.5, 0.9), 1.0)
		await _sleep(0.05)
		_explode(hit, Color(0.6, 2.8, 3.2, 1.0), Color(0.2, 1.0, 1.8, 1.0), 18.0, 18.0)
		_fade_free(strand_a, 0.18)
		_fade_free(strand_b, 0.18)
		await _sleep(0.06)

# S1: LASER GRID - 4x4 intersections, setup delay, then sky strikes and detonations.
func _s1_laser_grid() -> void:
	var center := _target_clamped(190.0)
	var spacing := 22.0
	var lines: Array[Node2D] = []
	for i in range(4):
		var o := (float(i) - 1.5) * spacing
		lines.append(_line(center + Vector2(-34, o), center + Vector2(34, o), Color(2.8, 0.45, 0.35, 0.85), 1.0, Color(1.5, 0.25, 0.2, 0.28), 2.0))
		lines.append(_line(center + Vector2(o, -34), center + Vector2(o, 34), Color(2.8, 0.45, 0.35, 0.85), 1.0, Color(1.5, 0.25, 0.2, 0.28), 2.0))
	await _sleep(0.6)
	await _sleep(0.3)
	for y in range(4):
		for x in range(4):
			var hit := center + Vector2((float(x) - 1.5) * spacing, (float(y) - 1.5) * spacing)
			var sky := _line(hit + Vector2(0, -170), hit, Color(3.0, 0.55, 0.45, 1.0), 1.0, Color(1.6, 0.25, 0.2, 0.45), 3.0)
			_explode(hit, Color(3.0, 0.75, 0.35, 1.0), Color(1.5, 0.25, 0.1, 1.0), 10.0, 10.0)
			_fade_free(sky, 0.10)
			await _sleep(0.02)
	for l in lines:
		_fade_free(l, 0.12)

# S1 ALT: OVERCHARGE - five beams in a 60 degree cone with endpoint explosions.
func _s1_overcharge() -> void:
	await _sleep(0.4)
	var base_angle := direction.angle()
	var beams: Array[Node2D] = []
	for i in range(5):
		var f := (float(i) - 2.0) / 2.0
		var d := Vector2.from_angle(base_angle + deg_to_rad(f * 30.0))
		var end := origin + d * 220.0
		beams.append(_line(origin, end, Color(3.0, 2.65, 0.35, 1.0), 2.0, Color(1.8, 0.9, 0.05, 0.4), 5.0))
		_explode(end, Color(3.0, 2.0, 0.35, 1.0), Color(1.6, 0.7, 0.05, 1.0), 12.0, 12.0)
	await _sleep(0.3)
	for b in beams:
		_fade_free(b, 0.14)

# S2: QUAKE - circular radius three, inner-to-outer ring timing.
func _s2_quake() -> void:
	var center := _target_clamped(210.0)
	var spacing := 18.0
	for ring in range(4):
		if ring == 0:
			_explode(center, Color(1.2, 2.5, 3.2, 1.0), Color(0.2, 0.75, 1.6, 1.0), 14.0, 14.0)
		else:
			var count := ring * 8
			for i in range(count):
				var a := TAU * float(i) / float(count)
				_explode(center + Vector2(cos(a), sin(a)) * spacing * float(ring), Color(1.0, 2.3, 3.0, 1.0), Color(0.2, 0.7, 1.5, 1.0), 9.0, 9.0)
		await _sleep(0.05)

# S3: NOVA - 8-way starburst then an aftershock ring.
func _s3_nova() -> void:
	var center := _target_clamped(200.0)
	_explode(center, Color(2.0, 3.0, 2.0, 1.0), Color(0.35, 1.2, 0.45, 1.0), 16.0, 14.0)
	for step in range(1, 4):
		for i in range(8):
			var a := TAU * float(i) / 8.0
			_explode(center + Vector2(cos(a), sin(a)) * float(step) * 20.0, Color(1.7, 2.9, 1.7, 1.0), Color(0.25, 1.0, 0.35, 1.0), 10.0, 10.0)
		await _sleep(0.05)
	await _sleep(0.12)
	for i in range(24):
		var a2 := TAU * float(i) / 24.0
		_explode(center + Vector2(cos(a2), sin(a2)) * 80.0, Color(1.4, 2.6, 1.5, 1.0), Color(0.2, 0.9, 0.3, 1.0), 8.0, 8.0)

# S3 ALT: WEB - three glowing tethers, pulse, sequential endpoint explosions.
func _s3_web() -> void:
	var center := _target_clamped(220.0)
	var perp := Vector2(-direction.y, direction.x)
	var points := [center, center + perp * 36.0, center - perp * 36.0]
	var webs: Array[Node2D] = []
	for p in points:
		webs.append(_line(origin, p, Color(1.7, 2.5, 1.7, 0.9), 2.0, Color(0.35, 1.2, 0.45, 0.45), 4.0))
	await _sleep(0.35)
	for p in points:
		_explode(p, Color(1.6, 2.8, 1.7, 1.0), Color(0.3, 1.1, 0.4, 1.0), 13.0, 14.0)
		await _sleep(0.08)
	for w in webs:
		_fade_free(w, 0.18)

# R1: NINEFOLD VOLLEY - nine staggered shots into a 3x3 target area.
func _r1_volley() -> void:
	var center := _target_clamped(220.0)
	for y in range(-1, 2):
		for x in range(-1, 2):
			var dest := center + Vector2(float(x) * 18.0, float(y) * 18.0)
			_simple_shot(dest, Color(1.0, 2.7, 3.2, 1.0), Color(0.2, 0.9, 1.5, 1.0), 0.22, 13.0)
			await _sleep(0.04)
	await _sleep(0.28)

# R2: CANNON - three slower, heavy projectiles with larger splash.
func _r2_cannon() -> void:
	var center := _target_clamped(250.0)
	var perp := Vector2(-direction.y, direction.x)
	for i in range(3):
		var dest := center + perp * (float(i) - 1.0) * 22.0
		_simple_shot(dest, Color(3.0, 1.8, 0.55, 1.0), Color(1.5, 0.5, 0.1, 1.0), 0.28, 25.0)
		await _sleep(0.10)
	await _sleep(0.32)

# R3: BARRAGE - eight staggered high-arc missiles around the target zone.
func _r3_barrage() -> void:
	var center := _target_clamped(300.0)
	for i in range(8):
		var a := TAU * float(i) / 8.0
		var dest := center + Vector2(cos(a), sin(a)) * 28.0
		_arc_shot(dest, 120.0, 1.2, Color(2.1, 2.8, 3.2, 1.0), Color(0.25, 0.9, 1.6, 1.0))
		await _sleep(0.15)
	await _sleep(1.2)

# R3 ALT: RAILGUN - charge, thick piercing beam, explosive hit burst.
func _r3_railgun() -> void:
	await _sleep(0.3)
	var end := origin + direction * 360.0
	var beam := _line(origin, end, Color(0.5, 2.3, 3.2, 0.95), 3.0, Color(0.35, 1.3, 2.2, 0.45), 8.0)
	for i in range(3, 10, 2):
		_explode(origin + direction * float(i) * 36.0, Color(0.7, 2.6, 3.3, 1.0), Color(0.25, 1.0, 1.8, 1.0), 12.0, 14.0)
		await _sleep(0.05)
	_fade_free(beam, 0.5)

# R4: MALFUNCTION - warning pause followed by chaotic spiral/ring explosions around self.
func _r4_malfunction() -> void:
	var warning := _line(origin - Vector2(8, 0), origin + Vector2(8, 0), Color(3.0, 0.5, 0.35, 1.0), 1.0, Color(1.5, 0.2, 0.1, 0.35), 3.0)
	await _sleep(0.5)
	_fade_free(warning, 0.08)
	for ring in range(1, 5):
		var count := ring * 6
		var phase := float(ring) * 0.65
		for i in range(count):
			var a := phase + TAU * float(i) / float(count)
			var p := origin + Vector2(cos(a), sin(a)) * float(ring) * 24.0
			_explode(p, Color(3.0, 0.8, 0.4, 1.0), Color(1.6, 0.2, 0.1, 1.0), 12.0, 12.0)
			await _sleep(0.04)
		await _sleep(0.12)

# R4 ALT: STORM - six rapid straight projectiles with explosive impacts.
func _r4_storm() -> void:
	var center := _target_clamped(260.0)
	for i in range(6):
		var jitter := Vector2(_rng.randf_range(-38.0, 38.0), _rng.randf_range(-28.0, 28.0))
		_simple_shot(center + jitter, Color(2.8, 1.3, 3.1, 1.0), Color(1.0, 0.25, 1.6, 1.0), 0.30, 16.0)
		await _sleep(0.08)
	await _sleep(0.35)
