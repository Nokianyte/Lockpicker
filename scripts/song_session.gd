extends RefCounted

const Chart = preload("res://scripts/song_chart.gd")
const T = preload("res://scripts/tuning.gd")
const G = preload("res://scripts/wall_geometry.gd")

const APPROACH := 1.65
const HIT_WINDOW := 0.10
const LEAD_IN := 1.5
const MAX_ENERGY := 100
const ENERGY_PER_HIT := 5
const ENERGY_PER_MISTAKE := 15
const CLOCK_EPSILON := 0.000001

var events: Array[Dictionary] = []
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
var last_hit: Dictionary = {}

var _deadline_order: Array[int] = []
var _deadline_cursor := 0
var _turn_from := T.TIP_ANGLE
var _turn_target := T.TIP_ANGLE
var _turn_started := -INF

func setup(schedule: Array[Dictionary], length: float, cursor: float, start: float) -> void:
	time = start
	duration = length
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

func tip_angle(at: float) -> float:
	return wrapf(G.turn_angle(_turn_from, _turn_target, at - _turn_started), -PI, PI)

func rotate(direction: float, at: float) -> void:
	advance_to(at)
	if energy == 0:
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
		resolved[index] = 1
		if event.spike:
			if G.gap_accepts_tip(tip_angle(event.time), Chart.direction_angle(event.lane)):
				spike_hits += 1
				_penalize("Spike", deadline)
		else:
			misses += 1
			_penalize("Miss", deadline)

func press(at: float) -> void:
	advance_to(at)
	if energy == 0:
		return
	var best := -1
	var distance := HIT_WINDOW + CLOCK_EPSILON
	for index in range(first_event_at(events, time - distance), events.size()):
		var event := events[index]
		if event.time > time + HIT_WINDOW + CLOCK_EPSILON:
			break
		var error := absf(event.time - time)
		if not event.spike and not resolved[index] and error < distance:
			best = index
			distance = error
	if best < 0:
		_feedback("Off beat", time)
		return
	var note := events[best]
	if not G.gap_accepts_tip(tip_angle(time), Chart.direction_angle(note.lane)):
		_feedback("Wrong direction", time)
		return
	resolved[best] = 1
	hits += 1
	combo += 1
	energy = mini(MAX_ENERGY, energy + ENERGY_PER_HIT)
	last_hit = {"lane": note.lane, "at": time}
	var timing := time - float(note.time)
	if absf(timing) <= 0.035:
		_feedback("On beat", time)
	else:
		_feedback("Early" if timing < 0.0 else "Late", time)

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

func _deadline(index: int) -> float:
	var event := events[index]
	return float(event.time) if event.spike else minf(float(event.time) + HIT_WINDOW, duration)

func _feedback(message: String, at: float) -> void:
	feedback = message
	feedback_at = at

func _penalize(message: String, at: float) -> void:
	energy = maxi(0, energy - ENERGY_PER_MISTAKE)
	combo = 0
	_feedback(message, at)
