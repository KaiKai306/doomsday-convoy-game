extends Control
## One pointer owns the joystick until release, even outside its circle.
## The interaction button has its own pointer, so talking never steals motion.
signal axis_changed(value: float)
signal pressed
var kind = "joystick"
var enabled = true
var owner_pointer = -2
var knob = Vector2.ZERO
var axis = 0.0
const NONE = -2
const MOUSE = -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "左右移动 · A / D" if kind == "joystick" else "靠近队友交谈 · E / 空格"

func radius() -> float:
	return minf(size.x,size.y)*0.5-3

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_begin(event.index,event.position); accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and event.device != InputEvent.DEVICE_ID_EMULATION:
		_begin(MOUSE,event.position); accept_event()

func _begin(pointer: int, point: Vector2) -> void:
	if owner_pointer != NONE or not enabled or point.distance_to(size*0.5)>radius(): return
	owner_pointer = pointer
	if kind == "joystick": _move(point)
	queue_redraw()

func _move(point: Vector2) -> void:
	knob = (point-size*0.5).limit_length(radius()*0.55)
	# Vertical travel stays visible but only the horizontal component moves actors.
	var raw = knob.x/(radius()*0.55)
	axis = signf(raw)*clampf((absf(raw)-0.15)/0.85,0,1)
	axis_changed.emit(axis); queue_redraw()

func release() -> void:
	owner_pointer = NONE; knob = Vector2.ZERO; axis = 0
	axis_changed.emit(0); queue_redraw()

func _input(event: InputEvent) -> void:
	if owner_pointer == NONE: return
	if event is InputEventScreenDrag and event.index == owner_pointer and kind == "joystick":
		_move(get_global_transform_with_canvas().affine_inverse()*event.position)
	elif event is InputEventMouseMotion and owner_pointer == MOUSE and kind == "joystick":
		_move(get_global_transform_with_canvas().affine_inverse()*event.position)
	elif event is InputEventScreenTouch and not event.pressed and event.index == owner_pointer:
		var inside = (get_global_transform_with_canvas().affine_inverse()*event.position).distance_to(size*0.5)<=radius()
		var activate = kind == "hand" and enabled and inside and not event.canceled
		release()
		if activate: pressed.emit()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and owner_pointer == MOUSE:
		var inside = (get_global_transform_with_canvas().affine_inverse()*event.position).distance_to(size*0.5)<=radius()
		var activate = kind == "hand" and enabled and inside
		release()
		if activate: pressed.emit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT: release()

func _draw() -> void:
	var c = size*0.5; var r = radius()
	var ink = Color(ConvoyTheme.GOLD,0.72 if enabled else 0.27)
	draw_circle(c,r,Color(0.025,0.045,0.065,0.52))
	draw_arc(c,r,0,TAU,96,ink,1.6,true)
	if kind == "joystick":
		for side in [-1,1]:
			var tip = c+Vector2(side*r*0.79,0)
			draw_colored_polygon(PackedVector2Array([tip,tip+Vector2(-side*7,-5),tip+Vector2(-side*7,5)]),Color(ConvoyTheme.MUTED,0.42))
		draw_circle(c+knob,r*0.40,Color(ConvoyTheme.GOLD,0.16))
		draw_arc(c+knob,r*0.40,0,TAU,64,ink,1.5,true)
	else:
		# Open-palm silhouette: readable without a word or an emoji font.
		var p = c+Vector2(-2,4)
		draw_circle(p+Vector2(0,7),14,ink)
		for finger in [[-13,-12,5],[-5,-23,5],[4,-26,5],[13,-19,4]]:
			var start = p+Vector2(finger[0],0)
			var end = p+Vector2(finger[0],finger[1])
			draw_line(start,end,ink,float(finger[2])*2,true); draw_circle(end,float(finger[2]),ink)
		draw_line(p+Vector2(-12,11),p+Vector2(-24,-3),ink,9,true)
		draw_circle(p+Vector2(-24,-3),4.5,ink)
		draw_style_box(_wrist(ink),Rect2(p+Vector2(-8,12),Vector2(18,14)))
		if enabled: draw_arc(c,r-5,-0.9,0.9,24,Color(ConvoyTheme.GOLD,0.9),2,true)

func _wrist(color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new(); style.bg_color = color
	style.set_corner_radius_all(4); return style
