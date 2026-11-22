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
var _cursor := 0.0
var _paused := false
var _finished := false
var _title: Label
var _hit_count: Label
var _feedback: Label
var _energy: ProgressBar
var _veil: ColorRect
var _result: Label
var _summary: Label
var _continue: Button
var _penalty_flash := PenaltyFlash.new()

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
	_hit_count = UI.label("", 16)
	header.add_child(_hit_count)
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
	var instructions := UI.label("Wheel or arrows  Aim    Z / X  Tap    Matching arrow  Hit slider    Esc  Back", 15, UI.MUTED)
	instructions.size_flags_horizontal = SIZE_EXPAND_FILL
	footer.add_child(instructions)
	_feedback = UI.label("", 18, UI.ACCENT)
	footer.add_child(_feedback)
	_build_result()
	add_child(_penalty_flash)
	_penalty_flash.set_anchors_and_offsets_preset(PRESET_FULL_RECT)

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
	arena.approach_horizon = chart.approach_horizon()
	arena.center_rotation_track = chart.center_rotation_track()
	transport.load_song(stream)
	var bounds := chart.playback_bounds(transport.duration())
	transport.set_playback_range(bounds.start, bounds.end)
	_schedule = chart.schedule(transport.playback_start, transport.playback_end)
	_cursor = clampf(cursor, transport.playback_start, transport.playback_end)
	_title.text = chart.title
	_restart()

func _restart() -> void:
	_paused = false
	_finished = false
	_veil.hide()
	_penalty_flash.reset()
	var start := maxf(transport.playback_start, _cursor - Session.LEAD_IN)
	session = Session.new()
	session.setup(_schedule, transport.playback_end, _cursor, start)
	session.penalized.connect(_penalty_flash.flash)
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
			_hit_arrow(-1)
		KEY_RIGHT:
			_hit_arrow(1)
		_:
			if _paused or _finished:
				_continue_run()
			else:
				session.press(transport.song_time())
				_update_view()

func _turn(direction: float) -> void:
	if not _paused and not _finished:
		session.rotate(direction, transport.song_time())

func _hit_arrow(direction: int) -> void:
	if not _paused and not _finished:
		session.press_arrow(direction, transport.song_time())
		_update_view()

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
		session.advance_to(transport.playback_end, true)
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
	_hit_count.text = "%d hits" % session.hits
	_energy.value = session.energy
	_feedback.text = session.feedback if session.time - session.feedback_at < 0.65 else ""

class PenaltyFlash extends Control:
	const DURATION := 0.55
	const EDGE_COLOR := Color(Palette.RED, 0.48)
	const CLEAR_COLOR := Color(Palette.RED, 0.0)
	var _fade: Tween

	func _ready() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE
		modulate.a = 0.0
		resized.connect(queue_redraw)

	func reset() -> void:
		if _fade != null:
			_fade.kill()
			_fade = null
		modulate.a = 0.0

	func flash() -> void:
		reset()
		modulate.a = 1.0
		_fade = create_tween()
		_fade.tween_property(self, "modulate:a", 0.0, DURATION).set_trans(Tween.TRANS_SINE)

	func _draw() -> void:
		var inset := minf(size.x, size.y) * 0.085
		if inset <= 0.0:
			return
		var outer := PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0.0), size, Vector2(0.0, size.y)])
		var inner := PackedVector2Array([
			Vector2(inset, inset), Vector2(size.x - inset, inset),
			size - Vector2(inset, inset), Vector2(inset, size.y - inset),
		])
		var colors := PackedColorArray([EDGE_COLOR, EDGE_COLOR, CLEAR_COLOR, CLEAR_COLOR])
		for side in 4:
			var next := (side + 1) % 4
			draw_polygon(PackedVector2Array([outer[side], outer[next], inner[next], inner[side]]), colors)
