extends RefCounted

const T = preload("res://scripts/tuning.gd")
const Palette = preload("res://scripts/palette.gd")
const VERSION := 1
const MIN_BPM := 10.0
const MAX_BPM := 600.0
const MIN_PLAYBACK_SECONDS := 0.001
const SUBDIVISIONS := [1, 2, 4, 8, 16, 32]
const DIRECTIONS := ["Up", "Upper right", "Lower right", "Down", "Lower left", "Upper left"]
const MIN_SPAWN_RADIUS := T.SONG_CORE_RADIUS + 1.0
const MAX_SPAWN_RADIUS := 3000.0
const DEFAULT_APPROACH := 1.65
const MIN_APPROACH_SPEED := 30.0
const MAX_APPROACH_SPEED := 2000.0
const DEFAULT_APPROACH_SPEED := 176.0
const MAX_CENTER_ROTATION_SPEED := 3600.0
const ZONE_COLOR_DEFAULTS := {
	"polygon_start_color": Palette.INK,
	"polygon_end_color": Palette.INK,
	"background_color": Palette.SURFACE,
}

var id := new_id()
var title := "Untitled chart"
var audio_id := ""
var audio_name := ""
var bpm := 120.0
var offset := 0.0
var start_offset := 0.0
var end_offset := 0.0
var subdivision := 4
var events: Array[Dictionary] = []
var zones: Array[Dictionary] = []

static func new_id() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()

static func valid_id(value: Variant) -> bool:
	return value is String and value.length() == 32 and value.is_valid_hex_number(false)

static func number_between(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= low and value <= high

static func direction_angle(lane: int) -> float:
	return T.TIP_ANGLE + lane * T.WHEEL_STEP

func time_at(beat: float) -> float:
	return offset + beat * 60.0 / bpm

func beat_at(time: float) -> float:
	return (time - offset) * bpm / 60.0

func snap(time: float) -> float:
	return snappedf(beat_at(time), 1.0 / subdivision)

func event_at(beat: float, lane: int) -> int:
	for index in events.size():
		if events[index].lane == lane and absf(events[index].beat - beat) < 0.000001:
			return index
	return -1

static func new_zone(beat: float) -> Dictionary:
	return {
		"beat": beat, "spawn_radius": T.OUTER_RADIUS,
		"start_speed": DEFAULT_APPROACH_SPEED, "end_speed": DEFAULT_APPROACH_SPEED,
		"rotation_offset": 0.0, "center_rotation_speed": 0.0,
	}

func zone_at(beat: float) -> int:
	for index in zones.size():
		if absf(float(zones[index].beat) - beat) < 0.000001:
			return index
	return -1

func insert_zone(beat: float) -> int:
	var index := zones.size()
	while index > 0 and zones[index - 1].beat > beat:
		index -= 1
	var zone := new_zone(beat) if index == 0 else zones[index - 1].duplicate(true)
	zone.beat = beat
	zones.insert(index, zone)
	return index

func sort_zones() -> void:
	zones.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.beat < b.beat)

func center_rotation_track() -> Array[Dictionary]:
	var track: Array[Dictionary] = []
	var last_time := 0.0
	var angle := 0.0
	var speed := 0.0
	for zone in zones:
		var next_speed := deg_to_rad(zone.center_rotation_speed)
		if next_speed == speed:
			continue
		var time := maxf(0.0, time_at(zone.beat))
		angle = fposmod(angle + (time - last_time) * speed, TAU)
		track.append({"time": time, "angle": angle, "speed": next_speed})
		last_time = time
		speed = next_speed
	return track

static func center_rotation_at(track: Array[Dictionary], at: float) -> float:
	var index := _segment_at(track, at)
	if index < 0:
		return 0.0
	var segment := track[index]
	return fposmod(float(segment.angle) + (at - float(segment.time)) * float(segment.speed), TAU)

