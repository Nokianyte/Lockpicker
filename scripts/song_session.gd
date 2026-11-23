extends RefCounted

signal penalized

const Chart = preload("res://scripts/song_chart.gd")
const T = preload("res://scripts/tuning.gd")
const G = preload("res://scripts/wall_geometry.gd")

const HIT_WINDOW := 0.10
const PERFECT_WINDOW := 0.035
const GOOD_WINDOW := 0.070
const LEAD_IN := 1.5
const MAX_ENERGY := 100
const ENERGY_PER_HIT := 5
const ENERGY_PER_MISTAKE := 15
const CLOCK_EPSILON := 0.000001

enum Judgment { NONE, PERFECT, GOOD, OK, MISS }

var events: Array[Dictionary] = []
var slider_turns: Array[Dictionary] = []
var input_circle_track: Array[Dictionary] = []
var resolved := PackedByteArray()
var energy := MAX_ENERGY
var combo := 0
var hits := 0
var misses := 0
var spike_hits := 0
var time := 0.0
var duration := 0.0
var feedback := ""
var feedback_at := -INF
var tint_judgment := Judgment.NONE
var tint_at := -INF
var tint_side := 0

var _deadline_order: Array[int] = []
var _deadline_cursor := 0
var _inner := 0
var _turn_from := 0.0
var _turn_target := 0.0
var _turn_started := -INF

func setup(schedule: Array[Dictionary], length: float, cursor: float, start: float, inputs: Array[Dictionary] = []) -> void:
	time = start
	duration = length
	slider_turns = build_slider_turns(schedule)
	input_circle_track = inputs
	for event in schedule:
		if event.time >= cursor and event.time < duration:
			_deadline_order.append(events.size())
			events.append(event)
	resolved.resize(events.size())
	_deadline_order.sort_custom(func(a: int, b: int) -> bool:
		var left := _deadline(a)
		var right := _deadline(b)
		if left == right:
			return events[a].spike and not events[b].spike
		return left < right
	)

func ring_angle(index: int, at: float) -> float:
	var event := events[index]
	return Chart.approach_angle(event, Chart.remaining_approach(event, at)) + turn_offset(index, at)

func turn_offset(index: int, at: float) -> float:
	var event := events[index]
	if _inner < events.size() and event.time == events[_inner].time:
		return G.turn_angle(_turn_from, _turn_target, at - _turn_started)
	return 0.0

func rotate(direction: float, at: float) -> void:
	advance_to(at)
	_turn_inner(direction)

func center_angle(at: float) -> float:
	return center_angle_at(slider_turns, at)

static func build_slider_turns(schedule: Array[Dictionary]) -> Array[Dictionary]:
	var turns: Array[Dictionary] = []
	var steps := 0
	for event in schedule:
		if event.has("slider_direction"):
			var direction: int = event.slider_direction
			steps += direction
			turns.append({"time": event.time, "direction": direction, "steps": steps})
	return turns

static func center_angle_at(turns: Array[Dictionary], at: float) -> float:
	var stop := first_event_at(turns, at)
	if stop == 0:
		return T.TIP_ANGLE
	var offset := (int(turns[stop - 1].steps) % 6) * T.WHEEL_STEP
	# Start with the full turns, then subtract the portion of each turn still in progress.
	for index in range(stop - 1, -1, -1):
		var turn := turns[index]
		var elapsed := at - float(turn.time)
		if elapsed >= T.TURN_DURATION:
			break
		var step := int(turn.direction) * T.WHEEL_STEP
		offset -= step - G.turn_angle(0.0, step, elapsed)
	return T.TIP_ANGLE + offset

static func note_input_side(turns: Array[Dictionary], inputs: Array[Dictionary], note: Dictionary, angle: float, at: float) -> int:
	# A slider's own scheduled turn must not pull its target away during the late hit window.
	var aim_at := minf(at, note.time) if note.has("slider_direction") else at
	var center := center_angle_at(turns, aim_at)
	var side := G.nearest_input_side(center, angle)
	if (Chart.input_mask_at(inputs, aim_at) & (1 << side)) != 0 and G.gap_accepts_tip(G.input_angle(center, side), angle):
		return side
	return -1

func _turn_inner(direction: float) -> void:
	if energy == 0 or _inner >= events.size():
		return
	var current := G.turn_angle(_turn_from, _turn_target, time - _turn_started)
	if time - _turn_started >= T.TURN_DURATION:
		current = wrapf(current, -PI, PI)
		_turn_target = current
	_turn_from = current
	_turn_target += direction * T.WHEEL_STEP
	_turn_started = time

