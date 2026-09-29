extends CharacterBody2D
class_name MechaController

signal hull_changed(current_hull: int, max_hull: int)
signal destroyed(mecha)

const InputSetupScript = preload("res://Scripts/input_setup.gd")
const SpecialAbilityScript = preload("res://Scripts/special_ability_effect.gd")
const SFX = preload("res://Scripts/sound_fx.gd")

const GAMEPAD_AIM_DEADZONE := 0.28


const MAX_ABILITY_TIER := 3
const ABILITY_NAMES := {
	"M1": {"primary": "PLASMA CLEAVER", "secondary": "REPULSOR BURST"},
	"M2": {"primary": "VECTOR HARPOONS", "secondary": "ANCHOR BLOOM"},
	"M3": {"primary": "COMET MORTAR", "secondary": "ORBITAL RAIN"},
	"R1": {"primary": "PRISM LANCE", "secondary": "HALO SWEEP"},
	"R2": {"primary": "BREACH CANNON", "secondary": "COUNTERSHOCK"},
	"R3": {"primary": "HUNTER MISSILES", "secondary": "MISSILE HALO"},
	"R4": {"primary": "ARC CASCADE", "secondary": "EMP CROWN"},
	"S1": {"primary": "PHOTON RAKE", "secondary": "SOLAR FLARE"},
	"S2": {"primary": "GRAVITY WELL", "secondary": "MASS EJECTION"},
	"S3": {"primary": "PHASE NEEDLES", "secondary": "PHASE BLOOM"},
}
const PRIMARY_UPGRADE_LABELS := {
	"M1": ["WIDER EDGE   ARC +2 TEETH", "TWIN EDGE   SECOND CLEAVE", "RETURN CUT   THIRD BACKSWING"],
	"M2": ["HARPOON ARRAY II   5 TETHERS", "HARPOON ARRAY III   7 TETHERS", "LONG HAUL   RANGE + IMPACT"],
	"M3": ["MORTAR SHARDING   +2 SHRAPNEL", "MORTAR SHARDING II   +4 SHRAPNEL", "DOUBLE TAP   CORE REDETONATES"],
	"R1": ["PRISM IV   +1 LANCE", "PRISM V   +2 LANCES", "REFRACTION   CROSS BURSTS"],
	"R2": ["BREACH II   +2 SPLINTERS", "BREACH III   IMPACT + RANGE", "BREACH CORE   +2 SPLINTERS"],
	"R3": ["HUNTER IV   +1 MISSILE", "HUNTER V   +2 MISSILES", "HUNTER VI   +3 MISSILES + RANGE"],
	"R4": ["CASCADE II   +2 CHAIN HOPS", "CASCADE III   +4 CHAIN HOPS", "CASCADE IV   +6 HOPS + JUMP RANGE"],
	"S1": ["RAKE V   +2 BEAMS", "RAKE VII   +4 BEAMS", "RAKE IX   +6 BEAMS + RANGE"],
	"S2": ["WELL II   PULL RADIUS +12", "DEEP WELL   EXTRA COLLAPSE", "EVENT HORIZON   DOUBLE IMPLOSION"],
	"S3": ["NEEDLE VII   +2 SHARDS", "NEEDLE IX   +4 SHARDS", "PHASE FAN   +6 SHARDS + SPREAD"],
}
const SECONDARY_UPGRADE_LABELS := {
	"M1": ["REPULSOR II   +4 SPOKES + RANGE", "DOUBLE PULSE   SECOND RING", "OVERSHOCK   THIRD RING"],
	"M2": ["ANCHOR II   PULL RADIUS +14", "DOUBLE COLLAPSE   EXTRA STEP", "ANCHOR NOVA   OVERSIZED RELEASE"],
	"M3": ["RAIN II   +4 ORBITAL STRIKES", "RAIN III   +8 ORBITAL STRIKES", "SATURATION   +12 STRIKES + RANGE"],
	"R1": ["HALO II   +4 SPOKES", "DOUBLE SWEEP   SECOND PHASE", "HALO III   RANGE + SPOKES"],
	"R2": ["COUNTER II   +2 BLASTS", "COUNTER III   +4 BLASTS", "COUNTER CORE   +6 BLASTS + RANGE"],
	"R3": ["HALO II   +2 MISSILES", "HALO III   +4 MISSILES", "HALO IV   +6 MISSILES + RANGE"],
	"R4": ["CROWN III   +1 EMP WAVE", "CROWN IV   +2 EMP WAVES", "CROWN V   +3 WAVES + DENSITY"],
	"S1": ["FLARE XII   +4 RADIAL BEAMS", "FLARE XVI   +8 RADIAL BEAMS", "SOLAR MAX   +12 BEAMS + RANGE"],
	"S2": ["EJECTION II   FIELD +14", "EJECTION III   IMPACT + FIELD", "MASS BREAK   MAXIMUM FIELD"],
	"S3": ["BLOOM II   SECOND PHASE WAVE", "BLOOM III   THIRD PHASE WAVE", "BLOOM IV   FOUR WAVES + DENSITY"],
}

