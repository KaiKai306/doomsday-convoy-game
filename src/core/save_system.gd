class_name SaveSystem
extends RefCounted

const SAVE_VERSION := 3
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
		"members": state.members.duplicate(true),
		"major_route": state.major_route, "route_history": state.route_history.duplicate(true),
		"morning_resolutions": loop.morning_resolutions.duplicate(true), "travel_event_text": loop.travel_event_text,
	}

func restore(saved: Dictionary, state: GameState, loop: DayLoop) -> bool:
	var legacy_morning: bool = saved.get("version") == 2 and saved.get("phase") == GameState.Phase.MORNING
	saved = _migrate(saved)
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
	if saved.has("members"):
		state.members = saved.members.duplicate(true)
		for member in state.members:
			for key in ["health", "fatigue", "trust"]: member[key] = int(member[key])
	else:
		state.initialize_members(loop.content.members())
		for member in state.members:
			member.fatigue = state.fatigue
			member.trust = state.team_trust
	state.major_route = str(saved.get("major_route", ""))
	state.route_history = saved.get("route_history", []).duplicate(true)
	loop.morning_resolutions = saved.get("morning_resolutions", []).duplicate(true)
	loop.travel_event_text = str(saved.get("travel_event_text", ""))
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
	if legacy_morning:
		# Old mornings contain only 2–3 requests; rebuild the current five-member queue.
		loop._begin_morning()
		loop.prepared = bool(saved.prepared)
	state.day_changed.emit(state.day)
	state.phase_changed.emit(state.phase)
	return true

func _migrate(source: Dictionary) -> Dictionary:
	if source.get("version") != 2: return source
	var saved := source.duplicate(true)
	var rename := {"队长": "主角", "老赵": "老张", "许宁": "艾琳", "阿遥": "阿杰", "周禾": "索菲亚"}
	if saved.get("members") is Array:
		for member in saved.members:
			if member is Dictionary and member.get("name") is String:
				member.name = rename.get(member.name, member.name)
	if saved.get("daily_transactions") is Array:
		for transaction in saved.daily_transactions:
			if not transaction is Dictionary: continue
			for key in ["speaker", "target_member"]:
				if transaction.get(key) is String: transaction[key] = rename.get(transaction[key], transaction[key])
	if saved.get("phase") == GameState.Phase.REST_STOP:
		saved.phase = GameState.Phase.STOP_DIALOGUE
	if saved.get("phase") == GameState.Phase.TRAVEL and saved.get("travel_progress") is float and saved.get("travel_resolved") is bool:
		# The old loop could resolve an event immediately after departure.
		if saved.travel_resolved: saved.travel_progress = maxf(0.5, saved.travel_progress)
	# An old route/travel save on a big-route day has already departed into the old demo.
	# Assign a default direction for that segment, allowing later checkpoints to change it.
	saved["major_route"] = "南部断路"
	saved["route_history"] = []
	saved["morning_resolutions"] = []
	saved["travel_event_text"] = ""
	if saved.get("world_facts") is Dictionary:
		saved.world_facts["story_direction"] = "南部断路"
		saved.world_facts["story_checkpoint"] = "旧版旅程延续"
	saved.version = SAVE_VERSION
	return saved

