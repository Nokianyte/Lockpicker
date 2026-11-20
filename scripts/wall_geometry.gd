extends RefCounted

const T = preload("res://scripts/tuning.gd")

static func point(radius: float, rotation: float, angle: float) -> Vector2:
	# Intersect a ray with a regular hexagon. Gap and collision use the same outline.
	var sector := PI / 3.0
	var offset := fposmod(angle - rotation + sector / 2.0, sector) - sector / 2.0
	var distance := radius * cos(PI / 6.0) / cos(offset)
	return Vector2.from_angle(angle) * distance

static func segments(radius: float, rotation: float) -> Array:
	var start := rotation + T.GAP_ANGLE / 2.0
	var finish := rotation + TAU - T.GAP_ANGLE / 2.0
	var angles: Array[float] = [start]
	for i in range(6):
		var a := rotation + PI / 6.0 + i * PI / 3.0
		if a > start and a < finish:
			angles.append(a)
	angles.append(finish)
	var result: Array = []
	for i in range(angles.size() - 1):
		result.append([point(radius, rotation, angles[i]), point(radius, rotation, angles[i + 1])])
	return result

static func distance_to_wall(p: Vector2, radius: float, rotation: float) -> float:
	var result := INF
	for segment in segments(radius, rotation):
		result = minf(result, p.distance_to(Geometry2D.get_closest_point_to_segment(p, segment[0], segment[1])))
	return result

static func swept_hit(from: Vector2, to: Vector2, old_radius: float, new_radius: float, rotation: float, clearance: float, old_rotation: float = NAN) -> float:
	# Conservative advancement: a distance bound covers both dot and wall motion.
	# Unlike discrete endpoint tests, this cannot step over a thin wall.
	var start_angle := rotation if is_nan(old_rotation) else old_rotation
	var angle_delta := angle_difference(start_angle, rotation)
	var bound := from.distance_to(to) + absf(new_radius - old_radius) + maxf(old_radius, new_radius) * absf(angle_delta)
	var t := 0.0
	for iteration in range(128):
		var distance := distance_to_wall(from.lerp(to, t), lerpf(old_radius, new_radius, t), start_angle + angle_delta * t) - clearance
		if distance <= 0.001:
			return t
		if bound < 0.00001:
			return -1.0
		t += maxf(distance / bound * 0.9, 0.000001)
		if t > 1.0:
			return -1.0
	return t if t <= 1.0 else -1.0
