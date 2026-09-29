extends Node2D
class_name SpacehaulSpecialAbility

const ExplosionScript = preload("res://Scripts/special_explosion.gd")
const ProjectileFxScript = preload("res://Scripts/special_projectile.gd")
const AbilityParticleScript = preload("res://Scripts/ability_particle_emitter.gd")
const IsoVfx = preload("res://Scripts/isometric_vfx.gd")

# All generated VFX are authored in world pixels: 1x1 core pixels with a 2x2
# additive bloom. Because the project uses nearest filtering and canvas stretch,
# these pixels scale with the mecha sprite pixels instead of becoming smooth FX.
const CORE_PIXEL := 1.0
const BLOOM_PIXEL := 2.0

var mecha_id := "M1"
var origin := Vector2.ZERO
var owner_center := Vector2.ZERO
var owner_ground := Vector2.ZERO
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
	new_owner_ground: Vector2,
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
	owner_ground = new_owner_ground.round()
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
	await get_tree().create_timer(maxf(seconds, 0.001), false).timeout

func _particle_profile() -> String:
	match mecha_id:
		"M1": return "ember"
		"M2": return "ion"
		"M3": return "ember"
		"R1": return "prism"
		"R2": return "sparks"
		"R3": return "exhaust"
		"R4": return "electric"
		"S1": return "solar"
		"S2": return "gravity"
		"S3": return "phase"
		_: return "ion"

func _spawn_follow_particles(target_node: Node2D, core: Color, glow: Color, duration: float, rate: float = 52.0) -> void:
	if target_node == null or root == null:
		return
	var emitter := AbilityParticleScript.new() as SpacehaulAbilityParticles
	root.add_child(emitter)
	emitter.setup_follow(target_node, core, glow, _particle_profile(), duration, rate)

func _spawn_path_particles(points: PackedVector2Array, core: Color, glow: Color, count: int = 7, life: float = 0.20) -> void:
	if root == null or points.size() < 2:
		return
	var emitter := AbilityParticleScript.new() as SpacehaulAbilityParticles
	root.add_child(emitter)
	emitter.setup_path(points, core, glow, _particle_profile(), count, life)

func _spawn_impact_particles(at: Vector2, core: Color, glow: Color, radius: float) -> void:
	if root == null:
		return
	var emitter := AbilityParticleScript.new() as SpacehaulAbilityParticles
	root.add_child(emitter)
	var count := clampi(int(round(radius * 0.42)), 5, 12)
	var speed := clampf(radius * 1.35, 18.0, 46.0)
	emitter.setup_burst(at.round(), core, glow, _particle_profile(), count, speed, 0.24)

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
	if from.distance_to(to) >= 32.0 and _rng.randf() < 0.58:
		_spawn_path_particles(
			PackedVector2Array([from.round(), to.round()]),
			color,
			glow_color,
			clampi(int(round(from.distance_to(to) / 42.0)), 2, 5),
			0.18
		)
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
	var total_length := 0.0
	for i in range(points.size() - 1):
		total_length += points[i].distance_to(points[i + 1])
	if total_length >= 24.0:
		_spawn_path_particles(
			points,
			color,
			glow_color,
			clampi(int(round(total_length / 42.0)), 4, 10),
			0.20
		)
	return container

func _fade_free(node: Node2D, seconds: float = 0.12) -> void:
	if node == null or not is_instance_valid(node):
		return
	var tween := root.create_tween()
	tween.tween_property(node, "modulate:a", 0.0, seconds)
	tween.tween_callback(node.queue_free)

func _make_arc_ground_shadow(at: Vector2) -> Polygon2D:
	var shadow := Polygon2D.new()
	shadow.polygon = PackedVector2Array([
		Vector2(0.0, -1.0),
		Vector2(2.0, 0.0),
		Vector2(0.0, 1.0),
		Vector2(-2.0, 0.0),
	])
	shadow.color = Color(0.02, 0.025, 0.035, 0.42)
	shadow.global_position = at.round()
	shadow.z_as_relative = false
	shadow.z_index = clampi(int(round(at.y)) + 2, -3000, 3000)
	root.add_child(shadow)
	return shadow

func _pulse_ring(center: Vector2, radius: float, core: Color, glow: Color, life: float = 0.16, point_count: int = 32, phase: float = 0.0) -> Node2D:
	var points := PackedVector2Array()
	var count := maxi(8, point_count)
	for i in range(count + 1):
		var angle := phase + TAU * float(i) / float(count)
		points.append(IsoVfx.ground_point(center, angle, radius).round())
	var ring := _polyline(points, core, glow)
	# Ground rings participate in the deck's Y-depth instead of always rendering
	# above every wall. Foreground geometry can now naturally cross in front.
	ring.z_index = clampi(int(round(center.y)) + 4, -3000, 3000)
	_fade_free(ring, life)
	return ring

func _spark_pixels(at: Vector2, core: Color, glow: Color, count: int, travel_radius: float, life: float = 0.22) -> void:
	for i in range(maxi(0, count)):
		var pixel := ProjectileFxScript.new() as SpacehaulSpecialProjectile
		root.add_child(pixel)
		pixel.setup(at, core, glow, 1.0, true)
		var angle := TAU * float(i) / float(maxi(1, count)) + _rng.randf_range(-0.16, 0.16)
		var distance := travel_radius * _rng.randf_range(0.55, 1.0)
		var destination := (at + IsoVfx.ground_offset(angle, distance)).round()
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
	_spawn_impact_particles(at, core, glow, radius * impact_scale)
	_damage_radius(at, hit_radius * impact_scale, (at - owner_ground).normalized())

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
		if collider == null or not collider.has_method("take_projectile_hit"):
			continue
		var body := collider as Node2D
		if body != null and not IsoVfx.inside_ground_radius(at, body.global_position, radius):
			continue
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
		if body != null and not IsoVfx.inside_ground_radius(at, body.global_position, radius):
			continue
		var push := Vector2.RIGHT
		if body != null:
			push = body.global_position - at
			if not outward:
				push = -push
			if push.length_squared() <= 0.001:
				push = direction
		collider.call("take_projectile_hit", push.normalized())

# Every damaging rendered trajectory resolves contact through this helper.
# Each enemy can be hit only once per trajectory, but a direct intersection now
# always produces a local impact burst and passes the trajectory direction into
# take_projectile_hit(), preserving the project's normal knockback response.
func _trajectory_contact_fx(at: Vector2, radius: float = 7.0) -> void:
	var core := Color(1.6, 2.9, 3.3, 1.0)
	var glow := Color(0.2, 0.85, 1.55, 1.0)

	match mecha_id:
		"M1":
			core = Color(3.0, 1.55, 0.55, 1.0)
			glow = Color(1.5, 0.40, 0.08, 1.0)
		"M2":
			core = Color(1.2, 2.9, 3.2, 1.0)
			glow = Color(0.2, 0.95, 1.4, 1.0)
		"M3":
			core = Color(3.0, 1.45, 0.40, 1.0)
			glow = Color(1.5, 0.35, 0.08, 1.0)
		"R1":
			core = Color(1.45, 3.0, 3.35, 1.0)
			glow = Color(0.2, 0.9, 1.5, 1.0)
		"R2":
			core = Color(3.05, 1.55, 0.42, 1.0)
			glow = Color(1.5, 0.40, 0.08, 1.0)
		"R3":
			core = Color(1.55, 2.75, 3.25, 1.0)
			glow = Color(0.2, 0.8, 1.5, 1.0)
		"R4":
			core = Color(2.55, 1.45, 3.3, 1.0)
			glow = Color(1.0, 0.25, 1.7, 1.0)
		"S1":
			core = Color(3.15, 1.15, 0.48, 1.0)
			glow = Color(1.6, 0.30, 0.08, 1.0)
		"S2":
			core = Color(1.35, 2.75, 3.4, 1.0)
			glow = Color(0.2, 0.7, 1.6, 1.0)
		"S3":
			core = Color(2.05, 2.65, 3.4, 1.0)
			glow = Color(0.55, 0.85, 1.8, 1.0)

	_ability_impact_fx(at.round(), core, glow, radius)


func _damage_line(from: Vector2, to: Vector2, radius: float = 5.0) -> void:
	if get_world_2d() == null:
		return

	var delta := to - from
	var push_dir := delta.normalized()
	if push_dir.length_squared() <= 0.001:
		push_dir = direction
	if push_dir.length_squared() <= 0.001:
		push_dir = Vector2.RIGHT

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

			# Use the enemy's actual position for the contact flash when possible, so
			# the explosion reads as a true collision with the rendered trajectory.
			var impact_at := p.round()
			var body := collider as Node2D
			if body != null:
				impact_at = body.global_position.round()

			collider.call("take_projectile_hit", push_dir)
			_trajectory_contact_fx(
				impact_at,
				clampf(5.5 + radius * 0.45, 6.0, 10.0)
			)

func _straight_shot_from(start: Vector2, dest: Vector2, core: Color, glow: Color, travel_time: float = 0.18, explode_radius: float = 14.0) -> void:
	var projectile := ProjectileFxScript.new() as SpacehaulSpecialProjectile
	root.add_child(projectile)
	projectile.setup(start.round(), core, glow, 1.0)
	_spawn_follow_particles(projectile, core, glow, travel_time + 0.05, 58.0)
	var tracer := _line(start, dest, Color(core.r, core.g, core.b, 0.72), Color(glow.r, glow.g, glow.b, 0.22))
	_fade_free(tracer, minf(0.12, travel_time))

	# The visible tracer is a real attack trajectory. Enemies touching it now
	# receive the same contact hit / explosion / directional knockback rule as
	# every other damaging line-based special ability.
	_damage_line(start, dest, 4.0)

	var tween := root.create_tween()
	tween.tween_property(projectile, "global_position", dest.round(), travel_time)
	await tween.finished
	if is_instance_valid(projectile):
		projectile.queue_free()
	_explode(dest, core, glow, explode_radius, explode_radius)

func _arc_shot_from(
	start: Vector2,
	dest: Vector2,
	arc_height: float,
	travel_time: float,
	core: Color,
	glow: Color,
	explode_radius: float = 18.0,
	tracking_target_id: int = 0
) -> Vector2:
	var projectile := ProjectileFxScript.new() as SpacehaulSpecialProjectile
	root.add_child(projectile)
	projectile.setup(start.round(), core, glow, 1.0)
	_spawn_follow_particles(projectile, core, glow, travel_time + 0.08, 64.0)
	var ground_shadow := _make_arc_ground_shadow(start)

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
	var live_dest := dest.round()

	while elapsed < travel_time:
		await get_tree().process_frame
		elapsed += get_process_delta_time()

		# Resolve the tracked enemy fresh every frame.
		# If it has been killed/freed, instance_from_id() simply returns null
		# and the projectile continues toward its last valid destination.
		if tracking_target_id != 0:
			var tracked_object := instance_from_id(tracking_target_id)
			var tracked_node := tracked_object as Node2D

			if tracked_node != null and is_instance_valid(tracked_node):
				if tracked_node.is_inside_tree():
					live_dest = tracked_node.global_position.round()

		var t := clampf(
			elapsed / maxf(travel_time, 0.001),
			0.0,
			1.0
		)

		var p := start.lerp(live_dest, t)
		p.y -= sin(t * PI) * arc_height
		p = p.round()

		if is_instance_valid(projectile):
			projectile.global_position = p

		if is_instance_valid(ground_shadow):
			var ground_p := start.lerp(live_dest, t).round()
			var height_factor := sin(t * PI)
			ground_shadow.global_position = ground_p
			ground_shadow.z_index = clampi(int(round(ground_p.y)) + 2, -3000, 3000)
			ground_shadow.scale = Vector2.ONE * lerpf(1.0, 0.62, height_factor)
			ground_shadow.modulate.a = lerpf(0.82, 0.38, height_factor)

		trail_glow.add_point(p)
		trail_core.add_point(p)

		if trail_core.get_point_count() > 24:
			trail_core.remove_point(0)
			trail_glow.remove_point(0)

	if is_instance_valid(projectile):
		projectile.queue_free()
	if is_instance_valid(ground_shadow):
		ground_shadow.queue_free()

	if is_instance_valid(trail_container):
		_fade_free(trail_container, 0.14)

	_explode(
		live_dest,
		core,
		glow,
		explode_radius,
		explode_radius
	)

	return live_dest

