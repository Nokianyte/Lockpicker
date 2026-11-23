extends SceneTree

const AppScene = preload("res://scenes/main.tscn")
const Chart = preload("res://scripts/song_chart.gd")
const Library = preload("res://scripts/chart_library.gd")
const Package = preload("res://scripts/chart_package.gd")
const Session = preload("res://scripts/song_session.gd")
const T = preload("res://scripts/tuning.gd")
const G = preload("res://scripts/wall_geometry.gd")
const Palette = preload("res://scripts/palette.gd")

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

func _check_judgment_tints() -> void:
	var model := _session([_event(1.0), _event(2.0), _event(2.3), _event(4.0), _event(4.5, 0, true)])
	var penalties: Array[bool] = []
	model.penalized.connect(func() -> void: penalties.append(true))
	model.press(0.8)
	_check(model.tint_judgment == Session.Judgment.NONE, "An off-beat press must leave the center at its idle color.")
	model.press(1.035)
	_check(model.tint_judgment == Session.Judgment.PERFECT and model.feedback == "Perfect", "A hit at the Perfect boundary must trigger the Perfect tint.")
	model.press(1.2)
	_check(model.tint_judgment == Session.Judgment.PERFECT and model.tint_at == 1.035, "An invalid press must not replace or retrigger the last judgment tint.")
	model.press(2.07)
	_check(model.tint_judgment == Session.Judgment.GOOD and model.feedback == "Good · Late", "A hit at the Good boundary must trigger the Good tint.")
	model.press(2.21)
	_check(model.tint_judgment == Session.Judgment.GOOD and model.tint_at == 2.07 and model.feedback == "OK · Early" and model.hits == 3, "An OK hit must count without starting a new tint or interrupting the last one.")
	_check(penalties.is_empty(), "Hits and invalid presses must not trigger the penalty flash.")
	model.advance_to(4.11)
	_check(model.tint_judgment == Session.Judgment.MISS and model.tint_at == 4.1 and model.feedback == "Miss", "A missed note must trigger the Miss tint at the deadline.")
	model.advance_to(4.5)
	_check(model.tint_judgment == Session.Judgment.MISS and model.tint_at == 4.5 and model.feedback == "Spike", "A spike hit must trigger the Miss tint.")
	_check(penalties.size() == 2, "Each miss and spike hit must trigger one penalty flash.")

