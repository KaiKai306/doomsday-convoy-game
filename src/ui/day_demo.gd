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
var team_overlay: StatusOverview
var team_cards: VBoxContainer
var team_open := false
var camp_view := "site"

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
	var team_button := ConvoyTheme.button("状态总览", _toggle_team, "team")
	team_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	team_button.custom_minimum_size.x = 140
	header.add_child(team_button)
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
	var build_label := ConvoyTheme.label("十日框架版 · 场景占位", 13, ConvoyTheme.MUTED)
	build_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	build_label.custom_minimum_size.x = 170
	stage_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	footer.add_child(build_label)
	_build_team()
	_build_pause()

func _build_team() -> void:
	team_overlay = StatusOverview.new()
	team_overlay.hide()
	canvas.add_child(team_overlay)
	team_overlay.close_requested.connect(_toggle_team)
	team_cards = team_overlay.team_cards

func _toggle_team() -> void:
	if paused: return
	team_open = not team_open
	team_overlay.visible = team_open
	world.paused = team_open
	exploration.set_active(game_state.phase in [GameState.Phase.REST_STOP, GameState.Phase.STOP_DIALOGUE], team_open)
	if not team_open: return
	team_overlay.refresh(game_state, day_loop, _phase_name(), true)

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
	if day_loop == null or paused or team_open: return
	if game_state.phase in [GameState.Phase.REST_STOP, GameState.Phase.STOP_DIALOGUE] and not day_loop.conversation_open:
		for child in actions.get_children():
			if child is Button and child.get_meta("action_id", "") == "inspect_nearby":
				child.disabled = exploration.nearby_member().is_empty()
	if game_state.phase == GameState.Phase.TRAVEL:
		var finished := day_loop.tick_travel(delta)
		travel_bar.value = day_loop.travel_progress
		world.progress = day_loop.travel_progress
		if finished: refresh()

func refresh() -> void:
	if team_open: team_overlay.refresh(game_state, day_loop, _phase_name())
	for child in actions.get_children():
		actions.remove_child(child)
		child.queue_free()
	for child in primary_actions.get_children():
		primary_actions.remove_child(child)
		child.queue_free()
	world.phase = game_state.phase
	world.progress = day_loop.travel_progress
	world.day = game_state.day
	world.moving = game_state.phase == GameState.Phase.TRAVEL
	world.visible = game_state.phase not in [GameState.Phase.REST_STOP, GameState.Phase.STOP_DIALOGUE]
	exploration.set_active(game_state.phase in [GameState.Phase.REST_STOP, GameState.Phase.STOP_DIALOGUE], paused or team_open)
	world.queue_redraw()
	title.text = "末日车队  /  第 %02d 天" % game_state.day
	location.text = "%02d / %02d  %s · %s" % [game_state.day, day_loop.content.demo_days(), day_loop.content.stop_name(game_state.day), _phase_name()]
	for key in resource_labels:
		resource_labels[key].text = "%s   %02d" % [DemoContent.RESOURCE_NAMES[key], game_state.resources[key]]
		resource_labels[key].add_theme_color_override("font_color", Color("#ef9c83") if int(game_state.resources[key]) < 4 else ConvoyTheme.TEXT)
	status.text = "耐久 %d/100    全队信任 %d/100    平均疲劳 %d\n知识 %d    追踪 %d/100    队伍 %d 人" % [game_state.vehicle_health, game_state.team_trust, game_state.fatigue, game_state.knowledge, game_state.tracking, game_state.members.size()]
	feedback.text = day_loop.event_log.back() if not day_loop.event_log.is_empty() else "先让五个人活过今天，再想更远的地方。"
	stage_label.text = "准备 › 五人事务 › 选路 › 移动 › 事件 › 停歇 › 对话 › 夜间  /  %s" % _phase_name()
	stage_label.add_theme_font_size_override("font_size", 14)
	travel_bar.value = day_loop.travel_progress
	travel_bar.visible = game_state.phase == GameState.Phase.TRAVEL
	match game_state.phase:
		GameState.Phase.MORNING: _morning()
		GameState.Phase.MEMBER_AFFAIRS: _dialogue()
		GameState.Phase.MAJOR_ROUTE_SELECTION: _major_routes()
		GameState.Phase.ROUTE_SELECTION: _routes()
		GameState.Phase.TRAVEL:
			_heading("引擎启动，沿公路前进", "路线和预设已锁定。途中会出现一次即时事件，处理后继续前往停歇点。")
			_note("预设：%s\n事故概率：%.0f%%\n快速行驶：疲劳 +6、追踪 +8\n低噪音：疲劳 +10、追踪 -2\n绕行：疲劳 +10、追踪 +1" % [day_loop.travel_style, day_loop.route_accident_chance() * 100])
			_note("疲劳变化作用于全员；阿杰沿途侦察另增疲劳 +3。道路事故可能擦伤老张，追踪过高会让阿杰受伤。")
		GameState.Phase.TRAVEL_EVENT: _travel_event()
		GameState.Phase.REST_STOP:
			_heading("抵达临时停歇点", "补给已经入库。现在可以走动、查看成员状态，再开始停歇对话。")
			_note("本次补给：" + day_loop.content.cost_text(day_loop.route_supplies(), true))
			_action("开始 NPC 对话 →", func(): _execute(day_loop.begin_stop_dialogues()), "stop_dialogues")
		GameState.Phase.STOP_DIALOGUE:
			if day_loop.conversation_open: _dialogue()
			else: _explore()
		GameState.Phase.CAMP_ACTION: _camp()
		GameState.Phase.NIGHT_SETTLEMENT: _night()
		GameState.Phase.ENDING:
			_heading(game_state.ending, day_loop.content.ending_text(game_state.ending))
			_note("旅途持续 %d 天 · 知识 %d · 信任 %d\n\n本次十日框架体验结束。剧情与正式美术将在后续补充。" % [game_state.day, game_state.knowledge, game_state.team_trust])
			_action("回到主菜单", func(): return_to_menu.emit(), "ending_menu")

