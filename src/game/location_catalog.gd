extends RefCounted
## Presentation only: actual arrivals and active encounters select the art.
const ART_SIZE = Vector2(2688,1152)
const EXISTING = preload("res://data/final/location_walks.json")

static func resolve(s: Dictionary, view: String = "journey", active_card: String = "") -> String:
	var phase = str(s.get("phase","morning"))
	var daily: Dictionary = s.get("daily",{})
	var facts: Dictionary = s.get("facts",{})
	var position = str(s.get("position",""))
	var day = int(s.get("day",1))
	# An immediate road failure retains its actual site. Night-time endings
	# still use the campsite where the final ration check took place.
	if phase == "ending" and not daily.get("night_done",false):
		if daily.get("card","") == "N-C04": return "tunnel_entrance"
		if not daily.get("camp_used",false):
			phase = "stop" if daily.get("travel_done",false) else "route"
	# Selecting a branch is explicitly labelled as a preview by the main UI.
	if phase == "route" and daily.get("map_choice","") == "sealed_tunnel": return "tunnel_entrance"
	# The paid day-eight scout visits the entrance, not the rescue room.
	if day == 8 and phase == "route" and s.get("south_pledge",false) and "entrance" in s.get("clues",[]): return "rescue_station_exterior"
	if phase == "rescue":
		return "rescue_station_exterior" if rescue_site_reached(s) else "journey_road"
	if phase == "rescue_seats": return "rescue_station_interior"
	# Position changes only on an actual visit/terminal action; goal tabs and
	# remote faction contacts never count as arrival.
	if position == "商会登记处": return "neutral_market"
	if position in ["避难点","南边正式定居区"]: return "settlement_reception"
	if position == "已抵达目标" and daily.get("terminal_entered",false) and s.get("intent","") in ["E03","E08","E11"]: return "settlement_reception"
	if phase == "event":
		if daily.get("card","") == "N-C04": return "tunnel_entrance"
		return "journey_road"
	if phase == "stop":
		if day == 10 and daily.get("travel_done",false):
			if str(s.get("sister","")) in ["alive","rescued_pending","rescued_not_joined","safe_departed"]: return "rescue_station_interior"
			if s.get("sister","") == "confirmed_dead" and facts.get("rescue_site_confirmed",false): return "rescue_station_exterior"
		var card = str(daily.get("opportunity_card",""))
		if card in ["R01","N-F09"]: return "neutral_market"
		if card == "R03": return "gas_station"
		if card == "R04": return "abandoned_clinic"
		if "加油站" in str(daily.get("source",{}).get("name","")): return "gas_station"
		if daily.get("travel_done",false) and daily.get("route","") != "stay":
			if day == 4: return "abandoned_clinic"
			if day == 7: return "old_water_tower"
		return "gas_station" if day == 1 and float(s.get("distance",0)) == 0 else "journey_road"
	# The user's opening location also applies to every preparation tab and to
	# route planning before the first departure. A card preview is not travel.
	if day == 1 and phase in ["morning","route"] and not daily.get("travel_done",false): return "gas_station"
	if phase == "route": return "journey_road"
	if phase in ["camp","camp_event","morning","night","split","ending"]:
		if view in ["knowledge","inventory","team"]: return "camp_interior"
		return "snow_camp" if northern_camp(s) else "camp"
	return "journey_road"

static func rescue_site_reached(s: Dictionary) -> bool:
	# Same physical-arrival requirements as the onsite inspection command;
	# supplies/skills may still be insufficient after reaching the exterior.
	var has_car = s.get("vehicles",[]).any(func(v): return not v.get("destroyed",false) and float(v.get("durability",0)) > 0)
	return int(s.get("legs",0)) >= 6 and s.get("clues",[]).size() >= 3 and has_car

static func northern_camp(s: Dictionary) -> bool:
	var day = int(s.get("day",1)); var facts: Dictionary = s.get("facts",{})
	var chosen = int(facts.get("direction_day",-10))
	if facts.get("direction","") != "north" or day <= chosen or day > chosen+2: return false
	var daily: Dictionary = s.get("daily",{})
	if daily.get("travel_done",false) and daily.get("route","") != "stay": return true
	# A following morning retains the previous night's northern campsite.
	# Legacy saves contain travel summaries in history, but no art-site field.
	for row in s.get("history",[]):
		if int(row.get("day",0)) != day-1 or int(row.day) <= chosen: continue
		for line in row.get("log",[]):
			if str(line).begins_with("行进 ") and not str(line).begins_with("行进 stay/"): return true
	return false

static func config(id: String) -> Dictionary:
	var extra_path = "res://assets/locations/biomes_20261016/manifest.json"
	if FileAccess.file_exists(extra_path):
		var extra = JSON.parse_string(FileAccess.get_file_as_string(extra_path))
		if extra is Dictionary and extra.get("locations",{}).has(id): return extra.locations[id].duplicate(true)
	var known: Dictionary = EXISTING.data
	if known.has(id): return known[id].duplicate(true)
	var path = "res://assets/locations/%s/manifest.json" % id
	if not FileAccess.file_exists(path): return {}
	return JSON.parse_string(FileAccess.get_file_as_string(path))

static func scene_path(id: String) -> String:
	return "res://scenes/camp_three_parallax.tscn" if id == "camp" else "res://scenes/%s_parallax.tscn" % id

static func foot_at(path: Array, x: float) -> Vector2:
	if path.is_empty(): return Vector2.ZERO
	var value = clampf(x,float(path[0][0]),float(path[-1][0]))
	for i in range(1,path.size()):
		var a = Vector2(path[i-1][0],path[i-1][1]); var b = Vector2(path[i][0],path[i][1])
		if value <= b.x: return a.lerp(b,(value-a.x)/(b.x-a.x))
	return Vector2(path[-1][0],path[-1][1])