func _check_sliders() -> void:
	var right := _event(1.0)
	right.slider_direction = 1
	var left := _event(2.0, 1)
	left.slider_direction = -1
	var model := _session([right, _event(1.5, 1), _event(1.75, 1, true), left, _event(2.5)])
	model.press(0.95)
	model.press_arrow(-1, 0.96)
	_check(model.hits == 0 and model.resolved[0] == 0 and model.feedback == "Wrong arrow", "A slider must stay available after a tap or the wrong arrow.")
	model.press_arrow(1, 0.98)
	_check(model.hits == 1 and model.center_angle(0.99) == T.TIP_ANGLE, "An early hit must score without starting the center turn before the beat.")
	_check(is_equal_approx(model.center_angle(1.08), T.TIP_ANGLE + T.WHEEL_STEP / 2.0), "The right slider must turn the center on its charted beat.")
	_check(is_equal_approx(model.ring_angle(1, 1.5), Chart.direction_angle(1)), "Slider turns must leave later rings in their charted orientations.")
	model.press(1.5)
	model.advance_to(1.75)
	_check(model.hits == 2 and model.spike_hits == 1, "Both taps and spikes must use the shifted target for judgment.")
	model.press_arrow(-1, 2.0)
	model.press(2.5)
	_check(model.hits == 4 and is_equal_approx(model.center_angle(2.5), T.TIP_ANGLE), "A left slider must undo the previous right step and aim the following tap.")
	model = _session([{"time": 1.0, "lane": 1, "spike": false, "slider_direction": 1}, _event(1.5, 1)])
	model.press_arrow(1, 0.9)
	_check(model.hits == 0 and model.feedback == "Wrong direction", "The correct arrow cannot hit a slider in the wrong lane.")
	model.advance_to(1.11)
	model.press(1.5)
	_check(model.misses == 1 and model.hits == 1 and is_equal_approx(model.center_angle(1.5), T.TIP_ANGLE + T.WHEEL_STEP), "An unhit slider must still rotate the target for the following tap.")
	model = _session([right])
	model.press_arrow(1, 1.09)
	_check(model.hits == 1 and absf(angle_difference(model.center_angle(1.09), T.TIP_ANGLE)) > T.GAP_ANGLE, "A late slider hit must still use its alignment at the beat while the target turns.")
	model = _session([{"time": 1.0, "lane": 1, "spike": false, "slider_direction": 1}])
	model.press_arrow(-1, 0.75)
	model.press_arrow(1, 1.0)
	_check(model.hits == 1, "An arrow outside the hit window must still aim the ring for a slider.")
	model = _session([right, _event(1.5, 1)], 1.5)
	_check(model.center_angle(0.8) == T.TIP_ANGLE, "Cursor playtest lead-in must use the angle at its actual song time.")
	model.press(1.5)
	_check(model.hits == 1 and is_equal_approx(model.center_angle(1.5), T.TIP_ANGLE + T.WHEEL_STEP), "Cursor playtest must start with the target angle from earlier sliders.")
	var second := _event(1.08)
	second.slider_direction = 1
	model = _session([right, second])
	_check(is_equal_approx(model.center_angle(1.16), T.TIP_ANGLE + 1.5 * T.WHEEL_STEP) and is_equal_approx(model.center_angle(1.25), T.TIP_ANGLE + 2.0 * T.WHEEL_STEP), "Closely spaced slider turns must add without restarting either turn.")

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

func _check_extra_input_circles() -> void:
	var chart := Chart.new()
	chart.audio_id = Chart.new_id()
	chart.zones = [Chart.new_zone(2.0), Chart.new_zone(4.0)]
	chart.zones[0].extra_input_sides = 1 << 1
	var track := chart.input_circle_track()
	_check(Chart.input_mask_at(track, 0.9) == 1 and Chart.input_mask_at(track, 1.0) == 3 and Chart.input_mask_at(track, 2.0) == 1, "Extra targets must switch exactly at zone boundaries.")
	var model := Session.new()
	var slider := _event(1.5, 1)
	slider.slider_direction = 1
	model.setup([_event(1.0, 2), _event(1.0, 1), slider, _event(1.8, 2, true), _event(2.1, 2)], 3.0, 0.0, 0.0, track)
	model.press(1.0)
	_check(model.hits == 1 and model.resolved[1] == 1 and model.tint_side == 1, "An extra target must allow a hit even when a simultaneous note is misaligned.")
	model.press_arrow(1, 1.5)
	_check(model.hits == 2 and model.tint_side == 1, "A slider must score at an enabled extra target.")
	model.advance_to(1.8)
	_check(model.spike_hits == 1, "The extra target must rotate with the slider and register a spike hit.")
	model.press(2.1)
	_check(model.hits == 2 and model.feedback == "Wrong direction", "An extra target from the previous zone must deactivate.")
	_check(Chart.from_record(chart.record()).zones == chart.zones, "Extra input sides must survive saving and reopening.")
	chart.zones[0].extra_input_sides = 63
	_check(Chart.from_record(chart.record()) == null, "The mandatory primary side cannot be stored as an extra side.")

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

