extends Node2D
class_name SpacehaulProjectile

@export var speed := 430.0
@export var max_distance := 520.0
@export var collision_mask := 1

const CORE_SIZE := Vector2(1.0, 1.0)
const BLOOM_SIZE := Vector2(4.0, 4.0)

var direction := Vector2.RIGHT
var traveled_distance := 0.0
var shooter_rid: RID

var primary_color := Color("54d8eb")
var secondary_color := Color("bdf8ff")
var glow_color := Color("2b7786")


func setup(
	start_position: Vector2,
	travel_direction: Vector2,
	source_rid: RID,
	source_mecha_id: String = ""
) -> void:
	global_position = start_position.round()
	direction = travel_direction.normalized()
	shooter_rid = source_rid

	_configure_style(source_mecha_id)

	# Additive rendering is active for the projectile's entire lifetime.
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive

	z_as_relative = false
	z_index = clampi(
		int(round(global_position.y + 8.0)),
		-3000,
		3000
	)

	queue_redraw()


func _configure_style(source_mecha_id: String) -> void:
	match source_mecha_id:

		"M1":
			primary_color = Color(2.7, 1.45, 0.5, 1.0)
			secondary_color = Color(3.0, 2.2, 1.0, 1.0)
			glow_color = Color(1.2, 0.48, 0.12, 1.0)

		"M2":
			primary_color = Color(1.2, 2.7, 2.85, 1.0)
			secondary_color = Color(2.1, 3.1, 3.2, 1.0)
			glow_color = Color(0.2, 0.92, 1.25, 1.0)

		"M3":
			primary_color = Color(2.9, 1.85, 0.8, 1.0)
			secondary_color = Color(3.2, 2.35, 1.15, 1.0)
			glow_color = Color(1.15, 0.55, 0.18, 1.0)

		"R4":
			primary_color = Color(2.35, 1.15, 3.0, 1.0)
			secondary_color = Color(2.95, 1.85, 3.35, 1.0)
			glow_color = Color(0.95, 0.2, 1.65, 1.0)

		"S1":
			primary_color = Color(2.6, 2.4, 0.85, 1.0)
			secondary_color = Color(3.0, 2.85, 1.25, 1.0)
			glow_color = Color(1.25, 0.95, 0.22, 1.0)

		"S2":
			primary_color = Color(1.1, 2.25, 3.15, 1.0)
			secondary_color = Color(2.1, 3.0, 3.4, 1.0)
			glow_color = Color(0.18, 0.65, 1.4, 1.0)

		"S3":
			primary_color = Color(1.85, 2.45, 3.1, 1.0)
			secondary_color = Color(2.55, 3.0, 3.45, 1.0)
			glow_color = Color(0.45, 0.82, 1.75, 1.0)

		_:
			primary_color = Color("54d8eb")
			secondary_color = Color("bdf8ff")
			glow_color = Color("2b7786")


func _physics_process(delta: float) -> void:
	if direction.length_squared() <= 0.001:
		queue_free()
		return

	var old_position := global_position
	var travel := direction * speed * delta
	var next_position := old_position + travel

	var query := PhysicsRayQueryParameters2D.create(
		old_position,
		next_position,
		collision_mask
	)

	if shooter_rid.is_valid():
		query.exclude = [shooter_rid]

	query.collide_with_areas = true
	query.collide_with_bodies = true

	var hit := get_world_2d().direct_space_state.intersect_ray(query)

	if not hit.is_empty():
		global_position = (hit["position"] as Vector2).round()

		var collider := hit.get("collider") as Object

		if collider != null and collider.has_method("take_projectile_hit"):
			collider.call(
				"take_projectile_hit",
				direction
			)

		queue_free()
		return

	global_position = next_position

	traveled_distance += travel.length()

	z_index = clampi(
		int(round(global_position.y + 8.0)),
		-3000,
		3000
	)

	if traveled_distance >= max_distance:
		queue_free()


func _draw() -> void:
	# 2 x 2 additive bloom.
	draw_rect(
		Rect2(
			Vector2(-1.0, -1.0),
			BLOOM_SIZE
		),
		Color(
			glow_color.r,
			glow_color.g,
			glow_color.b,
			0.35
		),
		true
	)

	# Slightly stronger inner glow.
	draw_rect(
		Rect2(
			Vector2(-1.0, -1.0),
			BLOOM_SIZE
		),
		Color(
			primary_color.r,
			primary_color.g,
			primary_color.b,
			0.18
		),
		true
	)

	# Crisp 1 x 1 projectile pixel.
	draw_rect(
		Rect2(
			Vector2.ZERO,
			CORE_SIZE
		),
		secondary_color,
		true
	)
