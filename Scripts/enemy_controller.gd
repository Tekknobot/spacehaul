extends CharacterBody2D
class_name SpacehaulEnemy

signal defeated(salvage_value: int, was_elite: bool, death_position: Vector2)

const EnemyProjectileScript = preload("res://Scripts/enemy_projectile.gd")
const SalvagePickupScript = preload("res://Scripts/salvage_pickup.gd")
const SFX = preload("res://Scripts/sound_fx.gd")
const EnemyAttackVfx = preload("res://Scripts/enemy_attack_vfx.gd")
const ParticleScript = preload("res://Scripts/ability_particle_emitter.gd")

const FRAME_SIZE := Vector2(32.0, 32.0)
const FRAME_COUNT := 8
const ENEMY_SHEETS := {
	"alien_1": "res://Sprites/Enemies/alien_1.png",
	"beetle_1": "res://Sprites/Enemies/beetle_1.png",
	"beetle_2": "res://Sprites/Enemies/beetle_2.png",
	"bug_1": "res://Sprites/Enemies/bug_1.png",
	"bug_2": "res://Sprites/Enemies/bug_2.png",
	"bug_3": "res://Sprites/Enemies/bug_3.png",
	"bug_4": "res://Sprites/Enemies/bug_4.png",
	"spider_1": "res://Sprites/Enemies/spider_1.png",
	"spider_2": "res://Sprites/Enemies/spider_2.png",
	"spider_3": "res://Sprites/Enemies/spider_3.png",
}

@export var enemy_type := "bug_1"

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var deck: ProceduralDeck
var home_position := Vector2.ZERO
var health := 2
var max_health := 2
var move_speed := 66.0
var aggro_range := 270.0
var melee_range := 18.0
var attack_cooldown := 0.8
var preferred_range := 0.0
var ranged := false
var charger := false
var shocker := false
var projectile_speed := 180.0
var projectile_color := Color(1.3, 3.0, 1.2, 1.0)
var projectile_glow := Color(0.25, 1.3, 0.35, 1.0)
var salvage_value := 1
var elite := false
var omega_carrier := false

var _target: MechaController
var _dead := false
var _hurt_time := 0.0
var _attack_time := 0.0
var _repath_time := 0.0
var _target_refresh_time := 0.0
var _wander_time := 0.0
var _wander_target := Vector2.ZERO
var _path_step := Vector2.ZERO
var _charge_windup := 0.0
var _charge_time := 0.0
var _charge_direction := Vector2.RIGHT
var _charge_has_hit := false
var _rng := RandomNumberGenerator.new()
var _dissolve_material: ShaderMaterial
var _base_sprite_position := Vector2(0.0, -12.0)
var _health_bar_time := 0.0
var _telegraphing := false
var _base_modulate := Color.WHITE
var _omega_fx_time := 0.0
var _omega_beam: Line2D
var _omega_beam_glow: Line2D
var _omega_ring: Line2D
var _omega_ring_glow: Line2D
var _omega_orbit_lines: Array[Line2D] = []
var _omega_label: Label

func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 2
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_rng.seed = enemy_type.hash() ^ int(Time.get_ticks_usec()) ^ int(get_instance_id())
	_configure_archetype()
	_build_animation()
	animated_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	animated_sprite.position = _base_sprite_position
	animated_sprite.play("move")
	home_position = global_position
	_wander_target = home_position
	_attack_time = _rng.randf_range(0.15, attack_cooldown)
	_target_refresh_time = _rng.randf_range(0.05, 0.35)
	_repath_time = _rng.randf_range(0.05, 0.45)
	_update_depth_order()

