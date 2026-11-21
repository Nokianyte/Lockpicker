extends Control

signal arcade_requested
signal play_requested(chart, stream: AudioStreamWAV, cursor: float, from_editor: bool)

const Arena = preload("res://scripts/song_arena.gd")
const Chart = preload("res://scripts/song_chart.gd")
const Library = preload("res://scripts/chart_library.gd")
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
var _status: Label
var _title: LineEdit
var _song_name: Label
var _time: Label
var _bpm: SpinBox
var _offset: SpinBox
var _grid: OptionButton
var _transport_button: Button
var _play_button: Button
var _cursor_button: Button
var _save_button: Button
var _import_button: Button
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
	_file_dialog.title = "Import a WAV song"
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.filters = PackedStringArray(["*.wav ; WAV audio"])
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
	header.add_child(UI.button("‹ Arcade", func() -> void:
		if not _busy:
			arcade_requested.emit()
	))
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
	var shortcuts := UI.label("Click  Note    Shift-click  Spike    Right-click  Delete    Ctrl-wheel  Zoom", 13, UI.MUTED)
	shortcuts.size_flags_horizontal = SIZE_EXPAND_FILL
	footer.add_child(shortcuts)
	_status = UI.label("", 14, UI.MINT)
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
	var settings := VBoxContainer.new()
	panel.add_child(settings)
	settings.add_child(UI.label("Info / Settings", 20))
	var song := HBoxContainer.new()
	settings.add_child(song)
	_song_name = UI.label("", 14, UI.MUTED)
	_song_name.size_flags_horizontal = SIZE_EXPAND_FILL
	_song_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	song.add_child(_song_name)
	_import_button = UI.button("Import WAV", _import_song)
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
	var waveform := CheckButton.new()
	waveform.text = "Waveform"
	waveform.button_pressed = true
	waveform.toggled.connect(func(value: bool) -> void:
		timeline.show_waveform = value
		timeline.queue_redraw()
	)
	settings.add_child(waveform)
	return panel

func _build_transport() -> HBoxContainer:
	var bar := HBoxContainer.new()
	_transport_button = UI.button("Play", _toggle_preview)
	_transport_button.custom_minimum_size.x = 81
	bar.add_child(_transport_button)
	_time = UI.label("0:00.000", 19, UI.GOLD)
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
	_library_status.text = "Create a chart and import a WAV song to start." if result.charts.is_empty() else ""
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
	_audio.clear()
	_dirty = false
	_status.text = ""
	_title.text = chart.title
	_bpm.set_value_no_signal(chart.bpm)
	_offset.set_value_no_signal(chart.offset)
	_grid.select(Chart.SUBDIVISIONS.find(chart.subdivision))
	timeline.chart = chart
	timeline.reset_view()
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
	_refresh_schedule()
	_update_transport_button()
	_update_position()
	_refresh_actions()

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
	var stream := Library.decode_song(result.bytes)
	if stream == null:
		_show_status("Could not open this WAV file.", true)
		return
	chart.audio_id = Chart.new_id()
	chart.audio_name = result.name
	_audio = result.bytes
	timeline.reset_view()
	_load_song(stream)
	_set_dirty()
	_show_status("Song imported")

func _save_chart() -> void:
	if _busy or transport.stream == null:
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
		_show_status("The chart contains invalid timing or events.", true)
		return
	var error: String = await library.save_chart(snapshot, _audio)
	_busy = false
	if error.is_empty():
		_dirty = snapshot.record() != chart.record()
		_audio.clear()
		_show_status("Saved")
	else:
		_show_status(error, true)
	_refresh_actions()

func _refresh_actions() -> void:
	var no_song := transport.stream == null
	_import_button.disabled = _busy
	_save_button.disabled = _busy or no_song
	_play_button.disabled = _busy or no_song
	_cursor_button.disabled = _busy or no_song
	_transport_button.disabled = no_song

func _show_status(message: String, error: bool = false) -> void:
	_status.text = message
	_status.add_theme_color_override("font_color", UI.RED if error else UI.MINT)
	_status.tooltip_text = message

func _set_dirty() -> void:
	_dirty = true
	_show_status("Unsaved edits")

func _timing_changed() -> void:
	_set_dirty()
	_refresh_schedule()
	timeline.queue_redraw()

func _refresh_schedule() -> void:
	preview.events = chart.schedule()
	preview.queue_redraw()

func _edit_events() -> void:
	_undo.append(chart.events.duplicate())
	if _undo.size() > 100:
		_undo.pop_front()

func _place(beat: float, lane: int, spike: bool) -> void:
	if chart.event_at(beat, lane) >= 0:
		return
	_edit_events()
	chart.events.append({"beat": beat, "lane": lane, "spike": spike})
	_after_edit(chart.events.size() - 1)

func _remove(index: int) -> void:
	_edit_events()
	chart.events.remove_at(index)
	_after_edit(-1)

func _move(index: int, beat: float, lane: int) -> void:
	if chart.event_at(beat, lane) >= 0:
		return
	_edit_events()
	chart.events[index] = {"beat": beat, "lane": lane, "spike": chart.events[index].spike}
	_after_edit(index)

func _select(index: int) -> void:
	timeline.selection = index
	timeline.queue_redraw()

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
		if transport.song_time() >= transport.duration():
			transport.seek_to(0.0)
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

func _update_position() -> void:
	var time := transport.song_time()
	_time.text = UI.clock(time)
	timeline.update_playhead(time, transport.running)
	preview.song_time = time
	preview.queue_redraw()

func _play(from_cursor: bool) -> void:
	if not _busy and transport.stream != null:
		pause_preview()
		play_requested.emit(chart, transport.stream, transport.song_time() if from_cursor else 0.0, true)

func _process(_delta: float) -> void:
	if is_visible_in_tree() and _editor_screen.visible and transport.running:
		_update_position()

func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not _editor_screen.visible or not event is InputEventKey or not event.pressed or event.echo:
		return
	if (event.ctrl_pressed or event.meta_pressed) and event.keycode == KEY_Z and not _undo.is_empty():
		chart.events.assign(_undo.pop_back())
		_after_edit(-1)
		get_viewport().set_input_as_handled()
