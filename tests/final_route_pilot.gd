extends RefCounted
var commands = []
func cmd(r,action:String,args:Dictionary = {}) -> bool:
	var day = r.s.day; var phase = r.s.phase
	var ok = r.command(action,args)
	if ok: commands.append({"day":day,"phase":phase,"action":action,"args":args.duplicate(true)})
	return ok

func trim_cargo(r) -> bool:
	if r.weight() <= r.capacity(): return false
	for key in ["fuel","parts","tea","incense","medicine"]:
		if r.s.resources[key] > 0: return cmd(r,"drop",{"id":key,"amount":r.s.resources[key]})
	for role in r.BOOKS:
		if r.s.books[role] > 0: return cmd(r,"drop_item",{"id":role})
	if r.s.notebook: return cmd(r,"drop_item",{"id":"notebook"})
	var key = "water" if r.s.resources.water > r.people().size()*3 else "food"
	return cmd(r,"drop",{"id":key,"amount":minf(5,r.s.resources[key])})

func pilot(r,target) -> bool:
	var s = r.s
	match s.phase:
		"morning":
			if s.daily.prepared: return cmd(r,"finish_prepare")
			if target not in ["E01","E02","E14","E17"] and (target != "E15" or s.day <= 3) and "T01" in s.daily.card_candidates and s.resources.parts >= 3 and not s.daily.camp_used:
				if cmd(r,"card",{"id":"T01","option":0}): return true
			if target == "E15" and "T15" in s.daily.card_candidates and s.daily.tasks < 2:
				if cmd(r,"card",{"id":"T15","option":0}): return true
			var a = "none"
			if target in ["E05","E08","E10","E15"] and s.resources.water >= r.people().size()+4: a = "water"
			elif target != "E15" and not r.on_foot() and r.car().durability < 38 and s.resources.parts >= 5 and not r.qualified("repair").is_empty(): a = "repair"
			if target == "E15" and r.living("zhang") and r.person("zhang").health <= 10 and s.resources.medicine > 1: return cmd(r,"prepare",{"id":"aid","target":"zhang"})
			return cmd(r,"prepare",{"id":a})
		"route":
			if target == "E12":
				if s.day == 2 and "frequency" not in s.clues: return cmd(r,"intel",{"id":"frequency"})
				if s.day == 8 and not s.south_pledge: return cmd(r,"intel",{"id":"south"})
			if r.on_foot():
				if r.weight() > r.capacity(): return trim_cargo(r)
				if target == "E02" and s.position != "避难点": return cmd(r,"walk",{"id":"避难点"})
				return cmd(r,"depart",{"route":"stay","style":"quiet","supply":""})
			var tunnel = target == "E01" and s.legs >= 3 or target == "E14" and s.knowledge >= 50 and s.stored_copy or target in ["E02","E17"] and s.day == 11
			if tunnel and s.daily.map_choice != "sealed_tunnel": return cmd(r,"map_choice",{"id":"sealed_tunnel"})
			var stay = target in ["E03","E11","E07"] and s.legs >= 8 or s.resources.fuel < 10
			var supplies = r.supply_types(); var resource = supplies[0]
			if "water" in supplies and s.resources.water < 30: resource = "water"
			elif "food" in supplies and s.resources.food < 25: resource = "food"
			elif "fuel" in supplies: resource = "fuel"
			elif "parts" in supplies and s.resources.parts < 8: resource = "parts"
			elif "food" in supplies: resource = "food"
			var chosen_route = "stay" if stay else ("unknown" if target in ["E13","E15"] else "resource")
			return cmd(r,"depart",{"route":chosen_route,"style":"quiet","supply":resource})
		"rescue": return cmd(r,"rescue",{"id":"quiet" if target == "E12" else "abandon"})
		"rescue_seats": return cmd(r,"rescue_seat",{"id":"leave_sister"})
		"event","camp_event":
			var id = s.daily.card
			if id == "N-C04": return cmd(r,"card",{"id":id,"option":2 if target in ["E01","E14"] else 0})
			if id == "N-C05" and target == "E16": return cmd(r,"card",{"id":id,"option":1})
			if id == "N-C03" and target == "E15": return cmd(r,"card",{"id":id,"option":2,"target":"zhang"})
			if id == "N-C02" and target == "E15" and not r.on_foot() and r.car().durability > 35: return cmd(r,"card",{"id":id,"option":2,"target":"elin"})
			if id == "V08" and target == "E15": return cmd(r,"card",{"id":id,"option":2,"target":"captain"})
			var orders = [0,1,2,3,4]
			if target == "E16" and id in ["EV01","V01","V09"]: orders = [1,2,0,3,4]
			if id == "V01" and target in ["E15","E16"]: orders = [2,3,0,1]
			for o in orders:
				if cmd(r,"card",{"id":id,"option":o,"target":"captain","teacher":"zhang"}): return true
			return false
		"stop":
			if s.day in [4,7,9] and not s.daily.opportunity_used: return cmd(r,"recruit",{"id":"none"})
			if s.intent != "": return cmd(r,"begin_camp")
			if s.daily.tasks < 2:
				for faction in s.contacts:
					if s.factions[faction] <= -30 or "trade_"+faction in s.daily.used: continue
					if s.resources.water < r.people().size()*2 and s.resources.food >= 4: return cmd(r,"social",{"id":"trade","faction":faction,"offer":1})
					if s.resources.food < r.people().size()*2 and s.resources.fuel >= 8: return cmd(r,"social",{"id":"trade","faction":faction,"offer":0})
			if s.day >= 12 and target in r.GOAL_ACTIONS and r.ending_missing(target).is_empty() and s.daily.tasks < 2: return cmd(r,"goal",{"id":target})
			if target == "E07" and s.day >= 12 and s.resources.fuel > 10: return cmd(r,"drop",{"id":"fuel","amount":s.resources.fuel-10})
			if target == "E14" and not s.stored_copy and not s.records.is_empty() and s.daily.tasks < 2: return cmd(r,"social",{"id":"store_copy"})
			if target in ["E03","E11"] and r.people().size() > (3 if target == "E03" else 1) and s.legs >= 8 and s.daily.tasks < 2:
				if s.position != "避难点": return cmd(r,"visit",{"id":"refuge"})
				for m in r.people():
					if m.id != "captain" and m.trust >= 30: return cmd(r,"social",{"id":"safe_depart","target":m.id})
			if target == "E03" and s.factions.south < 60 and "south" in s.contacts and s.daily.tasks < 2 and "contribute_south" not in s.daily.used and s.resources.water >= 10 and s.resources.food >= 10: return cmd(r,"social",{"id":"contribute","faction":"south"})
			if target == "E08" and s.daily.tasks < 2:
				if r.affection() < 60 and int(s.facts.get("equal_day",-10))+3 <= int(s.day) and s.resources.water >= r.people().size()+2: return cmd(r,"social",{"id":"equal"})
				for faction in ["east","south"]:
					if faction in s.contacts and s.factions[faction] < 30 and "contribute_"+faction not in s.daily.used and s.resources.water >= 12 and s.resources.food >= 12: return cmd(r,"social",{"id":"contribute","faction":faction})
			if target == "E10" and s.day in [10,11,12] and s.daily.tasks < 2 and "favor" not in s.daily.used: return cmd(r,"social",{"id":"favor"})
			if target in ["E04","E05","E15","E16"] and s.daily.tasks < 2 and not s.contacts.is_empty():
				var faction = "east"
				for available in s.contacts:
					if s.factions[available] > -30: faction = available; break
				if target == "E05" and "south" in s.contacts and s.factions.south > -30: faction = "south"
				var raids_needed = 2 if target == "E04" else (3 if target == "E05" else (6 if target == "E15" else 7))
				if target == "E05" and s.factions.values().filter(func(v):return v<=-30).size() >= 2: raids_needed = 0
				if target == "E05" and s.raids >= 1 and "south" not in s.contacts: raids_needed = 0
				if s.raids < raids_needed and "raid" not in s.daily.used:
					if cmd(r,"social",{"id":"raid","faction":faction}): return true
				if target == "E04" and r.trust() > 30 and int(s.facts.get("command_day",-10))+2 <= int(s.day): return cmd(r,"social",{"id":"command"})
				if target == "E05" and r.affection() >= 30 and int(s.facts.get("command_day",-10))+2 <= int(s.day): return cmd(r,"social",{"id":"command"})
			if s.daily.tasks < 2:
				for faction in s.contacts:
					if s.factions[faction] <= -30 or "trade_"+faction in s.daily.used: continue
					if s.resources.water < r.people().size()*(3 if s.day == 9 or r.on_foot() else 2) and s.resources.food >= 4: return cmd(r,"social",{"id":"trade","faction":faction,"offer":1})
					if s.resources.food < r.people().size()*2 and s.resources.fuel >= 8: return cmd(r,"social",{"id":"trade","faction":faction,"offer":0})
					if (s.resources.fuel < 12 or target == "E06" and s.trades < 4) and s.resources.parts >= 2: return cmd(r,"social",{"id":"trade","faction":faction,"offer":2})
					if r.on_foot() and s.resources.fuel < 5 and s.resources.parts >= 2: return cmd(r,"social",{"id":"trade","faction":faction,"offer":2})
			return cmd(r,"begin_camp")
		"camp":
			if s.daily.camp_used: return cmd(r,"settle")
			if target in ["E15","E16"]:
				var who = "zhang" if target == "E15" else "captain"
				var health = r.person(who).health
				var deprivation = target == "E15" and s.day in [6,7,8] or target == "E16" and health > 20
				if deprivation and not s.daily.get("allocation_plan",{}).has(who): return cmd(r,"ration",{"id":"water" if health > 30 else "food","target":who,"amount":0})
			if target == "E14":
				if s.records.is_empty() and s.knowledge >= 35: return cmd(r,"camp",{"id":"record","label":"沿途验证的配给方法"})
				for role in r.BOOKS:
					if r.person("captain").understanding.get(role,0) < 100: return cmd(r,"camp",{"id":"read","target":"captain","role":role})
			var supplies = r.supply_types()
			for resource in ["water","food"]:
				if resource in supplies and s.resources[resource] < r.people().size()*2:
					if cmd(r,"camp",{"id":"gather","resource":resource}): return true
			if target != "E15" and not r.on_foot() and r.car().durability < 35 and s.resources.parts >= 3: return cmd(r,"camp",{"id":"repair"})
			if target == "E08" and r.affection() < 60 and s.resources.tea > 0 and s.resources.water >= 10: return cmd(r,"camp",{"id":"tea"})
			return cmd(r,"camp",{"id":"rest"})
		"night": return cmd(r,"next")
		"split": return cmd(r,"split",{"id":"separate" if target == "E10" and s.day >= 12 else "mediate"})
	return false
