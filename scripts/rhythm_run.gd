extends RefCounted

const T = preload("res://scripts/tuning.gd")
const G = preload("res://scripts/wall_geometry.gd")

const BPM := 100.0
const BEAT_SECONDS := 60.0 / BPM
const COUNT_IN_BEATS := 2
const CHART_BEATS := 32
const PERFECT_WINDOW := 0.045
const GOOD_WINDOW := 0.100
const APPROACH_SPEED := 75.0
const CORE_RADIUS := 100.0
const MARKER_RADIUS := 11.0
const ALIGNMENT_ANGLE := 0.055
const SPIKE_DEPTH := 18.0
const SPIKE_PASS_WINDOW := 0.20
const SPIKE_BEATS := [6.0, 14.0, 20.0, 28.0]

# Each pair gives the beat after the count-in and the opening's initial
# offset from the fixed tip, measured in 60-degree wheel notches.
const CHART := [
	Vector2(0, -1), Vector2(2, 1), Vector2(4, 1), Vector2(6, 0),
	Vector2(8, -1), Vector2(10, -1), Vector2(12, 0), Vector2(14, 0),
	Vector2(16, 1), Vector2(17, -1), Vector2(18, -1), Vector2(19, 1),
	Vector2(20, 0), Vector2(21, 1), Vector2(22, 1), Vector2(23, 0),
	Vector2(24, -1), Vector2(25, -1), Vector2(26, -1), Vector2(26.5, -1),
	Vector2(28, 0), Vector2(29, 1), Vector2(30, 1), Vector2(31, -1),
]

enum State { TITLE, PLAYING, RESULTS, CRASHED }
var state := State.TITLE
var paused := false
var time := -COUNT_IN_BEATS * BEAT_SECONDS
var next_note := 0
var score := 0
var combo := 0
var best_combo := 0
var perfect_hits := 0
var good_hits := 0
var misses := 0
var feedback := ""
var feedback_time := -INF
var cleared: Array[Dictionary] = []

var ring_rotation := 0.0
var turn_from := 0.0
var turn_target := 0.0
var turn_time := -INF

func reset() -> void:
	state = State.PLAYING
	paused = false
	time = -COUNT_IN_BEATS * BEAT_SECONDS
	next_note = 0
	score = 0
	combo = 0
	best_combo = 0
	perfect_hits = 0
	good_hits = 0
	misses = 0
	feedback = ""
	feedback_time = -INF
	cleared.clear()
	_reset_turn()

func rotate(direction: float) -> void:
	if state != State.PLAYING or paused or next_note >= CHART.size():
		return
	turn_from = ring_rotation
	turn_target += direction * T.WHEEL_STEP
	turn_time = time

func advance(seconds: float) -> void:
	if state != State.PLAYING or paused:
		return
	var end := minf(time + seconds, CHART_BEATS * BEAT_SECONDS)
	while next_note < CHART.size():
		var spike := is_spike(next_note)
		var deadline := hit_time(next_note) + (SPIKE_PASS_WINDOW if spike else GOOD_WINDOW)
		var until := minf(end, deadline)
		if spike and _advance_spike(until):
			state = State.CRASHED
			return
		_set_time(until)
		if end <= deadline:
			return
		if spike:
			_next_ring()
		else:
			_judge_miss("MISS")
	_set_time(end)
	if time >= CHART_BEATS * BEAT_SECONDS:
		state = State.RESULTS

func _set_time(value: float) -> void:
	time = value
	var turn_progress := clampf((time - turn_time) / T.TURN_DURATION, 0.0, 1.0)
	ring_rotation = lerpf(turn_from, turn_target, smoothstep(0.0, 1.0, turn_progress))

func _advance_spike(until: float) -> bool:
	var center := marker_center()
	# Before this time even a directly aligned spike tip is outside the circle.
	var reach := (MARKER_RADIUS + SPIKE_DEPTH) / (APPROACH_SPEED * cos(PI / 6.0))
	if until < hit_time(next_note) - reach:
		return false
	_set_time(maxf(time, hit_time(next_note) - reach))
	while true:
		var points := spike_points(next_note)
		if Geometry2D.is_point_in_polygon(center, points):
			return true
		var distance := INF
		for i in range(points.size()):
			var closest := Geometry2D.get_closest_point_to_segment(center, points[i], points[(i + 1) % points.size()])
			distance = minf(distance, center.distance_to(closest))
		if distance <= MARKER_RADIUS + 0.001:
			return true
		if time >= until:
			return false
		# Bound how fast the shrinking triangle can close on the fixed circle.
		var edge_speed := APPROACH_SPEED
		if time < turn_time + T.TURN_DURATION:
			var angular_speed := 1.5 * absf(turn_target - turn_from) / T.TURN_DURATION
			edge_speed += radius(next_note) * angular_speed
		_set_time(minf(time + (distance - MARKER_RADIUS) / edge_speed, until))
	return false

func tap() -> void:
	if state != State.PLAYING or paused or next_note >= CHART.size():
		return
	if is_spike(next_note):
		return
	var error := time - hit_time(next_note)
	if error < -GOOD_WINDOW:
		if time >= 0.0:
			combo = 0
			_show_feedback("EARLY")
		return
	if not is_aligned(next_note):
		_judge_miss("MISALIGNED")
		return

	var perfect := absf(error) <= PERFECT_WINDOW
	if perfect:
		perfect_hits += 1
		score += 100
	else:
		good_hits += 1
		score += 50
	combo += 1
	best_combo = maxi(best_combo, combo)
	_show_feedback("PERFECT" if perfect else ("GOOD · EARLY" if error < 0.0 else "GOOD · LATE"))
	cleared.append({"radius": radius(next_note), "angle": gap_angle(next_note)})
	_next_ring()

func _judge_miss(label: String) -> void:
	misses += 1
	combo = 0
	_next_ring()
	_show_feedback(label)

func _next_ring() -> void:
	next_note += 1
	_reset_turn()

func _reset_turn() -> void:
	ring_rotation = 0.0
	turn_from = 0.0
	turn_target = 0.0
	turn_time = -INF

func _show_feedback(label: String) -> void:
	feedback = label
	feedback_time = time

func hit_time(index: int) -> float:
	return CHART[index].x * BEAT_SECONDS

func gap_angle(index: int) -> float:
	var rotation := ring_rotation if index == next_note else 0.0
	return T.TIP_ANGLE + CHART[index].y * T.WHEEL_STEP + rotation

func is_spike(index: int) -> bool:
	return CHART[index].x in SPIKE_BEATS

func is_aligned(index: int) -> bool:
	return absf(angle_difference(T.TIP_ANGLE, gap_angle(index))) <= ALIGNMENT_ANGLE

func radius(index: int) -> float:
	return CORE_RADIUS + (hit_time(index) - time) * APPROACH_SPEED

func spike_points(index: int) -> PackedVector2Array:
	var angle := gap_angle(index)
	var ring_radius := radius(index)
	var half_gap := T.GAP_ANGLE * 0.5
	return PackedVector2Array([
		G.point(ring_radius, angle, angle - half_gap),
		G.point(ring_radius, angle, angle) - Vector2.from_angle(angle) * SPIKE_DEPTH,
		G.point(ring_radius, angle, angle + half_gap),
	])

static func marker_center() -> Vector2:
	return G.point(CORE_RADIUS, T.TIP_ANGLE, T.TIP_ANGLE)
