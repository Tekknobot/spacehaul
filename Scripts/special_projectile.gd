extends Node2D
class_name SpacehaulSpecialProjectile

var core_color := Color.WHITE
var glow_color := Color.CYAN

func setup(world_position: Vector2, new_core: Color, new_glow: Color, _new_pixel_size: float = 1.0) -> void:
	global_position = world_position.round()
	core_color = new_core
	glow_color = new_glow
	z_as_relative = false
	z_index = 1800
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive
	queue_redraw()

func _draw() -> void:
	# One world-space pixel is one source-art pixel. The 2x2 rectangle is only
	# the additive bloom around the 1x1 core and scales with the camera exactly
	# like the native mecha sprite pixels.
	draw_rect(Rect2(Vector2(-1.0, -1.0), Vector2(2.0, 2.0)), Color(glow_color.r, glow_color.g, glow_color.b, 0.34), true)
	draw_rect(Rect2(Vector2.ZERO, Vector2.ONE), core_color, true)