func _morning() -> void:
	_heading("天亮了，先看看大家", "今晚基本配给：饮水 5 / 食物 4。出发前可以做一次准备；随后必须回应五名成员的当日事务。")
	if game_state.day == 1: _note(str(day_loop.content.data.get("opening_scene", "")))
	_note("当前车辆：" + day_loop.content.vehicle_summary())
	if not game_state.major_route.is_empty(): _note("剧情方向：%s\n当前阶段：%s" % [game_state.major_route, game_state.world_facts.get("story_checkpoint", "")])
	_note(day_loop.content.members_summary())
	var patient := day_loop.medical_target()
	_note("最需关注：%s / 健康 %d，疲劳 %d\n今日抵达后：%s" % [patient.name, patient.health, patient.fatigue, day_loop.content.stop_event(game_state.day).get("title", "")])
	_note("今日事务\n" + day_loop.transaction_summary())
	if not day_loop.prepared:
		_action("检查车辆  /  零件 -1，耐久 +6", func(): _execute(day_loop.prepare("检查车辆")), "prepare_repair", day_loop.can_afford({"parts": 1}))
		_action("公开情报  /  信任 +2", func(): _execute(day_loop.prepare("公开情报")), "prepare_info")
		_action("分配饮水  /  饮水 -2，疲劳 -8", func(): _execute(day_loop.prepare("分配饮水")), "prepare_water", day_loop.can_afford({"water": 2}))
	else: _note("今日准备已完成。")
	_action("处理五名成员事务  →", func(): _execute(day_loop.finish_preparation()), "routes")

func _major_routes() -> void:
	_heading("第%d天 · 大路线选择" % game_state.day, "决定接下来的剧情方向和区域资源。第2、5、8、10天可以重新选择方向。")
	_note("当前方向：" + (game_state.major_route if not game_state.major_route.is_empty() else "尚未选择"))
	for route_name in day_loop.content.major_routes():
		var route: Dictionary = day_loop.content.major_route_data(route_name)
		_note("%s\n剧情阶段：%s\n今日补给：%s\n之后小路线额外补给：%s" % [route.description, day_loop.content.major_checkpoint(game_state.day, route_name), day_loop.content.cost_text(route.supplies, true), day_loop.content.cost_text(route.daily_bonus, true)])
		_action("选择 " + route_name, func(): _execute(day_loop.select_major_route(route_name)), "major_" + route_name)

func _travel_event() -> void:
	_heading("途中即时事件", "按出发前选定的行进预设处理；每一天只触发一次。")
	if not day_loop.travel_resolved:
		_note("前方道路与追踪情况发生变化。当前预设：" + day_loop.travel_style)
		_action("按预设处理事件", func(): _execute(day_loop.resolve_travel_event()), "resolve_event")
	else:
		_note(day_loop.travel_event_text)
		_action("继续车队移动 →", func(): _execute(day_loop.continue_after_event()), "continue_travel")

