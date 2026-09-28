extends CharacterBody2D
class_name MechaController

const InputSetupScript = preload("res://Scripts/input_setup.gd")
const ProjectileScript = preload("res://Scripts/projectile.gd")

const GAMEPAD_AIM_DEADZONE := 0.28
const PROJECTILE_SPAWN_OFFSET := 10.0

@export var mecha_id := "M1"
@export var player_walk_speed := 92.0
@export var player_run_speed := 138.0
@export var ai_move_speed := 54.0
@export var acceleration := 720.0
@export var deceleration := 920.0
@export var ai_patrol_radius := 52.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var camera: Camera2D = $Camera2D
@onready var marker: Node2D = $ControlMarker

var is_player_controlled := false
var home_position := Vector2.ZERO
var last_move_direction := Vector2.RIGHT
var facing := 1
var attacking := false
var hurt_lock := 0.0

var _ai_state := "idle"
var _ai_timer := 0.0
var _ai_target := Vector2.ZERO
var _rng := RandomNumberGenerator.new()
var _attack_fire_frame := 0
var _attack_projectile_pending := false
var _attack_direction := Vector2.RIGHT

func _ready() -> void:
	InputSetupScript.ensure_actions()
	_rng.seed = mecha_id.hash() ^ int(Time.get_ticks_usec()) ^ int(get_instance_id())
	_build_sprite_frames()
	animated_sprite.animation_finished.connect(_on_animation_finished)
	animated_sprite.frame_changed.connect(_on_frame_changed)
	animated_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	home_position = global_position
	_ai_target = home_position
	_set_ai_idle()
	set_player_controlled(is_player_controlled)
	_update_depth_order()

func _physics_process(delta: float) -> void:
	_update_depth_order()
	if hurt_lock > 0.0:
		hurt_lock = maxf(0.0, hurt_lock - delta)
		if hurt_lock <= 0.0:
			animated_sprite.modulate = Color.WHITE

	if is_player_controlled:
		_process_player(delta)
	else:
		_process_ai(delta)

func set_player_controlled(value: bool) -> void:
	is_player_controlled = value
	if not is_node_ready():
		return
	camera.enabled = value
	marker.visible = value
	if value:
		attacking = false
		_attack_projectile_pending = false
		velocity = Vector2.ZERO
		_play_if_needed("idle")
	else:
		home_position = global_position
		_set_ai_idle()

func set_ai_home(value: Vector2) -> void:
	home_position = value
	_ai_target = value

func teleport_to(value: Vector2) -> void:
	global_position = value
	home_position = value
	_ai_target = value
	velocity = Vector2.ZERO
	attacking = false
	_attack_projectile_pending = false
	_set_ai_idle()

func get_animation_name() -> String:
	return String(animated_sprite.animation)

func get_speed() -> float:
	return velocity.length()

func get_display_name() -> String:
	return mecha_id

func take_hurt() -> void:
	if hurt_lock > 0.0:
		return
	hurt_lock = 0.38
	animated_sprite.modulate = Color(1.0, 0.52, 0.42, 1.0)
	velocity *= 0.25

func take_projectile_hit(direction: Vector2) -> void:
	take_hurt()
	velocity += direction.normalized() * 45.0

func _process_player(delta: float) -> void:
	var move_input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var attack_direction := _get_attack_direction()

	if Input.is_action_just_pressed("shoot") and not attacking:
		_start_attack(attack_direction, true)

	if attacking:
		velocity = velocity.move_toward(Vector2.ZERO, deceleration * delta)
	else:
		var speed := player_run_speed if Input.is_action_pressed("run") else player_walk_speed
		var target_velocity := move_input * speed
		var rate := acceleration if move_input.length_squared() > 0.01 else deceleration
		velocity = velocity.move_toward(target_velocity, rate * delta)

		if move_input.length_squared() > 0.02:
			last_move_direction = move_input.normalized()
			_update_facing(last_move_direction)
			_play_if_needed("move")
		else:
			_update_facing(last_move_direction)
			_play_if_needed("idle")

	move_and_slide()

func _process_ai(delta: float) -> void:
	if attacking:
		velocity = velocity.move_toward(Vector2.ZERO, deceleration * delta)
		move_and_slide()
		return

	_ai_timer -= delta
	if _ai_state == "idle":
		velocity = velocity.move_toward(Vector2.ZERO, deceleration * delta)
		_play_if_needed("idle")
		if _ai_timer <= 0.0:
			_begin_ai_patrol()
	elif _ai_state == "move":
		var to_target := _ai_target - global_position
		if to_target.length() <= 5.0 or _ai_timer <= 0.0:
			_set_ai_idle()
		else:
			var direction := to_target.normalized()
			last_move_direction = direction
			_update_facing(direction)
			velocity = velocity.move_toward(direction * ai_move_speed, acceleration * delta)
			_play_if_needed("move")

	move_and_slide()
	if get_slide_collision_count() > 0 and _ai_state == "move":
		_set_ai_idle()

