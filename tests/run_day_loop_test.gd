extends SceneTree

var failures := 0
var checks := 0
var states: Array[GameState] = []
var content := DemoContent.new()
var saves := SaveSystem.new()

func _init() -> void:
	var loop := _new_run()
	_check(content.demo_days() == 10, "十天框架")
	_check(loop.daily_transactions.size() == 5, "五名成员每天各有一项事务")
	var speakers: Array = []
	for t in loop.daily_transactions: speakers.append(t.speaker)
	_check(speakers.size() == 5 and speakers.has("主角") and speakers.has("老张") and speakers.has("艾琳") and speakers.has("阿杰") and speakers.has("索菲亚"), "成员与剧情设定一致")
	var before := saves.snapshot(loop.state, loop)
	_check(not loop.start_travel() and not loop.respond("accept") and not loop.select_major_route("北部污染区"), "不能跨阶段操作")
	_check(saves.snapshot(loop.state, loop) == before, "非法操作不改变状态")
	_check(loop.prepare("检查车辆") and loop.state.vehicle_health == 86, "早晨准备真实生效")
	_check(not loop.prepare("公开情报"), "主要准备不能重复")
	_check(loop.finish_preparation() and loop.state.phase == GameState.Phase.MEMBER_AFFAIRS, "准备后进入事务")
	_check(not loop.start_travel() and not loop.choose_route("资源路线"), "五人事务未完禁止出发或选路")
	_check(_respond(loop, "accept") and loop.state.vehicle_health == 96 and loop.state.resources.parts == 7, "早晨维修立即生效")
	_roundtrip(loop, "晨间事务中途")
	while loop.state.phase == GameState.Phase.MEMBER_AFFAIRS: _respond(loop, "defer")
	_check(loop.morning_resolutions.size() == 5 and loop.state.phase == GameState.Phase.ROUTE_SELECTION, "所有回应已记录才开放小路线")
	_check(loop.choose_route("资源路线"), "第一天选择小路线")
	var story := loop.state.route_history.duplicate(true)
	_check(loop.start_travel(), "出发收费")
	_check(not loop.start_travel(), "出发不能重复收费")
	_check(not loop.resolve_travel_event(0), "事件不能提前执行")
	loop.tick_travel(10)
	_check(loop.state.phase == GameState.Phase.TRAVEL_EVENT and loop.travel_progress == 0.5, "途中停在独立事件阶段")
	var supplies_before := loop.state.resources.duplicate()
	_roundtrip(loop, "事件未处理")
	_check(loop.resolve_travel_event(0), "事件结算")
	_check(loop.state.resources == supplies_before, "途中事件不提前领取到达补给")
	before = saves.snapshot(loop.state, loop)
	_check(not loop.resolve_travel_event(0) and saves.snapshot(loop.state, loop) == before, "每天事件只结算一次")
	_roundtrip(loop, "事件已处理")
	_check(loop.continue_after_event(), "事件后继续行驶")
	_roundtrip(loop, "后半段行驶")
	loop.tick_travel(10)
	_check(loop.state.phase == GameState.Phase.REST_STOP and loop.travel_progress == 1, "独立抵达阶段")
	_check(loop.state.resources.water == int(supplies_before.water) + 7, "抵达才领取小路线补给")
	_check(loop.state.route_history == story and loop.state.major_route.is_empty(), "小路线不改变剧情")
	before = saves.snapshot(loop.state, loop)
	loop.tick_travel(10)
	_check(saves.snapshot(loop.state, loop) == before, "抵达补给不能重复领取")
	_check(not loop.respond("accept"), "抵达不自动进入对话")
	_check(loop.begin_stop_dialogues(), "抵达后手动进入 NPC 对话")
	_check(not loop.begin_conversation("索菲亚"), "不能绕过紧急事务")
	_check(not loop.begin_conversation("艾琳"), "远离队员不能交谈")
	_approach(loop)
	_check(loop.begin_conversation(str(loop.current_transaction().speaker)), "靠近当前队员打开对话")
	_roundtrip(loop, "营地打开对话")
	_check(not loop.move_in_camp(1, 1), "对话时不能移动")
	loop.close_conversation()
	_check(loop.transaction_index == 0 and loop.move_in_camp(1, 0.1), "结束交谈不消耗事务")
	while loop.state.phase == GameState.Phase.STOP_DIALOGUE: _respond(loop, "defer")
	_check(loop.state.phase == GameState.Phase.CAMP_ACTION, "停歇事务处理完可结算")
	var paid_parts: int = loop.state.resources.parts
	_check(paid_parts == 8, "晨间已维修不会在晚上自动再次收费，包含路线零件收益")
	_check(loop.finish_stop_dialogues(), "可以直接夜间结算，不强制额外行动")
	_check(loop.state.phase == GameState.Phase.NIGHT_SETTLEMENT, "夜间阶段")
	before = saves.snapshot(loop.state, loop)
	_check(not loop.finish_stop_dialogues() and saves.snapshot(loop.state, loop) == before, "夜间配给不重复")
	_check(loop.advance_to_next_day() and loop.state.day == 2 and loop.state.phase == GameState.Phase.MAJOR_ROUTE_SELECTION, "第一夜之后第2天大路线")
	_roundtrip(loop, "大路线未选")
	_check(not loop.finish_preparation(), "大路线未选不能开始早晨")
	_check(loop.select_major_route("北部污染区"), "大路线选择")
	_check(loop.state.route_history.size() == 1 and loop.state.world_facts.story_direction == "北部污染区", "记录剧情方向与章节")
	_check(not loop.select_major_route("南部断路"), "同一阶段不能重复改写大路线")
	_check(loop.route_supplies().get("medicine") == 1, "北部大路线药品收益")
	_to_routes(loop)
	_check(not loop.choose_route("资源路线"), "大路线日不再重复选择小路线")
	_check(loop.route_fuel_cost() == 4, "大路线的独立消耗")
	_roundtrip(loop, "大路线出发确认")
	var corrupt := saves.snapshot(loop.state, loop)
	corrupt.phase = GameState.Phase.MAJOR_ROUTE_SELECTION
	corrupt.day = 3
	before = saves.snapshot(loop.state, loop)
	_check(not saves.restore(corrupt, loop.state, loop) and saves.snapshot(loop.state, loop) == before, "拒绝错误日期的大路线存档")
	corrupt = before.duplicate(true)
	corrupt.morning_resolutions = "bad"
	_check(not saves.restore(corrupt, loop.state, loop), "拒绝损坏晨间记录")
	corrupt = before.duplicate(true)
	corrupt.members[0].health = -1
	_check(not saves.restore(corrupt, loop.state, loop), "拒绝损坏个人状态")
	corrupt = before.duplicate(true)
	corrupt.version = 1
	_check(not saves.restore(corrupt, loop.state, loop), "拒绝不支持的版本1")
	var legacy := before.duplicate(true)
	legacy.version = 2
	for key in ["morning_resolutions", "major_route", "route_history", "travel_event_text"]: legacy.erase(key)
	var renamed := {"主角": "队长", "老张": "老赵", "艾琳": "许宁", "阿杰": "阿遥", "索菲亚": "周禾"}
	for member in legacy.members: member.name = renamed[member.name]
	for t in legacy.daily_transactions: t.speaker = renamed[t.speaker]
	var migrated := _new_run()
	_check(saves.restore(legacy, migrated.state, migrated) and migrated.state.member_named("老张").health == loop.state.member_named("老张").health, "版本2姓名及字段迁移")
	legacy.phase = GameState.Phase.TRAVEL
	legacy.travel_progress = 0.3
	legacy.travel_resolved = true
	_check(saves.restore(legacy, migrated.state, migrated) and migrated.travel_progress == 0.5 and migrated.travel_resolved, "旧版出发即结算事件不会重播或拒绝恢复")
	legacy.phase = GameState.Phase.MORNING
	legacy.daily_transactions.resize(3)
	legacy.transaction_index = 0
	var migrated_morning := saves.restore(legacy, migrated.state, migrated)
	_check(migrated_morning and migrated.daily_transactions.size() == 5, "旧版早晨补全五人事务")
	corrupt = before.duplicate(true)
	corrupt.day = {}
	_check(not saves.restore(corrupt, loop.state, loop), "拒绝非数字日期且不崩溃")
	_test_ten_days()
	_test_failures()
	for state in states: state.free()
	print("DAY_LOOP_TEST_%s checks=%d failures=%d" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(failures)

func _test_ten_days() -> void:
	for direction in content.major_routes():
		var loop := _new_run()
		for day in range(1, 11):
			_check(loop.state.day == day, "天数正确 %s/%d" % [direction, day])
			if content.is_major_route_day(day):
				_check(loop.state.phase == GameState.Phase.MAJOR_ROUTE_SELECTION, "仅第2/5/8/10天大路线")
				loop.select_major_route(direction)
			_to_routes(loop)
			if not content.is_major_route_day(day):
				var chapter: String = str(loop.state.world_facts.get("story_checkpoint", ""))
				loop.choose_route("资源路线")
				_check(str(loop.state.world_facts.get("story_checkpoint", "")) == chapter, "小路线不改剧情章节")
			_travel(loop)
			loop.begin_stop_dialogues()
			while loop.state.phase == GameState.Phase.STOP_DIALOGUE: _respond(loop, "defer")
			loop.perform_camp_action("让成员休息")
			loop.advance_to_next_day()
		_check(loop.state.phase == GameState.Phase.ENDING and loop.state.day == 10 and loop.state.ending == "仍在路上", "各大方向可以走完十天 " + direction)
		_check(loop.state.route_history.map(func(item): return item.day) == [2, 5, 8, 10], "四次大路线历史")
		_roundtrip(loop, "十天结局")
	var changed := _new_run()
	for day in range(1, 11):
		if content.is_major_route_day(day):
			var direction := "北部污染区" if day == 2 else ("南部断路" if day == 5 else "东部聚落")
			changed.select_major_route(direction)
		_to_routes(changed)
		if not content.is_major_route_day(day): changed.choose_route("资源路线")
		_travel(changed)
		changed.begin_stop_dialogues()
		while changed.state.phase == GameState.Phase.STOP_DIALOGUE: _respond(changed, "defer")
		changed.perform_camp_action("阅读技术手册" if day == 1 else ("教学与记录" if day <= 3 else "让成员休息"))
		changed.advance_to_next_day()
	_check(changed.state.ending == "知识的火种", "十天教学策略仍可达")
	_check(changed.state.route_history[0].route == "北部污染区" and changed.state.route_history[1].route == "南部断路" and changed.state.major_route == "东部聚落", "大路线节点允许中途改变方向")

func _test_failures() -> void:
	var poor := _new_run()
	poor.state.resources.parts = 0
	_check(not poor.prepare("检查车辆"), "缺资源不能免费准备")
	_to_routes(poor)
	poor.state.resources.fuel = 0
	_check(not poor.start_travel() and poor.abandon_journey(), "缺燃料有明确结束入口")
	for reason in ["water", "food", "vehicle", "member"]:
		var loop := _new_run()
		_to_routes(loop)
		_travel(loop)
		loop.begin_stop_dialogues()
		while loop.state.phase == GameState.Phase.STOP_DIALOGUE: _respond(loop, "defer")
		match reason:
			"water": loop.state.resources.water = 0
			"food": loop.state.resources.food = 0
			"vehicle": loop.state.vehicle_health = 0
			"member": loop.state.adjust_member("老张", -100)
		loop.finish_stop_dialogues()
		_check(not loop.state.ending.is_empty(), "生存失败 " + reason)
		loop.advance_to_next_day()
		_check(loop.state.phase == GameState.Phase.ENDING and loop.state.day == 1, "失败不进入下一天")
	var event := _new_run()
	_to_routes(event)
	event.choose_style("快速")
	event.state.tracking = 24
	event.start_travel()
	event.tick_travel(10)
	event.resolve_travel_event(0)
	_check(event.state.vehicle_health == 68 and event.state.member_named("阿杰").health == 85 and event.state.member_named("老张").health == 100, "高追踪仅一次怪物事件，不再叠加道路事故")

func _new_run() -> DayLoop:
	var state := GameState.new()
	states.append(state)
	var loop := DayLoop.new(state, content)
	loop.start_new_game()
	return loop

func _to_routes(loop: DayLoop) -> void:
	loop.finish_preparation()
	while loop.state.phase == GameState.Phase.MEMBER_AFFAIRS: _respond(loop, "defer")

func _travel(loop: DayLoop) -> void:
	loop.start_travel()
	loop.tick_travel(10)
	loop.resolve_travel_event(0.99)
	loop.continue_after_event()
	loop.tick_travel(10)

func _approach(loop: DayLoop) -> void:
	var target := content.member_position(str(loop.current_transaction().speaker))
	if target < 0: return
	var distance := target - loop.state.camp_position
	if not is_zero_approx(distance): loop.move_in_camp(signf(distance), absf(distance) / float(content.camp_data().walk_speed))

func _respond(loop: DayLoop, choice: String) -> bool:
	if loop.state.phase == GameState.Phase.STOP_DIALOGUE and not loop.conversation_open:
		_approach(loop)
		loop.begin_conversation(str(loop.current_transaction().speaker))
	return loop.respond(choice)

func _roundtrip(loop: DayLoop, label: String) -> void:
	var copy := _new_run()
	var saved := saves.snapshot(loop.state, loop)
	_check(saves.restore(JSON.parse_string(JSON.stringify(saved)), copy.state, copy), "保存恢复 " + label)
	# JSON represents numbers as floats; compare serialized values, not Variant types.
	_check(JSON.parse_string(JSON.stringify(saves.snapshot(copy.state, copy))) == JSON.parse_string(JSON.stringify(saved)), "恢复全部进度 " + label)
	_check(copy.random.randf() == loop.random.randf(), "恢复随机序列 " + label)

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + description)
