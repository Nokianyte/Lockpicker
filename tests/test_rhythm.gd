extends SceneTree

const AppScene = preload("res://scenes/main.tscn")
const Chart = preload("res://scripts/song_chart.gd")
const Library = preload("res://scripts/chart_library.gd")
const Session = preload("res://scripts/song_session.gd")
const T = preload("res://scripts/tuning.gd")
const G = preload("res://scripts/wall_geometry.gd")

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
	model.rotate(-1.0, 0.77)
	model.press(1.0)
	_check(model.spike_hits == 0 and model.hits == 1, "Turning the layer in time must allow a dodge and a simultaneous hit.")

	model = _session([_event(1.0, 1), _event(1.0, 2, true), _event(1.4, 4)])
	model.rotate(-1.0, 0.7)
	_check(is_equal_approx(model.ring_angle(0, 0.7 + T.TURN_DURATION / 2.0), Chart.direction_angle(1) - T.WHEEL_STEP / 2.0), "The inner note must turn smoothly.")
	_check(is_equal_approx(model.ring_angle(1, 1.0), Chart.direction_angle(1)), "A spike on the same beat must turn with the active note.")
	_check(is_equal_approx(model.ring_angle(2, 1.0), Chart.direction_angle(4)), "An outer layer must keep its charted orientation during a turn.")
	model.press(0.95)
	model.advance_to(1.0)
	_check(model.hits == 1 and model.spike_hits == 0, "The layer must retain its turn through an early note hit while its spike is pending.")
	_check(is_equal_approx(model.ring_angle(2, 1.0), Chart.direction_angle(4)), "A newly active layer must start in its charted orientation.")

	model = _session([_event(0.7, 0, true), _event(1.0)], 1.0)
	model.press(0.95)
	_check(model.spike_hits == 0 and model.hits == 1, "A cursor test must allow the first early tap and ignore a spike before the cursor.")
	model = _session([_event(0.0, 0, true), _event(0.25), _event(0.5), _event(0.75), _event(1.0), _event(1.25), _event(1.5), _event(1.75)])
	model.advance_to(2.0)
	_check(model.energy == 0 and model.misses == 6, "Zero energy must end judgment.")

func _check_hit_bindings() -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_Z
	_check(event.is_action_pressed("song_hit"), "Z must trigger a song hit.")
	event.keycode = KEY_X
	_check(event.is_action_pressed("song_hit"), "X must trigger a song hit.")
	event.keycode = KEY_SPACE
	_check(not event.is_action_pressed("song_hit"), "Space must not trigger a song hit.")

func _check_zone_motion() -> void:
	var chart := Chart.new()
	chart.zones = [Chart.new_zone(4.0), Chart.new_zone(8.0)]
	var zone := chart.zones[0]
	zone.spawn_radius = 300.0
	zone.start_speed = 50.0
	zone.end_speed = 150.0
	zone.rotation_offset = 120.0
	chart.events = [
		{"beat": 3.0, "lane": 0, "spike": false}, {"beat": 4.0, "lane": 0, "spike": false},
		{"beat": 6.0, "lane": 0, "spike": true}, {"beat": 8.0, "lane": 0, "spike": false},
	]
	var schedule := chart.schedule()
	_check(not schedule[0].has("motion") and schedule[1].motion.spawn_radius == 300.0, "Zone settings must begin on their marker beat.")
	_check(schedule[2].motion.duration == 2.0 and schedule[3].motion.spawn_radius == T.OUTER_RADIUS, "The next marker must start a new motion profile while every arrival stays fixed.")
	_check(Chart.remaining_approach(schedule[2], 1.0) == 1.0 and Chart.remaining_approach(schedule[2], 3.0) == 0.0, "The spike must reach the target at its original beat.")
	var remaining := Chart.remaining_approach(schedule[2], 2.0)
	_check(is_equal_approx(remaining, 0.625), "An accelerating approach must cover more distance in its second half.")
	_check(is_equal_approx(Chart.approach_angle(schedule[2], remaining) - T.TIP_ANGLE, deg_to_rad(75.0)), "Rotation must follow the same speed ramp as radius.")
	var trimmed := chart.schedule(2.25, 4.0)
	_check(trimmed.size() == 1 and trimmed[0].motion == schedule[2].motion, "A trim or cursor inside a zone must retain its approach settings.")
	var model := _session(trimmed)
	model.advance_to(3.0)
	_check(model.spike_hits == 1, "The spike must align with the fixed circle when the authored rotation has completed.")
	_check(G.song_spike_aligns(T.TIP_ANGLE + deg_to_rad(7.0)) and not G.song_spike_aligns(T.TIP_ANGLE + deg_to_rad(8.0)), "A spike registers with its center inside the fixed circle, even while turning.")

