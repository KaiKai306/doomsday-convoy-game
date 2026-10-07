class_name DayLoop
extends RefCounted

## 一天 Demo 的规则层。UI 只调用这些方法，不直接修改资源或事件记录。

var state: GameState
var route_choice: String = "安全路线"
var event_log: Array[String] = []

func _init(game_state: GameState) -> void:
	state = game_state

func start_new_game() -> void:
	state.reset()
	route_choice = "安全路线"
	event_log.clear()

func choose_route(route_name: String) -> void:
	if route_name not in ["安全路线", "资源路线", "未知路线"]:
		return
	route_choice = route_name

func start_travel() -> void:
	_consume_resource("fuel", route_fuel_cost())
	_add_event("选择了%s" % route_choice)
	state.set_phase(GameState.Phase.TRAVEL)

func resolve_travel_event() -> void:
	_add_event("移动途中发现道路事故，车辆暂时减速")
	state.set_phase(GameState.Phase.REST_STOP)

func resolve_dialogue(result: String, parts_cost: int, trust_change: int) -> void:
	_consume_resource("parts", parts_cost)
	_add_event("对话结果：%s，信任 %+d" % [result, trust_change])
	state.set_phase(GameState.Phase.CAMP_ACTION)

func perform_camp_action(action_name: String, parts_cost: int) -> void:
	_consume_resource("parts", parts_cost)
	_consume_resource("water", 5)
	_consume_resource("food", 4)
	_add_event("营地行动：%s" % action_name)
	state.set_phase(GameState.Phase.NIGHT_SETTLEMENT)

func route_fuel_cost() -> int:
	match route_choice:
		"资源路线": return 6
		"未知路线": return 5
		_: return 4

func resources_text() -> String:
	return "饮水 %d  食物 %d  燃料 %d  药品 %d  零件 %d" % [
		state.resources["water"], state.resources["food"], state.resources["fuel"],
		state.resources["medicine"], state.resources["parts"]
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
