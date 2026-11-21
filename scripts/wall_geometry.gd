extends RefCounted

const T = preload("res://scripts/tuning.gd")

static func turn_angle(from: float, target: float, seconds: float) -> float:
	var progress := clampf(seconds / T.TURN_DURATION, 0.0, 1.0)
	return lerpf(from, target, smoothstep(0.0, 1.0, progress))

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

static func tip_contact_radius(tip_angle: float, gap_angle: float) -> float:
	# Include the inner edge of the stroke when the tip reaches the ring.
	return T.TIP_LENGTH / point(1.0, gap_angle, tip_angle).length() + T.WALL_WIDTH / (2.0 * cos(PI / 6.0))

static func gap_accepts_tip(tip_angle: float, gap_angle: float) -> bool:
	return absf(angle_difference(tip_angle, gap_angle)) < T.GAP_ANGLE / 2.0 - T.TIP_EDGE_MARGIN

static func song_marker(radius: float, angle: float) -> Vector2:
	return point(radius, angle, angle)

static func song_spike_aligns(angle: float, target_angle: float = T.TIP_ANGLE) -> bool:
	var target := song_marker(T.SONG_CORE_RADIUS, target_angle)
	var spike := song_marker(T.SONG_CORE_RADIUS, angle)
	return spike.distance_squared_to(target) <= T.SONG_SPIKE_ALIGNMENT_RADIUS * T.SONG_SPIKE_ALIGNMENT_RADIUS
