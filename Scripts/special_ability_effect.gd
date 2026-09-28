extends Node2D
class_name SpacehaulSpecialAbility

const ExplosionScript = preload("res://Scripts/special_explosion.gd")
const ProjectileFxScript = preload("res://Scripts/special_projectile.gd")

# All generated VFX are authored in world pixels: 1x1 core pixels with a 2x2
# additive bloom. Because the project uses nearest filtering and canvas stretch,
# these pixels scale with the mecha sprite pixels instead of becoming smooth FX.
const CORE_PIXEL := 1.0
const BLOOM_PIXEL := 2.0

var mecha_id := "M1"
var origin := Vector2.ZERO
var owner_center := Vector2.ZERO
var target := Vector2.ZERO
var direction := Vector2.RIGHT
var shooter_rid: RID
var alternate := false
var impact_scale := 1.0
var primary_tier := 0
var secondary_tier := 0
var root: Node
var _rng := RandomNumberGenerator.new()

func setup(
	new_mecha_id: String,
	start_position: Vector2,
	new_owner_center: Vector2,
	target_position: Vector2,
	source_rid: RID,
	use_alternate: bool = false,
	new_impact_scale: float = 1.0,
	new_primary_tier: int = 0,
	new_secondary_tier: int = 0
) -> void:
	mecha_id = new_mecha_id
	origin = start_position.round()
	owner_center = new_owner_center.round()
	target = target_position.round()
	shooter_rid = source_rid
	alternate = use_alternate
	impact_scale = clampf(new_impact_scale, 0.75, 3.0)
	primary_tier = clampi(new_primary_tier, 0, 3)
	secondary_tier = clampi(new_secondary_tier, 0, 3)
	direction = (target - origin).normalized()
	if direction.length_squared() <= 0.001:
		direction = Vector2.RIGHT
	_rng.seed = mecha_id.hash() ^ int(Time.get_ticks_usec()) ^ int(origin.x * 17.0) ^ int(origin.y * 31.0)
	root = get_tree().current_scene
	if root == null:
		root = get_parent()
	call_deferred("_run")

func _run() -> void:
	match mecha_id:
		"M1":
			if alternate:
				await _m1_repulsor_burst()
			else:
				await _m1_plasma_cleaver()
		"M2":
			if alternate:
				await _m2_anchor_bloom()
			else:
				await _m2_vector_harpoons()
		"M3":
			if alternate:
				await _m3_orbital_rain()
			else:
				await _m3_comet_mortar()
		"R1":
			if alternate:
				await _r1_halo_sweep()
			else:
				await _r1_prism_lance()
		"R2":
			if alternate:
				await _r2_countershock()
			else:
				await _r2_breach_cannon()
		"R3":
			if alternate:
				await _r3_flak_dome()
			else:
				await _r3_swarm_rack()
		"R4":
			if alternate:
				await _r4_emp_crown()
			else:
				await _r4_arc_cascade()
		"S1":
			if alternate:
				await _s1_solar_flare()
			else:
				await _s1_photon_rake()
		"S2":
			if alternate:
				await _s2_mass_ejection()
			else:
				await _s2_gravity_well()
		"S3":
			if alternate:
				await _s3_phase_bloom()
			else:
				await _s3_phase_needles()
		_:
			await _straight_shot_from(origin, _target_clamped(190.0), Color(0.75, 2.4, 2.8, 1.0), Color(0.2, 1.0, 1.5, 1.0), 0.18, 14.0)
	queue_free()

func _sleep(seconds: float) -> void:
	await get_tree().create_timer(maxf(seconds, 0.001)).timeout

func _line(from: Vector2, to: Vector2, color: Color, glow_color: Color = Color.TRANSPARENT) -> Node2D:
	var container := Node2D.new()
	container.z_as_relative = false
	container.z_index = 1700
	root.add_child(container)
	if glow_color.a > 0.0:
		var glow := Line2D.new()
		glow.width = BLOOM_PIXEL
		glow.default_color = glow_color
		glow.antialiased = false
		glow.use_parent_material = true
		glow.add_point(from.round())
		glow.add_point(to.round())
		container.add_child(glow)
	var core := Line2D.new()
	core.width = CORE_PIXEL
	core.default_color = color
	core.antialiased = false
	core.use_parent_material = true
	core.add_point(from.round())
	core.add_point(to.round())
	container.add_child(core)
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	container.material = additive
	return container

