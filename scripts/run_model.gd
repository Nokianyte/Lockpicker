extends RefCounted

const T = preload("res://scripts/tuning.gd")
const G = preload("res://scripts/wall_geometry.gd")

enum State { TITLE, PLAYING, OVER }
var state := State.TITLE
var paused := false
var boosting := false
var walls: Array[Dictionary] = []
var cleared: Array[Dictionary] = []
var score := 0
var shrink_speed := 0.0
var rng := RandomNumberGenerator.new()
var tip_angle := T.TIP_ANGLE
var turn_from := T.TIP_ANGLE
var turn_target := T.TIP_ANGLE
var turn_elapsed := T.TURN_DURATION

func _init() -> void:
	reset(42)
	state = State.TITLE

func reset(seed_value: int = 0) -> void:
	rng.seed = seed_value if seed_value != 0 else Time.get_ticks_usec()
	walls.clear()
	cleared.clear()
	score = 0
	paused = false
	boosting = false
	tip_angle = T.TIP_ANGLE
	turn_from = tip_angle
	turn_target = tip_angle
	turn_elapsed = T.TURN_DURATION
	state = State.PLAYING
	for i in range(T.WALL_COUNT):
		_append_wall(T.INITIAL_RADIUS + i * T.WALL_SPACING)
	# One downward notch aligns the opening on the first ring.
	walls[0].angle = T.TIP_ANGLE + T.WHEEL_STEP
	_set_layer_pace()

func _append_wall(radius: float) -> void:
	var gap_angle := T.TIP_ANGLE + rng.randi_range(0, 5) * T.WHEEL_STEP
	walls.append({"radius": radius, "angle": wrapf(gap_angle, -PI, PI)})

func press() -> void:
	if paused:
		paused = false
	elif state == State.TITLE or state == State.OVER:
		reset()
	else:
		boosting = true

func rotate(direction: float) -> void:
	if state != State.PLAYING or paused:
		return
	turn_from = tip_angle
	turn_target += direction * T.WHEEL_STEP
	turn_elapsed = 0.0

func _set_layer_pace() -> void:
	# Match the dot version's aiming windows. Calculate the rate once per
	# layer so an early drop still leaves time to aim at the next opening.
	var aim_time := T.OPENING_TIME
	if score > 0:
		aim_time = maxf(T.MIN_LAYER_TIME, 0.60 + 4.75 / pow(score, 0.82))
	var wall := walls[0]
	var contact_radius := G.tip_contact_radius(wall.angle, wall.angle)
	shrink_speed = (wall.radius - contact_radius) / aim_time

func _turn_angle(seconds: float) -> float:
	return G.turn_angle(turn_from, turn_target, seconds)

func step(dt: float) -> void:
	var remaining := dt
	while remaining > 0.000001 and state == State.PLAYING and not paused:
		var part := minf(remaining, 1.0 / 120.0)
		_tick(part)
		remaining -= part

func _tick(dt: float) -> void:
	var active_speed := T.DROP_SPEED if boosting else shrink_speed
	var wall := walls[0]
	var hit := _contact_time(wall.radius, wall.angle, active_speed, dt)
	var failed := hit >= 0.0 and not G.gap_accepts_tip(_turn_angle(turn_elapsed + hit), wall.angle)
	var elapsed := hit if failed else dt
	turn_elapsed = minf(turn_elapsed + elapsed, T.TURN_DURATION)
	tip_angle = _turn_angle(turn_elapsed)
	if turn_elapsed >= T.TURN_DURATION:
		tip_angle = wrapf(tip_angle, -PI, PI)
		turn_from = tip_angle
		turn_target = tip_angle

	for i in range(1, walls.size()):
		walls[i].radius -= shrink_speed * elapsed
	wall.radius -= active_speed * (hit if hit >= 0.0 else dt)
	if failed:
		state = State.OVER
		boosting = false
		return
	if hit >= 0.0:
		boosting = false
		cleared.append(walls.pop_front())
		score += 1
	# Refill from a fixed outer radius when there's enough space. Existing
	# rings keep drifting inward while the accelerated ring opens up room.
	if walls.is_empty() or (walls.size() < T.WALL_COUNT and walls[-1].radius <= T.OUTER_RADIUS - T.WALL_SPACING):
		_append_wall(T.OUTER_RADIUS)
	if hit >= 0.0:
		_set_layer_pace()

func _contact_time(radius: float, gap_angle: float, active_speed: float, dt: float) -> float:
	# Bound how quickly the distance can close as the tip rotates and the wall
	# shrinks. Advance only that far so a fast turn can't skip first contact.
	var max_angular_speed := 0.0
	if turn_elapsed < T.TURN_DURATION:
		max_angular_speed = 1.5 * absf(turn_target - turn_from) / T.TURN_DURATION
	var closing_speed := active_speed + T.TIP_LENGTH * max_angular_speed / cos(PI / 6.0)
	var time := 0.0
	while time <= dt:
		var angle := _turn_angle(turn_elapsed + time)
		var distance := radius - active_speed * time - G.tip_contact_radius(angle, gap_angle)
		if distance <= 0.001:
			return time
		time += maxf(distance / closing_speed, 0.0000001)
	return -1.0

func pause() -> void:
	if state == State.PLAYING:
		paused = true
		boosting = false
