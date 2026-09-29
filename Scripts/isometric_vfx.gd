extends RefCounted
class_name SpacehaulIsoVfx

# SPACEHAUL's procedural deck uses 64x32 diamonds. Ground-space Y therefore
# projects to half the screen distance of ground-space X.
const GROUND_Y_SCALE := 0.5

static func project_ground(value: Vector2) -> Vector2:
	return Vector2(value.x, value.y * GROUND_Y_SCALE)

static func unproject_ground(value: Vector2) -> Vector2:
	return Vector2(value.x, value.y / GROUND_Y_SCALE)

static func ground_offset(angle: float, radius: float) -> Vector2:
	return project_ground(Vector2(cos(angle), sin(angle)) * radius)

static func ground_point(center: Vector2, angle: float, radius: float) -> Vector2:
	return center + ground_offset(angle, radius)

# Converts a screen-facing direction into a displacement measured in true
# ground-space units. This is the important distinction from simply doing
# screen_direction * distance: vertical/depth travel compresses with the deck.
static func ground_vector(screen_direction: Vector2, ground_length: float, radians: float = 0.0) -> Vector2:
	var safe := screen_direction
	if safe.length_squared() <= 0.0001:
		safe = Vector2.RIGHT
	var logical_direction := unproject_ground(safe).normalized().rotated(radians)
	return project_ground(logical_direction * ground_length)

static func rotate_ground_direction(screen_direction: Vector2, radians: float) -> Vector2:
	var projected := ground_vector(screen_direction, 1.0, radians)
	if projected.length_squared() <= 0.0001:
		return Vector2.RIGHT
	return projected.normalized()

static func ground_perpendicular(screen_direction: Vector2) -> Vector2:
	return rotate_ground_direction(screen_direction, PI * 0.5)

static func ground_perpendicular_offset(screen_direction: Vector2, ground_length: float) -> Vector2:
	return ground_vector(screen_direction, ground_length, PI * 0.5)

static func rotate_ground_vector(screen_vector: Vector2, radians: float) -> Vector2:
	return project_ground(unproject_ground(screen_vector).rotated(radians))

static func ground_distance(a: Vector2, b: Vector2) -> float:
	return unproject_ground(b - a).length()

static func inside_ground_radius(center: Vector2, point: Vector2, radius: float) -> bool:
	return ground_distance(center, point) <= radius
