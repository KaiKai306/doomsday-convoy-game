class_name ConvoyTheme
extends RefCounted

const INK := Color("#0b1421")
const PANEL := Color("#111f30")
const GOLD := Color("#e5ae73")
const TEXT := Color("#e8e7e2")
const MUTED := Color("#899ba9")
const BLUE := Color("#79b5c6")

static func box(color: Color, border: Color = Color("#304354"), radius: int = 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style

static func create() -> Theme:
	var result := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "Droid Sans Fallback"])
	result.default_font = font
	result.default_font_size = 18
	result.set_color("font_color", "Label", TEXT)
	result.set_color("font_color", "Button", TEXT)
	result.set_color("font_disabled_color", "Button", Color("#62717e"))
	result.set_stylebox("panel", "PanelContainer", box(PANEL))
	result.set_stylebox("normal", "Button", box(Color("#172b3d")))
	result.set_stylebox("hover", "Button", box(Color("#243d4e"), GOLD))
	result.set_stylebox("pressed", "Button", box(Color("#37483f"), GOLD))
	result.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), GOLD))
	result.set_stylebox("disabled", "Button", box(Color("#14202d"), Color("#243344")))
	result.set_stylebox("background", "ProgressBar", box(Color("#1d3042"), Color("#1d3042"), 3))
	result.set_stylebox("fill", "ProgressBar", box(GOLD, GOLD, 3))
	result.set_constant("separation", "VBoxContainer", 12)
	result.set_constant("separation", "HBoxContainer", 12)
	return result

static func label(text: String, font_size: int = 18, color: Color = TEXT) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

static func button(text: String, callback: Callable, id: String = "") -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size.y = 54
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.pressed.connect(callback)
	node.set_meta("action_id", id)
	return node

static func margin(amount: int = 22) -> MarginContainer:
	var node := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		node.add_theme_constant_override("margin_" + side, amount)
	return node
