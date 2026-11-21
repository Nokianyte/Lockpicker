extends Control

signal game_requested
signal play_requested(chart, stream: AudioStreamWAV, cursor: float, from_editor: bool)

const Arena = preload("res://scripts/song_arena.gd")
const Chart = preload("res://scripts/song_chart.gd")
const Library = preload("res://scripts/chart_library.gd")
const Session = preload("res://scripts/song_session.gd")
const T = preload("res://scripts/tuning.gd")
const Timeline = preload("res://scripts/chart_timeline.gd")
const Transport = preload("res://scripts/song_transport.gd")
const Waveform = preload("res://scripts/song_waveform.gd")
const UI = preload("res://scripts/chart_ui.gd")

var library: Library
var chart: Chart
var transport := Transport.new()
var timeline := Timeline.new()
var preview := Arena.new()

var _waveform := Waveform.new()
var _audio := PackedByteArray()
var _undo: Array = []
var _dirty := false
var _busy := false
var _library_screen: VBoxContainer
var _editor_screen: VBoxContainer
var _library_rows: VBoxContainer
var _library_status: Label
var _back_to_game: Button
var _status: Label
var _title: LineEdit
var _song_name: Label
var _time: Label
var _bpm: SpinBox
var _offset: SpinBox
var _start_offset: SpinBox
var _end_offset: SpinBox
var _grid: OptionButton
var _transport_button: Button
var _play_button: Button
var _cursor_button: Button
var _save_button: Button
var _import_button: Button
var _add_zone_button: Button
var _delete_zone_button: Button
var _chart_settings: VBoxContainer
var _zone_settings: VBoxContainer
var _zone_time: Label
var _zone_fields: Dictionary[String, SpinBox] = {}
var _file_dialog: FileDialog
var _leave_dialog: ConfirmationDialog

func _ready() -> void:
	theme = UI.theme()
	add_child(transport)
	add_child(_waveform)
	var background := ColorRect.new()
	background.color = UI.BACKGROUND
	add_child(background)
	background.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var margins := UI.margins(22)
	add_child(margins)
	margins.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var stack := Control.new()
	margins.add_child(stack)
	_library_screen = _build_library()
	_editor_screen = _build_editor()
	for screen in [_library_screen, _editor_screen]:
		stack.add_child(screen)
		screen.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_editor_screen.hide()

	_file_dialog = FileDialog.new()
	_file_dialog.title = "Import a song"
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.filters = PackedStringArray(["*.mp3, *.wav ; MP3 or WAV audio"])
	_file_dialog.file_selected.connect(func(path: String) -> void: _accept_song(Library.read_song_file(path)))
	add_child(_file_dialog)
	_leave_dialog = ConfirmationDialog.new()
	_leave_dialog.title = "Unsaved chart"
	_leave_dialog.dialog_text = "Discard the edits since your last save?"
	_leave_dialog.ok_button_text = "Discard edits"
	_leave_dialog.confirmed.connect(show_charts)
	add_child(_leave_dialog)

	timeline.sought.connect(_seek)
	timeline.placed.connect(_place)
	timeline.removed.connect(_remove)
	timeline.moved.connect(_move)
	timeline.selected.connect(_select)
	timeline.zone_selected.connect(_select_zone)
	timeline.zone_moved.connect(_move_zone)
	transport.song_ended.connect(func() -> void:
		_update_transport_button()
		_update_position()
	)
	_waveform.updated.connect(_waveform_updated)
	resized.connect(_resize_panels)

func _build_library() -> VBoxContainer:
	var screen := VBoxContainer.new()
	var header := HBoxContainer.new()
	screen.add_child(header)
	_back_to_game = UI.button("‹ Rhythm", func() -> void:
		if not _busy:
			game_requested.emit()
	)
	header.add_child(_back_to_game)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var book := VBoxContainer.new()
	book.size_flags_horizontal = SIZE_EXPAND_FILL
	var title := HBoxContainer.new()
	book.add_child(title)
	var heading := UI.label("Charts", 36)
	heading.size_flags_horizontal = SIZE_EXPAND_FILL
	title.add_child(heading)
	title.add_child(UI.button("New chart", func() -> void:
		if not _busy:
			_open_editor(Chart.new(), null)
	, true))
	_library_status = UI.label("", 15, UI.MUTED)
	book.add_child(_library_status)
	_library_rows = VBoxContainer.new()
	book.add_child(_library_rows)
	scroll.add_child(book)
	screen.add_child(scroll)
	return screen

