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
	game.reset(7)
	var initial_angle: float = game.walls[0].angle
	var outer_angle: float = game.walls[1].angle
	game.rotate(1)
	check(is_equal_approx(angle_difference(initial_angle, game.walls[0].angle), PI / 3.0), "one notch advances one hexagon side")
	game.rotate(-1)
	check(is_equal_approx(game.walls[0].angle, initial_angle), "opposite notch reverses one side")
	check(game.walls[1].angle == outer_angle, "wheel leaves outer walls unchanged")
	game.rotate(-1)
	game.press()
	game.press()
	for i in range(100):
		game.step(1.0 / 120.0)
		if game.score > 0:
			break
	check(game.score == 1, "aligned launch clears exactly one wall")
	check(game.state == Model.State.READY, "crossing returns control")
	check(game.cleared.size() == 1 and game.walls.size() == T.WALL_COUNT, "one break event and replenishment")
	check(game.dot.y < 0, "dot physically moved outward")
	game.reset(7)
	game.walls[0].angle = 0.0
	game.press()
	var initial: float = game.walls[0].radius
	for i in range(120):
		game.step(1.0 / 120.0)
	check(game.bounce_count == 1 and game.score == 0, "solid hit bounces without scoring")
	check(game.state == Model.State.READY and game.dot.is_equal_approx(Vector2.ZERO), "bounce returns to origin")
	check(game.walls[0].radius < initial, "shrinking continues during bounce")
	game.pause()
	var frozen: float = game.walls[0].radius
	game.step(5)
	check(game.walls[0].radius == frozen, "pause freezes pressure")
	game.press()
	check(not game.paused and game.state == Model.State.READY, "resume does not launch")
	game.step(20)
	check(game.state == Model.State.OVER, "waiting ends in crush")
	game.press()
	check(game.score == 0 and game.state == Model.State.READY and game.dot == Vector2.ZERO, "restart resets run")
	game.state = Model.State.BOUNCING
	game.dot = Vector2(0, -100)
	game.launch_origin = game.dot
	game.walls[0].radius = 101.0
	game.walls[0].angle = 0.0
	game.step(0.01)
	check(game.state == Model.State.OVER, "bounce is not immune to crushing")
	var endpoint: Vector2 = G.point(180.0, -PI / 2.0, -PI / 2.0 + T.GAP_ANGLE / 2.0)
	check(G.swept_hit(endpoint + Vector2(0, 40), endpoint - Vector2(0, 40), 180, 180, -PI / 2, 7.5) >= 0, "gap endpoint is solid")
	check(G.swept_hit(Vector2.ZERO, Vector2(0, -300), 180, 175, 0, 7.5) >= 0, "fast launch cannot tunnel through wall")
	check(G.swept_hit(Vector2.ZERO, Vector2(0, -300), 180, 175, -PI / 2, 7.5) < 0, "aligned swept path remains open")
	for fps in [30, 60, 120, 240]:
		game.reset(8)
		game.walls[0].angle = -PI / 2
		game.press()
		for i in range(fps):
			game.step(1.0 / fps)
		check(game.score == 1 and game.state == Model.State.READY, "consistent launch at %s FPS" % fps)
	game.reset(21)
	game.walls[0].angle = -PI / 2
	game.walls[0].radius = 16.0
	game.press()
	game.step(0.1)
	check(game.score == 0, "late launch through a gap narrower than the dot cannot score")
	# Long seeded progression exposes spacing, numeric, and generation failures.
	game.reset(12)
	for layer in range(100):
		var aligned := false
		for notch in range(6):
			if absf(angle_difference(game.walls[0].angle, -PI / 2)) < 0.0001:
				aligned = true
				break
			game.rotate(1)
		check(aligned, "generated gap is reachable in whole-side steps")
		game.press()
		for frame in range(10000):
			game.step(1.0 / 60)
			if game.state != Model.State.LAUNCHING:
				break
		check(game.score == layer + 1, "seeded layer %d is reachable" % layer)
		if game.state == Model.State.OVER or game.score != layer + 1:
			break
		for j in range(1, game.walls.size()):
			check(game.walls[j].radius * cos(PI / 6) > game.walls[j - 1].radius + 12, "nested walls remain separated")
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
