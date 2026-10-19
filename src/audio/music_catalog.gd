extends RefCounted
## Read-only music selection. Playback and user volume belong to the director.
const CATALOG = preload("res://data/music_catalog.json")
const BIOMES = preload("res://src/game/biome_catalog.gd")

static func cue_for(location: String, state: Dictionary, view: String = "journey", active_card: String = "") -> String:
	var data: Dictionary = CATALOG.data
	var phase = str(state.get("phase", ""))
	if phase == "ending": return str(data.endings.get(str(state.get("ending", "")), "ending_tragic"))
	if location == "main_menu": return "main_menu"
	if view in data.planning_views or view == "journey" and phase == "route":
		return "morning_planning"
	if view == "card" or phase in ["event", "camp_event"]:
		var card = active_card if view == "card" and active_card != "" else str(state.get("daily", {}).get("card", ""))
		if data.event_cards.has(card): return str(data.event_cards[card])
	if phase == "night": return "endofday_check"
	var cue = str(data.locations.get(location, "@road"))
	if cue == "@camp":
		return str(data.region_camps.get(_region_for(location, state), "camp_forest"))
	if cue == "@road":
		cue = str(data.region_roads.get(_region_for(location, state), "road_lowland_forest"))
	if cue in data.region_roads.values():
		# Day nine's fixed recruitment is the actual supply stop, even when its
		# shared road illustration has no dedicated supply-site identifier.
		var daily: Dictionary = state.get("daily", {})
		if int(state.get("day", 1)) == 9 and phase == "stop" and daily.get("travel_done", false) and daily.get("route", "") != "stay":
			return "supply_stop"
		if _on_foot(state): return "on_foot_survival"
	return cue

static func playlist(cue: String) -> Array:
	var data: Dictionary = CATALOG.data
	if data.cues.has(cue): return data.cues[cue].duplicate()
	return [cue] if data.tracks.has(cue) else []

static func track(id: String) -> Dictionary:
	var data: Dictionary = CATALOG.data
	return data.tracks.get(id, {}).duplicate(true)

static func all_tracks() -> Dictionary:
	return CATALOG.data.tracks.duplicate(true)

static func _region_for(location: String, state: Dictionary) -> String:
	for region in ["forest", "desert", "pine", "snow"]:
		if location.begins_with(region + "_"): return region
	# Matches the art's actual arrivals, including a morning/stay at yesterday's site.
	return BIOMES.region(state)

static func _on_foot(state: Dictionary) -> bool:
	# Matches rules.gd cars()/on_foot(): wrecks can remain in the vehicles array.
	# A partial presentation state without vehicle data makes no travel claim.
	if not state.has("vehicles"): return false
	for vehicle in state.vehicles:
		if not vehicle.get("destroyed", false) and float(vehicle.get("durability", 0)) > 0: return false
	return true