func _valid(saved: Dictionary, content: DemoContent) -> bool:
	if saved.get("version") != SAVE_VERSION: return false
	if not _number(saved.get("day"), 1, content.demo_days()): return false
	for key in ["resources", "world_facts"]:
		if not saved.get(key) is Dictionary: return false
	for key in ["event_log", "daily_transactions", "next_day_effects", "morning_resolutions", "route_history"]:
		if not saved.get(key) is Array: return false
	for key in ["event_log", "next_day_effects"]:
		for entry in saved[key]:
			if not entry is String: return false
	for key in ["route_choice", "travel_style", "ending", "random_state"]:
		if not saved.get(key) is String: return false
	if not saved.get("major_route") is String or not saved.get("travel_event_text") is String: return false
	if not str(saved.major_route).is_empty() and not content.major_routes().has(saved.major_route): return false
	var previous_day := 0
	for entry in saved.route_history:
		if not entry is Dictionary or not _number(entry.get("day"), 1, int(saved.get("day", 0))): return false
		if not content.is_major_route_day(int(entry.day)) or int(entry.day) <= previous_day: return false
		if not entry.get("route") is String or not content.major_routes().has(entry.route): return false
		if not entry.get("chapter") is String or entry.chapter != content.major_checkpoint(int(entry.day), entry.route): return false
		previous_day = int(entry.day)
	if not str(saved.random_state).is_valid_int(): return false
	if not content.routes().has(saved.route_choice): return false
	if saved.travel_style not in ["低噪音", "快速", "绕行"]: return false
	if not saved.get("prepared") is bool or not saved.get("travel_resolved") is bool: return false
	for key in DemoContent.RESOURCE_NAMES:
		if not _number(saved.resources.get(key), 0, 100000): return false
	for key in ["team_trust", "vehicle_health", "fatigue", "tracking"]:
		if not _number(saved.get(key), 0, 100): return false
	if not _number(saved.get("day"), 1, content.demo_days()): return false
	if not _number(saved.get("phase"), 0, GameState.Phase.MAJOR_ROUTE_SELECTION): return false
	if not _number(saved.get("knowledge"), 0, 100000): return false
	if not _number(saved.get("travel_progress"), 0, 1, false): return false
	if not _number(saved.get("camp_position", content.camp_data().get("entry_position", 100.0)), 45.0, float(content.camp_data().get("width", 1440.0)) - 45.0, false): return false
	if not saved.get("conversation_open", false) is bool: return false
	if saved.has("members"):
		if not saved.members is Array or saved.members.size() != content.members().size(): return false
		var expected: Array[String] = []
		for initial in content.members(): expected.append(str(initial.name))
		for member in saved.members:
			if not member is Dictionary: return false
			if not member.get("name") is String or str(member.name) not in expected: return false
			expected.erase(str(member.name))
			if not member.get("job") is String or not member.get("last_memory") is String: return false
			for key in ["health", "fatigue", "trust"]:
				if not _number(member.get(key), 0, 100): return false
	if not _number(saved.get("transaction_index"), 0, saved.daily_transactions.size()): return false
	for transaction in saved.daily_transactions + saved.morning_resolutions:
		if not transaction is Dictionary: return false
		for key in ["id", "speaker", "job", "goal", "urgency", "body", "fact"]:
			if not transaction.get(key) is String: return false
		var valid_speaker := false
		for member in content.members():
			if member.name == transaction.speaker: valid_speaker = true
		if not valid_speaker: return false
		if transaction.has("target_member"):
			if not transaction.target_member is String: return false
			var valid_target := false
			for member in content.members():
				if member.name == transaction.target_member: valid_target = true
			if not valid_target: return false
		if not transaction.get("responses") is Dictionary: return false
		for choice in ["accept", "refuse", "defer"]:
			var option = transaction.responses.get(choice)
			if not option is Dictionary or not option.get("cost") is Dictionary: return false
			for key in ["label", "effect", "future"]:
				if not option.get(key) is String: return false
			for key in option.cost:
				if not DemoContent.RESOURCE_NAMES.has(key) or not _number(option.cost[key], 0, 10000): return false
			for key in ["trust", "repair", "knowledge", "fatigue", "health"]:
				if not _number(option.get(key, 0), -100, 100): return false
	if int(saved.phase) in [GameState.Phase.MEMBER_AFFAIRS, GameState.Phase.STOP_DIALOGUE] and int(saved.transaction_index) >= saved.daily_transactions.size(): return false
	if int(saved.phase) == GameState.Phase.MAJOR_ROUTE_SELECTION and not content.is_major_route_day(int(saved.day)): return false
	if int(saved.phase) == GameState.Phase.TRAVEL and saved.travel_resolved and float(saved.travel_progress) < 0.5: return false
	if int(saved.phase) == GameState.Phase.TRAVEL_EVENT and not is_equal_approx(float(saved.travel_progress), 0.5): return false
	if int(saved.phase) == GameState.Phase.MEMBER_AFFAIRS and not saved.get("conversation_open", false): return false
	if content.is_major_route_day(int(saved.day)) and int(saved.phase) != GameState.Phase.MAJOR_ROUTE_SELECTION and str(saved.major_route).is_empty(): return false
	if int(saved.phase) == GameState.Phase.ENDING and str(saved.ending).is_empty(): return false
	if saved.get("conversation_open", false):
		if int(saved.phase) not in [GameState.Phase.MEMBER_AFFAIRS, GameState.Phase.STOP_DIALOGUE]: return false
		var current: Dictionary = saved.daily_transactions[int(saved.transaction_index)]
		var target := content.member_position(str(current.speaker))
		if int(saved.phase) == GameState.Phase.STOP_DIALOGUE and current.speaker != "主角" and (target < 0.0 or absf(float(saved.get("camp_position", 100.0)) - target) > float(content.camp_data().get("interaction_range", 72.0))): return false
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
