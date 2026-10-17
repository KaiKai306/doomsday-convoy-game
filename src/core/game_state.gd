class_name GameState
extends Node

## 第一阶段只保存跨场景的最小状态；具体规则会在垂直切片中逐步加入。

signal day_changed(day: int)
signal phase_changed(phase: Phase)

enum Phase {
	MORNING,
	ROUTE_SELECTION,
	TRAVEL,
	REST_STOP,
	CAMP_ACTION,
	NIGHT_SETTLEMENT,
	ENDING,
	MEMBER_AFFAIRS,
	TRAVEL_EVENT,
	STOP_DIALOGUE,
	MAJOR_ROUTE_SELECTION,
}

const DEFAULT_RESOURCES: Dictionary = {
	"water": 20,
	"food": 20,
	"fuel": 30,
	"medicine": 5,
	"parts": 10,
}

var day: int = 1
var phase: Phase = Phase.MORNING
var resources: Dictionary = DEFAULT_RESOURCES.duplicate()
var team_trust: int = 50
var world_facts: Dictionary = {}
var vehicle_health: int = 80
var fatigue: int = 10
var knowledge: int = 0
var tracking: int = 0
var ending: String = ""
var camp_position: float = 100.0
var members: Array = []
var major_route: String = ""
var route_history: Array = []

func reset(initial_resources: Dictionary = DEFAULT_RESOURCES, initial_trust: int = 50) -> void:
	day = 1
	phase = Phase.MORNING
	resources = initial_resources.duplicate()
	team_trust = clampi(initial_trust, 0, 100)
	world_facts.clear()
	vehicle_health = 80
	fatigue = 10
	knowledge = 0
	tracking = 0
	ending = ""
	camp_position = 100.0
	members.clear()
	major_route = ""
	route_history.clear()

func initialize_members(initial: Array, trust: int = 50, initial_fatigue: int = 10) -> void:
	members = initial.duplicate(true)
	for member in members:
		member["health"] = int(member.get("health", 100))
		member["fatigue"] = int(member.get("fatigue", initial_fatigue))
		member["trust"] = int(member.get("trust", trust))
		member["last_memory"] = str(member.get("last_memory", "尚未留下对话记录。"))

func member_named(member_name: String) -> Dictionary:
	for member in members:
		if member.name == member_name: return member
	return {}

func adjust_member(member_name: String, health_change: int = 0, fatigue_change: int = 0, trust_change: int = 0) -> void:
	var member := member_named(member_name)
	if member.is_empty(): return
	member.health = clampi(int(member.health) + health_change, 0, 100)
	member.fatigue = clampi(int(member.fatigue) + fatigue_change, 0, 100)
	member.trust = clampi(int(member.trust) + trust_change, 0, 100)
	if fatigue_change != 0: sync_fatigue()

func adjust_all_fatigue(amount: int) -> void:
	for member in members:
		member.fatigue = clampi(int(member.fatigue) + amount, 0, 100)
	sync_fatigue()

func sync_fatigue() -> void:
	if members.is_empty(): return
	var total := 0
	for member in members: total += int(member.fatigue)
	fatigue = roundi(float(total) / members.size())

func adjust_trust(amount: int) -> void:
	team_trust = clampi(team_trust + amount, 0, 100)

func set_phase(next_phase: Phase) -> void:
	if phase == next_phase:
		return
	phase = next_phase
	phase_changed.emit(phase)

func advance_day() -> void:
	day += 1
	day_changed.emit(day)
