extends SceneTree

const Model = preload("res://scripts/run_model.gd")
const G = preload("res://scripts/wall_geometry.gd")
const T = preload("res://scripts/tuning.gd")
var failures := 0
var checks := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func _initialize() -> void:
	var game = Model.new()
	game.press()
	check(game.state == Model.State.PLAYING and not game.boosting, "start click does not boost")
	game.reset(7)
	var initial_gap: float = game.walls[0].angle
	game.rotate(1)
	game.step(T.TURN_DURATION / 2.0)
	check(is_equal_approx(game.tip_angle, T.TIP_ANGLE + T.WHEEL_STEP / 2.0), "tip animates between sides")
	game.step(T.TURN_DURATION)
	check(is_equal_approx(game.tip_angle, initial_gap), "one step aims at the adjacent opening")
	check(game.walls[0].angle == initial_gap, "wheel keeps ring orientation fixed")
	var inner_before: float = game.walls[0].radius
	var outer_before: float = game.walls[1].radius
	game.press()
	game.step(1.0 / 120.0)
	check(is_equal_approx(inner_before - game.walls[0].radius, T.DROP_SPEED / 120.0), "one press accelerates the active ring")
	check(is_equal_approx(outer_before - game.walls[1].radius, game.speed() / 120.0), "outer ring keeps normal speed")
	game.step(0.13)
	check(game.score == 1 and not game.boosting, "one press carries through contact and consumes the boost")
	inner_before = game.walls[0].radius
	game.step(0.1)
	check(is_equal_approx(inner_before - game.walls[0].radius, game.speed() * 0.1), "the next ring starts at normal speed")
	game.reset(7)
	game.rotate(1)
	game.press()
	game.pause()
	inner_before = game.walls[0].radius
	game.step(1)
	check(game.walls[0].radius == inner_before and not game.boosting, "pause freezes rings and clears boost")
	game.press()
	check(not game.paused and not game.boosting, "resume does not boost")
	game.step(1.8)
	check(game.score == 1 and game.cleared.size() == 1 and game.state == Model.State.PLAYING, "aligned contact clears a ring without pressing")
	game.reset(7)
	game.step(8)
	check(game.score == 0 and game.state == Model.State.OVER, "solid contact ends the run without points")
	game.press()
	check(game.score == 0 and game.state == Model.State.PLAYING and game.tip_angle == T.TIP_ANGLE and not game.boosting, "restart restores the initial position and speed")
	check(not G.gap_accepts_tip(T.TIP_ANGLE + T.GAP_ANGLE / 2.0, T.TIP_ANGLE), "gap edge does not clear")
	game.reset(7)
	game.walls.resize(1)
	game.walls[0].angle = T.TIP_ANGLE
	game.walls[0].radius = T.OUTER_RADIUS
	game.press()
	game.step(0.13)
	check(game.score == 1 and game.cleared.size() == 1, "even the farthest possible aligned drop clears within 130 ms")

	# The turn must be sampled when contact happens, even mid-animation.
	game.reset(7)
	game.walls[0].radius = G.tip_contact_radius(game.tip_angle, initial_gap) + 0.02
	game.rotate(1)
	game.press()
	game.step(0.5)
	check(game.state == Model.State.OVER and game.score == 0, "a late turn cannot retroactively clear a ring")
	game.reset(7)
	game.walls[0].angle = T.TIP_ANGLE + T.WHEEL_STEP
	game.walls[0].radius = T.TIP_LENGTH / cos(PI / 6.0) - 0.2
	game.rotate(1)
	game.step(0.01)
	check(game.state == Model.State.OVER, "contact at start of tick resolves before rotation moves away")

	for boosted in [false, true]:
		game.reset(17)
		for layer in range(100):
			var angle_delta: float = angle_difference(game.tip_angle, game.walls[0].angle)
			var notches := roundi(angle_delta / T.WHEEL_STEP)
			for i in range(absi(notches)):
				game.rotate(signf(notches))
			if boosted:
				game.step(T.TURN_DURATION)
				game.press()
			for frame in range(1200):
				game.step(1.0 / 30.0 if boosted else 1.0 / 120.0)
				if game.score != layer or game.state == Model.State.OVER:
					break
			check(game.score == layer + 1, "seeded ring %d is reachable (boosted: %s)" % [layer, boosted])
			if game.score != layer + 1:
				break
			check(not game.walls.is_empty() and game.walls[-1].radius <= T.OUTER_RADIUS, "refill is bounded")
			for j in range(1, game.walls.size()):
				check(game.walls[j].radius - game.walls[j - 1].radius >= T.WALL_SPACING - 0.01, "rings remain separated")
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