func _physics_process(delta: float) -> void:
	_update_depth_order()
	if _dead:
		return

	if omega_carrier:
		_update_omega_carrier_vfx(delta)

	_attack_time = maxf(0.0, _attack_time - delta)
	if _health_bar_time > 0.0:
		_health_bar_time = maxf(0.0, _health_bar_time - delta)
		if _health_bar_time <= 0.0 and not elite:
			queue_redraw()
	_target_refresh_time -= delta
	_repath_time -= delta
	_wander_time -= delta

	if _hurt_time > 0.0:
		_hurt_time = maxf(0.0, _hurt_time - delta)
		velocity = velocity.move_toward(Vector2.ZERO, 520.0 * delta)
		if _hurt_time <= 0.0:
			animated_sprite.modulate = _base_modulate
			animated_sprite.position = _base_sprite_position
		move_and_slide()
		return

	if _target_refresh_time <= 0.0:
		_target_refresh_time = _rng.randf_range(0.30, 0.52)
		_target = _find_target()

	if _charge_windup > 0.0:
		_charge_windup = maxf(0.0, _charge_windup - delta)
		velocity = Vector2.ZERO
		animated_sprite.speed_scale = 0.35
		if _charge_windup <= 0.0:
			_charge_time = 0.55
			animated_sprite.speed_scale = 1.55
			var palette := _attack_palette()
			EnemyAttackVfx.spawn_burst(get_tree().current_scene, global_position + Vector2(0.0, -7.0), palette["core"], palette["glow"], "sparks", 8, 34.0)
			EnemyAttackVfx.spawn_follow(get_tree().current_scene, self, palette["core"], palette["glow"], "sparks", 0.58, 48.0)
		move_and_slide()
		return

	if _charge_time > 0.0:
		_charge_time = maxf(0.0, _charge_time - delta)
		velocity = _charge_direction * move_speed * 2.9
		_update_facing(_charge_direction)
		move_and_slide()
		_try_contact_hit()
		if get_slide_collision_count() > 0:
			_charge_time = 0.0
			velocity *= 0.25
		return

	if _telegraphing:
		velocity = velocity.move_toward(Vector2.ZERO, 720.0 * delta)
		animated_sprite.speed_scale = 0.45
		move_and_slide()
		return

	animated_sprite.speed_scale = 1.0
	if _target == null or not is_instance_valid(_target):
		_process_wander(delta)
		return

	var to_target := _target.global_position - global_position
	var distance := to_target.length()
	if distance > aggro_range:
		_process_wander(delta)
		return

	if charger and distance < 150.0 and distance > 34.0 and _attack_time <= 0.0:
		_begin_charge(to_target.normalized())
		return

	if shocker and distance <= 54.0 and _attack_time <= 0.0:
		_begin_shock_telegraph()
		return

	if ranged:
		_process_ranged(delta, to_target, distance)
	else:
		_process_melee(delta, to_target, distance)

func _process_melee(delta: float, to_target: Vector2, distance: float) -> void:
	if distance <= melee_range:
		velocity = velocity.move_toward(Vector2.ZERO, 640.0 * delta)
		_try_contact_hit()
		move_and_slide()
		return

	var direction := _direction_toward_target(to_target)
	velocity = velocity.move_toward(direction * move_speed, 520.0 * delta)
	_update_facing(direction)
	move_and_slide()

func _process_ranged(delta: float, to_target: Vector2, distance: float) -> void:
	var direction := to_target.normalized()
	if distance <= preferred_range * 0.72:
		var retreat := -direction
		velocity = velocity.move_toward(retreat * move_speed * 0.78, 420.0 * delta)
		_update_facing(direction)
	elif distance > preferred_range * 1.16:
		var chase := _direction_toward_target(to_target)
		velocity = velocity.move_toward(chase * move_speed, 460.0 * delta)
		_update_facing(chase)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, 560.0 * delta)
		_update_facing(direction)
		if _attack_time <= 0.0:
			_begin_ranged_telegraph(direction)
	move_and_slide()

