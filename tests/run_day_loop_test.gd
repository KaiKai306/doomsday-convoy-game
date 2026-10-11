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
	_check(loop.daily_transactions.any(func(t): return t.id == "repair_priority" and t.goal.contains("检修")), "昨日接受生成后续检修事务")
	_check(loop.daily_transactions[0].goal.contains("记下来"), "情报后续事务按紧急度排在低优先检修之前")
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
	_check(survivor.state.world_facts.get("shared_maintenance", false), "教给两位新学员形成维护习惯")
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
	_check(loop.state.members.size() == 5 and loop.state.member_named("队长").health == 100, "独立成员初始化")
	_check(loop.state.member_named("老赵").health == 88 and loop.state.member_named("阿遥").health == 100, "事故只伤及实际处理车辆的成员")
	_check(loop.state.member_named("老赵").trust == 53 and loop.state.member_named("周禾").trust == 50, "接受请求只修改说话者个人信任")
	_check(loop.state.member_named("阿遥").last_memory.contains("核对"), "个人对话记忆保留")
	var restored_members := true
	for member in loop.state.members:
		var restored_member := resumed.state.member_named(str(member.name))
		for key in ["health", "fatigue", "trust", "job", "last_memory"]:
			if restored_member.get(key) != member.get(key): restored_members = false
	_check(restored_members, "个人状态完整保存恢复")
	var old_members := saves.snapshot(resumed.state, resumed)
	old_members.erase("members")
	old_members.fatigue = 39
	old_members.team_trust = 61
	_check(saves.restore(old_members, camp_restore.state, camp_restore) and camp_restore.state.members.size() == 5, "旧版 2 存档补全成员")
	_check(camp_restore.state.member_named("许宁").fatigue == 39 and camp_restore.state.member_named("许宁").trust == 61, "旧全队疲劳信任迁移到个人状态")
	corrupt = before.duplicate(true)
	corrupt.members[0].health = -1
	_check(not saves.restore(corrupt, camp_restore.state, camp_restore), "拒绝损坏个人健康")
	corrupt = before.duplicate(true)
	corrupt.members[1].name = corrupt.members[0].name
	_check(not saves.restore(corrupt, camp_restore.state, camp_restore), "拒绝重复成员")
	var treated := _new_run()
	_reach_camp(treated)
	treated.state.adjust_member("老赵", -40, 20)
	var other_fatigue: int = treated.state.member_named("周禾").fatigue
	var drugs: int = treated.state.resources.medicine
	_check(treated.perform_camp_action("照料伤员", "老赵"), "营地定向照料")
	_check(treated.state.member_named("老赵").health == 85 and treated.state.member_named("老赵").fatigue == 30, "照料只恢复目标的健康与疲劳")
	_check(treated.state.member_named("周禾").fatigue == other_fatigue and treated.state.resources.medicine == drugs - 1, "其他成员不获得免费治疗")
	_check(not treated.perform_camp_action("修复旧油泵"), "照料后不能再做地点行动")
	var poor_patient := _new_run()
	_reach_camp(poor_patient)
	before = saves.snapshot(poor_patient.state, poor_patient)
	_check(not poor_patient.perform_camp_action("照料伤员", "不存在") and saves.snapshot(poor_patient.state, poor_patient) == before, "不存在的目标不扣药品")
	poor_patient.state.resources.medicine = 0
	_check(not poor_patient.perform_camp_action("照料伤员", "老赵"), "缺药不可治疗")
	var injured := _new_run()
	_reach_camp(injured)
	injured.state.adjust_member("阿遥", -50)
	injured.perform_camp_action("阅读技术手册")
	injured.advance_to_next_day()
	_check(injured.daily_transactions[0].id == "medical_request" and injured.daily_transactions[0].target_member == "阿遥", "个人伤势生成优先医疗事务")
	injured.finish_preparation()
	injured.start_travel()
	injured.resolve_travel_event(0.99)
	var fatigue_before: int = injured.state.member_named("周禾").fatigue
	_respond(injured, "accept")
	_check(injured.state.member_named("阿遥").health == 70 and injured.state.member_named("周禾").health == 100, "医疗请求治疗具体伤员")
	_check(injured.state.member_named("周禾").fatigue == fatigue_before, "医疗请求不会降低其他成员疲劳")
	var exhausted := _new_run()
	_reach_camp(exhausted)
	exhausted.state.adjust_member("阿遥", 0, 70)
	exhausted.perform_camp_action("阅读技术手册")
	_check(exhausted.state.member_named("阿遥").health == 95 and exhausted.state.member_named("周禾").health == 100, "个人高疲劳导致夜间健康损失")
	var lost_member := _new_run()
	_reach_camp(lost_member)
	lost_member.state.adjust_member("老赵", -100)
	lost_member.perform_camp_action("阅读技术手册")
	_check(lost_member.state.ending == "关键成员倒下", "基础成员健康归零结束")
	var resentment := _new_run()
	_reach_camp(resentment)
	resentment.state.adjust_member("老赵", 0, 0, -30)
	resentment.state.world_facts.repair_priority = "accept"
	resentment.perform_camp_action("让成员休息")
	resentment.advance_to_next_day()
	_check(resentment.daily_transactions.any(func(t): return t.goal.contains("分配")), "个人低信任触发分配冲突")
	for day in range(1, 6):
		var site: Dictionary = content.stop_event(day)
		_check(site.actions.size() == 2, "地点两种取舍 %d" % day)
		for action_name in site.actions:
			var site_run := _new_run()
			site_run.state.day = day
			_reach_camp(site_run)
			var action: Dictionary = site.actions[action_name]
			var old_resources := site_run.state.resources.duplicate()
			_check(site_run.perform_camp_action(action_name), "地点行动可执行 " + action_name)
			var paid := true
			for key in old_resources:
				var expected := int(old_resources[key]) - int(action.cost.get(key, 0)) + int(action.get("gains", {}).get(key, 0)) - content.daily_cost(key)
				if int(site_run.state.resources[key]) != expected: paid = false
			_check(paid, "地点资源与夜间配给正确 " + action_name)
			_check(site_run.state.world_facts.get(action.fact, false), "地点选择记录 " + action_name)
			before = saves.snapshot(site_run.state, site_run)
			_check(not site_run.perform_camp_action(action_name) and saves.snapshot(site_run.state, site_run) == before, "地点不可重复领奖 " + action_name)
	var wrong_site := _new_run()
	_reach_camp(wrong_site)
	before = saves.snapshot(wrong_site.state, wrong_site)
	_check(not wrong_site.perform_camp_action("启动柴油抽水机") and saves.snapshot(wrong_site.state, wrong_site) == before, "不能执行其他地点行动")
	wrong_site.state.resources.parts = 0
	_check(not wrong_site.perform_camp_action("修复旧油泵"), "旧油泵需要实际零件")
	_test_personal_knowledge()
	if failures == 0: print("DAY_LOOP_TEST_PASS checks=%d" % checks)
	else: printerr("DAY_LOOP_TEST_FAIL failures=%d checks=%d" % [failures, checks])
	for state in states: state.free()
	quit(failures)

