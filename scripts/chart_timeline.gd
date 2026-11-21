extends Control

signal sought(time: float)
signal placed(beat: float, lane: int, spike: bool, slider_direction: int)
signal removed(index: int)
signal moved(index: int, beat: float, lane: int)
signal selected(index: int)
signal zone_selected(index: int)
signal zone_moved(index: int, beat: float)

const Chart = preload("res://scripts/song_chart.gd")
const Art = preload("res://scripts/arena_art.gd")
const Palette = preload("res://scripts/palette.gd")
const LEFT := 59.0
const RULER := 36.0
const RIGHT := 12.0
const BOTTOM := 16.0
const ZONE_HANDLE_Y := 30.0

enum Placement { NOTE, SPIKE, SLIDER_LEFT, SLIDER_RIGHT }

var chart: Chart
var waveform: PackedFloat32Array
var waveform_completed := 0
var waveform_bins_per_second := 0.0
var show_waveform := true
var duration := 0.0
var playback_start := 0.0
var playback_end := 0.0
var playhead := 0.0
var selection := -1
var zone_selection := -1
var start_time := 0.0
var span := 8.0
var placement := Placement.NOTE

var _drag_index := -1
var _drag_zone := -1
var _drag_origin := Vector2.ZERO
var _drag_position := Vector2.ZERO

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_CROSS
	focus_mode = FOCUS_CLICK
	clip_contents = true
	resized.connect(queue_redraw)

func reset_view() -> void:
	start_time = 0.0
	span = 8.0
	selection = -1
	zone_selection = -1
	cancel_drag()
	queue_redraw()

func cancel_drag() -> void:
	_drag_index = -1
	_drag_zone = -1

func update_playhead(time: float, follow: bool) -> void:
	playhead = time
	if follow and (time < start_time or time > start_time + span * 0.9):
		start_time = maxf(0.0, time - span * 0.15)
	queue_redraw()

func _plot_width() -> float:
	return maxf(1.0, size.x - LEFT - RIGHT)

func _plot_height() -> float:
	return maxf(1.0, size.y - RULER - BOTTOM)

func _x_at(time: float) -> float:
	return LEFT + (time - start_time) * _plot_width() / span

func _time_at(x: float) -> float:
	return start_time + (x - LEFT) * span / _plot_width()

func _y_at(lane: int) -> float:
	return RULER + (lane + 0.5) * _plot_height() / 6.0

func _lane_at(y: float) -> int:
	return clampi(floori((y - RULER) * 6.0 / _plot_height()), 0, 5)

func _draw() -> void:
	if chart == null:
		return
	var plot := Rect2(LEFT, RULER, _plot_width(), _plot_height())
	draw_rect(Rect2(Vector2.ZERO, size), Palette.PAPER)
	for lane in 6:
		var top := RULER + lane * plot.size.y / 6.0
		draw_rect(Rect2(0, top, size.x, plot.size.y / 6.0), Palette.SURFACE if lane % 2 == 0 else Palette.PANEL)
		draw_line(Vector2(0, top), Vector2(plot.end.x, top), Palette.BORDER)
	draw_line(Vector2(0, plot.end.y), Vector2(plot.end.x, plot.end.y), Palette.BORDER)
	if show_waveform and waveform_completed > 0 and duration > 0.0:
		_draw_waveform(plot)
	_draw_grid(plot)
	for lane in 6:
		var axis := Vector2.from_angle(Chart.direction_angle(lane))
		var center := Vector2(LEFT * 0.5, _y_at(lane))
		var tip := center + axis * 8.0
		var shoulder := tip - axis * 5.5
		var width := axis.orthogonal() * 4.0
		var ink := Palette.MUTED
		draw_line(center - axis * 7.0, tip, ink, 1.5, true)
		draw_polyline(PackedVector2Array([shoulder + width, tip, shoulder - width]), ink, 1.5, true)
	draw_line(Vector2(LEFT, 0), Vector2(LEFT, plot.end.y), Palette.RULE)
	for index in chart.events.size():
		var item := chart.events[index]
		var x := _x_at(chart.time_at(item.beat))
		if x >= LEFT and x <= plot.end.x:
			_draw_marker(Vector2(x, _y_at(item.lane)), item, index == selection)
	if _drag_index >= 0 and _drag_position.distance_to(_drag_origin) >= 4.0 and _drag_position.x >= LEFT:
		var x := _x_at(chart.time_at(chart.snap(_time_at(_drag_position.x))))
		if x >= LEFT and x <= plot.end.x:
			_draw_marker(Vector2(x, _y_at(_lane_at(_drag_position.y))), chart.events[_drag_index], true)
	_draw_trimmed_ranges(plot)
	_draw_zones(plot)
	var cursor_x := _x_at(playhead)
	if cursor_x >= LEFT and cursor_x <= plot.end.x:
		draw_line(Vector2(cursor_x, 5), Vector2(cursor_x, plot.end.y), Palette.RED, 1.5)
		draw_colored_polygon(PackedVector2Array([Vector2(cursor_x - 5, 4), Vector2(cursor_x + 5, 4), Vector2(cursor_x, 11)]), Palette.RED)