@export var mecha_id := "M1"
@export var player_walk_speed := 92.0
@export var player_run_speed := 138.0
@export var acceleration := 720.0
@export var deceleration := 920.0
@export var max_hull := 100
@export var attack_move_multiplier := 0.78
@export var boost_speed := 250.0
@export var boost_duration := 0.20
@export var boost_cooldown := 1.35

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var camera: Camera2D = $Camera2D
@onready var marker: Node2D = $ControlMarker
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var is_player_controlled := false
var last_move_direction := Vector2.RIGHT
var facing := 1
var attacking := false
var hull := 100
var impact_scale := 1.0
var secondary_unlocked := false
var primary_ability_tier := 0
var secondary_ability_tier := 0

var _rng := RandomNumberGenerator.new()
var _attack_fire_frame := 0
var _attack_projectile_pending := false
var _attack_direction := Vector2.RIGHT
var _attack_target := Vector2.ZERO
var _attack_alternate := false
var _primary_cooldown := 0.75
var _secondary_cooldown := 5.0
var _primary_cooldown_left := 0.0
var _secondary_cooldown_left := 0.0
var _hurt_time := 0.0
var _dead := false
var _dissolve_material: ShaderMaterial
var _combat_material: ShaderMaterial
var _deck_transition_material: ShaderMaterial
var _deck_transition_locked := false
var _boost_time := 0.0
var _boost_cooldown_left := 0.0
var _boost_direction := Vector2.RIGHT
var _boost_trail_time := 0.0
var _camera_shake_time := 0.0
var _camera_shake_strength := 0.0

func _ready() -> void:
	add_to_group("mechas")
	InputSetupScript.ensure_actions()
	_rng.seed = mecha_id.hash() ^ int(Time.get_ticks_usec()) ^ int(get_instance_id())
	_configure_survival_stats()
	hull = max_hull
	_build_sprite_frames()
	_build_combat_shader()
	_build_deck_transition_shader()
	animated_sprite.animation_finished.connect(_on_animation_finished)
	animated_sprite.frame_changed.connect(_on_frame_changed)
	animated_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_player_controlled(is_player_controlled)
	_update_depth_order()
	hull_changed.emit(hull, max_hull)

func _physics_process(delta: float) -> void:
	_update_depth_order()
	if _dead:
		return
	if _deck_transition_locked:
		velocity = Vector2.ZERO
		return

	_primary_cooldown_left = maxf(0.0, _primary_cooldown_left - delta)
	_secondary_cooldown_left = maxf(0.0, _secondary_cooldown_left - delta)
	_boost_cooldown_left = maxf(0.0, _boost_cooldown_left - delta)
	_update_camera_shake(delta)

	if _hurt_time > 0.0:
		_hurt_time = maxf(0.0, _hurt_time - delta)
		if _combat_material != null:
			_combat_material.set_shader_parameter("hit_flash", clampf(_hurt_time / 0.56, 0.0, 1.0))
	elif _combat_material != null:
		_combat_material.set_shader_parameter("hit_flash", 0.0)

	if _boost_time > 0.0:
		_boost_time = maxf(0.0, _boost_time - delta)
		_boost_trail_time -= delta
		if _boost_trail_time <= 0.0:
			_boost_trail_time = 0.035
			_spawn_boost_afterimage()
		if _combat_material != null:
			_combat_material.set_shader_parameter("boost_strength", clampf(_boost_time / maxf(0.001, boost_duration), 0.0, 1.0))
	elif _combat_material != null:
		_combat_material.set_shader_parameter("boost_strength", 0.0)

	if is_player_controlled:
		_process_player(delta)