func _process_wander(delta: float) -> void:
	if _wander_time <= 0.0 or global_position.distance_to(_wander_target) <= 7.0:
		_wander_time = _rng.randf_range(1.2, 3.2)
		if deck != null:
			_wander_target = deck.get_random_walkable_position_near(home_position, 5, _rng)
		else:
			var angle := _rng.randf_range(0.0, TAU)
			_wander_target = home_position + Vector2(cos(angle), sin(angle)) * _rng.randf_range(24.0, 72.0)

	var to_wander := _wander_target - global_position
	if to_wander.length_squared() <= 16.0:
		velocity = velocity.move_toward(Vector2.ZERO, 420.0 * delta)
		move_and_slide()
		return
	var direction := _direction_toward_world(_wander_target)
	velocity = velocity.move_toward(direction * move_speed * 0.48, 360.0 * delta)
	_update_facing(direction)
	move_and_slide()

func _direction_toward_target(fallback_vector: Vector2) -> Vector2:
	if _target == null:
		return fallback_vector.normalized()
	return _direction_toward_world(_target.global_position)

func _direction_toward_world(destination: Vector2) -> Vector2:
	if deck != null and _repath_time <= 0.0:
		_repath_time = _rng.randf_range(0.38, 0.68)
		_path_step = deck.get_next_path_step(global_position, destination)
	var waypoint := _path_step if _path_step != Vector2.ZERO else destination
	var direction := waypoint - global_position
	if direction.length_squared() <= 4.0:
		direction = destination - global_position
	if direction.length_squared() <= 0.001:
		return Vector2.ZERO
	return direction.normalized()

func _find_target() -> MechaController:
	var best: MechaController
	var best_distance := INF
	for node in get_tree().get_nodes_in_group("player_mecha"):
		var candidate := node as MechaController
		if candidate == null:
			continue
		var distance := global_position.distance_squared_to(candidate.global_position)
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best

func _begin_charge(direction: Vector2) -> void:
	_charge_direction = direction
	_charge_has_hit = false
	_charge_windup = 0.44
	_attack_time = attack_cooldown * 2.2
	velocity = Vector2.ZERO
	_update_facing(direction)
	_spawn_telegraph(direction)

func _spawn_telegraph(direction: Vector2) -> void:
	var palette := _attack_palette()
	EnemyAttackVfx.spawn_charge_telegraph(
		get_tree().current_scene,
		global_position + Vector2(0.0, -7.0),
		direction,
		52.0,
		palette["core"],
		palette["glow"]
	)

func _try_contact_hit() -> void:
	if _target == null or not is_instance_valid(_target):
		return
	var charging_now := charger and _charge_time > 0.0
	if charging_now:
		if _charge_has_hit:
			return
	elif _attack_time > 0.0:
		return
	if global_position.distance_to(_target.global_position) > melee_range + 5.0:
		return
	var push := (_target.global_position - global_position).normalized()
	_target.take_projectile_hit(push)
	if charging_now:
		_charge_has_hit = true
	else:
		_attack_time = attack_cooldown
	_spawn_melee_pixel(push)

func _spawn_melee_pixel(direction: Vector2) -> void:
	var palette := _attack_palette()
	var heavy := enemy_type == "bug_4" or enemy_type == "beetle_1"
	EnemyAttackVfx.spawn_slash(
		get_tree().current_scene,
		global_position + Vector2(0.0, -10.0),
		direction,
		palette["core"],
		palette["glow"],
		heavy
	)

func _begin_ranged_telegraph(direction: Vector2) -> void:
	if _telegraphing or _dead:
		return
	_telegraphing = true
	_attack_time = attack_cooldown
	_update_facing(direction)
	_spawn_ranged_telegraph(direction)
	await get_tree().create_timer(0.22, false).timeout
	if _dead or not is_inside_tree():
		return
	if _target == null or not is_instance_valid(_target) or not _target.is_inside_tree():
		_telegraphing = false
		return
	if not _target.is_in_group("player_mecha"):
		_telegraphing = false
		return
	_telegraphing = false
	_fire_projectile(direction)

