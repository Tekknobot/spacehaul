extends Node2D
class_name SpacehaulEnemyProjectile

const EnemyAttackVfx = preload("res://Scripts/enemy_attack_vfx.gd")

@export var speed := 180.0
@export var max_distance := 340.0

var direction := Vector2.RIGHT
var traveled := 0.0
var shooter_rid: RID
var core_color := Color(1.2, 3.0, 1.1, 1.0)
var glow_color := Color(0.25, 1.4, 0.35, 1.0)
var visual_profile := "bio"
var strong_impact := false

func setup(
	start_position: Vector2,
	travel_direction: Vector2,
	source_rid: RID,
	color: Color,
	glow: Color,
	projectile_speed: float = 180.0,
	profile: String = "bio",
	strong: bool = false
) -> void:
	global_position = start_position.round()
	direction = travel_direction.normalized()
	if direction.length_squared() <= 0.001:
		direction = Vector2.RIGHT
	shooter_rid = source_rid
	core_color = color
	glow_color = glow
	speed = projectile_speed
	visual_profile = profile
	strong_impact = strong
	z_as_relative = false
	z_index = 1850
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive

	# Hostile shots now use the exact same hard-pixel + translucent gas emitter
	# language as player abilities. The emitter survives the projectile long
	# enough for the final few trail pixels to dissipate after impact.
	var root := get_tree().current_scene
	if root != null:
		var emit_time := minf(2.4, max_distance / maxf(speed, 1.0) + 0.10)
		var emit_rate := 34.0
		match visual_profile:
			"venom": emit_rate = 26.0
			"bio": emit_rate = 30.0
			"ember", "electric": emit_rate = 32.0
		EnemyAttackVfx.spawn_follow(root, self, core_color, glow_color, visual_profile, emit_time, emit_rate)
		EnemyAttackVfx.spawn_burst(root, global_position, core_color, glow_color, visual_profile, 4 if not strong_impact else 7, 16.0 if not strong_impact else 24.0)
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
		_spawn_impact(true)
		queue_free()
		return

	global_position = next_position
	traveled += travel.length()
	if traveled >= max_distance:
		_spawn_impact(false)
		queue_free()

func _spawn_impact(hit_something: bool) -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	EnemyAttackVfx.spawn_impact(
		root,
		global_position.round(),
		core_color,
		glow_color,
		visual_profile,
		strong_impact and hit_something
	)

func _draw() -> void:
	# Layered hostile bolt: 1x1 authored-pixel core, 2x2 additive bloom, and a
	# single trailing pixel. The gas body is supplied by the shared emitter.
	draw_rect(Rect2(Vector2(-1.0, -1.0), Vector2(2.0, 2.0)), Color(glow_color.r, glow_color.g, glow_color.b, 0.38), true)
	draw_rect(Rect2(Vector2.ZERO, Vector2.ONE), core_color, true)
	var tail := (-direction * (3.0 if strong_impact else 2.0)).round()
	draw_rect(Rect2(tail, Vector2.ONE), Color(core_color.r, core_color.g, core_color.b, 0.62), true)
	if strong_impact:
		var side := Vector2(-direction.y, direction.x).round()
		draw_rect(Rect2(side, Vector2.ONE), Color(glow_color.r, glow_color.g, glow_color.b, 0.52), true)
