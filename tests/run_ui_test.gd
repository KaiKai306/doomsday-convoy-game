extends SceneTree

var failures := 0
var checks := 0
var capture := false
var output_dir := ""
var main: Control

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	output_dir = args[0] if not args.is_empty() else ProjectSettings.globalize_path("res://.godot/convoy-qa")
	capture = "--capture" in args
	DirAccess.make_dir_recursive_absolute(output_dir)
	main = load("res://scenes/main.tscn").instantiate()
	main.save_system = SaveSystem.new(output_dir + "/save")
	root.add_child(main)
	await process_frame
	await _capture("01_menu")
	await _click(main, "new_game")
	if main.day_demo == null:
		_check(false, "主菜单点击打开新游戏")
		main.queue_free()
		await process_frame
		quit(1)
		return
	var ui: DayDemo = main.day_demo
	_manual(ui)
	ui.save_system = main.save_system
	_check(ui.game_state.phase == GameState.Phase.MORNING, "新游戏第1天早晨")
	await process_frame
	_check(_inside(ui, "routes"), "早晨推进按钮位于画布内")
	await _capture("02_morning")
	_press(ui, "team")
	_check(ui.team_open and ui.team_cards.get_child_count() == 5, "五名成员独立状态")
	await _capture("14_team")
	_press(ui, "close_team")
	_press(ui, "prepare_info")
	_check(ui.game_state.team_trust == 52, "准备行动真实生效")
	_press(ui, "routes")
	_check(ui.game_state.phase == GameState.Phase.MEMBER_AFFAIRS, "准备后必须处理成员事务")
	_check(_find(ui, "depart") == null, "成员事务未完不显示出发")
	await _capture("03_affairs")
	_morning_affairs(ui)
	_check(ui.day_loop.morning_resolutions.size() == 5, "五人全部回应有记录")
	_press(ui, "route_资源路线")
	_press(ui, "style_绕行")
	await process_frame
	_check(ui.day_loop.route_choice == "资源路线" and ui.day_loop.travel_style == "绕行", "路线与预设闭包正确")
	_check(_inside(ui, "depart") and _inside(ui, "style_绕行"), "出发与预设固定可见")
	await _capture("04_routes")
	_press(ui, "depart")
	_press(ui, "team")
	var progress := ui.day_loop.travel_progress
	ui._process(10)
	_check(ui.day_loop.travel_progress == progress, "查看成员暂停自动移动")
	_press(ui, "close_team")
	ui.day_loop.travel_progress = 0.3
	_press(ui, "pause")
	ui._process(10)
	_check(is_equal_approx(ui.day_loop.travel_progress, 0.3), "暂停停止移动")
	_press(ui, "save")
	_press(ui, "save")
	_check(not ui.save_system.load_from_file().is_empty(), "写盘与覆盖保存")
	ui.day_loop.travel_progress = 0.4
	_press(ui, "load")
	_check(not ui.paused and is_equal_approx(ui.day_loop.travel_progress, 0.3), "读档恢复行进")
	await _capture("05_travel")
	ui._process(10)
	_check(ui.game_state.phase == GameState.Phase.TRAVEL_EVENT, "移动到一半进入事件")
	var event_resources := ui.game_state.resources.duplicate()
	await _capture("06_event_pending")
	_roundtrip_ui(ui, "事件未处理")
	_press(ui, "resolve_event")
	_check(ui.day_loop.travel_resolved and ui.game_state.phase == GameState.Phase.TRAVEL_EVENT, "事件结果停留待确认")
	_check(ui.game_state.resources == event_resources, "途中没有提前领补给")
	_check(_find(ui, "resolve_event") == null, "处理后不能重复领取事件效果")
	await _capture("07_event_result")
	_roundtrip_ui(ui, "事件已处理")
	_press(ui, "continue_travel")
	ui._process(10)
	_check(ui.game_state.phase == GameState.Phase.REST_STOP, "后半程抵达独立停歇阶段")
	_check(ui.exploration.visible and not ui.world.visible and not ui.day_loop.conversation_open, "抵达切换侧视探索")
	await process_frame
	await process_frame
	await _capture("08_arrival")
	await _test_camp_controls(ui)
	_press(ui, "stop_dialogues")
	var other := "阿杰" if ui.day_loop.current_transaction().speaker != "阿杰" else "艾琳"
	_walk_to(ui, other)
	_press(ui, "camp_scene_talk")
	_check(ui.inspected_member == other and not ui.day_loop.conversation_open, "查看非优先队员近况")
	await _capture("09_member_inspect")
	_approach(ui)
	await _capture("10_dialogue")
	var position := ui.game_state.camp_position
	Input.action_press("move_right")
	ui.exploration._physics_process(1)
	Input.action_release("move_right")
	_check(is_equal_approx(position, ui.game_state.camp_position), "交谈期间不能移动")
	var cursor := ui.day_loop.transaction_index
	_press(ui, "close_conversation")
	_check(not ui.day_loop.conversation_open and ui.day_loop.transaction_index == cursor, "关闭交谈不消耗事务")
	_approach(ui)
	_roundtrip_ui(ui, "打开停歇对话")
	_press(ui, "respond_defer")
	_check(not ui.day_loop.conversation_open, "回应后回到探索")
	_finish_requests(ui)
	_check(ui.game_state.phase == GameState.Phase.CAMP_ACTION, "停歇对话处理完整")
	await _capture("11_camp")
	_press(ui, "camp_tab_daily")
	_press(ui, "camp_阅读技术手册")
	_check(ui.game_state.phase == GameState.Phase.NIGHT_SETTLEMENT, "营地行动进入夜间")
	await process_frame
	_check(_inside(ui, "next_day"), "夜间推进固定可见")
	await _capture("12_night")
	_press(ui, "next_day")
	_check(ui.game_state.day == 2 and ui.game_state.phase == GameState.Phase.MAJOR_ROUTE_SELECTION, "第1夜后进入第2天大路线")
	await _capture("13_major_routes")
	_roundtrip_ui(ui, "大路线选择")
	for day in range(2, 11):
		_check(ui.game_state.day == day, "按天推进 %d" % day)
		if ui.day_loop.content.is_major_route_day(day):
			_check(ui.game_state.phase == GameState.Phase.MAJOR_ROUTE_SELECTION, "大路线日 %d" % day)
			_press(ui, "major_北部污染区" if day == 2 else ("major_南部断路" if day == 5 else "major_东部聚落"))
		_press(ui, "prepare_info")
		_press(ui, "routes")
		_morning_affairs(ui)
		var direction := ui.game_state.major_route
		if not ui.day_loop.content.is_major_route_day(day):
			_press(ui, "route_资源路线")
			_check(ui.game_state.major_route == direction, "小路线不改剧情 %d" % day)
		else:
			_check(_find(ui, "route_资源路线") == null, "大路线日不重复选小路线")
		_press(ui, "style_低噪音")
		_travel(ui)
		_finish_requests(ui)
		_press(ui, "camp_tab_daily")
		_press(ui, "camp_教学与记录" if day <= 3 else "camp_让成员休息")
		_press(ui, "next_day")
	_check(ui.game_state.phase == GameState.Phase.ENDING and ui.game_state.day == 10 and ui.game_state.ending == "知识的火种", "按钮完整十天教学策略")
	_check(ui.game_state.route_history.map(func(item): return int(item.day)) == [2, 5, 8, 10], "四个剧情节点记录")
	await _capture("15_ending")
	_press(ui, "ending_menu")
	await process_frame
	_check(main.day_demo == null and main.frame.visible, "结局返回主菜单")
	await _press(main, "continue_game")
	ui = main.day_demo
	_check(ui != null and ui.game_state.phase == GameState.Phase.TRAVEL, "主菜单继续读取第1天原存档")
	if ui != null:
		_manual(ui)
		root.content_scale_size = Vector2i(960, 600)
		root.size = Vector2i(960, 600)
		await process_frame
		await process_frame
		_check(ui.canvas.position.x >= -0.1 and ui.canvas.position.y >= -0.1, "窄横屏安全布局")
		await _capture("16_narrow")
		ui._process(10)
		_press(ui, "resolve_event")
		_press(ui, "continue_travel")
		ui._process(10)
		await process_frame
		await process_frame
		_check(ui.exploration.visible, "窄横屏侧视营地可见")
		await _mouse_point(ui.exploration, Vector2(190, ui.exploration.size.y * 0.72))
		ui.exploration._physics_process(2)
		_check(is_equal_approx(ui.game_state.camp_position, 190), "窄横屏点击坐标正确（实际 %.2f）" % ui.game_state.camp_position)
		await _capture("17_narrow_camp")
		root.content_scale_size = Vector2i(1560, 720)
		root.size = Vector2i(1560, 720)
		await process_frame
		await process_frame
		_check(ui.canvas.position.x >= -0.1 and ui.canvas.position.y >= -0.1, "宽横屏安全布局")
		await _capture("18_wide")
		await _mouse_point(ui.exploration, Vector2(250, ui.exploration.size.y * 0.72))
		ui.exploration._physics_process(2)
		_check(is_equal_approx(ui.game_state.camp_position, 250), "宽横屏点击坐标正确")
		_press(ui, "pause")
		_press(ui, "menu")
		await process_frame
	root.content_scale_size = Vector2i(1280, 720)
	root.size = Vector2i(1280, 720)
	await process_frame
	await _test_new_features()
	main.queue_free()
	await process_frame
	print("UI_TEST_%s checks=%d failures=%d" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(failures)

func _manual(ui: DayDemo) -> void:
	# Freeze only the automatic frame callbacks; exercise them explicitly below.
	ui.set_process(false)
	ui.exploration.set_physics_process(false)
	ui.day_loop.random.seed = 20261012

func _morning_affairs(ui: DayDemo) -> void:
	for i in range(5):
		if ui.game_state.phase == GameState.Phase.MEMBER_AFFAIRS:
			_press(ui, "respond_defer")
	_check(ui.game_state.phase == GameState.Phase.ROUTE_SELECTION, "五名成员回应后进入选路")

func _travel(ui: DayDemo) -> void:
	_press(ui, "depart")
	ui._process(10)
	_press(ui, "resolve_event")
	_press(ui, "continue_travel")
	ui._process(10)
	_check(ui.game_state.phase == GameState.Phase.REST_STOP, "事件后抵达")

func _roundtrip_ui(ui: DayDemo, label: String) -> void:
	var original := ui.save_system
	ui.save_system = SaveSystem.new(output_dir + "/phase_save")
	var saved := ui.save_system.snapshot(ui.game_state, ui.day_loop)
	_press(ui, "pause")
	_press(ui, "save")
	ui.game_state.knowledge += 1
	_press(ui, "load")
	_check(not ui.paused and JSON.parse_string(JSON.stringify(ui.save_system.snapshot(ui.game_state, ui.day_loop))) == JSON.parse_string(JSON.stringify(saved)), "文件往返 " + label)
	ui.save_system = original

func _find(node: Node, id: String) -> Button:
	if node is Button and str(node.get_meta("action_id", "")) == id: return node
	for child in node.get_children():
		var found := _find(child, id)
		if found != null: return found
	return null

func _press(node: Node, id: String) -> void:
	var button := _find(node, id)
	_check(button != null and not button.disabled, "按钮可用 " + id)
	if button != null and not button.disabled: button.pressed.emit()
	if node == main: await create_timer(0.45).timeout

func _click(node: Node, id: String) -> void:
	await process_frame
	await process_frame
	var button := _find(node, id)
	_check(button != null and not button.disabled, "指针可点 " + id)
	if button == null or button.disabled: return
	var event := InputEventMouseButton.new()
	event.position = button.get_global_rect().get_center()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event, true)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await process_frame
	if node == main: await create_timer(0.45).timeout

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func _walk_to(ui: DayDemo, speaker: String) -> void:
	var distance := ui.day_loop.content.member_position(speaker) - 50 - ui.game_state.camp_position
	if is_zero_approx(distance):
		ui.exploration._sync()
		return
	var direction := "move_right" if distance > 0 else "move_left"
	Input.action_press(direction)
	ui.exploration._physics_process(absf(distance) / float(ui.day_loop.content.camp_data().walk_speed))
	Input.action_release(direction)

