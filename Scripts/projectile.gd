extends Node2D
class_name SpacehaulProjectile

@export var speed := 430.0
@export var max_distance := 520.0
@export var collision_mask := 1

var direction := Vector2.RIGHT
var traveled_distance := 0.0
var shooter_rid: RID

func setup(start_position: Vector2, travel_direction: Vector2, source_rid: RID) -> void:
	global_position = start_position
	direction = travel_direction.normalized()
	shooter_rid = source_rid
	z_as_relative = false
	z_index = clampi(int(round(global_position.y + 8.0)), -3000, 3000)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if direction.length_squared() <= 0.001:
		queue_free()
		return

	var old_position := global_position
	var travel := direction * speed * delta
	var next_position := old_position + travel

	var query := PhysicsRayQueryParameters2D.create(old_position, next_position, collision_mask)
	if shooter_rid.is_valid():
		query.exclude = [shooter_rid]
	query.collide_with_areas = true
	query.collide_with_bodies = true

	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position = hit["position"] as Vector2
		var collider := hit.get("collider") as Object
		if collider != null and collider.has_method("take_projectile_hit"):
			collider.call("take_projectile_hit", direction)
		queue_free()
		return

	global_position = next_position
	traveled_distance += travel.length()
	z_index = clampi(int(round(global_position.y + 8.0)), -3000, 3000)

	if traveled_distance >= max_distance:
		queue_free()

func _draw() -> void:
	# A compact generated projectile made only from hard edged pixel blocks.
	draw_rect(Rect2(Vector2(-4.0, -1.0), Vector2(7.0, 3.0)), Color("54d8eb"), true)
	draw_rect(Rect2(Vector2(-1.0, -2.0), Vector2(4.0, 5.0)), Color("bdf8ff"), true)
	draw_rect(Rect2(Vector2(-6.0, 0.0), Vector2(2.0, 1.0)), Color("2b7786"), true)
