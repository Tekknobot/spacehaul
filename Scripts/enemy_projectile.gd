extends Node2D
class_name SpacehaulEnemyProjectile

@export var speed := 180.0
@export var max_distance := 340.0

var direction := Vector2.RIGHT
var traveled := 0.0
var shooter_rid: RID
var core_color := Color(1.2, 3.0, 1.1, 1.0)
var glow_color := Color(0.25, 1.4, 0.35, 1.0)

func setup(start_position: Vector2, travel_direction: Vector2, source_rid: RID, color: Color, glow: Color, projectile_speed: float = 180.0) -> void:
	global_position = start_position.round()
	direction = travel_direction.normalized()
	if direction.length_squared() <= 0.001:
		direction = Vector2.RIGHT
	shooter_rid = source_rid
	core_color = color
	glow_color = glow
	speed = projectile_speed
	z_as_relative = false
	z_index = 1850
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive
	queue_redraw()

func _physics_process(delta: float) -> void:
	var old_position := global_position
	var travel := direction * speed * delta
	var next_position := old_position + travel

	var query := PhysicsRayQueryParameters2D.create(old_position, next_position, 1)
	if shooter_rid.is_valid():
		query.exclude = [shooter_rid]
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position = (hit["position"] as Vector2).round()
		var collider := hit.get("collider") as Object
		if collider != null and collider.has_method("take_projectile_hit"):
			collider.call("take_projectile_hit", direction)
		queue_free()
		return

	global_position = next_position
	traveled += travel.length()
	if traveled >= max_distance:
		queue_free()

func _draw() -> void:
	# Tiny hard-edged hostile bolt with a 2x2 additive bloom.
	draw_rect(Rect2(Vector2(-1.0, -1.0), Vector2(2.0, 2.0)), Color(glow_color.r, glow_color.g, glow_color.b, 0.36), true)
	draw_rect(Rect2(Vector2.ZERO, Vector2.ONE), core_color, true)
