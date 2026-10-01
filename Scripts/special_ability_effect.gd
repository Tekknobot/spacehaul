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
var legendary_mutation := ""
# Showroom mode reuses the real ability renderer inside a paused SubViewport.
# It disables combat queries/audio while preserving the authored VFX/timing.
var preview_mode := false
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
	new_secondary_tier: int = 0,
	new_legendary_mutation: String = ""
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
	legendary_mutation = new_legendary_mutation
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
				await _r1_prism_understrike()
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

	# RMB abilities are SPACEHAUL's emergency crowd-control layer. Preserve every
	# chassis-specific secondary effect, then finish by physically clearing the
	# occupied combat disk: surviving mobile enemies inside the authored ability
	# radius are pushed all the way toward that radius' perimeter. This is a
	# movement/control effect only; it does not add another hidden damage hit.
	if alternate:
		_push_enemies_to_perimeter(owner_ground, _secondary_perimeter_radius())

	queue_free()

func _sleep(seconds: float) -> void:
	await get_tree().create_timer(maxf(seconds, 0.001), preview_mode).timeout

# Returns the outer gameplay footprint for each RMB at its current upgrade tier.
# These values mirror the radii already authored by the individual secondary
# routines below, including their largest upgraded finishing wave where relevant.
func _secondary_perimeter_radius() -> float:
	var tier := secondary_tier
	match mecha_id:
		"M1":
			var waves := 1 + (1 if tier >= 2 else 0) + (1 if tier >= 3 else 0)
			return 64.0 + float(tier) * 10.0 + float(waves - 1) * 22.0
		"M2":
			var m2_radius := 72.0 + float(tier) * 14.0
			return m2_radius + (18.0 if tier >= 3 else 0.0)
		"M3":
			return 72.0 + float(tier) * 10.0
		"R1":
			return 76.0 + float(tier) * 10.0
		"R2":
			return 82.0 + float(tier) * 11.0
		"R3":
			return 72.0 + float(tier) * 10.0 + (8.0 if tier >= 3 else 0.0)
		"R4":
			var r4_waves := 2 + tier
			return 38.0 + float(r4_waves - 1) * (20.0 + float(tier) * 2.0) + 8.0
		"S1":
			var s1_radius := 78.0 + float(tier) * 11.0
			if tier >= 3:
				return s1_radius + 28.0
			if tier >= 2:
				return s1_radius + 14.0
			return s1_radius
		"S2":
			var s2_radius := 76.0 + float(tier) * 14.0
			if tier >= 3:
				return s2_radius + 26.0
			if tier >= 2:
				return s2_radius + 18.0
			return s2_radius + 10.0
		"S3":
			# Final web wave: 58 + wave*18 + tier*8, with wave == tier.
			return 58.0 + float(tier) * 26.0
		_:
			return 72.0

# Universal RMB crowd-control pass. We intentionally operate on the enemy group
# rather than dealing damage through another shape query: an enemy only needs to
# be inside the secondary's final footprint to be displaced. Stationary hazards
# such as Broodmother eggs do not implement receive_rmb_perimeter_push(), so they
# keep their authored in-place behavior.
func _push_enemies_to_perimeter(center: Vector2, radius: float) -> void:
	if preview_mode or radius <= 0.0 or get_tree() == null:
		return

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == null or not is_instance_valid(enemy):
			continue
		if not enemy.has_method("receive_rmb_perimeter_push"):
			continue

		var body := enemy as Node2D
		if body == null:
			continue
		if IsoVfx.ground_distance(center, body.global_position) > radius:
			continue

		enemy.call("receive_rmb_perimeter_push", center, radius)

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

# -----------------------------------------------------------------------------
# ISOMETRIC VFX DEPTH
# -----------------------------------------------------------------------------
# The mecha itself is sorted at ground Y + 2. Special abilities used to force
# nearly every generated CanvasItem onto fixed 1700-1800 layers, which meant a
# beam/ring/explosion could never pass behind the chassis. These helpers keep the
# authored 2D art but sort each visual from its ground footprint instead.
#
# This same code is used by the chassis showroom because preview_mode only
# disables combat queries/audio; owner_ground still represents the preview
# mecha's feet in the isolated SubViewport.
func _depth_y_for_point(point: Vector2) -> float:
	# Weapon origins are authored around the upper body (roughly 18 px above the
	# feet). Treat the exact muzzle/center as belonging to the chassis' ground
	# footprint so a shot fired "behind" the mecha can disappear behind the body
	# immediately instead of being sorted by the muzzle's elevated screen Y.
	if point.distance_squared_to(origin) <= 4.0:
		return owner_ground.y
	if point.distance_squared_to(owner_center) <= 4.0:
		return owner_ground.y
	return point.y

func _depth_index_for_y(depth_y: float, bias: int = 0) -> int:
	return clampi(int(round(depth_y)) + bias, -3000, 3000)

func _depth_index_for_point(point: Vector2, bias: int = 0) -> int:
	return _depth_index_for_y(_depth_y_for_point(point), bias)

func _set_fx_depth(node: Node2D, ground_point: Vector2, bias: int = 0) -> void:
	if node == null or not is_instance_valid(node):
		return
	node.z_as_relative = false
	node.z_index = _depth_index_for_point(ground_point, bias)

func _player_depth_boundary() -> float:
	# Matches MechaController._update_depth_order(): ground Y + 2.
	return owner_ground.y + 2.0

func _clear_depth_lines(container: Node2D) -> void:
	if container == null:
		return
	for child in container.get_children():
		if child is Line2D:
			container.remove_child(child)
			child.free()

func _make_depth_line_piece(
	container: Node2D,
	from: Vector2,
	to: Vector2,
	depth_from: Vector2,
	depth_to: Vector2,
	color: Color,
	glow_color: Color
) -> void:
	var average_depth_y := (
		_depth_y_for_point(depth_from)
		+ _depth_y_for_point(depth_to)
	) * 0.5
	var piece_z := _depth_index_for_y(average_depth_y)

	if glow_color.a > 0.0:
		var glow := Line2D.new()
		glow.width = BLOOM_PIXEL
		glow.default_color = glow_color
		glow.antialiased = false
		glow.use_parent_material = true
		glow.z_as_relative = false
		glow.z_index = piece_z
		glow.add_point(from.round())
		glow.add_point(to.round())
		container.add_child(glow)

	var core := Line2D.new()
	core.width = CORE_PIXEL
	core.default_color = color
	core.antialiased = false
	core.use_parent_material = true
	core.z_as_relative = false
	core.z_index = piece_z
	core.add_point(from.round())
	core.add_point(to.round())
	container.add_child(core)

func _append_depth_sorted_segment(
	container: Node2D,
	visual_from: Vector2,
	visual_to: Vector2,
	depth_from: Vector2,
	depth_to: Vector2,
	color: Color,
	glow_color: Color
) -> void:
	var a_depth := _depth_y_for_point(depth_from)
	var b_depth := _depth_y_for_point(depth_to)
	var normalized_depth_from := Vector2(depth_from.x, a_depth)
	var normalized_depth_to := Vector2(depth_to.x, b_depth)
	var boundary := _player_depth_boundary()

	# Split a trajectory exactly where it crosses the mecha's depth plane. That
	# lets one beam/ring/web strand render behind the chassis on its far half and
	# in front on its near half instead of assigning the entire line one layer.
	var crosses := (
		(a_depth < boundary and b_depth > boundary)
		or (a_depth > boundary and b_depth < boundary)
	)

	if crosses and absf(b_depth - a_depth) > 0.001:
		var split_t := clampf(
			(boundary - a_depth) / (b_depth - a_depth),
			0.0,
			1.0
		)
		var visual_split := visual_from.lerp(visual_to, split_t).round()
		var depth_split := normalized_depth_from.lerp(
			normalized_depth_to,
			split_t
		).round()

		_make_depth_line_piece(
			container,
			visual_from,
			visual_split,
			normalized_depth_from,
			depth_split,
			color,
			glow_color
		)
		_make_depth_line_piece(
			container,
			visual_split,
			visual_to,
			depth_split,
			normalized_depth_to,
			color,
			glow_color
		)
		return

	_make_depth_line_piece(
		container,
		visual_from,
		visual_to,
		normalized_depth_from,
		normalized_depth_to,
		color,
		glow_color
	)

func _refresh_depth_line(
	container: Node2D,
	from: Vector2,
	to: Vector2,
	color: Color,
	glow_color: Color
) -> void:
	if container == null or not is_instance_valid(container):
		return
	_clear_depth_lines(container)
	_append_depth_sorted_segment(
		container,
		from,
		to,
		from,
		to,
		color,
		glow_color
	)

func _refresh_depth_polyline(
	container: Node2D,
	visual_points: PackedVector2Array,
	color: Color,
	glow_color: Color
) -> void:
	_refresh_depth_polyline_with_depth(
		container,
		visual_points,
		color,
		glow_color,
		PackedVector2Array()
	)

func _refresh_depth_polyline_with_depth(
	container: Node2D,
	visual_points: PackedVector2Array,
	color: Color,
	glow_color: Color,
	depth_points: PackedVector2Array
) -> void:
	if container == null or not is_instance_valid(container):
		return
	_clear_depth_lines(container)

	if visual_points.size() < 2:
		return

	var use_custom_depth := depth_points.size() == visual_points.size()
	for i in range(visual_points.size() - 1):
		var depth_a := depth_points[i] if use_custom_depth else visual_points[i]
		var depth_b := depth_points[i + 1] if use_custom_depth else visual_points[i + 1]
		_append_depth_sorted_segment(
			container,
			visual_points[i],
			visual_points[i + 1],
			depth_a,
			depth_b,
			color,
			glow_color
		)

