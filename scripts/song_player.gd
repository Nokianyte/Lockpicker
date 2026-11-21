extends Control

signal exit_requested

const Arena = preload("res://scripts/song_arena.gd")
const Chart = preload("res://scripts/song_chart.gd")
const Session = preload("res://scripts/song_session.gd")
const Transport = preload("res://scripts/song_transport.gd")
const UI = preload("res://scripts/chart_ui.gd")
const Palette = preload("res://scripts/palette.gd")

var transport := Transport.new()
var arena := Arena.new()
var session: Session

var _schedule: Array[Dictionary] = []
var _stream: AudioStreamWAV
var _cursor := 0.0
var _paused := false
var _finished := false
var _title: Label
var _counts: Label
var _feedback: Label
var _energy: ProgressBar
var _veil: ColorRect
var _result: Label
var _summary: Label
var _continue: Button

func _ready() -> void:
	theme = UI.theme()
	add_child(transport)
	transport.song_ended.connect(_song_ended)
	var background := ColorRect.new()
	background.color = UI.BACKGROUND
	add_child(background)
	background.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var margins := UI.margins(22)
	add_child(margins)
	margins.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var content := VBoxContainer.new()
	margins.add_child(content)
	var header := HBoxContainer.new()
	content.add_child(header)
	header.add_child(UI.button("‹ Back", _leave))
	_title = UI.label("", 21)
	_title.size_flags_horizontal = SIZE_EXPAND_FILL
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	header.add_child(_title)
	_counts = UI.label("", 16)
	header.add_child(_counts)
	_energy = ProgressBar.new()
	_energy.max_value = Session.MAX_ENERGY
	_energy.show_percentage = false
	_energy.custom_minimum_size.y = 8
	_energy.add_theme_stylebox_override("background", UI.box(Palette.PANEL, Palette.BORDER))
	_energy.add_theme_stylebox_override("fill", UI.box(Palette.RED, Palette.RED))
	content.add_child(_energy)
	var stage := PanelContainer.new()
	stage.size_flags_vertical = SIZE_EXPAND_FILL
	content.add_child(stage)
	stage.add_child(arena)
	var footer := HBoxContainer.new()
	content.add_child(footer)
	var instructions := UI.label("Wheel or Left / Right Arrow  Turn ring      Z / X  Tap      Esc  Back", 15, UI.MUTED)
	instructions.size_flags_horizontal = SIZE_EXPAND_FILL
	footer.add_child(instructions)
	_feedback = UI.label("", 18, UI.ACCENT)
	footer.add_child(_feedback)
	_build_result()

func _build_result() -> void:
	_veil = ColorRect.new()
	_veil.color = Color(Palette.PAPER, 0.94)
	add_child(_veil)
	_veil.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var center := CenterContainer.new()
	_veil.add_child(center)
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(content)
	_result = UI.label("", 34)
	_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_result)
	_summary = UI.label("", 16, UI.MUTED)
	_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_summary)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(actions)
	actions.add_child(UI.button("Back", _leave))
	_continue = UI.button("Retry", _continue_run, true)
	actions.add_child(_continue)
	_veil.hide()

func start_run(chart: Chart, stream: AudioStreamWAV, cursor: float) -> void:
	_schedule = chart.schedule()
	_stream = stream
	_cursor = clampf(cursor, 0.0, stream.get_length())
	_title.text = chart.title
	_restart()

func _restart() -> void:
	_paused = false
	_finished = false
	_veil.hide()
	transport.load_song(_stream)
	var start := maxf(0.0, _cursor - Session.LEAD_IN)
	session = Session.new()
	session.setup(_schedule, transport.duration(), _cursor, start)
	arena.session = session
	transport.start_at(start)
	_update_view()

func _process(_delta: float) -> void:
	if not is_visible_in_tree() or session == null or _paused or _finished:
		return
	session.advance_to(transport.song_time())
	_update_view()
	if session.energy == 0:
		_end_run(false)

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or session == null:
		return
	if event is InputEventKey:
		_key_input(event)
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		get_viewport().set_input_as_handled()
		_turn(-1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0)

func _key_input(event: InputEventKey) -> void:
	if event.keycode not in [KEY_ESCAPE, KEY_LEFT, KEY_RIGHT] and not event.is_action("song_hit"):
		return
	get_viewport().set_input_as_handled()
	if not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_ESCAPE:
			_leave()
		KEY_LEFT:
			_turn(-1.0)
		KEY_RIGHT:
			_turn(1.0)
		_:
			if _paused or _finished:
				_continue_run()
			else:
				session.press(transport.song_time())
				_update_view()

func _turn(direction: float) -> void:
	if not _paused and not _finished:
		session.rotate(direction, transport.song_time())

func pause_run() -> void:
	if not is_visible_in_tree() or session == null or _paused or _finished:
		return
	transport.pause_song()
	session.advance_to(transport.song_time())
	_update_view()
	if session.energy == 0:
		_end_run(false)
		return
	_paused = true
	_result.text = "Paused"
	_summary.text = "Press Z or X to resume."
	_continue.text = "Resume"
	_veil.show()

func _continue_run() -> void:
	if _paused:
		_paused = false
		_veil.hide()
		transport.resume_song()
	else:
		_restart()

func _song_ended() -> void:
	if is_visible_in_tree() and session != null and not _finished:
		session.advance_to(transport.duration(), true)
		_update_view()
		_end_run(session.energy > 0)

func _end_run(success: bool) -> void:
	_finished = true
	transport.pause_song()
	_result.text = "Chart clear" if success else "Out of energy"
	_summary.text = "%d hits  ·  %d misses  ·  %d spikes hit" % [session.hits, session.misses, session.spike_hits]
	_continue.text = "Retry"
	_veil.show()

func _leave() -> void:
	transport.pause_song()
	exit_requested.emit()

func _update_view() -> void:
	arena.queue_redraw()
	_counts.text = "%d hits    %d combo" % [session.hits, session.combo]
	_energy.value = session.energy
	_feedback.text = session.feedback if session.time - session.feedback_at < 0.65 else ""
