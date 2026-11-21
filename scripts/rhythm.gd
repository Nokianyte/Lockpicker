extends Node2D

const Run = preload("res://scripts/rhythm_run.gd")
const T = preload("res://scripts/tuning.gd")
const G = preload("res://scripts/wall_geometry.gd")

const PAPER := Color("#f9f8f4")
const INK := Color("#252325")
const MUTED := Color("#6d6667")
const RED := Color("#d8243d")
const SPIKE_INK := Color("#a84b24")

var game = Run.new()
var font := ThemeDB.fallback_font
var plain_click := AudioStreamPlayer.new()
var accent_click := AudioStreamPlayer.new()
var next_beat := -Run.COUNT_IN_BEATS
var clock_usec := 0
var effects: Array[Dictionary] = []

func _ready() -> void:
	plain_click.stream = _make_click(940.0, 0.24)
	accent_click.stream = _make_click(1470.0, 0.33)
	add_child(plain_click)
	add_child(accent_click)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.lockpickerBlurred=false;window.addEventListener('blur',()=>window.lockpickerBlurred=true);document.addEventListener('visibilitychange',()=>{if(document.hidden)window.lockpickerBlurred=true;});")

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_pause()

func _pause() -> void:
	if game.state == Run.State.PLAYING and not game.paused:
		game.paused = true
		plain_click.stop()
		accent_click.stop()
		next_beat = ceili(game.time / Run.BEAT_SECONDS)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode in [KEY_Z, KEY_X]:
		if event.pressed and not event.echo:
			_press()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_advance_clock()
		game.rotate(-1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0)
		get_viewport().set_input_as_handled()

func _press() -> void:
	if game.paused:
		game.paused = false
		clock_usec = Time.get_ticks_usec()
	elif game.state != Run.State.PLAYING:
		game.reset()
		effects.clear()
		next_beat = -Run.COUNT_IN_BEATS
		clock_usec = Time.get_ticks_usec()
		_play_due_beat()
	else:
		_advance_clock()
		game.tap()

func _process(_delta: float) -> void:
	if OS.has_feature("web") and JavaScriptBridge.eval("window.lockpickerBlurred === true"):
		_pause()
		JavaScriptBridge.eval("window.lockpickerBlurred=false;")
	_advance_clock()
	if game.state == Run.State.PLAYING and not game.paused:
		_play_due_beat()
	for wall in game.cleared:
		wall.time = game.time
		effects.append(wall)
	game.cleared.clear()
	effects = effects.filter(func(wall): return game.time - wall.time < T.BREAK_TIME)
	queue_redraw()

func _advance_clock() -> void:
	if game.state != Run.State.PLAYING or game.paused:
		return
	var now := Time.get_ticks_usec()
	game.advance((now - clock_usec) / 1000000.0)
	clock_usec = now

func _play_due_beat() -> void:
	# Trigger before the target to allow for the next audio mix and device output.
	var audio_lead := AudioServer.get_time_to_next_mix() + AudioServer.get_output_latency()
	var due := mini(floori((game.time + audio_lead) / Run.BEAT_SECONDS), Run.CHART_BEATS - 1)
	if due < next_beat:
		return
	next_beat = due + 1
	if posmod(due, 4) == 0:
		accent_click.play()
	else:
		plain_click.play()

func _make_click(frequency: float, volume: float) -> AudioStreamWAV:
	const RATE := 22050
	var samples := PackedByteArray()
	samples.resize(int(RATE * 0.045) * 2)
	for i in range(samples.size() / 2):
		var t := float(i) / RATE
		var envelope := minf(t / 0.001, 1.0) * exp(-t * 145.0)
		var sample := sin(TAU * frequency * t) * envelope * volume
		samples.encode_s16(i * 2, roundi(sample * 32767.0))
	var click := AudioStreamWAV.new()
	click.format = AudioStreamWAV.FORMAT_16_BITS
	click.mix_rate = RATE
	click.data = samples
	return click

func _draw_ring(origin: Vector2, zoom: float, radius: float, angle: float, color: Color, width: float) -> void:
	for segment in G.segments(radius, angle):
		draw_line(origin + segment[0] * zoom, origin + segment[1] * zoom, color, width, true)

func _draw_core(origin: Vector2, zoom: float) -> void:
	var points := PackedVector2Array()
	for i in range(6):
		var angle := T.TIP_ANGLE + PI / 6.0 + i * T.WHEEL_STEP
		points.append(origin + Vector2.from_angle(angle) * Run.CORE_RADIUS * zoom)
	var hit_feedback: bool = game.feedback.begins_with("PERFECT") or game.feedback.begins_with("GOOD")
	var flash := 0.0
	if hit_feedback:
		flash = maxf(0.0, 1.0 - (game.time - game.feedback_time) / 0.23)
	var fill := PAPER.lerp(RED, 0.06 + flash * 0.20)
	draw_colored_polygon(points, fill)
	points.append(points[0])
	draw_polyline(points, RED, 3.0 * zoom, true)
	_draw_marker(origin + Run.marker_center() * zoom, zoom, fill, RED)