func _spawn_ranged_telegraph(direction: Vector2) -> void:
	var origin := global_position + Vector2(0.0, -12.0)
	EnemyAttackVfx.spawn_muzzle(
		get_tree().current_scene,
		origin,
		direction,
		projectile_color,
		projectile_glow,
		_projectile_profile(),
		enemy_type == "spider_3"
	)
	EnemyAttackVfx.spawn_path(
		get_tree().current_scene,
		origin,
		origin + direction * 28.0,
		projectile_color,
		projectile_glow,
		_projectile_profile(),
		5
	)

func _begin_shock_telegraph() -> void:
	if _telegraphing or _dead:
		return
	_telegraphing = true
	_attack_time = attack_cooldown * 1.45
	velocity = Vector2.ZERO
	_spawn_shock_warning_ring()
	await get_tree().create_timer(0.34, false).timeout
	if _dead or not is_inside_tree():
		return
	if _target == null or not is_instance_valid(_target) or not _target.is_inside_tree():
		_telegraphing = false
		return
	if not _target.is_in_group("player_mecha"):
		_telegraphing = false
		return
	_telegraphing = false
	_fire_shock_pulse()

func _spawn_shock_warning_ring() -> void:
	EnemyAttackVfx.spawn_shock_warning(
		get_tree().current_scene,
		global_position + Vector2(0.0, -8.0),
		54.0,
		Color(0.78, 2.95, 3.35, 1.0),
		Color(0.18, 1.05, 1.85, 1.0),
		0.34
	)

func _fire_projectile(direction: Vector2) -> void:
	if _target == null or not is_instance_valid(_target) or not _target.is_inside_tree():
		return
	if not _target.is_in_group("player_mecha"):
		return
	var projectile := EnemyProjectileScript.new() as SpacehaulEnemyProjectile
	get_tree().current_scene.add_child(projectile)
	var muzzle := global_position + Vector2(0.0, -12.0) + direction * 9.0
	projectile.setup(muzzle, direction, get_rid(), projectile_color, projectile_glow, projectile_speed, _projectile_profile(), enemy_type == "spider_3")
	EnemyAttackVfx.spawn_muzzle(get_tree().current_scene, muzzle, direction, projectile_color, projectile_glow, _projectile_profile(), enemy_type == "spider_3")
	_attack_time = attack_cooldown
	SFX.play(self, "enemy_shot", -18.0, _rng.randf_range(0.90, 1.10))

	# Spider sentinels fire a slightly offset second pixel after a short delay.
	if enemy_type == "spider_3":
		var delayed_direction := direction.rotated(_rng.randf_range(-0.08, 0.08))
		_fire_delayed_second_shot(delayed_direction)

func _fire_delayed_second_shot(direction: Vector2) -> void:
	await get_tree().create_timer(0.13, false).timeout
	if _dead or not is_inside_tree():
		return
	if _target == null or not is_instance_valid(_target) or not _target.is_inside_tree():
		return
	if not _target.is_in_group("player_mecha"):
		return
	var projectile := EnemyProjectileScript.new() as SpacehaulEnemyProjectile
	get_tree().current_scene.add_child(projectile)
	var muzzle := global_position + Vector2(0.0, -12.0) + direction * 9.0
	projectile.setup(muzzle, direction, get_rid(), projectile_color, projectile_glow, projectile_speed * 0.92, _projectile_profile(), true)
	EnemyAttackVfx.spawn_muzzle(get_tree().current_scene, muzzle, direction, projectile_color, projectile_glow, _projectile_profile(), true)
	SFX.play(self, "enemy_shot", -20.0, _rng.randf_range(0.95, 1.08))

func _fire_shock_pulse() -> void:
	_attack_time = attack_cooldown * 1.45
	velocity = Vector2.ZERO
	SFX.play(self, "enemy_shot", -16.5, _rng.randf_range(0.72, 0.82))
	var center := global_position + Vector2(0.0, -8.0)
	EnemyAttackVfx.spawn_shock_pulse(
		get_tree().current_scene,
		center,
		54.0,
		Color(0.88, 3.1, 3.45, 1.0),
		Color(0.20, 1.10, 1.95, 1.0)
	)
	if _target != null and is_instance_valid(_target) and _target.is_inside_tree():
		if _target.is_in_group("player_mecha") and global_position.distance_to(_target.global_position) <= 58.0:
			_target.take_projectile_hit((_target.global_position - global_position).normalized())