func _nearest_unused_enemy(
	aim_point: Vector2,
	search_radius: float,
	max_owner_range: float,
	excluded_ids: Dictionary
) -> Node2D:
	var best: Node2D = null
	var best_distance_sq := search_radius * search_radius

	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Node2D

		if enemy == null:
			continue

		if not is_instance_valid(enemy):
			continue

		if not enemy.is_inside_tree():
			continue

		var enemy_id := enemy.get_instance_id()

		if excluded_ids.has(enemy_id):
			continue

		var collision_body := enemy as CollisionObject2D

		if collision_body != null and collision_body.collision_layer == 0:
			continue

		if IsoVfx.ground_distance(owner_ground, enemy.global_position) > max_owner_range:
			continue

		var distance := IsoVfx.ground_distance(aim_point, enemy.global_position)
		var distance_sq := distance * distance

		if distance_sq <= best_distance_sq:
			best_distance_sq = distance_sq
			best = enemy

	return best

func _nearest_enemy_to_aim(
	aim_point: Vector2,
	search_radius: float,
	max_owner_range: float
) -> Node2D:
	return _nearest_unused_enemy(
		aim_point,
		search_radius,
		max_owner_range,
		{}
	)

func _show_target_lock(at: Vector2, core: Color, glow: Color) -> void:
	# A tiny 1px reticle confirms that an arcing weapon acquired the enemy nearest
	# the cursor. It uses the same 1px core / 2px bloom language as every other FX.
	_pulse_ring(at.round(), 8.0, core, Color(glow.r, glow.g, glow.b, 0.22), 0.11, 12)
	for i in range(4):
		var angle := float(i) * PI * 0.5
		var a := IsoVfx.ground_point(at, angle, 7.0)
		var b := IsoVfx.ground_point(at, angle, 11.0)
		var mark := _line(a, b, core, Color(glow.r, glow.g, glow.b, 0.18))
		_fade_free(mark, 0.11)

func _target_clamped(max_range: float) -> Vector2:
	var ground_delta := IsoVfx.unproject_ground(target - origin)
	if ground_delta.length() > max_range:
		return (origin + IsoVfx.project_ground(ground_delta.normalized() * max_range)).round()
	return target.round()

