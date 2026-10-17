class_name StatusOverview
extends Control

signal close_requested

const ART := "res://assets/ui/status_overview/"
const CREAM := Color("#e6dbc0")
const MUTED := Color("#899494")
const GOLD := Color("#e1b254")
const GREEN := Color("#79b98a")
const RED := Color("#d05f55")
const BLUE := Color("#689aac")
const PORTRAITS := {"主角": "captain", "老张": "mechanic", "艾琳": "medic", "阿杰": "scout", "索菲亚": "quartermaster"}
var game_state: GameState
var day_loop: DayLoop
var phase_name := ""
var heading: Label
var resource_values: Dictionary = {}
var resource_hints: Dictionary = {}
var resource_bars: Dictionary = {}
var team_cards: VBoxContainer
var route_label: Label
var stop_label: Label
var map_surface: Control
var map_pins: Array[Button] = []
var map_points: Array[Vector2] = [Vector2(64, 53), Vector2(247, 115), Vector2(73, 182), Vector2(232, 245), Vector2(296, 307)]
var map_page := 0
var selected_stop := 1
var arrived_stop := 0
var page_label: Label
var member_detail: Control
var detail_name: Label
var detail_summary: Label
var detail_portrait: TextureRect
var detail_scroll: ScrollContainer
var inspected_member := ""
var snapshot := ""

func _ready() -> void:
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()

func _build() -> void:
	_picture(self, "background.jpg", Vector2.ZERO, size)
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.02, 0.025, 0.10)
	shade.size = size
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	heading = _text(self, "", Vector2(680, 20), Vector2(520, 36), 20, CREAM)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var resources := _panel(self, Rect2(80, 106, 344, 464))
	_text(resources, "车队资源", Vector2(52, 10), Vector2(265, 40), 27, CREAM)
	_icon(resources, "convoy", Vector2(15, 16), 29, CREAM)
	var keys := ["water", "food", "fuel", "medicine", "parts", "trust"]
	var colors := [BLUE, GOLD, BLUE, GREEN, BLUE, GREEN]
	for i in range(keys.size()):
		var key: String = keys[i]
		var row := _panel(resources, Rect2(12, 58 + i * 65, 320, 59), true)
		_icon(row, key, Vector2(10, 12), 36, colors[i])
		_text(row, "全队信任" if key == "trust" else DemoContent.RESOURCE_NAMES[key], Vector2(61, 4), Vector2(120, 22), 18, CREAM)
		resource_values[key] = _text(row, "", Vector2(187, 6), Vector2(121, 25), 18, CREAM)
		resource_values[key].horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var bar := ProgressBar.new()
		bar.position = Vector2(62, 29)
		bar.size = Vector2(181, 7)
		bar.show_percentage = false
		bar.add_theme_font_size_override("font_size", 1)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_theme_stylebox_override("background", _flat(Color("#1c2527"), Color("#283031"), 2))
		bar.add_theme_stylebox_override("fill", _flat(colors[i], colors[i].darkened(0.3), 2))
		row.add_child(bar)
		bar.size = Vector2(181, 7)
		resource_bars[key] = bar
		resource_hints[key] = _text(row, "", Vector2(62, 39), Vector2(248, 14), 11, MUTED)
	var map_panel := _panel(self, Rect2(444, 106, 391, 464))
	_icon(map_panel, "map", Vector2(16, 17), 28, CREAM)
	_text(map_panel, "停歇点", Vector2(59, 10), Vector2(219, 38), 27, CREAM)
	map_surface = Control.new()
	map_surface.position = Vector2(16, 59)
	map_surface.size = Vector2(359, 356)
	map_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_panel.add_child(map_surface)
	_picture(map_surface, "terrain.jpg", Vector2.ZERO, map_surface.size).show_behind_parent = true
	map_surface.draw.connect(_draw_map)
	_text(map_surface, "N", Vector2(321, 8), Vector2(24, 22), 13, MUTED)
	for i in range(5):
		var pin := _button(map_surface, "", Rect2(map_points[i] - Vector2(17, 17), Vector2(34, 34)), func(): _select_stop(map_page * 5 + i + 1), "stop_%d" % i)
		pin.add_theme_font_size_override("font_size", 19)
		map_pins.append(pin)
	stop_label = _text(map_panel, "", Vector2(17, 416), Vector2(356, 22), 14, GOLD)
	route_label = _text(map_panel, "", Vector2(17, 442), Vector2(266, 16), 11, MUTED)
	_button(map_panel, "‹", Rect2(290, 432, 25, 25), func(): _change_page(-1), "map_previous")
	page_label = _text(map_panel, "", Vector2(318, 435), Vector2(30, 20), 12, CREAM)
	_button(map_panel, "›", Rect2(352, 432, 25, 25), func(): _change_page(1), "map_next")
	var members := _panel(self, Rect2(854, 106, 347, 464))
	_icon(members, "members", Vector2(16, 16), 31, CREAM)
	_text(members, "成员状态", Vector2(62, 10), Vector2(255, 38), 27, CREAM)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(14, 58)
	scroll.size = Vector2(320, 390)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	members.add_child(scroll)
	team_cards = VBoxContainer.new()
	team_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	team_cards.add_theme_constant_override("separation", 8)
	scroll.add_child(team_cards)
	_text(members, "点按成员查看健康、疲劳与最近记忆", Vector2(16, 447), Vector2(317, 14), 11, MUTED)
	var back := _button(self, "回到当前阶段", Rect2(518, 602, 244, 63), func(): close_requested.emit(), "close_team")
	back.add_theme_stylebox_override("normal", _metal())
	back.add_theme_font_size_override("font_size", 26)
	_text(self, "", Vector2(350, 672), Vector2(580, 20), 12, CREAM).name = "StageCaption"
	_build_detail()

