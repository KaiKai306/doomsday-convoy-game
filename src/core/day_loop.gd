class_name DayLoop
extends RefCounted

## Rules own all mutations; UI only issues validated commands.
var state: GameState
var content: DemoContent
var route_choice := "安全路线"
var travel_style := "低噪音"
var event_log: Array[String] = []
var daily_transactions: Array = []
var next_day_effects: Array[String] = []
var transaction_index := 0
var prepared := false
var travel_progress := 0.0
var travel_resolved := false
var random := RandomNumberGenerator.new()
var last_error := ""
var conversation_open := false

func _init(game_state: GameState, demo_content: DemoContent) -> void:
	state = game_state
	content = demo_content

func start_new_game() -> void:
	state.reset(content.initial_resources(), content.initial_trust())
	state.initialize_members(content.members(), content.initial_trust())
	state.vehicle_health = int(content.vehicle().get("durability", 80))
	route_choice = "安全路线"
	travel_style = "低噪音"
	event_log.clear()
	next_day_effects.clear()
	state.camp_position = float(content.camp_data().get("entry_position", 100.0))
	_begin_morning()

func _begin_morning() -> void:
	prepared = false
	transaction_index = 0
	travel_progress = 0.0
	travel_resolved = false
	conversation_open = false
	var facts := state.world_facts.duplicate(true)
	if int(state.member_named("老赵").trust) <= 30: facts["repair_priority"] = "refuse"
	daily_transactions = content.morning_transactions_for_day(state.day, facts)
	if int(state.resources.water) < content.daily_cost("water") * 2:
		daily_transactions.push_front(content.transaction("water"))
	var patient := medical_target()
	if not patient.is_empty() and (int(patient.health) <= 75 or int(patient.fatigue) >= 35):
		var request := content.transaction("medical")
		request["target_member"] = str(patient.name)
		request.goal = "照料%s的伤势与疲劳" % patient.name
		request.body = "“%s的健康只有%d，疲劳已经%d。给我一份药品，我先处理伤势；晚上仍需要考虑让大家休息。”" % [patient.name, patient.health, patient.fatigue]
		request.responses.accept["health"] = 20
		request.responses.accept.effect = "药品 -1，%s健康 +20、疲劳 -15，全队信任 +3" % patient.name
		request.responses.refuse.effect = "全队信任 -4，保留药品；%s伤势未处理" % patient.name
		daily_transactions.push_front(request)
	_sort_transactions()
	daily_transactions = daily_transactions.slice(0, 3)
	state.set_phase(GameState.Phase.MORNING)

func prepare(action: String) -> bool:
	if state.phase != GameState.Phase.MORNING or prepared: return false
	match action:
		"检查车辆":
			if not _pay({"parts": 1}): return false
			state.vehicle_health = mini(100, state.vehicle_health + 6)
			_add_event("出发前检查 → 零件 -1，耐久 +6（上限 100）")
		"公开情报":
			state.adjust_trust(2)
			_add_event("公开今日路线情报 → 信任 +2")
		"分配饮水":
			if not _pay({"water": 2}): return false
			state.adjust_all_fatigue(-8)
			_add_event("补充饮水 → 饮水 -2，疲劳 -8（下限 0）")
		_: return false
	prepared = true
	return true

func finish_preparation() -> bool:
	if state.phase != GameState.Phase.MORNING: return false
	state.set_phase(GameState.Phase.ROUTE_SELECTION)
	return true

func choose_route(route_name: String) -> bool:
	if state.phase != GameState.Phase.ROUTE_SELECTION or not content.routes().has(route_name): return false
	route_choice = route_name
	return true

func choose_style(style: String) -> bool:
	if state.phase != GameState.Phase.ROUTE_SELECTION or style not in ["低噪音", "快速", "绕行"]: return false
	travel_style = style
	return true

func start_travel() -> bool:
	if state.phase != GameState.Phase.ROUTE_SELECTION: return false
	if not _pay({"fuel": route_fuel_cost()}): return false
	travel_progress = 0.0
	travel_resolved = false
	_add_event("%s · %s → 燃料 -%d" % [route_choice, travel_style, route_fuel_cost()])
	state.set_phase(GameState.Phase.TRAVEL)
	return true

func tick_travel(delta: float) -> bool:
	if state.phase != GameState.Phase.TRAVEL: return false
	travel_progress = minf(1.0, travel_progress + delta / 7.0)
	return travel_progress >= 1.0