func set_player_controlled(value: bool) -> void:
	is_player_controlled = value
	if not is_node_ready():
		return
	camera.enabled = value
	marker.visible = value
	if value:
		if not is_in_group("player_mecha"):
			add_to_group("player_mecha")
		attacking = false
		_attack_projectile_pending = false
		velocity = Vector2.ZERO
		_play_if_needed("idle")
	else:
		if is_in_group("player_mecha"):
			remove_from_group("player_mecha")
		velocity = Vector2.ZERO

func teleport_to(value: Vector2) -> void:
	global_position = value
	velocity = Vector2.ZERO
	attacking = false
	_attack_projectile_pending = false
	_primary_cooldown_left = minf(_primary_cooldown_left, 0.25)
	_secondary_cooldown_left = minf(_secondary_cooldown_left, 0.5)
	if not _dead:
		_play_if_needed("idle")

func begin_deck_transition() -> void:
	if _dead:
		return
	_deck_transition_locked = true
	velocity = Vector2.ZERO
	attacking = false
	_attack_projectile_pending = false
	_boost_time = 0.0
	if marker != null:
		marker.visible = false
	if _deck_transition_material != null:
		_deck_transition_material.set_shader_parameter("dissolve_amount", 0.0)
		_deck_transition_material.set_shader_parameter("phase_strength", 1.0)
		animated_sprite.material = _deck_transition_material
	animated_sprite.modulate.a = 1.0
	animated_sprite.scale = Vector2.ONE

func prepare_deck_materialize() -> void:
	if _dead:
		return
	_deck_transition_locked = true
	velocity = Vector2.ZERO
	if marker != null:
		marker.visible = false
	if _deck_transition_material != null:
		_deck_transition_material.set_shader_parameter("dissolve_amount", 1.0)
		_deck_transition_material.set_shader_parameter("phase_strength", 1.0)
		animated_sprite.material = _deck_transition_material
	animated_sprite.modulate.a = 1.0
	animated_sprite.scale = Vector2(0.92, 1.08)

func set_deck_transition_amount(value: float) -> void:
	if _deck_transition_material != null:
		_deck_transition_material.set_shader_parameter("dissolve_amount", clampf(value, 0.0, 1.0))

func set_deck_transition_scale(value: float) -> void:
	animated_sprite.scale = Vector2(lerpf(0.92, 1.0, value), lerpf(1.08, 1.0, value))

func set_transition_camera_zoom(value: float) -> void:
	if camera != null:
		camera.zoom = Vector2.ONE * maxf(0.2, value)

func end_deck_transition() -> void:
	if _dead:
		return
	_deck_transition_locked = false
	animated_sprite.modulate.a = 1.0
	animated_sprite.scale = Vector2.ONE
	if _combat_material != null:
		animated_sprite.material = _combat_material
	if marker != null:
		marker.visible = is_player_controlled
	if camera != null:
		camera.zoom = Vector2.ONE
	_play_if_needed("idle")

func get_animation_name() -> String:
	if animated_sprite == null:
		return ""
	return String(animated_sprite.animation)

func get_speed() -> float:
	return velocity.length()

func get_display_name() -> String:
	return mecha_id

func get_hull() -> int:
	return hull

func get_max_hull() -> int:
	return max_hull

func get_primary_cooldown_left() -> float:
	return _primary_cooldown_left

