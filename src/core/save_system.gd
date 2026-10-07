class_name SaveSystem
extends RefCounted

const SAVE_VERSION := 1
const SAVE_DIRECTORY := "user://saves"

func snapshot(state: GameState, loop: DayLoop) -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"day": state.day,
		"phase": int(state.phase),
		"resources": state.resources.duplicate(),
		"team_trust": state.team_trust,
		"world_facts": state.world_facts.duplicate(true),
		"route_choice": loop.route_choice,
		"event_log": loop.event_log.duplicate(),
		"daily_transactions": loop.daily_transactions.duplicate(true),
		"next_day_effects": loop.next_day_effects.duplicate(),
	}

func restore(snapshot_data: Dictionary, state: GameState, loop: DayLoop) -> bool:
	if int(snapshot_data.get("version", 0)) != SAVE_VERSION:
		return false
	if not snapshot_data.has("resources") or not snapshot_data.has("day"):
		return false

	var old_day := state.day
	var old_phase := state.phase
	state.day = max(1, int(snapshot_data.get("day", 1)))
	state.phase = clampi(int(snapshot_data.get("phase", GameState.Phase.MORNING)), 0, GameState.Phase.ENDING)
	state.resources = snapshot_data["resources"].duplicate()
	state.team_trust = clampi(int(snapshot_data.get("team_trust", 50)), 0, 100)
	state.world_facts = snapshot_data.get("world_facts", {}).duplicate(true)
	loop.route_choice = str(snapshot_data.get("route_choice", "安全路线"))
	loop.event_log = snapshot_data.get("event_log", []).duplicate()
	loop.daily_transactions = snapshot_data.get("daily_transactions", []).duplicate(true)
	loop.next_day_effects = snapshot_data.get("next_day_effects", []).duplicate()

	if old_day != state.day:
		state.day_changed.emit(state.day)
	if old_phase != state.phase:
		state.phase_changed.emit(state.phase)
	return true

func save_to_file(state: GameState, loop: DayLoop, slot: String = "slot_1") -> bool:
	var directory := DirAccess.open("user://")
	if directory == null:
		return false
	if directory.make_dir_recursive("saves") != OK and not DirAccess.dir_exists_absolute(SAVE_DIRECTORY):
		return false
	var file := FileAccess.open("%s/%s.json" % [SAVE_DIRECTORY, slot], FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(snapshot(state, loop)))
	return true

func load_from_file(slot: String = "slot_1") -> Dictionary:
	var file := FileAccess.open("%s/%s.json" % [SAVE_DIRECTORY, slot], FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}