func background_track() -> Array[Dictionary]:
	var track: Array[Dictionary] = []
	var last_color := Palette.SURFACE
	for zone in zones:
		var color := zone_color(zone, "background_color", Palette.SURFACE)
		if color != last_color:
			track.append({"time": time_at(zone.beat), "color": color})
			last_color = color
	return track

static func background_at(track: Array[Dictionary], at: float) -> Color:
	var index := _segment_at(track, at)
	return Palette.SURFACE if index < 0 else track[index].color

static func zone_color(zone: Dictionary, key: String, fallback: Color) -> Color:
	return Color.html(zone[key]) if zone.has(key) else fallback

static func _segment_at(track: Array[Dictionary], at: float) -> int:
	var low := 0
	var high := track.size()
	while low < high:
		var middle := (low + high) >> 1
		if track[middle].time <= at:
			low = middle + 1
		else:
			high = middle
	return low - 1

func approach_horizon() -> float:
	var horizon := DEFAULT_APPROACH
	for zone in zones:
		horizon = maxf(horizon, _zone_duration(zone))
	return horizon

static func _zone_duration(zone: Dictionary) -> float:
	return 2.0 * (float(zone.spawn_radius) - T.SONG_CORE_RADIUS) / (float(zone.start_speed) + float(zone.end_speed))

static func remaining_approach(event: Dictionary, at: float) -> float:
	var motion: Dictionary = event.get("motion", {})
	var remaining := float(event.time) - at
	if motion.is_empty():
		return clampf(remaining / DEFAULT_APPROACH, 0.0, 1.0)
	# Integrate linearly changing speed over the time left, then divide by total travel.
	var fraction := clampf(remaining / float(motion.duration), 0.0, 1.0)
	return fraction * (1.0 + float(motion.acceleration) * (1.0 - fraction))

static func approach_angle(event: Dictionary, remaining: float) -> float:
	var motion: Dictionary = event.get("motion", {})
	return direction_angle(event.lane) + float(motion.get("rotation", 0.0)) * remaining

static func approach_color(motion: Dictionary, remaining: float, fallback: Color) -> Color:
	var end: Color = motion.get("polygon_end_color", fallback)
	return end.lerp(motion.get("polygon_start_color", fallback), remaining)

static func max_song_offset(length: float, other_offset: float = 0.0) -> float:
	return maxf(0.0, length - MIN_PLAYBACK_SECONDS - other_offset)

func playback_bounds(length: float) -> Dictionary:
	var start := minf(start_offset, max_song_offset(length))
	var end_trim := minf(end_offset, max_song_offset(length, start))
	return {"start": start, "end": length - end_trim}

func schedule(start: float = -INF, end: float = INF) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event in events:
		var time := time_at(event.beat)
		if time >= start and time < end:
			var scheduled := {"time": time, "lane": event.lane, "spike": event.spike}
			if event.has("slider_direction"):
				scheduled.slider_direction = event.slider_direction
			result.append(scheduled)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.time < b.time)
	var index := 0
	var motion := {}
	for event in result:
		while index < zones.size() and time_at(zones[index].beat) <= event.time:
			var zone := zones[index]
			motion = {
				"duration": _zone_duration(zone), "spawn_radius": zone.spawn_radius,
				"acceleration": (float(zone.end_speed) - float(zone.start_speed)) / (float(zone.end_speed) + float(zone.start_speed)),
				"rotation": deg_to_rad(zone.rotation_offset),
			}
			for key in ["polygon_start_color", "polygon_end_color"]:
				if zone.has(key):
					motion[key] = Color.html(zone[key])
			index += 1
		if not motion.is_empty():
			event.motion = motion
	return result

func record() -> Dictionary:
	return {
		"version": VERSION, "id": id, "title": title, "audio_id": audio_id,
		"audio_name": audio_name, "bpm": bpm, "offset": offset,
		"start_offset": start_offset, "end_offset": end_offset,
		"subdivision": subdivision, "events": events, "zones": zones,
	}

