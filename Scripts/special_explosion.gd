extends Node2D
class_name SpacehaulSpecialExplosion

const EXPLOSION_FRAME_COUNT := 14
const EXPLOSION_FPS := 18.0
const EXPLOSION_PATH := "res://Sprites/VFX/Explosion/explosion%d.png"

var core_color := Color(2.8, 1.5, 0.4, 1.0)
var glow_color := Color(1.5, 0.55, 0.12, 1.0)
var radius := 18.0
var procedural_duration := 0.28
var total_duration := 0.28
var elapsed := 0.0
var seed := 1

func setup(world_position: Vector2, new_core: Color, new_glow: Color, new_radius: float = 18.0, new_duration: float = 0.28) -> void:
	global_position = world_position.round()
	core_color = new_core
	glow_color = new_glow
	radius = new_radius
	procedural_duration = maxf(new_duration, 0.001)
	seed = int(Time.get_ticks_usec()) ^ int(global_position.x * 17.0) ^ int(global_position.y * 31.0)
	z_as_relative = false
	z_index = clampi(int(round(global_position.y)) + 80, -3000, 3000)

	# Preserve the existing generated additive burst. The authored explosion
	# animation is layered on top as a child so both effects play together.
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive

	var animation_duration := _build_explosion_animation()
	total_duration = maxf(procedural_duration, animation_duration)
	queue_redraw()

func _build_explosion_animation() -> float:
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	frames.add_animation("explode")
	frames.set_animation_loop("explode", false)
	frames.set_animation_speed("explode", EXPLOSION_FPS)

	var loaded_frames := 0
	for frame_index in range(1, EXPLOSION_FRAME_COUNT + 1):
		var path := EXPLOSION_PATH % frame_index
		if not ResourceLoader.exists(path):
			continue
		var texture := load(path) as Texture2D
		if texture != null:
			frames.add_frame("explode", texture)
			loaded_frames += 1

	if loaded_frames <= 0:
		return 0.0

	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	sprite.animation = &"explode"
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_index = 1

	# The source VFX is 64x64. Scale it with the existing impact radius so
	# cannon/artillery hits read larger while small chain impacts stay tight.
	var impact_scale := clampf(radius / 18.0, 0.55, 1.45)
	sprite.scale = Vector2.ONE * impact_scale
	add_child(sprite)
	sprite.play("explode")

	return float(loaded_frames) / EXPLOSION_FPS

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= total_duration:
		queue_free()
		return
	queue_redraw()

func _rand01(i: int) -> float:
	return absf(fmod(sin(float(seed + i * 97) * 12.9898) * 43758.5453, 1.0))

func _pixel(p: Vector2, c: Color, alpha: float = 1.0) -> void:
	var q := p.round()
	# Existing crisp generated impact: 2x2 additive bloom around a 1x1 pixel.
	draw_rect(Rect2(q - Vector2(0.5, 0.5), Vector2(2.0, 2.0)), Color(glow_color.r, glow_color.g, glow_color.b, 0.22 * alpha), true)
	draw_rect(Rect2(q, Vector2.ONE), Color(c.r, c.g, c.b, c.a * alpha), true)

func _draw() -> void:
	# The authored sprite can live longer than this procedural burst. Clamp the
	# generated portion to its original timing instead of stretching it.
	var p := clampf(elapsed / procedural_duration, 0.0, 1.0)
	var expand := sin(p * PI * 0.88)
	var fade := 1.0 - p
	if fade <= 0.0:
		return

	_pixel(Vector2.ZERO, Color(core_color.r * 1.2, core_color.g * 1.2, core_color.b * 1.2, 1.0), fade)
	for i in range(20):
		var angle := TAU * (float(i) / 20.0) + (_rand01(i) - 0.5) * 0.35
		var dist := radius * expand * lerpf(0.38, 1.0, _rand01(40 + i))
		var pos := Vector2(cos(angle), sin(angle)) * dist
		_pixel(pos, core_color, fade * lerpf(0.45, 1.0, _rand01(80 + i)))
	for i in range(8):
		var angle2 := TAU * (float(i) / 8.0)
		var pos2 := Vector2(cos(angle2), sin(angle2)) * radius * 0.55 * expand
		_pixel(pos2, Color(core_color.r * 1.15, core_color.g * 1.15, core_color.b * 1.15, 1.0), fade)
