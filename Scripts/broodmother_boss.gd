extends CharacterBody2D
class_name SpacehaulBroodmother

signal defeated

const EnemyProjectileScript = preload("res://Scripts/enemy_projectile.gd")
const SalvagePickupScript = preload("res://Scripts/salvage_pickup.gd")
const EggScene = preload("res://Scenes/brood_egg.tscn")
const SFX = preload("res://Scripts/sound_fx.gd")

const FRAME_SIZE := Vector2(64.0, 64.0)
const FRAME_COUNT := 8
const SHEETS := {
	"idle": "res://Sprites/Bosses/broodmother_idle.png",
	"walk": "res://Sprites/Bosses/broodmother_walk.png",
	"attack": "res://Sprites/Bosses/broodmother_attack.png",
}

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var deck: ProceduralDeck
var health := 84
var max_health := 84
var move_speed := 42.0
var phase := 1

var _target: MechaController
var _dead := false
var _attacking := false
var _attack_token := 0
var _shot_time := 2.0
var _lay_time := 4.2
var _contact_time := 0.0
var _target_refresh_time := 0.0
var _repath_time := 0.0
var _path_step := Vector2.ZERO
var _strafe_time := 0.0
var _strafe_sign := 1.0
var _hurt_flash_time := 0.0
var _base_sprite_position := Vector2(0.0, -24.0)
var _rng := RandomNumberGenerator.new()
var _eggs: Array[Node] = []
var _dissolve_material: ShaderMaterial

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("bosses")
	collision_layer = 2
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_rng.seed = int(Time.get_ticks_usec()) ^ int(get_instance_id()) ^ 0xB00D
	_build_animations()
	animated_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	animated_sprite.position = _base_sprite_position
	animated_sprite.play("idle")
	_target_refresh_time = 0.05
	_strafe_sign = -1.0 if _rng.randf() < 0.5 else 1.0
	_update_depth_order()
	queue_redraw()
	_spawn_phase_pulse()

func _physics_process(delta: float) -> void:
	_update_depth_order()
	if _dead:
		return

	_shot_time = maxf(0.0, _shot_time - delta)
	_lay_time = maxf(0.0, _lay_time - delta)
	_contact_time = maxf(0.0, _contact_time - delta)
	_target_refresh_time -= delta
	_repath_time -= delta
	_strafe_time -= delta

	if _hurt_flash_time > 0.0:
		_hurt_flash_time = maxf(0.0, _hurt_flash_time - delta)
		if _hurt_flash_time <= 0.0:
			animated_sprite.modulate = Color.WHITE

	if _target_refresh_time <= 0.0:
		_target_refresh_time = 0.28
		_target = get_tree().get_first_node_in_group("player_mecha") as MechaController

	if _target == null or not is_instance_valid(_target):
		velocity = velocity.move_toward(Vector2.ZERO, 260.0 * delta)
		_play_motion_animation(false)
		move_and_slide()
		return

	if _attacking:
		velocity = velocity.move_toward(Vector2.ZERO, 760.0 * delta)
		move_and_slide()
		return

	if _lay_time <= 0.0 and _live_egg_count() < _max_live_eggs():
		_begin_lay_attack()
		return
	if _shot_time <= 0.0:
		_begin_spit_attack()
		return

	var to_target := _target.global_position - global_position
	var distance := to_target.length()
	var desired := 104.0
	var direction := Vector2.ZERO
	if distance > desired + 34.0:
		direction = _direction_toward_world(_target.global_position)
	elif distance < desired - 42.0:
		direction = -to_target.normalized()
	else:
		if _strafe_time <= 0.0:
			_strafe_time = _rng.randf_range(0.85, 1.55)
			if _rng.randf() < 0.42:
				_strafe_sign *= -1.0
		var tangent := Vector2(-to_target.y, to_target.x).normalized() * _strafe_sign
		direction = (tangent * 0.82 + to_target.normalized() * 0.18).normalized()

	var speed_scale := 1.0 + float(phase - 1) * 0.12
	velocity = velocity.move_toward(direction * move_speed * speed_scale, 300.0 * delta)
	_update_facing(to_target)
	_play_motion_animation(velocity.length_squared() > 20.0)
	move_and_slide()
	_try_contact_hit()