func _routes() -> void:
	if day_loop.content.is_major_route_day(game_state.day):
		_heading("大路线已确定，准备出发", "今天沿已选的大路线行驶，只需确认行进预设。小路线在第1、3、4、6、7、9天选择。")
		var route := day_loop.current_route_data()
		_note("%s · %s\n今日补给：%s" % [game_state.major_route, route.description, day_loop.content.cost_text(day_loop.route_supplies(), true)])
	else:
		_heading("选择今天的小路线", "只影响资源种类、数量和途中风险，不改变大路线或剧情方向。补给在抵达后获得。")
		_note("剧情方向：" + (game_state.major_route if not game_state.major_route.is_empty() else "第2天决定"))
		for route_name in day_loop.content.routes():
			var route: Dictionary = day_loop.content.route_data(route_name)
			var chosen: bool = route_name == day_loop.route_choice
			_action(("%s  " % ("●" if chosen else "○")) + route_name + "  /  燃料 -%d" % int(route.fuel_cost), func(): _execute(day_loop.choose_route(route_name)), "route_" + route_name)
			var supplies: Dictionary = route.supplies.duplicate()
			for key in day_loop.content.major_route_data(game_state.major_route).get("daily_bonus", {}):
				supplies[key] = int(supplies.get(key, 0)) + int(day_loop.content.major_route_data(game_state.major_route).daily_bonus[key])
			_note("%s\n抵达补给：%s" % [route.description, day_loop.content.cost_text(supplies, true)])
	_note("移动预设：低噪音减少追踪；快速降低疲劳但更吵；绕行多用 2 燃料，事故率 -10%，事故损伤较小。")
	var styles := HBoxContainer.new()
	primary_actions.add_child(styles)
	for style in ["低噪音", "快速", "绕行"]:
		styles.add_child(ConvoyTheme.button(("● " if day_loop.travel_style == style else "") + style, func(): _execute(day_loop.choose_style(style)), "style_" + style))
	primary_actions.add_child(ConvoyTheme.label("本次燃料 -%d / 道路事故 %.0f%%" % [day_loop.route_fuel_cost(), day_loop.route_accident_chance() * 100], 16, ConvoyTheme.GOLD))
	_action("确认出发  →", func(): _execute(day_loop.start_travel()), "depart", day_loop.can_afford({"fuel": day_loop.route_fuel_cost()}))
	var stranded := false
	if day_loop.content.is_major_route_day(game_state.day):
		stranded = int(game_state.resources.fuel) < int(day_loop.current_route_data().get("fuel_cost", 0))
	else:
		stranded = true
		for route in day_loop.content.routes():
			if int(game_state.resources.fuel) >= day_loop.content.route_fuel_cost(route): stranded = false
	if stranded:
		_note("燃料不足以到达任一停歇点，旅途无法继续。")
		_action("查看旅途结果", func(): _execute(day_loop.abandon_journey()), "stranded")

func _dialogue() -> void:
	var transaction := day_loop.current_transaction()
	_heading(("出发前事务 · " if game_state.phase == GameState.Phase.MEMBER_AFFAIRS else "停歇对话 · ") + "%s · %s" % [transaction.speaker, transaction.job], transaction.body)
	var member := game_state.member_named(str(transaction.speaker))
	_note("说话者健康 %d / 疲劳 %d / 个人信任 %d" % [member.health, member.fatigue, member.trust])
	_note("事务 %d / %d   ·   紧急度%s\n%s" % [day_loop.transaction_index + 1, day_loop.daily_transactions.size(), transaction.urgency, transaction.goal])
	for choice in ["accept", "refuse", "defer"]:
		var option: Dictionary = transaction.responses[choice]
		_action(option.label + "\n" + option.effect, func(): _execute(day_loop.respond(choice)), "respond_" + choice, day_loop.can_afford(option.cost))
		_note("之后：" + str(option.future))
	if game_state.phase == GameState.Phase.STOP_DIALOGUE:
		_action("先结束交谈，回到营地", _close_conversation, "close_conversation")

func _explore() -> void:
	var transaction := day_loop.current_transaction()
	_heading("抵达营地，先找大家聊聊", "点按地面让主角走过去，或按住场景中的左右方向。靠近队员后点按交谈。")
	_note("先处理：%s · %s\n紧急度%s / 剩余 %d 条事务" % [transaction.speaker, transaction.goal, transaction.urgency, day_loop.daily_transactions.size() - day_loop.transaction_index])
	_note("回应会影响物资、信任和下一天的请求。现在只是走动与了解情况，不会自动消耗资源。")
	if transaction.speaker == "主角":
		_action("整理并说明主角的计划", func(): _execute(day_loop.begin_conversation("主角")), "captain_reflection")
	if not inspected_member.is_empty():
		for member in day_loop.content.camp_members():
			if member.name == inspected_member:
				_note(day_loop.member_summary(str(member.name)))
				_note(str(member.idle))
				if day_loop.current_transaction().speaker != inspected_member:
					_note("当前优先处理%s的事务，之后再继续回应其他请求。" % transaction.speaker)
	_action("查看成员情况", exploration.try_interact, "inspect_nearby", not exploration.nearby_member().is_empty())
	_note(day_loop.content.members_summary())