func _update_depth_line_endpoint(container: Node2D, to: Vector2) -> void:
	if container == null or not is_instance_valid(container):
		return
	if not container.has_meta("depth_line_from"):
		return
	var from: Vector2 = container.get_meta("depth_line_from")
	var core: Color = container.get_meta("depth_line_core")
	var glow: Color = container.get_meta("depth_line_glow")
	_refresh_depth_line(container, from, to.round(), core, glow)

func _path_depth_groups(points: PackedVector2Array) -> Array:
	var groups: Array = []
	if points.size() < 2:
		return groups

	var boundary := _player_depth_boundary()
	var active_points := PackedVector2Array()
	var active_front := false
	var has_active := false
	var active_length := 0.0

	for i in range(points.size() - 1):
		var a := points[i]
		var b := points[i + 1]
		var a_depth := _depth_y_for_point(a)
		var b_depth := _depth_y_for_point(b)
		var pieces: Array = []

		var crosses := (
			(a_depth < boundary and b_depth > boundary)
			or (a_depth > boundary and b_depth < boundary)
		)

		if crosses and absf(b_depth - a_depth) > 0.001:
			var split_t := clampf(
				(boundary - a_depth) / (b_depth - a_depth),
				0.0,
				1.0
			)
			var split := a.lerp(b, split_t).round()
			pieces.append(PackedVector2Array([a.round(), split]))
			pieces.append(PackedVector2Array([split, b.round()]))
		else:
			pieces.append(PackedVector2Array([a.round(), b.round()]))

		for piece in pieces:
			var piece_points: PackedVector2Array = piece
			var midpoint := piece_points[0].lerp(piece_points[1], 0.5)
			var front := _depth_y_for_point(midpoint) > boundary
			var piece_length := piece_points[0].distance_to(piece_points[1])

			if not has_active or front != active_front:
				if has_active and active_points.size() >= 2:
					groups.append({
						"points": active_points,
						"front": active_front,
						"length": active_length,
					})
				active_points = PackedVector2Array([
					piece_points[0],
					piece_points[1],
				])
				active_front = front
				active_length = piece_length
				has_active = true
			else:
				if active_points[active_points.size() - 1].distance_squared_to(piece_points[0]) > 0.25:
					active_points.append(piece_points[0])
				active_points.append(piece_points[1])
				active_length += piece_length

	if has_active and active_points.size() >= 2:
		groups.append({
			"points": active_points,
			"front": active_front,
			"length": active_length,
		})

	return groups

func _spawn_follow_particles(target_node: Node2D, core: Color, glow: Color, duration: float, rate: float = 52.0) -> void:
	if target_node == null or root == null:
		return
	var emitter := AbilityParticleScript.new() as SpacehaulAbilityParticles
	root.add_child(emitter)
	emitter.setup_follow(target_node, core, glow, _particle_profile(), duration, rate)
	# The spawning projectile/head has already been placed on the correct
	# isometric layer, so its attached trail begins on that exact layer too.
	emitter.z_as_relative = false
	emitter.z_index = target_node.z_index

func _spawn_path_particles(points: PackedVector2Array, core: Color, glow: Color, count: int = 7, life: float = 0.20) -> void:
	if root == null or points.size() < 2:
		return

	var groups := _path_depth_groups(points)
	if groups.is_empty():
		return

	var total_length := 0.0
	for group_value in groups:
		var group: Dictionary = group_value
		total_length += float(group.get("length", 0.0))
	total_length = maxf(total_length, 0.001)

	for group_value in groups:
		var group: Dictionary = group_value
		var group_points: PackedVector2Array = group.get("points", PackedVector2Array())
		if group_points.size() < 2:
			continue
		var group_length := float(group.get("length", 0.0))
		var group_count := clampi(
			int(round(float(count) * group_length / total_length)),
			2,
			maxi(2, count)
		)
		var emitter := AbilityParticleScript.new() as SpacehaulAbilityParticles
		root.add_child(emitter)
		emitter.setup_path(
			group_points,
			core,
			glow,
			_particle_profile(),
			group_count,
			life
		)

		var sample := group_points[0].lerp(
			group_points[group_points.size() - 1],
			0.5
		)
		var depth := _depth_index_for_point(sample)
		var player_depth := _depth_index_for_y(owner_ground.y + 2.0)
		if bool(group.get("front", false)):
			emitter.z_index = maxi(depth, player_depth + 1)
		else:
			emitter.z_index = mini(depth, player_depth - 1)
		emitter.z_as_relative = false

func _spawn_impact_particles(at: Vector2, core: Color, glow: Color, radius: float) -> void:
	if root == null:
		return
	var emitter := AbilityParticleScript.new() as SpacehaulAbilityParticles
	root.add_child(emitter)
	var count := clampi(int(round(radius * 0.42)), 5, 12)
	var speed := clampf(radius * 1.35, 18.0, 46.0)
	emitter.setup_burst(at.round(), core, glow, _particle_profile(), count, speed, 0.24)
	_set_fx_depth(emitter, at, 0)

func _line(from: Vector2, to: Vector2, color: Color, glow_color: Color = Color.TRANSPARENT) -> Node2D:
	var container := Node2D.new()
	container.z_as_relative = false
	container.z_index = 0
	root.add_child(container)

	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	container.material = additive

	container.set_meta("depth_line_from", from.round())
	container.set_meta("depth_line_core", color)
	container.set_meta("depth_line_glow", glow_color)

	_refresh_depth_line(
		container,
		from.round(),
		to.round(),
		color,
		glow_color
	)

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
	container.z_index = 0
	root.add_child(container)

	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	container.material = additive

	_refresh_depth_polyline(
		container,
		points,
		color,
		glow_color
	)

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
	shadow.z_index = _depth_index_for_point(at, -1)
	root.add_child(shadow)
	return shadow

func _pulse_ring(center: Vector2, radius: float, core: Color, glow: Color, life: float = 0.16, point_count: int = 32, phase: float = 0.0) -> Node2D:
	var points := PackedVector2Array()
	var count := maxi(8, point_count)
	for i in range(count + 1):
		var angle := phase + TAU * float(i) / float(count)
		points.append(IsoVfx.ground_point(center, angle, radius).round())
	var ring := _polyline(points, core, glow)
	# _polyline() depth-sorts every arc segment independently. The far half of a
	# ring can therefore disappear behind the chassis while the near half remains
	# visible in front, which is the isometric read we want.
	_fade_free(ring, life)
	return ring

func _spark_pixels(at: Vector2, core: Color, glow: Color, count: int, travel_radius: float, life: float = 0.22) -> void:
	for i in range(maxi(0, count)):
		var pixel := ProjectileFxScript.new() as SpacehaulSpecialProjectile
		root.add_child(pixel)
		pixel.setup(at, core, glow, 1.0, true)
		_set_fx_depth(pixel, at, 1)
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
		_set_fx_depth(pixel, p, 1)
		var tween := root.create_tween()
		tween.tween_property(pixel, "modulate:a", 0.0, life)
		tween.tween_callback(pixel.queue_free)

func _explode(at: Vector2, core: Color = Color(3.0, 1.5, 0.45, 1.0), glow: Color = Color(1.6, 0.45, 0.1, 1.0), radius: float = 18.0, hit_radius: float = 16.0) -> void:
	var fx := ExplosionScript.new() as SpacehaulSpecialExplosion
	root.add_child(fx)
	fx.setup(at.round(), core, glow, radius * impact_scale, 0.28, not preview_mode)
	_set_fx_depth(fx, at, 0)
	_spawn_impact_particles(at, core, glow, radius * impact_scale)
	_damage_radius(at, hit_radius * impact_scale, (at - owner_ground).normalized())