func set_game_label(label: String) -> void:
	_back_to_game.text = "‹ " + label

func _build_editor() -> VBoxContainer:
	var screen := VBoxContainer.new()
	screen.add_child(_build_header())
	var upper := HBoxContainer.new()
	upper.name = "PreviewAndSettings"
	screen.add_child(upper)
	var preview_panel := PanelContainer.new()
	preview_panel.size_flags_horizontal = SIZE_EXPAND_FILL
	preview_panel.size_flags_stretch_ratio = 0.76
	preview_panel.add_child(preview)
	upper.add_child(preview_panel)
	upper.add_child(_build_settings())
	screen.add_child(_build_transport())
	timeline.size_flags_vertical = SIZE_EXPAND_FILL
	timeline.custom_minimum_size.y = 212
	screen.add_child(timeline)
	var footer := HBoxContainer.new()
	screen.add_child(footer)
	var tool := OptionButton.new()
	tool.add_item("Tap note", Timeline.Placement.NOTE)
	tool.add_item("Spike", Timeline.Placement.SPIKE)
	tool.add_item("Left slider", Timeline.Placement.SLIDER_LEFT)
	tool.add_item("Right slider", Timeline.Placement.SLIDER_RIGHT)
	tool.tooltip_text = "Choose what a left click places on the timeline."
	tool.item_selected.connect(func(index: int) -> void: timeline.placement = tool.get_item_id(index))
	footer.add_child(tool)
	var shortcuts := UI.label("Shift-click  Spike    Right-click  Delete    Ctrl-wheel  Zoom", 13, UI.MUTED)
	shortcuts.size_flags_horizontal = SIZE_EXPAND_FILL
	footer.add_child(shortcuts)
	_status = UI.label("", 14, UI.ACCENT)
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_status.size_flags_horizontal = SIZE_EXPAND_FILL
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	footer.add_child(_status)
	return screen

func _build_header() -> HBoxContainer:
	var bar := HBoxContainer.new()
	bar.add_child(UI.label("Level Editor", 23))
	bar.add_child(UI.button("‹ Charts", _go_back))
	_title = LineEdit.new()
	_title.placeholder_text = "Chart name"
	_title.max_length = 100
	_title.size_flags_horizontal = SIZE_EXPAND_FILL
	_title.text_changed.connect(func(value: String) -> void:
		chart.title = value
		_set_dirty()
	)
	bar.add_child(_title)
	_save_button = UI.button("Save", _save_chart)
	bar.add_child(_save_button)
	_play_button = UI.button("Playtest", _play.bind(false), true)
	bar.add_child(_play_button)
	return bar

func _build_settings() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = SIZE_EXPAND_FILL
	_chart_settings = VBoxContainer.new()
	panel.add_child(_chart_settings)
	var settings := _chart_settings
	settings.add_child(UI.label("Info / Settings", 20))
	var song := HBoxContainer.new()
	settings.add_child(song)
	_song_name = UI.label("", 14, UI.MUTED)
	_song_name.size_flags_horizontal = SIZE_EXPAND_FILL
	_song_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	song.add_child(_song_name)
	_import_button = UI.button("Import Audio", _import_song)
	song.add_child(_import_button)
	var offset_row := HBoxContainer.new()
	settings.add_child(offset_row)
	offset_row.add_child(UI.label("First beat", 15))
	_offset = _spin(-3600.0, 3600.0, 0.001, 118)
	_offset.suffix = "s"
	_offset.value_changed.connect(func(value: float) -> void:
		chart.offset = value
		_timing_changed()
	)
	offset_row.add_child(_offset)
	var trim_row := HBoxContainer.new()
	settings.add_child(trim_row)
	trim_row.add_child(UI.label("Start offset", 15))
	_start_offset = _spin(0.0, 0.0, 0.001, 96)
	_start_offset.suffix = "s"
	_start_offset.tooltip_text = "Seconds skipped from the beginning of the song."
	_start_offset.value_changed.connect(func(value: float) -> void:
		chart.start_offset = value
		_update_playback_range()
		_set_dirty()
	)
	trim_row.add_child(_start_offset)
	trim_row.add_child(UI.label("End offset", 15))
	_end_offset = _spin(0.0, 0.0, 0.001, 96)
	_end_offset.suffix = "s"
	_end_offset.tooltip_text = "Seconds skipped from the end of the song."
	_end_offset.value_changed.connect(func(value: float) -> void:
		chart.end_offset = value
		_update_playback_range()
		_set_dirty()
	)
	trim_row.add_child(_end_offset)
	var waveform := CheckButton.new()
	waveform.text = "Waveform"
	waveform.button_pressed = true
	waveform.toggled.connect(func(value: bool) -> void:
		timeline.show_waveform = value
		timeline.queue_redraw()
	)
	settings.add_child(waveform)
	panel.add_child(_build_zone_settings())
	return panel