func _draw_marker(center: Vector2, zoom: float, fill: Color, outline: Color) -> void:
	var radius := Run.MARKER_RADIUS * zoom
	draw_circle(center, radius, fill, true, -1.0, true)
	draw_arc(center, radius, 0.0, TAU, 40, outline, 2.5 * zoom, true)

func _draw_spike(index: int, origin: Vector2, zoom: float) -> void:
	var points: PackedVector2Array = game.spike_points(index)
	for vertex in range(points.size()):
		points[vertex] = origin + points[vertex] * zoom
	draw_colored_polygon(points, SPIKE_INK)

func _draw_text(value: String, at: Vector2, size: int, color: Color = INK) -> void:
	draw_string(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _centered(value: String, y: float, size: int, color: Color = INK) -> void:
	var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_draw_text(value, Vector2((get_viewport_rect().size.x - width) * 0.5, y), size, color)

func _draw() -> void:
	var size := get_viewport_rect().size
	var zoom := 0.79 * minf(size.x / 1100.0, size.y / 800.0)
	var origin := size * 0.5
	draw_rect(Rect2(Vector2.ZERO, size), PAPER)
	for i in range(mini(game.next_note + 3, Run.CHART.size()) - 1, game.next_note - 1, -1):
		var radius: float = game.radius(i)
		if radius > 420.0:
			continue
		var active: bool = i == game.next_note
		var angle: float = game.gap_angle(i)
		var is_spike: bool = game.is_spike(i)
		var color := INK if active else MUTED
		if active and game.is_aligned(i) and not is_spike:
			color = RED
		_draw_ring(origin, zoom, radius, angle, color, (3.2 if active else 2.2) * zoom)
		if is_spike:
			if not active or game.state != Run.State.CRASHED:
				_draw_spike(i, origin, zoom)
			continue
		var marker := origin + G.point(radius, angle, angle) * zoom
		if active:
			var pulse := 1.0 - clampf(absf(game.hit_time(i) - game.time) / 0.18, 0.0, 1.0)
			draw_circle(marker, (Run.MARKER_RADIUS + 6.0 * pulse) * zoom, Color(color, 0.22 * pulse), true, -1.0, true)
		_draw_marker(marker, zoom, PAPER, color)
	for wall in effects:
		var age: float = game.time - wall.time
		var color := Color(RED, 1.0 - age / T.BREAK_TIME)
		for segment in G.segments(wall.radius, wall.angle):
			var mid: Vector2 = (segment[0] + segment[1]) * 0.5
			var offset := mid.normalized() * age * 95.0
			draw_line(origin + (segment[0] + offset) * zoom, origin + (segment[1] + offset) * zoom, color, 2.0 * zoom, true)
	_draw_core(origin, zoom)
	if game.state == Run.State.CRASHED:
		_draw_spike(game.next_note, origin, zoom)
	_draw_ui(size)

func _draw_ui(size: Vector2) -> void:
	_draw_text("LOCKPICKER", Vector2(32, 51), 25)
	_draw_text("SCORE  %04d" % game.score, Vector2(size.x - 178, 36), 17)
	_draw_text("COMBO  %d" % game.combo, Vector2(size.x - 178, 60), 17, RED)
	_centered("Scroll to align circles or dodge spikes   ·   Tap Z or X on beat", size.y - 32, 17, MUTED)
	if game.state == Run.State.TITLE:
		_centered("Press Z or X to start  ·  100 BPM", size.y - 85, 24)
	elif game.state == Run.State.CRASHED:
		_centered("Spike hit  ·  Press Z or X to retry", size.y - 83, 24, RED)
	elif game.paused or game.state == Run.State.RESULTS:
		_draw_overlay(size)
	elif game.time < 0.0:
		_centered(str(ceili(-game.time / Run.BEAT_SECONDS)), size.y - 83, 34, RED)
	elif game.time - game.feedback_time < 0.50:
		_centered(game.feedback, size.y - 81, 24, RED)

func _draw_overlay(size: Vector2) -> void:
	draw_rect(Rect2(Vector2(0, 83), Vector2(size.x, size.y - 156)), Color(PAPER, 0.94))
	if game.paused:
		_centered("Paused", size.y * 0.46, 43)
		_centered("Press Z or X to resume", size.y * 0.55, 20)
	else:
		_centered("Chart complete", size.y * 0.40, 43)
		_centered("%d Perfect  ·  %d Good  ·  %d Miss" % [game.perfect_hits, game.good_hits, game.misses], size.y * 0.49, 20)
		_centered("Best combo  %d" % game.best_combo, size.y * 0.54, 20, MUTED)
		_centered("Press Z or X to replay", size.y * 0.63, 20)