func _attack_palette() -> Dictionary:
	match enemy_type:
		"alien_1":
			return {"core": Color(1.55, 3.0, 0.72, 1.0), "glow": Color(0.30, 1.25, 0.24, 1.0)}
		"beetle_1":
			return {"core": Color(3.0, 0.82, 0.38, 1.0), "glow": Color(1.45, 0.22, 0.08, 1.0)}
		"beetle_2":
			return {"core": projectile_color, "glow": projectile_glow}
		"bug_1":
			return {"core": Color(2.1, 3.0, 0.72, 1.0), "glow": Color(0.55, 1.25, 0.18, 1.0)}
		"bug_2":
			return {"core": Color(3.0, 0.72, 0.42, 1.0), "glow": Color(1.35, 0.18, 0.08, 1.0)}
		"bug_3":
			return {"core": Color(0.88, 3.1, 3.45, 1.0), "glow": Color(0.20, 1.10, 1.95, 1.0)}
		"bug_4":
			return {"core": Color(3.15, 1.05, 0.42, 1.0), "glow": Color(1.55, 0.28, 0.08, 1.0)}
		"spider_1":
			return {"core": Color(1.25, 3.0, 1.02, 1.0), "glow": Color(0.22, 1.22, 0.40, 1.0)}
		"spider_2", "spider_3":
			return {"core": projectile_color, "glow": projectile_glow}
		_:
			return {"core": Color(2.8, 0.72, 0.38, 1.0), "glow": Color(1.2, 0.22, 0.08, 1.0)}

func _projectile_profile() -> String:
	match enemy_type:
		"beetle_2":
			return "bio"
		"spider_2":
			return "venom"
		"spider_3":
			return "ember"
		_:
			return "bio"

func take_projectile_hit(direction: Vector2) -> void:
	if _dead:
		return
	health -= 1
	_health_bar_time = 1.15
	_hurt_time = 0.16
	velocity = direction.normalized() * 72.0
	animated_sprite.modulate = Color(3.0, 0.72, 0.52, 1.0)
	animated_sprite.position = _base_sprite_position + Vector2(float(-1 if direction.x > 0.0 else 1), 0.0)
	queue_redraw()
	if health <= 0:
		_die()
	else:
		SFX.play(self, "enemy_hit", -24.0, _rng.randf_range(0.92, 1.10))

func take_hurt() -> void:
	take_projectile_hit(Vector2.ZERO)

func _die() -> void:
	if _dead:
		return
	_dead = true
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)
	animated_sprite.speed_scale = 0.0
	animated_sprite.position = _base_sprite_position
	animated_sprite.modulate = Color.WHITE
	_spawn_salvage()
	SFX.play(get_tree().current_scene, "enemy_die", -22.0, _rng.randf_range(0.90, 1.08))
	defeated.emit(salvage_value, elite, global_position)
	_start_pixel_dissolve()

func _start_pixel_dissolve() -> void:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode unshaded;
uniform float dissolve_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 edge_color : source_color = vec4(1.0, 0.42, 0.16, 1.0);