func _check_center_rotation() -> void:
	var chart := Chart.new()
	chart.zones = [Chart.new_zone(2.0), Chart.new_zone(4.0), Chart.new_zone(6.0)]
	chart.zones[0].center_rotation_speed = 90.0
	chart.zones[1].center_rotation_speed = -45.0
	var track := chart.center_rotation_track()
	_check(Chart.center_rotation_at(track, 0.5) == 0.0, "The center must stay still before the first rotating zone.")
	_check(is_equal_approx(Chart.center_rotation_at(track, 2.0), PI / 2.0), "A speed change must preserve the angle at the zone boundary.")
	_check(is_equal_approx(Chart.center_rotation_at(track, 2.5), deg_to_rad(67.5)), "Negative speed must reverse the spin.")
	_check(is_equal_approx(Chart.center_rotation_at(track, 5.0), PI / 4.0), "A zero-speed zone must hold the angle reached by the previous zone.")
	_check(is_equal_approx(Chart.center_rotation_at(track, 1.5), PI / 4.0), "A backward seek must reproduce the angle at that song time.")

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
	var stream: AudioStreamWAV = app.editor.transport.song
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
	var legacy := chart.record()
	legacy.erase("start_offset")
	legacy.erase("end_offset")
	legacy.erase("zones")
	var reopened = Chart.from_record(legacy)
	_check(reopened.start_offset == 0.0 and reopened.end_offset == 0.0 and reopened.zones.is_empty(), "Legacy charts must default to the whole song and regular motion.")
	var trimmed := chart.record()
	trimmed.start_offset = 1.0
	trimmed.end_offset = 3.5
	reopened = Chart.from_record(trimmed)
	_check(reopened.record() == trimmed, "Saved offsets must round-trip with the chart.")
	trimmed.end_offset = -0.5
	_check(Chart.from_record(trimmed) == null, "Negative song trims must be rejected.")
	chart.zones.append(Chart.new_zone(1.5))
	chart.zones[0].rotation_offset = -60.0
	chart.zones[0].center_rotation_speed = -90.0
	var with_zone := chart.record()
	_check(Chart.from_record(with_zone).record() == with_zone, "Zone settings must round-trip with the chart.")
	var old_zone := with_zone.duplicate(true)
	old_zone.zones[0].erase("center_rotation_speed")
	reopened = Chart.from_record(old_zone)
	_check(reopened.zones[0].center_rotation_speed == 0.0, "A previously saved zone must default to a stationary center.")
	var with_duplicate := with_zone.duplicate(true)
	with_duplicate.zones.append(Chart.new_zone(1.5))
	_check(Chart.from_record(with_duplicate) == null, "Two zones cannot share the same start marker.")
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
		_check(saved.has("chart") and saved.chart.zones == chart.zones, "Saved zone settings must survive a fresh process.")