func get_secondary_cooldown_left() -> float:
	return _secondary_cooldown_left

func has_secondary_ability() -> bool:
	return true

func is_secondary_unlocked() -> bool:
	return secondary_unlocked and has_secondary_ability()

func set_secondary_unlocked(value: bool) -> void:
	secondary_unlocked = value


func get_primary_ability_name() -> String:
	var data: Dictionary = ABILITY_NAMES.get(mecha_id, {})
	return String(data.get("primary", "PRIMARY"))

func get_secondary_ability_name() -> String:
	var data: Dictionary = ABILITY_NAMES.get(mecha_id, {})
	return String(data.get("secondary", "SECONDARY"))

func get_primary_ability_tier() -> int:
	return primary_ability_tier

func get_secondary_ability_tier() -> int:
	return secondary_ability_tier

func can_upgrade_primary_ability() -> bool:
	return primary_ability_tier < MAX_ABILITY_TIER

func can_upgrade_secondary_ability() -> bool:
	return is_secondary_unlocked() and secondary_ability_tier < MAX_ABILITY_TIER

func upgrade_primary_ability() -> void:
	primary_ability_tier = mini(MAX_ABILITY_TIER, primary_ability_tier + 1)

func upgrade_secondary_ability() -> void:
	secondary_ability_tier = mini(MAX_ABILITY_TIER, secondary_ability_tier + 1)

func get_primary_upgrade_label() -> String:
	var labels: Array = PRIMARY_UPGRADE_LABELS.get(mecha_id, [])
	if primary_ability_tier >= labels.size():
		return ""
	return "%s   %s" % [get_primary_ability_name(), String(labels[primary_ability_tier])]

func get_secondary_upgrade_label() -> String:
	var labels: Array = SECONDARY_UPGRADE_LABELS.get(mecha_id, [])
	if secondary_ability_tier >= labels.size():
		return ""
	return "%s   %s" % [get_secondary_ability_name(), String(labels[secondary_ability_tier])]

func apply_primary_cooling(multiplier: float) -> void:
	_primary_cooldown = maxf(0.16, _primary_cooldown * multiplier)
	_primary_cooldown_left = minf(_primary_cooldown_left, _primary_cooldown)

func apply_secondary_cooling(multiplier: float) -> void:
	_secondary_cooldown = maxf(1.0, _secondary_cooldown * multiplier)
	_secondary_cooldown_left = minf(_secondary_cooldown_left, _secondary_cooldown)

func apply_impact_multiplier(multiplier: float) -> void:
	impact_scale = clampf(impact_scale * multiplier, 0.75, 3.0)

func apply_move_speed_multiplier(multiplier: float) -> void:
	player_walk_speed *= multiplier
	player_run_speed *= multiplier

func add_max_hull(amount: int, repair_amount: int = -1) -> void:
	max_hull = maxi(1, max_hull + amount)
	if repair_amount < 0:
		hull = mini(max_hull, hull + amount)
	else:
		hull = mini(max_hull, hull + repair_amount)
	hull_changed.emit(hull, max_hull)

func repair_hull(amount: int) -> void:
	if _dead:
		return
	hull = mini(max_hull, hull + maxi(0, amount))
	hull_changed.emit(hull, max_hull)

func take_hurt(amount: int = 10) -> void:
	if _dead or _hurt_time > 0.0 or _boost_time > 0.0:
		return
	_hurt_time = 0.56
	hull = maxi(0, hull - maxi(1, amount))
	if _combat_material != null:
		_combat_material.set_shader_parameter("hit_flash", 1.0)
	velocity *= 0.25
	_trigger_camera_shake(2.4, 0.16)
	SFX.play(self, "player_hurt", -5.5, _rng.randf_range(0.94, 1.06))
	hull_changed.emit(hull, max_hull)
	if hull <= 0:
		_die()

func take_projectile_hit(direction: Vector2, amount: int = 10) -> void:
	if _dead or _hurt_time > 0.0 or _boost_time > 0.0:
		return
	take_hurt(amount)
	if direction.length_squared() > 0.001 and not _dead:
		velocity += direction.normalized() * 45.0