func _check_zone_colors() -> void:
	var chart := Chart.new()
	chart.audio_id = Chart.new_id()
	chart.zones = [Chart.new_zone(2.0), Chart.new_zone(8.0)]
	var zone := chart.zones[0]
	zone.spawn_radius = 300.0
	zone.start_speed = 50.0
	zone.end_speed = 150.0
	zone.polygon_start_color = "ff0000"
	zone.polygon_end_color = "0000ff"
	zone.background_color = "101820"
	chart.events = [{"beat": 6.0, "lane": 0, "spike": false}]
	var event := chart.schedule()[0]
	_check(Chart.approach_color(event.motion, 1.0, Palette.INK) == Color.RED and Chart.approach_color(event.motion, 0.0, Palette.INK) == Color.BLUE, "Color endpoints must match the zone settings.")
	var halfway := Chart.approach_color(event.motion, Chart.remaining_approach(event, 2.0), Palette.INK)
	_check(halfway.is_equal_approx(Color(0.625, 0.0, 0.375)), "Accelerating polygons must also change color faster as they approach.")
	var background := chart.background_track()
	_check(Chart.background_at(background, 0.99) == Palette.SURFACE and Chart.background_at(background, 1.0) == Color("101820") and Chart.background_at(background, 4.0) == Palette.SURFACE, "Background changes must follow zone boundaries and restore the default for an unset zone.")
	_check(Chart.from_record(chart.record()).record() == chart.record(), "All three zone colors must survive saving and reopening.")
	zone.background_color = "bad value"
	_check(Chart.from_record(chart.record()) == null, "Invalid zone colors must be rejected.")

func _check_master_volume(app) -> void:
	var bus := AudioServer.get_bus_index("Master")
	var initial: float = app._volume_slider.value
	app._volume_slider.value = 25
	_check(is_equal_approx(AudioServer.get_bus_volume_db(bus), linear_to_db(0.25)) and not AudioServer.is_bus_mute(bus), "The master volume slider must set the mixer level.")
	app._volume_slider.value = 0
	_check(AudioServer.is_bus_mute(bus), "Zero volume must mute the master bus.")
	app._volume_slider.value = initial

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
	_check(app.editor.visible and app.editor._library_screen.is_visible_in_tree() and not app.song.visible, "The app must open straight to the chart library.")
	app.editor._open_editor(Chart.new(), null)
	app.editor._accept_song({"name": "Timing.wav", "bytes": wav})
	var chart: Chart = app.editor.chart
	var stream: AudioStreamWAV = app.editor.transport.song
	_check(stream.get_length() == 6.0, "The native editor must accept a six-second WAV.")
	app.editor.timeline.placed.emit(4.0, 0, false, 0)
	app.editor.timeline.placed.emit(4.0, 1, true, 0)
	app.editor.timeline.removed.emit(1)
	_check(chart.events.size() == 1 and not chart.events[0].spike, "Erasing a simultaneous spike must preserve the other lane.")
	app.editor.timeline.placed.emit(4.0, 1, true, 0)
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
	chart.zones[0].spawn_radius = Chart.MAX_SPAWN_RADIUS
	chart.zones[0].rotation_offset = -60.0
	chart.zones[0].center_rotation_speed = -90.0
	chart.zones[0].extra_input_sides = (1 << 1) | (1 << 5)
	chart.events.append({"beat": 3.0, "lane": 2, "spike": false, "slider_direction": -1})
	var with_zone := chart.record()
	_check(Chart.from_record(with_zone).record() == with_zone, "Offscreen spawn distance and slider direction must round-trip with the chart.")
	var invalid_slider := with_zone.duplicate(true)
	invalid_slider.events[1].slider_direction = 0
	_check(Chart.from_record(invalid_slider) == null, "A slider must have a left or right direction.")
	var old_zone := with_zone.duplicate(true)
	old_zone.zones[0].erase("center_rotation_speed")
	reopened = Chart.from_record(old_zone)
	_check(reopened.zones[0].center_rotation_speed == 0.0, "A previously saved zone must default to a stationary center.")
	var with_duplicate := with_zone.duplicate(true)
	with_duplicate.zones.append(Chart.new_zone(1.5))
	_check(Chart.from_record(with_duplicate) == null, "Two zones cannot share the same start marker.")
	var package := Package.pack(chart, wav)
	var unpacked := Package.unpack(package)
	_check(unpacked.has("chart") and unpacked.chart.record() == chart.record() and unpacked.audio == wav, "A chart package must preserve settings, notes, and the original audio bytes.")
	_check(Package.unpack(package.slice(0, package.size() - 1)).is_empty(), "A truncated chart package must be rejected.")
	if arguments.size() != 2:
		return
	library.directory = arguments[1]
	if arguments[0] == "write":
		_check(await library.save_chart(chart, wav) == "", "Native save must write the chart and audio.")
		chart.title = "Updated timing check"
		_check(await library.save_chart(chart, PackedByteArray()) == "", "Saving an existing chart must replace its metadata.")
		var exported := await library.export_package(chart.id)
		var shared_path := library.directory.path_join("Shared")
		_check(exported.has("bytes") and library.write_package_file(shared_path, exported.bytes).is_empty(), "A saved chart must export to a .lockchart file.")
		var readback := Library.read_package_file(shared_path + ".lockchart")
		_check(readback.has("bytes") and await library.import_package(readback.bytes) == "", "A chart package must import into the library as a copy.")
		chart.audio_id = Chart.new_id()
		_check(await library.save_chart(chart, PackedByteArray()) != "", "Missing replacement audio must reject the save.")
	elif arguments[0] == "read":
		var library_index: Dictionary = await library.list_charts()
		_check(library_index.charts.size() == 2, "The original chart and imported copy must appear after a fresh process starts.")
		var saved: Dictionary = await library.read_chart(chart.id)
		_check(saved.has("chart") and saved.chart.title == "Updated timing check", "The last successful native save must survive a restart.")
		_check(saved.has("stream") and is_equal_approx(saved.stream.get_length(), 6.0), "The saved song must reopen without another import.")
		_check(saved.has("chart") and saved.chart.zones == chart.zones, "Saved zone settings must survive a fresh process.")
		_check(saved.has("chart") and saved.chart.events == chart.events, "Saved sliders must survive a fresh process.")
		for entry in library_index.charts:
			if entry.id != chart.id:
				var imported := await library.read_chart(entry.id)
				_check(imported.has("chart") and imported.chart.audio_id != chart.audio_id and imported.chart.events == chart.events and imported.stream.data == saved.stream.data, "Import must create separate IDs and preserve the playable song.")

