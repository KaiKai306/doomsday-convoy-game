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
var morning_resolutions: Array = []
var travel_event_text := ""

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
	morning_resolutions.clear()
	state.camp_position = float(content.camp_data().get("entry_position", 100.0))
	_begin_morning()

func _begin_morning() -> void:
	prepared = false
	transaction_index = 0
	travel_progress = 0.0
	travel_resolved = false
	conversation_open = false
	travel_event_text = ""
	morning_resolutions.clear()
	var facts := state.world_facts.duplicate(true)
	if int(state.member_named("老张").trust) <= 30: facts["repair_priority"] = "refuse"
	daily_transactions = content.morning_transactions_for_day(state.day, facts)

	var patient := medical_target()
	if not patient.is_empty() and (int(patient.health) <= 75 or int(patient.fatigue) >= 35):
		var request := content.transaction("medical")
		request["target_member"] = str(patient.name)
		request.goal = "照料%s的伤势与疲劳" % patient.name
		request.body = "“%s的健康只有%d，疲劳已经%d。给我一份药品，我先处理伤势；晚上仍需要考虑让大家休息。”" % [patient.name, patient.health, patient.fatigue]
		request.responses.accept["health"] = 20
		request.responses.accept.effect = "药品 -1，%s健康 +20、疲劳 -15，全队信任 +3" % patient.name
		request.responses.refuse.effect = "全队信任 -4，保留药品；%s伤势未处理" % patient.name
		for i in range(daily_transactions.size()):
			if daily_transactions[i].speaker == "艾琳": daily_transactions[i] = request
	_sort_transactions()
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
	state.set_phase(GameState.Phase.MEMBER_AFFAIRS)
	conversation_open = true
	return true

func choose_route(route_name: String) -> bool:
	if state.phase != GameState.Phase.ROUTE_SELECTION or content.is_major_route_day(state.day) or not content.routes().has(route_name): return false
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
	_add_event("%s · %s → 燃料 -%d" % [state.major_route if content.is_major_route_day(state.day) else route_choice, travel_style, route_fuel_cost()])
	state.set_phase(GameState.Phase.TRAVEL)
	return true

func tick_travel(delta: float) -> bool:
	if state.phase != GameState.Phase.TRAVEL or not is_finite(delta) or delta <= 0.0: return false
	var limit := 1.0 if travel_resolved else 0.5
	travel_progress = minf(limit, travel_progress + delta / 7.0)
	if not travel_resolved and travel_progress >= 0.5:
		state.set_phase(GameState.Phase.TRAVEL_EVENT)
	elif travel_resolved and travel_progress >= 1.0:
		_arrive_at_stop()
	return state.phase != GameState.Phase.TRAVEL

func resolve_travel_event(test_roll: float = -1.0) -> bool:
	if state.phase != GameState.Phase.TRAVEL_EVENT or travel_resolved: return false
	travel_resolved = true
	var accident := (random.randf() if test_roll < 0.0 else test_roll) < route_accident_chance()
	var noise := 12 if travel_style == "快速" else (2 if travel_style == "低噪音" else 5)
	state.tracking = clampi(state.tracking + noise - 4, 0, 100)
	state.adjust_all_fatigue(6 if travel_style == "快速" else 10)
	state.adjust_member("阿杰", 0, 3)
	# Exactly one incident per day. Pursuit takes priority over a road accident.
	if state.tracking >= 25:
		state.vehicle_health = maxi(0, state.vehicle_health - 12)
		state.tracking = maxi(0, state.tracking - 10)
		state.adjust_member("阿杰", -15)
		travel_event_text = "异变兽追踪 → 执行%s预设，耐久 -12，阿杰健康 -15，追踪 -10" % travel_style
	else:
		var wear := 4 + ((5 if travel_style == "绕行" else 12) if accident else 0)
		state.vehicle_health = maxi(0, state.vehicle_health - wear)
		if accident:
			var injury := 5 if travel_style == "绕行" else 12
			state.adjust_member("老张", -injury)
			travel_event_text = "路面塌陷 → 执行%s预设，耐久 -%d，老张健康 -%d" % [travel_style, wear, injury]
		else:
			travel_event_text = "发现破损路面 → 按%s预设通过，正常行驶耐久 -4" % travel_style
	_add_event(travel_event_text)
	return true

func continue_after_event() -> bool:
	if state.phase != GameState.Phase.TRAVEL_EVENT or not travel_resolved: return false
	state.set_phase(GameState.Phase.TRAVEL)
	return true

