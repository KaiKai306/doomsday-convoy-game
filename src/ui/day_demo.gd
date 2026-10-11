class_name DayDemo
extends Control

signal return_to_menu

var game_state: GameState
var day_loop: DayLoop
var save_system := SaveSystem.new()
var canvas: Control
var world: ConvoyWorld
var exploration: CampExploration
var inspected_member: String = ""
var title: Label
var resource_labels: Dictionary = {}
var status: Label
var location: Label
var feedback: Label
var stage_label: Label
var actions: VBoxContainer
var primary_actions: VBoxContainer
var pause_overlay: ColorRect
var pause_status: Label
var travel_bar: ProgressBar
var paused := false

func _ready() -> void:
	theme = ConvoyTheme.create()
	canvas = Control.new()
	canvas.size = Vector2(1280, 720)
	add_child(canvas)
	get_viewport().size_changed.connect(_fit)
	_fit()
	_build()

func _fit() -> void:
	var viewport_size := get_viewport_rect().size
	var factor := minf(viewport_size.x / 1280.0, viewport_size.y / 720.0)
	canvas.scale = Vector2.ONE * factor
	canvas.position = (viewport_size - Vector2(1280, 720) * factor) / 2

func _build() -> void:
	var background := ColorRect.new()
	background.color = ConvoyTheme.INK
	background.size = Vector2(1280, 720)
	canvas.add_child(background)
	var layout := VBoxContainer.new()
	layout.position = Vector2(24, 18)
	layout.size = Vector2(1232, 684)
	canvas.add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	title = ConvoyTheme.label("", 27, ConvoyTheme.GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var pause_button := ConvoyTheme.button("暂停 / 存档", _toggle_pause, "pause")
	pause_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	pause_button.custom_minimum_size.x = 172
	header.add_child(pause_button)
	var resources := HBoxContainer.new()
	layout.add_child(resources)
	for key in DemoContent.RESOURCE_NAMES:
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var label := ConvoyTheme.label("", 20)
		card.add_child(label)
		resources.add_child(card)
		resource_labels[key] = label
	var center := HBoxContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(center)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_child(left)
	location = ConvoyTheme.label("", 18, ConvoyTheme.BLUE)
	left.add_child(location)
	world = ConvoyWorld.new()
	world.custom_minimum_size = Vector2(0, 270)
	world.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(world)
	exploration = CampExploration.new()
	left.add_child(exploration)
	exploration.hide()
	exploration.interaction_requested.connect(_interact_with_member)
	travel_bar = ProgressBar.new()
	travel_bar.custom_minimum_size.y = 7
	travel_bar.show_percentage = false
	travel_bar.max_value = 1.0
	left.add_child(travel_bar)
	var state_card := PanelContainer.new()
	left.add_child(state_card)
	var state_layout := VBoxContainer.new()
	state_card.add_child(state_layout)
	status = ConvoyTheme.label("", 17)
	state_layout.add_child(status)
	feedback = ConvoyTheme.label("", 16, ConvoyTheme.MUTED)
	feedback.custom_minimum_size.y = 45
	state_layout.add_child(feedback)
	var decisions := PanelContainer.new()
	decisions.custom_minimum_size.x = 474
	center.add_child(decisions)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var decision_stack := VBoxContainer.new()
	decisions.add_child(decision_stack)
	decision_stack.add_child(scroll)
	actions = VBoxContainer.new()
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(actions)
	primary_actions = VBoxContainer.new()
	decision_stack.add_child(primary_actions)
	var footer := HBoxContainer.new()
	layout.add_child(footer)
	stage_label = ConvoyTheme.label("", 16, ConvoyTheme.MUTED)
	stage_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(stage_label)
	var build_label := ConvoyTheme.label("五日体验版 · 场景占位", 13, ConvoyTheme.MUTED)
	build_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	build_label.custom_minimum_size.x = 170
	stage_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	footer.add_child(build_label)
	_build_pause()

func _build_pause() -> void:
	pause_overlay = ColorRect.new()
	pause_overlay.color = Color(0.015, 0.035, 0.06, 0.94)
	pause_overlay.size = Vector2(1280, 720)
	pause_overlay.hide()
	canvas.add_child(pause_overlay)
	var panel := PanelContainer.new()
	panel.position = Vector2(400, 120)
	panel.size = Vector2(480, 480)
	pause_overlay.add_child(panel)
	var list := VBoxContainer.new()
	panel.add_child(list)
	list.add_child(ConvoyTheme.label("在这里歇一会儿", 28, ConvoyTheme.GOLD))
	pause_status = ConvoyTheme.label("旅途已经暂停。", 17, ConvoyTheme.MUTED)
	list.add_child(pause_status)
	list.add_child(ConvoyTheme.button("继续旅程", _toggle_pause, "resume"))
	list.add_child(ConvoyTheme.button("保存当前进度", _save, "save"))
	list.add_child(ConvoyTheme.button("读取已存进度", _load, "load"))
	list.add_child(ConvoyTheme.button("返回主菜单", func(): return_to_menu.emit(), "menu"))
	list.add_child(ConvoyTheme.label("返回菜单前请保存；移动进度也会被保留。", 15, ConvoyTheme.MUTED))

func setup(state: GameState, saved: Dictionary = {}) -> bool:
	game_state = state
	day_loop = DayLoop.new(state, DemoContent.new())
	day_loop.start_new_game()
	if not saved.is_empty() and not save_system.restore(saved, state, day_loop): return false
	exploration.setup(day_loop)
	refresh()
	return true

func _process(delta: float) -> void:
	if day_loop == null or paused: return
	if game_state.phase == GameState.Phase.REST_STOP and not day_loop.conversation_open:
		for child in actions.get_children():
			if child is Button and child.get_meta("action_id", "") == "inspect_nearby":
				child.disabled = exploration.nearby_member().is_empty()
	if game_state.phase == GameState.Phase.TRAVEL:
		var finished := day_loop.tick_travel(delta)
		travel_bar.value = day_loop.travel_progress
		world.progress = day_loop.travel_progress
		if finished:
			day_loop.resolve_travel_event()
			refresh()

func refresh() -> void:
	for child in actions.get_children():
		actions.remove_child(child)
		child.queue_free()
	for child in primary_actions.get_children():
		primary_actions.remove_child(child)
		child.queue_free()
	world.phase = game_state.phase
	world.day = game_state.day
	world.moving = game_state.phase == GameState.Phase.TRAVEL
	world.visible = game_state.phase != GameState.Phase.REST_STOP
	exploration.set_active(game_state.phase == GameState.Phase.REST_STOP, paused)
	world.queue_redraw()
	title.text = "末日车队  /  第 %02d 天" % game_state.day
	location.text = "%02d / 05     %s    ·    %s" % [game_state.day, day_loop.content.stop_name(game_state.day), _phase_name()]
	for key in resource_labels:
		resource_labels[key].text = "%s   %02d" % [DemoContent.RESOURCE_NAMES[key], game_state.resources[key]]
		resource_labels[key].add_theme_color_override("font_color", Color("#ef9c83") if int(game_state.resources[key]) < 4 else ConvoyTheme.TEXT)
	status.text = "耐久 %d/100    信任 %d/100    疲劳 %d/100\n知识 %d    追踪 %d/100    队伍 5 人" % [game_state.vehicle_health, game_state.team_trust, game_state.fatigue, game_state.knowledge, game_state.tracking]
	feedback.text = day_loop.event_log.back() if not day_loop.event_log.is_empty() else "先让五个人活过今天，再想更远的地方。"
	stage_label.text = "早晨  ›  选路  ›  行进  ›  对话  ›  营地  ›  夜晚     /     当前：%s" % _phase_name()
	travel_bar.value = day_loop.travel_progress
	travel_bar.visible = game_state.phase == GameState.Phase.TRAVEL
	match game_state.phase:
		GameState.Phase.MORNING: _morning()
		GameState.Phase.ROUTE_SELECTION: _routes()
		GameState.Phase.TRAVEL:
			_heading("引擎启动，沿公路前进", "路线和预设已锁定。旅途中不再重新分配物资，约七秒后抵达。")
			_note("预设：%s\n事故概率：%.0f%%\n快速行驶：疲劳 +6、追踪 +8\n低噪音：疲劳 +10、追踪 -2\n绕行：疲劳 +10、追踪 +1" % [day_loop.travel_style, day_loop.route_accident_chance() * 100])
		GameState.Phase.REST_STOP:
			if day_loop.conversation_open: _dialogue()
			else: _explore()
		GameState.Phase.CAMP_ACTION: _camp()
		GameState.Phase.NIGHT_SETTLEMENT: _night()
		GameState.Phase.ENDING:
			_heading(game_state.ending, day_loop.content.ending_text(game_state.ending))
			_note("旅途持续 %d 天 · 知识 %d · 信任 %d\n\n本次五日体验到此结束。完整旅途还会继续延伸。" % [game_state.day, game_state.knowledge, game_state.team_trust])
			_action("回到主菜单", func(): return_to_menu.emit(), "ending_menu")

func _morning() -> void:
	_heading("天亮了，先看看大家", "今晚基本配给：饮水 5 / 食物 4。出发前可以做一次准备，也可以直接选路。")
	_note(day_loop.content.members_summary())
	_note("今日事务\n" + day_loop.transaction_summary())
	if not day_loop.prepared:
		_action("检查车辆  /  零件 -1，耐久 +6", func(): _execute(day_loop.prepare("检查车辆")), "prepare_repair", day_loop.can_afford({"parts": 1}))
		_action("公开情报  /  信任 +2", func(): _execute(day_loop.prepare("公开情报")), "prepare_info")
		_action("分配饮水  /  饮水 -2，疲劳 -8", func(): _execute(day_loop.prepare("分配饮水")), "prepare_water", day_loop.can_afford({"water": 2}))
	else: _note("今日准备已完成。")
	_action("查看今日路线  →", func(): _execute(day_loop.finish_preparation()), "routes")

func _routes() -> void:
	_heading("下一处停歇点，怎么走？", "补给在抵达后获得。事故概率会受维护、车损与移动预设影响。")
	for route_name in day_loop.content.routes():
		var route: Dictionary = day_loop.content.route_data(route_name)
		var chosen: bool = route_name == day_loop.route_choice
		_action(("%s  " % ("●" if chosen else "○")) + route_name + "  /  燃料 -%d" % int(route.fuel_cost), func(): _execute(day_loop.choose_route(route_name)), "route_" + route_name)
		_note("%s\n抵达补给：%s" % [route.description, day_loop.content.cost_text(route.supplies, true)])
	_note("移动预设：低噪音减少追踪；快速降低疲劳但更吵；绕行多用 2 燃料，事故率 -10%，事故损伤较小。")
	var styles := HBoxContainer.new()
	primary_actions.add_child(styles)
	for style in ["低噪音", "快速", "绕行"]:
		styles.add_child(ConvoyTheme.button(("● " if day_loop.travel_style == style else "") + style, func(): _execute(day_loop.choose_style(style)), "style_" + style))
	primary_actions.add_child(ConvoyTheme.label("本次燃料 -%d / 道路事故 %.0f%%" % [day_loop.route_fuel_cost(), day_loop.route_accident_chance() * 100], 16, ConvoyTheme.GOLD))
	_action("确认出发  →", func(): _execute(day_loop.start_travel()), "depart", day_loop.can_afford({"fuel": day_loop.route_fuel_cost()}))
	var stranded := true
	for route in day_loop.content.routes():
		if int(game_state.resources.fuel) >= day_loop.content.route_fuel_cost(route): stranded = false
	if stranded:
		_note("燃料不足以到达任一停歇点，旅途无法继续。")
		_action("查看旅途结果", func(): _execute(day_loop.abandon_journey()), "stranded")

func _dialogue() -> void:
	var transaction := day_loop.current_transaction()
	_heading("%s · %s" % [transaction.speaker, transaction.job], transaction.body)
	_note("事务 %d / %d   ·   紧急度%s\n%s" % [day_loop.transaction_index + 1, day_loop.daily_transactions.size(), transaction.urgency, transaction.goal])
	for choice in ["accept", "refuse", "defer"]:
		var option: Dictionary = transaction.responses[choice]
		_action(option.label + "\n" + option.effect, func(): _execute(day_loop.respond(choice)), "respond_" + choice, day_loop.can_afford(option.cost))
		_note("之后：" + str(option.future))
	_action("先结束交谈，回到营地", _close_conversation, "close_conversation")

func _explore() -> void:
	var transaction := day_loop.current_transaction()
	_heading("抵达营地，先找大家聊聊", "点按地面让队长走过去，或按住场景中的左右方向。靠近队员后点按交谈。")
	_note("先处理：%s · %s\n紧急度%s / 剩余 %d 条事务" % [transaction.speaker, transaction.goal, transaction.urgency, day_loop.daily_transactions.size() - day_loop.transaction_index])
	_note("回应会影响物资、信任和下一天的请求。现在只是走动与了解情况，不会自动消耗资源。")
	if not inspected_member.is_empty():
		for member in day_loop.content.camp_members():
			if member.name == inspected_member:
				_note("%s · %s\n%s" % [member.name, member.job, member.idle])
				if day_loop.current_transaction().speaker != inspected_member:
					_note("当前优先处理%s的事务，之后再继续回应其他请求。" % transaction.speaker)
	_action("查看成员情况", exploration.try_interact, "inspect_nearby", not exploration.nearby_member().is_empty())
	_note(day_loop.content.members_summary())

func _interact_with_member(speaker: String) -> void:
	if game_state.phase != GameState.Phase.REST_STOP or paused: return
	inspected_member = speaker
	if day_loop.current_transaction().speaker == speaker:
		day_loop.begin_conversation(speaker)
	refresh()

func _close_conversation() -> void:
	day_loop.close_conversation()
	exploration.release_controls()
	refresh()

func _camp() -> void:
	_heading("火还亮着，今晚做什么？", "只能执行一次主要营地行动。选择后自动结算夜间配给。")
	for name_key in day_loop.content.camp_actions():
		var action: Dictionary = day_loop.content.camp_actions()[name_key]
		var unlocked: bool = not action.get("requires_manual", false) or game_state.world_facts.get("manual_read", false)
		_action(name_key, func(): _execute(day_loop.perform_camp_action(name_key)), "camp_" + name_key, unlocked and day_loop.can_afford(action.cost))
		_note(str(action.effect) + ("\n需要先阅读技术手册。" if not unlocked else ""))

func _night() -> void:
	_heading("今夜，选择留下了什么", "夜间配给已扣除。以下结果已经生效。")
	_note(day_loop.event_log_text())
	_note("留给明天\n" + day_loop.next_day_effects_text())
	_action("查看旅途结果" if not game_state.ending.is_empty() else "进入第 %d 天  →" % (game_state.day + 1), func(): _execute(day_loop.advance_to_next_day()), "next_day")

func _heading(text: String, description: String) -> void:
	actions.add_child(ConvoyTheme.label(text, 25, ConvoyTheme.GOLD))
	actions.add_child(ConvoyTheme.label(description, 18))

func _note(text: String) -> void:
	actions.add_child(ConvoyTheme.label(text, 16, ConvoyTheme.MUTED))

func _action(text: String, callback: Callable, id: String, enabled: bool = true) -> void:
	var button := ConvoyTheme.button(text, callback, id)
	button.disabled = not enabled
	button.add_theme_font_size_override("font_size", 17)
	if id in ["routes", "depart", "next_day", "ending_menu", "stranded", "close_conversation"]:
		primary_actions.add_child(button)
	else:
		actions.add_child(button)

func _execute(success: bool) -> void:
	if success:
		inspected_member = ""
		refresh()
	else: feedback.text = day_loop.last_error if not day_loop.last_error.is_empty() else "这个行动目前无法执行。"

func _toggle_pause() -> void:
	paused = not paused
	world.paused = paused
	exploration.set_active(game_state.phase == GameState.Phase.REST_STOP, paused)
	pause_overlay.visible = paused
	if paused: pause_status.text = "旅途已经暂停。"

func _save() -> void:
	pause_status.text = "已保存第 %d 天的进度。" % game_state.day if save_system.save_to_file(game_state, day_loop) else "保存失败，进度未写入。"

func _load() -> void:
	var saved := save_system.load_from_file()
	if saved.is_empty() or not save_system.restore(saved, game_state, day_loop):
		pause_status.text = "没有可用的本版本存档。"
		return
	_toggle_pause()
	inspected_member = ""
	refresh()

func _phase_name() -> String:
	return ["早晨准备", "路线选择", "自动行进", "停歇对话", "营地行动", "夜间结算", "旅途结果"][game_state.phase]