static func from_record(record: Variant) -> RefCounted:
	if not record is Dictionary or record.get("version") != VERSION:
		return null
	if not valid_id(record.get("id")) or not valid_id(record.get("audio_id")):
		return null
	if not record.get("title") is String or record.title.strip_edges().is_empty() or not record.get("audio_name") is String:
		return null
	if not number_between(record.get("bpm"), MIN_BPM, MAX_BPM) or not number_between(record.get("offset"), -3600.0, 3600.0):
		return null
	var start: Variant = record.get("start_offset", 0.0)
	var end: Variant = record.get("end_offset", 0.0)
	if not number_between(start, 0.0, INF) or not number_between(end, 0.0, INF):
		return null
	if not number_between(record.get("subdivision"), 1, 32) or record.subdivision != int(record.subdivision) or not SUBDIVISIONS.has(int(record.subdivision)):
		return null
	if not record.get("events") is Array:
		return null
	var chart := new()
	chart.id = record.id
	chart.title = record.title
	chart.audio_id = record.audio_id
	chart.audio_name = record.audio_name
	chart.bpm = record.bpm
	chart.offset = record.offset
	chart.start_offset = start
	chart.end_offset = end
	chart.subdivision = int(record.subdivision)
	var cells := {}
	for event in record.events:
		if not event is Dictionary or not number_between(event.get("beat"), -1000000, 1000000):
			return null
		if not number_between(event.get("lane"), 0, DIRECTIONS.size() - 1) or event.lane != int(event.lane) or not event.get("spike") is bool:
			return null
		var direction: Variant = event.get("slider_direction", 0)
		if event.has("slider_direction") and (event.spike or not number_between(direction, -1.0, 1.0) or absf(float(direction)) != 1.0):
			return null
		var lane := int(event.lane)
		var beat := float(event.beat)
		var cell := "%d:%.6f" % [lane, beat]
		if cells.has(cell):
			return null
		cells[cell] = true
		var item := {"beat": beat, "lane": lane, "spike": event.spike}
		if direction != 0:
			item.slider_direction = int(direction)
		chart.events.append(item)
	var saved_zones: Variant = record.get("zones", [])
	if not saved_zones is Array:
		return null
	for zone in saved_zones:
		if not zone is Dictionary or not number_between(zone.get("beat"), -1000000, 1000000):
			return null
		if not number_between(zone.get("spawn_radius"), MIN_SPAWN_RADIUS, MAX_SPAWN_RADIUS):
			return null
		if not number_between(zone.get("start_speed"), MIN_APPROACH_SPEED, MAX_APPROACH_SPEED) or not number_between(zone.get("end_speed"), MIN_APPROACH_SPEED, MAX_APPROACH_SPEED):
			return null
		if not number_between(zone.get("rotation_offset"), -360.0, 360.0):
			return null
		var center_speed: Variant = zone.get("center_rotation_speed", 0.0)
		if not number_between(center_speed, -MAX_CENTER_ROTATION_SPEED, MAX_CENTER_ROTATION_SPEED):
			return null
		var settings := {
			"beat": float(zone.beat), "spawn_radius": float(zone.spawn_radius),
			"start_speed": float(zone.start_speed), "end_speed": float(zone.end_speed),
			"rotation_offset": float(zone.rotation_offset), "center_rotation_speed": float(center_speed),
		}
		for key in ZONE_COLOR_DEFAULTS:
			if zone.has(key):
				var color: Variant = zone[key]
				if not color is String or color.length() != 6 or not Color.html_is_valid(color):
					return null
				settings[key] = color.to_lower()
		chart.zones.append(settings)
	chart.sort_zones()
	for index in range(1, chart.zones.size()):
		if float(chart.zones[index].beat) - float(chart.zones[index - 1].beat) < 0.000001:
			return null
	return chart