func _begin_lay_attack() -> void:
	if _attacking or _dead:
		return
	_attacking = true
	_attack_token += 1
	var token := _attack_token
	velocity = Vector2.ZERO
	animated_sprite.play("attack")
	SFX.play_nonstacking(self, "warning", -19.0, 0.74 + float(phase) * 0.04, 300)
	await get_tree().create_timer(0.38, false).timeout
	if not _attack_still_valid(token):
		return
	_lay_egg_cluster()
	await get_tree().create_timer(0.40, false).timeout
	if not _attack_still_valid(token):
		return
	_attacking = false
	_lay_time = _egg_lay_cooldown()
	animated_sprite.play("idle")

func _begin_spit_attack() -> void:
	if _attacking or _dead:
		return
	_attacking = true
	_attack_token += 1
	var token := _attack_token
	velocity = Vector2.ZERO
	var aim := Vector2.RIGHT
	if _target != null and is_instance_valid(_target):
		aim = (_target.global_position - global_position).normalized()
	_update_facing(aim)
	animated_sprite.play("attack")
	await get_tree().create_timer(0.30, false).timeout
	if not _attack_still_valid(token):
		return
	_fire_bio_volley(aim)
	await get_tree().create_timer(0.46, false).timeout
	if not _attack_still_valid(token):
		return
	_attacking = false
	_shot_time = _spit_cooldown()
	animated_sprite.play("idle")

func _attack_still_valid(token: int) -> bool:
	return not _dead and is_inside_tree() and token == _attack_token

func _lay_egg_cluster() -> void:
	var available := _max_live_eggs() - _live_egg_count()
	if available <= 0:
		return
	var egg_count := mini(available, 1 + phase)
	var used_positions: Array[Vector2] = []
	for i in range(egg_count):
		var landing := global_position
		for attempt in range(7):
			if deck != null:
				landing = deck.get_random_walkable_position_near(global_position, 2 + int(phase / 2), _rng)
			else:
				var angle := _rng.randf_range(0.0, TAU)
				landing = global_position + Vector2(cos(angle), sin(angle)) * _rng.randf_range(30.0, 58.0)
			var separated := true
			for used in used_positions:
				if used.distance_to(landing) < 18.0:
					separated = false
					break
			if separated:
				break
		used_positions.append(landing)

		var egg := EggScene.instantiate() as SpacehaulBroodEgg
		if egg == null:
			continue
		var parent_node := get_parent()
		if parent_node == null:
			parent_node = get_tree().current_scene
		egg.global_position = global_position + Vector2(0.0, -4.0)
		parent_node.add_child(egg)
		egg.hatch_requested.connect(_on_egg_hatch_requested)
		egg.removed.connect(_on_egg_removed)
		_eggs.append(egg)
		egg.setup(landing, _egg_hatch_delay(), phase)

func _on_egg_hatch_requested(world_position: Vector2, egg_phase: int) -> void:
	if _dead:
		return
	var manager := get_parent()
	if manager != null and manager.has_method("spawn_brood_hatchling"):
		manager.call("spawn_brood_hatchling", world_position, egg_phase)

func _on_egg_removed(egg: Node) -> void:
	_eggs.erase(egg)

func _live_egg_count() -> int:
	var alive: Array[Node] = []
	for egg in _eggs:
		if egg != null and is_instance_valid(egg) and not egg.is_queued_for_deletion():
			alive.append(egg)
	_eggs = alive
	return _eggs.size()

func _max_live_eggs() -> int:
	match phase:
		1: return 4
		2: return 5
		_: return 6

func _egg_lay_cooldown() -> float:
	match phase:
		1: return 8.6
		2: return 6.8
		_: return 5.2

func _egg_hatch_delay() -> float:
	match phase:
		1: return 7.2
		2: return 5.8
		_: return 4.6

func _spit_cooldown() -> float:
	match phase:
		1: return 3.2
		2: return 2.65
		_: return 2.15