func resolve_travel_event(test_roll: float = -1.0) -> bool:
	if state.phase != GameState.Phase.TRAVEL or travel_resolved: return false
	travel_resolved = true
	travel_progress = 1.0
	var accident := (random.randf() if test_roll < 0.0 else test_roll) < route_accident_chance()
	var wear := 4
	if accident:
		wear += 5 if travel_style == "绕行" else 12
		_add_event("路面塌陷 → %s预设，耐久 -%d" % [travel_style, wear])
	else:
		_add_event("避开道路事故 → 正常行驶损耗，耐久 -4")
	state.vehicle_health = maxi(0, state.vehicle_health - wear)
	if accident:
		var injury := 5 if travel_style == "绕行" else 12
		state.adjust_member("老赵", -injury)
		_add_event("老赵检查车底时擦伤 → 老赵健康 -%d" % injury)
	var noise := 12 if travel_style == "快速" else (2 if travel_style == "低噪音" else 5)
	state.tracking = clampi(state.tracking + noise - 4, 0, 100)
	state.adjust_all_fatigue(6 if travel_style == "快速" else 10)
	state.adjust_member("阿遥", 0, 3)
	if state.tracking >= 25:
		state.vehicle_health = maxi(0, state.vehicle_health - 8)
		state.tracking = maxi(0, state.tracking - 10)
		_add_event("发动机噪音积累 → 异变兽追上车队，耐久 -8，追踪 -10")
		state.adjust_member("阿遥", -15)
		_add_event("阿遥掩护撤离时受伤 → 阿遥健康 -15")
	var gains: Dictionary = content.route_data(route_choice).get("supplies", {})
	for key in gains: state.resources[key] = int(state.resources.get(key, 0)) + int(gains[key])
	var route_knowledge := int(content.route_data(route_choice).get("knowledge", 0))
	state.knowledge += route_knowledge
	if route_knowledge > 0: _add_event("发现旧路线档案 → 知识 +%d" % route_knowledge)
	_add_event("抵达%s → 补给 %s" % [content.stop_name(state.day), content.cost_text(gains, true)])
	state.camp_position = float(content.camp_data().get("entry_position", 100.0))
	conversation_open = false
	state.set_phase(GameState.Phase.REST_STOP)
	return accident

func move_in_camp(direction: float, delta: float) -> bool:
	if state.phase != GameState.Phase.REST_STOP or conversation_open: return false
	if not is_finite(direction) or not is_finite(delta) or delta <= 0.0: return false
	var settings := content.camp_data()
	state.camp_position = clampf(state.camp_position + clampf(direction, -1.0, 1.0) * delta * float(settings.get("walk_speed", 210.0)), 45.0, float(settings.get("width", 1440.0)) - 45.0)
	return true

func begin_conversation(speaker: String) -> bool:
	if state.phase != GameState.Phase.REST_STOP or conversation_open: return false
	var transaction := current_transaction()
	if transaction.is_empty() or transaction.speaker != speaker:
		last_error = "先处理当前的紧急事务，再回应其他请求。"
		return false
	var target := content.member_position(speaker)
	if target < 0.0 or absf(state.camp_position - target) > float(content.camp_data().get("interaction_range", 72.0)):
		last_error = "靠近这位队员后才能交谈。"
		return false
	conversation_open = true
	return true

func close_conversation() -> void:
	conversation_open = false

func current_transaction() -> Dictionary:
	return daily_transactions[transaction_index] if transaction_index < daily_transactions.size() else {}

