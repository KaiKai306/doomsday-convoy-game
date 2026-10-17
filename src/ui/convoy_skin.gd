extends RefCounted
## Shared with the title page: same ARWES geometry, translucent ink, warm gold,
## Song-style headings and tactical click feedback. Layouts own no skin constants.
const FRAME = preload("res://src/ui/arwes_frame.gd")
const FEEDBACK = preload("res://src/ui/ui_feedback.gd")
const GOLD = Color("e5ae73")
const TEXT = Color("e8e7e2")
const MUTED = Color("899ba9")
static var heading_font: SystemFont

static func title(label: Label) -> void:
	if heading_font == null:
		heading_font = SystemFont.new(); heading_font.font_names = PackedStringArray(["STZhongsong","SimSun"])
	label.add_theme_font_override("font",heading_font)
	label.add_theme_color_override("font_color",GOLD)
	label.add_theme_color_override("font_shadow_color",Color("663813"))
	label.add_theme_constant_override("shadow_offset_x",1); label.add_theme_constant_override("shadow_offset_y",2)

static func panel(parent: Node,point: Vector2,dimensions: Vector2,selected: bool = false) -> Control:
	var frame = FRAME.new(); frame.name = "TitleStylePanel"; frame.position = point; frame.size = dimensions
	frame.shape = FRAME.Shape.KRANOX if dimensions.x >= 430 and dimensions.y >= 120 else FRAME.Shape.NEFREX
	frame.fill = Color(0.024,0.045,0.065,0.66 if selected else 0.54)
	frame.line = GOLD if selected else Color("899ba9"); frame.active = selected
	parent.add_child(frame); return frame

static func feedback_for(host: Node) -> Node:
	var parent = host.get_parent()
	if parent != null and "feedback" in parent and is_instance_valid(parent.feedback): return parent.feedback
	var feedback = host.get_node_or_null("GameUIFeedback")
	if feedback == null:
		feedback = FEEDBACK.new(); feedback.name = "GameUIFeedback"; host.add_child(feedback)
	return feedback

static func button(button: Button,primary: bool = false,feedback: Node = null) -> void:
	button.set_meta("title_primary",primary)
	for state in ["normal","disabled","hover","pressed","focus"]:
		var empty = StyleBoxEmpty.new(); empty.content_margin_left = 16; empty.content_margin_right = 16; empty.content_margin_top = 8; empty.content_margin_bottom = 8
		button.add_theme_stylebox_override(state,empty)
	button.add_theme_color_override("font_color",GOLD)
	button.add_theme_color_override("font_hover_color",Color("f5d3aa")); button.add_theme_color_override("font_focus_color",Color("f5d3aa"))
	button.add_theme_color_override("font_pressed_color",Color("f5d3aa")); button.add_theme_color_override("font_disabled_color",Color("65717a"))
	var frame = button.get_node_or_null("ArwesFrame")
	if frame == null:
		frame = FRAME.new(); frame.name = "ArwesFrame"; frame.show_behind_parent = true; frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); button.add_child(frame)
	if not button.has_meta("title_skin_bound"):
		button.set_meta("title_skin_bound",true)
		for event in [button.mouse_entered,button.mouse_exited,button.focus_entered,button.focus_exited,button.button_down,button.button_up,button.draw]:
			event.connect(func(): refresh(button))
		if feedback != null: feedback.bind_button(button)
	refresh(button)
	if button is OptionButton:
		var popup = button.get_popup()
		var box = StyleBoxFlat.new(); box.bg_color = Color(0.024,0.045,0.065,0.97); box.border_color = Color("a88c6b"); box.set_border_width_all(1); box.set_corner_radius_all(0)
		box.set_content_margin_all(12); popup.add_theme_stylebox_override("panel",box)
		popup.add_theme_color_override("font_color",TEXT); popup.add_theme_color_override("font_hover_color",GOLD)

static func refresh(button: Button) -> void:
	var frame = button.get_node_or_null("ArwesFrame")
	if frame == null: return
	var highlighted = not button.disabled and (button.is_hovered() or button.has_focus())
	var primary = bool(button.get_meta("title_primary",false))
	frame.fill = Color(0.22,0.14,0.07,0.35 if highlighted else 0.19) if primary or highlighted else Color(0.024,0.045,0.065,0.26)
	if button.is_pressed(): frame.fill.a = 0.55
	frame.line = GOLD if primary or highlighted else MUTED
	if button.disabled: frame.fill.a = 0.18; frame.line = Color("52606a")
	frame.queue_redraw()

static func polish_tree(root: Node,feedback: Node = null) -> void:
	if root is Button and not root.get_meta("skin_skip",false): button(root,bool(root.get_meta("title_primary",false)),feedback)
	for child in root.get_children(): polish_tree(child,feedback)