func _damage_radius(at: Vector2, radius: float, push_dir: Vector2) -> void:
	if preview_mode:
		return
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
	if preview_mode:
		return
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
	if preview_mode:
		return
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
	_set_fx_depth(projectile, Vector2(start.x, _depth_y_for_point(start)), 1)
	_spawn_follow_particles(projectile, core, glow, travel_time + 0.05, 58.0)

	var tracer := _line(
		start,
		dest,
		Color(core.r, core.g, core.b, 0.72),
		Color(glow.r, glow.g, glow.b, 0.22)
	)
	_fade_free(tracer, minf(0.12, travel_time))

	# The visible tracer is a real attack trajectory. Enemies touching it now
	# receive the same contact hit / explosion / directional knockback rule as
	# every other damaging line-based special ability.
	_damage_line(start, dest, 4.0)

	# A normal Tween can move the projectile, but it cannot update its isometric
	# depth as it crosses the chassis plane. Advance it explicitly so the shot can
	# start behind the mecha and emerge in front (or the reverse) during flight.
	var elapsed := 0.0
	var ground_start := Vector2(start.x, _depth_y_for_point(start))
	while elapsed < travel_time:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		var t := clampf(
			elapsed / maxf(travel_time, 0.001),
			0.0,
			1.0
		)
		var visual_p := start.lerp(dest, t).round()
		var depth_p := ground_start.lerp(dest, t).round()
		if is_instance_valid(projectile):
			projectile.global_position = visual_p
			_set_fx_depth(projectile, depth_p, 1)

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

	var ground_start := Vector2(start.x, _depth_y_for_point(start)).round()
	_set_fx_depth(projectile, ground_start, 1)
	_spawn_follow_particles(projectile, core, glow, travel_time + 0.08, 64.0)
	var ground_shadow := _make_arc_ground_shadow(ground_start)

	# The arc trail needs two coordinate sets: visual points rise above the deck,
	# while depth points remain on the projected ground path. Sorting by the
	# elevated Y would incorrectly make a high projectile appear "behind"
	# everything just because it moved upward on screen.
	var trail_container := Node2D.new()
	trail_container.z_as_relative = false
	trail_container.z_index = 0
	root.add_child(trail_container)
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	trail_container.material = additive

	var trail_visual_points := PackedVector2Array()
	var trail_depth_points := PackedVector2Array()
	trail_visual_points.append(start.round())
	trail_depth_points.append(ground_start)

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

		var ground_p := ground_start.lerp(live_dest, t).round()
		var p := start.lerp(live_dest, t)
		p.y -= sin(t * PI) * arc_height
		p = p.round()

		if is_instance_valid(projectile):
			projectile.global_position = p
			_set_fx_depth(projectile, ground_p, 1)

		if is_instance_valid(ground_shadow):
			var height_factor := sin(t * PI)
			ground_shadow.global_position = ground_p
			_set_fx_depth(ground_shadow, ground_p, -1)
			ground_shadow.scale = Vector2.ONE * lerpf(1.0, 0.62, height_factor)
			ground_shadow.modulate.a = lerpf(0.82, 0.38, height_factor)

		trail_visual_points.append(p)
		trail_depth_points.append(ground_p)
		if trail_visual_points.size() > 24:
			trail_visual_points.remove_at(0)
			trail_depth_points.remove_at(0)

		_refresh_depth_polyline_with_depth(
			trail_container,
			trail_visual_points,
			Color(core.r, core.g, core.b, 0.78),
			Color(glow.r, glow.g, glow.b, 0.24),
			trail_depth_points
		)

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
	if preview_mode:
		return null
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
	if preview_mode:
		points.append(target.round())
		return points
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
	radius: float,
	play_sound: bool = false
) -> void:
	var fx := ExplosionScript.new() as SpacehaulSpecialExplosion
	root.add_child(fx)

	# Most generated impact sprites are decorative members of a larger barrage, so
	# they stay silent by default. RMB abilities can opt one representative impact
	# into audio for each meaningful detonation beat without stacking dozens of
	# copies of the same explosion sample.
	fx.setup(
		at.round(),
		core,
		glow,
		radius * impact_scale,
		0.28,
		play_sound and not preview_mode
	)
	# Impact sprites use their deck contact point for depth. An explosion behind
	# the chassis now stays behind it instead of inheriting SpecialExplosion's
	# intentionally attention-grabbing +80 legacy offset.
	_set_fx_depth(fx, at, 0)

	_spawn_impact_particles(
		at,
		core,
		glow,
		radius * impact_scale
	)
		

# -----------------------------------------------------------------------------
# OMEGA LEGENDARY PRIMARY MUTATIONS — ROSTER EXPANSION
# Every chassis keeps its Tier III primary as the prerequisite, then replaces
# that attack with one of three geometry/rule-changing legendary behaviors.
# -----------------------------------------------------------------------------

# M2 PANTHER // VECTOR HARPOONS
func _m2_legendary_predator_grid(base_direction: Vector2) -> void:
	var saved_direction := direction
	for fan_angle in [-0.42, 0.0, 0.42]:
		direction = base_direction.rotated(float(fan_angle)).normalized()
		var ends: Array[Vector2] = []
		for i in range(5):
			var f := float(i) / 4.0 - 0.5
			ends.append((origin + IsoVfx.ground_vector(direction, 194.0, f * deg_to_rad(34.0))).round())
		await _m2_project_vector_harpoons(ends, 3, 0.11)
		await _sleep(0.018)
	direction = saved_direction
	_pulse_ring(owner_ground, 54.0, Color(1.55, 3.2, 3.45, 1.0), Color(0.18, 1.0, 1.55, 0.24), 0.16, 28)

func _m2_legendary_apex_reel(base_direction: Vector2) -> void:
	var ends: Array[Vector2] = []
	var count := 14
	for i in range(count):
		var angle := base_direction.angle() + TAU * float(i) / float(count)
		ends.append(IsoVfx.ground_point(owner_ground, angle, 154.0).round())
	await _m2_project_vector_harpoons(ends, 3, 0.14)
	_pulse_ring(owner_ground, 154.0, Color(1.45, 3.05, 3.4, 1.0), Color(0.2, 0.9, 1.6, 0.24), 0.15, 40)
	_radial_hit(owner_ground, 160.0, false)
	await _sleep(0.05)
	_explode(owner_ground, Color(2.0, 3.35, 3.5, 1.0), Color(0.2, 1.0, 1.65, 1.0), 30.0, 34.0)

func _m2_legendary_kill_lattice(base_direction: Vector2) -> void:
	var ends: Array[Vector2] = []
	for i in range(9):
		var f := float(i) / 8.0 - 0.5
		ends.append((origin + IsoVfx.ground_vector(base_direction, 208.0, f * deg_to_rad(56.0))).round())
	await _m2_project_vector_harpoons(ends, 3, 0.13)
	for stage in range(4):
		var t := 1.0 - float(stage) * 0.22
		for end in ends:
			var at := origin.lerp(end, t).round()
			_ability_impact_fx(at, Color(1.45, 3.1, 3.4, 1.0), Color(0.18, 0.95, 1.55, 1.0), 7.0 + float(stage))
			if stage == 2:
				_damage_line(end, origin, 5.0)
		await _sleep(0.028)
	_explode(owner_ground, Color(1.8, 3.3, 3.5, 1.0), Color(0.2, 1.0, 1.6, 1.0), 25.0, 28.0)

# M3 COMET // COMET MORTAR
func _m3_legendary_meteor_shower(base_direction: Vector2) -> void:
	var center := _target_clamped(286.0)
	_show_target_lock(center, Color(3.4, 2.1, 0.7, 1.0), Color(1.7, 0.42, 0.08, 1.0))
	for i in range(5):
		var angle := TAU * float(i) / 5.0 + 0.3
		var offset := Vector2.ZERO if i == 0 else IsoVfx.ground_offset(angle, 34.0 + float(i % 2) * 12.0)
		await _arc_shot_from(origin, (center + offset).round(), 92.0 + float(i) * 5.0, 0.16, Color(3.4, 1.55, 0.35, 1.0), Color(1.7, 0.38, 0.08, 1.0), 22.0)
		await _sleep(0.015)
	_pulse_ring(center, 64.0, Color(3.5, 2.2, 0.8, 1.0), Color(1.7, 0.45, 0.08, 0.24), 0.18, 34)

func _m3_legendary_cluster_sun(base_direction: Vector2) -> void:
	var dest := await _arc_shot_from(origin, _target_clamped(280.0), 112.0, 0.28, Color(3.6, 1.7, 0.38, 1.0), Color(1.8, 0.4, 0.08, 1.0), 34.0)
	_pulse_ring(dest, 74.0, Color(3.6, 2.3, 0.75, 1.0), Color(1.8, 0.45, 0.08, 0.25), 0.18, 40)
	for i in range(16):
		var angle := TAU * float(i) / 16.0
		var end := IsoVfx.ground_point(dest, angle, 76.0).round()
		var ray := _line(dest, end, Color(3.4, 1.65, 0.42, 0.95), Color(1.7, 0.38, 0.08, 0.18))
		_damage_line(dest, end, 4.5)
		_explode(end, Color(3.35, 1.45, 0.35, 1.0), Color(1.65, 0.34, 0.07, 1.0), 10.0, 10.0)
		_fade_free(ray, 0.13)

func _m3_legendary_comet_corridor(base_direction: Vector2) -> void:
	for i in range(7):
		var distance := 54.0 + float(i) * 33.0
		var lateral := IsoVfx.ground_perpendicular_offset(base_direction, sin(float(i) * 1.8) * 10.0)
		var dest := (origin + IsoVfx.ground_vector(base_direction, distance) + lateral).round()
		await _arc_shot_from(origin, dest, 58.0 + float(i) * 5.0, 0.105, Color(3.35, 1.45, 0.32, 1.0), Color(1.65, 0.35, 0.07, 1.0), 18.0 + float(i) * 1.2)
		await _sleep(0.012)

# R1 PRISM // PRISM UNDERSTRIKE
# PRISM is the inverse of HUNTER's dive attack. It designates remote deck space,
# then refracted energy erupts upward from the surface at alternating isometric
# angles. The mutation IDs remain unchanged because the upgrade system already
# stores those string keys, but none of these behaviors use the old lance shot.
func _r1_understrike_air_vector(index: int, tier: int, scale: float = 1.0) -> Vector2:
	# Keep PRISM's diagonal breach silhouette compact. The strike should read as a
	# violent eruption from the deck, not a full-height beam stretching off-screen.
	var side := -1.0 if index % 2 == 0 else 1.0
	var lateral := (
		16.0
		+ float(tier) * 2.0
		+ float(index % 3) * 2.5
	) * side
	var rise := 44.0 + float((index + tier) % 3) * 5.0
	return Vector2(lateral, -rise) * scale