func respond(response: String) -> bool:
	if state.phase != GameState.Phase.REST_STOP or not conversation_open or response not in ["accept", "refuse", "defer"]: return false
	var transaction := current_transaction()
	if transaction.is_empty(): return false
	var option: Dictionary = transaction.get("responses", {}).get(response, {})
	if option.is_empty() or not _pay(option.get("cost", {})): return false
	state.adjust_trust(int(option.get("trust", 0)))
	state.vehicle_health = clampi(state.vehicle_health + int(option.get("repair", 0)), 0, 100)
	state.knowledge += int(option.get("knowledge", 0))
	var target_name: String = str(transaction.get("target_member", transaction.speaker))
	state.adjust_member(str(transaction.speaker), 0, 0, int(option.get("trust", 0)))
	if transaction.id == "water_request": state.adjust_all_fatigue(int(option.get("fatigue", 0)))
	else: state.adjust_member(target_name, int(option.get("health", 0)), int(option.get("fatigue", 0)))
	var speaker := state.member_named(str(transaction.speaker))
	if not speaker.is_empty(): speaker.last_memory = "%s：%s" % [option.get("label", response), option.get("effect", "")]
	var fact_key: String = transaction.get("fact", "")
	if not fact_key.is_empty(): state.world_facts[fact_key] = response
	if fact_key == "repair_priority":
		state.world_facts["road_accident_modifier"] = -1 if response == "accept" else (1 if response == "refuse" else 0)
	_add_event("%s · %s → %s" % [transaction.speaker, option.get("label", response), option.get("effect", "")])
	next_day_effects.append(str(option.get("future", "本次回应已记录。")))
	transaction["resolution"] = response
	transaction_index += 1
	conversation_open = false
	if transaction_index >= daily_transactions.size(): state.set_phase(GameState.Phase.CAMP_ACTION)
	return true

func perform_camp_action(action_name: String, target_name: String = "", teacher_name: String = "") -> bool:
	if state.phase != GameState.Phase.CAMP_ACTION: return false
	var action: Dictionary = content.available_camp_actions(state.day).get(action_name, {})
	if action.is_empty(): return false
	if action.get("target_required", false):
		if state.member_named(target_name).is_empty():
			last_error = "先选择需要照料的成员。"
			return false
	# Resolve and validate every participant before spending resources or the evening.
	if action_name in ["阅读技术手册", "维修车辆"]:
		var candidates := knowledge_candidates(action_name)
		if target_name.is_empty():
			target_name = "老赵" if candidates.has("老赵") else (candidates[0] if not candidates.is_empty() else "")
		if not candidates.has(target_name):
			last_error = "选择尚未掌握知识、健康大于0且疲劳低于70的读者。" if action_name == "阅读技术手册" else "选择健康大于0且疲劳低于70的维修者。"
			return false
	if action_name == "教学与记录":
		if teacher_name.is_empty():
			for candidate in knowledge_candidates(action_name):
				var candidate_learners := knowledge_candidates(action_name, candidate)
				if (target_name.is_empty() and not candidate_learners.is_empty()) or candidate_learners.has(target_name):
					teacher_name = candidate
					break
		var learners: Array[String] = []
		if not teacher_name.is_empty(): learners = knowledge_candidates(action_name, teacher_name)
		if target_name.is_empty() and not learners.is_empty(): target_name = learners[0]
		if teacher_name.is_empty() or not learners.has(target_name):
			last_error = "教师须掌握维修知识，学员尚未掌握；两人须不同、健康大于0、疲劳低于70且个人信任大于30。"
			return false
	if not _pay(action.get("cost", {})): return false
	var repair := repair_amount(target_name) if action_name == "维修车辆" else int(action.get("repair", 0))
	state.vehicle_health = mini(100, state.vehicle_health + repair)
	if int(action.get("fatigue", 0)) != 0: state.adjust_all_fatigue(int(action.fatigue))
	state.knowledge += int(action.get("knowledge", 0))
	state.adjust_trust(int(action.get("trust", 0)))
	for key in action.get("gains", {}): state.resources[key] = int(state.resources[key]) + int(action.gains[key])
	state.tracking = clampi(state.tracking + int(action.get("tracking", 0)), 0, 100)
	if action.get("target_required", false):
		state.adjust_member(target_name, int(action.get("health", 0)), int(action.get("member_fatigue", 0)), int(action.get("member_trust", 0)))
		state.member_named(target_name).last_memory = "队长在营地安排了照料。"
	for member_name in action.get("member_effects", {}):
		var effects: Dictionary = action.member_effects[member_name]
		state.adjust_member(member_name, int(effects.get("health", 0)), int(effects.get("fatigue", 0)), int(effects.get("trust", 0)))
		state.member_named(member_name).last_memory = "%s：%s" % [action_name, action.get("effect", "")]
	if not str(action.get("fact", "")).is_empty():
		state.world_facts[str(action.fact)] = true
		next_day_effects.append(str(action.get("future", "这个地点的选择已留下记录。")))
	var effect: String = str(action.get("effect", ""))
	if action_name == "维修车辆":
		effect = "零件 -2，耐久 +%d（最高 100）" % repair
		state.member_named(target_name).last_memory = "承担营地维修：耐久 +%d。" % repair
	if action_name == "阅读技术手册":
		var reader := state.member_named(target_name)
		reader.maintenance_knowledge = true
		reader.learned_from = "技术手册"
		reader.last_memory = "读懂技术手册，掌握了维修知识。"
		state.world_facts["manual_read"] = true
		effect = "知识 +1；%s掌握维修知识" % target_name
	if action_name == "教学与记录":
		var learner := state.member_named(target_name)
		learner.maintenance_knowledge = true
		learner.learned_from = teacher_name
		learner.last_memory = "向%s学习，掌握了维修知识。" % teacher_name
		state.member_named(teacher_name).last_memory = "把维修知识教给了%s。" % target_name
		state.world_facts["lessons"] = int(state.world_facts.get("lessons", 0)) + 1
		effect = "%s教给%s；知识 +1，信任 +2" % [teacher_name, target_name]
		next_day_effects.append("%s的维修知识来自%s，今后也能维修或继续教学。" % [target_name, teacher_name])
		if int(state.world_facts.lessons) >= 2 and _knowledge_count() >= 3 and _taught_count() >= 2 and not state.world_facts.get("shared_maintenance", false):
			state.world_facts["shared_maintenance"] = true
			_add_event("两次传授给不同新学员，三人掌握维修知识 → 共同维护习惯形成，今后每天耐久 +3")
	_add_event("营地 · %s%s → %s" % [action_name, "（%s）" % target_name if not target_name.is_empty() else "", effect])
	_settle_night()
	return true