func _arrive_at_stop() -> void:
	var gains := route_supplies()
	for key in gains: state.resources[key] = int(state.resources.get(key, 0)) + int(gains[key])
	_add_event("抵达%s → 补给 %s" % [content.stop_name(state.day), content.cost_text(gains, true)])
	state.camp_position = float(content.camp_data().get("entry_position", 100.0))
	conversation_open = false
	_build_stop_transactions()
	state.set_phase(GameState.Phase.REST_STOP)

func _build_stop_transactions() -> void:
	daily_transactions = []
	transaction_index = 0
	# Deferred requests carry forward without replaying accepted costs and rewards.
	for item in morning_resolutions:
		if item.get("resolution", "") == "defer":
			var pending: Dictionary = item.duplicate(true)
			pending.erase("resolution")
			daily_transactions.append(pending)
	var patient := medical_target()
	if not patient.is_empty() and int(patient.health) < 100:
		var request := content.transaction("medical")
		request["target_member"] = str(patient.name)
		request.goal = "处理%s的途中伤势" % patient.name
		request.body = "“%s受伤了。现在用一份药品处理伤势，或者把药留给之后的路。”" % patient.name
		request.responses.accept.merge({"label": "治疗%s" % patient.name, "cost": {"medicine": 1}, "health": 20, "fatigue": -15, "trust": 3, "effect": "药品 -1，%s健康 +20、疲劳 -15" % patient.name}, true)
		# Replace a deferred medicine check with the actual injury follow-up.
		for i in range(daily_transactions.size() - 1, -1, -1):
			if daily_transactions[i].speaker == "艾琳": daily_transactions.remove_at(i)
		daily_transactions.push_front(request)
	if daily_transactions.is_empty(): daily_transactions.append(content.transaction("arrival"))

func begin_stop_dialogues() -> bool:
	if state.phase != GameState.Phase.REST_STOP: return false
	state.set_phase(GameState.Phase.STOP_DIALOGUE)
	return true

func select_major_route(route_name: String) -> bool:
	if state.phase != GameState.Phase.MAJOR_ROUTE_SELECTION or not content.major_routes().has(route_name): return false
	state.major_route = route_name
	var checkpoint := content.major_checkpoint(state.day, route_name)
	state.route_history.append({"day": state.day, "route": route_name, "chapter": checkpoint})
	state.world_facts["story_direction"] = route_name
	state.world_facts["story_checkpoint"] = checkpoint
	_add_event("第%d天大路线 → %s · %s" % [state.day, route_name, checkpoint])
	state.set_phase(GameState.Phase.MORNING)
	return true

func current_route_data() -> Dictionary:
	return content.major_route_data(state.major_route) if content.is_major_route_day(state.day) else content.route_data(route_choice)

func route_supplies() -> Dictionary:
	var gains: Dictionary = current_route_data().get("supplies", {}).duplicate()
	if not content.is_major_route_day(state.day):
		var bonus: Dictionary = content.major_route_data(state.major_route).get("daily_bonus", {})
		for key in bonus: gains[key] = int(gains.get(key, 0)) + int(bonus[key])
	return gains

func move_in_camp(direction: float, delta: float) -> bool:
	if state.phase not in [GameState.Phase.REST_STOP, GameState.Phase.STOP_DIALOGUE] or conversation_open: return false
	if not is_finite(direction) or not is_finite(delta) or delta <= 0.0: return false
	var settings := content.camp_data()
	state.camp_position = clampf(state.camp_position + clampf(direction, -1.0, 1.0) * delta * float(settings.get("walk_speed", 210.0)), 45.0, float(settings.get("width", 1440.0)) - 45.0)
	return true

func begin_conversation(speaker: String) -> bool:
	if state.phase != GameState.Phase.STOP_DIALOGUE or conversation_open: return false
	var transaction := current_transaction()
	if transaction.is_empty() or transaction.speaker != speaker:
		last_error = "先处理当前的紧急事务，再回应其他请求。"
		return false
	var target := content.member_position(speaker)
	if speaker != "主角" and (target < 0.0 or absf(state.camp_position - target) > float(content.camp_data().get("interaction_range", 72.0))):
		last_error = "靠近这位队员后才能交谈。"
		return false
	conversation_open = true
	return true

func close_conversation() -> void:
	conversation_open = false

func current_transaction() -> Dictionary:
	return daily_transactions[transaction_index] if transaction_index < daily_transactions.size() else {}