func _process_player(delta: float) -> void:
	var move_input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var attack_direction := _get_attack_direction()

	if Input.is_action_just_pressed("dash") and _boost_cooldown_left <= 0.0:
		_start_boost(move_input, attack_direction)

	if _boost_time <= 0.0 and not attacking:
		# Primary remains hold-to-fire, but firing no longer roots the chassis.
		if Input.is_action_pressed("shoot") and _primary_cooldown_left <= 0.0:
			_attack_target = _get_attack_target(attack_direction)
			_attack_alternate = false
			_primary_cooldown_left = _primary_cooldown
			_start_attack(attack_direction, true)
		elif Input.is_action_just_pressed("secondary_ability") and is_secondary_unlocked() and _secondary_cooldown_left <= 0.0:
			_attack_target = _get_attack_target(attack_direction)
			_attack_alternate = true
			_secondary_cooldown_left = _secondary_cooldown
			_start_attack(attack_direction, true)

	if _boost_time > 0.0:
		velocity = _boost_direction * boost_speed
		_update_facing(_boost_direction)
	else:
		var speed := player_run_speed if Input.is_action_pressed("run") else player_walk_speed
		if attacking:
			speed *= attack_move_multiplier
		var target_velocity := move_input * speed
		var rate := acceleration if move_input.length_squared() > 0.01 else deceleration
		velocity = velocity.move_toward(target_velocity, rate * delta)

		if move_input.length_squared() > 0.02:
			last_move_direction = move_input.normalized()
			if not attacking:
				_update_facing(last_move_direction)
				_play_if_needed("move")
		elif not attacking:
			_update_facing(last_move_direction)
			_play_if_needed("idle")

	move_and_slide()

func _start_boost(move_input: Vector2, attack_direction: Vector2) -> void:
	if _dead or _boost_time > 0.0:
		return
	var direction := move_input.normalized()
	if direction.length_squared() <= 0.001:
		direction = last_move_direction
	if direction.length_squared() <= 0.001:
		direction = attack_direction
	if direction.length_squared() <= 0.001:
		direction = Vector2.RIGHT
	_boost_direction = direction.normalized()
	last_move_direction = _boost_direction
	_boost_time = boost_duration
	_boost_cooldown_left = boost_cooldown
	_boost_trail_time = 0.0
	_trigger_camera_shake(0.75, 0.08)
	SFX.play(self, "boost", -7.0, _rng.randf_range(0.96, 1.05))
	_spawn_boost_afterimage()

func _spawn_boost_afterimage() -> void:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return
	var texture := animated_sprite.sprite_frames.get_frame_texture(animated_sprite.animation, animated_sprite.frame)
	if texture == null:
		return
	var ghost := Sprite2D.new()
	ghost.texture = texture
	ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ghost.flip_h = animated_sprite.flip_h
	ghost.z_as_relative = false
	ghost.z_index = z_index - 1
	ghost.modulate = Color(0.35, 1.5, 2.2, 0.34)
	get_tree().current_scene.add_child(ghost)
	ghost.global_position = animated_sprite.global_position
	var tween := ghost.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ghost, "global_position", ghost.global_position - _boost_direction * 13.0, 0.16)
	tween.tween_property(ghost, "modulate:a", 0.0, 0.16)
	tween.set_parallel(false)
	tween.tween_callback(ghost.queue_free)

func _trigger_camera_shake(strength: float, duration: float) -> void:
	_camera_shake_strength = maxf(_camera_shake_strength, strength)
	_camera_shake_time = maxf(_camera_shake_time, duration)

func _update_camera_shake(delta: float) -> void:
	if camera == null:
		return
	if _camera_shake_time > 0.0:
		_camera_shake_time = maxf(0.0, _camera_shake_time - delta)
		var falloff := clampf(_camera_shake_time / 0.18, 0.0, 1.0)
		camera.offset = Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * _camera_shake_strength * falloff
	else:
		camera.offset = camera.offset.move_toward(Vector2.ZERO, 80.0 * delta)
		_camera_shake_strength = 0.0