func refresh(state: GameState, loop: DayLoop, current_phase: String, reset_view: bool = false) -> void:
	game_state = state
	day_loop = loop
	phase_name = current_phase
	arrived_stop = state.day if state.phase in [GameState.Phase.REST_STOP, GameState.Phase.STOP_DIALOGUE, GameState.Phase.CAMP_ACTION, GameState.Phase.NIGHT_SETTLEMENT] or loop.travel_progress >= 1.0 else state.day - 1
	if reset_view:
		map_page = (state.day - 1) / 5
		selected_stop = state.day
		member_detail.hide()
	heading.text = "第 %d 天  |  %d 人  |  %s" % [state.day, state.members.size(), current_phase]
	get_node("StageCaption").text = "当前：%s  ·  关闭总览后继续" % current_phase
	get_node("StageCaption").horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for key in resource_values:
		var value := state.team_trust if key == "trust" else int(state.resources.get(key, 0))
		var baseline := 100 if key == "trust" else int(loop.content.initial_resources().get(key, 1))
		resource_bars[key].max_value = maxi(1, baseline)
		resource_bars[key].value = mini(value, baseline)
		resource_values[key].text = "%d / 100" % value if key == "trust" else "%d 份" % value
		var hint := "" if key == "trust" else ""
		var warning := false
		if key in ["water", "food"]:
			var cost := loop.content.daily_cost(key)
			var nights := value / maxi(1, cost)
			hint = "基础配给可供 %d 晚" % nights
			warning = value < cost * 2
		elif key == "fuel":
			var cost := loop.route_fuel_cost()
			hint = "本次行程需要 %d 份" % cost
			warning = value < cost
		elif key == "medicine":
			hint = "治疗成员的储备"
			warning = value == 0
		elif key == "parts":
			hint = "车辆耐久 %d / 100" % state.vehicle_health
			warning = value == 0
		else:
			hint = "平均疲劳 %d / 100" % state.fatigue
			warning = value <= 30
		resource_hints[key].text = ("不足 · " if warning else "") + hint
		resource_hints[key].add_theme_color_override("font_color", GOLD if warning else MUTED)
		resource_values[key].add_theme_color_override("font_color", GOLD if warning else CREAM)
		resource_bars[key].tooltip_text = "初始储备参考 %d，当前 %d；资源没有容量上限" % [baseline, value] if key != "trust" else "全队信任"
	_rebuild_members()
	_update_map()
	if member_detail.visible and not inspected_member.is_empty(): _show_member(inspected_member)
	snapshot = _state_snapshot()

func _process(_delta: float) -> void:
	if visible and game_state != null and _state_snapshot() != snapshot:
		refresh(game_state, day_loop, phase_name)

func _state_snapshot() -> String:
	return JSON.stringify([game_state.day, game_state.phase, game_state.resources, game_state.members, game_state.team_trust, game_state.vehicle_health, game_state.fatigue, game_state.major_route, day_loop.route_choice])

