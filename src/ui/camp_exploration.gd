class_name CampExploration
extends Control

signal interaction_requested(speaker: String)

var loop: DayLoop
var active := false
var blocked := false
var camera_x := 0.0
var elapsed := 0.0
var walk_target := -1.0
var walk_direction := 1.0
var walking := false
var contacts: Dictionary = {}
var talk_button: Button
var control_box := ConvoyTheme.box(Color(0.08, 0.16, 0.23, 0.93))

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(0, 270)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	talk_button = ConvoyTheme.button("靠近队员交谈", try_interact, "camp_scene_talk")
	talk_button.custom_minimum_size = Vector2(190, 54)
	add_child(talk_button)
	resized.connect(_layout_controls)
	get_window().focus_exited.connect(release_controls)
	_layout_controls()

func setup(day_loop: DayLoop) -> void:
	loop = day_loop
	camera_x = 0.0
	walk_target = -1.0
	queue_redraw()

func set_active(value: bool, input_blocked: bool = false) -> void:
	active = value
	blocked = input_blocked
	visible = value
	if not value or input_blocked: release_controls()
	_sync()

func release_controls() -> void:
	contacts.clear()
	walk_target = -1.0
	walking = false

func _layout_controls() -> void:
	talk_button.position = Vector2(maxf(0.0, size.x - 208), size.y - 67)
	talk_button.size = Vector2(190, 54)
	_sync()

func _physics_process(delta: float) -> void:
	if not active or blocked or loop == null: return
	elapsed += delta
	walking = false
	if not loop.conversation_open:
		var direction := Input.get_axis("move_left", "move_right")
		for value in contacts.values(): direction += float(value)
		direction = clampf(direction, -1, 1)
		if not is_zero_approx(direction):
			walk_target = -1.0
		elif walk_target >= 0.0:
			var distance := walk_target - loop.state.camp_position
			var step := float(loop.content.camp_data().walk_speed) * delta
			if absf(distance) <= step:
				loop.move_in_camp(signf(distance), absf(distance) / float(loop.content.camp_data().walk_speed))
				walk_target = -1.0
			else: direction = signf(distance)
		if not is_zero_approx(direction):
			var old_position := loop.state.camp_position
			loop.move_in_camp(direction, delta)
			walking = not is_equal_approx(old_position, loop.state.camp_position)
			walk_direction = direction
	_sync()
	queue_redraw()

func _sync() -> void:
	if loop == null: return
	var total_width := float(loop.content.camp_data().width)
	camera_x = clampf(loop.state.camp_position - size.x * 0.4, 0, maxf(0, total_width - size.x))
	var nearby := nearby_member()
	talk_button.disabled = blocked or loop.conversation_open or nearby.is_empty()
	talk_button.text = "与%s交谈" % nearby.name if not nearby.is_empty() else "靠近队员交谈"

func nearby_member() -> Dictionary:
	if loop == null: return {}
	var nearest: Dictionary = {}
	var distance := float(loop.content.camp_data().interaction_range)
	for member in loop.content.camp_members():
		var gap := absf(loop.state.camp_position - float(member.x))
		if gap <= distance:
			nearest = member
			distance = gap
	return nearest

func try_interact() -> void:
	if not active or blocked or loop == null or loop.conversation_open: return
	var member := nearby_member()
	if not member.is_empty():
		release_controls()
		interaction_requested.emit(str(member.name))

func _unhandled_key_input(event: InputEvent) -> void:
	if active and not blocked and event.is_action_pressed("interact") and not event.is_echo():
		try_interact()
		get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	# Receive releases even when a pointer leaves the scene.
	if event is InputEventScreenTouch and not event.pressed: contacts.erase(event.index)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed: contacts.erase(-1)

func _gui_input(event: InputEvent) -> void:
	if not active or blocked or loop == null or loop.conversation_open: return
	if event is InputEventScreenTouch and event.pressed:
		_pointer_down(event.index, event.position)
		accept_event()
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_pointer_down(-1, event.position)
		accept_event()
	elif event is InputEventScreenDrag and contacts.has(event.index):
		var local: Vector2 = event.position
		if not _left_rect().has_point(local) and not _right_rect().has_point(local):
			contacts.erase(event.index)
		accept_event()

func _pointer_down(index: int, local: Vector2) -> void:
	# Containers may have just resized after this scene became visible.
	# Refresh the camera before translating the first pointer into world space.
	_sync()
	if _left_rect().has_point(local): contacts[index] = -1.0
	elif _right_rect().has_point(local): contacts[index] = 1.0
	else:
		contacts.erase(index)
		walk_target = clampf(local.x + camera_x, 45, float(loop.content.camp_data().width) - 45)
		for member in loop.content.camp_members():
			if absf(walk_target - float(member.x)) < 28:
				walk_target = float(member.x) + (-50 if loop.state.camp_position < float(member.x) else 50)
				break

func _left_rect() -> Rect2:
	return Rect2(18, size.y - 67, 70, 54)

func _right_rect() -> Rect2:
	return Rect2(100, size.y - 67, 70, 54)