func _configure_survival_stats() -> void:
	match mecha_id:
		"M1":
			_primary_cooldown = 0.68
			_secondary_cooldown = 5.2
		"M2":
			_primary_cooldown = 0.72
			_secondary_cooldown = 5.4
		"M3":
			_primary_cooldown = 1.12
			_secondary_cooldown = 6.4
		"R1":
			_primary_cooldown = 0.56
			_secondary_cooldown = 5.8
		"R2":
			_primary_cooldown = 1.08
			_secondary_cooldown = 6.2
		"R3":
			_primary_cooldown = 1.36
			_secondary_cooldown = 6.8
		"R4":
			_primary_cooldown = 0.82
			_secondary_cooldown = 6.0
		"S1":
			_primary_cooldown = 0.94
			_secondary_cooldown = 6.2
		"S2":
			_primary_cooldown = 1.06
			_secondary_cooldown = 6.4
		"S3":
			_primary_cooldown = 0.76
			_secondary_cooldown = 5.6
		_:
			_primary_cooldown = 0.85
			_secondary_cooldown = 5.8

func _start_attack(direction: Vector2, launch_projectile: bool) -> void:
	if attacking or _dead:
		return
	if direction.length_squared() <= 0.001:
		direction = last_move_direction
	if direction.length_squared() <= 0.001:
		direction = Vector2.RIGHT

	_attack_direction = direction.normalized()
	last_move_direction = _attack_direction
	_update_facing(_attack_direction)
	attacking = true
	_attack_projectile_pending = launch_projectile
	_attack_fire_frame = maxi(0, int(animated_sprite.sprite_frames.get_frame_count("attack") / 2) - 1)
	animated_sprite.play("attack")

func _on_frame_changed() -> void:
	if not attacking or not _attack_projectile_pending or _dead:
		return
	if animated_sprite.animation != &"attack":
		return
	if animated_sprite.frame >= _attack_fire_frame:
		_attack_projectile_pending = false
		# Fire audio on the exact frame that creates the ability instead of at
		# animation start, keeping muzzle/impact timing coherent.
		SFX.play(self, "secondary" if _attack_alternate else "primary", -10.0 if not _attack_alternate else -7.5, _rng.randf_range(0.97, 1.04))
		_spawn_special_ability(_attack_direction)

func _on_animation_finished() -> void:
	if animated_sprite.animation == &"attack":
		attacking = false
		_attack_projectile_pending = false
		if is_player_controlled and not _dead:
			_update_facing(_attack_direction)
			animated_sprite.play("idle")

func _spawn_special_ability(direction: Vector2) -> void:
	var root := get_tree().current_scene
	if root == null:
		root = get_parent()
	var effect := SpecialAbilityScript.new() as SpacehaulSpecialAbility
	root.add_child(effect)
	var muzzle_origin := global_position + Vector2(0.0, -18.0) + direction.normalized() * 8.0
	effect.setup(mecha_id, muzzle_origin, global_position + Vector2(0.0, -18.0), _attack_target, get_rid(), _attack_alternate, impact_scale, primary_ability_tier, secondary_ability_tier)

func _get_attack_target(attack_dir: Vector2) -> Vector2:
	var joy_id := _first_connected_joypad()
	if joy_id >= 0:
		var stick := Vector2(
			Input.get_joy_axis(joy_id, JOY_AXIS_RIGHT_X),
			Input.get_joy_axis(joy_id, JOY_AXIS_RIGHT_Y)
		)
		if stick.length() >= GAMEPAD_AIM_DEADZONE:
			return global_position + Vector2(0.0, -18.0) + stick.normalized() * 220.0
	var mouse_target := get_global_mouse_position()
	if mouse_target.distance_squared_to(global_position) > 4.0:
		return mouse_target
	return global_position + Vector2(0.0, -18.0) + attack_dir.normalized() * 180.0

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
	# The authored mecha art faces left, so right-facing movement is mirrored.
	animated_sprite.flip_h = facing > 0