func _check_song_offsets(app, wav: PackedByteArray) -> void:
	var editor = app.editor
	var chart := Chart.new()
	editor._open_editor(chart, null)
	editor._accept_song({"name": "Trim.wav", "bytes": wav})
	editor._start_offset.value = 1.0
	editor._end_offset.value = 3.5
	for beat in [1.0, 2.0, 4.0, 5.0, 8.0]:
		editor.timeline.placed.emit(beat, 0, false)
	_check(editor.timeline.duration == 6.0 and chart.events.size() == 5, "Trimming must preserve the original timeline and chart events.")
	_check(editor.preview.events.size() == 2 and editor.preview.events[0].time == 1.0, "The preview must include the start boundary and exclude the end boundary.")
	editor._seek(0.25)
	_check(editor.timeline.playhead == 1.0, "Seeking before the playable range must stop at its start.")
	editor._seek(5.0)
	_check(editor.timeline.playhead == 2.5, "Seeking after the playable range must stop at its end.")
	editor._toggle_preview()
	_check(editor.transport.running and editor.transport._position == 1.0, "Preview replay at the cutoff must restart at the playable start.")
	editor.pause_preview()
	editor._play(false)
	_check(app.song.session.time == 1.0 and app.song.session.duration == 2.5, "Full playtest must run between the trimmed boundaries.")
	await create_timer(1.85).timeout
	_check(app.song._finished and not app.song.transport.running and app.song.session.misses == 2, "Playtest must finish at the cutoff and judge only the events inside it.")
	app.song._leave()
	editor._seek(1.2)
	editor._play(true)
	_check(app.song.session.time == 1.0 and app.song.session.events.size() == 1, "Cursor playtest lead-in must stay inside the playable range.")
	app.song._leave()

func _check_zone_editor(app, wav: PackedByteArray) -> void:
	var editor = app.editor
	var chart := Chart.new()
	editor._open_editor(chart, null)
	editor._accept_song({"name": "Zones.wav", "bytes": wav})
	await process_frame
	editor.timeline.placed.emit(6.0, 0, true)
	editor._seek(2.04)
	editor._add_zone_button.pressed.emit()
	_check(chart.zones.size() == 1 and chart.zones[0].beat == 4.0 and editor._zone_settings.visible, "Adding a zone must snap at the playhead and open its settings.")
	editor._zone_fields.rotation_offset.value = -120.0
	editor._zone_fields.start_speed.value = 80.0
	editor._zone_fields.center_rotation_speed.value = 120.0
	editor._select_zone(-1)
	var click := InputEventMouseButton.new()
	click.position = Vector2(editor.timeline._x_at(2.0), editor.timeline.ZONE_HANDLE_Y)
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	editor.timeline._gui_input(click)
	_check(editor._zone_settings.visible and editor._zone_fields.rotation_offset.value == -120.0 and editor._zone_fields.center_rotation_speed.value == 120.0, "Clicking a zone marker must reopen that zone's settings.")
	click.position.x = editor.timeline._x_at(2.5)
	click.pressed = false
	editor.timeline._gui_input(click)
	_check(chart.zones[0].beat == 5.0 and chart.zones[0].start_speed == 80.0, "Dragging a zone must move its marker and preserve its settings.")
	editor._play(false)
	_check(app.song.session.events[0].motion.rotation == editor.preview.events[0].motion.rotation, "Playtest and editor preview must share the zone's motion profile.")
	_check(app.song.arena.center_rotation_track == editor.preview.center_rotation_track and is_equal_approx(Chart.center_rotation_at(app.song.arena.center_rotation_track, 2.75), PI / 6.0), "Playtest and preview must share the arena angle at a given song time.")
	app.song._leave()
	editor._delete_zone_button.pressed.emit()
	_check(chart.zones.is_empty() and editor._chart_settings.visible and chart.events.size() == 1, "Deleting a zone must restore chart settings and preserve its notes and spikes.")
	var undo := InputEventKey.new()
	undo.keycode = KEY_Z
	undo.ctrl_pressed = true
	undo.pressed = true
	editor._unhandled_key_input(undo)
	_check(chart.zones.size() == 1 and chart.zones[0].beat == 5.0, "Undo must restore the deleted zone at its moved start.")

func _run() -> void:
	_check_judgment()
	_check_hit_bindings()
	_check_zone_motion()
	_check_center_rotation()
	var app := AppScene.instantiate()
	root.add_child(app)
	var arguments := OS.get_cmdline_user_args()
	var wav := _wav()
	await _check_storage(app.editor.library, arguments, wav)
	if not arguments.has("read"):
		await _check_application(app, wav)
		await _check_song_offsets(app, wav)
		await _check_zone_editor(app, wav)
	app.queue_free()
	await process_frame
	await create_timer(0.10).timeout
	print("RHYTHM: %d checks, %d failures" % [_checks, _failed])
	quit(1 if _failed else 0)
