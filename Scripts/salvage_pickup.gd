extends Area2D
class_name SpacehaulSalvagePickup

@export var value := 1
@export var magnet_radius := 86.0
@export var magnet_speed := 150.0

var _target: MechaController
var _age := 0.0
var _bob_phase := 0.0
var _collected := false

func setup(world_position: Vector2, salvage_value: int = 1) -> void:
	global_position = world_position.round()
	value = maxi(1, salvage_value)

func _ready() -> void:
	add_to_group("salvage_pickups")
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	monitorable = false
	z_as_relative = false
	z_index = 1750
	_bob_phase = fmod(float(get_instance_id()), 31.0)

	var shape := CircleShape2D.new()
	shape.radius = 5.0
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
	body_entered.connect(_on_body_entered)

	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive
	queue_redraw()

func _process(delta: float) -> void:
	if _collected:
		return
	_age += delta
	if _target == null or not is_instance_valid(_target):
		_target = get_tree().get_first_node_in_group("player_mecha") as MechaController

	if _target != null and is_instance_valid(_target):
		var delta_to_target := _target.global_position + Vector2(0.0, -8.0) - global_position
		var distance := delta_to_target.length()
		var effective_radius := magnet_radius
		var managers := get_tree().get_nodes_in_group("survival_manager")
		if not managers.is_empty() and managers[0].has_method("get_salvage_magnet_radius"):
			effective_radius = float(managers[0].call("get_salvage_magnet_radius"))
		if distance <= effective_radius and distance > 0.001:
			var pull := magnet_speed * (1.0 + (1.0 - distance / maxf(effective_radius, 1.0)) * 1.8)
			global_position += delta_to_target.normalized() * pull * delta

	queue_redraw()

func _on_body_entered(body: Node) -> void:
	if _collected:
		return
	if not body.is_in_group("player_mecha"):
		return
	_collected = true
	for manager in get_tree().get_nodes_in_group("survival_manager"):
		if manager.has_method("collect_salvage"):
			manager.call("collect_salvage", value)
			break
	queue_free()

func _draw() -> void:
	var bob := roundi(sin(_age * 5.0 + _bob_phase) * 1.0)
	var p := Vector2(0.0, float(bob))
	var glow := Color(0.25, 1.35, 1.7, 0.42)
	var core := Color(1.2, 3.0, 3.2, 1.0)
	# Tight pixel-art pickup: 2x2 additive bloom around a bright 1x1 core.
	draw_rect(Rect2((p - Vector2.ONE).round(), Vector2(2.0, 2.0)), glow, true)
	draw_rect(Rect2(p.round(), Vector2.ONE), core, true)
	if value >= 3:
		draw_rect(Rect2((p + Vector2(2.0, 0.0)).round(), Vector2.ONE), core, true)
