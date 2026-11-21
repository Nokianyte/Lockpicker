extends SceneTree

const Model = preload("res://scripts/run_model.gd")
const Rhythm = preload("res://scripts/rhythm_run.gd")
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
	check(is_equal_approx(outer_before - game.walls[1].radius, game.shrink_speed / 120.0), "outer ring keeps normal speed")
	game.step(0.13)
	check(game.score == 1 and not game.boosting, "one press carries through contact and consumes the boost")
	inner_before = game.walls[0].radius
	game.step(0.1)
	check(is_equal_approx(inner_before - game.walls[0].radius, game.shrink_speed * 0.1), "the next ring starts at normal speed")
	game.walls[0].angle = game.tip_angle + T.WHEEL_STEP
	game.step(5.0)
	check(game.state == Model.State.PLAYING, "an early drop leaves about five seconds to aim at the next gap")
	game.step(0.5)
	check(game.state == Model.State.OVER and game.score == 1, "the second layer brings back the pressure after the opening")
	game.reset(7)
	game.rotate(1)
	game.press()
	game.pause()
	inner_before = game.walls[0].radius
	game.step(1)
	check(game.walls[0].radius == inner_before and not game.boosting, "pause freezes rings and clears boost")
	game.press()
	check(not game.paused and not game.boosting, "resume does not boost")
	game.step(13.3)
	check(game.score == 1 and game.cleared.size() == 1 and game.state == Model.State.PLAYING, "aligned contact clears a ring without pressing")
	game.reset(7)
	game.step(13.0)
	check(game.state == Model.State.PLAYING, "the opening gives about thirteen seconds like the dot version")
	game.step(0.3)
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
			for frame in range(1800):
				game.step(1.0 / 30.0 if boosted else 1.0 / 120.0)
				if game.score != layer or game.state == Model.State.OVER:
					break
			check(game.score == layer + 1, "seeded ring %d is reachable (boosted: %s)" % [layer, boosted])
			if game.score != layer + 1:
				break
			check(not game.walls.is_empty() and game.walls[-1].radius <= T.OUTER_RADIUS, "refill is bounded")
			for j in range(1, game.walls.size()):
				check(game.walls[j].radius - game.walls[j - 1].radius >= T.WALL_SPACING - 0.01, "rings remain separated")
	_check_rhythm()
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