func _fire_bio_volley(base_direction: Vector2) -> void:
	if base_direction.length_squared() <= 0.001:
		base_direction = Vector2.RIGHT
	var projectile_count := 3 + phase * 2
	var spread := 0.34 + float(phase - 1) * 0.08
	for i in range(projectile_count):
		var t := 0.5 if projectile_count <= 1 else float(i) / float(projectile_count - 1)
		var shot_direction := base_direction.rotated(lerpf(-spread, spread, t))
		var projectile := EnemyProjectileScript.new() as SpacehaulEnemyProjectile
		get_tree().current_scene.add_child(projectile)
		var muzzle := global_position + Vector2(0.0, -25.0) + shot_direction * 20.0
		projectile.setup(
			muzzle.round(),
			shot_direction,
			get_rid(),
			Color(1.15, 3.1, 0.62, 1.0),
			Color(0.28, 1.45, 0.22, 1.0),
			178.0 + float(phase) * 14.0
		)
	SFX.play(self, "enemy_shot", -13.5, _rng.randf_range(0.66, 0.76))

func _try_contact_hit() -> void:
	if _contact_time > 0.0 or _target == null or not is_instance_valid(_target):
		return
	if global_position.distance_to(_target.global_position) > 35.0:
		return
	var push := (_target.global_position - global_position).normalized()
	_target.take_projectile_hit(push, 16)
	_contact_time = 1.15

func take_projectile_hit(direction: Vector2) -> void:
	if _dead:
		return
	health -= 1
	_hurt_flash_time = 0.10
	animated_sprite.modulate = Color(2.5, 0.72, 0.58, 1.0)
	if direction.length_squared() > 0.001:
		velocity += direction.normalized() * 7.0
	_update_phase()
	queue_redraw()
	if health <= 0:
		_die()
	else:
		SFX.play_nonstacking(self, "enemy_hit", -25.0, _rng.randf_range(0.74, 0.88), 65)

func take_hurt() -> void:
	take_projectile_hit(Vector2.ZERO)

func _update_phase() -> void:
	var ratio := float(health) / float(max_health)
	var next_phase := 1
	if ratio <= 0.30:
		next_phase = 3
	elif ratio <= 0.60:
		next_phase = 2
	if next_phase == phase:
		return
	phase = next_phase
	_shot_time = minf(_shot_time, 0.85)
	_lay_time = minf(_lay_time, 1.4)
	SFX.play_nonstacking(self, "warning", -13.0, 0.84 + float(phase) * 0.06, 350)
	_spawn_phase_pulse()

func _spawn_phase_pulse() -> void:
	var ring := Line2D.new()
	ring.width = 2.0
	ring.default_color = Color(0.55, 3.0, 0.65, 0.82)
	ring.antialiased = false
	var points := PackedVector2Array()
	for i in range(25):
		var angle := TAU * float(i) / 24.0
		points.append((Vector2(cos(angle), sin(angle)) * 18.0).round())
	ring.points = points
	ring.z_as_relative = false
	ring.z_index = 1900
	get_tree().current_scene.add_child(ring)
	ring.global_position = global_position + Vector2(0.0, -18.0)
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	ring.material = additive
	var tw := ring.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector2.ONE * 3.0, 0.34)
	tw.tween_property(ring, "modulate:a", 0.0, 0.34)
	tw.set_parallel(false)
	tw.tween_callback(ring.queue_free)

func _die() -> void:
	if _dead:
		return
	_dead = true
	_attacking = false
	_attack_token += 1
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)
	for egg in _eggs.duplicate():
		if egg != null and is_instance_valid(egg) and egg.has_method("destroy_without_hatch"):
			egg.call("destroy_without_hatch")
	_spawn_boss_salvage()
	SFX.play_explosion(self, -5.5, 0.72)
	SFX.play(self, "enemy_die", -11.5, 0.70)
	defeated.emit()
	_start_pixel_dissolve()