func _settle_night() -> void:
	for key in ["water", "food"]:
		var amount := content.daily_cost(key)
		if int(state.resources[key]) < amount:
			state.ending = "饮水耗尽" if key == "water" else "粮食耗尽"
		state.resources[key] = maxi(0, int(state.resources[key]) - amount)
	_add_event("夜间配给 → 饮水 -%d，食物 -%d" % [content.daily_cost("water"), content.daily_cost("food")])
	if state.world_facts.get("shared_maintenance", false):
		state.vehicle_health = mini(100, state.vehicle_health + 3)
		_add_event("共同维护习惯 → 车辆耐久 +3")
	if state.vehicle_health <= 0: state.ending = "车队停摆"
	if state.team_trust <= 0: state.ending = "车队分裂"
	if state.fatigue >= 100: state.ending = "疲惫倒下"
	for member in state.members:
		if int(member.fatigue) >= 70:
			state.adjust_member(str(member.name), -5)
			_add_event("%s的高疲劳未缓解 → 健康 -5" % member.name)
		if int(member.health) <= 0:
			state.ending = "关键成员倒下"
			_add_event("%s的伤势未能挽回 → 基础岗位无法维持" % member.name)
	if state.ending.is_empty() and state.day >= content.demo_days():
		state.ending = "知识的火种" if state.world_facts.get("shared_maintenance", false) else "仍在路上"
	state.set_phase(GameState.Phase.NIGHT_SETTLEMENT)

func advance_to_next_day() -> bool:
	if state.phase != GameState.Phase.NIGHT_SETTLEMENT: return false
	if not state.ending.is_empty():
		state.set_phase(GameState.Phase.ENDING)
		return true
	state.advance_day()
	event_log.clear()
	next_day_effects.clear()
	_begin_morning()
	return true

func route_fuel_cost() -> int:
	return content.route_fuel_cost(route_choice) + (2 if travel_style == "绕行" else 0)

func abandon_journey() -> bool:
	if state.phase != GameState.Phase.ROUTE_SELECTION: return false
	for route in content.routes():
		if int(state.resources.fuel) >= content.route_fuel_cost(route): return false
	state.ending = "燃料耗尽"
	state.set_phase(GameState.Phase.ENDING)
	return true

func route_accident_chance() -> float:
	var modifier := int(state.world_facts.get("road_accident_modifier", 0))
	var style_modifier := -0.1 if travel_style == "绕行" else (0.1 if travel_style == "快速" else 0.0)
	return clampf(content.route_accident_chance(route_choice) + modifier * 0.15 + style_modifier + (0.15 if state.vehicle_health < 40 else 0.0), 0.0, 0.95)