func _rebuild_members() -> void:
	for child in team_cards.get_children():
		team_cards.remove_child(child)
		child.queue_free()
	for member in game_state.members:
		var member_name := str(member.name)
		var button := _button(team_cards, "", Rect2(0, 0, 320, 70), func(): _show_member(member_name), "member_" + member_name)
		button.custom_minimum_size = Vector2(0, 70)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_stylebox_override("normal", _metal(true))
		_picture(button, PORTRAITS.get(member_name, "captain") + ".png", Vector2(4, 4), Vector2(61, 62))
		_text(button, member_name, Vector2(79, 6), Vector2(136, 27), 21, CREAM)
		_text(button, str(member.job), Vector2(79, 35), Vector2(136, 22), 15, MUTED)
		var condition := member_condition(member)
		var mark := "✓" if condition.text == "良好" else ("+" if condition.text in ["受伤", "危急"] else "!")
		_text(button, mark + " " + str(condition.text), Vector2(223, 17), Vector2(90, 25), 17, condition.color)
		_text(button, "›", Vector2(297, 43), Vector2(16, 17), 16, MUTED)
		button.tooltip_text = day_loop.member_summary(member_name)

static func member_condition(member: Dictionary) -> Dictionary:
	if int(member.health) <= 0: return {"text": "危急", "color": RED}
	if int(member.health) < 100: return {"text": "受伤", "color": RED}
	if int(member.fatigue) >= 70: return {"text": "疲惫", "color": GOLD}
	if int(member.trust) <= 30: return {"text": "不安", "color": GOLD}
	return {"text": "良好", "color": GREEN}

func _select_stop(day: int) -> void:
	selected_stop = day
	_update_map()

func _change_page(change: int) -> void:
	var pages := ceili(day_loop.content.demo_days() / 5.0)
	map_page = clampi(map_page + change, 0, pages - 1)
	selected_stop = map_page * 5 + 1
	_update_map()

func _update_map() -> void:
	page_label.text = "%d/%d" % [map_page + 1, ceili(day_loop.content.demo_days() / 5.0)]
	for i in range(map_pins.size()):
		var day := map_page * 5 + i + 1
		map_pins[i].text = str(day)
		map_pins[i].visible = day <= day_loop.content.demo_days()
		map_pins[i].tooltip_text = day_loop.content.stop_name(day)
		var color := GOLD if day == game_state.day else (GREEN if day <= arrived_stop else MUTED)
		map_pins[i].add_theme_color_override("font_color", color)
		map_pins[i].add_theme_stylebox_override("normal", _flat(Color("#182326"), color, 14))
	var state := "已经过" if selected_stop <= arrived_stop else "待抵达"
	if selected_stop == game_state.day:
		state = "当前" if arrived_stop == game_state.day else "今日目标"
	stop_label.text = "%d · %s  [%s]" % [selected_stop, day_loop.content.stop_name(selected_stop), state]
	route_label.text = game_state.major_route if not game_state.major_route.is_empty() else day_loop.route_choice
	map_surface.queue_redraw()

func _draw_map() -> void:
	if game_state == null: return
	for i in range(4):
		var first := map_points[i]
		var second := map_points[i + 1]
		var bend := Vector2((first.x + second.x) * 0.5, (first.y + second.y) * 0.5 + 14)
		var visited := map_page * 5 + i + 2 <= arrived_stop
		for ends in [[first, bend], [bend, second]]:
			if visited: map_surface.draw_line(ends[0], ends[1], GOLD.darkened(0.2), 2, true)
			else: map_surface.draw_dashed_line(ends[0], ends[1], Color(0.63, 0.67, 0.64, 0.8), 1.5, 5, true)
	for i in range(5):
		var day := map_page * 5 + i + 1
		var point := map_points[i]
		if day == game_state.day:
			map_surface.draw_circle(point, 30, Color(0.87, 0.67, 0.24, 0.12))
			map_surface.draw_arc(point, 24, 0, TAU, 48, GOLD, 1, true)
		if day == selected_stop: map_surface.draw_arc(point, 20, 0, TAU, 40, CREAM, 1, true)
		var font := get_theme_default_font()
		var name := day_loop.content.stop_name(day)
		var text_width := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		var text_pos := Vector2(clampf(point.x - text_width / 2, 7, 352 - text_width), point.y + 33)
		map_surface.draw_string(font, text_pos, name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, GOLD if day == game_state.day else CREAM)
	map_surface.draw_rect(Rect2(Vector2.ZERO, map_surface.size), Color("#69716b"), false, 1)
	map_surface.draw_line(Vector2(333, 31), Vector2(333, 53), MUTED, 1)
	map_surface.draw_line(Vector2(322, 42), Vector2(344, 42), MUTED, 1)