func _r1_targeted_strike_position(
	aim_point: Vector2,
	search_radius: float,
	max_owner_range: float,
	excluded_ids: Dictionary,
	fallback: Vector2
) -> Vector2:
	# PRISM acquires targets the same way the roster's smart weapons do: prefer a
	# live enemy near the aimed area, do not spend two simultaneous breaches on the
	# same target, and preserve the authored pattern whenever no target is available.
	var enemy := _nearest_unused_enemy(
		aim_point,
		search_radius,
		max_owner_range,
		excluded_ids
	)

	if enemy == null or not is_instance_valid(enemy):
		return fallback.round()

	var enemy_id := enemy.get_instance_id()
	excluded_ids[enemy_id] = true
	var enemy_position := enemy.global_position.round()

	_show_target_lock(
		enemy_position,
		Color(1.45, 3.1, 3.45, 0.96),
		Color(0.2, 0.92, 1.58, 0.72)
	)

	return enemy_position


func _r1_prism_understrike_at(
	at: Vector2,
	air_vector: Vector2,
	tier: int,
	impact_radius: float,
	play_sound: bool = false,
	heavy: bool = false
) -> void:
	var strike_at := at.round()
	var core := Color(1.05, 2.95, 3.35, 1.0)
	var glow := Color(0.2, 0.92, 1.55, 1.0)
	var trail_glow := Color(0.16, 0.76, 1.45, 0.24)

	# Defensive clamp keeps every base/OMEGA variant inside the same compact visual
	# language, including older callers that still pass one of the taller vectors.
	var render_vector := air_vector * 0.78
	var max_render_length := 48.0 + (8.0 if heavy else 0.0)
	if render_vector.length() > max_render_length:
		render_vector = render_vector.normalized() * max_render_length
	var rise_end := (strike_at + render_vector).round()

	# The tell is deliberately tiny: enough to read the impact point without
	# turning a rapid primary into a slow telegraphed bombardment.
	_pulse_ring(
		strike_at,
		7.0 + float(tier) * 0.8 + (2.0 if heavy else 0.0),
		Color(1.55, 3.2, 3.45, 0.95),
		Color(0.2, 0.95, 1.6, 0.18),
		0.10,
		12
	)

	# Damage lives on the deck contact point. The rising streak is aerial VFX only,
	# so enemies are never damaged simply because their screen sprite overlaps it.
	_ability_impact_fx(
		strike_at,
		core,
		glow,
		impact_radius + (2.0 if heavy else 0.0),
		play_sound
	)

	var push_dir := (strike_at - owner_ground).normalized()
	if push_dir.length_squared() <= 0.001:
		push_dir = direction
	if push_dir.length_squared() <= 0.001:
		push_dir = Vector2.RIGHT

	_damage_radius(
		strike_at,
		impact_radius + (1.5 if heavy else 0.0),
		push_dir
	)

	_spark_pixels(
		strike_at,
		Color(1.65, 3.1, 3.4, 1.0),
		glow,
		(5 + tier) + (3 if heavy else 0),
		14.0 + float(tier) * 2.0 + (5.0 if heavy else 0.0),
		0.18
	)

	var head := ProjectileFxScript.new() as SpacehaulSpecialProjectile
	root.add_child(head)
	head.setup(
		strike_at,
		core,
		glow,
		1.0 + (0.15 if heavy else 0.0),
		true
	)
	_set_fx_depth(head, strike_at, 1)

	var rise_time := 0.082 + (0.018 if heavy else 0.0)
	_spawn_follow_particles(
		head,
		core,
		glow,
		rise_time + 0.07,
		70.0 + float(tier) * 4.0 + (10.0 if heavy else 0.0)
	)

	# Build the streak manually so its visual endpoint can rise into the air while
	# every segment remains depth-sorted from the same deck footprint.
	var streak := _line(
		strike_at,
		strike_at,
		Color(core.r, core.g, core.b, 0.92),
		trail_glow
	)

	var steps := 7
	for step in range(steps):
		var t := float(step + 1) / float(steps)
		var rise_t := 1.0 - pow(1.0 - t, 3.0)
		var p := strike_at.lerp(rise_end, rise_t).round()

		if is_instance_valid(head):
			head.global_position = p
			_set_fx_depth(head, strike_at, 1)

		if is_instance_valid(streak):
			_refresh_depth_polyline_with_depth(
				streak,
				PackedVector2Array([strike_at, p]),
				Color(core.r, core.g, core.b, 0.92),
				trail_glow,
				PackedVector2Array([strike_at, strike_at])
			)

		await _sleep(rise_time / float(steps))

	if heavy:
		_pulse_ring(
			strike_at,
			18.0 + float(tier) * 2.0,
			Color(1.7, 3.3, 3.5, 0.96),
			Color(0.2, 1.0, 1.65, 0.20),
			0.12,
			20
		)

	# Let the finished eruption hang for a beat before it disappears. This gives
	# the player time to read which enemy was struck while keeping the attack fast.
	var visual_hold := 1.105 + (0.035 if heavy else 0.0)

	if is_instance_valid(head):
		var head_tween := root.create_tween()
		head_tween.tween_interval(visual_hold)
		head_tween.tween_property(head, "modulate:a", 0.0, 0.065)
		head_tween.tween_callback(head.queue_free)

	if is_instance_valid(streak):
		var streak_tween := root.create_tween()
		streak_tween.tween_interval(visual_hold)
		streak_tween.tween_property(
			streak,
			"modulate:a",
			0.0,
			0.095 if not heavy else 0.12
		)
		streak_tween.tween_callback(streak.queue_free)


func _r1_legendary_prism_wall(base_direction: Vector2) -> void:
	var center := _target_clamped(252.0)
	var core := Color(1.35, 3.25, 3.5, 1.0)
	var glow := Color(0.2, 1.0, 1.65, 1.0)
	_show_target_lock(center, core, glow)

	# A transverse curtain of upward eruptions. It keeps the mutation's wall idea,
	# but the wall is now created by deck strikes instead of forward beam fire.
	var count := 9
	var targeted_ids: Dictionary = {}
	for i in range(count):
		var f := float(i) / float(count - 1) - 0.5
		var fallback := (
			center
			+ IsoVfx.ground_perpendicular_offset(base_direction, f * 112.0)
			+ IsoVfx.ground_vector(base_direction, absf(f) * 12.0)
		).round()
		var strike_at := _r1_targeted_strike_position(
			fallback,
			86.0,
			286.0,
			targeted_ids,
			fallback
		)
		await _r1_prism_understrike_at(
			strike_at,
			_r1_understrike_air_vector(i, 3, 1.08),
			3,
			12.0,
			i == 0,
			i == int(count / 2)
		)
		await _sleep(0.006)

	_pulse_ring(
		center,
		58.0,
		Color(1.7, 3.4, 3.55, 1.0),
		Color(0.2, 1.0, 1.6, 0.22),
		0.15,
		30
	)


func _r1_legendary_kaleidoscope(base_direction: Vector2) -> void:
	var center := _target_clamped(236.0)
	var core := Color(1.45, 3.15, 3.5, 1.0)
	var glow := Color(0.2, 0.95, 1.65, 1.0)
	_show_target_lock(center, core, glow)
	_pulse_ring(center, 52.0, core, Color(glow.r, glow.g, glow.b, 0.20), 0.15, 28)

	# Eight angled eruptions rotate around the designation, then the center punches
	# upward last. The alternating air vectors make the silhouette refract rather
	# than resemble HUNTER's parallel top-down dives.
	var count := 8
	var targeted_ids: Dictionary = {}
	for i in range(count):
		var angle := base_direction.angle() + TAU * float(i) / float(count)
		var fallback := IsoVfx.ground_point(center, angle, 46.0).round()
		var strike_at := _r1_targeted_strike_position(
			fallback,
			78.0,
			276.0,
			targeted_ids,
			fallback
		)
		var radial_sign := -1.0 if i % 2 == 0 else 1.0
		var air_vector := Vector2(
			(18.0 + float(i % 3) * 2.5) * radial_sign,
			-46.0 - float(i % 2) * 5.0
		)
		await _r1_prism_understrike_at(
			strike_at,
			air_vector,
			3,
			11.5,
			i == 0,
			false
		)
		await _sleep(0.004)

	var center_strike := _r1_targeted_strike_position(
		center,
		92.0,
		276.0,
		targeted_ids,
		center
	)
	await _r1_prism_understrike_at(
		center_strike,
		Vector2(0.0, -58.0),
		3,
		17.0,
		false,
		true
	)
	_radial_hit(center, 56.0, true)