func _play_if_needed(animation_name: StringName) -> void:
	if attacking or _dead:
		return
	if animated_sprite.animation != animation_name or not animated_sprite.is_playing():
		animated_sprite.play(animation_name)

func _die() -> void:
	if _dead:
		return
	_dead = true
	attacking = false
	_attack_projectile_pending = false
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)
	if is_in_group("player_mecha"):
		remove_from_group("player_mecha")
	animated_sprite.speed_scale = 0.0
	_start_pixel_dissolve()
	destroyed.emit(self)

func _start_pixel_dissolve() -> void:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode unshaded;
uniform float dissolve_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 edge_color : source_color = vec4(0.3, 1.7, 2.2, 1.0);
float pixel_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (tex.a < 0.01) { discard; }
	vec2 tex_size = vec2(textureSize(TEXTURE, 0));
	vec2 pixel = floor(UV * tex_size);
	float noise = pixel_hash(pixel);
	if (noise < dissolve_amount) { discard; }
	float edge = step(dissolve_amount, noise) * (1.0 - step(dissolve_amount + 0.08, noise));
	tex.rgb += edge_color.rgb * edge * 1.6;
	COLOR = tex * COLOR;
}
"""
	_dissolve_material = ShaderMaterial.new()
	_dissolve_material.shader = shader
	_dissolve_material.set_shader_parameter("dissolve_amount", 0.0)
	animated_sprite.material = _dissolve_material
	var tween := create_tween()
	tween.tween_method(_set_dissolve_amount, 0.0, 1.0, 1.05)
	tween.tween_property(animated_sprite, "modulate:a", 0.0, 0.15)

func _set_dissolve_amount(value: float) -> void:
	if _dissolve_material != null:
		_dissolve_material.set_shader_parameter("dissolve_amount", value)


func _build_deck_transition_shader() -> void:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode unshaded;

uniform float dissolve_amount : hint_range(0.0, 1.0) = 0.0;
uniform float phase_strength : hint_range(0.0, 1.0) = 1.0;
uniform vec4 edge_color : source_color = vec4(0.35, 1.35, 1.65, 1.0);

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
	// Mostly vertical materialization with enough random breakup to look like
	// individual pixels being transmitted rather than a simple wipe.
	float ordered = mix(noise, 1.0 - UV.y, 0.62);
	if (ordered < dissolve_amount) {
		discard;
	}

	float edge = 1.0 - smoothstep(0.018, 0.105, abs(ordered - dissolve_amount));
	float scan = step(0.82, fract((pixel.x * 0.37 + pixel.y * 0.19) + TIME * 8.0));
	tex.rgb += edge_color.rgb * edge * (1.15 + phase_strength * 0.75);
	tex.rgb += edge_color.rgb * scan * phase_strength * edge * 0.32;
	COLOR = tex * COLOR;
}
"""
	_deck_transition_material = ShaderMaterial.new()
	_deck_transition_material.shader = shader
	_deck_transition_material.set_shader_parameter("dissolve_amount", 0.0)
	_deck_transition_material.set_shader_parameter("phase_strength", 1.0)

func _build_combat_shader() -> void:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode unshaded;
uniform float hit_flash : hint_range(0.0, 1.0) = 0.0;
uniform float boost_strength : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (tex.a < 0.01) { discard; }
	float stripe = step(0.5, fract((UV.y + UV.x * 0.18) * 24.0));
	vec3 boosted = tex.rgb + vec3(0.10, 0.78, 1.15) * boost_strength * (0.28 + stripe * 0.42);
	vec3 hurt = mix(boosted, vec3(1.0, 0.20, 0.10), hit_flash * 0.78);
	COLOR = vec4(hurt, tex.a) * COLOR;
}
"""
	_combat_material = ShaderMaterial.new()
	_combat_material.shader = shader
	_combat_material.set_shader_parameter("hit_flash", 0.0)
	_combat_material.set_shader_parameter("boost_strength", 0.0)
	animated_sprite.material = _combat_material

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
