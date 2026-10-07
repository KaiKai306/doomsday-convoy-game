extends SceneTree

var _failures: int = 0

func _init() -> void:
	var state: GameState = GameState.new()
	var loop: DayLoop = DayLoop.new(state, DemoContent.new())
	loop.start_new_game()
	_check(state.day == 1, "新游戏从第 1 天开始")
	_check(state.phase == GameState.Phase.MORNING, "新游戏从早晨阶段开始")
	_check(state.resources["fuel"] == 30, "新游戏燃料为 30")
	_check(state.team_trust == 50, "新游戏信任为 50")
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
	_check(state.team_trust == 51, "接受对话请求提高信任")
	_check(state.world_facts["repair_priority"] == "accepted", "接受请求写入世界事实")
	_check(state.world_facts["road_accident_modifier"] == -1, "接受请求降低下一日道路事故风险")
	_check(loop.next_day_effects_text().contains("下降"), "夜间结算生成下一日因果")

	loop.advance_to_next_day()
	_check(state.day == 2, "夜间结算后进入第 2 天")
	_check(state.phase == GameState.Phase.MORNING, "第 2 天从早晨阶段开始")
	_check(loop.daily_transactions.size() == 1, "第 2 天生成一条后续事务")
	_check(loop.daily_transactions[0].get("id") == "repair_follow_up_success", "接受请求生成对应后续事务")
	loop.choose_route("安全路线")
	loop.start_travel()
	loop.resolve_travel_event()
	_check(loop.event_log.back().contains("未发生道路事故"), "接受请求降低下一日道路事故结果")

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
	_check(loop.event_log.size() == 7, "事件日志记录两天路线、突发、对话和两次行动")

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
