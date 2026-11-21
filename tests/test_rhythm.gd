extends SceneTree

const AppScene = preload("res://scenes/main.tscn")
const Chart = preload("res://scripts/song_chart.gd")
const Library = preload("res://scripts/chart_library.gd")
const Session = preload("res://scripts/song_session.gd")

var _checks := 0
var _failed := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failed += 1
		push_error(description)

func _event(time: float, lane: int = 0, spike: bool = false) -> Dictionary:
	return {"time": time, "lane": lane, "spike": spike}

func _session(events: Array[Dictionary], cursor: float = 0.0) -> Session:
	var model := Session.new()
	model.setup(events, 5.5, cursor, maxf(0.0, cursor - Session.LEAD_IN))
	return model

func _check_judgment() -> void:
	var model := _session([_event(1.0), _event(1.5), _event(1.56)])
	model.press(1.0 - Session.HIT_WINDOW)
	_check(model.hits == 1 and model.events[1].time == 1.5, "An early edge hit must preserve the next arrival.")
	model.press(1.55)
	_check(model.hits == 2 and model.resolved[2] == 1 and model.resolved[1] == 0, "An overlapping window must score only its closest note.")
	model.press(1.5 + Session.HIT_WINDOW)
	_check(model.hits == 3 and model.combo == 3, "A late edge hit must count as a separate press on a repeated direction.")

	model = _session([_event(1.0, 1), _event(1.4)])
	model.press(1.0)
	_check(model.hits == 0 and model.feedback == "Wrong direction", "A timing-valid press in the wrong direction must not score.")
	model.advance_to(1.11)
	_check(model.misses == 1 and model.energy == Session.MAX_ENERGY - Session.ENERGY_PER_MISTAKE, "An unresolved note must expire once.")
	model.press(1.4)
	_check(model.energy == Session.MAX_ENERGY - Session.ENERGY_PER_MISTAKE + Session.ENERGY_PER_HIT, "A subsequent hit must restore energy.")

	model = _session([_event(1.0, 0, true), _event(1.0, 1)])
	model.advance_to(1.0)
	_check(model.spike_hits == 1 and model.energy == Session.MAX_ENERGY - Session.ENERGY_PER_MISTAKE, "An aimed spike must penalize without a press.")
	model.advance_to(1.05)
	_check(model.spike_hits == 1 and model.resolved[1] == 0, "A spike must resolve once while a simultaneous note remains eligible.")
	model = _session([_event(1.0, 0, true), _event(1.0, 1)])
	model.rotate(1.0, 0.77)
	model.press(1.0)
	_check(model.spike_hits == 0 and model.hits == 1, "Turning to another lane in time must allow a dodge and a simultaneous hit.")

	model = _session([_event(0.7, 0, true), _event(1.0)], 1.0)
	model.press(0.95)
	_check(model.spike_hits == 0 and model.hits == 1, "A cursor test must allow the first early tap and ignore a spike before the cursor.")
	model = _session([_event(0.0, 0, true), _event(0.25), _event(0.5), _event(0.75), _event(1.0), _event(1.25), _event(1.5), _event(1.75)])
	model.advance_to(2.0)
	_check(model.energy == 0 and model.misses == 6, "Zero energy must end judgment.")

func _wav() -> PackedByteArray:
	var format := AudioStreamWAV.new()
	format.mix_rate = 8000
	format.format = AudioStreamWAV.FORMAT_16_BITS
	var samples := PackedByteArray()
	samples.resize(8000 * 6 * 2)
	for frame in 8000 * 6:
		var gain := 0.65 if float(frame % 4000) / 8000.0 < 0.05 else 0.0
		samples.encode_s16(frame * 2, int(sin(frame * 0.33) * gain * 32767.0))
	var wav := PackedByteArray()
	wav.append_array("RIFF".to_ascii_buffer())
	wav.resize(44)
	wav.encode_u32(4, samples.size() + 36)
	var chunk_names := {"WAVE": 8, "fmt ": 12, "data": 36}
	for key in chunk_names:
		for point in 4:
			wav[int(chunk_names[key]) + point] = key.unicode_at(point)
	wav.encode_u32(16, 16)
	wav.encode_u16(20, 1)
	wav.encode_u16(22, 1)
	wav.encode_u32(24, format.mix_rate)
	wav.encode_u32(28, format.mix_rate * 2)
	wav.encode_u16(32, 2)
	wav.encode_u16(34, 16)
	wav.encode_u32(40, samples.size())
	wav.append_array(samples)
	return wav

