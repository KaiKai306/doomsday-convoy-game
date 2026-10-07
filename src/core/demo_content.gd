class_name DemoContent
extends RefCounted

const CONTENT_PATH := "res://data/demo_content.json"

var data: Dictionary = {}

func _init(content_path: String = CONTENT_PATH) -> void:
	var file := FileAccess.open(content_path, FileAccess.READ)
	if file == null:
		push_error("无法读取 Demo 数据：%s" % content_path)
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		data = parsed
	else:
		push_error("Demo 数据不是有效的 JSON 对象：%s" % content_path)

func initial_resources() -> Dictionary:
	return data.get("initial_resources", {}).duplicate()

func initial_trust() -> int:
	return int(data.get("initial_trust", 50))

func members() -> Array:
	return data.get("members", []).duplicate(true)

func vehicle() -> Dictionary:
	return data.get("vehicle", {}).duplicate(true)

func members_summary() -> String:
	var names: Array[String] = []
	for member in members():
		names.append(str(member.get("name", "未命名")))
	return "%d 人（%s）" % [names.size(), "、".join(names)]

func vehicle_summary() -> String:
	var current_vehicle := vehicle()
	return "%s，耐久 %d/%d" % [
		current_vehicle.get("name", "未命名车辆"),
		int(current_vehicle.get("durability", 0)),
		int(current_vehicle.get("max_durability", 0))
	]

func morning_transactions() -> Array:
	return data.get("morning_transactions", []).duplicate(true)

func route_fuel_cost(route_name: String) -> int:
	var route: Dictionary = data.get("routes", {}).get(route_name, {})
	return int(route.get("fuel_cost", 0))

func daily_cost(resource_name: String) -> int:
	return int(data.get("daily_costs", {}).get(resource_name, 0))