func _polyline(points: PackedVector2Array, color: Color, glow_color: Color = Color.TRANSPARENT) -> Node2D:
	var container := Node2D.new()
	container.z_as_relative = false
	container.z_index = 1700
	root.add_child(container)
	if glow_color.a > 0.0:
		var glow := Line2D.new()
		glow.width = BLOOM_PIXEL
		glow.default_color = glow_color
		glow.antialiased = false
		glow.use_parent_material = true
		for point in points:
			glow.add_point(point.round())
		container.add_child(glow)
	var core := Line2D.new()
	core.width = CORE_PIXEL
	core.default_color = color
	core.antialiased = false
	core.use_parent_material = true
	for point in points:
		core.add_point(point.round())
	container.add_child(core)
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	container.material = additive
	return container

func _fade_free(node: Node2D, seconds: float = 0.12) -> void:
	if node == null or not is_instance_valid(node):
		return
	var tween := root.create_tween()
	tween.tween_property(node, "modulate:a", 0.0, seconds)
	tween.tween_callback(node.queue_free)

func _pulse_ring(center: Vector2, radius: float, core: Color, glow: Color, life: float = 0.16, point_count: int = 32, phase: float = 0.0) -> Node2D:
	var points := PackedVector2Array()
	var count := maxi(8, point_count)
	for i in range(count + 1):
		var angle := phase + TAU * float(i) / float(count)
		points.append((center + Vector2(cos(angle), sin(angle)) * radius).round())
	var ring := _polyline(points, core, glow)
	_fade_free(ring, life)
	return ring

func _spark_pixels(at: Vector2, core: Color, glow: Color, count: int, travel_radius: float, life: float = 0.22) -> void:
	for i in range(maxi(0, count)):
		var pixel := ProjectileFxScript.new() as SpacehaulSpecialProjectile
		root.add_child(pixel)
		pixel.setup(at, core, glow, 1.0)
		var angle := TAU * float(i) / float(maxi(1, count)) + _rng.randf_range(-0.16, 0.16)
		var distance := travel_radius * _rng.randf_range(0.55, 1.0)
		var destination := (at + Vector2(cos(angle), sin(angle)) * distance).round()
		var tween := root.create_tween()
		tween.set_parallel(true)
		tween.tween_property(pixel, "global_position", destination, life)
		tween.tween_property(pixel, "modulate:a", 0.0, life)
		tween.chain().tween_callback(pixel.queue_free)

func _dotted_trace(from: Vector2, to: Vector2, core: Color, glow: Color, spacing: float = 8.0, life: float = 0.14) -> void:
	var delta := to - from
	var steps := maxi(1, int(ceil(delta.length() / maxf(2.0, spacing))))
	for i in range(steps + 1):
		if i % 2 == 1:
			continue
		var p := from.lerp(to, float(i) / float(steps)).round()
		var pixel := ProjectileFxScript.new() as SpacehaulSpecialProjectile
		root.add_child(pixel)
		pixel.setup(p, core, glow, 1.0)
		var tween := root.create_tween()
		tween.tween_property(pixel, "modulate:a", 0.0, life)
		tween.tween_callback(pixel.queue_free)

func _explode(at: Vector2, core: Color = Color(3.0, 1.5, 0.45, 1.0), glow: Color = Color(1.6, 0.45, 0.1, 1.0), radius: float = 18.0, hit_radius: float = 16.0) -> void:
	var fx := ExplosionScript.new() as SpacehaulSpecialExplosion
	root.add_child(fx)
	fx.setup(at.round(), core, glow, radius * impact_scale)
	_damage_radius(at, hit_radius * impact_scale, (at - owner_center).normalized())

func _damage_radius(at: Vector2, radius: float, push_dir: Vector2) -> void:
	if get_world_2d() == null:
		return
	var shape := CircleShape2D.new()
	shape.radius = maxf(1.0, radius)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, at)
	query.collision_mask = 2
	query.collide_with_bodies = true
	query.collide_with_areas = true
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 96):
		var collider := hit.get("collider") as Object
		if collider != null and collider.has_method("take_projectile_hit"):
			collider.call("take_projectile_hit", push_dir)

func _radial_hit(at: Vector2, radius: float, outward: bool = true) -> void:
	if get_world_2d() == null:
		return
	var shape := CircleShape2D.new()
	shape.radius = maxf(1.0, radius)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, at)
	query.collision_mask = 2
	query.collide_with_bodies = true
	query.collide_with_areas = true
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 96):
		var collider := hit.get("collider") as Object
		if collider == null or not collider.has_method("take_projectile_hit"):
			continue
		var body := collider as Node2D
		var push := Vector2.RIGHT
		if body != null:
			push = body.global_position - at
			if not outward:
				push = -push
			if push.length_squared() <= 0.001:
				push = direction
		collider.call("take_projectile_hit", push.normalized())

