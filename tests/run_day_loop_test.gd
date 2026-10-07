extends SceneTree

var _failures: int = 0

func _init() -> void:
	var state: GameState = GameState.new()
	var loop: DayLoop = DayLoop.new(state, DemoContent.new())
	loop.start_new_game()
	_check(state.day == 1, "新游戏从第 1 天开始")
	_check(state.phase == GameState.Phase.MORNING, "新游戏从早晨阶段开始")
	_check(state.resources["fuel"] == 30, "新游戏燃料为 30")
	_check(loop.content.members().size() == 5, "Demo 数据包含 5 名初始成员")
	_check(loop.content.vehicle().get("name") == "掠夺者", "Demo 数据包含初始车辆")
	_check(loop.content.route_fuel_cost("未知路线") == 5, "Demo 数据包含未知路线燃料消耗")
	_check(loop.daily_transactions.size() == 2, "新游戏生成 2 条 NPC 当日事务")
	_check(loop.daily_transactions[0].get("urgency") == "高", "第一条事务保留紧急度")
	_check(loop.transaction_summary().contains("维修"), "事务摘要包含说话人")

	loop.choose_route("未知路线")
	loop.start_travel()
	_check(state.phase == GameState.Phase.TRAVEL, "确认路线后进入移动阶段")
	_check(state.resources["fuel"] == 25, "未知路线消耗 5 燃料")

	loop.resolve_travel_event()
	_check(state.phase == GameState.Phase.REST_STOP, "移动突发后抵达停歇点")
	loop.resolve_dialogue("接受请求", 2, 1)
	_check(state.phase == GameState.Phase.CAMP_ACTION, "对话后进入营地行动")
	_check(state.resources["parts"] == 8, "对话正确消耗零件")

	loop.perform_camp_action("维修车辆", 2)
	_check(state.phase == GameState.Phase.NIGHT_SETTLEMENT, "营地行动后进入夜间结算")
	_check(state.resources["water"] == 15, "营地行动消耗饮水")
	_check(state.resources["food"] == 16, "营地行动消耗食物")
	_check(state.resources["parts"] == 6, "营地行动正确消耗零件")

	state.resources["water"] = 0
	state.resources["food"] = 0
	state.resources["parts"] = 0
	loop.perform_camp_action("让成员休息", 2)
	_check(state.resources["water"] == 0, "资源不会扣成负数：饮水")
	_check(state.resources["food"] == 0, "资源不会扣成负数：食物")
	_check(state.resources["parts"] == 0, "资源不会扣成负数：零件")
	_check(loop.event_log.size() == 5, "事件日志记录路线、突发、对话和两次行动")

	if _failures == 0:
		print("DAY_LOOP_TEST_PASS")
	else:
		printerr("DAY_LOOP_TEST_FAIL count=%d" % _failures)
	loop = null
	state.free()
	quit(_failures)

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	printerr("FAIL: %s" % message)
