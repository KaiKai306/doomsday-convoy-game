extends CanvasLayer
## Same confirmation API as the controller's old dialog, rendered in the title skin.
signal confirmed
const SKIN = preload("res://src/ui/convoy_skin.gd")
const MOBILE = preload("res://src/ui/mobile_layout.gd")
var title = "确认选择"
var min_size = Vector2i(660,240)
var dialog_text = ""
var screen: Control
var body: RichTextLabel
var heading: Label
var frame: Control
var confirm_button: Button

func _ready() -> void:
	layer = 80
	screen = Control.new(); screen.theme = ConvoyTheme.create(); screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(screen)
	var shade = ColorRect.new(); shade.color = Color(0.005,0.012,0.02,0.82); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); screen.add_child(shade)
	frame = SKIN.panel(screen,Vector2.ZERO,Vector2(760,420),true); frame.fill.a = 0.94
	heading = ConvoyTheme.label("",30,SKIN.GOLD); heading.position = Vector2(40,30); heading.size = Vector2(675,45); SKIN.title(heading); frame.add_child(heading)
	body = RichTextLabel.new(); body.position = Vector2(42,100); body.size = Vector2(676,206); body.add_theme_font_size_override("normal_font_size",20); body.add_theme_color_override("default_color",SKIN.TEXT); frame.add_child(body)
	var cancel = Button.new(); cancel.text = "返回"; cancel.position = Vector2(40,345); cancel.size = Vector2(320,46); cancel.pressed.connect(hide); frame.add_child(cancel); SKIN.button(cancel)
	confirm_button = Button.new(); confirm_button.text = "确认选择  →"; confirm_button.position = Vector2(396,345); confirm_button.size = Vector2(320,46); confirm_button.pressed.connect(func(): hide(); confirmed.emit()); frame.add_child(confirm_button); SKIN.button(confirm_button,true)
	get_viewport().size_changed.connect(_fit); _fit(); hide()

func _fit() -> void:
	var area = MOBILE.safe_rect(screen); var factor = minf(1,minf(area.size.x/840.0,area.size.y/480.0))
	frame.scale = Vector2.ONE*factor; frame.position = area.position+(area.size-frame.size*factor)*0.5

func popup_centered() -> void:
	heading.text = title; body.text = dialog_text; SKIN.polish_tree(screen,SKIN.feedback_for(get_parent())); _fit(); show(); confirm_button.grab_focus()

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		hide(); get_viewport().set_input_as_handled()
