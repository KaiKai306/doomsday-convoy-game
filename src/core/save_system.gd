class_name SaveSystem
extends RefCounted

const SAVE_VERSION := 2
const SAVE_DIRECTORY := "user://saves"
var save_directory: String

func _init(directory: String = SAVE_DIRECTORY) -> void:
	save_directory = directory

func snapshot(state: GameState, loop: DayLoop) -> Dictionary:
	return {
		"version": SAVE_VERSION, "day": state.day, "phase": int(state.phase),
		"resources": state.resources.duplicate(), "team_trust": state.team_trust,
		"world_facts": state.world_facts.duplicate(true),
		"vehicle_health": state.vehicle_health, "fatigue": state.fatigue,
		"knowledge": state.knowledge, "tracking": state.tracking, "ending": state.ending,
		"route_choice": loop.route_choice, "travel_style": loop.travel_style,
		"event_log": loop.event_log.duplicate(), "daily_transactions": loop.daily_transactions.duplicate(true),
		"next_day_effects": loop.next_day_effects.duplicate(),
		"transaction_index": loop.transaction_index, "prepared": loop.prepared,
		"travel_progress": loop.travel_progress, "travel_resolved": loop.travel_resolved,
		"random_state": str(loop.random.state),
		"camp_position": state.camp_position, "conversation_open": loop.conversation_open,
	}

func restore(saved: Dictionary, state: GameState, loop: DayLoop) -> bool:
	# Validate the entire payload before mutating the active run.
	if not _valid(saved, loop.content): return false
	state.day = int(saved.day)
	state.phase = int(saved.phase)
	state.resources = saved.resources.duplicate()
	state.team_trust = int(saved.team_trust)
	state.world_facts = saved.world_facts.duplicate(true)
	state.vehicle_health = int(saved.vehicle_health)
	state.fatigue = int(saved.fatigue)
	state.knowledge = int(saved.knowledge)
	state.tracking = int(saved.tracking)
	state.ending = str(saved.ending)
	state.camp_position = float(saved.get("camp_position", loop.content.camp_data().get("entry_position", 100.0)))
	loop.route_choice = str(saved.route_choice)
	loop.travel_style = str(saved.travel_style)
	loop.event_log.assign(saved.event_log)
	loop.daily_transactions = saved.daily_transactions.duplicate(true)
	loop.next_day_effects.assign(saved.next_day_effects)
	loop.transaction_index = int(saved.transaction_index)
	loop.prepared = bool(saved.prepared)
	loop.travel_progress = float(saved.travel_progress)
	loop.travel_resolved = bool(saved.travel_resolved)
	loop.random.state = int(saved.random_state)
	loop.conversation_open = bool(saved.get("conversation_open", false))
	state.day_changed.emit(state.day)
	state.phase_changed.emit(state.phase)
	return true

func _valid(saved: Dictionary, content: DemoContent) -> bool:
	if saved.get("version") != SAVE_VERSION: return false
	for key in ["resources", "world_facts"]:
		if not saved.get(key) is Dictionary: return false
	for key in ["event_log", "daily_transactions", "next_day_effects"]:
		if not saved.get(key) is Array: return false
	for key in ["event_log", "next_day_effects"]:
		for entry in saved[key]:
			if not entry is String: return false
	for key in ["route_choice", "travel_style", "ending", "random_state"]:
		if not saved.get(key) is String: return false
	if not str(saved.random_state).is_valid_int(): return false
	if not content.routes().has(saved.route_choice): return false
	if saved.travel_style not in ["低噪音", "快速", "绕行"]: return false
	if not saved.get("prepared") is bool or not saved.get("travel_resolved") is bool: return false
	for key in DemoContent.RESOURCE_NAMES:
		if not _number(saved.resources.get(key), 0, 100000): return false
	for key in ["team_trust", "vehicle_health", "fatigue", "tracking"]:
		if not _number(saved.get(key), 0, 100): return false
	if not _number(saved.get("day"), 1, content.demo_days()): return false
	if not _number(saved.get("phase"), 0, GameState.Phase.ENDING): return false
	if not _number(saved.get("knowledge"), 0, 100000): return false
	if not _number(saved.get("travel_progress"), 0, 1, false): return false
	if not _number(saved.get("camp_position", content.camp_data().get("entry_position", 100.0)), 45.0, float(content.camp_data().get("width", 1440.0)) - 45.0, false): return false
	if not saved.get("conversation_open", false) is bool: return false
	if not _number(saved.get("transaction_index"), 0, saved.daily_transactions.size()): return false
	for transaction in saved.daily_transactions:
		if not transaction is Dictionary: return false
		for key in ["id", "speaker", "job", "goal", "urgency", "body", "fact"]:
			if not transaction.get(key) is String: return false
		if not transaction.get("responses") is Dictionary: return false
		for choice in ["accept", "refuse", "defer"]:
			var option = transaction.responses.get(choice)
			if not option is Dictionary or not option.get("cost") is Dictionary: return false
			for key in ["label", "effect", "future"]:
				if not option.get(key) is String: return false
			for key in option.cost:
				if not DemoContent.RESOURCE_NAMES.has(key) or not _number(option.cost[key], 0, 10000): return false
	if int(saved.phase) == GameState.Phase.REST_STOP and int(saved.transaction_index) >= saved.daily_transactions.size(): return false
	if int(saved.phase) == GameState.Phase.TRAVEL and saved.travel_resolved: return false
	if int(saved.phase) == GameState.Phase.ENDING and str(saved.ending).is_empty(): return false
	if saved.get("conversation_open", false):
		if int(saved.phase) != GameState.Phase.REST_STOP: return false
		var current: Dictionary = saved.daily_transactions[int(saved.transaction_index)]
		var target := content.member_position(str(current.speaker))
		if target < 0.0 or absf(float(saved.get("camp_position", 100.0)) - target) > float(content.camp_data().get("interaction_range", 72.0)): return false
	return true

func _number(value: Variant, low: float, high: float, integer: bool = true) -> bool:
	if not (value is int or value is float): return false
	return is_finite(float(value)) and float(value) >= low and float(value) <= high and (not integer or float(value) == floor(float(value)))

func save_to_file(state: GameState, loop: DayLoop, slot: String = "slot_1") -> bool:
	if not slot.is_valid_identifier(): return false
	if DirAccess.make_dir_recursive_absolute(save_directory) != OK: return false
	var path := "%s/%s.json" % [save_directory, slot]
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(snapshot(state, loop)))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK: return false
	return DirAccess.rename_absolute(temporary, path) == OK

func load_from_file(slot: String = "slot_1") -> Dictionary:
	if not slot.is_valid_identifier(): return {}
	var file := FileAccess.open("%s/%s.json" % [save_directory, slot], FileAccess.READ)
	if file == null: return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}
