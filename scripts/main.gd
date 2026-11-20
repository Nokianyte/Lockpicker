extends Node2D

const Model = preload("res://scripts/run_model.gd")
const T = preload("res://scripts/tuning.gd")
const G = preload("res://scripts/wall_geometry.gd")
const INK := Color("e8f3ee")
const MINT := Color("9cfdc2")
const MUTED := Color("71848e")
const RED := Color("ff886e")
const GOLD := Color("ffd17e")
const CORE_BODY := [
	Vector2(0, -T.TIP_LENGTH), Vector2(23, -64), Vector2(40, -63),
	Vector2(70, -3), Vector2(38, 50), Vector2(-33, 50),
	Vector2(-69, -1), Vector2(-36, -61), Vector2(-22, -64),
]
var game = Model.new()
var font: Font = ThemeDB.fallback_font
var effects: Array = []
var clock := 0.0
var middle_down := false
var best := 0

func _ready() -> void:
	DisplayServer.window_set_title("Lockpicker")
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
				if game.state == Model.State.TITLE or game.state == Model.State.OVER:
					effects.clear()
				game.press()
				middle_down = true
			elif not event.pressed:
				middle_down = false
			get_viewport().set_input_as_handled()
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			game.rotate(-1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0)
			get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
	game.step(delta)
	best = maxi(best, game.score)
	for wall in game.cleared:
		for segment in G.segments(wall.radius, wall.angle):
			var mid: Vector2 = (segment[0] + segment[1]) / 2.0
			effects.append({"a": segment[0], "b": segment[1], "v": mid.normalized() * 70.0, "life": T.BREAK_TIME})
	game.cleared.clear()

func _process(delta: float) -> void:
	if OS.has_feature("web") and JavaScriptBridge.eval("window.lockpickerBlurred === true"):
		game.pause()
		middle_down = false
		JavaScriptBridge.eval("window.lockpickerBlurred=false;")
	clock += delta
	if not game.paused:
		for effect in effects:
			effect.life -= delta
			effect.a += effect.v * delta
			effect.b += effect.v * delta
		effects = effects.filter(func(effect): return effect.life > 0.0)
	queue_redraw()