func _arc_points(center_point: Vector2, aim_angle: float, radius: float, half_angle: float, count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	var safe_count := maxi(3, count)
	var screen_aim := Vector2(cos(aim_angle), sin(aim_angle))
	var ground_aim_angle := IsoVfx.unproject_ground(screen_aim).angle()
	for i in range(safe_count):
		var t := float(i) / float(safe_count - 1)
		var angle := ground_aim_angle + lerpf(-half_angle, half_angle, t)
		points.append(IsoVfx.ground_point(center_point, angle, radius).round())
	return points

func _jagged_segment_points(from: Vector2, to: Vector2, jitter: float = 4.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	var delta := to - from
	var normal := IsoVfx.ground_perpendicular(delta)
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
			var distance := IsoVfx.ground_distance(cursor, body.global_position)
			if distance > range_limit:
				continue
			var score := distance
			if hop == 0:
				score += IsoVfx.ground_distance(body.global_position, target) * 0.45
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
func _m1_traveling_cleaver_wave(
	start_radius: float,
	end_radius: float,
	start_half_angle: float,
	end_half_angle: float,
	teeth: int,
	travel_time: float,
	hit_radius: float,
	core: Color,
	glow: Color
) -> void:
	var hit_ids: Dictionary = {}
	var step_count := 12

	var final_arc := PackedVector2Array()

	for step in range(step_count):
		var t := float(step) / float(maxi(1, step_count - 1))

		var radius := lerpf(
			start_radius,
			end_radius,
			t
		)

		var half_angle := lerpf(
			start_half_angle,
			end_half_angle,
			t
		)

		var arc := _arc_points(
			owner_ground,
			direction.angle(),
			radius,
			half_angle,
			teeth
		)

		final_arc = arc

		var blade := _polyline(
			arc,
			core,
			glow
		)

		blade.z_index = clampi(
			int(round(owner_ground.y)) + 5,
			-3000,
			3000
		)

		_fade_free(
			blade,
			0.075
		)

		if get_world_2d() != null:
			var shape := CircleShape2D.new()
			shape.radius = hit_radius

			var query := PhysicsShapeQueryParameters2D.new()
			query.shape = shape
			query.collision_mask = 2
			query.collide_with_bodies = true
			query.collide_with_areas = true

			for point in arc:
				query.transform = Transform2D(
					0.0,
					point
				)

				for hit in get_world_2d().direct_space_state.intersect_shape(
					query,
					32
				):
					var collider := hit.get("collider") as Object

					if collider == null:
						continue

					if not collider.has_method("take_projectile_hit"):
						continue

					var id := collider.get_instance_id()

					if hit_ids.has(id):
						continue

					var body := collider as Node2D

					if body != null:
						if not IsoVfx.inside_ground_radius(
							point,
							body.global_position,
							hit_radius
						):
							continue

					hit_ids[id] = true

					var push := direction

					if body != null:
						push = body.global_position - owner_ground

						if push.length_squared() <= 0.001:
							push = direction

					collider.call(
						"take_projectile_hit",
						push.normalized()
					)

					# Contact explosion.
					#
					# This is deliberately visual-only because the enemy
					# has already received the cleaver hit above.
					var impact_position := point

					if body != null:
						impact_position = body.global_position

					_ability_impact_fx(
						impact_position,
						Color(
							3.0,
							1.55,
							0.55,
							1.0
						),
						Color(
							1.5,
							0.40,
							0.08,
							1.0
						),
						8.0
					)

		# Plasma debris along the moving blade.
		if step % 2 == 0:
			var tip := (
				owner_ground
				+ IsoVfx.ground_vector(
					direction,
					radius
				)
			).round()

			_spark_pixels(
				tip,
				core,
				Color(
					glow.r,
					glow.g,
					glow.b,
					1.0
				),
				2,
				8.0,
				0.16
			)

		await _sleep(
			travel_time / float(step_count)
		)

	# Restore the original Plasma Cleaver's three-point impact language.
	#
	# The final wave detonates at:
	# - one end of the crescent
	# - the center
	# - the opposite end
	if final_arc.size() >= 3:
		var impact_indices := [
			0,
			int(final_arc.size() / 2),
			final_arc.size() - 1
		]

		for index in impact_indices:
			var point := final_arc[index]

			_explode(
				point,
				Color(
					3.0,
					1.5,
					0.55,
					1.0
				),
				Color(
					1.5,
					0.40,
					0.08,
					1.0
				),
				10.0 + float(primary_tier),
				9.0 + float(primary_tier)
			)

	# Final plasma breakup.
	var final_tip := (
		owner_ground
			+ IsoVfx.ground_vector(
				direction,
				end_radius
			)
	).round()

	_spark_pixels(
		final_tip,
		core,
		Color(
			glow.r,
			glow.g,
			glow.b,
			1.0
		),
		6,
		18.0,
		0.22
	)
	
func _ability_impact_fx(
	at: Vector2,
	core: Color,
	glow: Color,
	radius: float
) -> void:
	var fx := ExplosionScript.new() as SpacehaulSpecialExplosion
	root.add_child(fx)

	# This helper is deliberately visual-only. Do not trigger the global explosion
	# sample for contact sparks/corona/web decoration; real damaging _explode()
	# calls remain audible.
	fx.setup(
		at.round(),
		core,
		glow,
		radius * impact_scale,
		0.28,
		false
	)

	_spawn_impact_particles(
		at,
		core,
		glow,
		radius * impact_scale
	)
		
# M1 PRIMARY: PLASMA CLEAVER
# A travelling isometric plasma crescent that cuts forward through crowds.
func _m1_plasma_cleaver() -> void:
	var tier := primary_tier

	# Start almost directly in front of Atlas instead of spawning the blade
	# at its maximum range.
	var start_radius := 22.0

	# Each upgrade gives the weapon noticeably more forward reach.
	var end_radius := 132.0 + float(tier) * 14.0

	var start_half_angle := deg_to_rad(
		27.0 + float(tier) * 2.0
	)

	var end_half_angle := deg_to_rad(
		36.0 + float(tier) * 5.0
	)

	var teeth := 7 + tier * 2

	await _m1_traveling_cleaver_wave(
		start_radius,
		end_radius,
		start_half_angle,
		end_half_angle,
		teeth,
		0.22,
		9.0 + float(tier),
		Color(3.0, 1.45, 0.55, 1.0),
		Color(1.5, 0.42, 0.10, 0.30)
	)

	# Tier 2: a hotter, narrower second wave punches farther through
	# whatever survived the first cleave.
	if tier >= 2:
		await _sleep(0.045)

		await _m1_traveling_cleaver_wave(
			28.0,
			end_radius + 18.0,
			start_half_angle * 0.82,
			end_half_angle * 0.88,
			teeth + 2,
			0.17,
			8.0 + float(tier),
			Color(2.9, 1.05, 0.32, 1.0),
			Color(1.35, 0.30, 0.07, 0.28)
		)

	# Tier 3: a larger overcharged echo follows the attack and opens the
	# cleaver into a much stronger crowd-clearing weapon.
	if tier >= 3:
		await _sleep(0.04)

		await _m1_traveling_cleaver_wave(
			34.0,
			end_radius + 32.0,
			start_half_angle,
			end_half_angle * 1.18,
			teeth + 4,
			0.18,
			9.0,
			Color(3.2, 2.0, 0.8, 1.0),
			Color(1.6, 0.5, 0.10, 0.30)
		)
		
# M1 SECONDARY: REPULSOR BURST
func _m1_repulsor_burst() -> void:
	var tier := secondary_tier
	var waves := 1 + (1 if tier >= 2 else 0) + (1 if tier >= 3 else 0)
	var spokes := 12 + tier * 4
	for wave in range(waves):
		var radius := 64.0 + float(tier) * 10.0 + float(wave) * 22.0
		_pulse_ring(owner_ground, radius, Color(1.2, 2.9, 3.2, 1.0), Color(0.2, 1.0, 1.6, 0.26), 0.20, spokes)
		_radial_hit(owner_ground, radius, true)
		for i in range(spokes):
			if i % 2 != 0:
				continue
			var angle := TAU * float(i) / float(spokes)
			var end := IsoVfx.ground_point(owner_ground, angle, radius)
			var ray := _line(owner_ground, end, Color(1.5, 3.1, 3.3, 0.9), Color(0.25, 1.0, 1.5, 0.18))
			_fade_free(ray, 0.10)
			_explode(end, Color(1.8, 3.0, 3.2, 1.0), Color(0.25, 1.0, 1.5, 1.0), 9.0, 10.0)
		await _sleep(0.08)

# M2 PRIMARY: VECTOR HARPOONS
# Panther now physically projects its tether heads across the isometric deck.
# The original fan count, spread, reach, line damage and endpoint impacts remain intact.
func _m2_project_vector_harpoons(
	ends: Array[Vector2],
	tier: int,
	travel_time: float
) -> void:
	if ends.is_empty():
		return

	var core := Color(0.9, 2.8, 3.2, 1.0)
	var glow := Color(0.15, 0.95, 1.45, 0.28)
	var impact_core := Color(1.2, 2.9, 3.2, 1.0)
	var impact_glow := Color(0.2, 0.95, 1.4, 1.0)
	var heads: Array[Node2D] = []
	var tethers: Array[Node2D] = []

	# Give every harpoon a visible projectile head with the same attached gas
	# treatment used by the other floating special-ability pixels. Each cable is
	# created once and its endpoint is extended as the head travels.
	for _end in ends:
		var head := ProjectileFxScript.new() as SpacehaulSpecialProjectile
		root.add_child(head)
		head.setup(origin.round(), core, Color(0.2, 1.0, 1.55, 1.0), 1.0, true)
		heads.append(head)

		var tether := _line(origin, origin, core, glow)
		tethers.append(tether)

	var steps := 11

	for step in range(steps):
		var t := float(step + 1) / float(steps)

		# Slight ease-out gives the fan a launched/propelled feeling instead of
		# simply drawing progressively longer lines at a constant rate.
		var travel_t := 1.0 - pow(1.0 - t, 2.0)

		for i in range(ends.size()):
			var current := origin.lerp(ends[i], travel_t).round()

			if i < heads.size() and is_instance_valid(heads[i]):
				heads[i].global_position = current

			if i < tethers.size() and is_instance_valid(tethers[i]):
				for child in tethers[i].get_children():
					var line := child as Line2D
					if line != null and line.get_point_count() >= 2:
						line.set_point_position(1, current)

		await _sleep(travel_time / float(steps))

	# Resolve the original Vector Harpoon gameplay only once the heads reach
	# their destinations. Each tether still damages along its complete path.
	for i in range(ends.size()):
		var end := ends[i]

		_damage_line(
			origin,
			end,
			4.0 + float(tier)
		)

		# Restore path particles at full extension; the growing cable itself does
		# not repeatedly spawn emitters during its travel.
		_spawn_path_particles(
			PackedVector2Array([origin.round(), end.round()]),
			core,
			glow,
			clampi(int(round(origin.distance_to(end) / 42.0)), 3, 7),
			0.20
		)

		_explode(
			end,
			impact_core,
			impact_glow,
			9.0 + float(tier),
			10.0 + float(tier)
		)

		if i < tethers.size() and is_instance_valid(tethers[i]):
			_fade_free(tethers[i], 0.18)

		if i < heads.size() and is_instance_valid(heads[i]):
			heads[i].queue_free()


func _m2_vector_harpoons() -> void:
	var tier := primary_tier

	# Preserve Panther's existing upgrade structure:
	# T0 = 3, T1 = 5, T2 = 7, T3 = 9 projected harpoons.
	var bolt_count := 3 + tier * 2
	var total_spread := deg_to_rad(24.0 + float(tier) * 4.0)
	var reach := 158.0 + float(tier) * 12.0
	var ends: Array[Vector2] = []

	for i in range(bolt_count):
		var f := 0.0 if bolt_count == 1 else (
			float(i) / float(bolt_count - 1) - 0.5
		)

		var bolt_offset := IsoVfx.ground_vector(
			direction,
			reach,
			f * total_spread
		)

		ends.append((origin + bolt_offset).round())

	# Higher tiers project a larger fan, but keep the same fast Panther cadence.
	var travel_time := maxf(0.14, 0.21 - float(tier) * 0.012)
	await _m2_project_vector_harpoons(ends, tier, travel_time)
	await _sleep(0.04)


# M2 SECONDARY: ANCHOR BLOOM
# The inward anchor behavior is preserved, but its release is now a visibly
# projected radial detonation travelling across the isometric ground plane.
func _m2_anchor_release_wave(
	max_radius: float,
	tier: int,
	overcharged: bool = false
) -> void:
	var core := (
		Color(1.75, 3.15, 3.35, 1.0)
		if overcharged
		else Color(1.25, 2.95, 3.25, 1.0)
	)

	var glow := (
		Color(0.28, 1.05, 1.65, 1.0)
		if overcharged
		else Color(0.18, 0.85, 1.5, 1.0)
	)

	var shard_count := 10 + tier * 4 + (4 if overcharged else 0)
	var endpoints: Array[Vector2] = []
	var shards: Array[Node2D] = []
	var phase := 0.16 if overcharged else 0.0

	for i in range(shard_count):
		var angle := (
			phase
			+ TAU * float(i) / float(shard_count)
			+ _rng.randf_range(-0.055, 0.055)
		)

		var distance := max_radius * _rng.randf_range(0.88, 1.0)
		var endpoint := IsoVfx.ground_point(
			owner_ground,
			angle,
			distance
		).round()

		endpoints.append(endpoint)

		var shard := ProjectileFxScript.new() as SpacehaulSpecialProjectile
		root.add_child(shard)
		shard.setup(owner_ground, core, glow, 1.0, true)
		shards.append(shard)

	var steps := 10

	for step in range(steps):
		var t := float(step + 1) / float(steps)
		var blast_t := 1.0 - pow(1.0 - t, 2.35)
		var ring_radius := lerpf(12.0, max_radius, blast_t)

		_pulse_ring(
			owner_ground,
			ring_radius,
			core,
			Color(glow.r, glow.g, glow.b, 0.22),
			0.075,
			24 + tier * 4 + (6 if overcharged else 0),
			phase + float(step) * 0.035
		)

		for i in range(endpoints.size()):
			if i >= shards.size() or not is_instance_valid(shards[i]):
				continue

			shards[i].global_position = owner_ground.lerp(
				endpoints[i],
				blast_t
			).round()

		await _sleep(0.018)

	# Apply the original outward gameplay impulse at the edge of the projected wave.
	_radial_hit(owner_ground, max_radius, true)

	# Break the perimeter into impact flashes so the release feels like an actual
	# detonation reaching the floor rather than a decorative ring disappearing.
	var impact_stride := maxi(1, int(round(float(shard_count) / 8.0)))

	for i in range(endpoints.size()):
		if i % impact_stride == 0:
			_ability_impact_fx(
				endpoints[i],
				core,
				glow,
				7.0 + float(tier) + (2.0 if overcharged else 0.0)
			)

		if i < shards.size() and is_instance_valid(shards[i]):
			shards[i].queue_free()


func _m2_anchor_bloom() -> void:
	var tier := secondary_tier

	# Preserve the original upgrade logic:
	# +14 radius per tier, an extra collapse stage from Tier 2 onward,
	# and the oversized Anchor Nova release at Tier 3.
	var radius := 72.0 + float(tier) * 14.0
	var collapse_count := 3 + (1 if tier >= 2 else 0)

	# Pull phase: progressively collapsing isometric rings converge on Panther.
	for i in range(collapse_count):
		var r := lerpf(
			radius,
			24.0,
			float(i) / float(maxi(1, collapse_count - 1))
		)

		_pulse_ring(
			owner_ground,
			r,
			Color(0.8, 2.7, 3.2, 1.0),
			Color(0.15, 0.8, 1.4, 0.25),
			0.12,
			28 + tier * 2,
			float(i) * 0.12
		)

		await _sleep(0.045)

	# Keep Anchor Bloom's defining crowd-control behavior: enemies are first
	# dragged inward before the anchor core violently releases.
	_radial_hit(owner_ground, radius, false)
	await _sleep(0.08)

	_explode(
		owner_ground,
		Color(1.3, 3.0, 3.25, 1.0),
		Color(0.2, 1.0, 1.5, 1.0),
		22.0 + float(tier) * 3.0,
		26.0 + float(tier) * 5.0
	)

	# Project the normal release outward rather than applying an invisible push
	# immediately after the center explosion.
	await _m2_anchor_release_wave(
		radius * 0.78,
		tier,
		false
	)

	# Tier 3 keeps the original oversized second release, now rendered as an
	# overcharged projected nova with denser radial debris and perimeter impacts.
	if tier >= 3:
		await _sleep(0.045)
		await _m2_anchor_release_wave(
			radius + 18.0,
			tier,
			true
		)

# M3 PRIMARY: COMET MORTAR
func _m3_comet_mortar() -> void:
	var tier := primary_tier
	var max_range := 245.0 + float(tier) * 12.0

	var locked_target := _nearest_enemy_to_aim(
		target,
		74.0,
		max_range
	)

	var tracking_target_id := 0
	var dest := _target_clamped(max_range)

	if locked_target != null and is_instance_valid(locked_target):
		tracking_target_id = locked_target.get_instance_id()
		dest = locked_target.global_position.round()

		_show_target_lock(
			dest,
			Color(3.0, 1.75, 0.55, 1.0),
			Color(1.5, 0.35, 0.08, 1.0)
		)

	# Main mortar shell follows the enemy originally acquired near the cursor.
	dest = await _arc_shot_from(
		origin,
		dest,
		70.0 + float(tier) * 10.0,
		0.34,
		Color(3.0, 1.15, 0.28, 1.0),
		Color(1.5, 0.32, 0.08, 1.0),
		19.0 + float(tier) * 2.0,
		tracking_target_id
	)

	var shards := 4 + tier * 2
	var shard_radius := 32.0 + float(tier) * 5.0
	var used_targets: Dictionary = {}

	# Prefer other nearby enemies for the follow-up shrapnel.
	if locked_target != null and is_instance_valid(locked_target):
		used_targets[locked_target.get_instance_id()] = true

	for i in range(shards):
		var end := Vector2.ZERO

		var shard_target := _nearest_unused_enemy_from_point(
			dest,
			shard_radius,
			used_targets
		)

		if shard_target != null and is_instance_valid(shard_target):
			var shard_target_id := shard_target.get_instance_id()
			used_targets[shard_target_id] = true
			end = shard_target.global_position.round()
		else:
			# Once unique nearby enemies are exhausted, keep the remaining
			# shrapnel useful by falling back to a radial scatter.
			var angle := TAU * float(i) / float(maxi(1, shards))
			end = (
				dest
				+ IsoVfx.ground_offset(angle, shard_radius)
			).round()

		var shrapnel := _line(
			dest,
			end,
			Color(3.0, 1.8, 0.65, 0.95),
			Color(1.5, 0.4, 0.08, 0.22)
		)

		_damage_line(
			dest,
			end,
			3.0
		)

		_explode(
			end,
			Color(3.0, 1.45, 0.4, 1.0),
			Color(1.5, 0.35, 0.08, 1.0),
			8.0,
			8.0
		)

		_fade_free(
			shrapnel,
			0.12
		)

		# Tiny cadence makes the shrapnel read as a cascading burst.
		await _sleep(0.018)

	if tier >= 3:
		await _sleep(0.10)

		_explode(
			dest,
			Color(3.2, 2.0, 0.8, 1.0),
			Color(1.7, 0.45, 0.08, 1.0),
			24.0,
			24.0
		)


func _nearest_unused_enemy_from_point(
	search_center: Vector2,
	search_radius: float,
	excluded_ids: Dictionary
) -> Node2D:
	var best: Node2D = null
	var best_distance_sq := search_radius * search_radius

	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Node2D

		if enemy == null:
			continue

		if not is_instance_valid(enemy):
			continue

		if not enemy.is_inside_tree():
			continue

		var enemy_id := enemy.get_instance_id()

		if excluded_ids.has(enemy_id):
			continue

		var collision_body := enemy as CollisionObject2D

		if collision_body != null and collision_body.collision_layer == 0:
			continue

		var distance := IsoVfx.ground_distance(search_center, enemy.global_position)
		var distance_sq := distance * distance

		if distance_sq <= best_distance_sq:
			best_distance_sq = distance_sq
			best = enemy

	return best
				
# M3 SECONDARY: ORBITAL RAIN
func _m3_orbital_rain() -> void:
	var tier := secondary_tier
	var strikes := 8 + tier * 4
	var radius := 72.0 + float(tier) * 10.0
	_explode(owner_ground, Color(2.8, 1.2, 0.3, 1.0), Color(1.4, 0.3, 0.08, 1.0), 13.0, 13.0)
	for i in range(strikes):
		var angle := TAU * float(i) / float(strikes) + float(tier) * 0.13
		var hit := (IsoVfx.ground_point(owner_ground, angle, radius)).round()
		var sky_start := hit + Vector2(float((i % 3) - 1) * 18.0, -140.0)
		var beam := _line(sky_start, hit, Color(3.0, 1.35, 0.35, 1.0), Color(1.5, 0.35, 0.08, 0.24))
		_explode(hit, Color(3.0, 1.2, 0.3, 1.0), Color(1.5, 0.3, 0.08, 1.0), 11.0 + float(tier), 12.0 + float(tier))
		_fade_free(beam, 0.11)
		await _sleep(0.025)

# R1 / R2 SHARED: ANNULAR IMPACT FIELD
# Applies one crowd-control/damage hit to enemies in a donut around the player.
# The center remains deliberately safe and visually clear.
func _annular_hit(
	center: Vector2,
	inner_radius: float,
	outer_radius: float,
	outward: bool = true
) -> void:
	if get_world_2d() == null:
		return

	var shape := CircleShape2D.new()
	shape.radius = maxf(1.0, outer_radius)

	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, center)
	query.collision_mask = 2
	query.collide_with_bodies = true
	query.collide_with_areas = true

	var hit_ids: Dictionary = {}

	for hit in get_world_2d().direct_space_state.intersect_shape(query, 96):
		var collider := hit.get("collider") as Object

		if collider == null or not collider.has_method("take_projectile_hit"):
			continue

		var id := collider.get_instance_id()
		if hit_ids.has(id):
			continue

		var body := collider as Node2D
		if body == null:
			continue

		var distance := IsoVfx.ground_distance(center, body.global_position)

		if distance < inner_radius or distance > outer_radius:
			continue

		hit_ids[id] = true

		var push := body.global_position - center
		if not outward:
			push = -push

		if push.length_squared() <= 0.001:
			push = direction

		collider.call("take_projectile_hit", push.normalized())


# Creates a dense donut of visual-only explosions. Gameplay damage is applied
# separately through _annular_hit(), preventing overlapping explosion nodes from
# multiplying damage while still giving the ability a much heavier presentation.
func _radial_explosion_field(
	center: Vector2,
	inner_radius: float,
	outer_radius: float,
	ring_count: int,
	points_per_ring: int,
	core: Color,
	glow: Color,
	phase: float = 0.0,
	explosion_size: float = 8.0
) -> void:
	var safe_rings := maxi(1, ring_count)

	for ring_index in range(safe_rings):
		var ring_t := float(ring_index + 1) / float(safe_rings)
		var ring_radius := lerpf(inner_radius, outer_radius, ring_t)
		var point_count := maxi(6, points_per_ring + ring_index * 2)
		var ring_phase := phase + float(ring_index) * 0.31

		_pulse_ring(
			center,
			ring_radius,
			core,
			Color(glow.r, glow.g, glow.b, 0.20),
			0.13,
			point_count * 2,
			ring_phase
		)

		for i in range(point_count):
			var angle := ring_phase + TAU * float(i) / float(point_count)
			var blast_point := IsoVfx.ground_point(
				center,
				angle,
				ring_radius
			).round()

			_ability_impact_fx(
				blast_point,
				core,
				glow,
				explosion_size + ring_t * 2.0
			)
			
			await _sleep(0.018)
			
		# The slight cadence makes the blast visibly propagate away from the
		# chassis instead of every explosion appearing on the same frame.
		await _sleep(0.022)


# R1 PRIMARY: PRISM LANCE
# A projected refracting salvo. The original lance count/range progression is
# preserved, but each lance now physically travels across the deck and the fan
# opens slightly as tiers are added.
func _r1_prism_lance() -> void:
	var tier := primary_tier
	var lance_count := 3 + tier
	var reach := 184.0 + float(tier) * 14.0
	var fan_width := deg_to_rad(8.0 + float(tier) * 2.0)

	var core := Color(0.85, 2.8, 3.25, 1.0)
	var glow := Color(0.18, 0.9, 1.5, 0.25)
	var impact_core := Color(1.1, 2.9, 3.3, 1.0)
	var impact_glow := Color(0.2, 0.9, 1.5, 1.0)

	var starts: Array[Vector2] = []
	var ends: Array[Vector2] = []
	var heads: Array[Node2D] = []
	var beams: Array[Node2D] = []

	for i in range(lance_count):
		var f := 0.0 if lance_count == 1 else (
			float(i) / float(lance_count - 1) - 0.5
		)

		var lateral := IsoVfx.ground_perpendicular_offset(
			direction,
			f * 10.0
		)

		var start := (origin + lateral).round()
		var end := (
			start
			+ IsoVfx.ground_vector(
				direction,
				reach,
				f * fan_width
			)
		).round()

		starts.append(start)
		ends.append(end)

		var head := ProjectileFxScript.new() as SpacehaulSpecialProjectile
		root.add_child(head)
		head.setup(
			start,
			core,
			Color(0.2, 1.0, 1.55, 1.0),
			1.0,
			true
		)
		_spawn_follow_particles(head, core, impact_glow, 0.24, 46.0)
		heads.append(head)

		var beam := _line(start, start, core, glow)
		beams.append(beam)

	var travel_time := maxf(0.13, 0.20 - float(tier) * 0.012)
	var steps := 10

	for step in range(steps):
		var t := float(step + 1) / float(steps)
		var travel_t := 1.0 - pow(1.0 - t, 2.0)

		for i in range(ends.size()):
			var current := starts[i].lerp(ends[i], travel_t).round()

			if i < heads.size() and is_instance_valid(heads[i]):
				heads[i].global_position = current

			if i < beams.size() and is_instance_valid(beams[i]):
				for child in beams[i].get_children():
					var line := child as Line2D
					if line != null and line.get_point_count() >= 2:
						line.set_point_position(1, current)

		await _sleep(travel_time / float(steps))

	for i in range(ends.size()):
		var start := starts[i]
		var end := ends[i]

		_damage_line(
			start,
			end,
			3.5 + float(tier) * 0.5
		)

		_explode(
			end,
			impact_core,
			impact_glow,
			9.0 + float(tier),
			8.0 + float(tier)
		)

		# Max-tier refraction still produces the original cross burst, but now
		# the cross is larger and accompanied by impact sparks.
		if tier >= 3:
			var cross_offset := IsoVfx.ground_perpendicular_offset(
				direction,
				11.0
			)

			var cross := _line(
				end - cross_offset,
				end + cross_offset,
				Color(1.8, 3.1, 3.4, 0.9),
				Color(0.2, 0.9, 1.5, 0.20)
			)

			_damage_line(
				end - cross_offset,
				end + cross_offset,
				4.5
			)

			_fade_free(cross, 0.12)

		if i < beams.size() and is_instance_valid(beams[i]):
			_fade_free(beams[i], 0.15)

		if i < heads.size() and is_instance_valid(heads[i]):
			heads[i].queue_free()


# R1 SECONDARY: HALO SWEEP
# A prismatic radial sweep followed by a dense annular explosion field.
# Explosions fill the combat radius, but the immediate area around the player
# remains a deliberate safe pocket.
func _r1_halo_sweep() -> void:
	var tier := secondary_tier
	var phases := 1 + (1 if tier >= 2 else 0)
	var spokes := 8 + tier * 4
	var radius := 76.0 + float(tier) * 10.0
	var safe_radius := 25.0

	var core := Color(0.9, 2.8, 3.25, 1.0)
	var glow := Color(0.18, 0.9, 1.5, 1.0)

	for phase_index in range(phases):
		var phase := float(phase_index) * PI / float(maxi(1, spokes))

		_pulse_ring(
			owner_ground,
			safe_radius,
			Color(1.6, 3.1, 3.35, 0.95),
			Color(0.2, 0.9, 1.5, 0.18),
			0.16,
			spokes,
			phase
		)

		_pulse_ring(
			owner_ground,
			radius,
			core,
			Color(0.18, 0.9, 1.5, 0.22),
			0.18,
			spokes * 2,
			phase
		)

		# Keep Halo Sweep's ray identity, but begin the rays outside the safe
		# center so the player is never buried under its own VFX.
		for i in range(spokes):
			var angle := phase + TAU * float(i) / float(spokes)
			var ray_start := IsoVfx.ground_point(
				owner_ground,
				angle,
				safe_radius
			).round()
			var end := IsoVfx.ground_point(
				owner_ground,
				angle,
				radius
			).round()

			var beam := _line(
				ray_start,
				end,
				Color(1.2, 3.0, 3.3, 0.9),
				Color(0.2, 0.9, 1.5, 0.16)
			)

			_damage_line(
				ray_start,
				end,
				3.0 + float(tier) * 0.25
			)

			_fade_free(beam, 0.11)

		await _radial_explosion_field(
			owner_ground,
			safe_radius + 6.0,
			radius,
			3 + (1 if tier >= 3 else 0),
			6 + tier * 2,
			Color(1.25, 3.0, 3.35, 1.0),
			glow,
			phase,
			7.0 + float(tier) * 0.6
		)

		# One controlled annular hit gives the explosion carpet real gameplay
		# weight without multiplying damage for every overlapping visual blast.
		_annular_hit(
			owner_ground,
			safe_radius,
			radius,
			true
		)

		await _sleep(0.055)


# R2 PRIMARY: BREACH CANNON
# Still a single heavy cannon trajectory, but the shot now visibly travels and
# tears a forward fracture cone through the crowd after impact.
func _r2_breach_cannon() -> void:
	var tier := primary_tier
	var max_range := 250.0 + float(tier) * 18.0
	var end := _target_clamped(max_range)

	var core := Color(3.2, 2.2, 0.85, 1.0)
	var glow := Color(1.6, 0.5, 0.1, 0.32)
	var impact_core := Color(3.2, 1.65, 0.45, 1.0)
	var impact_glow := Color(1.6, 0.42, 0.08, 1.0)

	# Short warning line keeps the weapon readable before the heavy slug launches.
	var telegraph := _line(
		origin,
		end,
		Color(2.8, 1.2, 0.35, 0.45),
		Color(1.3, 0.35, 0.08, 0.12)
	)

	await _sleep(0.045)
	_fade_free(telegraph, 0.045)

	var slug_head := ProjectileFxScript.new() as SpacehaulSpecialProjectile
	root.add_child(slug_head)
	slug_head.setup(
		origin.round(),
		core,
		Color(1.7, 0.55, 0.12, 1.0),
		1.25,
		true
	)
	_spawn_follow_particles(
		slug_head,
		core,
		impact_glow,
		0.26,
		68.0
	)

	var slug_trail := _line(
		origin,
		origin,
		core,
		glow
	)

	# Higher tiers add visual pressure rails while remaining one gameplay shot.
	var rail_a: Node2D = null
	var rail_b: Node2D = null
	var rail_offset := 4.0 + float(tier)

	if tier >= 1:
		var left := IsoVfx.ground_perpendicular_offset(direction, -rail_offset)
		var right := IsoVfx.ground_perpendicular_offset(direction, rail_offset)

		rail_a = _line(
			origin + left,
			origin + left,
			Color(3.0, 1.45, 0.40, 0.60),
			Color(1.4, 0.34, 0.07, 0.12)
		)

		rail_b = _line(
			origin + right,
			origin + right,
			Color(3.0, 1.45, 0.40, 0.60),
			Color(1.4, 0.34, 0.07, 0.12)
		)

	var steps := 11
	var travel_time := maxf(0.13, 0.20 - float(tier) * 0.01)

	for step in range(steps):
		var t := float(step + 1) / float(steps)
		var travel_t := 1.0 - pow(1.0 - t, 2.25)
		var current := origin.lerp(end, travel_t).round()

		if is_instance_valid(slug_head):
			slug_head.global_position = current

		if is_instance_valid(slug_trail):
			for child in slug_trail.get_children():
				var line := child as Line2D
				if line != null and line.get_point_count() >= 2:
					line.set_point_position(1, current)

		if tier >= 1:
			var left_offset := IsoVfx.ground_perpendicular_offset(
				direction,
				-rail_offset
			)
			var right_offset := IsoVfx.ground_perpendicular_offset(
				direction,
				rail_offset
			)

			if rail_a != null and is_instance_valid(rail_a):
				for child in rail_a.get_children():
					var line := child as Line2D
					if line != null and line.get_point_count() >= 2:
						line.set_point_position(1, current + left_offset)

			if rail_b != null and is_instance_valid(rail_b):
				for child in rail_b.get_children():
					var line := child as Line2D
					if line != null and line.get_point_count() >= 2:
						line.set_point_position(1, current + right_offset)

		# Tiny floor ruptures make the shell feel mechanically heavy without
		# adding extra gameplay hits along the corridor.
		if step == 4 or step == 8:
			_ability_impact_fx(
				current,
				Color(2.9, 1.25, 0.32, 0.9),
				Color(1.35, 0.30, 0.07, 0.8),
				4.5 + float(tier) * 0.5
			)

		await _sleep(travel_time / float(steps))

	if is_instance_valid(slug_head):
		slug_head.queue_free()

	if is_instance_valid(slug_trail):
		_fade_free(slug_trail, 0.18)

	if rail_a != null and is_instance_valid(rail_a):
		_fade_free(rail_a, 0.14)

	if rail_b != null and is_instance_valid(rail_b):
		_fade_free(rail_b, 0.14)

	_damage_line(
		origin,
		end,
		6.0 + float(tier)
	)

	# Tier 2 specifically gains the stronger impact/range identity described by
	# its upgrade label. Tier 3 pushes that impact even further.
	var impact_bonus := 0.0
	if tier >= 2:
		impact_bonus = 4.0 + float(tier - 2) * 3.0

	_explode(
		end,
		impact_core,
		impact_glow,
		23.0 + float(tier) * 3.0 + impact_bonus,
		22.0 + float(tier) * 3.0 + impact_bonus
	)

	if tier >= 2:
		_pulse_ring(
			end,
			27.0 + float(tier) * 4.0,
			Color(3.2, 2.0, 0.65, 1.0),
			Color(1.6, 0.42, 0.08, 0.22),
			0.17,
			22 + tier * 4
		)

	# Preserve the original upgrade structure: more splinters at each tier.
	# They now fracture FORWARD beyond the main impact instead of folding back
	# toward the player, making upgraded Breach Cannon much better in a swarm.
	var splinters := 4 + tier * 2
	var fracture_reach := 34.0 + float(tier) * 7.0
	var fracture_spread := 0.82 + float(tier) * 0.06

	for i in range(splinters):
		var f := 0.0 if splinters == 1 else (
			float(i) / float(splinters - 1) - 0.5
		)
		var spread_angle := f * fracture_spread * 2.0
		var splinter_offset := IsoVfx.ground_vector(
			direction,
			fracture_reach,
			spread_angle
		)
		var splinter_end := (end + splinter_offset).round()

		var splinter := _line(
			end,
			splinter_end,
			Color(3.0, 1.55, 0.45, 0.9),
			Color(1.5, 0.4, 0.08, 0.18)
		)

		_damage_line(
			end,
			splinter_end,
			3.0 + float(tier) * 0.25
		)

		_ability_impact_fx(
			splinter_end,
			Color(3.0, 1.45, 0.4, 1.0),
			Color(1.5, 0.35, 0.08, 1.0),
			6.0 + float(tier) * 0.5
		)

		_fade_free(splinter, 0.12)


# R2 SECONDARY: COUNTERSHOCK
# A heavy annular counter-blast. The inner pocket is intentionally untouched,
# while the rest of the radius fills with expanding breach explosions.
func _r2_countershock() -> void:
	var tier := secondary_tier
	var blasts := 4 + tier * 2
	var radius := 82.0 + float(tier) * 11.0
	var safe_radius := 27.0

	var core := Color(3.0, 1.75, 0.55, 1.0)
	var glow := Color(1.5, 0.45, 0.08, 1.0)

	# A tight inner warning ring clearly communicates the safe center.
	_pulse_ring(
		owner_ground,
		safe_radius,
		Color(3.2, 2.1, 0.75, 0.95),
		Color(1.6, 0.45, 0.08, 0.20),
		0.18,
		18 + tier * 2
	)

	# Retain Countershock's directional blast spokes, but launch them from the
	# edge of the safe pocket instead of directly through the player.
	for i in range(blasts):
		var angle := TAU * float(i) / float(blasts)
		var ray_start := IsoVfx.ground_point(
			owner_ground,
			angle,
			safe_radius
		).round()
		var end := IsoVfx.ground_point(
			owner_ground,
			angle,
			radius
		).round()

		var beam := _line(
			ray_start,
			end,
			core,
			Color(1.5, 0.45, 0.08, 0.24)
		)

		_damage_line(
			ray_start,
			end,
			5.0 + float(tier) * 0.35
		)

		_explode(
			end,
			Color(3.0, 1.45, 0.4, 1.0),
			Color(1.5, 0.35, 0.08, 1.0),
			13.0 + float(tier),
			14.0 + float(tier)
		)

		_fade_free(beam, 0.15)

	# Fill the entire donut with staged explosion coverage rather than leaving
	# empty space between only a few radial endpoints.
	await _radial_explosion_field(
		owner_ground,
		safe_radius + 6.0,
		radius,
		3 + (1 if tier >= 2 else 0),
		7 + tier * 2,
		Color(3.05, 1.55, 0.42, 1.0),
		glow,
		0.12,
		8.0 + float(tier) * 0.8
	)

	_annular_hit(
		owner_ground,
		safe_radius,
		radius,
		true
	)

	# Max-tier counter core gets a final perimeter concussion without ever
	# detonating beneath the chassis.
	if tier >= 3:
		await _sleep(0.035)

		var outer_points := 12
		for i in range(outer_points):
			var angle := (
				TAU * float(i) / float(outer_points)
				+ PI / float(outer_points)
			)
			var edge := IsoVfx.ground_point(
				owner_ground,
				angle,
				radius + 10.0
			).round()

			_ability_impact_fx(
				edge,
				Color(3.25, 1.9, 0.58, 1.0),
				Color(1.65, 0.42, 0.08, 1.0),
				9.5
			)

	await _sleep(0.05)


# R3 PRIMARY: HUNTER MISSILES
# Hunter keeps its smart multi-target identity, but missiles now visibly launch
# upward out of the local combat plane before diving back down onto their locks.
func _r3_resolve_target_position(tracking_target_id: int, fallback: Vector2) -> Vector2:
	if tracking_target_id == 0:
		return fallback.round()

	var tracked_object := instance_from_id(tracking_target_id)
	var tracked_node := tracked_object as Node2D

	if tracked_node != null and is_instance_valid(tracked_node):
		if tracked_node.is_inside_tree():
			return tracked_node.global_position.round()

	return fallback.round()


func _r3_run_dive_salvo(
	destinations: Array[Vector2],
	tracking_ids: Array[int],
	tier: int,
	stagger: float,
	impact_radius: float,
	launch_from_hunter: bool = true
) -> void:
	if destinations.is_empty():
		return

	var core := Color(1.55, 2.75, 3.25, 1.0)
	var glow := Color(0.2, 0.8, 1.5, 1.0)
	var trail_glow := Color(0.16, 0.65, 1.35, 0.24)

	# Phase one: the rack kicks missiles upward. They leave the immediate ground
	# plane first, so the later top-down strike reads as an actual dive attack.
	if launch_from_hunter:
		var launch_time := 0.105
		var launch_heads: Array = []

		for i in range(destinations.size()):
			var lateral := IsoVfx.ground_perpendicular_offset(
				direction,
				(float(i) - float(destinations.size() - 1) * 0.5) * 2.2
			)
			var launch_start := (origin + lateral).round()
			var launch_end := (
				launch_start
				+ Vector2(
					float((i % 3) - 1) * 5.0,
					-72.0 - float(i % 2) * 10.0
				)
			).round()

			var launch_head := ProjectileFxScript.new() as SpacehaulSpecialProjectile
			root.add_child(launch_head)
			launch_head.setup(
				launch_start,
				core,
				glow,
				1.0,
				true
			)
			launch_heads.append(launch_head)

			_spawn_follow_particles(
				launch_head,
				core,
				glow,
				launch_time + 0.05,
				66.0
			)

			var launch_trail := _line(
				launch_start,
				launch_end,
				Color(core.r, core.g, core.b, 0.78),
				trail_glow
			)
			_fade_free(launch_trail, launch_time + 0.04)

			var tween := root.create_tween()
			tween.tween_property(
				launch_head,
				"global_position",
				launch_end,
				launch_time
			)
			tween.tween_property(
				launch_head,
				"modulate:a",
				0.0,
				0.035
			)
			tween.tween_callback(launch_head.queue_free)

			await _sleep(0.012)

		await _sleep(launch_time * 0.72)

	# Phase two: missiles re-enter from above. Each projectile owns a persistent
	# growing trail and can continue following its originally acquired enemy.
	var count := destinations.size()
	var dive_nodes: Array = []
	var dive_trails: Array = []
	var dive_starts: Array[Vector2] = []
	var started: Array[bool] = []
	var impacted: Array[bool] = []

	for i in range(count):
		dive_nodes.append(null)
		dive_trails.append(null)
		dive_starts.append(Vector2.ZERO)
		started.append(false)
		impacted.append(false)

	var elapsed := 0.0
	var dive_time := maxf(0.15, 0.205 - float(tier) * 0.008)
	var total_time := stagger * float(maxi(0, count - 1)) + dive_time + 0.06

	while elapsed < total_time:
		await get_tree().process_frame
		elapsed += get_process_delta_time()

		for i in range(count):
			var delay := stagger * float(i)

			if elapsed < delay:
				continue

			var tracking_id := 0
			if i < tracking_ids.size():
				tracking_id = tracking_ids[i]

			var live_dest := _r3_resolve_target_position(
				tracking_id,
				destinations[i]
			)

			if not started[i]:
				started[i] = true

				var sky_start := (
					live_dest
					+ Vector2(
						float((i % 3) - 1) * (15.0 + float(tier) * 2.0),
						-132.0 - float(i % 2) * 14.0
					)
				).round()

				dive_starts[i] = sky_start

				# The tiny deck marker appears just before the missile begins its
				# descent, making each strike readable without slowing the salvo.
				_show_target_lock(
					live_dest,
					Color(1.35, 2.7, 3.3, 0.92),
					Color(0.18, 0.78, 1.5, 0.75)
				)

				var missile := ProjectileFxScript.new() as SpacehaulSpecialProjectile
				root.add_child(missile)
				missile.setup(
					sky_start,
					core,
					glow,
					1.0 + float(tier) * 0.04,
					true
				)
				dive_nodes[i] = missile

				_spawn_follow_particles(
					missile,
					core,
					glow,
					dive_time + 0.08,
					74.0 + float(tier) * 4.0
				)

				var trail := _line(
					sky_start,
					sky_start,
					Color(core.r, core.g, core.b, 0.90),
					trail_glow
				)
				dive_trails[i] = trail

			if impacted[i]:
				continue

			var local_t := clampf(
				(elapsed - delay) / maxf(dive_time, 0.001),
				0.0,
				1.0
			)

			# Accelerate into the deck so the strike feels like a powered terminal
			# dive instead of a projectile simply tweening at constant speed.
			var dive_t := local_t * local_t
			var p := dive_starts[i].lerp(live_dest, dive_t).round()

			var missile_node := dive_nodes[i] as Node2D
			if missile_node != null and is_instance_valid(missile_node):
				missile_node.global_position = p

			var trail_node := dive_trails[i] as Node2D
			if trail_node != null and is_instance_valid(trail_node):
				for child in trail_node.get_children():
					var line := child as Line2D
					if line != null and line.get_point_count() >= 2:
						line.set_point_position(1, p)

			if local_t >= 1.0:
				impacted[i] = true

				if missile_node != null and is_instance_valid(missile_node):
					missile_node.queue_free()

				if trail_node != null and is_instance_valid(trail_node):
					_fade_free(trail_node, 0.11)

				_explode(
					live_dest,
					core,
					glow,
					impact_radius,
					impact_radius
				)

				_spark_pixels(
					live_dest,
					Color(1.8, 3.0, 3.35, 1.0),
					glow,
					4 + tier,
					12.0 + float(tier) * 2.0,
					0.19
				)

	# Defensive cleanup if a scene transition or unusually large frame step left
	# any visual node alive after the salvo's intended lifetime.
	for i in range(count):
		if i < dive_nodes.size():
			var missile_ref = dive_nodes[i]

			if is_instance_valid(missile_ref):
				var missile_node := missile_ref as Node2D

				if missile_node != null:
					missile_node.queue_free()

			dive_nodes[i] = null

		if i < dive_trails.size():
			var trail_ref = dive_trails[i]

			if is_instance_valid(trail_ref):
				var trail_node := trail_ref as Node2D

				if trail_node != null:
					_fade_free(trail_node, 0.08)

			dive_trails[i] = null


func _r3_swarm_rack() -> void:
	var tier := primary_tier

	# Preserve Hunter's upgrade structure:
	# T0 = 3 missiles, T1 = 4, T2 = 5, T3 = 6 plus the longest lock range.
	var missile_count := 3 + tier
	var max_range := 275.0 + float(tier) * 12.0
	var secondary_lock_radius := 110.0 + float(tier) * 14.0

	var first_target := _nearest_enemy_to_aim(
		target,
		84.0,
		max_range
	)

	var primary_target_position := _target_clamped(max_range)
	var used_targets: Dictionary = {}
	var destinations: Array[Vector2] = []
	var tracking_ids: Array[int] = []

	if first_target != null and is_instance_valid(first_target):
		primary_target_position = first_target.global_position.round()
		used_targets[first_target.get_instance_id()] = true

		_show_target_lock(
			primary_target_position,
			Color(1.6, 2.9, 3.35, 1.0),
			Color(0.2, 0.85, 1.55, 1.0)
		)

	for i in range(missile_count):
		var selected_enemy: Node2D = null
		var tracking_target_id := 0
		var dest := primary_target_position

		if i == 0:
			if first_target != null and is_instance_valid(first_target):
				selected_enemy = first_target
		else:
			selected_enemy = _nearest_unused_enemy(
				primary_target_position,
				secondary_lock_radius,
				max_range,
				used_targets
			)

			if selected_enemy == null:
				selected_enemy = _nearest_unused_enemy(
					primary_target_position,
					max_range,
					max_range,
					used_targets
				)

		if selected_enemy != null and is_instance_valid(selected_enemy):
			tracking_target_id = selected_enemy.get_instance_id()
			used_targets[tracking_target_id] = true
			dest = selected_enemy.global_position.round()

			if i > 0:
				_show_target_lock(
					dest,
					Color(1.15, 2.5, 3.15, 0.82),
					Color(0.15, 0.65, 1.35, 0.65)
				)
		else:
			# If unique locks are exhausted, unused missiles still dive into a
			# small isometric spread around the player's aimed impact point.
			var angle := TAU * float(i) / float(maxi(1, missile_count))
			var offset_radius := (
				0.0
				if i == 0
				else 8.0 + float(tier) * 2.0 + float(i % 2) * 5.0
			)

			dest = (
				primary_target_position
				+ IsoVfx.ground_offset(angle, offset_radius)
			).round()

		destinations.append(dest)
		tracking_ids.append(tracking_target_id)

	await _r3_run_dive_salvo(
		destinations,
		tracking_ids,
		tier,
		0.034,
		12.0 + float(tier),
		true
	)


# R3 SECONDARY: MISSILE HALO / SATURATION BOMBARDMENT
# The old circumference-only halo is replaced by a staggered field bombardment.
# Missiles occupy the entire annulus around Hunter while keeping its center clear.
func _r3_flak_dome() -> void:
	var tier := secondary_tier
	var missile_count := 8 + tier * 2
	var radius := 72.0 + float(tier) * 10.0
	var safe_radius := 27.0

	var destinations: Array[Vector2] = []
	var tracking_ids: Array[int] = []

	# Telegraph both the protected center and the maximum saturation radius.
	_pulse_ring(
		owner_ground,
		safe_radius,
		Color(1.55, 2.85, 3.3, 0.88),
		Color(0.2, 0.8, 1.5, 0.18),
		0.20,
		18 + tier * 2
	)

	_pulse_ring(
		owner_ground,
		radius,
		Color(1.2, 2.75, 3.25, 0.78),
		Color(0.18, 0.72, 1.45, 0.16),
		0.22,
		28 + tier * 4,
		0.11
	)

	# Golden-angle placement gives even coverage across the usable annulus instead
	# of putting every impact on the outside circumference. Because radius rises
	# as the salvo index rises, the stagger produces a readable outward rolling
	# bombardment while still feeling irregular enough to be a missile strike.
	var golden_angle := 2.39996323
	var inner := safe_radius + 15.0
	var outer := radius

	for i in range(missile_count):
		var fraction := float(i + 1) / float(missile_count + 1)

		# sqrt distributes points by AREA rather than clustering everything near
		# Hunter or the perimeter.
		var radial_t := sqrt(fraction)
		var strike_radius := lerpf(inner, outer, radial_t)

		# Small seeded jitter breaks the mathematical spiral without sacrificing
		# the even field coverage that makes this better than the old halo.
		strike_radius *= _rng.randf_range(0.92, 1.03)

		var angle := (
			float(i) * golden_angle
			+ float(tier) * 0.17
			+ _rng.randf_range(-0.10, 0.10)
		)

		var dest := IsoVfx.ground_point(
			owner_ground,
			angle,
			strike_radius
		).round()

		destinations.append(dest)
		tracking_ids.append(0)

	await _r3_run_dive_salvo(
		destinations,
		tracking_ids,
		tier,
		maxf(0.026, 0.044 - float(tier) * 0.003),
		10.0 + float(tier),
		true
	)

	# Max tier finishes with a visible perimeter concussion, preserving the idea
	# that HUNTER VI / HALO IV owns more space without dropping a strike on Hunter.
	if tier >= 3:
		await _sleep(0.045)

		_pulse_ring(
			owner_ground,
			radius + 8.0,
			Color(1.7, 3.0, 3.35, 1.0),
			Color(0.22, 0.85, 1.55, 0.22),
			0.20,
			40
		)

		var finish_count := 8
		for i in range(finish_count):
			var angle := TAU * float(i) / float(finish_count) + 0.22
			var edge := IsoVfx.ground_point(
				owner_ground,
				angle,
				radius + 8.0
			).round()

			_ability_impact_fx(
				edge,
				Color(1.8, 3.0, 3.35, 1.0),
				Color(0.2, 0.85, 1.55, 1.0),
				8.0
			)

			await _sleep(0.014)


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
			ring_points.append(IsoVfx.ground_point(owner_ground, angle, radius + jitter).round())
		var ring := _polyline(ring_points, Color(2.6, 1.5, 3.35, 1.0), Color(1.0, 0.25, 1.7, 0.28))
		ring.z_index = clampi(int(round(owner_ground.y)) + 4, -3000, 3000)
		_radial_hit(owner_ground, radius + 8.0, true)
		for i in range(0, point_count, 4):
			_explode(ring_points[i], Color(2.5, 1.3, 3.2, 1.0), Color(1.0, 0.25, 1.7, 1.0), 8.0, 8.0)
		_fade_free(ring, 0.16)
		await _sleep(0.07)

# S1 PRIMARY: PHOTON RAKE
# SOLARIS sweeps a bank of projected photon cutters across the deck. Each lane
# visibly grows from the chassis instead of appearing at full length at once.
func _s1_project_photon_cut(
	start: Vector2,
	end: Vector2,
	tier: int,
	overburn: bool = false
) -> void:
	var core := (
		Color(3.25, 1.35, 0.62, 1.0)
		if overburn
		else Color(3.0, 0.72, 0.52, 1.0)
	)
	var glow := (
		Color(1.7, 0.42, 0.10, 1.0)
		if overburn
		else Color(1.5, 0.22, 0.12, 1.0)
	)

	var head := ProjectileFxScript.new() as SpacehaulSpecialProjectile
	root.add_child(head)
	head.setup(
		start.round(),
		core,
		glow,
		1.30 if overburn else 1.05,
		true
	)

	var travel_time := maxf(
		0.050,
		(0.072 if overburn else 0.082) - float(tier) * 0.005
	)

	_spawn_follow_particles(
		head,
		core,
		glow,
		travel_time + 0.06,
		78.0 if overburn else 64.0
	)

	var beam := _line(
		start,
		start,
		core,
		Color(glow.r, glow.g, glow.b, 0.26 if overburn else 0.20)
	)

	var steps := 8
	for step in range(steps):
		var t := float(step + 1) / float(steps)
		var travel_t := 1.0 - pow(1.0 - t, 2.1)
		var current := start.lerp(end, travel_t).round()

		if is_instance_valid(head):
			head.global_position = current

		if is_instance_valid(beam):
			for child in beam.get_children():
				var line := child as Line2D
				if line != null and line.get_point_count() >= 2:
					line.set_point_position(1, current)

		await _sleep(travel_time / float(steps))

	if is_instance_valid(head):
		head.queue_free()

	_damage_line(
		start,
		end,
		5.0 + float(tier) * 0.35 + (1.0 if overburn else 0.0)
	)

	_explode(
		end,
		Color(3.25, 1.35, 0.48, 1.0) if overburn else Color(3.0, 0.82, 0.42, 1.0),
		Color(1.7, 0.38, 0.08, 1.0) if overburn else Color(1.5, 0.22, 0.10, 1.0),
		11.0 + float(tier) + (2.0 if overburn else 0.0),
		10.0 + float(tier) + (2.0 if overburn else 0.0)
	)

	if is_instance_valid(beam):
		_fade_free(beam, 0.14 if overburn else 0.12)


func _s1_photon_rake() -> void:
	var tier := primary_tier
	var beam_count := 3 + tier * 2
	var reach := 206.0 + float(tier) * 14.0
	var spacing := 6.0

	# Sweep cleanly from one side of the chassis to the other so PHOTON RAKE
	# reads as an actual cutting pass instead of several simultaneous tracers.
	for i in range(beam_count):
		var offset := (
			float(i) - float(beam_count - 1) * 0.5
		) * spacing

		var lateral := IsoVfx.ground_perpendicular_offset(
			direction,
			offset
		)

		var start := (origin + lateral).round()
		var end := (
			start
			+ IsoVfx.ground_vector(
				direction,
				reach
			)
		).round()

		await _s1_project_photon_cut(
			start,
			end,
			tier,
			false
		)

	# Tier 2+ gains a hotter overburn pass down the center. Tier 3 splits that
	# follow-up into two close rails, giving the final upgrade a distinct finish
	# without changing the weapon's forward-raking identity.
	if tier >= 2:
		await _sleep(0.025)

		var overburn_count := 1 if tier == 2 else 2
		for i in range(overburn_count):
			var offset := 0.0

			if overburn_count > 1:
				offset = (
					float(i) - float(overburn_count - 1) * 0.5
				) * 7.0

			var lateral := IsoVfx.ground_perpendicular_offset(
				direction,
				offset
			)

			var start := (origin + lateral).round()
			var end := (
				start
				+ IsoVfx.ground_vector(
					direction,
					reach + 18.0 + float(tier) * 3.0
				)
			).round()

			await _s1_project_photon_cut(
				start,
				end,
				tier,
				true
			)


# S1 SECONDARY: SOLAR FLARE
# The flare now behaves like a stellar eruption: a bright core ignites first,
# then a projected corona expands across the isometric ground while localized
# solar eruptions break along the moving wavefront.
func _s1_solar_corona_wave(
	max_radius: float,
	eruption_count: int,
	tier: int,
	overcharged: bool = false
) -> void:
	var core := (
		Color(3.35, 2.15, 0.78, 1.0)
		if overcharged
		else Color(3.15, 1.45, 0.58, 1.0)
	)
	var glow := (
		Color(1.8, 0.62, 0.08, 1.0)
		if overcharged
		else Color(1.55, 0.32, 0.08, 1.0)
	)

	var steps := 12
	var emitted := 0
	var safe_count := maxi(1, eruption_count)
	var golden_angle := 2.399963229728653
	var phase := 0.31 if overcharged else 0.0

	for step in range(steps):
		var t := float(step + 1) / float(steps)
		var wave_t := 1.0 - pow(1.0 - t, 2.0)
		var radius := lerpf(
			18.0,
			max_radius,
			wave_t
		)

		_pulse_ring(
			owner_ground,
			radius,
			core,
			Color(glow.r, glow.g, glow.b, 0.23),
			0.075,
			26 + tier * 4 + (6 if overcharged else 0),
			phase + float(step) * 0.035
		)

		# Spread the requested eruption count across the full life of the moving
		# corona. The golden-angle phase prevents the impacts from collapsing into
		# obvious spokes or only decorating the final circumference.
		var target_emitted := mini(
			safe_count,
			int(ceil(float(safe_count) * t))
		)

		while emitted < target_emitted:
			var angle := (
				phase
				+ float(emitted) * golden_angle
				+ _rng.randf_range(-0.10, 0.10)
			)

			var blast_radius := clampf(
				radius + _rng.randf_range(-6.0, 6.0),
				18.0,
				max_radius
			)

			var blast_point := IsoVfx.ground_point(
				owner_ground,
				angle,
				blast_radius
			).round()

			_ability_impact_fx(
				blast_point,
				core,
				glow,
				7.0 + float(tier) * 0.8 + (1.5 if overcharged else 0.0)
			)

			if emitted % 3 == 0:
				_spark_pixels(
					blast_point,
					core,
					glow,
					3 + (1 if overcharged else 0),
					12.0 + float(tier) * 2.0,
					0.18
				)

			emitted += 1

		await _sleep(0.018)

	# Gameplay damage is applied once when the visible wave reaches its maximum
	# extent, so the many visual eruptions do not secretly multiply damage.
	_radial_hit(
		owner_ground,
		max_radius,
		true
	)


func _s1_solar_flare() -> void:
	var tier := secondary_tier

	# Preserve SOLAR FLARE's existing upgrade scale:
	# T0/T1/T2/T3 = 8/12/16/20 eruption points and +11 radius per tier.
	var beam_count := 8 + tier * 4
	var radius := 78.0 + float(tier) * 11.0

	# Core ignition.
	_explode(
		owner_ground,
		Color(3.35, 2.25, 0.72, 1.0),
		Color(1.75, 0.58, 0.08, 1.0),
		18.0 + float(tier),
		18.0 + float(tier)
	)

	_pulse_ring(
		owner_ground,
		24.0,
		Color(3.4, 2.3, 0.82, 1.0),
		Color(1.7, 0.52, 0.08, 0.24),
		0.14,
		20 + tier * 2
	)

	await _sleep(0.035)

	# Main expanding corona.
	await _s1_solar_corona_wave(
		radius,
		beam_count,
		tier,
		false
	)

	# Tier 2: a hotter delayed echo rolls beyond the first corona.
	if tier >= 2:
		await _sleep(0.045)

		await _s1_solar_corona_wave(
			radius + 14.0,
			maxi(7, int(round(float(beam_count) * 0.58))),
			tier,
			true
		)

	# Tier 3: the final upgrade ends with one last oversized coronal pulse,
	# giving SOLARIS a true screen-clearing stellar finish.
	if tier >= 3:
		await _sleep(0.04)

		await _s1_solar_corona_wave(
			radius + 28.0,
			maxi(8, int(round(float(beam_count) * 0.45))),
			tier,
			true
		)


# S2 / PHANTOM: GRAVITY COLLAPSE
# Pulls a visible shell of captured mass inward before resolving the gameplay pull.
# The VFX carries the motion; damage/control is applied only at the completed collapse
# so the extra particles do not multiply hits.
func _s2_gravity_collapse(
	center: Vector2,
	radius: float,
	tier: int,
	overcharged: bool = false
) -> void:
	var core := (
		Color(1.65, 2.95, 3.55, 1.0)
		if overcharged
		else Color(1.05, 2.45, 3.35, 1.0)
	)
	var glow := (
		Color(0.24, 0.80, 1.75, 1.0)
		if overcharged
		else Color(0.16, 0.62, 1.50, 1.0)
	)

	var mote_count := 8 + tier * 3 + (4 if overcharged else 0)
	var starts: Array[Vector2] = []
	var motes: Array[Node2D] = []
	var phase := 0.18 if overcharged else 0.0

	for i in range(mote_count):
		var angle := (
			phase
			+ TAU * float(i) / float(mote_count)
			+ _rng.randf_range(-0.08, 0.08)
		)
		var start_radius := radius * _rng.randf_range(0.78, 1.0)
		var start := IsoVfx.ground_point(
			center,
			angle,
			start_radius
		).round()

		starts.append(start)

		var mote := ProjectileFxScript.new() as SpacehaulSpecialProjectile
		root.add_child(mote)
		mote.setup(start, core, glow, 1.0, true)
		motes.append(mote)

		if i % 2 == 0:
			_spawn_follow_particles(
				mote,
				core,
				glow,
				0.28,
				42.0 + float(tier) * 4.0
			)

	var steps := 10 + tier

	for step in range(steps):
		var t := float(step + 1) / float(steps)
		var collapse_t := t * t
		var ring_radius := lerpf(radius, 10.0, collapse_t)

		_pulse_ring(
			center,
			ring_radius,
			core,
			Color(glow.r, glow.g, glow.b, 0.20),
			0.075,
			24 + tier * 4 + (6 if overcharged else 0),
			phase + float(step) * 0.04
		)

		for i in range(motes.size()):
			if not is_instance_valid(motes[i]):
				continue

			var spiral_offset := IsoVfx.ground_offset(
				phase + float(i) * 0.72 + float(step) * 0.18,
				lerpf(5.0, 1.0, collapse_t)
			)

			motes[i].global_position = (
				starts[i].lerp(center, collapse_t)
				+ spiral_offset
			).round()

		await _sleep(0.018)

	_radial_hit(center, radius, false)

	_ability_impact_fx(
		center,
		core,
		glow,
		10.0 + float(tier) * 1.5 + (3.0 if overcharged else 0.0)
	)

	for mote in motes:
		if is_instance_valid(mote):
			mote.queue_free()


# S2 PRIMARY: GRAVITY WELL
# PHANTOM fires a gravity seed, then the battlefield visibly caves inward around it.
func _s2_gravity_well() -> void:
	var tier := primary_tier
	var max_range := 205.0 + float(tier) * 16.0

	var locked_target := _nearest_enemy_to_aim(
		target,
		76.0,
		max_range
	)

	var tracking_target_id := 0
	var dest := _target_clamped(max_range)

	if locked_target != null and is_instance_valid(locked_target):
		tracking_target_id = locked_target.get_instance_id()
		dest = locked_target.global_position.round()

		_show_target_lock(
			dest,
			Color(1.2, 2.7, 3.4, 1.0),
			Color(0.2, 0.7, 1.6, 1.0)
		)

	# The gravity seed is still a real projectile, preserving the aimed/locked
	# primary identity while making the impact only the beginning of the attack.
	dest = await _arc_shot_from(
		origin,
		dest,
		38.0 + float(tier) * 7.0,
		0.24,
		Color(1.1, 2.35, 3.25, 1.0),
		Color(0.18, 0.65, 1.5, 1.0),
		9.0,
		tracking_target_id
	)

	var radius := 58.0 + float(tier) * 12.0

	await _s2_gravity_collapse(
		dest,
		radius,
		tier,
		false
	)

	await _sleep(0.045)

	# The singularity snaps shut after the visible pull.
	_explode(
		dest,
		Color(1.45, 2.75, 3.35, 1.0),
		Color(0.2, 0.7, 1.55, 1.0),
		18.0 + float(tier) * 2.0,
		20.0 + float(tier) * 4.0
	)

	# Tier 3 folds the field a second time instead of merely making the same
	# collapse larger. This gives the final upgrade a distinct double-implosion beat.
	if tier >= 3:
		await _sleep(0.055)

		await _s2_gravity_collapse(
			dest,
			radius * 0.82,
			tier,
			true
		)

		_explode(
			dest,
			Color(1.8, 3.0, 3.5, 1.0),
			Color(0.2, 0.75, 1.65, 1.0),
			16.0,
			19.0
		)


# S2 / PHANTOM: MASS EJECTION WAVE
# Captured mass is slung from the collapsed core behind a growing gravity front.
func _s2_mass_ejection_wave(
	max_radius: float,
	tier: int,
	overcharged: bool = false
) -> void:
	var core := (
		Color(1.8, 3.05, 3.55, 1.0)
		if overcharged
		else Color(1.35, 2.75, 3.40, 1.0)
	)
	var glow := (
		Color(0.28, 0.85, 1.75, 1.0)
		if overcharged
		else Color(0.18, 0.66, 1.55, 1.0)
	)

	var shard_count := 10 + tier * 4 + (4 if overcharged else 0)
	var endpoints: Array[Vector2] = []
	var shards: Array[Node2D] = []
	var phase := 0.22 if overcharged else 0.0
	var start_radius := 12.0

	for i in range(shard_count):
		var angle := (
			phase
			+ TAU * float(i) / float(shard_count)
			+ _rng.randf_range(-0.055, 0.055)
		)
		var endpoint := IsoVfx.ground_point(
			owner_ground,
			angle,
			max_radius * _rng.randf_range(0.88, 1.0)
		).round()
		var start := IsoVfx.ground_point(
			owner_ground,
			angle,
			start_radius
		).round()

		endpoints.append(endpoint)

		var shard := ProjectileFxScript.new() as SpacehaulSpecialProjectile
		root.add_child(shard)
		shard.setup(start, core, glow, 1.0, true)
		shards.append(shard)

		if i % 2 == 0:
			_spawn_follow_particles(
				shard,
				core,
				glow,
				0.26,
				46.0 + float(tier) * 4.0
			)

	var steps := 11

	for step in range(steps):
		var t := float(step + 1) / float(steps)
		var blast_t := 1.0 - pow(1.0 - t, 2.25)
		var ring_radius := lerpf(start_radius, max_radius, blast_t)

		_pulse_ring(
			owner_ground,
			ring_radius,
			core,
			Color(glow.r, glow.g, glow.b, 0.21),
			0.075,
			26 + tier * 4 + (6 if overcharged else 0),
			phase + float(step) * 0.035
		)

		for i in range(shards.size()):
			if not is_instance_valid(shards[i]):
				continue

			var start := IsoVfx.ground_point(
				owner_ground,
				phase + TAU * float(i) / float(shard_count),
				start_radius
			)

			shards[i].global_position = start.lerp(
				endpoints[i],
				blast_t
			).round()

		await _sleep(0.018)

	# Gameplay resolves once, when the visible mass front reaches its full radius.
	_radial_hit(owner_ground, max_radius, true)

	var impact_stride := maxi(1, int(round(float(shard_count) / 9.0)))

	for i in range(endpoints.size()):
		if i % impact_stride == 0:
			_ability_impact_fx(
				endpoints[i],
				core,
				glow,
				7.0 + float(tier) * 0.8 + (2.0 if overcharged else 0.0)
			)

		if i < shards.size() and is_instance_valid(shards[i]):
			shards[i].queue_free()


# S2 SECONDARY: MASS EJECTION
# PHANTOM first compresses nearby enemies, then violently throws the captured mass out.
func _s2_mass_ejection() -> void:
	var tier := secondary_tier
	var radius := 76.0 + float(tier) * 14.0

	# Compression phase: the old three shrinking rings are now accompanied by
	# visible captured mass actually falling toward PHANTOM.
	await _s2_gravity_collapse(
		owner_ground,
		radius,
		tier,
		false
	)

	await _sleep(0.055)

	_explode(
		owner_ground,
		Color(1.5, 2.9, 3.45, 1.0),
		Color(0.2, 0.7, 1.6, 1.0),
		24.0 + float(tier) * 3.0,
		28.0 + float(tier) * 4.0
	)

	await _s2_mass_ejection_wave(
		radius + 10.0,
		tier,
		false
	)

	# Tier 2+ gets a visible residual gravity ripple after the first ejection.
	if tier >= 2:
		_pulse_ring(
			owner_ground,
			radius + 18.0,
			Color(1.5, 2.85, 3.45, 1.0),
			Color(0.2, 0.7, 1.6, 0.22),
			0.16,
			34 + tier * 4,
			0.18
		)

	# Tier 3 releases a second, rotated overcharged mass shell. It is delayed
	# enough to read as another eruption rather than a single oversized flash.
	if tier >= 3:
		await _sleep(0.055)

		await _s2_mass_ejection_wave(
			radius + 26.0,
			tier,
			true
		)


# S3 / SPIDER: PHASE NEEDLE VOLLEY
# All needles blink forward together, vanishing between short phase jumps instead
# of drawing complete trajectories instantly.
func _s3_phase_needle_volley(
	ends: Array[Vector2],
	tier: int,
	echo: bool = false
) -> void:
	if ends.is_empty():
		return

	var core := (
		Color(2.25, 2.85, 3.55, 1.0)
		if echo
		else Color(1.9, 2.5, 3.3, 1.0)
	)
	var glow := Color(0.55, 0.85, 1.8, 1.0)
	var heads: Array[Node2D] = []

	for i in range(ends.size()):
		var lateral_jitter := IsoVfx.ground_perpendicular_offset(
			direction,
			(float(i % 3) - 1.0) * (2.0 if echo else 1.0)
		)
		var start := (origin + lateral_jitter).round()

		var head := ProjectileFxScript.new() as SpacehaulSpecialProjectile
		root.add_child(head)
		head.setup(start, core, glow, 1.0, true)
		heads.append(head)

		if i % 2 == 0:
			_spawn_follow_particles(
				head,
				core,
				glow,
				0.24,
				40.0 + float(tier) * 4.0
			)

	var jumps := 4 + tier + (1 if echo else 0)
	var previous_positions: Array[Vector2] = []

	for i in range(ends.size()):
		previous_positions.append(origin.round())

	_pulse_ring(
		origin,
		6.0 + float(tier),
		core,
		Color(glow.r, glow.g, glow.b, 0.22),
		0.10,
		12 + tier * 2,
		0.14 if echo else 0.0
	)

	for jump in range(jumps):
		var t := float(jump + 1) / float(jumps)

		for i in range(ends.size()):
			if i >= heads.size() or not is_instance_valid(heads[i]):
				continue

			# A tiny alternating lateral offset makes the reappearance points feel
			# like spatial hops rather than a conventional straight projectile.
			var phase_offset := IsoVfx.ground_perpendicular_offset(
				direction,
				sin(float(jump + i) * 1.7) * (3.0 + float(tier))
			)
			var current := (
				origin.lerp(ends[i], t)
				+ phase_offset * (1.0 - t)
			).round()

			heads[i].visible = false

			_dotted_trace(
				previous_positions[i],
				current,
				Color(core.r, core.g, core.b, 0.78),
				Color(glow.r, glow.g, glow.b, 0.72),
				7.0,
				0.085
			)

			heads[i].global_position = current
			previous_positions[i] = current

		await _sleep(0.012)

		for head in heads:
			if is_instance_valid(head):
				head.visible = true

		await _sleep(0.012)

	# Resolve each original needle path once. The blink residue is presentation,
	# not extra hidden damage.
	for i in range(ends.size()):
		var end := ends[i]

		_damage_line(
			origin,
			end,
			3.0 + float(tier) * 0.5
		)

		_explode(
			end,
			Color(2.1, 2.7, 3.4, 1.0),
			glow,
			8.0 + float(tier) + (1.0 if echo else 0.0),
			8.0 + float(tier)
		)

		if i < heads.size() and is_instance_valid(heads[i]):
			heads[i].queue_free()


# S3 PRIMARY: PHASE NEEDLES
# SPIDER now fires a synchronized fan that repeatedly disappears and reappears downrange.
func _s3_phase_needles() -> void:
	var tier := primary_tier
	var shard_count := 5 + tier * 2
	var reach := 176.0 + float(tier) * 12.0
	var spread := deg_to_rad(48.0 + float(tier) * 6.0)
	var ends: Array[Vector2] = []

	for i in range(shard_count):
		var f := 0.0 if shard_count == 1 else (
			float(i) / float(shard_count - 1) - 0.5
		)
		var shard_offset := IsoVfx.ground_vector(
			direction,
			reach,
			f * spread
		)
		ends.append((origin + shard_offset).round())

	await _s3_phase_needle_volley(
		ends,
		tier,
		false
	)

	# Tier 3 leaves behind a smaller delayed echo volley, making the final phase
	# upgrade visibly "double image" without replacing the original fan identity.
	if tier >= 3:
		await _sleep(0.045)

		var echo_ends: Array[Vector2] = []
		var echo_count := 5

		for i in range(echo_count):
			var f := float(i) / float(echo_count - 1) - 0.5
			var echo_offset := IsoVfx.ground_vector(
				direction,
				reach + 20.0,
				f * spread * 0.72
			)
			echo_ends.append((origin + echo_offset).round())

		await _s3_phase_needle_volley(
			echo_ends,
			tier,
			true
		)


# S3 / SPIDER: PHASE WEB WAVE
# Builds inner and outer phase anchors, laces them together briefly, then detonates
# the web sequentially. Each upgrade increases anchor density and web complexity.
func _s3_phase_web_wave(
	radius: float,
	count: int,
	tier: int,
	wave_index: int
) -> void:
	var core := Color(1.9, 2.55, 3.35, 1.0)
	var glow := Color(0.55, 0.85, 1.8, 1.0)
	var phase := float(wave_index) * 0.19
	var outer_points := PackedVector2Array()
	var inner_points := PackedVector2Array()
	var anchors: Array[Node2D] = []

	for i in range(count):
		var angle := phase + TAU * float(i) / float(count)
		var outer := IsoVfx.ground_point(
			owner_ground,
			angle,
			radius
		).round()
		var inner := IsoVfx.ground_point(
			owner_ground,
			angle + PI / float(count),
			radius * 0.48
		).round()

		outer_points.append(outer)
		inner_points.append(inner)

		var anchor := ProjectileFxScript.new() as SpacehaulSpecialProjectile
		root.add_child(anchor)
		anchor.setup(owner_ground.round(), core, glow, 1.0, true)
		anchors.append(anchor)

	# Phase anchors first appear on the inner web, then blink to the outer web.
	for i in range(anchors.size()):
		if is_instance_valid(anchors[i]):
			anchors[i].global_position = inner_points[i]

	_pulse_ring(
		owner_ground,
		radius * 0.48,
		core,
		Color(glow.r, glow.g, glow.b, 0.18),
		0.10,
		count * 2,
		phase
	)

	await _sleep(0.035)

	for i in range(anchors.size()):
		if not is_instance_valid(anchors[i]):
			continue

		anchors[i].visible = false

		_dotted_trace(
			inner_points[i],
			outer_points[i],
			Color(core.r, core.g, core.b, 0.72),
			Color(glow.r, glow.g, glow.b, 0.70),
			8.0,
			0.09
		)

		anchors[i].global_position = outer_points[i]

	await _sleep(0.018)

	for anchor in anchors:
		if is_instance_valid(anchor):
			anchor.visible = true

	# Briefly reveal the web geometry. Max tier uses every strand; earlier tiers
	# intentionally leave gaps so upgrade density is visible, not only numerical.
	var outer_loop := PackedVector2Array(outer_points)
	outer_loop.append(outer_points[0])
	var inner_loop := PackedVector2Array(inner_points)
	inner_loop.append(inner_points[0])

	var outer_web := _polyline(
		outer_loop,
		core,
		Color(glow.r, glow.g, glow.b, 0.18)
	)
	var inner_web := _polyline(
		inner_loop,
		Color(1.7, 2.4, 3.3, 0.9),
		Color(glow.r, glow.g, glow.b, 0.14)
	)

	_fade_free(outer_web, 0.16)
	_fade_free(inner_web, 0.16)

	var strand_stride := 1 if tier >= 3 else 2
	var strands: Array[Node2D] = []

	for i in range(0, count, strand_stride):
		var next_inner := (i + 1) % count

		var spoke := _line(
			inner_points[i],
			outer_points[i],
			Color(1.9, 2.55, 3.35, 0.78),
			Color(glow.r, glow.g, glow.b, 0.13)
		)
		strands.append(spoke)

		var cross := _line(
			outer_points[i],
			inner_points[next_inner],
			Color(1.75, 2.45, 3.3, 0.70),
			Color(glow.r, glow.g, glow.b, 0.11)
		)
		strands.append(cross)

	# Preserve Phase Bloom's crowd-control identity with one radial gameplay hit.
	_radial_hit(
		owner_ground,
		radius,
		true
	)

	# Detonations chase around the web rather than appearing all at once.
	for i in range(count):
		if i % 3 == 0:
			_explode(
				outer_points[i],
				Color(2.0, 2.65, 3.4, 1.0),
				glow,
				8.0 + float(tier) * 0.5,
				8.0 + float(tier) * 0.5
			)
		else:
			_ability_impact_fx(
				outer_points[i],
				core,
				glow,
				6.0 + float(tier) * 0.35
			)

		await _sleep(0.010)

	for strand in strands:
		if is_instance_valid(strand):
			_fade_free(strand, 0.10)

	for anchor in anchors:
		if is_instance_valid(anchor):
			anchor.queue_free()


# S3 SECONDARY: PHASE BLOOM
# SPIDER blooms an expanding series of phase webs rather than simple perimeter rings.
func _s3_phase_bloom() -> void:
	var tier := secondary_tier
	var waves := 1 + tier

	for wave in range(waves):
		var radius := (
			58.0
			+ float(wave) * 18.0
			+ float(tier) * 8.0
		)
		var count := 8 + tier * 4

		await _s3_phase_web_wave(
			radius,
			count,
			tier,
			wave
		)

		await _sleep(0.045)
