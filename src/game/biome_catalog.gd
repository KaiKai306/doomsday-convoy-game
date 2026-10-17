extends RefCounted
## Read-only presentation: no resource, RNG, route or ending changes.
const BASE = preload("res://src/game/location_catalog.gd")
const FIXED = {
	"LOC-SP01":"checkpoint", "LOC-SP02":"repair_workshop", "LOC-SP03":"repair_workshop",
	"LOC-SP04":"repair_workshop", "LOC-SP05":"repair_workshop", "LOC-SP06":"repair_workshop",
	"LOC-SP07":"scrapyard", "LOC-SP08":"supply_warehouse", "LOC-SP09":"repair_workshop",
	"LOC-SP10":"rail_supply_station", "LOC-SP11":"communications_station", "LOC-SP12":"waterworks",
	"LOC-SP13":"supply_warehouse", "LOC-SP14":"supply_warehouse", "LOC-SP15":"library_archive"
}
const SOURCES = {
	"SRC01":"checkpoint", "SRC02":"repair_workshop", "SRC03":"repair_workshop", "SRC04":"repair_workshop",
	"SRC05":"scrapyard", "SRC06":"repair_workshop", "SRC07":"communications_station", "SRC08":"supply_warehouse",
	"SRC09":"waterworks", "SRC10":"supply_warehouse", "SRC11":"scrapyard", "SRC12":"communications_station",
	"SRC13":"repair_workshop", "SRC14":"repair_workshop", "SRC15":"library_archive"
}
const CARD_SITES = {"S05":"abandoned_school", "R05":"checkpoint", "N-F08":"checkpoint", "R06":"scrapyard", "N-F09":"supply_warehouse"}

static func region_for_day(day: int) -> String:
	if day <= 6: return "forest"
	if day <= 10: return "desert"
	if day <= 14: return "pine"
	return "snow"

static func region(s: Dictionary, preview: bool = false) -> String:
	var day = int(s.get("day",1)); var daily: Dictionary = s.get("daily",{})
	if preview: return region_for_day(day)
	if daily.get("travel_done",false) and daily.get("route","") != "stay" and float(daily.get("distance",0)) > 0:
		return region_for_day(day)
	# Legacy saves already contain actual travel summaries. A stationary
	# morning/stay retains that place until the next real journey.
	var last_day = 1
	for row in s.get("history",[]):
		for line in row.get("log",[]):
			if str(line).begins_with("行进 ") and not str(line).begins_with("行进 stay/"):
				last_day = maxi(last_day,int(row.get("day",1)))
			if "救援" in str(line) and int(row.get("day",0)) == 10 and s.get("sister","") in ["alive","rescued_pending","rescued_not_joined","safe_departed","rescued_dead"]:
				last_day = maxi(last_day,10)
	return region_for_day(last_day)

static func opening_available(s: Dictionary) -> bool:
	return int(s.get("day",1)) == 1 and s.get("phase","") in ["morning","route"] and not s.get("daily",{}).get("travel_done",false)

static func road(s: Dictionary, preview: bool = false) -> String:
	return region(s,preview)+"_road"

static func campsite(s: Dictionary) -> String:
	var terrain = region(s)
	return "snow_camp" if terrain == "snow" else terrain+"_camp"

static func fixed_site(id: String) -> String:
	return str(FIXED.get(id,""))

static func source_site(id: String, s: Dictionary) -> String:
	if id in ["SRC07","SRC12"] and region(s) == "snow": return "research_relay"
	return site_in_region(str(SOURCES.get(id,"")),s)

static func site_in_region(site: String, s: Dictionary) -> String:
	var terrain = region(s)
	var native = {"fuel_depot":"desert", "checkpoint":"forest", "scrapyard":"forest", "communications_station":"pine", "waterworks":"pine"}
	if native.has(site) and terrain != native[site]: return terrain+"_"+site
	return site

static func build_site(s: Dictionary) -> String:
	return "snow_habitable_ruins" if region(s) == "snow" else "habitable_ruins"

static func scene_for(s: Dictionary, view: String = "journey", active_card: String = "", context: Dictionary = {}) -> String:
	var phase = str(s.get("phase","morning")); var daily: Dictionary = s.get("daily",{})
	var legacy = BASE.resolve(s,view,active_card)
	if opening_available(s):
		return "gas_station_interior" if context.get("opening_inside",false) else "forest_gas_station"
	# Fixed destinations and completed actions have priority over stale events.
	if s.get("position","") == "废车点": return site_in_region("scrapyard",s)
	if s.get("intent","") == "E07" and daily.get("terminal_entered",false): return build_site(s)
	if legacy in ["settlement_reception","rescue_station_exterior","rescue_station_interior"]: return legacy
	if phase == "stop" and int(context.get("day",-1)) == int(s.get("day",1)) and int(context.get("legs",-1)) == int(s.get("legs",0)) and not BASE.config(str(context.get("site",""))).is_empty():
		return str(context.site)
	# Recruitment days retain their fixed destination even if a source is drawn.
	if phase == "stop" and daily.get("travel_done",false) and daily.get("route","") != "stay":
		if int(s.get("day",1)) == 4: return "forest_clinic"
		if int(s.get("day",1)) == 7: return "old_water_tower"
	if phase in ["event","stop"]:
		var card = str(daily.get("card","") if phase == "event" else daily.get("opportunity_card",""))
		# Opening a remote card preview is never physical arrival.
		if card in CARD_SITES: return site_in_region(str(CARD_SITES[card]),s)
		if phase == "stop" and not daily.get("source",{}).is_empty():
			var site = source_site(str(daily.source.get("id","")),s)
			if site != "": return site
	if phase == "camp_event" and str(daily.get("card","")) == "S05": return "abandoned_school"
	if legacy == "gas_station": return region(s)+"_gas_station" if region(s) != "desert" else legacy
	if legacy == "abandoned_clinic": return region(s)+"_clinic" if region(s) != "desert" else legacy
	if legacy in ["camp","snow_camp"]: return campsite(s)
	if legacy == "journey_road": return road(s,phase == "route")
	return legacy