float pixel_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (tex.a < 0.01) {
		discard;
	}
	vec2 tex_size = vec2(textureSize(TEXTURE, 0));
	vec2 pixel = floor(UV * tex_size);
	float noise = pixel_hash(pixel);
	if (noise < dissolve_amount) {
		discard;
	}
	float edge = step(dissolve_amount, noise) * (1.0 - step(dissolve_amount + 0.075, noise));
	tex.rgb += edge_color.rgb * edge * 1.8;
	COLOR = tex * COLOR;
}
"""
	_dissolve_material = ShaderMaterial.new()
	_dissolve_material.shader = shader
	_dissolve_material.set_shader_parameter("dissolve_amount", 0.0)
	animated_sprite.material = _dissolve_material

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.tween_method(_set_dissolve_amount, 0.0, 1.0, 0.72)
	tween.parallel().tween_method(_emit_dissolve_pixels, 0.0, 1.0, 0.72)
	tween.tween_callback(queue_free)

func _set_dissolve_amount(value: float) -> void:
	if _dissolve_material != null:
		_dissolve_material.set_shader_parameter("dissolve_amount", value)

func _emit_dissolve_pixels(progress: float) -> void:
	# Emit only on a subset of tween callbacks so dense enemy groups stay cheap.
	if _rng.randf() > 0.16:
		return
	var pixel := Polygon2D.new()
	var half_pixel := 0.5
	pixel.polygon = PackedVector2Array([
		Vector2(-half_pixel, -half_pixel), Vector2(half_pixel, -half_pixel), Vector2(half_pixel, half_pixel), Vector2(-half_pixel, half_pixel)
	])
	pixel.color = _death_pixel_color()
	pixel.z_as_relative = false
	pixel.z_index = 1900
	get_tree().current_scene.add_child(pixel)
	pixel.global_position = (global_position + Vector2(_rng.randf_range(-11.0, 11.0), _rng.randf_range(-26.0, -2.0))).round()
	var target_pos := pixel.global_position + Vector2(_rng.randf_range(-12.0, 12.0), _rng.randf_range(-18.0, 8.0)) * (0.6 + progress * 0.7)
	var tw := pixel.create_tween()
	tw.set_parallel(true)
	tw.tween_property(pixel, "global_position", target_pos.round(), 0.28)
	tw.tween_property(pixel, "modulate:a", 0.0, 0.28)
	tw.chain().tween_callback(pixel.queue_free)

func _death_pixel_color() -> Color:
	match enemy_type:
		"beetle_1", "bug_2": return Color(2.5, 0.42, 0.28, 1.0)
		"beetle_2", "spider_1", "spider_2": return Color(0.65, 2.8, 0.55, 1.0)
		"bug_3": return Color(0.35, 2.1, 2.9, 1.0)
		"spider_3": return Color(2.0, 0.28, 0.35, 1.0)
		_: return Color(1.4, 2.5, 0.65, 1.0)

func _configure_archetype() -> void:
	match enemy_type:
		"alien_1":
			health = 3
			move_speed = 66.0
			aggro_range = 300.0
			melee_range = 19.0
			attack_cooldown = 0.72
		"beetle_1":
			health = 5
			move_speed = 46.0
			aggro_range = 300.0
			melee_range = 21.0
			attack_cooldown = 1.05
			charger = true
		"beetle_2":
			health = 3
			move_speed = 48.0
			aggro_range = 330.0
			preferred_range = 112.0
			attack_cooldown = 1.35
			ranged = true
			projectile_speed = 168.0
			projectile_color = Color(0.8, 2.9, 0.65, 1.0)
			projectile_glow = Color(0.2, 1.2, 0.35, 1.0)
		"bug_1":
			health = 2
			move_speed = 82.0
			aggro_range = 245.0
			melee_range = 17.0
			attack_cooldown = 0.62
		"bug_2":
			health = 2
			move_speed = 88.0
			aggro_range = 285.0
			melee_range = 17.0
			attack_cooldown = 0.58
		"bug_3":
			health = 3
			move_speed = 60.0
			aggro_range = 280.0
			attack_cooldown = 1.20
			shocker = true
		"bug_4":
			health = 6
			move_speed = 38.0
			aggro_range = 250.0
			melee_range = 22.0
			attack_cooldown = 0.95
		"spider_1":
			health = 2
			move_speed = 94.0
			aggro_range = 270.0
			melee_range = 16.0
			attack_cooldown = 0.55
		"spider_2":
			health = 3
			move_speed = 55.0
			aggro_range = 340.0
			preferred_range = 126.0
			attack_cooldown = 1.08
			ranged = true
			projectile_speed = 205.0
			projectile_color = Color(1.55, 2.8, 0.75, 1.0)
			projectile_glow = Color(0.45, 1.15, 0.35, 1.0)
		"spider_3":
			health = 4
			move_speed = 44.0
			aggro_range = 360.0
			preferred_range = 142.0
			attack_cooldown = 1.42
			ranged = true
			projectile_speed = 220.0
			projectile_color = Color(2.4, 0.52, 0.42, 1.0)
			projectile_glow = Color(1.2, 0.18, 0.12, 1.0)


func _spawn_salvage() -> void:
	var pickup := SalvagePickupScript.new() as SpacehaulSalvagePickup
	if pickup == null:
		return
	var parent_node := get_parent()
	if parent_node == null:
		parent_node = get_tree().current_scene
	parent_node.add_child(pickup)
	pickup.setup(global_position + Vector2(0.0, -6.0), salvage_value)

func make_omega_carrier(health_multiplier: float = 1.35) -> void:
	if omega_carrier:
		return
	omega_carrier = true
	elite = true
	add_to_group("omega_carriers")
	health = maxi(health + 4, int(ceil(float(health) * maxf(1.0, health_multiplier))))
	max_health = health
	move_speed *= 1.04
	salvage_value += 2
	animated_sprite.scale = Vector2.ONE * 1.32
	_base_modulate = Color(1.22, 0.72, 1.38, 1.0)
	animated_sprite.modulate = _base_modulate
	_build_omega_carrier_vfx()
	queue_redraw()

func is_omega_carrier() -> bool:
	return omega_carrier

func _build_omega_carrier_vfx() -> void:
	if _omega_label != null:
		return

	# Carrier should look special, but should NOT resemble the dropped Omega Core.
	# The actual Core beacon/beam only appears after this enemy dies.

	_omega_label = Label.new()
	_omega_label.text = "OMEGA CARRIER"
	_omega_label.position = Vector2(-44.0, -58.0)
	_omega_label.size = Vector2(88.0, 16.0)
	_omega_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_omega_label.add_theme_font_override(
		"font",
		load("res://Fonts/mago1.ttf") as Font
	)
	_omega_label.add_theme_font_size_override("font_size", 10)
	_omega_label.add_theme_color_override(
		"font_color",
		Color(1.0, 0.52, 1.0, 1.0)
	)
	
func _make_omega_ring(width: float, color: Color, radius: float) -> Line2D:
	var line := Line2D.new()
	line.width = width
	line.default_color = color
	line.antialiased = false
	line.points = PackedVector2Array([
		Vector2(0.0, -radius * 0.42),
		Vector2(radius, 0.0),
		Vector2(0.0, radius * 0.42),
		Vector2(-radius, 0.0),
		Vector2(0.0, -radius * 0.42),
	])
	return line

func _update_omega_carrier_vfx(delta: float) -> void:
	_omega_fx_time += delta
	var pulse := 0.72 + sin(_omega_fx_time * 7.5) * 0.20
	if _omega_beam != null:
		_omega_beam.modulate.a = 0.72 + pulse * 0.25
		_omega_beam.set_point_position(1, Vector2(0.0, -72.0 + sin(_omega_fx_time * 5.0) * 3.0))
	if _omega_beam_glow != null:
		_omega_beam_glow.modulate.a = 0.70 + pulse * 0.22
	if _omega_ring != null:
		_omega_ring.modulate.a = 0.72 + pulse * 0.26
	if _omega_ring_glow != null:
		_omega_ring_glow.modulate.a = 0.62 + pulse * 0.24
	for i in range(_omega_orbit_lines.size()):
		var line := _omega_orbit_lines[i]
		var angle := _omega_fx_time * (1.9 + float(i) * 0.16) + TAU * float(i) / 3.0
		var radius := 12.0 + float(i) * 2.5
		var a := Vector2(cos(angle), sin(angle) * 0.44) * radius + Vector2(0.0, -12.0)
		var b := Vector2(cos(angle + 0.72), sin(angle + 0.72) * 0.44) * (radius + 3.0) + Vector2(0.0, -12.0)
		line.set_point_position(0, a.round())
		line.set_point_position(1, b.round())

	if fmod(_omega_fx_time, 0.85) < delta:
		var root := get_tree().current_scene
		if root != null:
			var emitter := ParticleScript.new() as SpacehaulAbilityParticles
			root.add_child(emitter)
			emitter.setup_burst(global_position + Vector2(0.0, -10.0), Color(3.2, 1.0, 3.8, 1.0), Color(1.1, 0.16, 1.7, 0.9), "phase", 5, 15.0, 0.28)

func apply_difficulty(run_time: float, deck_number: int, make_elite: bool = false) -> void:
	var phase := maxi(0, int(floor(run_time / 180.0)))
	health += mini(5, phase)
	move_speed *= minf(1.34, 1.0 + run_time / 2400.0 + float(maxi(0, deck_number - 1)) * 0.025)
	attack_cooldown *= maxf(0.62, 1.0 - run_time / 3200.0)

	match enemy_type:
		"alien_1", "bug_1", "bug_2", "spider_1": salvage_value = 1
		"beetle_2", "bug_3", "spider_2": salvage_value = 2
		"beetle_1", "bug_4", "spider_3": salvage_value = 3
		_: salvage_value = 1

	if make_elite:
		elite = true
		health = maxi(health + 3, int(ceil(float(health) * 1.8)))
		move_speed *= 1.08
		attack_cooldown *= 0.88
		salvage_value += 4
		animated_sprite.scale = Vector2.ONE * 1.22
		_base_modulate = Color(1.25, 1.0, 0.72, 1.0)
		animated_sprite.modulate = _base_modulate
	max_health = health
	queue_redraw()

func _draw() -> void:
	if _dead or max_health <= 0:
		return
	if not elite and _health_bar_time <= 0.0:
		return
	var ratio := clampf(float(health) / float(max_health), 0.0, 1.0)
	var width := 18.0 if not elite else (28.0 if omega_carrier else 24.0)
	var y := -31.0 if not elite else (-37.0 if omega_carrier else -34.0)
	draw_rect(Rect2(Vector2(-width * 0.5 - 1.0, y - 1.0), Vector2(width + 2.0, 4.0)), Color(0.02, 0.025, 0.035, 0.9), true)
	draw_rect(Rect2(Vector2(-width * 0.5, y), Vector2(width, 2.0)), Color(0.22, 0.08, 0.06, 0.95), true)
	var bar_color := Color(3.0, 0.62, 3.5, 1.0) if omega_carrier else (Color(1.0, 0.78, 0.28, 1.0) if elite else Color(0.95, 0.30, 0.20, 1.0))
	draw_rect(Rect2(Vector2(-width * 0.5, y), Vector2(maxf(1.0, width * ratio), 2.0)), bar_color, true)

func _build_animation() -> void:
	var texture_path := String(ENEMY_SHEETS.get(enemy_type, ENEMY_SHEETS["bug_1"]))
	var texture := load(texture_path) as Texture2D
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	frames.add_animation("move")
	frames.set_animation_loop("move", true)
	frames.set_animation_speed("move", 9.0 + _rng.randf_range(-1.0, 1.5))
	if texture != null:
		for frame_index in range(FRAME_COUNT):
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(float(frame_index) * FRAME_SIZE.x, 0.0, FRAME_SIZE.x, FRAME_SIZE.y)
			frames.add_frame("move", atlas)
	animated_sprite.sprite_frames = frames

func _update_facing(direction: Vector2) -> void:
	if absf(direction.x) <= 0.05:
		return

	# Enemy artwork faces LEFT by default.
	# Moving left  = original artwork.
	# Moving right = horizontally flipped.
	animated_sprite.flip_h = direction.x > 0.0

func _update_depth_order() -> void:
	z_as_relative = false
	z_index = clampi(int(round(global_position.y + 1.0)), -3000, 3000)