func _damage_line(from: Vector2, to: Vector2, radius: float = 5.0) -> void:
	if get_world_2d() == null:
		return
	var delta := to - from
	var steps := maxi(1, int(ceil(delta.length() / 10.0)))
	var hit_ids := {}
	for i in range(steps + 1):
		var p := from.lerp(to, float(i) / float(steps))
		var shape := CircleShape2D.new()
		shape.radius = maxf(1.0, radius)
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = shape
		query.transform = Transform2D(0.0, p)
		query.collision_mask = 2
		query.collide_with_bodies = true
		query.collide_with_areas = true
		for hit in get_world_2d().direct_space_state.intersect_shape(query, 32):
			var collider := hit.get("collider") as Object
			if collider == null or not collider.has_method("take_projectile_hit"):
				continue
			var id := collider.get_instance_id()
			if hit_ids.has(id):
				continue
			hit_ids[id] = true
			collider.call("take_projectile_hit", delta.normalized())

func _straight_shot_from(start: Vector2, dest: Vector2, core: Color, glow: Color, travel_time: float = 0.18, explode_radius: float = 14.0) -> void:
	var projectile := ProjectileFxScript.new() as SpacehaulSpecialProjectile
	root.add_child(projectile)
	projectile.setup(start.round(), core, glow, 1.0)
	var tracer := _line(start, dest, Color(core.r, core.g, core.b, 0.72), Color(glow.r, glow.g, glow.b, 0.22))
	_fade_free(tracer, minf(0.12, travel_time))
	var tween := root.create_tween()
	tween.tween_property(projectile, "global_position", dest.round(), travel_time)
	await tween.finished
	if is_instance_valid(projectile):
		projectile.queue_free()
	_explode(dest, core, glow, explode_radius, explode_radius)

func _arc_shot_from(start: Vector2, dest: Vector2, arc_height: float, travel_time: float, core: Color, glow: Color, explode_radius: float = 18.0) -> void:
	var projectile := ProjectileFxScript.new() as SpacehaulSpecialProjectile
	root.add_child(projectile)
	projectile.setup(start.round(), core, glow, 1.0)
	var trail_container := Node2D.new()
	trail_container.z_as_relative = false
	trail_container.z_index = 1699
	root.add_child(trail_container)
	var trail_glow := Line2D.new()
	trail_glow.width = BLOOM_PIXEL
	trail_glow.default_color = Color(glow.r, glow.g, glow.b, 0.24)
	trail_glow.antialiased = false
	trail_glow.use_parent_material = true
	trail_container.add_child(trail_glow)
	var trail_core := Line2D.new()
	trail_core.width = CORE_PIXEL
	trail_core.default_color = Color(core.r, core.g, core.b, 0.78)
	trail_core.antialiased = false
	trail_core.use_parent_material = true
	trail_container.add_child(trail_core)
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	trail_container.material = additive
	var elapsed := 0.0
	while elapsed < travel_time:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		var t := clampf(elapsed / maxf(travel_time, 0.001), 0.0, 1.0)
		var p := start.lerp(dest, t)
		p.y -= sin(t * PI) * arc_height
		p = p.round()
		projectile.global_position = p
		trail_glow.add_point(p)
		trail_core.add_point(p)
		if trail_core.get_point_count() > 24:
			trail_core.remove_point(0)
			trail_glow.remove_point(0)
	if is_instance_valid(projectile):
		projectile.queue_free()
	_fade_free(trail_container, 0.14)
	_explode(dest, core, glow, explode_radius, explode_radius)

func _target_clamped(max_range: float) -> Vector2:
	var delta := target - origin
	if delta.length() > max_range:
		return (origin + delta.normalized() * max_range).round()
	return target.round()