func respond(response: String) -> bool:
	if state.phase not in [GameState.Phase.MEMBER_AFFAIRS, GameState.Phase.STOP_DIALOGUE] or not conversation_open or response not in ["accept", "refuse", "defer"]: return false
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
	var morning := state.phase == GameState.Phase.MEMBER_AFFAIRS
	conversation_open = morning and transaction_index < daily_transactions.size()
	if transaction_index >= daily_transactions.size():
		if morning:
			morning_resolutions = daily_transactions.duplicate(true)
			state.set_phase(GameState.Phase.ROUTE_SELECTION)
		else: state.set_phase(GameState.Phase.CAMP_ACTION)
	return true

func perform_camp_action(action_name: String, target_name: String = "") -> bool:
	if state.phase != GameState.Phase.CAMP_ACTION: return false
	var action: Dictionary = content.available_camp_actions(state.day).get(action_name, {})
	if action.is_empty(): return false
	if action.get("target_required", false):
		if state.member_named(target_name).is_empty():
			last_error = "先选择需要照料的成员。"
			return false
	if action.get("requires_manual", false) and not state.world_facts.get("manual_read", false):
		last_error = "需要先阅读技术手册。"
		return false
	if not _pay(action.get("cost", {})): return false
	state.vehicle_health = mini(100, state.vehicle_health + int(action.get("repair", 0)))
	if int(action.get("fatigue", 0)) != 0: state.adjust_all_fatigue(int(action.fatigue))
	state.knowledge += int(action.get("knowledge", 0))
	state.adjust_trust(int(action.get("trust", 0)))
	for key in action.get("gains", {}): state.resources[key] = int(state.resources[key]) + int(action.gains[key])
	state.tracking = clampi(state.tracking + int(action.get("tracking", 0)), 0, 100)
	if action.get("target_required", false):
		state.adjust_member(target_name, int(action.get("health", 0)), int(action.get("member_fatigue", 0)), int(action.get("member_trust", 0)))
		state.member_named(target_name).last_memory = "主角在营地安排了照料。"
	for member_name in action.get("member_effects", {}):
		var effects: Dictionary = action.member_effects[member_name]
		state.adjust_member(member_name, int(effects.get("health", 0)), int(effects.get("fatigue", 0)), int(effects.get("trust", 0)))
		state.member_named(member_name).last_memory = "%s：%s" % [action_name, action.get("effect", "")]
	if not str(action.get("fact", "")).is_empty():
		state.world_facts[str(action.fact)] = true
		next_day_effects.append(str(action.get("future", "这个地点的选择已留下记录。")))
	if action_name == "阅读技术手册": state.world_facts["manual_read"] = true
	if action_name == "教学与记录":
		state.world_facts["lessons"] = int(state.world_facts.get("lessons", 0)) + 1
		if int(state.world_facts.lessons) >= 2 and not state.world_facts.get("shared_maintenance", false):
			state.world_facts["shared_maintenance"] = true
			_add_event("两次共同教学与记录 → 共同维护习惯形成，今后每天耐久 +3")
	_add_event("营地 · %s%s → %s" % [action_name, "（%s）" % target_name if not target_name.is_empty() else "", action.get("effect", "")])
	_settle_night()
	return true

func finish_stop_dialogues() -> bool:
	if state.phase != GameState.Phase.CAMP_ACTION: return false
	_add_event("停歇对话结束 → 今晚不安排额外营地行动")
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
	if content.is_major_route_day(state.day): state.set_phase(GameState.Phase.MAJOR_ROUTE_SELECTION)
	return true

func route_fuel_cost() -> int:
	return int(current_route_data().get("fuel_cost", 0)) + (2 if travel_style == "绕行" else 0)

func abandon_journey() -> bool:
	if state.phase != GameState.Phase.ROUTE_SELECTION: return false
	if content.is_major_route_day(state.day):
		if int(state.resources.fuel) >= int(current_route_data().get("fuel_cost", 0)): return false
	else:
		for route in content.routes():
			if int(state.resources.fuel) >= content.route_fuel_cost(route): return false
	state.ending = "燃料耗尽"
	state.set_phase(GameState.Phase.ENDING)
	return true

func route_accident_chance() -> float:
	var modifier := int(state.world_facts.get("road_accident_modifier", 0))
	var style_modifier := -0.1 if travel_style == "绕行" else (0.1 if travel_style == "快速" else 0.0)
	return clampf(float(current_route_data().get("accident_chance", 0.0)) + modifier * 0.15 + style_modifier + (0.15 if state.vehicle_health < 40 else 0.0), 0.0, 0.95)

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
	return "%s · %s\n健康 %d / 疲劳 %d / 个人信任 %d\n记忆：%s" % [member.name, member.job, member.health, member.fatigue, member.trust, member.last_memory]

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
