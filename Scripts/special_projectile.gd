extends Node2D
class_name SpacehaulSpecialProjectile

var core_color := Color.WHITE
var glow_color := Color.CYAN
var pixel_size := 1.0

func setup(world_position: Vector2, new_core: Color, new_glow: Color, new_pixel_size: float = 1.0) -> void:
	global_position = world_position.round()
	core_color = new_core
	glow_color = new_glow
	pixel_size = maxf(1.0, new_pixel_size)
	z_as_relative = false
	z_index = 1800
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive
	queue_redraw()

func _draw() -> void:
	var size := Vector2.ONE * pixel_size
	var base := -size * 0.5
	# Tight 2x2 bloom regardless of projectile core size.
	draw_rect(Rect2(Vector2(-1.0, -1.0), Vector2(2.0, 2.0)), Color(glow_color.r, glow_color.g, glow_color.b, 0.38), true)
	draw_rect(Rect2(base, size), core_color, true)
