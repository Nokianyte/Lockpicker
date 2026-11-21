extends RefCounted

const T = preload("res://scripts/tuning.gd")
const VERSION := 1
const MIN_BPM := 10.0
const MAX_BPM := 600.0
const SUBDIVISIONS := [1, 2, 4, 8, 16, 32]
const DIRECTIONS := ["Up", "Upper right", "Lower right", "Down", "Lower left", "Upper left"]

var id := new_id()
var title := "Untitled chart"
var audio_id := ""
var audio_name := ""
var bpm := 120.0
var offset := 0.0
var subdivision := 4
var events: Array[Dictionary] = []

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

func schedule() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event in events:
		result.append({"time": time_at(event.beat), "lane": event.lane, "spike": event.spike})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.time < b.time)
	return result

func record() -> Dictionary:
	return {
		"version": VERSION, "id": id, "title": title, "audio_id": audio_id,
		"audio_name": audio_name, "bpm": bpm, "offset": offset,
		"subdivision": subdivision, "events": events,
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
	chart.subdivision = int(record.subdivision)
	var cells := {}
	for event in record.events:
		if not event is Dictionary or not number_between(event.get("beat"), -1000000, 1000000):
			return null
		if not number_between(event.get("lane"), 0, DIRECTIONS.size() - 1) or event.lane != int(event.lane) or not event.get("spike") is bool:
			return null
		var lane := int(event.lane)
		var beat := float(event.beat)
		var cell := "%d:%.6f" % [lane, beat]
		if cells.has(cell):
			return null
		cells[cell] = true
		chart.events.append({"beat": beat, "lane": lane, "spike": event.spike})
	return chart
