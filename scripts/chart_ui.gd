extends RefCounted

const Palette = preload("res://scripts/palette.gd")
const INK := Palette.INK
const MUTED := Palette.MUTED
const ACCENT := Palette.RED
const ERROR := Palette.SPIKE
const BACKGROUND := Palette.PAPER

static func box(fill: Color, border: Color, inset: float = 0.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = inset
	style.content_margin_right = inset
	style.content_margin_top = inset
	style.content_margin_bottom = inset
	return style

static func label(value: String, font_size: int = 16, color: Color = INK) -> Label:
	var result := Label.new()
	result.text = value
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	return result

static func button(value: String, callback: Callable, primary: bool = false) -> Button:
	var result := Button.new()
	result.text = value
	result.custom_minimum_size.y = 35
	result.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if primary:
		result.add_theme_stylebox_override("normal", box(Palette.RED_WASH, ACCENT, 9))
		result.add_theme_stylebox_override("hover", box(Palette.RED_HOVER, ACCENT, 9))
		result.add_theme_stylebox_override("pressed", box(Palette.RED_PRESSED, ACCENT, 9))
	result.pressed.connect(callback)
	return result

static func theme() -> Theme:
	var result := Theme.new()
	result.default_font_size = 15
	for type in ["Button", "OptionButton", "CheckButton"]:
		result.set_stylebox("normal", type, box(Palette.SURFACE, Palette.BORDER, 9))
		result.set_stylebox("hover", type, box(Palette.PANEL, Palette.RULE, 9))
		result.set_stylebox("pressed", type, box(Palette.RED_WASH, ACCENT, 9))
		result.set_stylebox("hover_pressed", type, box(Palette.RED_HOVER, ACCENT, 9))
		result.set_stylebox("disabled", type, box(Palette.PANEL, Palette.LINE, 9))
		result.set_stylebox("focus", type, box(Color.TRANSPARENT, ACCENT))
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			result.set_color(state, type, INK)
		result.set_color("font_disabled_color", type, MUTED)
	result.set_color("font_color", "Label", INK)
	result.set_stylebox("normal", "LineEdit", box(Palette.SURFACE, Palette.BORDER, 8))
	result.set_stylebox("focus", "LineEdit", box(Color.TRANSPARENT, ACCENT))
	result.set_color("font_color", "LineEdit", INK)
	result.set_color("font_placeholder_color", "LineEdit", MUTED)
	result.set_color("font_selected_color", "LineEdit", INK)
	result.set_color("selection_color", "LineEdit", Palette.RED_HOVER)
	result.set_color("caret_color", "LineEdit", ACCENT)
	for arrow in ["up", "down"]:
		result.set_color(arrow + "_icon_modulate", "SpinBox", MUTED)
		result.set_color(arrow + "_hover_icon_modulate", "SpinBox", INK)
		result.set_color(arrow + "_pressed_icon_modulate", "SpinBox", ACCENT)
	result.set_constant("modulate_arrow", "OptionButton", 1)
	result.set_stylebox("panel", "PopupMenu", box(Palette.SURFACE, Palette.BORDER, 5))
	result.set_stylebox("panel", "PopupPanel", box(Palette.SURFACE, Palette.BORDER, 8))
	result.set_stylebox("hover", "PopupMenu", box(Palette.RED_WASH, Palette.LINE))
	result.set_color("font_color", "PopupMenu", INK)
	result.set_color("font_hover_color", "PopupMenu", INK)
	result.set_stylebox("panel", "PanelContainer", box(Palette.SURFACE, Palette.BORDER, 16))
	result.set_stylebox("panel", "AcceptDialog", box(Palette.SURFACE, Palette.BORDER, 16))
	result.set_stylebox("embedded_border", "Window", box(Palette.PANEL, Palette.BORDER))
	result.set_stylebox("embedded_unfocused_border", "Window", box(Palette.PANEL, Palette.BORDER))
	result.set_color("title_color", "Window", INK)
	result.set_constant("separation", "VBoxContainer", 12)
	result.set_constant("separation", "HBoxContainer", 10)
	return result

static func margins(amount: int) -> MarginContainer:
	var result := MarginContainer.new()
	for side in ["top", "bottom", "left", "right"]:
		result.add_theme_constant_override("margin_" + side, amount)
	return result

static func clock(time: float) -> String:
	return "%d:%06.3f" % [floori(time / 60.0), fposmod(time, 60.0)]
