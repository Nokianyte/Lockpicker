extends RefCounted

const INK := Color("e8f3ee")
const MUTED := Color("a6bbc2")
const MINT := Color("a5f6c7")
const RED := Color("ff9a84")
const GOLD := Color("f7d685")
const BACKGROUND := Color("091117")

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
		result.add_theme_stylebox_override("normal", box(Color("18332b"), Color("3c6b56"), 9))
		result.add_theme_stylebox_override("hover", box(Color("224839"), MINT, 9))
		result.add_theme_stylebox_override("pressed", box(Color("102a22"), MINT, 9))
		result.add_theme_color_override("font_color", MINT)
	result.pressed.connect(callback)
	return result

static func theme() -> Theme:
	var result := Theme.new()
	result.default_font_size = 15
	for type in ["Button", "OptionButton"]:
		result.set_stylebox("normal", type, box(Color("17232e"), Color("31434e"), 9))
		result.set_stylebox("hover", type, box(Color("233440"), Color("52717b"), 9))
		result.set_stylebox("pressed", type, box(Color("142b28"), Color("6a9e83"), 9))
		result.set_stylebox("disabled", type, box(Color("101820"), Color("25313b"), 9))
		result.set_color("font_color", type, INK)
		result.set_color("font_disabled_color", type, Color("80939a"))
	result.set_stylebox("normal", "LineEdit", box(Color("0c161e"), Color("354651"), 8))
	result.set_stylebox("focus", "LineEdit", box(Color(0, 0, 0, 0), MINT))
	result.set_color("font_color", "LineEdit", INK)
	result.set_color("caret_color", "LineEdit", MINT)
	result.set_stylebox("panel", "PanelContainer", box(Color("101a23"), Color("2b3e48"), 16))
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
