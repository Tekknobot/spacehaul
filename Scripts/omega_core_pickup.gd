extends Area2D
class_name SpaceMechaOmegaCorePickup

const ParticleScript = preload("res://Scripts/ability_particle_emitter.gd")
const SFX = preload("res://Scripts/sound_fx.gd")

# Omega Cores are intentionally NOT salvage-like. They are fixed world drops:
# no magnet radius, no drift toward the player, and no lifetime. The player has
# to physically reach the beacon to collect it.
@export var pickup_radius := 9.0
@export_range(0.25, 2.0, 0.05) var idle_burst_interval := 0.75

var _drop_position := Vector2.ZERO
var _age := 0.0
var _bob_phase := 0.0
var _collected := false
var _idle_burst_timer := 0.0
var _beam: Line2D
var _beam_glow: Line2D
var _beacon: Line2D
var _beacon_glow: Line2D
var _orbit_lines: Array[Line2D] = []

const CORE := Color(3.2, 1.05, 3.8, 1.0)
const HOT := Color(3.4, 2.55, 3.8, 1.0)
const GLOW := Color(1.2, 0.16, 1.75, 0.46)

func setup(world_position: Vector2) -> void:
	_drop_position = world_position.round()
	global_position = _drop_position
	var root := get_tree().current_scene
	if root != null:
		var emitter := ParticleScript.new() as SpacehaulAbilityParticles
		root.add_child(emitter)
		emitter.setup_burst(global_position, HOT, GLOW, "phase", 18, 38.0, 0.42)
	SFX.play(self, "level", -12.0, 0.70)

func _ready() -> void:
	add_to_group("omega_core_pickups")
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	monitorable = false
	z_as_relative = false
	z_index = 1810
	_bob_phase = fmod(float(get_instance_id()), 31.0)
	_idle_burst_timer = idle_burst_interval * 0.45

	# setup() is called immediately after add_child(), which means _ready() runs
	# first. Keep a safe fallback in case this pickup is ever instantiated directly.
	if _drop_position == Vector2.ZERO:
		_drop_position = global_position.round()

	var shape := CircleShape2D.new()
	shape.radius = pickup_radius
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
	body_entered.connect(_on_body_entered)

	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive

	# Tall persistent loot beacon. This stays anchored to the death location and
	# is deliberately much taller than the original so it remains visible through
	# dense enemies, gas, and attack effects.
	_beam_glow = Line2D.new()
	_beam_glow.width = 5.0
	_beam_glow.default_color = Color(1.0, 0.12, 1.65, 0.14)
	_beam_glow.antialiased = false
	_beam_glow.add_point(Vector2(0.0, -8.0))
	_beam_glow.add_point(Vector2(0.0, -150.0))
	add_child(_beam_glow)

	_beam = Line2D.new()
	_beam.width = 1.0
	_beam.default_color = Color(3.2, 1.45, 3.8, 0.94)
	_beam.antialiased = false
	_beam.add_point(Vector2(0.0, -7.0))
	_beam.add_point(Vector2(0.0, -154.0))
	add_child(_beam)

	# Isometric ground beacon. Unlike the bobbing core, this never moves, so the
	# exact pickup location remains readable even when the screen is chaotic.
	_beacon_glow = _make_beacon_line(3.0, Color(1.1, 0.12, 1.65, 0.18), 15.0)
	add_child(_beacon_glow)
	_beacon = _make_beacon_line(1.0, Color(3.2, 0.85, 3.8, 0.88), 12.0)
	add_child(_beacon)

	for i in range(3):
		var line := Line2D.new()
		line.width = 1.0
		line.default_color = Color(3.0, 0.75 + float(i) * 0.22, 3.7, 0.78)
		line.antialiased = false
		line.add_point(Vector2.ZERO)
		line.add_point(Vector2.ZERO)
		add_child(line)
		_orbit_lines.append(line)

	queue_redraw()

func _make_beacon_line(width: float, color: Color, radius: float) -> Line2D:
	var line := Line2D.new()
	line.width = width
	line.default_color = color
	line.antialiased = false
	var points := PackedVector2Array([
		Vector2(0.0, -radius * 0.42),
		Vector2(radius, 0.0),
		Vector2(0.0, radius * 0.42),
		Vector2(-radius, 0.0),
		Vector2(0.0, -radius * 0.42)
	])
	line.points = points
	return line