func _r1_legendary_refraction_engine(base_direction: Vector2) -> void:
	var center := _target_clamped(270.0)
	var core := Color(1.65, 3.35, 3.6, 1.0)
	var glow := Color(0.22, 1.0, 1.7, 1.0)
	_show_target_lock(center, core, glow)
	var targeted_ids: Dictionary = {}

	# The engine opens on a real target whenever one is available, then refracts
	# that event into nearby secondary breaches.
	var opening_strike := _r1_targeted_strike_position(
		center,
		270.0,
		270.0,
		targeted_ids,
		center
	)
	await _r1_prism_understrike_at(
		opening_strike,
		Vector2(0.0, -62.0),
		3,
		18.0,
		true,
		true
	)

	for stage in range(1, 4):
		var stage_radius := 26.0 + float(stage) * 20.0
		_pulse_ring(
			center,
			stage_radius,
			Color(1.5, 3.2, 3.5, 0.92),
			Color(0.2, 0.95, 1.6, 0.16),
			0.11,
			18 + stage * 4
		)

		for side in [-1.0, 1.0]:
			var lateral := IsoVfx.ground_perpendicular_offset(
				base_direction,
				side * stage_radius
			)
			var forward := IsoVfx.ground_vector(
				base_direction,
				float(stage - 1) * 12.0
			)
			var fallback := (center + lateral + forward).round()
			var strike_at := _r1_targeted_strike_position(
				fallback,
				82.0 + float(stage) * 6.0,
				294.0,
				targeted_ids,
				fallback
			)
			var air_vector := Vector2(
				-side * (21.0 + float(stage) * 2.5),
				-48.0 - float(stage) * 4.0
			)
			await _r1_prism_understrike_at(
				strike_at,
				air_vector,
				3,
				12.0 + float(stage),
				false,
				stage == 3
			)

		await _sleep(0.012)

	_pulse_ring(
		center,
		90.0,
		Color(1.9, 3.5, 3.65, 1.0),
		Color(0.22, 1.0, 1.7, 0.22),
		0.18,
		40
	)

# R2 BREACHER // BREACH CANNON
func _r2_legendary_rail_annihilator(base_direction: Vector2) -> void:
	var end := (origin + IsoVfx.ground_vector(base_direction, 330.0)).round()
	var rail := _line(origin, end, Color(3.7, 2.35, 0.82, 1.0), Color(1.9, 0.5, 0.08, 0.34))
	_damage_line(origin, end, 11.0)
	_fade_free(rail, 0.28)
	for i in range(8):
		var at := origin.lerp(end, float(i + 1) / 8.0).round()
		_explode(at, Color(3.6, 1.7, 0.40, 1.0), Color(1.8, 0.42, 0.07, 1.0), 16.0 + float(i) * 1.4, 14.0)
		await _sleep(0.022)

func _r2_legendary_breach_trident(base_direction: Vector2) -> void:
	for angle in [-0.18, 0.0, 0.18]:
		var aim := base_direction.rotated(float(angle)).normalized()
		var end := (origin + IsoVfx.ground_vector(aim, 286.0)).round()
		var rail := _line(origin, end, Color(3.55, 2.1, 0.70, 1.0), Color(1.8, 0.45, 0.08, 0.30))
		_damage_line(origin, end, 8.0)
		_explode(end, Color(3.5, 1.6, 0.38, 1.0), Color(1.75, 0.4, 0.07, 1.0), 29.0, 28.0)
		_fade_free(rail, 0.20)
		await _sleep(0.035)

func _r2_legendary_fault_engine(base_direction: Vector2) -> void:
	var cursor := origin.round()
	for i in range(8):
		var distance := 34.0 * float(i + 1)
		var lateral := IsoVfx.ground_perpendicular_offset(base_direction, (18.0 if i % 2 == 0 else -18.0) + sin(float(i)) * 5.0)
		var next := (origin + IsoVfx.ground_vector(base_direction, distance) + lateral).round()
		var fault := _line(cursor, next, Color(3.45, 1.85, 0.55, 0.96), Color(1.75, 0.42, 0.07, 0.22))
		_damage_line(cursor, next, 7.0)
		_explode(next, Color(3.4, 1.5, 0.34, 1.0), Color(1.7, 0.38, 0.06, 1.0), 15.0 + float(i), 14.0)
		_fade_free(fault, 0.16)
		cursor = next
		await _sleep(0.028)

# R3 HUNTER // HUNTER MISSILES
func _omega_hunter_fill_pack(count: int, max_range: float, destinations: Array[Vector2], tracking_ids: Array[int]) -> void:
	var used: Dictionary = {}
	var aim := _target_clamped(max_range)
	for i in range(count):
		var enemy := _nearest_unused_enemy(aim, max_range, max_range, used)
		if enemy != null and is_instance_valid(enemy):
			var id := enemy.get_instance_id()
			used[id] = true
			destinations.append(enemy.global_position.round())
			tracking_ids.append(id)
			_show_target_lock(enemy.global_position, Color(1.5, 2.9, 3.4, 0.9), Color(0.2, 0.85, 1.55, 0.7))
		else:
			var angle := TAU * float(i) / float(maxi(1, count))
			destinations.append((aim + IsoVfx.ground_offset(angle, 18.0 + float(i % 3) * 8.0)).round())
			tracking_ids.append(0)

func _r3_legendary_cerberus_protocol(base_direction: Vector2) -> void:
	var destinations: Array[Vector2] = []
	var tracking_ids: Array[int] = []
	_omega_hunter_fill_pack(6, 310.0, destinations, tracking_ids)
	for salvo in range(3):
		await _r3_run_dive_salvo(destinations, tracking_ids, 3, 0.022, 13.0 + float(salvo) * 2.0, salvo == 0)
		await _sleep(0.025)

func _r3_legendary_orbital_pack(base_direction: Vector2) -> void:
	var destinations: Array[Vector2] = []
	var tracking_ids: Array[int] = []
	_omega_hunter_fill_pack(12, 320.0, destinations, tracking_ids)
	await _r3_run_dive_salvo(destinations, tracking_ids, 3, 0.018, 15.0, true)
	_pulse_ring(owner_ground, 54.0, Color(1.65, 3.0, 3.4, 1.0), Color(0.2, 0.85, 1.55, 0.22), 0.15, 30)

func _r3_legendary_recursive_warhead(base_direction: Vector2) -> void:
	var destinations: Array[Vector2] = []
	var tracking_ids: Array[int] = []
	_omega_hunter_fill_pack(6, 310.0, destinations, tracking_ids)
	await _r3_run_dive_salvo(destinations, tracking_ids, 3, 0.026, 15.0, true)
	for center in destinations:
		for j in range(3):
			var angle := TAU * float(j) / 3.0 + 0.35
			var end := IsoVfx.ground_point(center, angle, 30.0).round()
			var fragment := _line(center, end, Color(1.7, 3.0, 3.35, 0.9), Color(0.2, 0.8, 1.5, 0.18))
			_damage_line(center, end, 4.0)
			_explode(end, Color(1.7, 2.9, 3.3, 1.0), Color(0.2, 0.8, 1.5, 1.0), 9.0, 9.0)
			_fade_free(fragment, 0.12)
		await _sleep(0.012)

# R4 CASCADE // ARC CASCADE
func _r4_omega_render_chain(chain: PackedVector2Array, core: Color, glow: Color, radius: float = 6.0) -> void:
	if chain.size() <= 1:
		return
	var lightning := PackedVector2Array()
	for segment_index in range(chain.size() - 1):
		var jagged := _jagged_segment_points(chain[segment_index], chain[segment_index + 1], 7.0)
		for j in range(jagged.size()):
			if segment_index > 0 and j == 0:
				continue
			lightning.append(jagged[j])
		_damage_line(chain[segment_index], chain[segment_index + 1], radius)
		_explode(chain[segment_index + 1], core, glow, 12.0, 11.0)
	var arc := _polyline(lightning, core, Color(glow.r, glow.g, glow.b, 0.34))
	_fade_free(arc, 0.22)

func _r4_legendary_tesla_storm(base_direction: Vector2) -> void:
	var saved_target := target
	for offset in [-92.0, 0.0, 92.0]:
		target = saved_target + IsoVfx.ground_perpendicular_offset(base_direction, float(offset))
		var chain := _chain_enemy_points(9, 290.0, 150.0)
		if chain.size() <= 1:
			chain.append(_target_clamped(260.0))
		_r4_omega_render_chain(chain, Color(2.9, 1.75, 3.65, 1.0), Color(1.15, 0.28, 1.9, 1.0), 6.0)
		await _sleep(0.035)
	target = saved_target

func _r4_legendary_arc_web(base_direction: Vector2) -> void:
	var chain := _chain_enemy_points(11, 300.0, 158.0)
	if chain.size() <= 1:
		chain.append(_target_clamped(270.0))
	_r4_omega_render_chain(chain, Color(2.85, 1.65, 3.65, 1.0), Color(1.1, 0.28, 1.9, 1.0), 6.0)
	if chain.size() >= 4:
		for i in range(chain.size() - 2):
			if i % 2 != 0:
				continue
			var cross := _line(chain[i], chain[i + 2], Color(2.7, 1.55, 3.5, 0.78), Color(1.0, 0.25, 1.75, 0.18))
			_damage_line(chain[i], chain[i + 2], 5.0)
			_fade_free(cross, 0.18)

func _r4_legendary_neural_overload(base_direction: Vector2) -> void:
	var chain := _chain_enemy_points(12, 310.0, 160.0)
	if chain.size() <= 1:
		chain.append(_target_clamped(275.0))
	_r4_omega_render_chain(chain, Color(3.0, 1.8, 3.7, 1.0), Color(1.15, 0.30, 1.95, 1.0), 6.5)
	for pass_index in range(2):
		for i in range(chain.size() - 1, 0, -1):
			_explode(chain[i], Color(3.1, 1.55, 3.7, 1.0), Color(1.2, 0.28, 1.95, 1.0), 14.0 + float(pass_index) * 3.0, 13.0)
			await _sleep(0.016)

