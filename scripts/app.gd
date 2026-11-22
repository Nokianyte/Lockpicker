extends Node

const ArcadeModel = preload("res://scripts/run_model.gd")
const ChartEditor = preload("res://scripts/chart_editor.gd")
const Library = preload("res://scripts/chart_library.gd")
const RhythmModel = preload("res://scripts/rhythm_run.gd")
const SongPlayer = preload("res://scripts/song_player.gd")
const UI = preload("res://scripts/chart_ui.gd")
const SETTINGS_FILE := "user://settings.cfg"

@onready var arcade: Node2D = $Arcade
@onready var rhythm: Node2D = $Rhythm

var editor: ChartEditor
var song: SongPlayer
var _chart_button: Button
var _mode_button: Button
var _settings_button: Button
var _settings: AcceptDialog
var _volume_slider: HSlider
var _volume_label: Label
var _saved_volume := 100
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
	_settings_button = UI.button("Settings", _show_settings)
	controls.add_child(_settings_button)
	_settings_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_settings_button.offset_left = 160
	_settings_button.offset_right = 252
	_settings_button.offset_top = 27
	_settings_button.offset_bottom = 63

	var library := Library.new()
	add_child(library)
	editor = ChartEditor.new()
	editor.library = library
	controls.add_child(editor)
	editor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	editor.hide()
	editor.game_requested.connect(func() -> void: _show_game(_return_to_arcade))
	editor.play_requested.connect(_start_song)
	editor.settings_requested.connect(_show_settings)

	song = SongPlayer.new()
	controls.add_child(song)
	song.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	song.hide()
	song.exit_requested.connect(_back_from_song)
	song.settings_requested.connect(_show_settings)
	if OS.has_feature("web"):
		_browser = JavaScriptBridge.get_interface("window")
		JavaScriptBridge.eval("""
			window.lockpickerSettings = {
				readVolume() {
					try { return localStorage.getItem('lockpicker.masterVolume') ?? '100'; }
					catch (_) { return '100'; }
				},
				writeVolume(value) {
					try { localStorage.setItem('lockpicker.masterVolume', String(value)); }
					catch (_) {}
				}
			};
			window.lockpickerBlurred = false;
			window.addEventListener('blur', () => window.lockpickerBlurred = true);
			document.addEventListener('visibilitychange', () => {
				if (document.hidden) window.lockpickerBlurred = true;
			});
		""")
	_build_settings(controls)

func _build_settings(controls: Control) -> void:
	_settings = AcceptDialog.new()
	_settings.title = "Settings"
	_settings.ok_button_text = "Done"
	_settings.theme = controls.theme
	controls.add_child(_settings)
	var content := VBoxContainer.new()
	_settings.add_child(content)
	var row := HBoxContainer.new()
	content.add_child(row)
	var label := UI.label("Master volume", 16)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	_volume_label = UI.label("", 16)
	row.add_child(_volume_label)
	_volume_slider = HSlider.new()
	_volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_volume_slider.custom_minimum_size = Vector2(240, 24)
	_volume_slider.step = 1.0
	_volume_slider.max_value = 100.0
	var volume_fill := UI.box(UI.ACCENT, UI.ACCENT, 3)
	_volume_slider.add_theme_stylebox_override("grabber_area", volume_fill)
	_volume_slider.add_theme_stylebox_override("grabber_area_highlight", volume_fill)
	content.add_child(_volume_slider)
	_saved_volume = _load_volume()
	_volume_slider.set_value_no_signal(_saved_volume)
	_apply_volume(_saved_volume)
	_volume_slider.value_changed.connect(_apply_volume)
	_settings.visibility_changed.connect(func() -> void:
		if not _settings.visible:
			_save_volume()
	)

func _show_settings() -> void:
	_pause_active()
	_settings.popup_centered(Vector2i(420, 145))
	_volume_slider.grab_focus()

func _apply_volume(percent: float) -> void:
	_volume_label.text = "%d%%" % int(percent)
	var level := percent / 100.0
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(bus, level == 0.0)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(level, 0.001)))
	editor.transport.set_web_volume(level)

func _load_volume() -> int:
	if _browser != null:
		var stored: String = _browser.lockpickerSettings.readVolume()
		return clampi(stored.to_int(), 0, 100) if stored.is_valid_int() else 100
	var config := ConfigFile.new()
	config.load(SETTINGS_FILE)
	var stored: Variant = config.get_value("audio", "master_volume", 100)
	return clampi(stored, 0, 100) if stored is int else 100

func _save_volume() -> void:
	var value := int(_volume_slider.value)
	if value == _saved_volume:
		return
	if _browser != null:
		_browser.lockpickerSettings.writeVolume(value)
	else:
		var config := ConfigFile.new()
		config.set_value("audio", "master_volume", value)
		if config.save(SETTINGS_FILE) != OK:
			return
	_saved_volume = value

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
	_settings_button.visible = _chart_button.visible

func _show_charts() -> void:
	_return_to_arcade = arcade.visible
	editor.set_game_label("Arcade" if _return_to_arcade else "Rhythm")
	_set_game_active(arcade, false)
	_set_game_active(rhythm, false)
	_chart_button.hide()
	_mode_button.hide()
	_settings_button.hide()
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