func _build_detail() -> void:
	member_detail = Control.new()
	member_detail.size = size
	member_detail.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(member_detail)
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.025, 0.85)
	dim.size = size
	member_detail.add_child(dim)
	var panel := _panel(member_detail, Rect2(340, 178, 600, 360))
	detail_portrait = _picture(panel, "captain.png", Vector2(24, 24), Vector2(110, 120))
	detail_name = _text(panel, "", Vector2(156, 25), Vector2(419, 40), 28, CREAM)
	detail_scroll = ScrollContainer.new()
	detail_scroll.position = Vector2(156, 80)
	detail_scroll.size = Vector2(416, 164)
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(detail_scroll)
	detail_summary = _text(detail_scroll, "", Vector2.ZERO, Vector2.ZERO, 19, CREAM)
	detail_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_summary.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_text(panel, "疲劳达到70，每晚健康减少5；受伤可通过医疗行动恢复。", Vector2(25, 252), Vector2(550, 36), 15, MUTED)
	_button(panel, "返回状态总览", Rect2(190, 301, 220, 43), func(): member_detail.hide(), "close_member_detail")
	member_detail.hide()

func _show_member(member_name: String) -> void:
	var member := game_state.member_named(member_name)
	if member.is_empty(): return
	if inspected_member != member_name or not member_detail.visible: detail_scroll.scroll_vertical = 0
	inspected_member = member_name
	detail_portrait.texture = load(ART + PORTRAITS.get(member_name, "captain") + ".png")
	detail_name.text = "%s · %s" % [member_name, member.job]
	detail_summary.text = "健康     %d / 100\n疲劳     %d / 100\n个人信任     %d / 100\n\n最近记忆\n%s" % [member.health, member.fatigue, member.trust, member.last_memory]
	member_detail.show()

func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"): return
	if member_detail.visible: member_detail.hide()
	else: close_requested.emit()
	get_viewport().set_input_as_handled()

func _picture(parent: Node, file: String, point: Vector2, dimensions: Vector2) -> TextureRect:
	var picture := TextureRect.new()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.texture = load(ART + file)
	picture.position = point
	picture.size = dimensions
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(picture)
	return picture

func _icon(parent: Node, file: String, point: Vector2, dimension: int, color: Color) -> void:
	var icon := _picture(parent, "icons/" + file + ".svg", point, Vector2(dimension, dimension))
	icon.modulate = color

func _text(parent: Node, value: String, point: Vector2, dimensions: Vector2, font_size: int, color: Color) -> Label:
	var label := ConvoyTheme.label(value, font_size, color)
	label.position = point
	label.size = dimensions
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	parent.add_child(label)
	return label

func _panel(parent: Node, rect: Rect2, row: bool = false) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _metal(row))
	parent.add_child(panel)
	return panel

func _metal(row: bool = false) -> StyleBoxTexture:
	var material := StyleBoxTexture.new()
	material.texture = load(ART + ("row.png" if row else "panel.png"))
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]: material.set_texture_margin(side, 16)
	return material

func _button(parent: Node, value: String, rect: Rect2, callback: Callable, action: String) -> Button:
	var button := Button.new()
	button.text = value
	button.position = rect.position
	button.size = rect.size
	button.set_meta("action_id", action)
	button.pressed.connect(callback)
	button.add_theme_color_override("font_color", CREAM)
	button.add_theme_stylebox_override("normal", _flat(Color("#0f191de8"), Color("#7e8277"), 3))
	button.add_theme_stylebox_override("hover", _flat(Color("#28302e"), GOLD, 3))
	button.add_theme_stylebox_override("pressed", _flat(Color("#383a2c"), GOLD, 3))
	button.add_theme_stylebox_override("focus", _flat(Color(0, 0, 0, 0), GOLD, 3))
	parent.add_child(button)
	return button

static func _flat(fill: Color, edge: Color, radius: int) -> StyleBoxFlat:
	var material := StyleBoxFlat.new()
	material.bg_color = fill
	material.border_color = edge
	material.set_border_width_all(1)
	material.set_corner_radius_all(radius)
	return material