func _arc_points(center_point: Vector2, aim_angle: float, radius: float, half_angle: float, count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	var safe_count := maxi(3, count)
	for i in range(safe_count):
		var t := float(i) / float(safe_count - 1)
		var angle := aim_angle + lerpf(-half_angle, half_angle, t)
		points.append((center_point + Vector2(cos(angle), sin(angle)) * radius).round())
	return points

func _jagged_segment_points(from: Vector2, to: Vector2, jitter: float = 4.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	var delta := to - from
	var normal := Vector2(-delta.y, delta.x).normalized()
	points.append(from.round())
	for i in range(1, 4):
		var t := float(i) / 4.0
		var offset := normal * _rng.randf_range(-jitter, jitter)
		points.append((from.lerp(to, t) + offset).round())
	points.append(to.round())
	return points

func _chain_enemy_points(max_hops: int, first_range: float, jump_range: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	points.append(origin.round())
	var used: Array[Node] = []
	var cursor := origin
	for hop in range(max_hops):
		var best: Node2D = null
		var best_score := INF
		for node in get_tree().get_nodes_in_group("enemies"):
			if node == null or not is_instance_valid(node) or used.has(node):
				continue
			var body := node as Node2D
			if body == null:
				continue
			var range_limit := first_range if hop == 0 else jump_range
			var distance := cursor.distance_to(body.global_position)
			if distance > range_limit:
				continue
			var score := distance
			if hop == 0:
				score += body.global_position.distance_to(target) * 0.45
			if score < best_score:
				best_score = score
				best = body
		if best == null:
			break
		used.append(best)
		cursor = best.global_position.round()
		points.append(cursor)
	return points

# M1 PRIMARY: PLASMA CLEAVER
# A short, hard-edged crescent that chews through the crowd in front of M1.
func _m1_plasma_cleaver() -> void:
	var tier := primary_tier
	var radius := 66.0 + float(tier) * 8.0
	var half_angle := deg_to_rad(36.0 + float(tier) * 6.0)
	var teeth := 7 + tier * 2
	var arc := _arc_points(owner_center, direction.angle(), radius, half_angle, teeth)
	var blade := _polyline(arc, Color(3.0, 1.45, 0.55, 1.0), Color(1.5, 0.42, 0.10, 0.30))
	for i in range(arc.size()):
		_damage_radius(arc[i], 9.0 + float(tier), direction)
		if i == 0 or i == int(arc.size() / 2) or i == arc.size() - 1:
			_explode(arc[i], Color(3.0, 1.5, 0.55, 1.0), Color(1.5, 0.40, 0.08, 1.0), 10.0 + float(tier), 9.0 + float(tier))
	_fade_free(blade, 0.16)
	_spark_pixels(owner_center + direction * radius * 0.65, Color(3.0, 1.8, 0.75, 1.0), Color(1.5, 0.45, 0.1, 1.0), 5 + tier * 2, 18.0)
	if tier >= 2:
		await _sleep(0.07)
		var outer := _arc_points(owner_center, direction.angle(), radius + 15.0, half_angle * 0.88, teeth)
		var second := _polyline(outer, Color(2.8, 1.0, 0.35, 1.0), Color(1.3, 0.30, 0.08, 0.26))
		for p in outer:
			_damage_radius(p, 8.0 + float(tier), direction)
		_fade_free(second, 0.14)
	if tier >= 3:
		await _sleep(0.06)
		var return_arc := _arc_points(owner_center, direction.angle(), radius * 0.78, half_angle * 1.12, teeth + 2)
		var backcut := _polyline(return_arc, Color(3.1, 2.0, 0.8, 1.0), Color(1.5, 0.5, 0.1, 0.25))
		for p in return_arc:
			_damage_radius(p, 8.0, -direction)
		_fade_free(backcut, 0.12)

# M1 SECONDARY: REPULSOR BURST
func _m1_repulsor_burst() -> void:
	var tier := secondary_tier
	var waves := 1 + (1 if tier >= 2 else 0) + (1 if tier >= 3 else 0)
	var spokes := 12 + tier * 4
	for wave in range(waves):
		var radius := 64.0 + float(tier) * 10.0 + float(wave) * 22.0
		_pulse_ring(owner_center, radius, Color(1.2, 2.9, 3.2, 1.0), Color(0.2, 1.0, 1.6, 0.26), 0.20, spokes)
		_radial_hit(owner_center, radius, true)
		for i in range(spokes):
			if i % 2 != 0:
				continue
			var angle := TAU * float(i) / float(spokes)
			var end := owner_center + Vector2(cos(angle), sin(angle)) * radius
			var ray := _line(owner_center, end, Color(1.5, 3.1, 3.3, 0.9), Color(0.25, 1.0, 1.5, 0.18))
			_fade_free(ray, 0.10)
			_explode(end, Color(1.8, 3.0, 3.2, 1.0), Color(0.25, 1.0, 1.5, 1.0), 9.0, 10.0)
		await _sleep(0.08)

# M2 PRIMARY: VECTOR HARPOONS
func _m2_vector_harpoons() -> void:
	var tier := primary_tier
	var bolt_count := 3 + tier * 2
	var total_spread := deg_to_rad(24.0 + float(tier) * 4.0)
	var reach := 158.0 + float(tier) * 12.0
	for i in range(bolt_count):
		var f := 0.0 if bolt_count == 1 else (float(i) / float(bolt_count - 1) - 0.5)
		var bolt_dir := direction.rotated(f * total_spread)
		var end := (origin + bolt_dir * reach).round()
		var tether := _line(origin, end, Color(0.9, 2.8, 3.2, 1.0), Color(0.15, 0.95, 1.45, 0.28))
		_damage_line(origin, end, 4.0 + float(tier))
		_explode(end, Color(1.2, 2.9, 3.2, 1.0), Color(0.2, 0.95, 1.4, 1.0), 9.0 + float(tier), 10.0 + float(tier))
		_fade_free(tether, 0.16)
	await _sleep(0.04)

# M2 SECONDARY: ANCHOR BLOOM
func _m2_anchor_bloom() -> void:
	var tier := secondary_tier
	var radius := 72.0 + float(tier) * 14.0
	var collapse_count := 3 + (1 if tier >= 2 else 0)
	for i in range(collapse_count):
		var r := lerpf(radius, 24.0, float(i) / float(maxi(1, collapse_count - 1)))
		_pulse_ring(owner_center, r, Color(0.8, 2.7, 3.2, 1.0), Color(0.15, 0.8, 1.4, 0.25), 0.12, 28, float(i) * 0.12)
		await _sleep(0.045)
	_radial_hit(owner_center, radius, false)
	await _sleep(0.08)
	_explode(owner_center, Color(1.3, 3.0, 3.25, 1.0), Color(0.2, 1.0, 1.5, 1.0), 22.0 + float(tier) * 3.0, 26.0 + float(tier) * 5.0)
	_radial_hit(owner_center, radius * 0.78, true)
	if tier >= 3:
		_pulse_ring(owner_center, radius + 18.0, Color(1.7, 3.1, 3.3, 1.0), Color(0.25, 1.0, 1.5, 0.24), 0.18, 36)
		_radial_hit(owner_center, radius + 18.0, true)

# M3 PRIMARY: COMET MORTAR
func _m3_comet_mortar() -> void:
	var tier := primary_tier
	var dest := _target_clamped(245.0 + float(tier) * 12.0)
	await _arc_shot_from(origin, dest, 78.0 + float(tier) * 12.0, 0.42, Color(3.0, 1.15, 0.28, 1.0), Color(1.5, 0.32, 0.08, 1.0), 19.0 + float(tier) * 2.0)
	var shards := 4 + tier * 2
	var shard_radius := 32.0 + float(tier) * 5.0
	for i in range(shards):
		var angle := TAU * float(i) / float(shards)
		var end := (dest + Vector2(cos(angle), sin(angle)) * shard_radius).round()
		var shrapnel := _line(dest, end, Color(3.0, 1.8, 0.65, 0.95), Color(1.5, 0.4, 0.08, 0.22))
		_damage_line(dest, end, 3.0)
		_explode(end, Color(3.0, 1.45, 0.4, 1.0), Color(1.5, 0.35, 0.08, 1.0), 8.0, 8.0)
		_fade_free(shrapnel, 0.12)
	if tier >= 3:
		await _sleep(0.10)
		_explode(dest, Color(3.2, 2.0, 0.8, 1.0), Color(1.7, 0.45, 0.08, 1.0), 24.0, 24.0)

# M3 SECONDARY: ORBITAL RAIN
func _m3_orbital_rain() -> void:
	var tier := secondary_tier
	var strikes := 8 + tier * 4
	var radius := 72.0 + float(tier) * 10.0
	_explode(owner_center, Color(2.8, 1.2, 0.3, 1.0), Color(1.4, 0.3, 0.08, 1.0), 13.0, 13.0)
	for i in range(strikes):
		var angle := TAU * float(i) / float(strikes) + float(tier) * 0.13
		var hit := (owner_center + Vector2(cos(angle), sin(angle)) * radius).round()
		var sky_start := hit + Vector2(float((i % 3) - 1) * 18.0, -140.0)
		var beam := _line(sky_start, hit, Color(3.0, 1.35, 0.35, 1.0), Color(1.5, 0.35, 0.08, 0.24))
		_explode(hit, Color(3.0, 1.2, 0.3, 1.0), Color(1.5, 0.3, 0.08, 1.0), 11.0 + float(tier), 12.0 + float(tier))
		_fade_free(beam, 0.11)
		await _sleep(0.025)

# R1 PRIMARY: PRISM LANCE
func _r1_prism_lance() -> void:
	var tier := primary_tier
	var lance_count := 3 + tier
	var reach := 184.0 + float(tier) * 14.0
	var perp := Vector2(-direction.y, direction.x)
	for i in range(lance_count):
		var offset := (float(i) - float(lance_count - 1) * 0.5) * 5.0
		var start := origin + perp * offset
		var end := (start + direction * reach).round()
		var beam := _line(start, end, Color(0.85, 2.8, 3.25, 1.0), Color(0.18, 0.9, 1.5, 0.25))
		_damage_line(start, end, 3.5 + float(tier) * 0.5)
		_explode(end, Color(1.1, 2.9, 3.3, 1.0), Color(0.2, 0.9, 1.5, 1.0), 8.0 + float(tier), 8.0 + float(tier))
		_fade_free(beam, 0.13)
		if tier >= 3:
			var cross := _line(end - perp * 9.0, end + perp * 9.0, Color(1.8, 3.1, 3.4, 0.9), Color(0.2, 0.9, 1.5, 0.20))
			_damage_line(end - perp * 9.0, end + perp * 9.0, 4.0)
			_fade_free(cross, 0.10)

# R1 SECONDARY: HALO SWEEP
func _r1_halo_sweep() -> void:
	var tier := secondary_tier
	var phases := 1 + (1 if tier >= 2 else 0)
	var spokes := 8 + tier * 4
	var radius := 76.0 + float(tier) * 10.0
	for phase_index in range(phases):
		var phase := float(phase_index) * PI / float(maxi(1, spokes))
		_pulse_ring(owner_center, radius, Color(0.9, 2.8, 3.25, 1.0), Color(0.18, 0.9, 1.5, 0.22), 0.18, spokes, phase)
		for i in range(spokes):
			var angle := phase + TAU * float(i) / float(spokes)
			var end := (owner_center + Vector2(cos(angle), sin(angle)) * radius).round()
			var beam := _line(owner_center, end, Color(1.2, 3.0, 3.3, 0.9), Color(0.2, 0.9, 1.5, 0.16))
			_damage_line(owner_center, end, 3.0)
			if i % 2 == 0:
				_explode(end, Color(1.1, 2.9, 3.3, 1.0), Color(0.2, 0.9, 1.5, 1.0), 8.0, 8.0)
			_fade_free(beam, 0.10)
		await _sleep(0.07)

# R2 PRIMARY: BREACH CANNON
func _r2_breach_cannon() -> void:
	var tier := primary_tier
	var end := _target_clamped(250.0 + float(tier) * 18.0)
	var telegraph := _line(origin, end, Color(2.8, 1.2, 0.35, 0.55), Color(1.3, 0.35, 0.08, 0.14))
	await _sleep(0.06)
	_fade_free(telegraph, 0.05)
	var slug := _line(origin, end, Color(3.2, 2.2, 0.85, 1.0), Color(1.6, 0.5, 0.1, 0.32))
	_damage_line(origin, end, 6.0 + float(tier))
	_explode(end, Color(3.2, 1.65, 0.45, 1.0), Color(1.6, 0.42, 0.08, 1.0), 23.0 + float(tier) * 3.0, 22.0 + float(tier) * 3.0)
	_fade_free(slug, 0.18)
	var splinters := 4 + tier * 2
	for i in range(splinters):
		var angle := direction.angle() + PI + lerpf(-0.75, 0.75, float(i) / float(maxi(1, splinters - 1)))
		var splinter_end := end + Vector2(cos(angle), sin(angle)) * (28.0 + float(tier) * 4.0)
		var splinter := _line(end, splinter_end, Color(3.0, 1.55, 0.45, 0.9), Color(1.5, 0.4, 0.08, 0.18))
		_damage_line(end, splinter_end, 3.0)
		_fade_free(splinter, 0.11)

# R2 SECONDARY: COUNTERSHOCK
func _r2_countershock() -> void:
	var tier := secondary_tier
	var blasts := 4 + tier * 2
	var radius := 82.0 + float(tier) * 11.0
	_radial_hit(owner_center, 42.0 + float(tier) * 6.0, true)
	for i in range(blasts):
		var angle := TAU * float(i) / float(blasts)
		var end := (owner_center + Vector2(cos(angle), sin(angle)) * radius).round()
		var beam := _line(owner_center, end, Color(3.0, 1.75, 0.55, 1.0), Color(1.5, 0.45, 0.08, 0.24))
		_damage_line(owner_center, end, 5.0)
		_explode(end, Color(3.0, 1.45, 0.4, 1.0), Color(1.5, 0.35, 0.08, 1.0), 13.0 + float(tier), 14.0 + float(tier))
		_fade_free(beam, 0.15)
	await _sleep(0.05)

# R3 PRIMARY: SWARM RACK
func _r3_swarm_rack() -> void:
	var tier := primary_tier
	var missile_count := 3 + tier
	var center_point := _target_clamped(275.0 + float(tier) * 12.0)
	for i in range(missile_count):
		var angle := TAU * float(i) / float(missile_count) + _rng.randf_range(-0.22, 0.22)
		var dest := center_point + Vector2(cos(angle), sin(angle)) * (18.0 + float(tier) * 4.0)
		await _arc_shot_from(origin, dest, 58.0 + float(i % 3) * 11.0, 0.24 + float(i % 2) * 0.04, Color(1.55, 2.75, 3.25, 1.0), Color(0.2, 0.8, 1.5, 1.0), 12.0 + float(tier))
		await _sleep(0.025)

# R3 SECONDARY: FLAK DOME
func _r3_flak_dome() -> void:
	var tier := secondary_tier
	var missile_count := 8 + tier * 2
	var radius := 72.0 + float(tier) * 10.0
	for i in range(missile_count):
		var angle := TAU * float(i) / float(missile_count)
		var dest := owner_center + Vector2(cos(angle), sin(angle)) * radius
		await _arc_shot_from(owner_center, dest, 44.0 + float(tier) * 7.0, 0.16, Color(1.6, 2.85, 3.3, 1.0), Color(0.2, 0.85, 1.55, 1.0), 10.0 + float(tier))
		await _sleep(0.012)
	_pulse_ring(owner_center, radius, Color(1.3, 2.8, 3.25, 1.0), Color(0.2, 0.8, 1.5, 0.22), 0.18, missile_count * 2)

# R4 PRIMARY: ARC CASCADE
func _r4_arc_cascade() -> void:
	var tier := primary_tier
	var hop_count := 3 + tier * 2
	var chain := _chain_enemy_points(hop_count, 220.0 + float(tier) * 12.0, 112.0 + float(tier) * 8.0)
	if chain.size() <= 1:
		chain.append(_target_clamped(210.0 + float(tier) * 15.0))
	var lightning := PackedVector2Array()
	for segment_index in range(chain.size() - 1):
		var jagged := _jagged_segment_points(chain[segment_index], chain[segment_index + 1], 4.0 + float(tier))
		for j in range(jagged.size()):
			if segment_index > 0 and j == 0:
				continue
			lightning.append(jagged[j])
		_damage_line(chain[segment_index], chain[segment_index + 1], 5.0)
		_explode(chain[segment_index + 1], Color(2.45, 1.25, 3.2, 1.0), Color(1.0, 0.25, 1.7, 1.0), 10.0 + float(tier), 10.0 + float(tier))
	var arc := _polyline(lightning, Color(2.7, 1.7, 3.4, 1.0), Color(1.0, 0.25, 1.7, 0.32))
	_fade_free(arc, 0.18)
	_spark_pixels(chain[chain.size() - 1], Color(2.8, 1.8, 3.5, 1.0), Color(1.0, 0.25, 1.7, 1.0), 6 + tier * 2, 22.0)

# R4 SECONDARY: EMP CROWN
func _r4_emp_crown() -> void:
	var tier := secondary_tier
	var waves := 2 + tier
	for wave in range(waves):
		var radius := 38.0 + float(wave) * (20.0 + float(tier) * 2.0)
		var point_count := 18 + tier * 4
		var ring_points := PackedVector2Array()
		for i in range(point_count + 1):
			var angle := TAU * float(i) / float(point_count)
			var jitter := _rng.randf_range(-3.0, 3.0)
			ring_points.append((owner_center + Vector2(cos(angle), sin(angle)) * (radius + jitter)).round())
		var ring := _polyline(ring_points, Color(2.6, 1.5, 3.35, 1.0), Color(1.0, 0.25, 1.7, 0.28))
		_radial_hit(owner_center, radius + 8.0, true)
		for i in range(0, point_count, 4):
			_explode(ring_points[i], Color(2.5, 1.3, 3.2, 1.0), Color(1.0, 0.25, 1.7, 1.0), 8.0, 8.0)
		_fade_free(ring, 0.16)
		await _sleep(0.07)

# S1 PRIMARY: PHOTON RAKE
func _s1_photon_rake() -> void:
	var tier := primary_tier
	var beam_count := 3 + tier * 2
	var reach := 206.0 + float(tier) * 14.0
	var perp := Vector2(-direction.y, direction.x)
	for i in range(beam_count):
		var offset := (float(i) - float(beam_count - 1) * 0.5) * 6.0
		var start := origin + perp * offset
		var end := (start + direction * reach).round()
		var beam := _line(start, end, Color(3.0, 0.72, 0.52, 1.0), Color(1.5, 0.22, 0.12, 0.28))
		_damage_line(start, end, 4.0)
		_explode(end, Color(3.0, 0.82, 0.42, 1.0), Color(1.5, 0.22, 0.10, 1.0), 9.0 + float(tier), 9.0 + float(tier))
		_fade_free(beam, 0.16)

# S1 SECONDARY: SOLAR FLARE
func _s1_solar_flare() -> void:
	var tier := secondary_tier
	var beam_count := 8 + tier * 4
	var radius := 78.0 + float(tier) * 11.0
	_explode(owner_center, Color(3.2, 2.15, 0.65, 1.0), Color(1.6, 0.55, 0.08, 1.0), 16.0, 18.0)
	for i in range(beam_count):
		var angle := TAU * float(i) / float(beam_count)
		var end := (owner_center + Vector2(cos(angle), sin(angle)) * radius).round()
		var beam := _line(owner_center, end, Color(3.1, 1.4, 0.55, 1.0), Color(1.5, 0.3, 0.08, 0.24))
		_damage_line(owner_center, end, 4.0)
		_explode(end, Color(3.0, 1.15, 0.4, 1.0), Color(1.5, 0.28, 0.08, 1.0), 10.0, 10.0)
		_fade_free(beam, 0.14)
	await _sleep(0.05)

# S2 PRIMARY: GRAVITY WELL
func _s2_gravity_well() -> void:
	var tier := primary_tier
	var dest := _target_clamped(205.0 + float(tier) * 16.0)
	await _arc_shot_from(origin, dest, 42.0 + float(tier) * 8.0, 0.30, Color(1.1, 2.35, 3.25, 1.0), Color(0.18, 0.65, 1.5, 1.0), 9.0)
	var radius := 58.0 + float(tier) * 12.0
	var collapse_steps := 3 + (1 if tier >= 2 else 0)
	for i in range(collapse_steps):
		var r := lerpf(radius, 16.0, float(i) / float(maxi(1, collapse_steps - 1)))
		_pulse_ring(dest, r, Color(0.85, 2.2, 3.1, 1.0), Color(0.15, 0.55, 1.4, 0.25), 0.12, 26, float(i) * 0.10)
		await _sleep(0.045)
	_radial_hit(dest, radius, false)
	await _sleep(0.06)
	_explode(dest, Color(1.45, 2.75, 3.35, 1.0), Color(0.2, 0.7, 1.55, 1.0), 18.0 + float(tier) * 2.0, 20.0 + float(tier) * 4.0)
	if tier >= 3:
		await _sleep(0.08)
		_radial_hit(dest, radius * 0.85, false)
		_explode(dest, Color(1.8, 3.0, 3.5, 1.0), Color(0.2, 0.75, 1.65, 1.0), 15.0, 18.0)

# S2 SECONDARY: MASS EJECTION
func _s2_mass_ejection() -> void:
	var tier := secondary_tier
	var radius := 76.0 + float(tier) * 14.0
	for i in range(3):
		_pulse_ring(owner_center, radius - float(i) * 18.0, Color(0.9, 2.3, 3.2, 1.0), Color(0.15, 0.6, 1.45, 0.22), 0.13, 28, float(i) * 0.15)
		await _sleep(0.04)
	_radial_hit(owner_center, radius, false)
	await _sleep(0.10)
	_explode(owner_center, Color(1.5, 2.9, 3.45, 1.0), Color(0.2, 0.7, 1.6, 1.0), 24.0 + float(tier) * 3.0, 28.0 + float(tier) * 4.0)
	_radial_hit(owner_center, radius + 10.0, true)
	_pulse_ring(owner_center, radius + 12.0, Color(1.4, 2.8, 3.4, 1.0), Color(0.2, 0.7, 1.6, 0.25), 0.20, 36)

# S3 PRIMARY: PHASE NEEDLES
func _s3_phase_needles() -> void:
	var tier := primary_tier
	var shard_count := 5 + tier * 2
	var reach := 176.0 + float(tier) * 12.0
	var spread := deg_to_rad(48.0 + float(tier) * 6.0)
	for i in range(shard_count):
		var f := 0.0 if shard_count == 1 else (float(i) / float(shard_count - 1) - 0.5)
		var shard_dir := direction.rotated(f * spread)
		var end := (origin + shard_dir * reach).round()
		_dotted_trace(origin, end, Color(1.9, 2.5, 3.3, 1.0), Color(0.55, 0.85, 1.8, 1.0), 8.0, 0.16)
		_damage_line(origin, end, 3.0 + float(tier) * 0.5)
		_explode(end, Color(2.1, 2.7, 3.4, 1.0), Color(0.55, 0.85, 1.8, 1.0), 8.0 + float(tier), 8.0 + float(tier))
	await _sleep(0.04)

# S3 SECONDARY: PHASE BLOOM
func _s3_phase_bloom() -> void:
	var tier := secondary_tier
	var waves := 1 + tier
	for wave in range(waves):
		var radius := 58.0 + float(wave) * 18.0 + float(tier) * 8.0
		var count := 8 + tier * 4
		_pulse_ring(owner_center, radius, Color(1.8, 2.45, 3.3, 1.0), Color(0.55, 0.85, 1.8, 0.25), 0.16, count * 2, float(wave) * 0.18)
		_spark_pixels(owner_center, Color(2.0, 2.65, 3.4, 1.0), Color(0.55, 0.85, 1.8, 1.0), count, radius, 0.18)
		_radial_hit(owner_center, radius, true)
		for i in range(count):
			if i % 2 != 0:
				continue
			var angle := TAU * float(i) / float(count) + float(wave) * 0.14
			var hit := owner_center + Vector2(cos(angle), sin(angle)) * radius
			_explode(hit, Color(2.0, 2.65, 3.4, 1.0), Color(0.55, 0.85, 1.8, 1.0), 9.0, 9.0)
		await _sleep(0.07)