func _set_ai_idle() -> void:
	_ai_state = "idle"
	_ai_timer = _rng.randf_range(0.8, 2.5)
	velocity = Vector2.ZERO
	if is_node_ready():
		_play_if_needed("idle")

func _begin_ai_patrol() -> void:
	_ai_state = "move"
	_ai_timer = _rng.randf_range(0.8, 1.8)
	var angle := _rng.randf_range(0.0, TAU)
	var radius := _rng.randf_range(18.0, ai_patrol_radius)
	_ai_target = home_position + Vector2(cos(angle), sin(angle)) * radius

func _start_attack(direction: Vector2, launch_projectile: bool) -> void:
	if attacking:
		return
	if direction.length_squared() <= 0.001:
		direction = last_move_direction
	if direction.length_squared() <= 0.001:
		direction = Vector2.RIGHT
	_attack_direction = direction.normalized()
	_update_facing(_attack_direction)
	attacking = true
	_attack_projectile_pending = launch_projectile
	_attack_fire_frame = maxi(0, int(animated_sprite.sprite_frames.get_frame_count("attack") / 2) - 1)
	animated_sprite.play("attack")

func _on_frame_changed() -> void:
	if not attacking or not _attack_projectile_pending:
		return
	if animated_sprite.animation != &"attack":
		return
	if animated_sprite.frame >= _attack_fire_frame:
		_attack_projectile_pending = false
		_fire_projectile(_attack_direction)

func _on_animation_finished() -> void:
	if animated_sprite.animation == &"attack":
		attacking = false
		_attack_projectile_pending = false
		if is_player_controlled:
			animated_sprite.play("idle")
		else:
			_set_ai_idle()

func _fire_projectile(direction: Vector2) -> void:
	var projectile := ProjectileScript.new() as SpacehaulProjectile
	var root := get_tree().current_scene
	if root == null:
		root = get_parent()
	root.add_child(projectile)
	var muzzle_origin := global_position + Vector2(0.0, -18.0) + direction * PROJECTILE_SPAWN_OFFSET
	projectile.setup(muzzle_origin, direction, get_rid())

func _get_attack_direction() -> Vector2:
	var joy_id := _first_connected_joypad()
	if joy_id >= 0:
		var stick := Vector2(
			Input.get_joy_axis(joy_id, JOY_AXIS_RIGHT_X),
			Input.get_joy_axis(joy_id, JOY_AXIS_RIGHT_Y)
		)
		if stick.length() >= GAMEPAD_AIM_DEADZONE:
			return stick.normalized()

	var mouse_delta := get_global_mouse_position() - (global_position + Vector2(0.0, -18.0))
	if mouse_delta.length_squared() > 4.0:
		return mouse_delta.normalized()
	return last_move_direction

func _first_connected_joypad() -> int:
	var joypads := Input.get_connected_joypads()
	if joypads.is_empty():
		return -1
	return int(joypads[0])

func _update_facing(direction: Vector2) -> void:
	if absf(direction.x) <= 0.08:
		return
	facing = 1 if direction.x > 0.0 else -1
	animated_sprite.flip_h = facing > 0

func _play_if_needed(animation_name: StringName) -> void:
	if attacking:
		return
	if animated_sprite.animation != animation_name or not animated_sprite.is_playing():
		animated_sprite.play(animation_name)

func _build_sprite_frames() -> void:
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")

	_add_animation(frames, "idle", _find_animation_textures("idle"), 6.0, true)
	_add_animation(frames, "move", _find_animation_textures("move"), 9.0, true)
	_add_animation(frames, "attack", _find_animation_textures("attack"), 12.0, false)
	animated_sprite.sprite_frames = frames
	animated_sprite.play("idle")

func _add_animation(frames: SpriteFrames, animation_name: String, textures: Array[Texture2D], fps: float, looped: bool) -> void:
	frames.add_animation(animation_name)
	frames.set_animation_speed(animation_name, fps)
	frames.set_animation_loop(animation_name, looped)
	for texture in textures:
		frames.add_frame(animation_name, texture)

	if textures.is_empty():
		push_error("No %s frames found for mecha %s" % [animation_name, mecha_id])

func _find_animation_textures(animation_name: String) -> Array[Texture2D]:
	var textures: Array[Texture2D] = []
	var lower_id := mecha_id.to_lower()
	var stems: Array[String] = []
	if animation_name == "attack":
		stems = ["atk"]
	elif animation_name == "move":
		stems = ["move", "walk"]
	else:
		stems = ["idle"]

	for stem in stems:
		textures.clear()
		for index in range(1, 25):
			var path := "res://Sprites/Mechas/%s/%s%s_%d.png" % [mecha_id, lower_id, stem, index]
			if not ResourceLoader.exists(path):
				break
			var texture := load(path) as Texture2D
			if texture != null:
				textures.append(texture)
		if not textures.is_empty():
			break
	return textures

func _update_depth_order() -> void:
	z_as_relative = false
	z_index = clampi(int(round(global_position.y + 2.0)), -3000, 3000)