func text(value: String, at: Vector2, size: int, color: Color = INK) -> void:
	draw_string(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func centered(value: String, y: float, size: int, color: Color = INK) -> void:
	text(value, Vector2((get_viewport_rect().size.x - font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x) / 2.0, y), size, color)

func draw_core(center: Vector2, zoom: float, aligned: bool) -> void:
	var rotation: float = game.tip_angle - T.TIP_ANGLE
	var points := PackedVector2Array()
	for point: Vector2 in CORE_BODY:
		points.append(center + point.rotated(rotation) * zoom)
	draw_colored_polygon(points, Color("362327"))
	var tip := points[0]
	var shoulder_a := points[1]
	var shoulder_b := points[-1]
	var tip_color := MINT if aligned else GOLD
	draw_colored_polygon(PackedVector2Array([tip, shoulder_a, shoulder_b]), Color(tip_color, 0.24))
	points.append(tip)
	draw_polyline(points, RED, 2.5, true)
	draw_polyline(PackedVector2Array([shoulder_b, tip, shoulder_a]), tip_color, 3.0, true)

func _draw() -> void:
	var size := get_viewport_rect().size
	var ui_scale := minf(size.x / 1100.0, size.y / 800.0)
	var zoom := 0.76 * ui_scale
	var origin := size * 0.5
	var active: Dictionary = game.walls[0]
	var aligned: bool = G.gap_accepts_tip(game.tip_angle, active.angle) and game.state != Model.State.OVER
	# Quiet graph-paper texture and corner registration marks.
	for x in range(24, int(size.x), 32):
		for y in range(24, int(size.y), 32):
			draw_circle(Vector2(x, y), 0.7, Color(0.22, 0.32, 0.36, 0.23))
	for i in range(game.walls.size() - 1, -1, -1):
		var wall: Dictionary = game.walls[i]
		var color := MINT if i == 0 else Color("344954").lerp(Color("162731"), float(i) / 5.0)
		if i == 0:
			if game.state == Model.State.OVER:
				color = RED
			elif game.boosting:
				color = GOLD
		for segment in G.segments(wall.radius, wall.angle):
			var a: Vector2 = origin + segment[0] * zoom
			var b: Vector2 = origin + segment[1] * zoom
			if i == 0:
				draw_line(a, b, Color(color, 0.06), 13.0, true)
			draw_line(a, b, color, T.WALL_WIDTH * zoom if i == 0 else 1.4, true)
		if i == 0:
			for angle in [wall.angle - T.GAP_ANGLE / 2.0, wall.angle + T.GAP_ANGLE / 2.0]:
				draw_circle(origin + G.point(wall.radius, wall.angle, angle) * zoom, 3.5, INK)
	for effect in effects:
		draw_line(origin + effect.a * zoom, origin + effect.b * zoom, Color(MINT, effect.life / T.BREAK_TIME), 2, true)
	draw_core(origin, zoom, aligned)
	var footer_y := size.y - 52
	# Keep outlines out of the HUD.
	draw_rect(Rect2(0, 0, size.x, 99), Color("06090f"))
	draw_line(Vector2(32, 98), Vector2(size.x - 32, 98), Color("23343e"), 1)
	text("L / P", Vector2(34, 48), 22, MINT)
	text("LOCKPICKER", Vector2(110, 49), 24)
	text("LAYERS CLEARED", Vector2(size.x - 184, 38), 11, MUTED)
	text("%02d" % game.score, Vector2(size.x - 184, 76), 34, MINT)
	text("BEST  %02d" % best, Vector2(size.x - 98, 71), 11, MUTED)
	draw_rect(Rect2(0, footer_y - 28, size.x, 80), Color("06090f"))
	draw_line(Vector2(32, footer_y - 28), Vector2(size.x - 32, footer_y - 28), Color("23343e"), 1)
	text("SCROLL  /  ROTATE TIP", Vector2(34, footer_y), 13, INK)
	text("PRESS WHEEL  /  SPEED UP INNER LAYER", Vector2(34, footer_y + 22), 13, GOLD if game.boosting else MUTED)
	if game.state == Model.State.PLAYING:
		var room: float = active.radius - G.tip_contact_radius(game.tip_angle, active.angle)
		var pressure := clampf(room / (T.INITIAL_RADIUS - T.TIP_LENGTH), 0.0, 1.0)
		draw_rect(Rect2(size.x - 39, 130, 3, size.y - 260), Color("23343e"))
		draw_rect(Rect2(size.x - 39, 130 + (1.0 - pressure) * (size.y - 260), 3, pressure * (size.y - 260)), MINT if pressure > 0.25 else RED)
	if game.state == Model.State.TITLE or game.state == Model.State.OVER or game.paused:
		draw_rect(Rect2(0, 100, size.x, size.y - 200), Color(0.025, 0.035, 0.06, 0.88))
		var title := "LINE UP THE TIP"
		var sub := "Scroll to point the tip into the gap before the inner layer reaches it."
		var action := "PRESS THE SCROLL WHEEL TO BEGIN"
		if game.state == Model.State.OVER:
			title = "MISSED THE GAP"
			sub = "Layers cleared: %d" % game.score
			action = "PRESS THE SCROLL WHEEL TO RESTART"
		if game.paused:
			title = "PAUSED"
			sub = ""
			action = "PRESS THE SCROLL WHEEL TO RESUME"
		centered(title, size.y * 0.46, int(42 * minf(1.0, size.x / 800.0)), INK)
		centered(sub, size.y * 0.46 + 37, 14, MUTED)
		centered(action, size.y * 0.62, 14, Color(MINT, 0.7 + sin(clock * 2) * 0.2))