func _test_personal_knowledge() -> void:
	var spreading := _new_run()
	_reach_camp(spreading)
	_check(spreading.knowledge_candidates("阅读技术手册").size() == 5 and spreading.knowledge_candidates("教学与记录").is_empty(), "新游戏无人掌握维修知识")
	_check(spreading.perform_camp_action("阅读技术手册", "老赵"), "指定读者阅读技术手册")
	_check(spreading.state.member_named("老赵").maintenance_knowledge and spreading.state.member_named("老赵").learned_from == "技术手册", "阅读只赋予个人知识并保存来源")
	_check(not spreading.state.member_named("队长").maintenance_knowledge and spreading.member_summary("老赵").contains("技术手册"), "其他人不会随全局知识自动掌握")
	spreading.advance_to_next_day()
	_reach_camp(spreading)
	var before := saves.snapshot(spreading.state, spreading)
	_check(not spreading.perform_camp_action("阅读技术手册", "老赵") and saves.snapshot(spreading.state, spreading) == before, "已知读者不可重复刷阅读且不消耗夜晚")
	_check(not spreading.perform_camp_action("教学与记录", "老赵", "老赵") and saves.snapshot(spreading.state, spreading) == before, "不能自我教学")
	_check(spreading.knowledge_candidates("教学与记录") == ["老赵"] and spreading.knowledge_candidates("教学与记录", "老赵").has("队长"), "候选教师与新学员来源于个人知识")
	_check(spreading.perform_camp_action("教学与记录", "队长", "老赵"), "手册读者教给第一位学员")
	_check(spreading.state.member_named("队长").learned_from == "老赵" and spreading.state.world_facts.lessons == 1 and not spreading.state.world_facts.get("shared_maintenance", false), "第一次教学记录来源但尚未形成习惯")
	spreading.advance_to_next_day()
	_reach_camp(spreading)
	before = saves.snapshot(spreading.state, spreading)
	_check(not spreading.perform_camp_action("教学与记录", "队长", "老赵") and saves.snapshot(spreading.state, spreading) == before, "重复教给同一学员不计课程且不消耗行动")
	spreading.state.vehicle_health = 50
	_check(spreading.perform_camp_action("教学与记录", "许宁", "队长"), "第一位学员继续教给第二位学员")
	_check(spreading.state.member_named("许宁").learned_from == "队长" and spreading.state.world_facts.lessons == 2, "多代传播保留实际教师来源")
	_check(spreading.state.world_facts.shared_maintenance and spreading.state.vehicle_health == 53, "两次不同新学员教学且三人掌握形成每晚维护")
	_check(spreading.knowledge_summary().contains("许宁 ← 队长") and spreading.knowledge_summary().contains("每晚耐久 +3"), "知识总览展示传播链与共同维护")
	var snapshot := saves.snapshot(spreading.state, spreading)
	var resumed := _new_run()
	_check(saves.restore(JSON.parse_string(JSON.stringify(snapshot)), resumed.state, resumed), "个人知识传播 JSON 恢复")
	_check(resumed.state.member_named("许宁").maintenance_knowledge and resumed.state.member_named("许宁").learned_from == "队长" and resumed.state.world_facts.lessons is int and resumed.state.resources.parts is int, "JSON 恢复来源并规范字段类型")
	var unchanged := saves.snapshot(resumed.state, resumed)
	for corruption in ["knowledge_type", "source_type", "unknown_source", "self_source", "missing_pair", "partial_members", "unlearned_source", "cyclic_source", "lesson_type", "manual_type", "shared_type", "shared_few_members", "shared_few_lessons", "shared_readers_only", "shared_one_learner"]:
		var corrupt := snapshot.duplicate(true)
		match corruption:
			"knowledge_type": corrupt.members[0].maintenance_knowledge = 1
			"source_type": corrupt.members[0].learned_from = 1
			"unknown_source": corrupt.members[0].learned_from = "陌生人"
			"self_source": corrupt.members[0].learned_from = "队长"
			"missing_pair": corrupt.members[0].erase("learned_from")
			"partial_members":
				corrupt.members[0].erase("learned_from")
				corrupt.members[0].erase("maintenance_knowledge")
			"unlearned_source": corrupt.members[0].learned_from = "阿遥"
			"cyclic_source": corrupt.members[1].learned_from = "队长"
			"lesson_type": corrupt.world_facts.lessons = "2"
			"manual_type": corrupt.world_facts.manual_read = "true"
			"shared_type": corrupt.world_facts.shared_maintenance = 1
			"shared_few_members":
				corrupt.members[2].maintenance_knowledge = false
				corrupt.members[2].learned_from = ""
			"shared_few_lessons": corrupt.world_facts.lessons = 1
			"shared_readers_only":
				corrupt.members[0].learned_from = "技术手册"
				corrupt.members[2].learned_from = "技术手册"
			"shared_one_learner": corrupt.members[2].learned_from = "技术手册"
		_check(not saves.restore(corrupt, resumed.state, resumed) and saves.snapshot(resumed.state, resumed) == unchanged, "损坏知识存档原子拒绝 " + corruption)
	# Explicit empty personal fields must never regain knowledge from stale global flags.
	var phantom := _new_run()
	_reach_camp(phantom)
	phantom.state.world_facts = {"manual_read": true}
	snapshot = saves.snapshot(phantom.state, phantom)
	_check(saves.restore(JSON.parse_string(JSON.stringify(snapshot)), resumed.state, resumed) and resumed.knowledge_candidates("教学与记录").is_empty(), "显式个人空知识不从全局手册标志补全")
	before = saves.snapshot(resumed.state, resumed)
	_check(not resumed.perform_camp_action("教学与记录") and saves.snapshot(resumed.state, resumed) == before, "全局手册标志不能代替真正的教师")
	# Legacy cohorts use content order even if the saved member order changes.
	for lessons in range(3):
		var legacy := snapshot.duplicate(true)
		for member in legacy.members:
			member.erase("maintenance_knowledge")
			member.erase("learned_from")
		legacy.members.reverse()
		legacy.world_facts = {"manual_read": true, "lessons": lessons, "shared_maintenance": lessons == 2}
		_check(saves.restore(JSON.parse_string(JSON.stringify(legacy)), resumed.state, resumed), "旧个人字段迁移课程 %d" % lessons)
		_check(resumed.state.member_named("老赵").learned_from == "技术手册" and resumed.state.member_named("队长").maintenance_knowledge == (lessons >= 1) and resumed.state.member_named("许宁").maintenance_knowledge == (lessons >= 2), "旧知识按内容顺序分配不同学员 %d" % lessons)
		_check(not resumed.state.member_named("阿遥").maintenance_knowledge and resumed.state.world_facts.shared_maintenance == (lessons == 2), "旧档维护状态保留且不扩大知识人数 %d" % lessons)
	var legacy := snapshot.duplicate(true)
	legacy.erase("members")
	legacy.world_facts = {"shared_maintenance": true}
	_check(saves.restore(legacy, resumed.state, resumed) and resumed.state.member_named("老赵").maintenance_knowledge and resumed.state.member_named("队长").maintenance_knowledge and resumed.state.member_named("许宁").maintenance_knowledge and resumed.state.world_facts.lessons == 2, "无成员的旧共同维护档补齐读者与两位学员")
	resumed.state.day = 5
	resumed.state.vehicle_health = 50
	_check(resumed.perform_camp_action("让成员休息") and resumed.state.vehicle_health == 53 and resumed.state.ending == "知识的火种", "旧档共同维护继续提供每晚耐久与知识结局")
	legacy.world_facts = {}
	_check(saves.restore(legacy, resumed.state, resumed) and resumed.knowledge_candidates("教学与记录").is_empty(), "无知识的旧档保留无人掌握")
	var repairing := _new_run()
	_reach_camp(repairing)
	repairing.state.vehicle_health = 40
	_check(repairing.repair_amount("队长") == 15 and repairing.perform_camp_action("维修车辆", "队长") and repairing.state.vehicle_health == 55, "普通成员营地维修保留基础15耐久")
	var skilled := _new_run()
	_reach_camp(skilled)
	skilled.perform_camp_action("阅读技术手册", "老赵")
	skilled.advance_to_next_day()
	_reach_camp(skilled)
	skilled.state.vehicle_health = 40
	var parts: int = skilled.state.resources.parts
	_check(skilled.repair_amount("老赵") == 21 and skilled.perform_camp_action("维修车辆", "老赵") and skilled.state.vehicle_health == 61 and skilled.state.resources.parts == parts - 2, "掌握知识营地维修多6耐久且费用不变")
	var dialogue := _new_run()
	dialogue.state.member_named("老赵").maintenance_knowledge = true
	dialogue.state.member_named("老赵").learned_from = "技术手册"
	dialogue.finish_preparation()
	dialogue.start_travel()
	dialogue.resolve_travel_event(0.99)
	var health_before: int = dialogue.state.vehicle_health
	_check(_respond(dialogue, "accept") and dialogue.state.vehicle_health == health_before + 10, "知识效率不会改动对话维修奖励")
	var poor := _new_run()
	_reach_camp(poor)
	poor.state.resources.parts = 0
	before = saves.snapshot(poor.state, poor)
	_check(not poor.perform_camp_action("维修车辆", "老赵") and saves.snapshot(poor.state, poor) == before, "缺资源维修不改变成员车辆或行动阶段")
	for issue in ["dead", "tired", "distrust_teacher", "distrust_learner"]:
		var denied := _new_run()
		_reach_camp(denied)
		denied.state.member_named("老赵").maintenance_knowledge = true
		denied.state.member_named("老赵").learned_from = "技术手册"
		match issue:
			"dead": denied.state.member_named("队长").health = 0
			"tired": denied.state.member_named("队长").fatigue = 70
			"distrust_teacher": denied.state.member_named("老赵").trust = 30
			"distrust_learner": denied.state.member_named("队长").trust = 30
		before = saves.snapshot(denied.state, denied)
		_check(not denied.perform_camp_action("教学与记录", "队长", "老赵") and saves.snapshot(denied.state, denied) == before, "教学参与资格不符原子拒绝 " + issue)
		if issue in ["dead", "tired"]:
			_check(denied.repair_amount("队长") == 0 and not denied.perform_camp_action("维修车辆", "队长") and not denied.perform_camp_action("阅读技术手册", "队长") and saves.snapshot(denied.state, denied) == before, "不合格执行者不可维修或阅读 " + issue)
	for issue in ["teachers_tired", "teachers_distrust", "teachers_dead", "all_known"]:
		var denied := _new_run()
		_reach_camp(denied)
		for member in denied.state.members:
			if str(member.name) in ["老赵", "许宁"] or issue == "all_known":
				member.maintenance_knowledge = true
				member.learned_from = "技术手册"
				match issue:
					"teachers_tired": member.fatigue = 70
					"teachers_distrust": member.trust = 30
					"teachers_dead": member.health = 0
		before = saves.snapshot(denied.state, denied)
		_check(not denied.perform_camp_action("教学与记录") and saves.snapshot(denied.state, denied) == before, "无合格教师学员配对时自动教学原子拒绝 " + issue)
	var borderline := _new_run()
	_reach_camp(borderline)
	borderline.state.member_named("老赵").maintenance_knowledge = true
	borderline.state.member_named("老赵").learned_from = "技术手册"
	for member_name in ["老赵", "队长"]:
		var member := borderline.state.member_named(member_name)
		member.fatigue = 69
		member.trust = 31
	_check(borderline.perform_camp_action("教学与记录", "队长", "老赵"), "疲劳69与个人信任31仍可合法教学")
	var exhausted := _new_run()
	_reach_camp(exhausted)
	exhausted.state.adjust_all_fatigue(70)
	before = saves.snapshot(exhausted.state, exhausted)
	_check(not exhausted.perform_camp_action("阅读技术手册") and not exhausted.perform_camp_action("维修车辆") and not exhausted.perform_camp_action("教学与记录") and saves.snapshot(exhausted.state, exhausted) == before, "无人可参与时自动选择也不消耗行动")
	var fallback := _new_run()
	_reach_camp(fallback)
	fallback.state.member_named("老赵").fatigue = 70
	_check(fallback.perform_camp_action("阅读技术手册") and fallback.state.member_named("队长").maintenance_knowledge and not fallback.state.member_named("老赵").maintenance_knowledge, "默认读者不可用时自动选择合格成员")

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