func can_afford(cost: Dictionary) -> bool:
	for key in cost:
		if int(state.resources.get(key, 0)) < int(cost[key]): return false
	return true

func transaction_summary() -> String:
	var lines: Array[String] = []
	for transaction in daily_transactions:
		lines.append("%s · %s / 紧急度%s" % [transaction.speaker, transaction.goal, transaction.urgency])
	return "\n".join(lines)

func next_day_effects_text() -> String:
	return "\n".join(next_day_effects)

func event_log_text() -> String:
	return "\n".join(event_log)

func resources_text() -> String:
	return content.cost_text(state.resources, true)

func medical_target() -> Dictionary:
	var target: Dictionary = {}
	var highest := -1
	for member in state.members:
		var urgency := (100 - int(member.health)) * 2 + int(member.fatigue)
		if urgency > highest:
			highest = urgency
			target = member
	return target

func member_summary(member_name: String) -> String:
	var member := state.member_named(member_name)
	if member.is_empty(): return ""
	var knowledge_text := "已掌握（来源：%s）" % member.get("learned_from", "") if member.get("maintenance_knowledge", false) else "尚未掌握"
	return "%s · %s\n健康 %d / 疲劳 %d / 个人信任 %d\n维修知识：%s\n记忆：%s" % [member.name, member.job, member.health, member.fatigue, member.trust, knowledge_text, member.last_memory]

func knowledge_candidates(action_name: String, teacher_name: String = "") -> Array[String]:
	var candidates: Array[String] = []
	if action_name == "教学与记录" and not teacher_name.is_empty():
		var teacher := state.member_named(teacher_name)
		if not _can_work(teacher) or not teacher.get("maintenance_knowledge", false) or int(teacher.trust) <= 30: return candidates
	for member in state.members:
		if not _can_work(member): continue
		var knows: bool = member.get("maintenance_knowledge", false)
		match action_name:
			"阅读技术手册":
				if not knows: candidates.append(str(member.name))
			"维修车辆": candidates.append(str(member.name))
			"教学与记录":
				if int(member.trust) <= 30: continue
				if teacher_name.is_empty() and knows: candidates.append(str(member.name))
				elif not teacher_name.is_empty() and not knows and member.name != teacher_name: candidates.append(str(member.name))
	return candidates

func repair_amount(member_name: String) -> int:
	var member := state.member_named(member_name)
	if not _can_work(member): return 0
	return int(content.camp_actions().get("维修车辆", {}).get("repair", 15)) + (6 if member.get("maintenance_knowledge", false) else 0)

func knowledge_summary() -> String:
	var lines: Array[String] = []
	for member in state.members:
		if member.get("maintenance_knowledge", false):
			lines.append("%s ← %s" % [member.name, member.get("learned_from", "")])
	var progress := "共同维护已形成：每晚耐久 +3" if state.world_facts.get("shared_maintenance", false) else "共同维护进度：新学员教学 %d/2，掌握 %d/3 人" % [mini(2, int(state.world_facts.get("lessons", 0))), mini(3, _knowledge_count())]
	return "维修知识：%s\n%s" % [" / ".join(lines) if not lines.is_empty() else "尚无人掌握；先安排阅读技术手册", progress]

func _can_work(member: Dictionary) -> bool:
	return not member.is_empty() and int(member.health) > 0 and int(member.fatigue) < 70

func _knowledge_count() -> int:
	var count := 0
	for member in state.members:
		if member.get("maintenance_knowledge", false): count += 1
	return count

func _taught_count() -> int:
	var count := 0
	for member in state.members:
		if member.get("maintenance_knowledge", false) and str(member.get("learned_from", "")) not in ["", "技术手册"]: count += 1
	return count

func _sort_transactions() -> void:
	# Stable order within each urgency level; conflicts precede low-priority follow-ups.
	var sorted: Array = []
	for urgency in ["高", "中", "低"]:
		for transaction in daily_transactions:
			if transaction.urgency == urgency: sorted.append(transaction)
	daily_transactions = sorted

func _pay(cost: Dictionary) -> bool:
	last_error = ""
	if not can_afford(cost):
		last_error = "物资不足，无法执行。"
		return false
	for key in cost: state.resources[key] = int(state.resources[key]) - int(cost[key])
	return true

func _add_event(message: String) -> void:
	event_log.append(message)