func _check_song_offsets(app, wav: PackedByteArray) -> void:
	var editor = app.editor
	var chart := Chart.new()
	editor._open_editor(chart, null)
	editor._accept_song({"name": "Trim.wav", "bytes": wav})
	editor._start_offset.value = 1.0
	editor._end_offset.value = 3.5
	for beat in [1.0, 2.0, 4.0, 5.0, 8.0]:
		editor.timeline.placed.emit(beat, 0, false, 0)
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
	editor.timeline.placed.emit(6.0, 0, true, 0)
	editor._seek(2.04)
	editor._add_zone_button.pressed.emit()
	_check(chart.zones.size() == 1 and chart.zones[0].beat == 4.0 and editor._zone_settings.visible, "Adding a zone must snap at the playhead and open its settings.")
	editor._zone_fields.rotation_offset.value = -120.0
	editor._zone_fields.start_speed.value = 80.0
	editor._zone_fields.center_rotation_speed.value = 120.0
	editor._zone_colors.background_color.color_changed.emit(Color("24364a"))
	editor._input_circles.get_popup().id_pressed.emit(1)
	_check(chart.zones[0].extra_input_sides == 2 and editor._input_circles.get_popup().is_item_checked(0), "Choosing an input side must update the zone and its menu.")
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
	_check(app.song.arena.background_track == editor.preview.background_track and Chart.background_at(app.song.arena.background_track, 2.75) == Color("24364a"), "Playtest and preview must share the edited zone background.")
	_check(app.song.session.input_circle_track == editor.preview.input_circle_track and Chart.input_mask_at(app.song.session.input_circle_track, 2.75) == 3, "Playtest and preview must share the enabled input sides.")
	app.song._leave()
	editor._delete_zone_button.pressed.emit()
	_check(chart.zones.is_empty() and editor._chart_settings.visible and chart.events.size() == 1, "Deleting a zone must restore chart settings and preserve its notes and spikes.")
	var undo := InputEventKey.new()
	undo.keycode = KEY_Z
	undo.ctrl_pressed = true
	undo.pressed = true
	editor._unhandled_key_input(undo)
	_check(chart.zones.size() == 1 and chart.zones[0].beat == 5.0, "Undo must restore the deleted zone at its moved start.")
	var timeline = editor.timeline
	timeline.placement = timeline.Placement.SLIDER_RIGHT
	click.position = Vector2(timeline._x_at(4.0), timeline._y_at(2))
	click.pressed = true
	timeline._gui_input(click)
	_check(chart.events.back().slider_direction == 1, "The selected placement tool must create a right slider from the grid.")
	timeline.moved.emit(1, 9.0, 4)
	_check(editor.preview.events.back().slider_direction == 1 and chart.events.back().lane == 4, "Moving a slider must preserve its arrow and update preview.")
	_check(is_equal_approx(Session.center_angle_at(editor.preview.slider_turns, 4.7), T.TIP_ANGLE + T.WHEEL_STEP), "Editor preview must apply the slider turn at its moved time.")
	_check(timeline.slider_turns == editor.preview.slider_turns, "The timeline and preview must share the same slider turns.")
	click.position = Vector2(timeline._x_at(4.7), timeline.RULER + timeline._plot_height() + timeline.TARGET_ROW * 0.5)
	timeline._gui_input(click)
	_check(is_equal_approx(timeline.playhead, 4.7), "Clicking the Target row must seek without placing an event.")
	editor._start_offset.value = 4.6
	_check(timeline.slider_turns.is_empty(), "The Target row must ignore sliders trimmed out of playback.")
	editor._start_offset.value = 0.0
	editor._select_zone(0)
	editor._zone_fields.spawn_radius.value = 680.0
	editor._zone_fields.end_speed.value = 320.0
	editor._zone_colors.polygon_start_color.color_changed.emit(Color("ff6700"))
	editor._zone_colors.polygon_end_color.color_changed.emit(Color("274a8c"))
	var expected := chart.zones[0].duplicate(true)
	editor._seek(5.0)
	editor._add_zone_button.pressed.emit()
	expected.beat = 10.0
	_check(chart.zones[1] == expected, "A new zone must copy every setting from the preceding zone.")
	editor._zone_fields.start_speed.value = 432.0
	editor._seek(4.75)
	editor._add_zone_button.pressed.emit()
	expected.beat = 9.5
	_check(chart.zones[1] == expected and chart.zones[2].start_speed == 432.0, "A zone inserted between markers must copy the earlier zone, even when the later marker is closer.")
	editor._zone_fields.rotation_offset.value = 45.0
	_check(chart.zones[0].rotation_offset == -120.0 and chart.zones[2].rotation_offset == -120.0, "Editing inherited settings must affect only the new zone.")
	editor._seek(0.5)
	editor._add_zone_button.pressed.emit()
	_check(chart.zones[0] == Chart.new_zone(1.0), "A zone with no preceding marker must use default settings.")

func _run() -> void:
	_check_judgment()
	_check_hit_bindings()
	_check_judgment_tints()
	_check_sliders()
	_check_zone_motion()
	_check_extra_input_circles()
	_check_center_rotation()
	_check_zone_colors()
	var app := AppScene.instantiate()
	root.add_child(app)
	_check_master_volume(app)
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