func _spawn_boss_salvage() -> void:
	var pickup := SalvagePickupScript.new() as SpacehaulSalvagePickup
	if pickup == null:
		return
	var parent_node := get_parent()
	if parent_node == null:
		parent_node = get_tree().current_scene
	parent_node.add_child(pickup)
	pickup.setup(global_position + Vector2(0.0, -12.0), 14)

func _start_pixel_dissolve() -> void:
	animated_sprite.speed_scale = 0.0
	animated_sprite.modulate = Color.WHITE
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode unshaded;
uniform float dissolve_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 edge_color : source_color = vec4(0.42, 1.0, 0.22, 1.0);
float pixel_hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123); }
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (tex.a < 0.01) { discard; }
	vec2 tex_size = vec2(textureSize(TEXTURE, 0));
	vec2 pixel = floor(UV * tex_size);
	float noise = pixel_hash(pixel);
	if (noise < dissolve_amount) { discard; }
	float edge = step(dissolve_amount, noise) * (1.0 - step(dissolve_amount + 0.08, noise));
	tex.rgb += edge_color.rgb * edge * 2.0;
	COLOR = tex * COLOR;
}
"""
	_dissolve_material = ShaderMaterial.new()
	_dissolve_material.shader = shader
	_dissolve_material.set_shader_parameter("dissolve_amount", 0.0)
	animated_sprite.material = _dissolve_material
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.tween_method(_set_dissolve_amount, 0.0, 1.0, 1.05)
	tween.tween_callback(queue_free)

func _set_dissolve_amount(value: float) -> void:
	if _dissolve_material != null:
		_dissolve_material.set_shader_parameter("dissolve_amount", value)

func _direction_toward_world(destination: Vector2) -> Vector2:
	if deck != null and _repath_time <= 0.0:
		_repath_time = _rng.randf_range(0.28, 0.48)
		_path_step = deck.get_next_path_step(global_position, destination)
	var waypoint := _path_step if _path_step != Vector2.ZERO else destination
	var direction := waypoint - global_position
	if direction.length_squared() <= 4.0:
		direction = destination - global_position
	if direction.length_squared() <= 0.001:
		return Vector2.ZERO
	return direction.normalized()

func _play_motion_animation(moving: bool) -> void:
	var wanted := "walk" if moving else "idle"
	if animated_sprite.animation != wanted:
		animated_sprite.play(wanted)

func _update_facing(direction: Vector2) -> void:
	if absf(direction.x) <= 0.05:
		return
	# The authored boss faces left, matching the standard enemy sheets.
	animated_sprite.flip_h = direction.x > 0.0

func _update_depth_order() -> void:
	z_as_relative = false
	z_index = clampi(int(round(global_position.y + 3.0)), -3000, 3000)

func _build_animations() -> void:
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	for anim_name in ["idle", "walk", "attack"]:
		frames.add_animation(anim_name)
		frames.set_animation_loop(anim_name, anim_name != "attack")
		frames.set_animation_speed(anim_name, 8.0 if anim_name == "idle" else 10.0)
		var texture := load(String(SHEETS[anim_name])) as Texture2D
		if texture == null:
			continue
		for frame_index in range(FRAME_COUNT):
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(float(frame_index) * FRAME_SIZE.x, 0.0, FRAME_SIZE.x, FRAME_SIZE.y)
			frames.add_frame(anim_name, atlas)
	animated_sprite.sprite_frames = frames

func _draw() -> void:
	if _dead or max_health <= 0:
		return
	var ratio := clampf(float(health) / float(max_health), 0.0, 1.0)
	var width := 58.0
	var y := -62.0
	draw_rect(Rect2(Vector2(-width * 0.5 - 1.0, y - 1.0), Vector2(width + 2.0, 5.0)), Color(0.015, 0.02, 0.025, 0.95), true)
	draw_rect(Rect2(Vector2(-width * 0.5, y), Vector2(width, 3.0)), Color(0.20, 0.04, 0.08, 1.0), true)
	draw_rect(Rect2(Vector2(-width * 0.5, y), Vector2(maxf(1.0, width * ratio), 3.0)), Color(0.42, 1.0, 0.24, 1.0), true)