func _check_application(app, wav: PackedByteArray) -> void:
	app._show_charts()
	app.editor._open_editor(Chart.new(), null)
	app.editor._accept_song({"name": "Timing.wav", "bytes": wav})
	var chart: Chart = app.editor.chart
	var stream: AudioStreamWAV = app.editor.transport.stream
	_check(stream.get_length() == 6.0, "The native editor must accept a six-second WAV.")
	app.editor.timeline.placed.emit(4.0, 0, false)
	app.editor.timeline.placed.emit(4.0, 1, true)
	app.editor.timeline.removed.emit(1)
	_check(chart.events.size() == 1 and not chart.events[0].spike, "Erasing a simultaneous spike must preserve the other lane.")
	app.editor.timeline.placed.emit(4.0, 1, true)
	app.editor.timeline.moved.emit(1, 4.0, 3)
	app.editor._seek(2.0)
	app.editor._play(true)
	_check(app.song.visible and app.song.session.events[1].lane == 3, "Cursor playtest must use the unsaved moved spike.")
	_check(is_equal_approx(app.song.session.time, 0.5), "Playback must start at the cursor minus the lead-in.")
	await create_timer(0.25).timeout
	_check(app.song.transport.song_time() > 0.55, "The native clock must advance with the reference track.")
	app._pause_active()
	var paused: float = app.song.transport.song_time()
	await create_timer(0.20).timeout
	_check(is_equal_approx(app.song.transport.song_time(), paused), "Focus pause must freeze the audio clock.")
	app.song._continue_run()
	await create_timer(0.25).timeout
	_check(app.song.transport.song_time() > paused + 0.05, "Resuming must continue the audio clock.")
	app.song._leave()
	_check(app.editor.visible and is_equal_approx(app.editor.timeline.playhead, 2.0), "Playtest exit must restore the editor cursor.")
	_check(app.editor.timeline.waveform_completed > 0 and app.editor.timeline.waveform[0] > 0.5, "The waveform must match the reference track's first pulse.")
	var timeline = app.editor.timeline
	var wheel := InputEventMouseButton.new()
	wheel.position = Vector2(timeline.LEFT + timeline._plot_width() * 0.4, 100)
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.ctrl_pressed = true
	var anchor: float = timeline._time_at(wheel.position.x)
	timeline._scroll(wheel)
	_check(timeline.span < 8.0 and absf(timeline._time_at(wheel.position.x) - anchor) < 0.001, "Zoom must keep the same song time beneath the pointer.")
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.ctrl_pressed = false
	timeline._scroll(wheel)
	_check(timeline._time_at(wheel.position.x) > anchor and chart.events[0].beat == 4.0, "Panning must move the view while preserving chart timing.")

func _check_storage(library: Library, arguments: PackedStringArray, wav: PackedByteArray) -> void:
	var chart := Chart.new()
	chart.id = "11111111111111111111111111111111"
	chart.title = "Timing check"
	chart.audio_id = "22222222222222222222222222222222"
	chart.audio_name = "Timing.wav"
	chart.offset = 0.125
	chart.events.append({"beat": 1.5, "lane": 3, "spike": true})
	_check(is_equal_approx(chart.time_at(1.5), 0.875), "Beat conversion must include the first-beat offset.")
	var invalid := chart.record()
	invalid.bpm = 0
	_check(Chart.from_record(invalid) == null, "An invalid BPM must be rejected.")
	if arguments.size() != 2:
		return
	library.directory = arguments[1]
	if arguments[0] == "write":
		_check(await library.save_chart(chart, wav) == "", "Native save must write the chart and audio.")
		chart.title = "Updated timing check"
		_check(await library.save_chart(chart, PackedByteArray()) == "", "Saving an existing chart must replace its metadata.")
		chart.audio_id = Chart.new_id()
		_check(await library.save_chart(chart, PackedByteArray()) != "", "Missing replacement audio must reject the save.")
	elif arguments[0] == "read":
		var library_index: Dictionary = await library.list_charts()
		_check(library_index.charts.size() == 1, "The saved chart must appear after a fresh process starts.")
		var saved: Dictionary = await library.read_chart(chart.id)
		_check(saved.has("chart") and saved.chart.title == "Updated timing check", "The last successful native save must survive a restart.")
		_check(saved.has("stream") and is_equal_approx(saved.stream.get_length(), 6.0), "The saved song must reopen without another import.")

func _run() -> void:
	_check_judgment()
	var app := AppScene.instantiate()
	root.add_child(app)
	var arguments := OS.get_cmdline_user_args()
	var wav := _wav()
	await _check_storage(app.editor.library, arguments, wav)
	if not arguments.has("read"):
		await _check_application(app, wav)
	app.queue_free()
	await process_frame
	await create_timer(0.10).timeout
	print("RHYTHM: %d checks, %d failures" % [_checks, _failed])
	quit(1 if _failed else 0)
