extends Node2D
class_name SpacehaulSpecialExplosion

const SFX = preload("res://Scripts/sound_fx.gd")

const EXPLOSION_FRAME_COUNT := 14
const EXPLOSION_FPS := 18.0
const EXPLOSION_PATH := "res://Sprites/VFX/Explosion/explosion%d.png"

static var _cached_explosion_frames: SpriteFrames

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

	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive

	var animation_duration := _build_explosion_animation()
	total_duration = maxf(procedural_duration, animation_duration)

	# Scale pitch slightly with blast size while routing every explosion through
	# one shared voice. Multiple simultaneous explosion VFX therefore remain
	# visually independent without increasing the explosion sample's volume.
	var size_pitch := clampf(1.06 - (radius - 12.0) * 0.006, 0.82, 1.08)
	SFX.play_explosion(self, -10.5, size_pitch)
	queue_redraw()

func _get_explosion_frames() -> SpriteFrames:
	if _cached_explosion_frames != null:
		return _cached_explosion_frames
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	frames.add_animation("explode")
	frames.set_animation_loop("explode", false)
	frames.set_animation_speed("explode", EXPLOSION_FPS)
	for frame_index in range(1, EXPLOSION_FRAME_COUNT + 1):
		var path := EXPLOSION_PATH % frame_index
		if not ResourceLoader.exists(path):
			continue
		var texture := load(path) as Texture2D
		if texture != null:
			frames.add_frame("explode", texture)
	_cached_explosion_frames = frames
	return _cached_explosion_frames

func _build_explosion_animation() -> float:
	var frames := _get_explosion_frames()
	var loaded_frames := frames.get_frame_count("explode")
	if loaded_frames <= 0:
		return 0.0
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	sprite.animation = &"explode"
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.use_parent_material = true
	sprite.z_index = 1
	# Keep the authored VFX at native 1:1 scale. Larger impacts get more
	# procedural pixels/radius, never fractional sprite scaling.
	sprite.scale = Vector2.ONE
	add_child(sprite)
	sprite.play("explode")
	return float(loaded_frames) / EXPLOSION_FPS

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= total_duration:
		queue_free()
		return
	queue_redraw()

func _rand01(index: int) -> float:
	return absf(fmod(sin(float(seed + index * 97) * 12.9898) * 43758.5453, 1.0))

func _pixel(position: Vector2, color: Color, alpha: float = 1.0) -> void:
	var p := position.round()
	draw_rect(Rect2(p - Vector2.ONE, Vector2(2.0, 2.0)), Color(glow_color.r, glow_color.g, glow_color.b, 0.20 * alpha), true)
	draw_rect(Rect2(p, Vector2.ONE), Color(color.r, color.g, color.b, color.a * alpha), true)

func _draw() -> void:
	var progress := clampf(elapsed / procedural_duration, 0.0, 1.0)
	var expand := sin(progress * PI * 0.88)
	var fade := 1.0 - progress
	if fade <= 0.0:
		return
	_pixel(Vector2.ZERO, Color(core_color.r * 1.2, core_color.g * 1.2, core_color.b * 1.2, 1.0), fade)
	for i in range(20):
		var angle := TAU * (float(i) / 20.0) + (_rand01(i) - 0.5) * 0.35
		var distance := radius * expand * lerpf(0.38, 1.0, _rand01(40 + i))
		_pixel(Vector2(cos(angle), sin(angle)) * distance, core_color, fade * lerpf(0.45, 1.0, _rand01(80 + i)))
	for i in range(8):
		var angle2 := TAU * (float(i) / 8.0)
		var pos2 := Vector2(cos(angle2), sin(angle2)) * radius * 0.55 * expand
		_pixel(pos2, Color(core_color.r * 1.15, core_color.g * 1.15, core_color.b * 1.15, 1.0), fade)