# S1 SOLARIS // PHOTON RAKE
func _s1_legendary_sunfire_grid(base_direction: Vector2) -> void:
	for i in range(9):
		var offset := (float(i) - 4.0) * 9.0
		var lateral := IsoVfx.ground_perpendicular_offset(base_direction, offset)
		var start := (origin + lateral).round()
		var end := (start + IsoVfx.ground_vector(base_direction, 252.0)).round()
		await _s1_project_photon_cut(start, end, 3, i % 2 == 0)
	await _sleep(0.02)

func _s1_legendary_solar_cross(base_direction: Vector2) -> void:
	for i in range(8):
		var aim := base_direction.rotated(TAU * float(i) / 8.0)
		var end := (origin + IsoVfx.ground_vector(aim, 224.0)).round()
		await _s1_project_photon_cut(origin, end, 3, true)
	_pulse_ring(owner_ground, 112.0, Color(3.5, 2.2, 0.75, 1.0), Color(1.8, 0.55, 0.08, 0.25), 0.18, 40)
	_radial_hit(owner_ground, 114.0, true)

func _s1_legendary_corona_breaker(base_direction: Vector2) -> void:
	for i in range(5):
		var offset := (float(i) - 2.0) * 10.0
		var lateral := IsoVfx.ground_perpendicular_offset(base_direction, offset)
		var start := (origin + lateral).round()
		var end := (start + IsoVfx.ground_vector(base_direction, 244.0)).round()
		await _s1_project_photon_cut(start, end, 3, true)
	var center := (origin + IsoVfx.ground_vector(base_direction, 235.0)).round()
	_pulse_ring(center, 92.0, Color(3.7, 2.4, 0.78, 1.0), Color(1.9, 0.6, 0.08, 0.28), 0.20, 44)
	_radial_hit(center, 94.0, true)
	_explode(center, Color(3.8, 2.0, 0.56, 1.0), Color(1.9, 0.48, 0.07, 1.0), 38.0, 42.0)
	for i in range(12):
		var end := IsoVfx.ground_point(center, TAU * float(i) / 12.0, 90.0).round()
		var flare := _line(center, end, Color(3.6, 1.75, 0.5, 0.9), Color(1.8, 0.45, 0.07, 0.18))
		_damage_line(center, end, 5.0)
		_fade_free(flare, 0.14)

# S2 PHANTOM // GRAVITY WELL
func _s2_legendary_black_star(base_direction: Vector2) -> void:
	var dest := _target_clamped(255.0)
	await _s2_gravity_collapse(dest, 122.0, 3, true)
	await _sleep(0.035)
	await _s2_gravity_collapse(dest, 94.0, 3, true)
	_explode(dest, Color(2.0, 3.25, 3.75, 1.0), Color(0.3, 0.9, 1.9, 1.0), 42.0, 48.0)
	_pulse_ring(dest, 132.0, Color(1.9, 3.2, 3.75, 1.0), Color(0.28, 0.85, 1.9, 0.28), 0.22, 48)
	_radial_hit(dest, 132.0, true)

func _s2_legendary_orbital_prison(base_direction: Vector2) -> void:
	var max_range := 265.0
	var locked := _nearest_enemy_to_aim(target, 105.0, max_range)
	var tracking_id := 0
	var fallback := _target_clamped(max_range)
	if locked != null and is_instance_valid(locked):
		tracking_id = locked.get_instance_id()
		fallback = locked.global_position.round()
	for cycle in range(3):
		var center := _r3_resolve_target_position(tracking_id, fallback)
		_show_target_lock(center, Color(1.65, 3.0, 3.6, 1.0), Color(0.24, 0.8, 1.8, 0.8))
		await _s2_gravity_collapse(center, 82.0 + float(cycle) * 9.0, 3, cycle > 0)
		fallback = center
		await _sleep(0.03)
	var final_center := _r3_resolve_target_position(tracking_id, fallback)
	_explode(final_center, Color(1.9, 3.2, 3.7, 1.0), Color(0.28, 0.85, 1.85, 1.0), 32.0, 36.0)

func _s2_legendary_event_horizon(base_direction: Vector2) -> void:
	var entry := _target_clamped(240.0)
	var exit := (entry + IsoVfx.ground_vector(base_direction, 118.0)).round()
	await _s2_gravity_collapse(entry, 80.0, 3, true)
	await _s2_gravity_collapse(exit, 80.0, 3, true)
	var rift := _line(entry, exit, Color(1.85, 3.2, 3.75, 1.0), Color(0.28, 0.85, 1.9, 0.32))
	_damage_line(entry, exit, 9.0)
	_fade_free(rift, 0.28)
	_explode(entry, Color(1.75, 3.05, 3.6, 1.0), Color(0.25, 0.8, 1.8, 1.0), 27.0, 30.0)
	_explode(exit, Color(2.0, 3.3, 3.8, 1.0), Color(0.3, 0.9, 1.95, 1.0), 34.0, 38.0)
	_pulse_ring(exit, 94.0, Color(1.9, 3.2, 3.75, 1.0), Color(0.28, 0.85, 1.9, 0.24), 0.18, 38)
	_radial_hit(exit, 96.0, true)

# S3 SPIDER // PHASE NEEDLES
func _s3_legendary_phase_fusillade(base_direction: Vector2) -> void:
	var saved_direction := direction
	for fan_angle in [-0.24, 0.0, 0.24]:
		direction = base_direction.rotated(float(fan_angle)).normalized()
		var ends: Array[Vector2] = []
		for i in range(9):
			var f := float(i) / 8.0 - 0.5
			ends.append((origin + IsoVfx.ground_vector(direction, 222.0, f * deg_to_rad(54.0))).round())
		await _s3_phase_needle_volley(ends, 3, fan_angle != 0.0)
		await _sleep(0.018)
	direction = saved_direction

func _s3_legendary_web_crown(base_direction: Vector2) -> void:
	var ends: Array[Vector2] = []
	for i in range(16):
		var aim := base_direction.rotated(TAU * float(i) / 16.0)
		ends.append((origin + IsoVfx.ground_vector(aim, 196.0)).round())
	await _s3_phase_needle_volley(ends, 3, true)
	_pulse_ring(owner_ground, 112.0, Color(2.3, 3.0, 3.7, 1.0), Color(0.6, 0.9, 1.95, 0.24), 0.18, 40)
	_radial_hit(owner_ground, 114.0, true)

func _s3_legendary_ghost_swarm(base_direction: Vector2) -> void:
	var saved_direction := direction
	for wave in range(4):
		direction = base_direction.rotated(sin(float(wave) * 1.8) * 0.12).normalized()
		var ends: Array[Vector2] = []
		var count := 7
		for i in range(count):
			var f := float(i) / float(count - 1) - 0.5
			var reach := 190.0 + float(wave) * 18.0
			ends.append((origin + IsoVfx.ground_vector(direction, reach, f * deg_to_rad(44.0 + float(wave) * 5.0))).round())
		await _s3_phase_needle_volley(ends, 3, true)
		await _sleep(0.028)
	direction = saved_direction

func _m1_legendary_omega_edge(base_direction: Vector2) -> void:
	# Three over-range cleavers tear through a broad forward fan. This is the
	# cleanest "more blade" mutation and keeps ATLAS readable in dense swarms.
	for angle in [-0.30, 0.0, 0.30]:
		direction = base_direction.rotated(float(angle)).normalized()
		await _m1_traveling_cleaver_wave(
			30.0, 205.0, deg_to_rad(31.0), deg_to_rad(52.0), 17, 0.13, 13.0,
			Color(3.5, 1.25, 3.7, 1.0), Color(1.45, 0.14, 1.8, 0.34)
		)
		await _sleep(0.018)
	direction = base_direction
	var end := owner_ground + IsoVfx.ground_vector(base_direction, 190.0)
	_pulse_ring(end, 30.0, Color(3.5, 2.5, 3.8, 1.0), Color(1.4, 0.16, 1.8, 0.25), 0.16, 24)
	_explode(end, Color(3.4, 1.5, 3.7, 1.0), Color(1.3, 0.12, 1.8, 1.0), 30.0, 30.0)

func _m1_legendary_atlas_crown(base_direction: Vector2) -> void:
	# Plasma Cleaver becomes an omnidirectional crown. The six blades fire in a
	# fast clock sequence so every sector around the chassis becomes dangerous.
	var start_angle := base_direction.angle()
	_pulse_ring(owner_ground, 38.0, Color(1.7, 3.3, 3.6, 1.0), Color(0.22, 1.0, 1.7, 0.22), 0.18, 30)
	for i in range(6):
		direction = Vector2.from_angle(start_angle + TAU * float(i) / 6.0)
		await _m1_traveling_cleaver_wave(
			24.0, 164.0, deg_to_rad(25.0), deg_to_rad(40.0), 13, 0.10, 11.5,
			Color(1.55, 3.25, 3.55, 1.0), Color(0.18, 1.05, 1.75, 0.30)
		)
		await _sleep(0.012)
	direction = base_direction
	_radial_hit(owner_ground, 104.0, true)
	_pulse_ring(owner_ground, 106.0, Color(2.2, 3.4, 3.6, 1.0), Color(0.25, 1.0, 1.6, 0.24), 0.20, 36)