func _build_zone_settings() -> VBoxContainer:
	_zone_settings = VBoxContainer.new()
	var header := HBoxContainer.new()
	_zone_settings.add_child(header)
	var title := UI.label("Zone settings", 20)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(title)
	_zone_time = UI.label("", 14, UI.MUTED)
	header.add_child(_zone_time)
	header.add_child(UI.button("‹ Chart", _select_zone.bind(-1)))
	_delete_zone_button = UI.button("Delete zone", _delete_zone)
	header.add_child(_delete_zone_button)
	var fields := GridContainer.new()
	fields.columns = 4
	fields.add_theme_constant_override("h_separation", 8)
	fields.add_theme_constant_override("v_separation", 6)
	_zone_settings.add_child(fields)
	_add_zone_field(fields, "Spawn distance", "spawn_radius", Chart.MIN_SPAWN_RADIUS, Chart.MAX_SPAWN_RADIUS, 1.0, "", "Initial polygon radius from the center. Larger values can start outside the arena.")
	_add_zone_field(fields, "Start speed", "start_speed", Chart.MIN_APPROACH_SPEED, Chart.MAX_APPROACH_SPEED, 1.0, "", "Approach speed at the beginning, in units per second.")
	_add_zone_field(fields, "Rotation offset", "rotation_offset", -360.0, 360.0, 0.1, "°", "Initial rotation relative to the charted direction.")
	_add_zone_field(fields, "End speed", "end_speed", Chart.MIN_APPROACH_SPEED, Chart.MAX_APPROACH_SPEED, 1.0, "", "Approach speed at the end, in units per second.")
	_add_zone_field(fields, "Center rotation speed", "center_rotation_speed", -Chart.MAX_CENTER_ROTATION_SPEED, Chart.MAX_CENTER_ROTATION_SPEED, 0.1, "°/s", "Rotates the entire arena during this zone. Positive values turn clockwise and negative values turn counterclockwise.")
	_zone_settings.add_child(HSeparator.new())
	_zone_settings.add_child(UI.label("Additional effects", 15, UI.MUTED))
	_zone_settings.hide()
	return _zone_settings

func _add_zone_field(parent: GridContainer, label: String, key: String, minimum: float, maximum: float, step: float, suffix: String, hint: String) -> void:
	parent.add_child(UI.label(label, 14))
	var field := _spin(minimum, maximum, step, 77)
	field.size_flags_horizontal = SIZE_EXPAND_FILL
	field.suffix = suffix
	field.tooltip_text = hint
	field.value_changed.connect(_change_zone.bind(key))
	parent.add_child(field)
	_zone_fields[key] = field

