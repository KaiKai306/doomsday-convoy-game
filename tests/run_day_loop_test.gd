extends SceneTree

var failures := 0
var checks := 0
var states: Array[GameState] = []
var content := DemoContent.new()
var saves := SaveSystem.new()

func _init() -> void:
	var loop := _new_run()
	_check(loop.state.phase == GameState.Phase.MORNING and loop.daily_transactions.size() == 2, "初始事务")
	var before := saves.snapshot(loop.state, loop)
	_check(not loop.start_travel(), "禁止跨阶段出发")
	_check(not loop.perform_camp_action("维修车辆"), "禁止跨阶段行动")
	_check(saves.snapshot(loop.state, loop) == before, "非法命令不修改状态")
	_check(loop.prepare("检查车辆"), "一次早晨准备")
	_check(loop.state.vehicle_health == 86 and loop.state.resources.parts == 9, "准备真实生效")
	_check(not loop.prepare("公开情报"), "准备不能重复")
	loop.finish_preparation()
	loop.choose_route("未知路线")
	_check(loop.start_travel(), "合法出发")
	_check(loop.state.resources.fuel == 25, "燃料消耗")
	_check(not loop.start_travel(), "出发不可重复收费")
	_check(loop.resolve_travel_event(0.0), "确定性事故")
	_check(loop.state.vehicle_health == 70, "事故实际损伤")
	_check(not loop.begin_conversation("维修") and not loop.respond("accept"), "不能远程打开或回应事务")
	_check(not loop.begin_conversation("老赵"), "必须先靠近当前说话人")
	var after := saves.snapshot(loop.state, loop)
	loop.resolve_travel_event(0.0)
	_check(saves.snapshot(loop.state, loop) == after, "不可重复领取补给")
	_check(_respond(loop, "accept"), "维修事务")
	_check(loop.state.vehicle_health == 80 and loop.state.resources.parts == 7, "维修请求生效")
	_check(loop.state.phase == GameState.Phase.REST_STOP and loop.transaction_index == 1, "第二条事务仍需回应")
	_check(loop.current_transaction().speaker == "阿遥", "独立侦察事务")
	_respond(loop, "accept")
	_check(loop.state.knowledge == 3 and loop.state.phase == GameState.Phase.CAMP_ACTION, "档案、侦察成果与队列结束")
	_check(not loop.perform_camp_action("教学与记录"), "路线知识不能替代手册阅读前置")
	loop.perform_camp_action("阅读技术手册")
	_check(loop.state.knowledge == 4 and loop.state.world_facts.get("manual_read", false), "阅读增加知识并解锁技术教学")
	_check(loop.state.resources.water == 19 and loop.state.resources.food == 17, "补给和夜间消耗正确")
	after = saves.snapshot(loop.state, loop)
	_check(not loop.perform_camp_action("阅读技术手册"), "营地行动不能重复")
	_check(saves.snapshot(loop.state, loop) == after, "夜间不重复收费")
	loop.advance_to_next_day()
	_check(loop.state.day == 2 and loop.event_log.is_empty(), "进入次日并清理当日日志")
	_check(loop.daily_transactions[0].id == "repair_priority" and loop.daily_transactions[0].goal.contains("检修"), "昨日接受生成后续检修事务")
	_check(loop.daily_transactions[1].goal.contains("记下来"), "情报结果改变次日侦察请求")
	loop.finish_preparation()
	loop.choose_route("安全路线")
	_check(is_equal_approx(loop.route_accident_chance(), 0.05), "维修风险修正生效")
	loop.choose_style("绕行")
	_check(loop.route_fuel_cost() == 6 and is_zero_approx(loop.route_accident_chance()), "绕行代价和事故概率")
	loop.start_travel()
	loop.tick_travel(3)
	var snapshot := saves.snapshot(loop.state, loop)
	var resumed := _new_run()
	_check(saves.restore(JSON.parse_string(JSON.stringify(snapshot)), resumed.state, resumed), "JSON 往返恢复")
	_check(is_equal_approx(resumed.travel_progress, loop.travel_progress), "行进进度恢复")
	_check(resumed.state.vehicle_health == loop.state.vehicle_health and resumed.state.knowledge == 4, "新状态恢复")
	_check(resumed.random.randf() == loop.random.randf(), "随机状态恢复")
	var unchanged := saves.snapshot(resumed.state, resumed)
	var corrupt := snapshot.duplicate(true)
	corrupt.resources = []
	_check(not saves.restore(corrupt, resumed.state, resumed), "损坏资源拒绝")
	corrupt = snapshot.duplicate(true)
	corrupt.resources.erase("water")
	_check(not saves.restore(corrupt, resumed.state, resumed), "缺资源拒绝")
	corrupt = snapshot.duplicate(true)
	corrupt.version = 1
	_check(not saves.restore(corrupt, resumed.state, resumed), "旧版存档明确拒绝")
	_check(saves.snapshot(resumed.state, resumed) == unchanged, "拒绝坏存档不破坏当前游戏")
	# One full run deliberately survives and teaches; one exhausts its water.
	var survivor := _new_run()
	for day in range(1, 6):
		survivor.finish_preparation()
		survivor.choose_route("资源路线")
		survivor.start_travel()
		survivor.resolve_travel_event(0.99)
		while survivor.state.phase == GameState.Phase.REST_STOP: _respond(survivor, "defer")
		survivor.perform_camp_action("阅读技术手册" if day == 1 else ("教学与记录" if day <= 3 else "让成员休息"))
		survivor.advance_to_next_day()
	_check(survivor.state.phase == GameState.Phase.ENDING and survivor.state.ending == "知识的火种", "完整五日知识结局")
	_check(survivor.state.world_facts.get("shared_maintenance", false), "重复教学形成维护习惯")
	_check(survivor.state.resources.water == 30 and survivor.state.resources.food == 25, "五日配给和补给总额")
	var stranded := _new_run()
	_reach_camp(stranded)
	stranded.state.resources.water = 0
	stranded.perform_camp_action("让成员休息")
	_check(stranded.state.ending == "饮水耗尽", "无水触发结束")
	stranded.advance_to_next_day()
	_check(stranded.state.phase == GameState.Phase.ENDING and stranded.state.day == 1, "失败后不能继续次日")
	var poor := _new_run()
	poor.state.resources.parts = 0
	before = saves.snapshot(poor.state, poor)
	_check(not poor.prepare("检查车辆") and saves.snapshot(poor.state, poor) == before, "缺零件不免费维修")
	poor.finish_preparation()
	poor.state.resources.fuel = 0
	_check(not poor.start_travel() and poor.state.phase == GameState.Phase.ROUTE_SELECTION, "缺燃料不可出发")
	# Exhausted fuel must offer a terminal result, not a permanently disabled screen.
	poor.abandon_journey()
	_check(poor.state.phase == GameState.Phase.ENDING and poor.state.ending == "燃料耗尽", "无法出发有可达结局")
	for ending_case in ["vehicle", "trust", "fatigue"]:
		var losing := _new_run()
		_reach_camp(losing)
		match ending_case:
			"vehicle": losing.state.vehicle_health = 0
			"trust": losing.state.team_trust = 0
			"fatigue": losing.state.fatigue = 100
		losing.perform_camp_action("阅读技术手册")
		_check(not losing.state.ending.is_empty(), "失败检测 " + ending_case)
	var hungry := _new_run()
	_reach_camp(hungry)
	hungry.state.resources.food = 0
	hungry.perform_camp_action("阅读技术手册")
	_check(hungry.state.ending == "粮食耗尽", "粮食失败检测")
	var denied := _new_run()
	denied.finish_preparation()
	denied.start_travel()
	denied.resolve_travel_event(0.99)
	denied.state.resources.parts = 0
	_approach(denied)
	denied.begin_conversation("老赵")
	before = saves.snapshot(denied.state, denied)
	_check(not _respond(denied, "accept") and saves.snapshot(denied.state, denied) == before, "缺零件不能接受维修并获得收益")
	_respond(denied, "refuse")
	_check(denied.state.world_facts.road_accident_modifier == 1, "拒绝增加道路风险")
	var hunted := _new_run()
	hunted.finish_preparation()
	hunted.choose_style("快速")
	hunted.state.tracking = 24
	hunted.start_travel()
	hunted.resolve_travel_event(0.99)
	_check(hunted.state.vehicle_health == 68 and hunted.state.tracking == 22, "高噪音追踪触发怪物损伤")
	var ordinary := _new_run()
	for day in range(1, 6):
		_reach_camp(ordinary)
		ordinary.perform_camp_action("让成员休息")
		ordinary.advance_to_next_day()
	_check(ordinary.state.ending == "仍在路上", "安全路线也可达普通五日结局")
	var camp_loop := _new_run()
	camp_loop.finish_preparation()
	camp_loop.start_travel()
	camp_loop.resolve_travel_event(0.99)
	_check(camp_loop.move_in_camp(-1, 100) and camp_loop.state.camp_position == 45, "左边界限位")
	_check(camp_loop.move_in_camp(1, 100) and camp_loop.state.camp_position == 1395, "右边界限位")
	_check(not camp_loop.begin_conversation("周禾"), "非当前成员不能抢答队列")
	_approach(camp_loop)
	_check(camp_loop.begin_conversation("老赵"), "靠近当前成员后交谈")
	before = saves.snapshot(camp_loop.state, camp_loop)
	_check(not camp_loop.move_in_camp(1, 1), "对话时阻止移动")
	_check(saves.snapshot(camp_loop.state, camp_loop) == before, "对话阻止移动且状态不变")
	var camp_restore := _new_run()
	_check(saves.restore(JSON.parse_string(JSON.stringify(before)), camp_restore.state, camp_restore), "营地对话存档往返")
	_check(camp_restore.conversation_open and is_equal_approx(camp_restore.state.camp_position, 340), "位置及打开对话恢复")
	camp_restore.close_conversation()
	_check(camp_restore.move_in_camp(1, 0.1), "关闭对话后恢复移动")
	var legacy := before.duplicate(true)
	legacy.erase("camp_position")
	legacy.erase("conversation_open")
	_check(saves.restore(legacy, camp_restore.state, camp_restore) and camp_restore.state.camp_position == 100 and not camp_restore.conversation_open, "兼容早期版本 2 存档")
	corrupt = before.duplicate(true)
	corrupt.camp_position = -10
	_check(not saves.restore(corrupt, camp_restore.state, camp_restore), "拒绝越界营地位置")
	corrupt = before.duplicate(true)
	corrupt.camp_position = 100
	_check(not saves.restore(corrupt, camp_restore.state, camp_restore), "拒绝远离成员却打开对话的存档")
	if failures == 0: print("DAY_LOOP_TEST_PASS checks=%d" % checks)
	else: printerr("DAY_LOOP_TEST_FAIL failures=%d checks=%d" % [failures, checks])
	for state in states: state.free()
	quit(failures)

func _new_run() -> DayLoop:
	var state := GameState.new()
	states.append(state)
	var loop := DayLoop.new(state, content)
	loop.start_new_game()
	return loop

func _reach_camp(loop: DayLoop) -> void:
	loop.finish_preparation()
	loop.start_travel()
	loop.resolve_travel_event(0.99)
	while loop.state.phase == GameState.Phase.REST_STOP: _respond(loop, "defer")

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + description)

func _approach(loop: DayLoop) -> void:
	var target := loop.content.member_position(str(loop.current_transaction().speaker))
	var distance := target - loop.state.camp_position
	if not is_zero_approx(distance):
		loop.move_in_camp(signf(distance), absf(distance) / float(loop.content.camp_data().walk_speed))

func _respond(loop: DayLoop, choice: String) -> bool:
	if not loop.conversation_open:
		_approach(loop)
		loop.begin_conversation(str(loop.current_transaction().speaker))
	return loop.respond(choice)
