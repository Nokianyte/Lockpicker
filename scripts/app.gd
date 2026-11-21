extends Node

const ArcadeModel = preload("res://scripts/run_model.gd")
const ChartEditor = preload("res://scripts/chart_editor.gd")
const Library = preload("res://scripts/chart_library.gd")
const RhythmModel = preload("res://scripts/rhythm_run.gd")
const SongPlayer = preload("res://scripts/song_player.gd")
const UI = preload("res://scripts/chart_ui.gd")

@onready var arcade: Node2D = $Arcade
@onready var rhythm: Node2D = $Rhythm

var editor: ChartEditor
var song: SongPlayer
var _chart_button: Button
var _mode_button: Button
var _from_editor := false
var _return_to_arcade := false
var _browser: JavaScriptObject

func _ready() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var controls := Control.new()
	controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	controls.theme = UI.theme()
	layer.add_child(controls)
	controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_chart_button = UI.button("Charts", _show_charts, true)
	_chart_button.custom_minimum_size = Vector2(110, 34)
	controls.add_child(_chart_button)
	_chart_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_chart_button.offset_left = -55
	_chart_button.offset_right = 55
	_chart_button.offset_top = 27
	_chart_button.offset_bottom = 63
	_mode_button = UI.button("Arcade", func() -> void: _show_game(not arcade.visible))
	controls.add_child(_mode_button)
	_mode_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_mode_button.offset_left = 65
	_mode_button.offset_right = 150
	_mode_button.offset_top = 27
	_mode_button.offset_bottom = 63

	var library := Library.new()
	add_child(library)
	editor = ChartEditor.new()
	editor.library = library
	controls.add_child(editor)
	editor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	editor.hide()
	editor.game_requested.connect(func() -> void: _show_game(_return_to_arcade))
	editor.play_requested.connect(_start_song)

	song = SongPlayer.new()
	controls.add_child(song)
	song.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	song.hide()
	song.exit_requested.connect(_back_from_song)
	if OS.has_feature("web"):
		_browser = JavaScriptBridge.get_interface("window")
		JavaScriptBridge.eval("""
			window.lockpickerBlurred = false;
			window.addEventListener('blur', () => window.lockpickerBlurred = true);
			document.addEventListener('visibilitychange', () => {
				if (document.hidden) window.lockpickerBlurred = true;
			});
		""")

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_pause_active()

func _pause_active() -> void:
	if editor == null or song == null:
		return
	if song.visible:
		song.pause_run()
	elif editor.visible:
		editor.pause_preview()
	elif arcade.visible:
		arcade.pause_run()
	else:
		rhythm.pause_run()

func _process(_delta: float) -> void:
	if _browser != null and _browser.lockpickerBlurred == true:
		_browser.lockpickerBlurred = false
		_pause_active()
	var at_arcade_menu: bool = arcade.visible and arcade.game.state != ArcadeModel.State.PLAYING
	var at_rhythm_menu: bool = rhythm.visible and rhythm.game.state != RhythmModel.State.PLAYING
	_chart_button.visible = at_arcade_menu or at_rhythm_menu
	_mode_button.visible = _chart_button.visible

func _show_charts() -> void:
	_return_to_arcade = arcade.visible
	editor.set_game_label("Arcade" if _return_to_arcade else "Rhythm")
	_set_game_active(arcade, false)
	_set_game_active(rhythm, false)
	_chart_button.hide()
	_mode_button.hide()
	editor.show()
	editor.show_charts()

func _show_game(show_arcade: bool) -> void:
	editor.hide()
	_set_game_active(arcade, show_arcade)
	_set_game_active(rhythm, not show_arcade)
	_mode_button.text = "Rhythm" if show_arcade else "Arcade"

func _set_game_active(game: Node2D, active: bool) -> void:
	game.visible = active
	game.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED

func _start_song(chart, stream: AudioStreamWAV, cursor: float, from_editor: bool) -> void:
	_from_editor = from_editor
	editor.hide()
	song.show()
	song.start_run(chart, stream, cursor)

func _back_from_song() -> void:
	song.hide()
	editor.show()
	if not _from_editor:
		editor.show_charts()
