extends RefCounted
## World art covers the display; interactive UI uses the platform's safe area.
## Tests may supply physical-pixel insets on the viewport without changing saves.
static func safe_rect(control: Control) -> Rect2:
	var viewport = control.get_viewport()
	var visible = viewport.get_visible_rect()
	var pixels = Rect2(Vector2.ZERO,Vector2(DisplayServer.window_get_size()))
	if viewport.has_meta("mobile_safe_insets"):
		var insets: Vector4 = viewport.get_meta("mobile_safe_insets")
		pixels = Rect2(Vector2(insets.x,insets.y),pixels.size-Vector2(insets.x+insets.z,insets.y+insets.w))
	elif OS.has_feature("mobile"):
		var platform_area = Rect2(DisplayServer.get_display_safe_area())
		if platform_area.has_area(): pixels = pixels.intersection(platform_area)
	var area = (viewport.get_final_transform().affine_inverse()*pixels).intersection(visible)
	if not area.has_area(): area = visible
	var margin = minf(visible.size.x/1600.0,visible.size.y/720.0)*8.0
	area = area.grow(-margin)
	return control.get_global_transform_with_canvas().affine_inverse()*area

static func fit(control: Control, design: Vector2, area: Rect2, alignment: Vector2 = Vector2(0.5,0.5)) -> void:
	_stop_old_transition(control)
	var factor = minf(area.size.x/design.x,area.size.y/design.y)
	control.size = design; control.scale = Vector2.ONE*factor
	control.position = area.position+(area.size-design*factor)*alignment
	control.set_meta("page_origin",control.position)

static func fit_tall(control: Control, design: Vector2, area: Rect2) -> void:
	_stop_old_transition(control)
	var factor = minf(area.size.x/design.x,area.size.y/design.y)
	control.scale = Vector2.ONE*factor
	control.size = Vector2(design.x,area.size.y/factor)
	control.position = area.position+Vector2((area.size.x-design.x*factor)*0.5,0)
	control.set_meta("page_origin",control.position)

static func cover(control: Control, design: Vector2, dimensions: Vector2) -> void:
	var factor = maxf(dimensions.x/design.x,dimensions.y/design.y)
	control.size = design; control.scale = Vector2.ONE*factor
	control.position = (dimensions-design*factor)*0.5

static func _stop_old_transition(control: Control) -> void:
	var previous = control.get_meta("page_tween") if control.has_meta("page_tween") else null
	if previous is Tween and previous.is_running():
		previous.kill()
		control.modulate.a = 1.0
