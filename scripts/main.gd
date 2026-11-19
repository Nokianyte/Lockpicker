extends Node2D

const Model = preload("res://scripts/run_model.gd")
const T = preload("res://scripts/tuning.gd")
const G = preload("res://scripts/wall_geometry.gd")
const INK := Color("e8f3ee")
const MINT := Color("9cfdc2")
const MUTED := Color("71848e")
const RED := Color("ff886e")
var game = Model.new()
var font: Font = ThemeDB.fallback_font
var effects: Array = []
var trail: Array[Vector2] = []
var camera_dot := Vector2.ZERO
var clock := 0.0
var last_bounces := 0
var hit_flash := 0.0
var middle_down := false
var best := 0
var visual_zoom := 1.0

func _ready() -> void:
	DisplayServer.window_set_title("LOCKPICKER — Scroll. Align. Escape.")
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.lockpickerBlurred=false;window.addEventListener('blur',()=>window.lockpickerBlurred=true);document.addEventListener('visibilitychange',()=>{if(document.hidden)window.lockpickerBlurred=true;});")

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		game.pause()
		middle_down = false

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed and not middle_down:
				game.press()
				if game.score == 0 and game.elapsed == 0:
					effects.clear()
					trail.clear()
					camera_dot = Vector2.ZERO
					visual_zoom = 1.0
					last_bounces = 0
					hit_flash = 0.0
				middle_down = true
			elif not event.pressed:
				middle_down = false
			get_viewport().set_input_as_handled()
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			game.rotate(-1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0)
			get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
	game.step(delta)
	if game.space_scale != 1.0:
		var factor: float = game.space_scale
		camera_dot *= factor
		for i in range(trail.size()):
			trail[i] *= factor
		for effect in effects:
			effect.a *= factor
			effect.b *= factor
		visual_zoom /= factor
		game.space_scale = 1.0
	best = maxi(best, game.score)
	for wall in game.cleared:
		for segment in G.segments(wall.radius, wall.angle):
			var mid: Vector2 = (segment[0] + segment[1]) / 2.0
			effects.append({"a": segment[0], "b": segment[1], "v": mid.normalized() * 70.0, "life": T.BREAK_TIME})
	game.cleared.clear()
	if game.bounce_count != last_bounces:
		hit_flash = 0.3
		last_bounces = game.bounce_count

func _process(delta: float) -> void:
	if OS.has_feature("web") and JavaScriptBridge.eval("window.lockpickerBlurred === true"):
		game.pause()
		middle_down = false
		JavaScriptBridge.eval("window.lockpickerBlurred=false;")
	clock += delta
	visual_zoom = lerpf(visual_zoom, 1.0, 1.0 - exp(-delta * 7.0))
	camera_dot = camera_dot.lerp(game.dot, 1.0 - exp(-delta * 9.0))
	if not game.paused:
		hit_flash = maxf(0.0, hit_flash - delta)
		for effect in effects:
			effect.life -= delta
			effect.a += effect.v * delta
			effect.b += effect.v * delta
		effects = effects.filter(func(effect): return effect.life > 0.0)
		trail.append(game.dot)
		if trail.size() > 12:
			trail.pop_front()
	queue_redraw()

