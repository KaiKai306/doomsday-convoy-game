class_name DayLoop
extends RefCounted

## 一天 Demo 的规则层。UI 只调用这些方法，不直接修改资源或事件记录。

var state: GameState
var content: DemoContent
var route_choice: String = "安全路线"
var event_log: Array[String] = []
var daily_transactions: Array = []
var next_day_effects: Array[String] = []

func _init(game_state: GameState, demo_content: DemoContent) -> void:
	state = game_state
	content = demo_content

func start_new_game() -> void:
	state.reset(content.initial_resources(), content.initial_trust())
	route_choice = "安全路线"
	event_log.clear()
	daily_transactions = content.morning_transactions_for_day(state.day, state.world_facts)
	next_day_effects.clear()

func transaction_summary() -> String:
	if daily_transactions.is_empty():
		return "今日暂无 NPC 事务。"
	var lines: Array[String] = []
	for transaction in daily_transactions:
		lines.append("%s：%s（紧急度%s，截止%s）" % [
			transaction.get("speaker", "未知"),
			transaction.get("goal", "暂无目标"),
			transaction.get("urgency", "未知"),
			transaction.get("deadline", "未知")
		])
	return "\n".join(lines)

func choose_route(route_name: String) -> void:
	if route_name not in ["安全路线", "资源路线", "未知路线"]:
		return
	route_choice = route_name

func start_travel() -> void:
	_consume_resource("fuel", route_fuel_cost())
	_add_event("选择了%s" % route_choice)
	state.set_phase(GameState.Phase.TRAVEL)

func resolve_travel_event() -> void:
	var accident_modifier := int(state.world_facts.get("road_accident_modifier", 0))
	if accident_modifier < 0:
		_add_event("车辆维护生效，移动途中未发生道路事故")
	else:
		_add_event("移动途中发现道路事故，车辆暂时减速")
	state.set_phase(GameState.Phase.REST_STOP)

func resolve_dialogue(result: String, parts_cost: int, trust_change: int) -> void:
	_consume_resource("parts", parts_cost)
	state.adjust_trust(trust_change)
	_apply_dialogue_consequence(result)
	_add_event("对话结果：%s，信任 %+d" % [result, trust_change])
	state.set_phase(GameState.Phase.CAMP_ACTION)

func next_day_effects_text() -> String:
	if next_day_effects.is_empty():
		return "下一天暂无额外因果。"
	return "\n".join(next_day_effects)

func advance_to_next_day() -> void:
	state.advance_day()
	daily_transactions = content.morning_transactions_for_day(state.day, state.world_facts)
	next_day_effects.clear()
	state.set_phase(GameState.Phase.MORNING)

func perform_camp_action(action_name: String, parts_cost: int) -> void:
	_consume_resource("parts", parts_cost)
	_consume_resource("water", content.daily_cost("water"))
	_consume_resource("food", content.daily_cost("food"))
	_add_event("营地行动：%s" % action_name)
	state.set_phase(GameState.Phase.NIGHT_SETTLEMENT)

func route_fuel_cost() -> int:
	return content.route_fuel_cost(route_choice)

func resources_text() -> String:
	return "饮水 %d  食物 %d  燃料 %d  药品 %d  零件 %d  信任 %d" % [
		state.resources["water"], state.resources["food"], state.resources["fuel"],
		state.resources["medicine"], state.resources["parts"], state.team_trust
	]

func event_log_text() -> String:
	if event_log.is_empty():
		return "暂无"
	return "；".join(event_log)

func _consume_resource(resource_name: String, amount: int) -> void:
	if amount <= 0:
		return
	state.resources[resource_name] = max(0, int(state.resources.get(resource_name, 0)) - amount)

func _add_event(message: String) -> void:
	event_log.append(message)

func _apply_dialogue_consequence(result: String) -> void:
	match result:
		"接受请求":
			state.world_facts["repair_priority"] = "accepted"
			state.world_facts["road_accident_modifier"] = -1
			next_day_effects.append("维修员获得优先资源，下一天道路事故风险下降。")
		"拒绝请求":
			state.world_facts["repair_priority"] = "refused"
			state.world_facts["road_accident_modifier"] = 1
			next_day_effects.append("维修员的不满被记录，下一天道路事故风险上升。")
		"暂缓处理":
			state.world_facts["repair_priority"] = "deferred"
			state.world_facts["road_accident_modifier"] = 0
			next_day_effects.append("维修请求被延期，下一天仍可能再次出现。")