func _draw_zones(plot: Rect2) -> void:
	for index in chart.zones.size():
		var beat: float = chart.zones[index].beat
		if index == _drag_zone and absf(_drag_position.x - _drag_origin.x) >= 4.0:
			var candidate := chart.snap(_time_at(_drag_position.x))
			if _valid_beat(candidate) and chart.zone_at(candidate) < 0:
				beat = candidate
		var x := _x_at(chart.time_at(beat))
		if x < LEFT or x > plot.end.x:
			continue
		var active := index == zone_selection
		var color := Palette.INK if active else Palette.MUTED
		draw_line(Vector2(x, ZONE_HANDLE_Y), Vector2(x, plot.end.y), color, 2.0 if active else 1.0)
		var handle := Vector2(x, ZONE_HANDLE_Y)
		draw_colored_polygon(PackedVector2Array([
			handle + Vector2(0, -5), handle + Vector2(6, 0),
			handle + Vector2(0, 5), handle + Vector2(-6, 0),
		]), color)

func _zone_at(x: float) -> int:
	var best := -1
	var distance := 8.0
	for index in chart.zones.size():
		var handle_x := _x_at(chart.time_at(chart.zones[index].beat))
		if handle_x < LEFT or handle_x > size.x - RIGHT:
			continue
		var delta := absf(handle_x - x)
		if delta < distance:
			distance = delta
			best = index
	return best

func _draw_trimmed_ranges(plot: Rect2) -> void:
	var shade := Color(Palette.PAPER, 0.68)
	var height := plot.end.y
	if playback_start > 0.0:
		var first := clampf(_x_at(0.0), LEFT, plot.end.x)
		var last := clampf(_x_at(playback_start), LEFT, plot.end.x)
		draw_rect(Rect2(first, 0.0, last - first, height), shade)
		if last > first and last < plot.end.x:
			draw_line(Vector2(last, 0.0), Vector2(last, height), Palette.RULE, 1.5)
	if playback_end < duration:
		var first := clampf(_x_at(playback_end), LEFT, plot.end.x)
		var last := clampf(_x_at(duration), LEFT, plot.end.x)
		draw_rect(Rect2(first, 0.0, last - first, height), shade)
		if last > first and first > LEFT:
			draw_line(Vector2(first, 0.0), Vector2(first, height), Palette.RULE, 1.5)

func _draw_grid(plot: Rect2) -> void:
	var subdivision := chart.subdivision
	var pixel_step := 60.0 * plot.size.x / (chart.bpm * span)
	var step := 1
	while pixel_step * step / subdivision < 6.0:
		step *= 2
	var first_tick := ceili(chart.beat_at(start_time) * subdivision / step) * step
	var end_tick := floori(chart.beat_at(start_time + span) * subdivision)
	for tick in range(first_tick, end_tick + 1, step):
		var beat := float(tick) / subdivision
		var x := _x_at(chart.time_at(beat))
		var bar := tick % (subdivision * 4) == 0
		var whole := tick % subdivision == 0
		var color := Palette.RULE if bar else (Palette.BORDER if whole else Palette.LINE)
		draw_line(Vector2(x, RULER if not whole else 24), Vector2(x, plot.end.y), color)
		if bar and x < plot.end.x - 40:
			draw_string(ThemeDB.fallback_font, Vector2(x + 5, 22), "%.1fs" % chart.time_at(beat), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Palette.MUTED)

func _draw_waveform(plot: Rect2) -> void:
	var center := plot.get_center().y
	var lines := PackedVector2Array()
	for x in range(ceili(LEFT), floori(plot.end.x)):
		var from := maxi(0, floori(_time_at(x) * waveform_bins_per_second))
		var to := mini(waveform_completed, ceili(_time_at(x + 1) * waveform_bins_per_second))
		var peak := 0.0
		for index in range(from, to):
			peak = maxf(peak, waveform[index])
		if peak > 0.0:
			var height := peak * plot.size.y * 0.47
			lines.append(Vector2(x, center - height))
			lines.append(Vector2(x, center + height))
	if not lines.is_empty():
		draw_multiline(lines, Palette.WAVEFORM)

