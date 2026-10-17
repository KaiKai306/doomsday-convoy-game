class_name DemoContent
extends RefCounted

const CONTENT_PATH := "res://data/demo_content.json"
const RESOURCE_NAMES := {"water": "饮水", "food": "食物", "fuel": "燃料", "medicine": "药品", "parts": "零件"}
var data: Dictionary = {}

func _init(content_path: String = CONTENT_PATH) -> void:
	var file := FileAccess.open(content_path, FileAccess.READ)
	if file == null:
		push_error("无法读取内容：%s" % content_path)
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary: data = parsed
	else: push_error("内容不是有效 JSON：%s" % content_path)

func initial_resources() -> Dictionary:
	return data.get("initial_resources", {}).duplicate()

func initial_trust() -> int:
	return int(data.get("initial_trust", 50))

func members() -> Array:
	return data.get("members", []).duplicate(true)

func camp_data() -> Dictionary:
	return data.get("camp", {})

func camp_members() -> Array:
	return camp_data().get("members", [])

func member_position(speaker: String) -> float:
	for member in camp_members():
		if member.name == speaker: return float(member.x)
	return -1.0

func vehicle() -> Dictionary:
	return data.get("vehicle", {}).duplicate(true)

func members_summary() -> String:
	var names: Array[String] = []
	for member in members(): names.append(str(member.name))
	return "%d 人 · %s" % [names.size(), " / ".join(names)]

func vehicle_summary() -> String:
	return str(vehicle().get("name", "车辆"))

func transaction(key: String) -> Dictionary:
	return data.get("transactions", {}).get(key, {}).duplicate(true)

func morning_transactions_for_day(day: int, world_facts: Dictionary) -> Array:
	var repair_key := "repair"
	if day > 1:
		match str(world_facts.get("repair_priority", "defer")):
			"accept": repair_key = "follow"
			"refuse": repair_key = "conflict"
	var scout_key := "map" if world_facts.get("route_intel", "") == "accept" else "scout"
	return [transaction(repair_key), transaction("medical"), transaction(scout_key), transaction("water"), transaction("captain")]

func is_major_route_day(day: int) -> bool:
	return day in [2, 5, 8, 10]

func major_routes() -> Dictionary:
	return data.get("major_routes", {})

func major_route_data(route_name: String) -> Dictionary:
	return major_routes().get(route_name, {})

func major_checkpoint(day: int, route_name: String) -> String:
	var checkpoints: Array = major_route_data(route_name).get("checkpoints", [])
	var index := [2, 5, 8, 10].find(day)
	return str(checkpoints[index]) if index >= 0 and index < checkpoints.size() else ""

func routes() -> Dictionary:
	return data.get("routes", {})

func route_data(route_name: String) -> Dictionary:
	return routes().get(route_name, {})

func route_fuel_cost(route_name: String) -> int:
	return int(route_data(route_name).get("fuel_cost", 0))

func route_accident_chance(route_name: String) -> float:
	return float(route_data(route_name).get("accident_chance", 0.0))

func daily_cost(resource_name: String) -> int:
	return int(data.get("daily_costs", {}).get(resource_name, 0))

func camp_actions() -> Dictionary:
	return data.get("camp_actions", {})

func stop_event(day: int) -> Dictionary:
	var events: Array = data.get("stop_events", [])
	return events[clampi(day - 1, 0, events.size() - 1)] if not events.is_empty() else {}

func available_camp_actions(day: int) -> Dictionary:
	var result := camp_actions().duplicate(true)
	for action_name in stop_event(day).get("actions", {}):
		result[action_name] = stop_event(day).actions[action_name].duplicate(true)
	return result

func demo_days() -> int:
	return int(data.get("demo_days", 10))

func stop_name(day: int) -> String:
	var stops: Array = data.get("stops", ["临时营地"])
	return str(stops[clampi(day - 1, 0, stops.size() - 1)])

func cost_text(cost: Dictionary, gains: bool = false) -> String:
	var parts: Array[String] = []
	for key in cost:
		parts.append("%s %s%d" % [RESOURCE_NAMES.get(key, key), "+" if gains else "-", int(cost[key])])
	return " / ".join(parts) if not parts.is_empty() else "无物资消耗"

func ending_text(ending: String) -> String:
	if ending == "燃料耗尽": return "最后一滴燃料用尽，而下一处补给还在远方。车队停在了路边。"
	return str(data.get("endings", {}).get(ending, "这段旅程结束了。"))