func text(value: String, at: Vector2, size: int, color: Color = INK) -> void:
	draw_string(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func centered(value: String, y: float, size: int, color: Color = INK) -> void:
	text(value, Vector2((get_viewport_rect().size.x - font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x) / 2.0, y), size, color)

func _draw() -> void:
	var size := get_viewport_rect().size
	var center := size * Vector2(0.5, 0.56)
	var ui_scale := minf(size.x / 1100.0, size.y / 800.0)
	var radius: float = game.walls[0].radius
	var zoom := minf(1.0, 280.0 / maxf(radius, 1.0)) * ui_scale * visual_zoom
	var origin := center - camera_dot * zoom * 0.75
	# Quiet graph-paper texture and corner registration marks.
	for x in range(24, int(size.x), 32):
		for y in range(24, int(size.y), 32):
			draw_circle(Vector2(x, y), 0.7, Color(0.22, 0.32, 0.36, 0.23))
	for i in range(game.walls.size() - 1, -1, -1):
		var wall: Dictionary = game.walls[i]
		var color := MINT if i == 0 else Color("344954").lerp(Color("162731"), float(i) / 5.0)
		if i == 0 and hit_flash > 0.0:
			color = RED
		for segment in G.segments(wall.radius, wall.angle):
			var a: Vector2 = origin + segment[0] * zoom
			var b: Vector2 = origin + segment[1] * zoom
			if i == 0:
				draw_line(a, b, Color(color, 0.06), 13.0, true)
			draw_line(a, b, color, 2.5 if i == 0 else 1.4, true)
		if i == 0:
			for angle in [wall.angle - T.GAP_ANGLE / 2.0, wall.angle + T.GAP_ANGLE / 2.0]:
				draw_circle(origin + G.point(wall.radius, wall.angle, angle) * zoom, 3.5, INK)
	for effect in effects:
		draw_line(origin + effect.a * zoom, origin + effect.b * zoom, Color(MINT, effect.life / T.BREAK_TIME), 2, true)
	var dot_screen: Vector2 = origin + game.dot * zoom
	if game.state == Model.State.READY:
		for i in range(5):
			var y := dot_screen.y - 20.0 - i * 11.0
			draw_line(Vector2(dot_screen.x, y), Vector2(dot_screen.x, y - 4), Color(MINT, 0.5 - i * 0.07), 1.5)
		draw_polyline(PackedVector2Array([dot_screen + Vector2(-4, -70), dot_screen + Vector2(0, -75), dot_screen + Vector2(4, -70)]), MINT, 1.5, true)
	for i in range(trail.size()):
		draw_circle(origin + trail[i] * zoom, maxf(2.0, T.DOT_RADIUS * zoom) * float(i) / 12.0, Color(MINT, float(i) / 48.0))
	draw_circle(dot_screen, 15, Color(MINT if game.state != Model.State.OVER else RED, 0.08))
	draw_circle(dot_screen, maxf(4.0, T.DOT_RADIUS * zoom), INK if game.state != Model.State.OVER else RED)
	var footer_y := size.y - 52
	# Keep polygon outlines out of the reading areas as the camera moves.
	draw_rect(Rect2(0, 0, size.x, 99), Color("06090f"))
	draw_line(Vector2(32, 98), Vector2(size.x - 32, 98), Color("23343e"), 1)
	text("L / P", Vector2(34, 48), 22, MINT)
	text("LOCKPICKER", Vector2(110, 49), 24)
	text("AN ENDLESS ESCAPE", Vector2(111, 72), 11, MUTED)
	text("LAYERS CLEARED", Vector2(size.x - 184, 38), 11, MUTED)
	text("%02d" % game.score, Vector2(size.x - 184, 76), 34, MINT)
	text("BEST  %02d" % best, Vector2(size.x - 98, 71), 11, MUTED)
	draw_rect(Rect2(0, footer_y - 28, size.x, 80), Color("06090f"))
	draw_line(Vector2(32, footer_y - 28), Vector2(size.x - 32, footer_y - 28), Color("23343e"), 1)
	text("SCROLL  /  ROTATE", Vector2(34, footer_y), 13, INK)
	text("PRESS WHEEL  /  LAUNCH", Vector2(34, footer_y + 22), 13, MUTED)
	text("ALIGN. ESCAPE. REPEAT.", Vector2(size.x - 215, footer_y), 12, MUTED)
	text("THE WALLS WON'T WAIT.", Vector2(size.x - 215, footer_y + 22), 12, MINT)
	if game.state == Model.State.READY or game.state == Model.State.BOUNCING or game.state == Model.State.LAUNCHING:
		var boundary: float = -G.point(radius, game.walls[0].angle, -PI / 2.0).y
		var room := maxf(0.0, boundary + game.dot.y - T.DOT_RADIUS)
		var pressure := clampf(room / 160.0, 0.0, 1.0)
		draw_rect(Rect2(size.x - 39, 130, 3, size.y - 260), Color("23343e"))
		draw_rect(Rect2(size.x - 39, 130 + (1.0 - pressure) * (size.y - 260), 3, pressure * (size.y - 260)), MINT if pressure > 0.25 else RED)
	if game.state == Model.State.TITLE or game.state == Model.State.OVER or game.paused:
		draw_rect(Rect2(0, 100, size.x, size.y - 200), Color(0.025, 0.035, 0.06, 0.88))
		var title := "FIND YOUR OPENING."
		var sub := "Rotate the polygon. Send the dot through. Stay ahead of the walls."
		var action := "PRESS THE SCROLL WHEEL TO BEGIN"
		if game.state == Model.State.OVER:
			title = "CRUSHED."
			sub = "%d LAYERS CLEARED  /  ONE MORE TRY?" % game.score
			action = "PRESS THE SCROLL WHEEL TO RESTART"
		if game.paused:
			title = "TAKE A BREATH."
			sub = "The walls are waiting for you."
			action = "PRESS THE SCROLL WHEEL TO RESUME"
		centered("01  /  LOCKPICKER", size.y * 0.36, 13, MINT)
		centered(title, size.y * 0.46, int(42 * minf(1.0, size.x / 800.0)), INK)
		centered(sub, size.y * 0.46 + 37, 14, MUTED)
		centered(action, size.y * 0.62, 14, Color(MINT, 0.7 + sin(clock * 2) * 0.2))
