extends Control

const Chart = preload("res://scripts/song_chart.gd")
const Art = preload("res://scripts/arena_art.gd")
const G = preload("res://scripts/wall_geometry.gd")
const T = preload("res://scripts/tuning.gd")
const Session = preload("res://scripts/song_session.gd")
const CORE_RADIUS := 100.0
const MARKER_RADIUS := 11.0
const SPIKE_DEPTH := 18.0
const SPIKE_CONTACT_RADIUS := CORE_RADIUS + (MARKER_RADIUS + SPIKE_DEPTH) / cos(PI / 6.0)

var events: Array[Dictionary] = []
var resolved := PackedByteArray()
var song_time := 0.0
var heading := T.TIP_ANGLE
var last_hit: Dictionary = {}
var _grid := PackedVector2Array()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_build_grid)
	_build_grid()

func _build_grid() -> void:
	_grid.clear()
	for x in range(16, int(size.x), 24):
		for y in range(16, int(size.y), 24):
			_grid.append(Vector2(x, y))
			_grid.append(Vector2(x + 1, y))
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	var zoom := minf(size.x, size.y) / (T.OUTER_RADIUS * 2.24)
	if zoom <= 0.0:
		return
	if not _grid.is_empty():
		draw_multiline(_grid, Color("243740"))
	_draw_core(center, zoom)
	var first := Session.first_event_at(events, song_time - Session.HIT_WINDOW)
	var stop := Session.first_event_at(events, song_time + Session.APPROACH)
	var aligned := false
	for index in range(stop - 1, first - 1, -1):
		if index < resolved.size() and resolved[index]:
			continue
		var event := events[index]
		var remaining := float(event.time) - song_time
		if event.spike and remaining < 0.0:
			continue
		var angle := Chart.direction_angle(event.lane)
		var approach := clampf(remaining / Session.APPROACH, 0.0, 1.0)
		var arrival_radius := SPIKE_CONTACT_RADIUS if event.spike else CORE_RADIUS
		var radius := lerpf(arrival_radius, T.OUTER_RADIUS, approach)
		var visibility := lerpf(1.0, 0.29, approach)
		if event.spike:
			Art.ring(self, center, zoom, radius, angle, Color(Art.RED, visibility * 0.33), 1.0)
			_draw_spike(center, zoom, radius, angle, Color(Art.RED, visibility))
		else:
			var ink := Color(Art.MINT, visibility)
			var width := lerpf(2.3, 1.0, approach)
			Art.ring(self, center, zoom, radius, angle, ink, width)
			var marker := center + G.point(radius, angle, angle) * zoom
			draw_arc(marker, MARKER_RADIUS * zoom, 0.0, TAU, 24, ink, width, true)
			if absf(remaining) <= Session.HIT_WINDOW and G.gap_accepts_tip(heading, angle):
				aligned = true
	var aim := center + G.point(CORE_RADIUS, T.TIP_ANGLE, heading) * zoom
	var aim_ink := Art.MINT if aligned else Art.GOLD
	draw_circle(aim, MARKER_RADIUS * zoom, Color(aim_ink, 0.24), true, -1.0, true)
	draw_arc(aim, MARKER_RADIUS * zoom, 0.0, TAU, 24, aim_ink, 2.0, true)
	if not last_hit.is_empty():
		var age := (song_time - float(last_hit.at)) / T.BREAK_TIME
		if age >= 0.0 and age < 1.0:
			var angle := Chart.direction_angle(last_hit.lane)
			var point := center + G.point(CORE_RADIUS, T.TIP_ANGLE, angle) * zoom
			draw_arc(point, lerpf(5.0, 22.0, age), 0.0, TAU, 24, Color(Art.MINT, 1.0 - age), 1.6, true)

func _draw_core(center: Vector2, zoom: float) -> void:
	var points := PackedVector2Array()
	for side in 6:
		var vertex := T.TIP_ANGLE + PI / 6.0 + side * T.WHEEL_STEP
		points.append(center + Vector2.from_angle(vertex) * CORE_RADIUS * zoom)
	draw_colored_polygon(points, Color("362327"))
	points.append(points[0])
	draw_polyline(points, Art.RED, 2.5, true)

func _draw_spike(center: Vector2, zoom: float, radius: float, angle: float, ink: Color) -> void:
	var half_gap := T.GAP_ANGLE * 0.5
	var tip := G.point(radius, angle, angle) - Vector2.from_angle(angle) * SPIKE_DEPTH
	draw_colored_polygon(PackedVector2Array([
		center + G.point(radius, angle, angle - half_gap) * zoom,
		center + tip * zoom,
		center + G.point(radius, angle, angle + half_gap) * zoom,
	]), ink)