func _m1_legendary_world_breaker(base_direction: Vector2) -> void:
	# One colossal forward rupture. The cleaver opens the lane, then a sequence
	# of delayed reactor detonations walks away from ATLAS through the horde.
	direction = base_direction
	await _m1_traveling_cleaver_wave(
		34.0, 230.0, deg_to_rad(34.0), deg_to_rad(59.0), 19, 0.20, 15.0,
		Color(3.6, 2.2, 0.72, 1.0), Color(1.7, 0.42, 0.08, 0.34)
	)
	for i in range(6):
		var distance := 60.0 + float(i) * 34.0
		var at := (owner_ground + IsoVfx.ground_vector(base_direction, distance)).round()
		_explode(
			at,
			Color(3.6, 1.72 + float(i) * 0.06, 0.52, 1.0),
			Color(1.7, 0.38, 0.06, 1.0),
			18.0 + float(i) * 2.2,
			17.0 + float(i) * 2.0
		)
		if i < 5:
			await _sleep(0.035)
	var end := (owner_ground + IsoVfx.ground_vector(base_direction, 236.0)).round()
	_pulse_ring(end, 42.0, Color(3.6, 2.65, 0.9, 1.0), Color(1.8, 0.45, 0.08, 0.28), 0.20, 32)

# M1 PRIMARY: PLASMA CLEAVER
# A travelling isometric plasma crescent that cuts forward through crowds.
func _m1_plasma_cleaver() -> void:
	var tier := primary_tier
	var base_direction := direction
	match legendary_mutation:
		"omega_edge":
			await _m1_legendary_omega_edge(base_direction)
			return
		"atlas_crown":
			await _m1_legendary_atlas_crown(base_direction)
			return
		"world_breaker":
			await _m1_legendary_world_breaker(base_direction)
			return

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
		_set_fx_depth(head, owner_ground, 1)
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
				_set_fx_depth(heads[i], current, 1)

			if i < tethers.size() and is_instance_valid(tethers[i]):
				_update_depth_line_endpoint(tethers[i], current)

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
	var base_direction := direction
	match legendary_mutation:
		"predator_grid":
			await _m2_legendary_predator_grid(base_direction)
			return
		"apex_reel":
			await _m2_legendary_apex_reel(base_direction)
			return
		"kill_lattice":
			await _m2_legendary_kill_lattice(base_direction)
			return

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
		_set_fx_depth(shard, owner_ground, 1)
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

			var shard_position := owner_ground.lerp(
				endpoints[i],
				blast_t
			).round()
			shards[i].global_position = shard_position
			_set_fx_depth(shards[i], shard_position, 1)

		await _sleep(0.018)

	# Apply the original outward gameplay impulse at the edge of the projected wave.
	_radial_hit(owner_ground, max_radius, true)

	# Break the perimeter into impact flashes so the release feels like an actual
	# detonation reaching the floor rather than a decorative ring disappearing.
	var impact_stride := maxi(1, int(round(float(shard_count) / 8.0)))

	var played_release_sound := false
	for i in range(endpoints.size()):
		if i % impact_stride == 0:
			_ability_impact_fx(
				endpoints[i],
				core,
				glow,
				7.0 + float(tier) + (2.0 if overcharged else 0.0),
				not played_release_sound
			)
			played_release_sound = true

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
	var base_direction := direction
	match legendary_mutation:
		"meteor_shower":
			await _m3_legendary_meteor_shower(base_direction)
			return
		"cluster_sun":
			await _m3_legendary_cluster_sun(base_direction)
			return
		"comet_corridor":
			await _m3_legendary_comet_corridor(base_direction)
			return
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
	if preview_mode:
		return null
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
	var core := Color(3.0, 1.2, 0.3, 1.0)
	var glow := Color(1.5, 0.3, 0.08, 1.0)

	_explode(owner_ground, Color(2.8, 1.2, 0.3, 1.0), Color(1.4, 0.3, 0.08, 1.0), 13.0, 13.0)

	# Early Orbital Rain still reads as a perimeter bombardment. Upgrades then
	# progressively invade the interior; Tier III SATURATION deliberately fills
	# the whole isometric ground disk instead of drawing one circumference.
	if tier >= 1:
		_pulse_ring(owner_ground, radius, core, Color(glow.r, glow.g, glow.b, 0.20), 0.18, 28, 0.0)
	if tier >= 2:
		_pulse_ring(owner_ground, radius * 0.58, core, Color(glow.r, glow.g, glow.b, 0.16), 0.16, 22, 0.21)
	if tier >= 3:
		_pulse_ring(owner_ground, radius * 0.30, core, Color(glow.r, glow.g, glow.b, 0.14), 0.15, 16, 0.42)
		# Guarantee that anything inside the saturated field participates even if it
		# happens to stand between individual impact sprites.
		_radial_hit(owner_ground, radius, true)

	for i in range(strikes):
		var hit_offset := _m3_orbital_rain_offset(i, strikes, tier, radius)
		var hit := (owner_ground + hit_offset).round()
		var sky_start := hit + Vector2(float((i % 3) - 1) * 18.0, -140.0)
		var beam := _line(sky_start, hit, Color(3.0, 1.35, 0.35, 1.0), Color(1.5, 0.35, 0.08, 0.24))
		_explode(hit, core, glow, 11.0 + float(tier), 12.0 + float(tier))
		_fade_free(beam, 0.11)
		await _sleep(0.025)

func _m3_orbital_rain_offset(index: int, strike_count: int, tier: int, radius: float) -> Vector2:
	var safe_count := maxi(1, strike_count)

	# Base ability preserves the original outer-ring identity.
	if tier <= 0:
		var base_angle := TAU * float(index) / float(safe_count)
		return IsoVfx.ground_offset(base_angle, radius)

	# Tier I starts occupying the interior with two staggered bands.
	if tier == 1:
		var inner_count := maxi(4, int(round(float(safe_count) * 0.36)))
		if index < inner_count:
			var inner_angle := TAU * float(index) / float(inner_count) + 0.28
			return IsoVfx.ground_offset(inner_angle, radius * 0.50)
		var outer_index := index - inner_count
		var outer_count := maxi(1, safe_count - inner_count)
		var outer_angle := TAU * float(outer_index) / float(outer_count) - 0.12
		return IsoVfx.ground_offset(outer_angle, radius * 0.94)

	# Tier II/III use a sunflower distribution. sqrt(t) is important: using a
	# linear radius would cluster impacts near the center instead of filling area.
	if tier >= 3 and index == 0:
		return Vector2.ZERO
	var adjusted_index := index if tier < 3 else index - 1
	var adjusted_count := safe_count if tier < 3 else maxi(1, safe_count - 1)
	var t := (float(adjusted_index) + 0.55) / float(adjusted_count)
	var strike_radius := radius * sqrt(clampf(t, 0.0, 1.0))
	var golden_angle := PI * (3.0 - sqrt(5.0))
	var angle := float(adjusted_index) * golden_angle + float(tier) * 0.19
	return IsoVfx.ground_offset(angle, strike_radius)

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
	explosion_size: float = 8.0,
	sound_per_ring: bool = false
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
				explosion_size + ring_t * 2.0,
				sound_per_ring and i == 0
			)
			
			await _sleep(0.018)
			
		# The slight cadence makes the blast visibly propagate away from the
		# chassis instead of every explosion appearing on the same frame.
		await _sleep(0.022)


# R1 PRIMARY: PRISM UNDERSTRIKE
# A cursor-designated refractive strike field. Unlike HUNTER, nothing launches
# from the chassis and nothing dives from the sky: PRISM energy breaches the deck
# at the target area and rises outward at sharp isometric angles.
func _r1_prism_understrike() -> void:
	var tier := primary_tier
	var base_direction := direction
	match legendary_mutation:
		"prism_wall":
			await _r1_legendary_prism_wall(base_direction)
			return
		"kaleidoscope":
			await _r1_legendary_kaleidoscope(base_direction)
			return
		"refraction_engine":
			await _r1_legendary_refraction_engine(base_direction)
			return

	var strike_count := 3 + tier
	var max_range := 206.0 + float(tier) * 14.0
	var spread := 42.0 + float(tier) * 8.0
	var center := _target_clamped(max_range)
	var core := Color(1.05, 2.95, 3.35, 1.0)
	var glow := Color(0.2, 0.92, 1.55, 1.0)

	_show_target_lock(center, core, glow)
	var targeted_ids: Dictionary = {}

	if tier >= 1:
		_pulse_ring(
			center,
			spread * 0.62,
			core,
			Color(glow.r, glow.g, glow.b, 0.15),
			0.12,
			18 + tier * 4
		)

	for i in range(strike_count):
		var f := 0.0 if strike_count == 1 else (
			float(i) / float(strike_count - 1) - 0.5
		)
		var lateral := IsoVfx.ground_perpendicular_offset(
			base_direction,
			f * spread
		)
		var stagger_forward := (
			float((i % 3) - 1)
			* (8.0 + float(tier) * 1.5)
		)
		var forward := IsoVfx.ground_vector(
			base_direction,
			stagger_forward
		)
		var fallback := (center + lateral + forward).round()
		var strike_at := _r1_targeted_strike_position(
			center,
			max_range,
			max_range,
			targeted_ids,
			fallback
		)

		await _r1_prism_understrike_at(
			strike_at,
			_r1_understrike_air_vector(i, tier),
			tier,
			10.0 + float(tier) * 1.25,
			i == 0,
			false
		)

		await _sleep(maxf(0.002, 0.012 - float(tier) * 0.002))

	# Tier III keeps the old primary's "something extra at the end" cadence, but
	# replaces its cross-lance burst with one heavy central breach from the opposite
	# angle. This makes the max tier read as a converging strike pattern.
	if tier >= 3:
		await _sleep(0.018)
		var finisher_at := _r1_targeted_strike_position(
			center,
			max_range,
			max_range,
			targeted_ids,
			center
		)
		await _r1_prism_understrike_at(
			finisher_at,
			Vector2(-24.0 if strike_count % 2 == 0 else 24.0, -58.0),
			tier,
			16.0,
			false,
			true
		)


