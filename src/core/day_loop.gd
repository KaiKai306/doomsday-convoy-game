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

func _init(game_state: GameState, demo_content: DemoContent) -> void:
	state = game_state
	content = demo_content

func start_new_game() -> void:
	state.reset(content.initial_resources(), content.initial_trust())
	state.vehicle_health = int(content.vehicle().get("durability", 80))
	route_choice = "安全路线"
	travel_style = "低噪音"
	event_log.clear()
	next_day_effects.clear()
	_begin_morning()

func _begin_morning() -> void:
	prepared = false
	transaction_index = 0
	travel_progress = 0.0
	travel_resolved = false
	daily_transactions = content.morning_transactions_for_day(state.day, state.world_facts)
	if int(state.resources.water) < content.daily_cost("water") * 2:
		daily_transactions.push_front(content.transaction("water"))
	elif state.fatigue >= 35:
		daily_transactions.push_front(content.transaction("medical"))
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
			state.fatigue = maxi(0, state.fatigue - 8)
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
	var noise := 12 if travel_style == "快速" else (2 if travel_style == "低噪音" else 5)
	state.tracking = clampi(state.tracking + noise - 4, 0, 100)
	state.fatigue = mini(100, state.fatigue + (6 if travel_style == "快速" else 10))
	if state.tracking >= 25:
		state.vehicle_health = maxi(0, state.vehicle_health - 8)
		state.tracking = maxi(0, state.tracking - 10)
		_add_event("发动机噪音积累 → 异变兽追上车队，耐久 -8，追踪 -10")
	var gains: Dictionary = content.route_data(route_choice).get("supplies", {})
	for key in gains: state.resources[key] = int(state.resources.get(key, 0)) + int(gains[key])
	var route_knowledge := int(content.route_data(route_choice).get("knowledge", 0))
	state.knowledge += route_knowledge
	if route_knowledge > 0: _add_event("发现旧路线档案 → 知识 +%d" % route_knowledge)
	_add_event("抵达%s → 补给 %s" % [content.stop_name(state.day), content.cost_text(gains, true)])
	state.set_phase(GameState.Phase.REST_STOP)
	return accident

func current_transaction() -> Dictionary:
	return daily_transactions[transaction_index] if transaction_index < daily_transactions.size() else {}

func respond(response: String) -> bool:
	if state.phase != GameState.Phase.REST_STOP or response not in ["accept", "refuse", "defer"]: return false
	var transaction := current_transaction()
	if transaction.is_empty(): return false
	var option: Dictionary = transaction.get("responses", {}).get(response, {})
	if option.is_empty() or not _pay(option.get("cost", {})): return false
	state.adjust_trust(int(option.get("trust", 0)))
	state.vehicle_health = clampi(state.vehicle_health + int(option.get("repair", 0)), 0, 100)
	state.knowledge += int(option.get("knowledge", 0))
	state.fatigue = clampi(state.fatigue + int(option.get("fatigue", 0)), 0, 100)
	var fact_key: String = transaction.get("fact", "")
	if not fact_key.is_empty(): state.world_facts[fact_key] = response
	if fact_key == "repair_priority":
		state.world_facts["road_accident_modifier"] = -1 if response == "accept" else (1 if response == "refuse" else 0)
	_add_event("%s · %s → %s" % [transaction.speaker, option.get("label", response), option.get("effect", "")])
	next_day_effects.append(str(option.get("future", "本次回应已记录。")))
	transaction["resolution"] = response
	transaction_index += 1
	if transaction_index >= daily_transactions.size(): state.set_phase(GameState.Phase.CAMP_ACTION)
	return true

func perform_camp_action(action_name: String) -> bool:
	if state.phase != GameState.Phase.CAMP_ACTION: return false
	var action: Dictionary = content.camp_actions().get(action_name, {})
	if action.is_empty(): return false
	if action.get("requires_manual", false) and not state.world_facts.get("manual_read", false):
		last_error = "需要先阅读技术手册。"
		return false
	if not _pay(action.get("cost", {})): return false
	state.vehicle_health = mini(100, state.vehicle_health + int(action.get("repair", 0)))
	state.fatigue = maxi(0, state.fatigue + int(action.get("fatigue", 0)))
	state.knowledge += int(action.get("knowledge", 0))
	state.adjust_trust(int(action.get("trust", 0)))
	if action_name == "阅读技术手册": state.world_facts["manual_read"] = true
	if action_name == "教学与记录":
		state.world_facts["lessons"] = int(state.world_facts.get("lessons", 0)) + 1
		if int(state.world_facts.lessons) >= 2 and not state.world_facts.get("shared_maintenance", false):
			state.world_facts["shared_maintenance"] = true
			_add_event("两次共同教学与记录 → 共同维护习惯形成，今后每天耐久 +3")
	_add_event("营地 · %s → %s" % [action_name, action.get("effect", "")])
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

func _pay(cost: Dictionary) -> bool:
	last_error = ""
	if not can_afford(cost):
		last_error = "物资不足，无法执行。"
		return false
	for key in cost: state.resources[key] = int(state.resources[key]) - int(cost[key])
	return true

func _add_event(message: String) -> void:
	event_log.append(message)
