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
	if not args.is_empty(): output_dir = args[0]
	capture = "--capture" in args
	main = load("res://scenes/main.tscn").instantiate()
	if not output_dir.is_empty(): main.save_system = SaveSystem.new(output_dir + "/save")
	root.add_child(main)
	await process_frame
	await _capture("01_menu")
	await _click(main, "new_game")
	await process_frame
	if main.day_demo == null:
		_check(false, "主菜单点击必须打开新游戏")
		main.queue_free()
		await process_frame
		quit(1)
		return
	var ui: DayDemo = main.day_demo
	ui.day_loop.random.seed = 20261011
	if not output_dir.is_empty(): ui.save_system = SaveSystem.new(output_dir + "/save")
	_check(ui.game_state.phase == GameState.Phase.MORNING, "新游戏按钮")
	_check(_inside(ui, "routes"), "早晨推进按钮始终在画布内")
	await _capture("02_morning")
	_press(ui, "team")
	_check(ui.team_open and ui.team_cards.get_child_count() == 5, "成员总览显示五个独立状态")
	await _capture("14_team")
	_press(ui, "close_team")
	_press(ui, "prepare_info")
	_check(ui.game_state.team_trust == 52, "准备按钮真实生效")
	_press(ui, "routes")
	_press(ui, "route_资源路线")
	_press(ui, "style_绕行")
	await process_frame
	_check(ui.day_loop.route_choice == "资源路线" and ui.day_loop.travel_style == "绕行", "动态按钮闭包选择正确")
	_check(_inside(ui, "depart") and _inside(ui, "style_绕行"), "出发与预设始终可见")
	await _capture("03_routes")
	_press(ui, "depart")
	_check(ui.game_state.phase == GameState.Phase.TRAVEL, "出发按钮")
	_press(ui, "team")
	var before_team := ui.day_loop.travel_progress
	ui._process(10)
	_check(ui.day_loop.travel_progress == before_team, "查看成员总览暂停自动行进")
	_press(ui, "close_team")
	ui.day_loop.travel_progress = 0.3
	_press(ui, "pause")
	ui._process(10)
	_check(is_equal_approx(ui.day_loop.travel_progress, 0.3), "暂停停止自动行进")
	_press(ui, "save")
	_check(not ui.save_system.load_from_file().is_empty(), "暂停真实保存")
	_press(ui, "save")
	_check(not ui.save_system.load_from_file().is_empty(), "覆盖保存成功")
	ui.day_loop.travel_progress = 0.8
	_press(ui, "load")
	_check(not ui.paused and is_equal_approx(ui.day_loop.travel_progress, 0.3), "读档恢复行进并继续")
	await _capture("04_travel")
	ui._process(10)
	await process_frame
	_check(ui.game_state.phase == GameState.Phase.REST_STOP, "自动抵达")
	_check(ui.exploration.visible and not ui.world.visible and not ui.day_loop.conversation_open, "抵达后切换侧视探索")
	await _capture("11_camp_explore")
	await _test_camp_controls(ui)
	_walk_to(ui, "许宁")
	_press(ui, "camp_scene_talk")
	_check(ui.inspected_member == "许宁" and not ui.day_loop.conversation_open, "查看非当前队员近况而不跳过事务")
	await _capture("12_member_inspect")
	_approach(ui)
	await _capture("05_dialogue")
	var position := ui.game_state.camp_position
	Input.action_press("move_right")
	ui.exploration._physics_process(1)
	Input.action_release("move_right")
	_check(is_equal_approx(position, ui.game_state.camp_position), "对话期间输入不能移动")
	_press(ui, "close_conversation")
	_check(not ui.day_loop.conversation_open and ui.day_loop.transaction_index == 0, "结束交谈不算延期也不消耗事务")
	_press(ui, "camp_scene_talk")
	_check(ui.day_loop.conversation_open, "在原地重新交谈")
	_press(ui, "respond_accept")
	_check(ui.day_loop.transaction_index == 1 and ui.game_state.phase == GameState.Phase.REST_STOP, "逐条对话")
	_check(not ui.day_loop.conversation_open, "回应后回到营地")
	_approach(ui)
	_press(ui, "respond_accept")
	_check(ui.game_state.phase == GameState.Phase.CAMP_ACTION, "队列结束进入营地")
	await _capture("06_camp")
	_press(ui, "camp_tab_daily")
	_press(ui, "camp_阅读技术手册")
	await process_frame
	_check(ui.game_state.phase == GameState.Phase.NIGHT_SETTLEMENT, "营地按钮到夜间")
	_check(_inside(ui, "next_day"), "结算按钮始终可见")
	await _capture("07_night")
	_press(ui, "next_day")
	_check(ui.game_state.day == 2, "次日按钮")
	# Continue through the remaining four days using the real command buttons.
	for day in range(2, 6):
		_press(ui, "routes")
		_press(ui, "route_资源路线")
		_press(ui, "style_低噪音")
		_press(ui, "depart")
		ui._process(10)
		for transaction in range(3):
			if ui.game_state.phase == GameState.Phase.REST_STOP:
				_approach(ui)
				_press(ui, "respond_defer")
		_press(ui, "camp_tab_daily")
		_press(ui, "camp_教学与记录" if day <= 3 else "camp_让成员休息")
		_press(ui, "next_day")
	_check(ui.game_state.phase == GameState.Phase.ENDING and ui.game_state.ending == "知识的火种", "按钮完整五日闭环")
	await _capture("08_ending")
	_press(ui, "ending_menu")
	await process_frame
	_check(main.day_demo == null and main.frame.visible, "结局返回菜单")
	_press(main, "continue_game")
	await process_frame
	ui = main.day_demo
	_check(ui != null and ui.game_state.phase == GameState.Phase.TRAVEL, "主菜单继续读取存档")
	if ui != null:
		# Narrow landscape and wide landscape should keep the design canvas centered.
		root.content_scale_size = Vector2i(960, 600)
		root.size = Vector2i(960, 600)
		await process_frame
		await process_frame
		_check(ui.canvas.position.x >= -0.1 and ui.canvas.position.y >= -0.1, "窄横屏安全布局")
		await _capture("09_narrow")
		ui._process(10)
		await process_frame
		_check(ui.exploration.visible, "窄横屏侧视营地可见")
		await _mouse_point(ui.exploration, Vector2(190, ui.exploration.size.y * 0.72))
		ui.exploration._physics_process(2)
		_check(is_equal_approx(ui.game_state.camp_position, 190), "窄横屏指针坐标正确")
		await _capture("13_narrow_camp")
		root.content_scale_size = Vector2i(1560, 720)
		root.size = Vector2i(1560, 720)
		await process_frame
		await process_frame
		_check(ui.canvas.position.x >= -0.1 and ui.canvas.position.y >= -0.1, "宽横屏安全布局")
		await _capture("10_wide")
		await _mouse_point(ui.exploration, Vector2(250, ui.exploration.size.y * 0.72))
		ui.exploration._physics_process(2)
		_check(is_equal_approx(ui.game_state.camp_position, 250), "宽横屏指针坐标正确")
	if ui != null:
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
	for i in range(3):
		if ui.game_state.phase == GameState.Phase.REST_STOP:
			_approach(ui)
			_press(ui, "respond_defer")