func _check_rhythm() -> void:
	var game = Rhythm.new()
	game.reset()
	check(is_equal_approx(game.time, -1.2), "rhythm starts on a two-beat count-in")
	var start_radius: float = game.radius(0)
	var initial_gap: float = game.gap_angle(0)
	var outer_gap: float = game.gap_angle(1)
	game.rotate(1)
	game.advance(T.TURN_DURATION / 2.0)
	check(is_equal_approx(game.gap_angle(0), initial_gap + T.WHEEL_STEP / 2.0), "only the active ring eases through the wheel turn")
	check(is_equal_approx(game.gap_angle(1), outer_gap), "the outer ring keeps its charted angle")
	game.advance(1.12 - T.TURN_DURATION / 2.0)
	check(game.radius(0) < start_radius, "the first ring approaches on the chart clock")
	check(is_equal_approx(game.gap_angle(0), T.TIP_ANGLE), "one notch moves the first gap to the fixed tip")
	game.tap()
	check(game.good_hits == 1 and game.combo == 1 and game.score == 50, "an aligned 80 ms early tap is Good")
	check(game.feedback == "GOOD · EARLY", "Good reports which side of the beat the tap landed on")
	check(is_equal_approx(game.gap_angle(1), outer_gap), "a hit hands off to the next ring without rotating it")
	var second_hit: float = game.hit_time(1)
	game.advance(0.08)
	game.tap()
	check(game.next_note == 1 and game.score == 50, "an off-beat press cannot clear the following ring")
	game.advance(second_hit - game.time)
	check(is_equal_approx(game.radius(1), Rhythm.CORE_RADIUS), "the outer hexagon reaches the core size at its scheduled beat")
	game.tap()
	check(game.misses == 1 and game.combo == 0 and game.next_note == 2, "an on-beat misaligned tap misses only its ring")

	game.reset()
	game.rotate(1)
	game.advance(1.33)
	check(game.misses == 1 and game.next_note == 1 and game.state == Rhythm.State.PLAYING, "alignment alone misses, and the chart keeps playing")
	game.rotate(-1)
	game.paused = true
	var paused_time: float = game.time
	var paused_angle: float = game.gap_angle(1)
	game.advance(1.0)
	game.tap()
	check(game.time == paused_time and game.gap_angle(1) == paused_angle and game.next_note == 1, "pause freezes timing, rotation, and judgment")
	game.paused = false
	game.advance(1.24 - game.time)
	game.tap()
	check(game.perfect_hits == 1 and game.score == 100, "an aligned 40 ms late tap is Perfect after resume")
	game.advance(20)
	check(game.state == Rhythm.State.CRASHED and game.is_spike(game.next_note), "a spike ends the run without a tap, even across a long frame")
	check(game.time < game.hit_time(game.next_note), "the triangle's point hits before its base reaches the red circle")
	check(is_equal_approx(game.time, game.hit_time(game.next_note) - (Rhythm.MARKER_RADIUS + Rhythm.SPIKE_DEPTH) / (Rhythm.APPROACH_SPEED * cos(PI / 6.0))), "collision freezes at first circle contact")
	var crash_time: float = game.time
	game.advance(1.0)
	check(game.time == crash_time and game.score == 100, "a crash freezes time and preserves the run score")
	game.reset()
	check(game.score == 0 and game.best_combo == 0 and game.next_note == 0 and game.cleared.is_empty(), "replay resets rhythm results and effects")

	game.advance(1.28)
	game.rotate(1)
	game.advance(0.04)
	game.advance(T.TURN_DURATION)
	check(game.next_note == 1 and is_equal_approx(game.gap_angle(1), outer_gap), "an expired ring's in-progress turn is discarded")

	game.reset()
	game.advance(3.8)
	game.rotate(1)
	game.advance(0.75)
	check(game.state == Rhythm.State.PLAYING and game.is_spike(game.next_note), "a spike beside the marker stays safe while it approaches")
	game.rotate(-1)
	game.advance(0.25)
	check(game.state == Rhythm.State.CRASHED and not is_zero_approx(game.ring_rotation), "turning into the circle can collide before the turn finishes")

	game.reset()
	for i in range(Rhythm.CHART.size()):
		if game.is_spike(i):
			var prior_score: int = game.score
			var prior_combo: int = game.combo
			game.tap()
			check(game.next_note == i and game.score == prior_score, "a tap cannot clear a fake note")
			game.rotate(1)
			game.advance(game.hit_time(i) + Rhythm.SPIKE_PASS_WINDOW + 0.001 - game.time)
			check(game.next_note == i + 1 and game.combo == prior_combo, "dodging a spike preserves the combo")
			continue
		var gap: float = game.gap_angle(i)
		var steps := roundi(angle_difference(gap, T.TIP_ANGLE) / T.WHEEL_STEP)
		check(absi(steps) <= 1, "each prototype ring needs at most one notch to reach the fixed tip")
		if steps != 0:
			game.rotate(steps)
		game.advance(game.hit_time(i) - game.time)
		check(G.point(game.radius(i), game.gap_angle(i), game.gap_angle(i)).is_equal_approx(Rhythm.marker_center()), "the circles share a center at the exact beat")
		game.tap()
	game.advance(1.0)
	var playable_notes: int = Rhythm.CHART.size() - Rhythm.SPIKE_BEATS.size()
	check(game.state == Rhythm.State.RESULTS and game.misses == 0, "the chart finishes with zero misses after all spikes are dodged")
	check(game.perfect_hits == playable_notes and game.best_combo == playable_notes, "all real notes can be hit in one combo")
