extends Control

const Chart = preload("res://scripts/song_chart.gd")
const Art = preload("res://scripts/arena_art.gd")
const G = preload("res://scripts/wall_geometry.gd")
const Palette = preload("res://scripts/palette.gd")
const T = preload("res://scripts/tuning.gd")
const Session = preload("res://scripts/song_session.gd")

var events: Array[Dictionary] = []
var approach_horizon := Chart.DEFAULT_APPROACH
var center_rotation_track: Array[Dictionary] = []
var song_time := 0.0
var session: Session
var _grid := PackedVector2Array()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
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
	var zoom := minf(size.x, size.y) / (T.OUTER_RADIUS * 2.24)
	if zoom <= 0.0:
		return
	if not _grid.is_empty():
		draw_multiline(_grid, Palette.BORDER)
	var schedule := session.events if session != null else events
	var at := session.time if session != null else song_time
	var rotation := Chart.center_rotation_at(center_rotation_track, at)
	var target_angle := session.center_angle(at) if session != null else T.TIP_ANGLE
	# Draw in the same center-relative frame that judging uses.
	draw_set_transform(size * 0.5, rotation)
	_draw_core(zoom, target_angle)
	var first := Session.first_event_at(schedule, at - Session.HIT_WINDOW)
	# The hexagon's nearest edge can reach a corner before any of its vertices enter view.
	var marker_margin := maxf(8.0, T.SONG_MARKER_RADIUS * 1.35 * zoom) + 2.0
	var visible_radius := (size.length() * 0.5 + marker_margin) / (zoom * cos(PI / 6.0))
	var visible_horizon := (visible_radius - T.SONG_CORE_RADIUS) / Chart.MIN_APPROACH_SPEED
	var stop := Session.first_event_at(schedule, at + minf(approach_horizon, visible_horizon))
	for index in range(stop - 1, first - 1, -1):
		if session != null and session.resolved[index]:
			continue
		var event := schedule[index]
		var remaining := float(event.time) - at
		if event.spike and remaining < 0.0:
			continue
		var approach := Chart.remaining_approach(event, at)
		if approach >= 1.0:
			continue
		var motion: Dictionary = event.get("motion", {})
		var radius := lerpf(T.SONG_CORE_RADIUS, motion.get("spawn_radius", T.OUTER_RADIUS), approach)
		if radius > visible_radius:
			continue
		var angle := Chart.approach_angle(event, approach)
		if session != null:
			angle += session.turn_offset(index, at)
		var marker := G.song_marker(radius, angle) * zoom
		var visibility := lerpf(1.0, 0.29, approach)
		if event.spike:
			Art.ring(self, Vector2.ZERO, zoom, radius, angle, Color(Palette.SPIKE, visibility * 0.33), 1.0)
			Art.spiky_circle(self, marker, T.SONG_MARKER_RADIUS * zoom, angle, Color(Palette.SPIKE, visibility))
		else:
			var aligned := absf(remaining) <= Session.HIT_WINDOW and G.gap_accepts_tip(target_angle, angle)
			var ink := Color(Palette.RED if aligned else Palette.INK, visibility)
			var width := lerpf(2.3, 1.0, approach)
			Art.ring(self, Vector2.ZERO, zoom, radius, angle, ink, width)
			if event.has("slider_direction"):
				var axis := Vector2(event.slider_direction, 0).rotated(-rotation)
				Art.slider_marker(self, marker, maxf(5.5, T.SONG_MARKER_RADIUS * zoom), axis, ink, width)
			else:
				draw_arc(marker, T.SONG_MARKER_RADIUS * zoom, 0.0, TAU, 24, ink, width, true)
	var marker := G.song_marker(T.SONG_CORE_RADIUS, target_angle) * zoom
	draw_circle(marker, T.SONG_MARKER_RADIUS * zoom, Palette.RED_WASH, true, -1.0, true)
	draw_arc(marker, T.SONG_MARKER_RADIUS * zoom, 0.0, TAU, 24, Palette.RED, 2.0, true)
	if session != null:
		var age := (at - session.last_hit_at) / T.BREAK_TIME
		if age >= 0.0 and age < 1.0:
			draw_arc(marker, lerpf(5.0, 22.0, age), 0.0, TAU, 24, Color(Palette.RED, 1.0 - age), 1.6, true)

func _draw_core(zoom: float, target_angle: float) -> void:
	var points := PackedVector2Array()
	for side in 6:
		var vertex := target_angle + PI / 6.0 + side * T.WHEEL_STEP
		points.append(Vector2.from_angle(vertex) * T.SONG_CORE_RADIUS * zoom)
	draw_colored_polygon(points, Palette.RED_WASH)
	points.append(points[0])
	draw_polyline(points, Palette.RED, 2.5, true)