func _approach(ui: DayDemo) -> void:
	if ui.day_loop.current_transaction().speaker == "主角":
		_press(ui, "captain_reflection")
	else:
		_walk_to(ui, str(ui.day_loop.current_transaction().speaker))
		_press(ui, "camp_scene_talk")
	_check(ui.day_loop.conversation_open, "靠近并打开当前对话")

func _mouse_point(control: Control, local: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.position = control.get_global_transform_with_canvas() * local
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event, true)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await process_frame

func _touch(control: Control, local: Vector2, index: int, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.position = control.get_global_transform_with_canvas() * local
	event.index = index
	event.pressed = pressed
	root.push_input(event, true)
	await process_frame

func _test_camp_controls(ui: DayDemo) -> void:
	var scene := ui.exploration
	var resources := ui.game_state.resources.duplicate()
	await _mouse_point(scene, Vector2(190, scene.size.y * 0.72))
	scene._physics_process(2)
	_check(is_equal_approx(ui.game_state.camp_position, 190), "点按地面实际行走到目标")
	await _touch(scene, scene._right_rect().get_center(), 2, true)
	_check(scene.contacts.has(2), "真实触屏方向按下被接收")
	var before := ui.game_state.camp_position
	scene._physics_process(0.4)
	_check(ui.game_state.camp_position > before, "按住触屏方向前进")
	await _touch(scene, scene._left_rect().get_center(), 3, true)
	_check(scene.contacts.size() == 2, "同时支持两根手指")
	before = ui.game_state.camp_position
	scene._physics_process(0.4)
	_check(is_equal_approx(before, ui.game_state.camp_position), "相反方向抵消")
	await _touch(scene, Vector2(-50, -50), 3, false)
	_check(not scene.contacts.has(3) and scene.contacts.has(2), "场景外松手只释放对应手指")
	before = ui.game_state.camp_position
	scene._physics_process(0.2)
	_check(ui.game_state.camp_position > before, "另一根手指继续移动")
	await _touch(scene, Vector2(-50, -50), 2, false)
	before = ui.game_state.camp_position
	scene._physics_process(0.4)
	_check(is_equal_approx(before, ui.game_state.camp_position), "全部松手后停止移动")
	await _touch(scene, scene._right_rect().get_center(), 4, true)
	_press(ui, "pause")
	before = ui.game_state.camp_position
	scene._physics_process(1)
	_check(is_equal_approx(before, ui.game_state.camp_position) and scene.contacts.is_empty(), "暂停停止移动并清空按住状态")
	_press(ui, "resume")
	scene._physics_process(0.5)
	_check(is_equal_approx(before, ui.game_state.camp_position), "继续后没有残留方向")
	await _touch(scene, Vector2(-50, -50), 4, false)
	_check(ui.game_state.resources == resources, "营地移动不额外消耗资源")

func _finish_requests(ui: DayDemo) -> void:
	if ui.game_state.phase == GameState.Phase.REST_STOP: _press(ui, "stop_dialogues")
	# Bound the queue so a regression fails instead of hanging the test.
	for i in range(6):
		if ui.game_state.phase == GameState.Phase.STOP_DIALOGUE:
			if not ui.day_loop.conversation_open: _approach(ui)
			_press(ui, "respond_defer")

func _test_new_features() -> void:
	var patient_state := GameState.new()
	var clinic: DayDemo = load("res://scenes/day_demo.tscn").instantiate()
	root.add_child(clinic)
	clinic.setup(patient_state)
	_manual(clinic)
	clinic.save_system = SaveSystem.new(output_dir + "/medical_save")
	_press(clinic, "routes")
	_morning_affairs(clinic)
	_press(clinic, "depart")
	clinic._process(10)
	clinic.day_loop.resolve_travel_event(0.0)
	clinic.refresh()
	_press(clinic, "continue_travel")
	clinic._process(10)
	_finish_requests(clinic)
	_check(clinic.game_state.phase == GameState.Phase.CAMP_ACTION, "定向治疗进入营地")
	_press(clinic, "team")
	await _capture("19_team_injury")
	_press(clinic, "close_team")
	_press(clinic, "camp_tab_medical")
	await _capture("20_treatment")
	var other_health: int = clinic.game_state.member_named("艾琳").health
	_press(clinic, "treat_老张")
	_check(clinic.game_state.member_named("老张").health == 100 and clinic.game_state.member_named("艾琳").health == other_health, "定向治疗只作用于老张")
	_check(clinic.game_state.phase == GameState.Phase.NIGHT_SETTLEMENT and clinic.game_state.resources.medicine == 4, "治疗消耗药品与一次行动")
	_press(clinic, "pause")
	_press(clinic, "save")
	clinic.game_state.member_named("老张").health = 1
	_press(clinic, "load")
	_check(clinic.game_state.member_named("老张").health == 100, "文件恢复个人健康")
	clinic.queue_free()
	await process_frame
	patient_state.free()
	await _press(main, "new_game")
	var ui: DayDemo = main.day_demo
	_manual(ui)
	var options := ["修复旧油泵", "只取入口物资", "启动柴油抽水机", "围火照看大家", "用备件交换口粮"]
	for day in range(1, 11):
		if ui.game_state.phase == GameState.Phase.MAJOR_ROUTE_SELECTION:
			_press(ui, "major_东部聚落")
		_press(ui, "prepare_repair")
		_press(ui, "routes")
		_morning_affairs(ui)
		if not ui.day_loop.content.is_major_route_day(day): _press(ui, "route_资源路线")
		_press(ui, "style_低噪音")
		_travel(ui)
		_finish_requests(ui)
		_check(ui.game_state.phase == GameState.Phase.CAMP_ACTION and ui.camp_view == "site", "默认显示当地发现 %d" % day)
		await _capture("site_%02d" % day)
		var old_fuel: int = ui.game_state.resources.fuel
		var old_water: int = ui.game_state.resources.water
		if day <= 5:
			_press(ui, "site_" + options[day - 1])
		elif day < 10:
			_press(ui, "camp_tab_daily")
			_press(ui, "camp_让成员休息")
		else:
			_press(ui, "settle_night")
		_check(ui.game_state.phase == GameState.Phase.NIGHT_SETTLEMENT, "地点或休息进入夜间 %d" % day)
		if day == 3:
			_check(ui.game_state.resources.fuel == old_fuel - 2 and ui.game_state.resources.water == old_water + 7 and ui.game_state.tracking == 12, "抽水真实成本收益和追踪")
		_press(ui, "next_day")
	_check(ui.game_state.phase == GameState.Phase.ENDING and ui.game_state.day == 10 and ui.game_state.ending == "仍在路上", "地点补给策略走完十天")
	_press(ui, "ending_menu")
	await process_frame

func _inside(ui: DayDemo, id: String) -> bool:
	var button := _find(ui, id)
	if button == null: return false
	# Container layout updates on the next frame, so use the owning dock as well.
	return ui.primary_actions.get_parent() != null and ui.canvas.get_global_rect().encloses(button.get_global_rect())

func _capture(name_key: String) -> void:
	if not capture: return
	for frame in range(3): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output_dir + "/" + name_key + ".png")