func _test_new_features() -> void:
	var patient_state := GameState.new()
	var clinic: DayDemo = load("res://scenes/day_demo.tscn").instantiate()
	root.add_child(clinic)
	clinic.setup(patient_state)
	clinic.save_system = SaveSystem.new(output_dir + "/medical_save")
	_press(clinic, "routes")
	_press(clinic, "depart")
	clinic.day_loop.resolve_travel_event(0.0)
	clinic.refresh()
	_finish_requests(clinic)
	_check(clinic.game_state.phase == GameState.Phase.CAMP_ACTION, "定向治疗测试进入营地")
	_press(clinic, "team")
	await _capture("17_team_injury")
	_press(clinic, "close_team")
	_press(clinic, "camp_tab_medical")
	await _capture("15_treatment")
	var other_health: int = clinic.game_state.member_named("许宁").health
	_press(clinic, "treat_老赵")
	_check(clinic.game_state.member_named("老赵").health == 100 and clinic.game_state.member_named("许宁").health == other_health, "治疗按钮只作用于所选老赵")
	_check(clinic.game_state.phase == GameState.Phase.NIGHT_SETTLEMENT and clinic.game_state.resources.medicine == 4, "定向治疗消耗药品与一次行动")
	_press(clinic, "pause")
	_press(clinic, "save")
	clinic.game_state.member_named("老赵").health = 1
	_press(clinic, "load")
	_check(clinic.game_state.member_named("老赵").health == 100, "文件读档恢复个人健康")
	_press(clinic, "team")
	await _capture("16_team_after_treatment")
	_press(clinic, "close_team")
	clinic.queue_free()
	await process_frame
	patient_state.free()
	_press(main, "new_game")
	await process_frame
	var ui: DayDemo = main.day_demo
	var options := ["修复旧油泵", "只取入口物资", "启动柴油抽水机", "围火照看大家", "用备件交换口粮"]
	ui.day_loop.random.seed = 20261011
	for day in range(1, 6):
		_press(ui, "routes")
		_press(ui, "route_安全路线")
		_press(ui, "style_低噪音")
		_press(ui, "depart")
		ui.day_loop.resolve_travel_event(0.99)
		ui.refresh()
		_finish_requests(ui)
		_check(ui.game_state.phase == GameState.Phase.CAMP_ACTION and ui.camp_view == "site", "每日默认显示当地发现 %d" % day)
		await _capture("site_%02d" % day)
		var old_fuel: int = ui.game_state.resources.fuel
		var old_water: int = ui.game_state.resources.water
		_press(ui, "site_" + options[day - 1])
		_check(ui.game_state.phase == GameState.Phase.NIGHT_SETTLEMENT, "地点按钮完成一次行动 %d" % day)
		if day == 3:
			_check(ui.game_state.resources.fuel == old_fuel - 2 and ui.game_state.resources.water == old_water + 7 and ui.game_state.tracking == 12, "抽水按钮真实成本收益和追踪")
		_press(ui, "next_day")
	_check(ui.game_state.phase == GameState.Phase.ENDING and ui.game_state.ending == "仍在路上", "五日地点事件策略可完成旅程")
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