func _interact_with_member(speaker: String) -> void:
	if game_state.phase != GameState.Phase.STOP_DIALOGUE or paused or team_open: return
	inspected_member = speaker
	if day_loop.current_transaction().speaker == speaker:
		day_loop.begin_conversation(speaker)
	refresh()

func _close_conversation() -> void:
	day_loop.close_conversation()
	exploration.release_controls()
	refresh()

func _camp() -> void:
	_heading("NPC 对话结束，准备夜间结算", "可以直接结算，也可以安排一次补给、维修、阅读或照料。")
	_action("直接进入夜间结算 →", func(): _execute(day_loop.finish_stop_dialogues()), "settle_night")
	var tabs := HBoxContainer.new()
	primary_actions.add_child(tabs)
	for view in ["site", "daily", "medical"]:
		var names := {"site": "当地发现", "daily": "常规行动", "medical": "照料成员"}
		tabs.add_child(ConvoyTheme.button(("● " if camp_view == view else "") + str(names[view]), func(): _switch_camp_view(view), "camp_tab_" + view))
	if camp_view == "site":
		var event := day_loop.content.stop_event(game_state.day)
		_heading(str(event.get("title", "当地发现")), str(event.get("description", "")))
		for action_name in event.get("actions", {}):
			var action: Dictionary = event.actions[action_name]
			_action(action_name, func(): _execute(day_loop.perform_camp_action(action_name)), "site_" + action_name, day_loop.can_afford(action.cost))
			_note(str(action.effect))
		return
	if camp_view == "medical":
		_note("照料一个成员 / 药品 -1\n健康 +25，疲劳 -10，个人信任 +3；占用今晚行动。")
		for member in game_state.members:
			if int(member.health) < 100 or int(member.fatigue) > 0:
				_action("照料%s / 健康 %d，疲劳 %d" % [member.name, member.health, member.fatigue], func(): _execute(day_loop.perform_camp_action("照料伤员", str(member.name))), "treat_" + str(member.name), day_loop.can_afford({"medicine": 1}))
		return
	for name_key in day_loop.content.camp_actions():
		var action: Dictionary = day_loop.content.camp_actions()[name_key]
		if action.get("target_required", false): continue
		var unlocked: bool = not action.get("requires_manual", false) or game_state.world_facts.get("manual_read", false)
		_action(name_key, func(): _execute(day_loop.perform_camp_action(name_key)), "camp_" + name_key, unlocked and day_loop.can_afford(action.cost))
		_note(str(action.effect) + ("\n需要先阅读技术手册。" if not unlocked else ""))

func _switch_camp_view(view: String) -> void:
	camp_view = view
	refresh()

func _night() -> void:
	_heading("今夜，选择留下了什么", "夜间配给已扣除。以下结果已经生效。")
	_note(day_loop.event_log_text())
	_note("留给明天\n" + day_loop.next_day_effects_text())
	_action("查看旅途结果" if not game_state.ending.is_empty() else ("第 %d 天 · 选择大路线 →" if day_loop.content.is_major_route_day(game_state.day + 1) else "进入第 %d 天 →") % (game_state.day + 1), func(): _execute(day_loop.advance_to_next_day()), "next_day")

func _heading(text: String, description: String) -> void:
	actions.add_child(ConvoyTheme.label(text, 25, ConvoyTheme.GOLD))
	actions.add_child(ConvoyTheme.label(description, 18))

func _note(text: String) -> void:
	actions.add_child(ConvoyTheme.label(text, 16, ConvoyTheme.MUTED))

func _action(text: String, callback: Callable, id: String, enabled: bool = true) -> void:
	var button := ConvoyTheme.button(text, callback, id)
	button.disabled = not enabled
	button.add_theme_font_size_override("font_size", 17)
	if id in ["routes", "depart", "next_day", "ending_menu", "stranded", "close_conversation", "stop_dialogues", "resolve_event", "continue_travel", "settle_night"]:
		primary_actions.add_child(button)
	else:
		actions.add_child(button)

func _execute(success: bool) -> void:
	if success:
		inspected_member = ""
		if game_state.phase != GameState.Phase.CAMP_ACTION: camp_view = "site"
		refresh()
	else: feedback.text = day_loop.last_error if not day_loop.last_error.is_empty() else "这个行动目前无法执行。"

func _toggle_pause() -> void:
	if team_open: return
	paused = not paused
	world.paused = paused
	exploration.set_active(game_state.phase in [GameState.Phase.REST_STOP, GameState.Phase.STOP_DIALOGUE], paused)
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
	return ["早晨准备", "路线出发", "车队移动", "抵达停歇点", "NPC 对话收尾", "夜间结算", "旅途结果", "五名成员事务", "一次即时事件", "NPC 对话", "大路线选择"][game_state.phase]