# Backward-compatible entry point for any older preview/debug code that still
# invokes the former method directly. Gameplay now routes through UNDERSTRIKE.
func _r1_prism_lance() -> void:
	await _r1_prism_understrike()


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
			7.0 + float(tier) * 0.6,
			true
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
	var base_direction := direction
	match legendary_mutation:
		"rail_annihilator":
			await _r2_legendary_rail_annihilator(base_direction)
			return
		"breach_trident":
			await _r2_legendary_breach_trident(base_direction)
			return
		"fault_engine":
			await _r2_legendary_fault_engine(base_direction)
			return
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
	_set_fx_depth(slug_head, owner_ground, 1)
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
			_set_fx_depth(slug_head, current, 1)

		if is_instance_valid(slug_trail):
			_update_depth_line_endpoint(slug_trail, current)

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
				_update_depth_line_endpoint(rail_a, current + left_offset)

			if rail_b != null and is_instance_valid(rail_b):
				_update_depth_line_endpoint(rail_b, current + right_offset)

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
		var played_finisher_sound := false
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
				9.5,
				not played_finisher_sound
			)
			played_finisher_sound = true

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
			_set_fx_depth(launch_head, owner_ground, 1)
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
				_set_fx_depth(missile, live_dest, 1)
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
				# The missile is descending vertically over its target. Sort it from the
				# target's deck footprint, not its elevated screen Y.
				_set_fx_depth(missile_node, live_dest, 1)

			var trail_node := dive_trails[i] as Node2D
			if trail_node != null and is_instance_valid(trail_node):
				# Keep the full dive streak on the target's depth plane. This preserves
				# altitude visually without making "higher" screen pixels sort behind
				# unrelated floor geometry.
				var trail_visual := PackedVector2Array([dive_starts[i], p])
				var trail_depth := PackedVector2Array([live_dest, live_dest])
				_refresh_depth_polyline_with_depth(
					trail_node,
					trail_visual,
					Color(core.r, core.g, core.b, 0.90),
					trail_glow,
					trail_depth
				)

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
	var base_direction := direction
	match legendary_mutation:
		"cerberus_protocol":
			await _r3_legendary_cerberus_protocol(base_direction)
			return
		"orbital_pack":
			await _r3_legendary_orbital_pack(base_direction)
			return
		"recursive_warhead":
			await _r3_legendary_recursive_warhead(base_direction)
			return

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

	# Missile Halo remains a protected annulus around Hunter, but it now behaves
	# like a true smart-missile defensive screen. If enemies are inside the halo's
	# usable combat ring, every missile receives a live target. Unique enemies are
	# covered first; if there are fewer enemies than missiles, the remaining
	# missiles cycle back across those same targets instead of wasting shots on
	# empty saturation points.
	var halo_targets: Array[Node2D] = []
	if not preview_mode and get_tree() != null:
		for node in get_tree().get_nodes_in_group("enemies"):
			var enemy := node as Node2D
			if enemy == null or not is_instance_valid(enemy):
				continue
			if not enemy.is_inside_tree():
				continue
			if not enemy.has_method("take_projectile_hit"):
				continue

			var collision_body := enemy as CollisionObject2D
			if collision_body != null and collision_body.collision_layer == 0:
				continue

			var enemy_distance := IsoVfx.ground_distance(
				owner_ground,
				enemy.global_position
			)

			# Preserve the authored clear pocket immediately around Hunter. Enemies
			# occupying the actual missile ring, however, are always preferred over
			# decorative saturation coordinates.
			if enemy_distance <= safe_radius or enemy_distance > radius:
				continue

			halo_targets.append(enemy)

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

	# Golden-angle placement is retained as the no-target fallback. It also gives
	# each missile a sensible last-known destination if its tracked enemy is killed
	# while the salvo is already in flight.
	var golden_angle := 2.39996323
	var inner := safe_radius + 15.0
	var outer := radius

	for i in range(missile_count):
		var fraction := float(i + 1) / float(missile_count + 1)

		# sqrt distributes fallback points by AREA rather than clustering everything
		# near Hunter or the perimeter.
		var radial_t := sqrt(fraction)
		var strike_radius := lerpf(inner, outer, radial_t)
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
		var tracking_target_id := 0

		if not halo_targets.is_empty():
			# Cover every available enemy once before repeating targets. This makes
			# a crowded halo distribute damage, while a lone dangerous enemy receives
			# the full defensive barrage.
			var selected_enemy := halo_targets[i % halo_targets.size()]
			if selected_enemy != null and is_instance_valid(selected_enemy):
				tracking_target_id = selected_enemy.get_instance_id()
				dest = selected_enemy.global_position.round()

				# Only draw one acquisition reticle per unique target. Repeated missiles
				# still track it, but do not bury the enemy under duplicate lock VFX.
				if i < halo_targets.size():
					_show_target_lock(
						dest,
						Color(1.45, 2.85, 3.35, 0.94),
						Color(0.18, 0.82, 1.55, 0.78)
					)

		destinations.append(dest)
		tracking_ids.append(tracking_target_id)

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
		var played_finish_sound := false
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
				8.0,
				not played_finish_sound
			)
			played_finish_sound = true

			await _sleep(0.014)


# R4 PRIMARY: ARC CASCADE
func _r4_arc_cascade() -> void:
	var tier := primary_tier
	var base_direction := direction
	match legendary_mutation:
		"tesla_storm":
			await _r4_legendary_tesla_storm(base_direction)
			return
		"arc_web":
			await _r4_legendary_arc_web(base_direction)
			return
		"neural_overload":
			await _r4_legendary_neural_overload(base_direction)
			return
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
	_set_fx_depth(head, Vector2(start.x, _depth_y_for_point(start)), 1)

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
			_set_fx_depth(head, current, 1)

		if is_instance_valid(beam):
			_update_depth_line_endpoint(beam, current)

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
	var base_direction := direction
	match legendary_mutation:
		"sunfire_grid":
			await _s1_legendary_sunfire_grid(base_direction)
			return
		"solar_cross":
			await _s1_legendary_solar_cross(base_direction)
			return
		"corona_breaker":
			await _s1_legendary_corona_breaker(base_direction)
			return
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
	var played_corona_sound := false
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

			var play_corona_impact := (
				not played_corona_sound
				and step >= 4
			)

			_ability_impact_fx(
				blast_point,
				core,
				glow,
				7.0 + float(tier) * 0.8 + (1.5 if overcharged else 0.0),
				play_corona_impact
			)
			if play_corona_impact:
				played_corona_sound = true

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
		_set_fx_depth(mote, start, 1)
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

			var mote_position := (
				starts[i].lerp(center, collapse_t)
				+ spiral_offset
			).round()
			motes[i].global_position = mote_position
			_set_fx_depth(motes[i], mote_position, 1)

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
	var base_direction := direction
	match legendary_mutation:
		"black_star":
			await _s2_legendary_black_star(base_direction)
			return
		"orbital_prison":
			await _s2_legendary_orbital_prison(base_direction)
			return
		"event_horizon":
			await _s2_legendary_event_horizon(base_direction)
			return
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
		_set_fx_depth(shard, start, 1)
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

			var shard_position := start.lerp(
				endpoints[i],
				blast_t
			).round()
			shards[i].global_position = shard_position
			_set_fx_depth(shards[i], shard_position, 1)

		await _sleep(0.018)

	# Gameplay resolves once, when the visible mass front reaches its full radius.
	_radial_hit(owner_ground, max_radius, true)

	var impact_stride := maxi(1, int(round(float(shard_count) / 9.0)))
	var played_ejection_sound := false

	for i in range(endpoints.size()):
		if i % impact_stride == 0:
			_ability_impact_fx(
				endpoints[i],
				core,
				glow,
				7.0 + float(tier) * 0.8 + (2.0 if overcharged else 0.0),
				not played_ejection_sound
			)
			played_ejection_sound = true

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
		_set_fx_depth(head, Vector2(start.x, _depth_y_for_point(start)), 1)
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
			_set_fx_depth(heads[i], current, 1)
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
	var base_direction := direction
	match legendary_mutation:
		"phase_fusillade":
			await _s3_legendary_phase_fusillade(base_direction)
			return
		"web_crown":
			await _s3_legendary_web_crown(base_direction)
			return
		"ghost_swarm":
			await _s3_legendary_ghost_swarm(base_direction)
			return
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
		_set_fx_depth(anchor, owner_ground, 1)
		anchors.append(anchor)

	# Phase anchors first appear on the inner web, then blink to the outer web.
	for i in range(anchors.size()):
		if is_instance_valid(anchors[i]):
			anchors[i].global_position = inner_points[i]
			_set_fx_depth(anchors[i], inner_points[i], 1)

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
		_set_fx_depth(anchors[i], outer_points[i], 1)

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