func advance_to(at: float, finishing: bool = false) -> void:
	time = maxf(time, at)
	while _deadline_cursor < _deadline_order.size() and energy > 0:
		var index := _deadline_order[_deadline_cursor]
		var event := events[index]
		var deadline := _deadline(index)
		if not finishing and (deadline > time or (not event.spike and deadline >= time - CLOCK_EPSILON)):
			break
		_deadline_cursor += 1
		if resolved[index]:
			continue
		if event.spike:
			var angle := ring_angle(index, event.time)
			var center := center_angle(event.time)
			var side := G.nearest_input_side(center, angle)
			if (Chart.input_mask_at(input_circle_track, event.time) & (1 << side)) != 0 and G.song_spike_aligns(angle, G.input_angle(center, side)):
				spike_hits += 1
				_penalize("Spike", deadline)
		else:
			misses += 1
			_penalize("Miss", deadline)
		_resolve(index)

func press(at: float) -> void:
	advance_to(at)
	if energy == 0:
		return
	var index := _nearest_note(false)
	if index < 0:
		_feedback("Off beat", time)
		return
	_hit_note(index)

func press_arrow(direction: int, at: float) -> void:
	advance_to(at)
	if energy == 0:
		return
	var index := _nearest_note(true, direction)
	if index < 0:
		_turn_inner(direction)
	elif int(events[index].slider_direction) != direction:
		_feedback("Wrong arrow", time)
	else:
		_hit_note(index)

func _nearest_note(slider: bool, direction: int = 0) -> int:
	var best := -1
	var best_matches := false
	var distance := HIT_WINDOW + CLOCK_EPSILON
	for index in range(first_event_at(events, time - distance), events.size()):
		var event := events[index]
		if event.time > time + HIT_WINDOW + CLOCK_EPSILON:
			break
		var error := absf(event.time - time)
		if event.spike or event.has("slider_direction") != slider or resolved[index] or error > distance:
			continue
		var matches := (not slider or int(event.slider_direction) == direction) and _note_input_side(index) >= 0
		# At a shared beat, prefer a note the player can hit with this input.
		if error < distance or (best >= 0 and event.time == events[best].time and matches and not best_matches):
			best = index
			distance = error
			best_matches = matches
	return best

func _note_input_side(index: int) -> int:
	return note_input_side(slider_turns, input_circle_track, events[index], ring_angle(index, time), time)

func _hit_note(index: int) -> void:
	var note := events[index]
	var side := _note_input_side(index)
	if side < 0:
		_feedback("Wrong direction", time)
		return
	_resolve(index)
	hits += 1
	combo += 1
	energy = mini(MAX_ENERGY, energy + ENERGY_PER_HIT)
	var timing := time - float(note.time)
	var error := absf(timing)
	var timing_label := " · Early" if timing < 0.0 else " · Late"
	if error <= PERFECT_WINDOW + CLOCK_EPSILON:
		_judge(Judgment.PERFECT, "Perfect", time, side)
	elif error <= GOOD_WINDOW + CLOCK_EPSILON:
		_judge(Judgment.GOOD, "Good" + timing_label, time, side)
	else:
		_judge(Judgment.OK, "OK" + timing_label, time)

static func first_event_at(schedule: Array[Dictionary], at: float) -> int:
	var low := 0
	var high := schedule.size()
	while low < high:
		var middle := (low + high) >> 1
		if schedule[middle].time < at:
			low = middle + 1
		else:
			high = middle
	return low

func _resolve(index: int) -> void:
	resolved[index] = 1
	if index != _inner:
		return
	var previous_beat: float = events[_inner].time
	while _inner < events.size() and resolved[_inner]:
		_inner += 1
	# Markers at the same beat share the current layer's rotation.
	if _inner == events.size() or events[_inner].time != previous_beat:
		_turn_from = 0.0
		_turn_target = 0.0
		_turn_started = -INF

func _deadline(index: int) -> float:
	var event := events[index]
	return float(event.time) if event.spike else minf(float(event.time) + HIT_WINDOW, duration)

func _feedback(message: String, at: float) -> void:
	feedback = message
	feedback_at = at

func _judge(result: Judgment, message: String, at: float, side: int = 0) -> void:
	if result != Judgment.OK:
		tint_judgment = result
		tint_at = at
		tint_side = side
	_feedback(message, at)

func _penalize(message: String, at: float) -> void:
	energy = maxi(0, energy - ENERGY_PER_MISTAKE)
	combo = 0
	_judge(Judgment.MISS, message, at)
	penalized.emit()