func _build_transport() -> HBoxContainer:
	var bar := HBoxContainer.new()
	_transport_button = UI.button("Play", _toggle_preview)
	_transport_button.custom_minimum_size.x = 81
	bar.add_child(_transport_button)
	_time = UI.label("0:00.000", 19, UI.ACCENT)
	_time.custom_minimum_size.x = 100
	bar.add_child(_time)
	_bpm = _spin(Chart.MIN_BPM, Chart.MAX_BPM, 0.01, 112)
	_bpm.suffix = "BPM"
	_bpm.value_changed.connect(func(value: float) -> void:
		chart.bpm = value
		_timing_changed()
	)
	bar.add_child(_bpm)
	_grid = OptionButton.new()
	_grid.custom_minimum_size.x = 112
	for step in Chart.SUBDIVISIONS:
		_grid.add_item("1/%d Grid" % step, step)
	_grid.item_selected.connect(func(index: int) -> void:
		chart.subdivision = _grid.get_item_id(index)
		_set_dirty()
		timeline.queue_redraw()
	)
	bar.add_child(_grid)
	_add_zone_button = UI.button("+ Zone", _add_zone)
	_add_zone_button.tooltip_text = "Add a zone at the nearest grid line to the playhead. Click its diamond marker to edit or drag it to move."
	bar.add_child(_add_zone_button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	bar.add_child(spacer)
	_cursor_button = UI.button("Playtest from cursor", _play.bind(true))
	bar.add_child(_cursor_button)
	return bar

func _spin(minimum: float, maximum: float, step: float, width: float) -> SpinBox:
	var field := SpinBox.new()
	field.min_value = minimum
	field.max_value = maximum
	field.step = step
	field.custom_minimum_size.x = width
	field.update_on_text_changed = false
	return field

func _resize_panels() -> void:
	var upper := _editor_screen.get_node("PreviewAndSettings") as Control
	upper.custom_minimum_size.y = clampf(size.y * 0.36, 205.0, 310.0)

func show_charts() -> void:
	transport.pause_song()
	_editor_screen.hide()
	_library_screen.show()
	_busy = true
	_library_status.text = "Loading charts…"
	for row in _library_rows.get_children():
		_library_rows.remove_child(row)
		row.queue_free()
	var result: Dictionary = await library.list_charts()
	_busy = false
	if result.has("error"):
		_library_status.text = result.error
		return
	_library_status.text = "Create a chart and import an MP3 or WAV song to start." if result.charts.is_empty() else ""
	for entry in result.charts:
		_add_library_row(entry)

func _add_library_row(entry: Dictionary) -> void:
	var panel := PanelContainer.new()
	_library_rows.add_child(panel)
	var row := HBoxContainer.new()
	panel.add_child(row)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = SIZE_EXPAND_FILL
	info.add_child(UI.label(entry.title, 20))
	info.add_child(UI.label(entry.audio_name, 14, UI.MUTED))
	row.add_child(info)
	row.add_child(UI.button("Edit", _open_saved.bind(entry.id, false)))
	row.add_child(UI.button("Play", _open_saved.bind(entry.id, true), true))

func _open_saved(id: String, play: bool) -> void:
	if _busy:
		return
	if play:
		transport.unlock_audio()
	_busy = true
	var result: Dictionary = await library.read_chart(id)
	_busy = false
	if result.has("error"):
		_library_status.text = result.error
	elif play:
		play_requested.emit(result.chart, result.stream, 0.0, false)
	else:
		_open_editor(result.chart, result.stream)

func _open_editor(draft: Chart, stream: AudioStreamWAV) -> void:
	chart = draft
	_undo.clear()
	_audio = PackedByteArray()
	_dirty = false
	_status.text = ""
	_title.text = chart.title
	_bpm.set_value_no_signal(chart.bpm)
	_offset.set_value_no_signal(chart.offset)
	_grid.select(Chart.SUBDIVISIONS.find(chart.subdivision))
	timeline.chart = chart
	timeline.reset_view()
	_select_zone(-1)
	_load_song(stream)
	_library_screen.hide()
	_editor_screen.show()
	_resize_panels()

func _go_back() -> void:
	if _busy:
		return
	if _dirty:
		pause_preview()
		_leave_dialog.popup_centered()
	else:
		show_charts()

func _load_song(stream: AudioStreamWAV) -> void:
	transport.load_song(stream)
	timeline.duration = transport.duration()
	_song_name.text = "No song selected" if stream == null else chart.audio_name
	_song_name.tooltip_text = chart.audio_name
	_waveform.begin(stream)
	_update_playback_range()
	_refresh_actions()

func _update_playback_range() -> void:
	var length := transport.duration()
	chart.start_offset = minf(chart.start_offset, Chart.max_song_offset(length))
	chart.end_offset = minf(chart.end_offset, Chart.max_song_offset(length, chart.start_offset))
	var bounds := chart.playback_bounds(length)
	transport.set_playback_range(bounds.start, bounds.end)
	timeline.playback_start = bounds.start
	timeline.playback_end = bounds.end
	_start_offset.set_block_signals(true)
	_end_offset.set_block_signals(true)
	_start_offset.max_value = Chart.max_song_offset(length, chart.end_offset)
	_end_offset.max_value = Chart.max_song_offset(length, chart.start_offset)
	_start_offset.set_value_no_signal(chart.start_offset)
	_end_offset.set_value_no_signal(chart.end_offset)
	_start_offset.set_block_signals(false)
	_end_offset.set_block_signals(false)
	_refresh_schedule()
	_update_transport_button()
	_update_position(true)

func _import_song() -> void:
	if _busy:
		return
	pause_preview()
	if not OS.has_feature("web"):
		_file_dialog.popup_centered_ratio(0.68)
		return
	_busy = true
	_refresh_actions()
	var result: Dictionary = await library.pick_web_song()
	_busy = false
	_accept_song(result)

func _accept_song(result: Dictionary) -> void:
	_refresh_actions()
	if result.is_empty():
		return
	if result.has("error"):
		_show_status(result.error, true)
		return
	_busy = true
	_refresh_actions()
	_show_status("Reading audio…")
	var stream := await library.decode_song(result.bytes, result.name)
	_busy = false
	if stream == null:
		_refresh_actions()
		_show_status("Could not open this MP3 or WAV file.", true)
		return
	chart.audio_id = Chart.new_id()
	chart.audio_name = result.name
	_audio = result.bytes
	timeline.reset_view()
	_select_zone(-1)
	_load_song(stream)
	_set_dirty()
	_show_status("Song imported")

func _save_chart() -> void:
	if _busy or transport.song == null:
		return
	if chart.title.strip_edges().is_empty():
		_show_status("Enter a chart name.", true)
		_title.grab_focus()
		return
	pause_preview()
	_busy = true
	_refresh_actions()
	var snapshot := Chart.from_record(chart.record())
	if snapshot == null:
		_busy = false
		_refresh_actions()
		_show_status("The chart contains invalid timing, events, or zones.", true)
		return
	var error: String = await library.save_chart(snapshot, _audio)
	_busy = false
	if error.is_empty():
		_dirty = snapshot.record() != chart.record()
		_audio = PackedByteArray()
		_show_status("Saved")
	else:
		_show_status(error, true)
	_refresh_actions()

func _refresh_actions() -> void:
	var no_song := transport.song == null
	_import_button.disabled = _busy
	_save_button.disabled = _busy or no_song
	_play_button.disabled = _busy or no_song
	_cursor_button.disabled = _busy or transport.song_time() >= transport.playback_end
	_transport_button.disabled = no_song
	_add_zone_button.disabled = _busy or no_song
	_delete_zone_button.disabled = _busy
	for field in _zone_fields.values():
		field.editable = not _busy
	_start_offset.editable = not _busy and not no_song
	_end_offset.editable = not _busy and not no_song

func _show_status(message: String, error: bool = false) -> void:
	_status.text = message
	_status.add_theme_color_override("font_color", UI.ERROR if error else UI.ACCENT)
	_status.tooltip_text = message

func _set_dirty() -> void:
	_dirty = true
	_show_status("Unsaved edits")

func _timing_changed() -> void:
	_set_dirty()
	_refresh_zone_settings()
	_refresh_schedule()
	timeline.queue_redraw()

func _refresh_schedule() -> void:
	preview.events = chart.schedule(transport.playback_start, transport.playback_end)
	preview.slider_turns = Session.build_slider_turns(preview.events)
	preview.approach_horizon = chart.approach_horizon()
	preview.center_rotation_track = chart.center_rotation_track()
	preview.queue_redraw()

func _remember_edit() -> void:
	_undo.append({"events": chart.events.duplicate(), "zones": chart.zones.duplicate()})
	if _undo.size() > 100:
		_undo.pop_front()

func _place(beat: float, lane: int, spike: bool, slider_direction: int = 0) -> void:
	if chart.event_at(beat, lane) >= 0:
		return
	_remember_edit()
	var item := {"beat": beat, "lane": lane, "spike": spike}
	if slider_direction != 0:
		item.slider_direction = slider_direction
	chart.events.append(item)
	_after_edit(chart.events.size() - 1)

func _remove(index: int) -> void:
	_remember_edit()
	chart.events.remove_at(index)
	_after_edit(-1)

func _move(index: int, beat: float, lane: int) -> void:
	if chart.event_at(beat, lane) >= 0:
		return
	_remember_edit()
	var item := chart.events[index].duplicate()
	item.beat = beat
	item.lane = lane
	chart.events[index] = item
	_after_edit(index)

func _select(index: int) -> void:
	timeline.selection = index
	timeline.queue_redraw()

func _add_zone() -> void:
	if _busy or transport.song == null:
		return
	var first_tick := ceili(chart.beat_at(0.0) * chart.subdivision)
	var last_tick := ceili(chart.beat_at(transport.duration()) * chart.subdivision) - 1
	if first_tick > last_tick:
		_show_status("There is no grid line inside the song.", true)
		return
	var tick := roundi(chart.beat_at(transport.song_time()) * chart.subdivision)
	var beat := float(clampi(tick, first_tick, last_tick)) / chart.subdivision
	var existing := chart.zone_at(beat)
	if existing >= 0:
		_select_zone(existing)
		return
	_remember_edit()
	chart.zones.append(Chart.new_zone(beat))
	chart.sort_zones()
	_after_zone_edit(chart.zone_at(beat))

func _select_zone(index: int) -> void:
	timeline.zone_selection = index
	_chart_settings.visible = index < 0
	_zone_settings.visible = index >= 0
	_refresh_zone_settings()
	timeline.queue_redraw()

func _refresh_zone_settings() -> void:
	if timeline.zone_selection < 0:
		return
	var zone := chart.zones[timeline.zone_selection]
	_zone_time.text = UI.clock(chart.time_at(zone.beat))
	for key in _zone_fields:
		_zone_fields[key].set_value_no_signal(zone[key])

func _move_zone(index: int, beat: float) -> void:
	if _busy or chart.zone_at(beat) >= 0:
		return
	_remember_edit()
	var zone := chart.zones[index].duplicate()
	zone.beat = beat
	chart.zones[index] = zone
	chart.sort_zones()
	_after_zone_edit(chart.zone_at(beat))

func _change_zone(value: float, key: String) -> void:
	var index := timeline.zone_selection
	if _busy or index < 0:
		return
	_remember_edit()
	var zone := chart.zones[index].duplicate()
	zone[key] = value
	chart.zones[index] = zone
	_set_dirty()
	_refresh_schedule()

func _delete_zone() -> void:
	if _busy or timeline.zone_selection < 0:
		return
	_remember_edit()
	chart.zones.remove_at(timeline.zone_selection)
	_after_zone_edit(-1)

func _after_zone_edit(selection: int) -> void:
	timeline.cancel_drag()
	_select_zone(selection)
	_set_dirty()
	_refresh_schedule()

func _after_edit(selection: int) -> void:
	timeline.cancel_drag()
	_select(selection)
	_set_dirty()
	_refresh_schedule()

func _waveform_updated() -> void:
	timeline.waveform = _waveform.peaks
	timeline.waveform_completed = _waveform.completed
	timeline.waveform_bins_per_second = _waveform.bins_per_second
	timeline.queue_redraw()

func _toggle_preview() -> void:
	if transport.running:
		pause_preview()
	else:
		if transport.song_time() >= transport.playback_end:
			transport.seek_to(transport.playback_start)
		transport.resume_song()
		_update_transport_button()

func _seek(seconds: float) -> void:
	transport.seek_to(seconds)
	_update_position()

func pause_preview() -> void:
	transport.pause_song()
	_update_transport_button()
	_update_position()

func _update_transport_button() -> void:
	_transport_button.text = "Pause" if transport.running else "Play"

func _update_position(follow: bool = false) -> void:
	var time := transport.song_time()
	_time.text = UI.clock(time)
	_cursor_button.disabled = _busy or time >= transport.playback_end
	timeline.update_playhead(time, follow or transport.running)
	preview.song_time = time
	preview.queue_redraw()

func _play(from_cursor: bool) -> void:
	if not _busy and transport.song != null:
		pause_preview()
		var cursor := transport.song_time() if from_cursor else transport.playback_start
		if cursor < transport.playback_end:
			play_requested.emit(chart, transport.song, cursor, true)

func _process(_delta: float) -> void:
	if is_visible_in_tree() and _editor_screen.visible and transport.running:
		_update_position()

func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not _editor_screen.visible or not event is InputEventKey or not event.pressed or event.echo:
		return
	if (event.ctrl_pressed or event.meta_pressed) and event.keycode == KEY_Z and not _undo.is_empty():
		var snapshot: Dictionary = _undo.pop_back()
		var zone_beat := -INF if timeline.zone_selection < 0 else float(chart.zones[timeline.zone_selection].beat)
		chart.events.assign(snapshot.events)
		chart.zones.assign(snapshot.zones)
		_select_zone(chart.zone_at(zone_beat))
		_after_edit(-1)
		get_viewport().set_input_as_handled()