func _draw_marker(point: Vector2, item: Dictionary, highlighted: bool) -> void:
	if highlighted:
		draw_circle(point, 11.0, Palette.RED, false, 1.45, true)
	if item.spike:
		Art.spiky_circle(self, point, 5.6, -PI / 2.0, Palette.SPIKE)
	elif item.has("slider_direction"):
		Art.slider_marker(self, point, 7.0, Vector2(item.slider_direction, 0), Palette.INK, 1.4)
	else:
		draw_circle(point, 6.0, Palette.INK, true, -1, true)

func _marker_at(point: Vector2, radius: float = 10.0) -> int:
	var lane := _lane_at(point.y)
	var nearest := -1
	var distance := radius
	for index in chart.events.size():
		var item := chart.events[index]
		var delta := absf(_x_at(chart.time_at(item.beat)) - point.x)
		if item.lane == lane and delta < distance:
			distance = delta
			nearest = index
	return nearest

func _gui_input(event: InputEvent) -> void:
	if chart == null:
		return
	if event is InputEventMouseMotion and (_drag_index >= 0 or _drag_zone >= 0):
		_drag_position = event.position
		queue_redraw()
		accept_event()
	elif event is InputEventMouseButton:
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			_scroll(event)
		elif event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and _drag_zone >= 0:
			var index := _drag_zone
			_drag_zone = -1
			if absf(event.position.x - _drag_origin.x) >= 4.0 and event.position.x >= LEFT and event.position.x <= size.x - RIGHT:
				var beat := chart.snap(_time_at(event.position.x))
				if _valid_beat(beat):
					zone_moved.emit(index, beat)
			queue_redraw()
		elif event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and _drag_index >= 0:
			var index := _drag_index
			_drag_index = -1
			if event.position.distance_to(_drag_origin) >= 4.0 and Rect2(LEFT, RULER, _plot_width(), _plot_height()).has_point(event.position):
				var beat := chart.snap(_time_at(event.position.x))
				if _valid_beat(beat):
					moved.emit(index, beat, _lane_at(event.position.y))
			queue_redraw()
		elif event.pressed and event.position.x >= LEFT:
			grab_focus()
			_click(event)
		accept_event()

func _click(event: InputEventMouseButton) -> void:
	var point := event.position
	if point.y < RULER:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var index := _zone_at(point.x) if absf(point.y - ZONE_HANDLE_Y) <= 8.0 else -1
			if index >= 0:
				zone_selected.emit(index)
				_drag_zone = index
				_drag_origin = point
				_drag_position = point
			else:
				sought.emit(clampf(_time_at(point.x), 0.0, duration))
	elif point.y < RULER + _plot_height():
		if event.button_index == MOUSE_BUTTON_RIGHT:
			var index := _marker_at(point)
			if index >= 0:
				removed.emit(index)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			var beat := chart.snap(_time_at(point.x))
			var lane := _lane_at(point.y)
			var index := chart.event_at(beat, lane)
			if index < 0:
				var snap_width := absf(_x_at(chart.time_at(beat + 1.0 / chart.subdivision)) - _x_at(chart.time_at(beat)))
				index = _marker_at(point, minf(8.0, snap_width * 0.45))
			if index >= 0:
				selected.emit(index)
				_drag_index = index
				_drag_origin = point
				_drag_position = point
			elif _valid_beat(beat):
				var tool := Placement.SPIKE if event.shift_pressed else placement
				var direction := 0
				match tool:
					Placement.SLIDER_LEFT: direction = -1
					Placement.SLIDER_RIGHT: direction = 1
				placed.emit(beat, lane, tool == Placement.SPIKE, direction)

func _valid_beat(beat: float) -> bool:
	var time := chart.time_at(beat)
	return time >= 0.0 and time < duration

func _scroll(event: InputEventMouseButton) -> void:
	var direction := 1.0 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1.0
	if event.ctrl_pressed:
		var anchor := _time_at(event.position.x)
		var fraction := clampf((event.position.x - LEFT) / _plot_width(), 0.0, 1.0)
		span = clampf(span * pow(1.25, direction), 0.65, 45.0)
		start_time = anchor - span * fraction
	else:
		start_time += span * 0.18 * direction
	var earliest := 0.0
	var end := duration
	for item in chart.events:
		var time := chart.time_at(item.beat)
		earliest = minf(earliest, time - 0.15)
		end = maxf(end, time + 0.15)
	if not chart.zones.is_empty():
		earliest = minf(earliest, chart.time_at(chart.zones.front().beat) - 0.15)
		end = maxf(end, chart.time_at(chart.zones.back().beat) + 0.15)
	start_time = clampf(start_time, earliest, maxf(earliest, end - span * 0.25))
	queue_redraw()
