extends CharacterBody2D
class_name SpacehaulBroodEgg

signal hatch_requested(world_position: Vector2, phase: int)
signal removed(egg: Node)

const SFX = preload("res://Scripts/sound_fx.gd")
const EnemyAttackVfx = preload("res://Scripts/enemy_attack_vfx.gd")
const EGG_SHEET := "res://Sprites/Bosses/egg_hatch.png"
const FRAME_SIZE := Vector2(32.0, 32.0)
const FRAME_COUNT := 16
const WOBBLE_FRAME_COUNT := 14

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var health := 5
var max_health := 5
var phase := 1
var hatch_delay := 7.0

var _age := 0.0
var _hatch_time := 7.0
var _resolved := false
var _landed := false
var _base_sprite_position := Vector2(0.0, -12.0)
var _rng := RandomNumberGenerator.new()
var _warning_fx_played := false

func setup(landing_position: Vector2, delay: float, boss_phase: int) -> void:
	phase = clampi(boss_phase, 1, 3)
	health = 4 + phase
	max_health = health
	hatch_delay = maxf(2.0, delay)
	_hatch_time = hatch_delay
	var start := global_position
	var target := landing_position.round()
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", target, 0.34)
	tween.finished.connect(_on_landed)
	EnemyAttackVfx.spawn_follow(
		get_tree().current_scene,
		self,
		Color(1.35, 3.05, 0.62, 1.0),
		Color(0.26, 1.35, 0.20, 1.0),
		"bio",
		0.38,
		42.0
	)
	if start.distance_to(target) < 2.0:
		global_position = target

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("boss_eggs")
	collision_layer = 2
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_rng.seed = int(Time.get_ticks_usec()) ^ int(get_instance_id())
	_build_animation()
	animated_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	animated_sprite.position = _base_sprite_position
	animated_sprite.play("wobble")
	_update_depth_order()

func _physics_process(delta: float) -> void:
	_update_depth_order()
	if _resolved:
		return
	_age += delta

	# Keep the egg visually alive without drifting its gameplay collider: the
	# sprite makes tiny whole-pixel shivers in place while the shell cycles.
	var wiggle_x := roundf(sin(_age * 8.5 + float(get_instance_id() % 7)))
	var wiggle_y := roundf(sin(_age * 5.8 + 1.7))
	animated_sprite.position = _base_sprite_position + Vector2(wiggle_x, wiggle_y)

	if not _landed:
		return
	_hatch_time -= delta
	if not _warning_fx_played and _hatch_time <= minf(1.15, hatch_delay * 0.24):
		_warning_fx_played = true
		EnemyAttackVfx.spawn_shock_warning(
			get_tree().current_scene,
			global_position,
			13.0 + float(phase),
			Color(1.50, 3.15, 0.66, 1.0),
			Color(0.28, 1.38, 0.20, 1.0),
			0.48
		)
	if _hatch_time <= 0.0:
		_resolve(true)

func _on_landed() -> void:
	if _resolved:
		return
	_landed = true
	global_position = global_position.round()
	_hatch_time = hatch_delay
	EnemyAttackVfx.spawn_impact(
		get_tree().current_scene,
		global_position,
		Color(1.35, 3.0, 0.58, 1.0),
		Color(0.24, 1.28, 0.18, 1.0),
		"bio",
		false
	)

func take_projectile_hit(_direction: Vector2) -> void:
	if _resolved:
		return
	health -= 1
	animated_sprite.modulate = Color(3.0, 0.9, 0.62, 1.0)
	var flash := create_tween()
	flash.tween_interval(0.06)
	flash.tween_property(animated_sprite, "modulate", Color.WHITE, 0.08)
	if health <= 0:
		_resolve(false)
	else:
		SFX.play(self, "enemy_hit", -26.0, _rng.randf_range(1.05, 1.20))

func take_hurt() -> void:
	take_projectile_hit(Vector2.ZERO)

func destroy_without_hatch() -> void:
	_resolve(false)

func _resolve(natural_hatch: bool) -> void:
	if _resolved:
		return
	_resolved = true
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)
	animated_sprite.modulate = Color.WHITE
	animated_sprite.position = _base_sprite_position
	animated_sprite.play("hatch")
	EnemyAttackVfx.spawn_impact(
		get_tree().current_scene,
		global_position + Vector2(0.0, -10.0),
		Color(1.55, 3.2, 0.68, 1.0),
		Color(0.30, 1.40, 0.20, 1.0),
		"bio",
		true
	)

	# Destruction deliberately uses the exact same shell-break animation as a
	# successful hatch, per the authored egg asset. Only a natural hatch creates
	# a broodling at the end of the animation.
	if natural_hatch:
		SFX.play(self, "enemy_shot", -23.0, _rng.randf_range(0.68, 0.78))
	else:
		SFX.play_explosion(self, -20.0, _rng.randf_range(1.15, 1.32))

	await get_tree().create_timer(0.92, false).timeout
	if not is_inside_tree():
		return
	if natural_hatch:
		hatch_requested.emit(global_position, phase)
	removed.emit(self)
	queue_free()

func _build_animation() -> void:
	var texture := load(EGG_SHEET) as Texture2D
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")

	frames.add_animation("wobble")
	frames.set_animation_loop("wobble", true)
	frames.set_animation_speed("wobble", 8.0)
	frames.add_animation("hatch")
	frames.set_animation_loop("hatch", false)
	frames.set_animation_speed("hatch", 17.0)

	if texture != null:
		for frame_index in range(WOBBLE_FRAME_COUNT):
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(float(frame_index) * FRAME_SIZE.x, 0.0, FRAME_SIZE.x, FRAME_SIZE.y)
			frames.add_frame("wobble", atlas)
		for frame_index in range(FRAME_COUNT):
			var hatch_atlas := AtlasTexture.new()
			hatch_atlas.atlas = texture
			hatch_atlas.region = Rect2(float(frame_index) * FRAME_SIZE.x, 0.0, FRAME_SIZE.x, FRAME_SIZE.y)
			frames.add_frame("hatch", hatch_atlas)
	animated_sprite.sprite_frames = frames

func _update_depth_order() -> void:
	z_as_relative = false
	z_index = clampi(int(round(global_position.y + 2.0)), -3000, 3000)