func _process(delta: float) -> void:
	if _collected:
		return

	# Hard-anchor the pickup to the point where it dropped. This is the important
	# behavioral difference from salvage: nearby player movement can never pull it.
	global_position = _drop_position
	_age += delta
	_idle_burst_timer -= delta

	var bob := roundf(sin(_age * 4.6 + _bob_phase) * 2.0)
	var pulse := 0.72 + sin(_age * 8.0) * 0.20

	if _beam != null:
		_beam.set_point_position(0, Vector2(0.0, -7.0 + bob))
		_beam.set_point_position(1, Vector2(0.0, -154.0 + sin(_age * 6.2) * 3.0))
		_beam.modulate.a = 0.76 + sin(_age * 8.0) * 0.20
	if _beam_glow != null:
		_beam_glow.set_point_position(0, Vector2(0.0, -8.0 + bob))
		_beam_glow.set_point_position(1, Vector2(0.0, -150.0 + sin(_age * 5.7) * 2.0))
		_beam_glow.modulate.a = 0.82 + sin(_age * 4.0) * 0.12
	if _beacon != null:
		_beacon.modulate.a = 0.70 + pulse * 0.25
	if _beacon_glow != null:
		_beacon_glow.modulate.a = 0.60 + pulse * 0.28

	for i in range(_orbit_lines.size()):
		var line := _orbit_lines[i]
		var angle := _age * (1.8 + float(i) * 0.17) + TAU * float(i) / 3.0
		var radius := 9.0 + float(i) * 2.0
		var a := Vector2(cos(angle), sin(angle) * 0.46) * radius + Vector2(0.0, bob)
		var b := Vector2(cos(angle + 0.72), sin(angle + 0.72) * 0.46) * (radius + 3.0) + Vector2(0.0, bob)
		line.set_point_position(0, a.round())
		line.set_point_position(1, b.round())

	# A tiny periodic phase flare keeps the stationary drop alive visually without
	# turning it into a noisy continuous particle fountain.
	if _idle_burst_timer <= 0.0:
		_idle_burst_timer = idle_burst_interval
		_spawn_idle_burst()

	queue_redraw()

func _spawn_idle_burst() -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	var emitter := ParticleScript.new() as SpacehaulAbilityParticles
	root.add_child(emitter)
	emitter.setup_burst(global_position + Vector2(0.0, -4.0), HOT, GLOW, "phase", 5, 16.0, 0.30)

func _on_body_entered(body: Node) -> void:
	if _collected or not body.is_in_group("player_mecha"):
		return
	_collected = true
	monitoring = false
	var root := get_tree().current_scene
	if root != null:
		var emitter := ParticleScript.new() as SpacehaulAbilityParticles
		root.add_child(emitter)
		emitter.setup_burst(global_position, Color(3.5, 2.7, 3.9, 1.0), Color(1.25, 0.18, 1.8, 1.0), "phase", 20, 54.0, 0.42)
	SFX.play_ui(self, "level", -5.5, 0.82)
	for manager in get_tree().get_nodes_in_group("survival_manager"):
		if manager.has_method("collect_omega_core"):
			manager.call("collect_omega_core")
			break
	queue_free()

func _draw() -> void:
	var bob := roundi(sin(_age * 4.6 + _bob_phase) * 2.0)
	var p := Vector2(0.0, float(bob))
	var pulse := 0.72 + sin(_age * 8.0) * 0.20

	# Larger hard-pixel silhouette than salvage, with a white-hot center.
	draw_rect(Rect2((p - Vector2(6.0, 6.0)).round(), Vector2(12.0, 12.0)), Color(GLOW.r, GLOW.g, GLOW.b, GLOW.a * pulse * 0.72), true)
	draw_rect(Rect2((p - Vector2(4.0, 4.0)).round(), Vector2(8.0, 8.0)), Color(1.35, 0.18, 1.8, 0.50), true)
	draw_rect(Rect2((p - Vector2(2.0, 4.0)).round(), Vector2(4.0, 8.0)), Color(1.65, 0.24, 2.05, 0.74), true)
	draw_rect(Rect2((p + Vector2(-4.0, -1.0)).round(), Vector2(8.0, 2.0)), Color(2.8, 0.70, 3.5, 0.94), true)
	draw_rect(Rect2((p - Vector2.ONE).round(), Vector2(2.0, 2.0)), CORE, true)
	draw_rect(Rect2((p + Vector2(0.0, -1.0)).round(), Vector2.ONE), HOT, true)