func _text(p: Vector2, text: String, font_size: int = 16, color: Color = ConvoyTheme.TEXT) -> void:
	draw_string(get_theme_default_font(), p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _draw() -> void:
	if loop == null: return
	var width := size.x
	var height := size.y
	var floor_y := height * 0.72
	var total_width := float(loop.content.camp_data().width)
	draw_rect(Rect2(Vector2.ZERO, size), Color("#0e1c2c"))
	draw_circle(Vector2(width - 100 - camera_x * 0.025, 63), 23, Color("#9cbdc5"))
	for i in range(24):
		draw_circle(Vector2(fmod(i * 137.0 + 29, width), fmod(i * 47.0, height * 0.45)), 1, Color(0.62, 0.77, 0.82, 0.3))
	var peaks := PackedVector2Array([Vector2(-30, height * 0.46), Vector2(85, height * 0.33), Vector2(190, height * 0.47), Vector2(315, height * 0.3), Vector2(485, height * 0.46), Vector2(width, height * 0.34), Vector2(width, height), Vector2(0, height)])
	draw_colored_polygon(peaks, Color("#223747"))
	draw_rect(Rect2(0, height * 0.5, width, height * 0.5), Color("#263841"))
	# The camp is viewed from the side; its horizon stays in the lower third.
	draw_set_transform(Vector2(-camera_x, 0))
	_landmark(floor_y)
	_vehicle(Vector2(250, floor_y - 8))
	_tent(Vector2(920, floor_y - 12))
	_supply(Vector2(1230, floor_y - 10))
	for i in range(25):
		draw_line(Vector2(i * 64, floor_y + 9), Vector2(i * 64 + 22, floor_y + 9), Color("#475a62"), 2)
	draw_line(Vector2(0, floor_y + 12), Vector2(total_width, floor_y + 12), Color("#61706c"), 2)
	_fire(Vector2(535, floor_y - 2))
	var current := loop.current_transaction()
	for member in loop.content.camp_members():
		var position := Vector2(float(member.x), floor_y)
		var completed := _completed(str(member.name))
		var selected: bool = not current.is_empty() and str(current.speaker) == str(member.name)
		if selected:
			draw_arc(position + Vector2(0, 5), 25, 0, PI, 20, ConvoyTheme.GOLD, 2)
		_person(position, Color(member.color), false, false)
		_text(position + Vector2(-26, -60), str(member.name), 17, ConvoyTheme.GOLD if selected else ConvoyTheme.TEXT)
		_text(position + Vector2(-32, -80), "优先事务" if selected else ("已回应" if completed else str(member.job)), 13, ConvoyTheme.GOLD if selected else ConvoyTheme.MUTED)
		var condition := loop.state.member_named(str(member.name))
		if not condition.is_empty() and int(condition.health) < 100:
			draw_rect(Rect2(position + Vector2(-18, -55), Vector2(36, 3)), Color("#432a2b"))
			draw_rect(Rect2(position + Vector2(-18, -55), Vector2(36 * float(condition.health) / 100, 3)), Color("#d9957a"))
	_person(Vector2(loop.state.camp_position, floor_y), Color("#d7c2a0"), true, walking)
	_text(Vector2(loop.state.camp_position - 18, floor_y - 60), "队长", 15, ConvoyTheme.TEXT)
	draw_set_transform(Vector2.ZERO)
	draw_rect(Rect2(0, 0, width, 39), Color(0.035, 0.08, 0.13, 0.9))
	var goal := "营地事务已完成"
	if not current.is_empty():
		var offset := float(loop.content.member_position(str(current.speaker))) - loop.state.camp_position
		goal = "%s %s  ·  %s" % ["←" if offset < -72 else ("→" if offset > 72 else "●"), current.speaker, current.goal]
	_text(Vector2(14, 26), goal, 16, ConvoyTheme.GOLD)
	var near := nearby_member()
	var hint := "点按地面移动，或按住左右方向"
	if loop.conversation_open: hint = "正在交谈 · 先回应或结束交谈，再继续走动"
	elif not near.is_empty(): hint = "已经靠近%s，可以交谈" % near.name
	_text(Vector2(14, height - 83), hint, 14, ConvoyTheme.MUTED)
	for rect in [_left_rect(), _right_rect()]:
		draw_style_box(control_box, rect)
	_text(_left_rect().position + Vector2(23, 34), "←", 26)
	_text(_right_rect().position + Vector2(23, 34), "→", 26)

func _completed(speaker: String) -> bool:
	for transaction in loop.daily_transactions:
		if transaction.speaker == speaker and transaction.has("resolution"): return true
	return false

func _person(p: Vector2, color: Color, captain: bool, moving: bool) -> void:
	var swing := sin(elapsed * 13) * 7 if moving else 0.0
	draw_line(p + Vector2(-4, -10), p + Vector2(-7 - swing, 3), Color("#18212d"), 5)
	draw_line(p + Vector2(4, -10), p + Vector2(7 + swing, 3), Color("#18212d"), 5)
	draw_rect(Rect2(p + Vector2(-11, -35), Vector2(22, 27)), color)
	draw_line(p + Vector2(-10, -28), p + Vector2(-15 + swing, -11), color.darkened(0.2), 5)
	draw_line(p + Vector2(10, -28), p + Vector2(15 - swing, -11), color.darkened(0.2), 5)
	draw_circle(p + Vector2(0, -43), 8, Color("#c4ab8f"))
	draw_line(p + Vector2(-8, -48), p + Vector2(8, -48), color.darkened(0.2), 5)
	if captain:
		draw_line(p + Vector2(3, -33), p + Vector2(11 * walk_direction, -28), ConvoyTheme.GOLD, 3)

func _vehicle(p: Vector2) -> void:
	draw_rect(Rect2(p + Vector2(-135, -71), Vector2(192, 55)), Color("#66716b"))
	draw_rect(Rect2(p + Vector2(57, -48), Vector2(45, 32)), Color("#8b8a70"))
	draw_rect(Rect2(p + Vector2(20, -64), Vector2(30, 20)), Color("#9bb2b2"))
	draw_line(p + Vector2(-136, -43), p + Vector2(19, -43), Color("#989e87"), 3)
	for x in [-95, 62]:
		draw_circle(p + Vector2(x, -7), 18, Color("#101820"))
		draw_circle(p + Vector2(x, -7), 8, Color("#77807d"))
	draw_line(p + Vector2(-15, -72), p + Vector2(-15, -111), Color("#9da8a7"), 2)
	draw_circle(p + Vector2(-15, -112), 3, ConvoyTheme.GOLD)

func _tent(p: Vector2) -> void:
	draw_colored_polygon(PackedVector2Array([p + Vector2(-90, 0), p + Vector2(0, -93), p + Vector2(95, 0)]), Color("#546e70"))
	draw_colored_polygon(PackedVector2Array([p + Vector2(-33, 0), p + Vector2(0, -68), p + Vector2(31, 0)]), Color("#172c35"))
	draw_line(p + Vector2(-90, 0), p + Vector2(0, -93), Color("#82989a"), 2)

func _supply(p: Vector2) -> void:
	for i in range(3):
		draw_rect(Rect2(p + Vector2(i * 27 - 50, -24), Vector2(25, 24)), Color("#7b7561"))
	draw_rect(Rect2(p + Vector2(8, -58), Vector2(29, 34)), Color("#536d76"))
	draw_line(p + Vector2(-58, -3), p + Vector2(50, -3), Color("#a49b7b"), 3)

func _fire(p: Vector2) -> void:
	for i in range(5, 0, -1):
		draw_circle(p + Vector2(0, -18), i * 19.0, Color(0.9, 0.49, 0.22, 0.025))
	draw_line(p + Vector2(-22, 3), p + Vector2(18, -2), Color("#96745a"), 6)
	var tip := -46 + sin(elapsed * 8) * 4
	draw_colored_polygon(PackedVector2Array([p + Vector2(-15, 0), p + Vector2(-4, tip), p + Vector2(8, -24), p + Vector2(18, 0)]), Color("#e79b62"))
	draw_colored_polygon(PackedVector2Array([p + Vector2(-7, 0), p + Vector2(2, -27), p + Vector2(10, 0)]), Color("#f4d19a"))

func _landmark(floor_y: float) -> void:
	var position := Vector2(650, floor_y - 55)
	match loop.state.day:
		1:
			draw_line(position + Vector2(-80, -36), position + Vector2(-80, -130), Color("#657e84"), 5)
			draw_line(position + Vector2(85, -36), position + Vector2(85, -130), Color("#657e84"), 5)
			draw_rect(Rect2(position + Vector2(-110, -145), Vector2(225, 19)), Color("#b2a17d"))
		2:
			draw_circle(position + Vector2(0, -20), 110, Color("#586972"))
			draw_circle(position + Vector2(0, -12), 83, Color("#0f2030"))
			draw_rect(Rect2(position + Vector2(-114, 0), Vector2(228, 74)), Color("#263841"))
		3:
			for x in [-45, 45]: draw_line(position + Vector2(x, -30), position + Vector2(x, -150), Color("#7c959b"), 4)
			draw_line(position + Vector2(-45, -150), position + Vector2(45, -30), Color("#7c959b"), 2)
			draw_rect(Rect2(position + Vector2(-65, -198), Vector2(130, 58)), Color("#65838d"))
		4:
			for i in range(32):
				var point := Vector2(fmod(i * 71 + elapsed * 15, 1440), fmod(i * 23 + elapsed * 9, floor_y))
				draw_circle(point, 2, Color("#adc1ca"))
		5:
			draw_line(position + Vector2(-90, 0), position + Vector2(-90, -141), Color("#829994"), 5)
			draw_line(position + Vector2(100, 0), position + Vector2(100, -141), Color("#829994"), 5)
			draw_line(position + Vector2(-90, -141), position + Vector2(100, -141), Color("#829994"), 5)
			draw_colored_polygon(PackedVector2Array([position + Vector2(100, -141), position + Vector2(154, -122), position + Vector2(100, -105)]), ConvoyTheme.GOLD)
