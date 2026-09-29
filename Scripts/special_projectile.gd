extends Node2D
class_name SpacehaulSpecialProjectile

var core_color := Color.WHITE
var glow_color := Color.CYAN

func setup(
	world_position: Vector2,
	new_core: Color,
	new_glow: Color,
	_new_pixel_size: float = 1.0,
	with_gas: bool = false
) -> void:
	global_position = world_position.round()
	core_color = new_core
	glow_color = new_glow
	z_as_relative = false
	z_index = 1800
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive
	if with_gas:
		_build_attached_gas()
	queue_redraw()

func _normalized_gas_color() -> Color:
	var source := glow_color
	var peak := maxf(source.r, maxf(source.g, source.b))
	if peak > 1.0:
		source.r /= peak
		source.g /= peak
		source.b /= peak
	return Color(
		clampf(source.r, 0.0, 1.0),
		clampf(source.g, 0.0, 1.0),
		clampf(source.b, 0.0, 1.0),
		1.0
	)

func _gas_quad(size: Vector2) -> PackedVector2Array:
	var half := size * 0.5
	return PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y),
	])

func _build_attached_gas() -> void:
	# Manual spark pixels do not use the shared ability emitter, so give them the
	# same tiny hazard-style gas envelope here. These children use normal alpha
	# blending (not the projectile's additive material), which keeps the gas soft.
	var gas := _normalized_gas_color()
	var puff_specs := [
		{"size": Vector2(6.0, 4.0), "offset": Vector2(-1.0, 0.0), "alpha": 0.075},
		{"size": Vector2(4.0, 4.0), "offset": Vector2(1.0, -1.0), "alpha": 0.11},
		{"size": Vector2(2.0, 4.0), "offset": Vector2.ZERO, "alpha": 0.15},
	]
	for spec in puff_specs:
		var puff := Polygon2D.new()
		puff.polygon = _gas_quad(spec["size"])
		puff.position = spec["offset"]
		puff.color = Color(gas.r, gas.g, gas.b, spec["alpha"])
		puff.z_index = -1
		puff.use_parent_material = false
		add_child(puff)

func _draw() -> void:
	# One world-space pixel is one source-art pixel. The 2x2 rectangle is only
	# the additive bloom around the 1x1 core and scales with the camera exactly
	# like the native mecha sprite pixels.
	draw_rect(Rect2(Vector2(-1.0, -1.0), Vector2(2.0, 2.0)), Color(glow_color.r, glow_color.g, glow_color.b, 0.34), true)
	draw_rect(Rect2(Vector2.ZERO, Vector2.ONE), core_color, true)
