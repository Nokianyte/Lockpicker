extends RefCounted

const T = preload("res://scripts/tuning.gd")
const G = preload("res://scripts/wall_geometry.gd")
enum State { TITLE, READY, LAUNCHING, BOUNCING, OVER }
var state := State.TITLE
var paused := false
var walls: Array = []
var dot := Vector2.ZERO
var launch_origin := Vector2.ZERO
var score := 0
var rng := RandomNumberGenerator.new()
var cleared: Array = []
var bounce_count := 0
var elapsed := 0.0
var space_scale := 1.0

func _init() -> void:
	reset(42)
	state = State.TITLE

func reset(seed_value: int = 0) -> void:
	rng.seed = seed_value if seed_value != 0 else Time.get_ticks_usec()
	walls.clear()
	cleared.clear()
	dot = Vector2.ZERO
	score = 0
	bounce_count = 0
	elapsed = 0.0
	space_scale = 1.0
	paused = false
	state = State.READY
	for i in range(T.WALL_COUNT):
		append_wall()
	# A gentle first alignment teaches the wheel without an automatic free clear.
	walls[0].angle = -PI / 2.0 + T.WHEEL_STEP

func append_wall() -> void:
	var radius: float = T.INITIAL_RADIUS
	if not walls.is_empty():
		var last: float = walls[-1].radius
		radius = maxf(last + T.WALL_SPACING, last * 1.25 + 32.0)
	# Every generated gap must be reachable using whole-side wheel steps.
	walls.append({"radius": radius, "angle": wrapf(-PI / 2.0 + rng.randi_range(0, 5) * T.WHEEL_STEP, -PI, PI)})

func press() -> void:
	if paused:
		paused = false
		return
	if state == State.TITLE or state == State.OVER:
		reset()
	elif state == State.READY:
		launch_origin = dot
		state = State.LAUNCHING

func rotate(direction: float) -> void:
	if state == State.READY and not paused:
		walls[0].angle = wrapf(walls[0].angle + direction * T.WHEEL_STEP, -PI, PI)

func speed() -> float:
	return minf(T.INITIAL_SPEED + score * 0.65, T.MAX_SPEED)

func step(dt: float) -> void:
	# Bound simulation steps even when called directly by tests or after a slow frame.
	var remaining := dt
	while remaining > 0.000001:
		var part := minf(remaining, 1.0 / 120.0)
		_tick(part)
		remaining -= part

func _tick(dt: float) -> void:
	if paused or state == State.TITLE or state == State.OVER:
		return
	elapsed += dt
	var wall: Dictionary = walls[0]
	var old_radius: float = wall.radius
	for entry in walls:
		entry.radius = maxf(0.0, entry.radius - speed() * dt)
	var previous := dot
	if state == State.LAUNCHING:
		dot.y -= T.LAUNCH_SPEED * dt
	elif state == State.BOUNCING:
		dot = dot.move_toward(launch_origin, T.BOUNCE_SPEED * dt)
	var clearance := T.DOT_RADIUS + T.WALL_WIDTH / 2.0
	var hit := G.swept_hit(previous, dot, old_radius, wall.radius, wall.angle, clearance)
	if hit >= 0.0:
		if state == State.LAUNCHING:
			dot = previous.lerp(dot, maxf(0.0, hit - 0.001))
			# Move just inside the contact surface so recovery starts separated.
			dot.y += 0.05
			state = State.BOUNCING
			bounce_count += 1
		else:
			state = State.OVER
		return
	# A collapsed ring crushes even if its gap happens to face the dot.
	if wall.radius <= clearance:
		state = State.OVER
		return
	if state == State.LAUNCHING:
		var boundary: float = -G.point(wall.radius, wall.angle, -PI / 2.0).y
		if -dot.y > boundary + clearance + 2.0:
			cleared.append({"radius": wall.radius, "angle": wall.angle})
			walls.pop_front()
			score += 1
			state = State.READY
			append_wall()
			# Rebase the coordinate scale to prevent unbounded radii and float drift.
			# Relative positions and the common polygon center are preserved.
			var factor: float = T.INITIAL_RADIUS / walls[0].radius
			for entry in walls:
				entry.radius *= factor
			for entry in cleared:
				entry.radius *= factor
			dot *= factor
			launch_origin *= factor
			space_scale *= factor
	elif state == State.BOUNCING and dot.distance_to(launch_origin) < 0.01:
		state = State.READY

func pause() -> void:
	if state != State.TITLE and state != State.OVER:
		paused = true
