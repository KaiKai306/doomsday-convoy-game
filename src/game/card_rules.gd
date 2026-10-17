extends "res://src/game/rules.gd"
## Explicit event predicates and effects, keyed to the manuscript's 109 stable IDs.
var expiry_mode = false

func _eligible_crisis_history(id: String) -> bool:
	return expiry_mode or not s.card_history.get(id,{}).get("closed",false)

func _draw_day() -> void:
	super._draw_day()
	if s.ending == "": _build_person_pool()

func speaker(id: String) -> String:
	if id.begins_with("M"):
		var i = int(id.substr(1)); return "zhang" if i <= 4 else ("elin" if i <= 8 else ("ajie" if i <= 12 else "sofia"))
	if id.begins_with("T"):
		var i = int(id.substr(1)); return "zhang" if i <= 4 else ("elin" if i <= 8 else ("ajie" if i <= 12 else "sofia"))
	if id in ["N-F04","N-F05"]: return "elin"
	if id in ["N-F01","N-F02","N-F03","N-F06","N-F08"]: return "sofia"
	if id in ["N-X03","N-X04","N-X05"]:
		for m in people():
			if m.joined > 1: return m.id
	if id == "N-X06": return "sister"
	return "captain"

func _eligible(id: String) -> bool:
	var card = content.cards[id]; var hist = s.card_history.get(id,{"last":-100,"count":0})
	if not expiry_mode:
		var once = "本局一次" in card.text or "首次一次" in card.text or "每局一次" in card.text or "一次，" in card.eligibility
		if once and hist.count >= 1: return false
		var cool = 3 if id in ["N-X01","N-X02"] else 4
		if _tier(id) < 2 and (hist.count >= 3 or (hist.count > 0 and s.day-hist.last < cool)): return false
		if _tier(id) == 2 and hist.get("closed",false): return false
	var z = person("zhang"); var e = person("elin"); var a = person("ajie"); var f = person("sofia")
	var owner = speaker(id)
	if card.pool == "person" and not living(owner): return false
	var hp = int(lowest().get("health",100)); var nv = not on_foot(); var dur = car().get("durability",0)
	var fatigue = person(owner).get("fatigue",0); var r = s.resources; var facts = s.facts
	var newcomer = people().filter(func(m): return m.joined > 1)
	var skill = best("scout").get("scout",0)
	match id:
		"M01": return nv and dur <= 60 and facts.get("front_unrepaired",false)
		"M02": return cars().size() == 2 and cars()[0].durability <= 60 and cars()[1].durability <= 60 and r.parts <= 10
		"M03": return facts.get("old_marker",false) and z.get("trust",0) >= 40 and not facts.get("marker_resolved",false)
		"M04": return newcomer.size() > 0 and not qualified("repair",50,80).is_empty() and facts.get("any_teaching",false)
		"M05": return hp <= 30 and facts.get("delayed_care",false)
		"M06": return r.medicine >= 1 and r.medicine <= 2 and people().filter(func(m): return m.health <= 40).size() >= 2
		"M07": return e.get("fatigue",0) >= 60 and facts.get("basic_nursing",false) and hp < 50
		"M08": return not qualified("medical",50,80).is_empty() and not facts.get("basic_nursing",false)
		"M09": return facts.get("yesterday_unknown_failure",false)
		"M10": return facts.get("radio",0) > 0 and s.day not in [5,10]
		"M11": return r.water <= 30 and facts.get("water_point_until",0) >= s.day
		"M12": return living("zhang") and living("ajie") and nv and dur <= 60 and r.fuel <= 30
		"M13": return s.institution >= 2 and not facts.get("public_rules",false)
		"M14": return newcomer.any(func(m): return not m.get("registered",false))
		"M15": return facts.get("preferential_days",0) >= 2
		"T01": return nv and s.day-int(z.get("last_talk",0)) >= 2
		"T02","T07","T10": return fatigue >= 60
		"T03": return nv and dur <= 40
		"T04": return nv and dur <= 60 and living("ajie")
		"T05": return hp <= 40
		"T06": return hp <= 40 and (weight() > capacity() or people().size() >= 8)
		"T08": return r.medicine <= 2 and s.day <= 9
		"T09": return facts.get("scout_refused",0) >= 2
		"T11": return r.fuel <= 30 and facts.get("warehouse",false)
		"T12": return a.get("trust",100) <= 40 or facts.get("scout_promise",false)
		"T13": return s.private_risk >= 10 or facts.get("private_allocation",false)
		"T14": return r.water < 2*people().size() or r.food < 2*people().size() or r.fuel < 16 or r.medicine < 2 or r.parts < 3
		"T15": return people().any(func(m): return m.id != "captain" and m.trust <= 20)
		"V01": return s.daily.route == "resource" and s.day >= 3 or s.tracking >= 70
		"V02": return nv and s.daily.route == "unknown" and s.daily.weather == "雨" and facts.get("front_unrepaired",false) and s.daily.style != "detour"
		"V03": return nv and s.daily.night_travel and s.daily.noise >= 50 and s.daily.light and not s.daily.sealed and r.food > 0
		"V04": return facts.get("radio",0) > 0 and not facts.get("radio_off",false) and s.day not in [5,10]
		"V05": return nv and r.fuel <= 10 and facts.get("fuel_depot",false)
		"V06": return s.daily.weather in ["雨","沙尘"]
		"V07": return facts.get("radio",0) >= 1 and s.daily.night_travel and not facts.get("radio_off",false) and s.day not in [5,10]
		"V08": return s.daily.weather == "雾" and s.legs >= 3 and not facts.get("seen_outline",false)
		"V09": return nv and (dur <= 20 or s.daily.route == "unknown" and s.daily.weather == "雨" and facts.get("front_unrepaired",false))
		"V10": return facts.get("fire_warning",false) or s.daily.night_travel and s.legs in [5,11,16]
		"V11": return s.daily.route == "unknown" and s.daily.weather in ["沙尘","雾"] and s.legs >= 4
		"S01": return facts.get("broken_promise",false) and trust() <= 40
		"S02": return facts.get("private_allocation",false) and r.food <= 20 and not facts.get("theft_done",false)
		"S03": return group_gap() > 0 and trust() <= 50
		"S04": return r.medicine == 1 and hp <= 40
		"S05": return s.legs in [5,11,16] and s.knowledge <= 40
		"R01": return s.daily.route == "resource" and s.daily.noise < 30 and (s.day == 3 or "guild" in s.contacts)
		"R02": return s.daily.route == "safe" and s.daily.noise < 30
		"R03": return s.daily.route == "resource" and r.fuel <= 40 and s.legs in [3,6,9,12,15]
		"R04": return s.daily.route == "resource" and r.medicine <= 3 and s.legs in [3,4,8,12]
		"R05": return s.daily.route == "safe"
		"R06": return s.daily.route == "resource" and s.day in [6,9,12]
		"R07": return s.position == "避难点" and not s.contacts.is_empty()
		"R08": return s.legs >= 5
		"N-F01": return facts.get("knowledge_loss_due",0) == s.day
		"N-F02": return facts.get("ration_dispute_due",0) == s.day
		"N-F03": return s.private_risk >= 20
		"N-F04": return hp <= 30 and facts.get("fever_upgraded",false)
		"N-F05": return facts.get("rest_refused_day",-100) == s.day-1
		"N-F06": return facts.get("panic",false) and _eligible_shortage()
		"N-F07": return false # Mandatory second-night screen, outside the daily pool.
		"N-F08": return facts.get("false_registration",false) and s.daily.route == "safe"
		"N-F09": return facts.get("warehouse_promise",false) and s.daily.route == "resource"
		"N-F10": return facts.get("brake_missing",false) and s.legs in [7,11,15]
		"N-F11": return facts.get("brake_number",false) and s.legs in [3,6,8,11,14]
		"N-X01": return facts.get("seen_outline",false) and s.observations < 2 and s.day-s.last_observation >= 3
		"N-X02": return s.observations >= 2 and s.obey < 3 and s.day-s.last_observation >= 3
		"N-X03": return newcomer.size() > 0 and r.water < people().size()*(2 if on_foot() else 1)
		"N-X04": return newcomer.size() > 0 and not qualified("repair",50,80).is_empty()
		"N-X05": return newcomer.any(func(m): return m.trust <= 35 or not m.get("registered",false))
		"N-X06": return s.day >= 11 and living("sister") and person("sister").health <= 49
		"N-X07": return not s.records.is_empty() and not s.stored_copy and s.legs >= 5
		"N-X08": return facts.get("father_ready",false) and s.position == "避难点"
		"N-X09": return facts.get("luzhi_ready",false) and s.position == "避难点"
		"N-C01": return false # Only player-initiated, never a random moral choice.
		"N-C02": return s.tracking >= 50 or facts.get("visible_pursuit",false)
		"N-C03": return nv and dur <= 35 and facts.get("front_unrepaired",false) and (s.tracking >= 60 or facts.get("visible_pursuit",false))
		"N-C04": return facts.get("sealed_tunnel_attempt",false)
		"N-C05": return person("captain").health <= 20 and s.tracking >= 70 and facts.get("visible_pursuit",false)
	if id.begins_with("C"):
		var n = int(id.substr(1)); var action = str(s.daily.get("camp_action",""))
		if n <= 5: return action == "read" and (n == 5 and not s.records.is_empty() or n in [1,2,3,4] and str(s.daily.get("camp_role","")) == ["repair","medical","scout","logistics"][n-1])
		if n <= 10: return action == "teach"
		if n <= 15:
			if action != "record": return false
			if n == 13: return s.members.any(func(m): return not m.alive or not m.active)
			if n == 14: return facts.get("radio",0) > 0
			return true
		if n <= 20: return action == "exchange_book" and not s.contacts.is_empty()
		if n <= 25: return action == "burn_book"
		if action != "rest": return false
		if n == 27: return s.members.any(func(m): return not m.alive)
		if n == 28: return facts.get("radio",0) > 0
		if n == 29: return s.tracking >= 20 or s.exposure >= 30
		if n == 30: return facts.get("quiet_nights",0) >= 1
		return true
	return false

func _eligible_shortage() -> bool:
	return s.resources.water < people().size()*2 or s.resources.food < people().size()*2

func _tier(id: String) -> int:
	if id in ["M01","M02","M05","M06","T02","T03","T05","T06","T07","T10","T14","T15","S01","S04","N-F02","N-F04","N-F05","N-F06","N-F08","N-X03","N-X08","N-X09","N-C04","N-C05"]: return 2
	if "P70" in content.cards[id].eligibility or id in ["N-F11","N-X05","N-X06"]: return 1
	return 0

func _draw_card(pool: String, rate: float) -> String:
	var candidates: Array = []
	for id in content.cards:
		if content.cards[id].pool == pool and _eligible(id): candidates.append(id)
	# Supplemental observation and aftermath cards use explicit pools.
	if pool == "travel":
		for id in ["N-X01","N-X02","N-F10"]:
			if _eligible(id): candidates.append(id)
	if candidates.is_empty(): return ""
	if pool == "travel":
		for id in ["N-C04","N-C05"]:
			if id in candidates: return id
	if pool == "camp":
		var top = 0
		for id in candidates: top = maxi(top,_tier(id))
		candidates = candidates.filter(func(id): return _tier(id) == top)
		rate = [35,70,100][top]
	if pool == "travel":
		if s.facts.has("next_event_rate"): rate = s.facts.next_event_rate; s.facts.erase("next_event_rate")
		rate = clampf(rate+s.facts.get("next_event_mod",0),0,100); s.facts.erase("next_event_mod")
	if not chance(rate): return ""
	var selected = str(candidates[rng.randi_range(0,candidates.size()-1)])
	if selected in ["V02","V09"] and not chance(breakdown_probability()): return ""
	if selected == "N-F10" and not chance(35 if s.daily.weather == "雨" else 25): return ""
	return selected

func _build_person_pool() -> void:
	if s.daily.get("people_drawn",false): return
	s.daily.people_drawn = true
	s.daily.card_candidates = []
	var by_person = {}
	for id in content.cards:
		if content.cards[id].pool != "person" or id in ["N-X01","N-X02","N-F10","N-F07"] or not _eligible(id): continue
		var owner = speaker(id)
		if not by_person.has(owner): by_person[owner] = []
		by_person[owner].append(id)
	for owner in by_person:
		var top = 0
		for id in by_person[owner]: top = maxi(top,_tier(id))
		var pool = by_person[owner].filter(func(id): return _tier(id) == top)
		if chance([35,70,100][top]): s.daily.card_candidates.append(pool[rng.randi_range(0,pool.size()-1)])
	s.daily.card_candidates.sort_custom(func(a,b): return _tier(a) > _tier(b) if _tier(a) != _tier(b) else a < b)

func _arrive() -> void:
	super._arrive()
	if s.day in [4,5,7,9,10] or s.daily.get("opportunity_drawn",false): return
	s.daily.opportunity_drawn = true
	var p = 35 if s.daily.route == "resource" else (40 if s.daily.route == "unknown" else 20)
	var id = _draw_card("opportunity",p)
	if id != "": s.daily.opportunity_card = id

func lowest() -> Dictionary:
	var pool = people().duplicate(); pool.sort_custom(func(a,b): return a.health < b.health)
	return pool[0] if not pool.is_empty() else {}

func _stat(id: String, key: String, amount: float) -> void:
	if living(id): change(person(id),key,amount)

func _note(label: String, knowledge: int = 4, pages: int = 1) -> bool:
	if s.pages < pages: return fail("笔记页不足")
	s.pages -= pages
	if label not in s.records: s.records.append(label); s.knowledge = mini(100,s.knowledge+knowledge)
	return true

func _repair(amount: int) -> void:
	if not on_foot(): car().durability = minf(100,car().durability+amount); s.facts.front_unrepaired = false

func _camp_replacement(hours: float = 2.5) -> bool:
	if s.daily.camp_used: return fail("今天唯一营地行动已使用")
	s.daily.camp_used = true; s.daily.hours += hours
	return true

func _remember(id: String) -> void:
	var h = s.card_history.get(id,{"last":-100,"count":0})
	h.last = s.day; h.count += 1
	if _tier(id) == 2 and h.count >= 2: h.closed = true
	s.card_history[id] = h
	var owner = speaker(id)
	if living(owner): person(owner).last_talk = s.day; person(owner).memory = content.cards[id].title+"：第%d天已回应" % s.day
	log_event("事件已结算："+id+" "+content.cards[id].title)

func breakdown_probability() -> int:
	var base = {"safe":5,"resource":10,"unknown":18}.get(s.daily.route,5)
	if s.daily.weather == "雨": base += 10
	if s.facts.get("front_unrepaired",false): base += 12
	if not on_foot() and car().durability > 20 and car().durability <= 40: base += 15
	if s.daily.style == "quiet": base -= 5
	return clampi(base,0,60)

func resolve_card(id: String, option: int, args: Dictionary = {}) -> bool:
	if not content.cards.has(id) or option < 0 or option > 5: return false
	var travel = s.phase == "event" and s.daily.card == id
	var camp_event = s.phase == "camp_event" and s.daily.card == id
	var opportunity = s.phase == "stop" and s.daily.get("opportunity_card","") == id
	var personal = s.phase in ["morning","route","stop"] and id in s.daily.card_candidates
	if not travel and not camp_event and not opportunity and not personal and not expiry_mode: return fail("该卡未生成，不能从图鉴执行")
	if personal or opportunity:
		if s.daily.tasks >= 2 and not expiry_mode: return fail("今天两项主要事务已用完")
		if not expiry_mode: s.daily.tasks += 1
		if opportunity:
			if s.daily.opportunity_used: return fail("今日机会已使用")
			s.daily.opportunity_used = true
	var target = person(str(args.get("target",lowest().get("id","captain"))))
	if target.is_empty(): target = lowest()
	var owner = speaker(id)
	var successful = false
	if id.begins_with("V") or id.begins_with("N-C") or id in ["N-X01","N-X02","N-F10"]: successful = _travel_effect(id,option,target,args)
	elif id.begins_with("C"): successful = _camp_effect(id,option,target,args)
	elif id.begins_with("M") or id.begins_with("T") or id.begins_with("N-"): successful = _person_effect(id,option,target,args)
	else: successful = _opportunity_effect(id,option,target,args)
	if not successful: return false
	_remember(id)
	s.daily.card_candidates.erase(id)
	if opportunity: s.daily.opportunity_card = ""
	_check_deaths(travel); _check_vehicle_loss()
	if s.ending != "": return true
	if travel:
		s.daily.event = id
		if s.daily.get("chain_card","") != "": s.daily.card = s.daily.chain_card; s.daily.chain_card = ""; s.phase = "event"
		else: s.daily.card = ""; _arrive()
	elif camp_event: s.daily.card = ""; s.phase = "camp"
	return true

func _travel_effect(id: String, o: int, target: Dictionary, args: Dictionary) -> bool:
	match id:
		"V01":
			match o:
				0:
					if not pay({"parts":3}): return false
					damage_car(8,true); s.tracking = maxi(0,s.tracking-10)
				1:
					if not pay({"food":10}): return false
					_stat("elin","trust",-3); s.tracking = maxi(0,s.tracking-15)
				2:
					if not pay({"parts":5}): return false
					if chance(clampi(25+floori(best("scout").get("scout",0)/2.0),15,85)): gain({"food":8,"fuel":8}); s.tracking = maxi(0,s.tracking-20)
					else: damage_car(15,true); change(target,"health",-30); s.tracking = mini(100,s.tracking+10)
				3:
					if s.resources.fuel >= 3: pay({"fuel":3}); damage_car(12); all_change("fatigue",10)
					else: s.resources.food = 0; s.tracking = maxi(0,s.tracking-10)
				_: return false
		"V02":
			if o == 0:
				if not pay({"parts":6}): return false
				_repair(10); s.daily.hours += 2
			elif o == 1: abandon_car(); all_change("trust",-5)
			elif o == 2: damage_car(5); change(target,"health",-10); s.facts.front_unrepaired = true
			elif o == 3: s.daily.hours += 3; all_change("fatigue",10); _undo_progress()
			else: return false
		"V03":
			if o == 0: s.tracking = maxi(0,s.tracking-20); s.daily.hours += 1; s.daily.light = false
			elif o == 1:
				if not pay({"fuel":4}): return false
				s.tracking = maxi(0,s.tracking-10); damage_car(3)
			elif o == 2:
				if not pay({"parts":2}): return false
				damage_car(8,true); change(target,"health",-20); s.tracking = mini(100,s.tracking+10)
			else: return false
			s.daily.sealed = true
		"V04","V07":
			if o == 0: s.exposure = mini(100,s.exposure+(2 if id == "V04" else 1)); s.facts.radio = s.facts.get("radio",0)+(1 if id == "V04" else 2)
			elif o == 1:
				if not _note("普通无线电%d" % s.day): return false
				s.facts.radio = s.facts.get("radio",0)+1
			elif o == 2: s.facts.radio_off = true; _stat("elin","trust",-2 if id == "V04" else -3)
			else: return false
		"V05":
			if o == 0:
				var deal = str(args.get("deal","pay"))
				if deal == "pay":
					if not pay({"food":5}): return false
					gain({"fuel":20})
				elif deal == "rob": gain({"fuel":20}); s.raids += 1; _faction("guild",-30); all_change("trust",-10)
				else: gain({"fuel":5})
				s.daily.hours += 2; s.daily.supply_claimed = true
			elif o == 1:
				_undo_progress(); s.edge_km = 15; s.distance += 15; s.daily.hours += 2
			elif o == 2:
				if cars().size() < 2: return fail("需要第二车")
				for v in cars():
					if v != car(): v.destroyed = true; break
				gain({"fuel":10})
			else: return false
		"V06":
			if o == 0: s.daily.hours += 4; all_change("fatigue",10)
			elif o == 1:
				var p = 20 if car().get("durability",0) > 40 else 35
				if has_mod("SP16") and s.daily.weather == "沙尘": p -= 10
				damage_car(10); all_change("fatigue",10)
				if not on_foot() and chance(p): s.daily.chain_card = "V09"; return true
			elif o == 2:
				if not pay({"fuel":4}): return false
				s.daily.hours += 2; _undo_progress()
			else: return false
		"V08","N-X01","N-X02":
			s.facts.seen_outline = true
			if o == 0 or id == "N-X02" and o == 1 and chance(70):
				if s.observations < 3:
					if not _note("同一轮廓记录%d" % (s.observations+1)): return false
					s.observations += 1
				s.obey += 1; s.last_observation = s.day; s.daily.hours += 2
			elif o == 1 and id != "N-X02" or o == 2 and id == "N-X02":
				if not pay({"fuel":3 if id in ["V08","N-X02"] else 2}): return false
				s.obey = 0; s.daily.hours += 3 if id == "V08" else 2
				if id == "V08": _undo_progress()
			else:
				all_change("health",-20 if id == "V08" else -10); damage_car(20 if id == "V08" else 10); s.obey = 0; s.tracking = mini(100,s.tracking+15)
		"V09":
			if o == 0:
				var cost = 3
				if qualified("repair").is_empty():
					if qualified("repair",30,95,40).is_empty(): return fail("无合格或可临时支持的见习维修者")
				if not pay({"parts":cost}): return false
				_repair(15); s.daily.hours += 3
			elif o == 1:
				var broken = chance(40 if s.facts.get("front_unrepaired",false) else 25)
				damage_car(20)
				if broken:
					if not on_foot(): car().destroyed = true
					change(target,"health",-30)
			elif o == 2:
				var winch = has_mod("SP11") and people().filter(func(m): return m.health >= 30).size() >= 2 and s.resources.fuel >= 1
				if people().filter(func(m): return m.health >= 30).size() < 3 and not winch: return fail("推车需3名健康30者，或有效绞盘及2人、油1")
				if winch: pay({"fuel":1})
				all_change("fatigue",12 if winch else 20); s.daily.hours += 3 if winch else 4; _undo_progress()
			elif o == 3: abandon_car()
			elif o == 4:
				if s.contacts.is_empty() or not pay({"water":5}): return false
				_repair(10); s.daily.hours += 3
			else: return false
		"V10":
			if o == 0:
				if not pay({"fuel":3}): return false
				damage_car(5); s.exposure = mini(100,s.exposure+2)
			elif o == 1: s.daily.hours += 2; all_change("fatigue",8 if has_mod("SP14") else 10); damage_car(4 if has_mod("SP14") else 8)
			elif o == 2:
				if not pay({"water":10,"parts":2}): return false
			elif o == 3: abandon_car(); s.resources.fuel = 0
			else: return false
		"V11":
			if o in [0,1]:
				if not pay({"fuel":3 if o == 0 else 2}): return false
				if o == 0: s.daily.hours += 2
				else: all_change("health",-10)
			elif o == 2:
				all_change("health",-10)
				if chance(40): change(target,"health",-20)
				s.daily.hours += 2; s.knowledge = mini(100,s.knowledge+5)
			elif o == 3: s.daily.hours += 3; all_change("fatigue",10); all_change("health",-5)
			else: return false
		"N-C01":
			if o == 0: return _trade("guild",int(args.get("offer",0)))
			if o == 1: gain({"water":10,"food":10,"fuel":12}); damage_car(5,true); s.raids += 1; _faction("guild",-30); all_change("trust",-10); s.tracking = mini(100,s.tracking+15)
		"N-C02","N-C03","N-C05":
			if o == 0:
				if not pay({"parts":4}): return false
				s.tracking = maxi(0,s.tracking-20)
			elif id == "N-C05" and o == 1: change(person("captain"),"health",-30); s.tracking = maxi(0,s.tracking-20)
			elif o == 1 and id == "N-C03": s.daily.hours += 2; s.tracking = maxi(0,s.tracking-10); damage_car(5)
			elif o == 1 or id == "N-C05" and o == 2:
				if not pay({"fuel":3}): return false
				s.daily.hours += 2; s.tracking = maxi(0,s.tracking-10)
			elif o == 2:
				for m in people(): change(m,"health",-30 if m.id == target.id else -10)
				damage_car(15,true); s.tracking = mini(100,s.tracking+15)
				_check_deaths(true)
				if id == "N-C03" and s.ending == "" and not target.alive and not on_foot() and car().durability <= 20 and qualified("repair",30,95,40).is_empty() and s.contacts.is_empty(): _end("E15")
			elif o == 3: s.resources.food = maxi(0,s.resources.food-(10 if id == "N-C05" else 5)); all_change("fatigue",10); s.tracking = maxi(0,s.tracking-5)
			else: return false
		"N-C04":
			if o == 0: abandon_car(); _undo_progress()
			elif o == 1:
				if not pay({"parts":10}): return false
				s.daily.hours += 3; all_change("fatigue",10); _undo_progress()
			elif o == 2:
				for v in s.vehicles: v.destroyed = true
				all_change("health",-100)
			elif o == 3:
				if on_foot() or not pay({"fuel":3}): return false
				s.daily.hours += 2; _undo_progress()
			else: return false
		"N-F10":
			if o == 0:
				if not pay({"parts":2}): return false
				_repair(5); s.daily.hours += 1; s.facts.brake_missing = false
			elif o == 1: damage_car(10); change(target,"health",-10); s.tracking = mini(100,s.tracking+5)
			elif o == 2:
				if not pay({"fuel":2}): return false
				s.daily.hours += 2
			else: return false
		_: return fail("未实现的移动卡："+id)
	return true

func _undo_progress() -> void:
	if s.daily.get("progress_undone",false): return
	s.daily.progress_undone = true
	if not on_foot() and s.daily.distance > 0:
		s.legs = maxi(0,s.legs-1); s.distance = maxf(0,s.distance-s.daily.distance); s.edge_km = 0

func _person_effect(id: String, o: int, target: Dictionary, args: Dictionary) -> bool:
	var owner = speaker(id)
	match id:
		"M01":
			if o == 0:
				if s.daily.prepared or not pay({"parts":3}): return fail("准备已用或零件不足")
				_repair(8); s.daily.prepared = true; s.daily.hours += 2; s.facts.next_b = -10
			elif o == 2: _stat("zhang","trust",-4); s.facts.front_unrepaired = true
			else: return fail("追问可直接阅读卡片详情，不占行动")
		"M02":
			if s.daily.prepared or cars().size() != 2: return false
			if not pay({"parts":4 if o == 2 else 2}): return false
			if o == 2:
				for v in cars(): v.durability = mini(100,v.durability+3)
				_stat("zhang","trust",-1); _stat("sofia","trust",-1)
			else:
				cars()[o].durability = mini(100,cars()[o].durability+8); _stat("zhang" if o == 0 else "sofia","trust",2)
			s.daily.prepared = true; s.daily.hours += 1
		"M03":
			if o == 0: _stat("zhang","trust",3); s.facts.repair_bonus = 2
			elif o == 1:
				if not _note("旧维修标记"): return false
				s.facts.repair_bonus = 2
			elif o == 2: gain({"parts":1}); _stat("zhang","trust",-3)
			else: return false
			s.facts.marker_resolved = true
		"M04","N-X04":
			if o == 0:
				if not _camp_replacement(2) or not teach(str(args.get("teacher","zhang")),target.id,str(args.get("role","repair"))): return false
			elif o == 1:
				s.daily.hours += 1
				if chance(85): change(target,str(args.get("role","repair")),3); target.understanding.repair = mini(100,target.understanding.get("repair",0)+5)
				else: change(target,"fatigue",10); damage_car(2 if id == "M04" else 0)
			elif o == 2: change(target,"trust",-2)
			else: return false
		"M05","T05","S04","N-F04":
			if o == 0:
				if not _camp_replacement() or not pay({"medicine":1}): return false
				heal(target,10 if id == "M05" else (25 if id == "N-F04" else 20)); _stat("elin","trust",3 if id in ["M05","N-F04"] else 5); s.facts.delayed_care = false; s.facts.fever_upgraded = false
			elif id == "N-F04" and o == 1:
				if s.position != "避难点" or not pay({"water":5}): return fail("当前需可达医疗援助点")
				change(target,"health",15); s.daily.hours += 2; target.unavailable_until = s.day+1; s.facts.fever_upgraded = false
			elif o == 2 or id == "S04" and o == 1:
				change(target,"health",-15 if id == "N-F04" else -10); _stat("elin","trust",-8 if id == "N-F04" else -6); s.facts.delayed_care = true
				if id == "M05": s.facts.fever_upgraded = true
				if id == "N-F04": s.pending.append({"kind":"damage","target":target.id,"day":s.day+1,"amount":-5}); s.facts.fever_upgraded = false
			else: return fail("追问只显示详情，不收费")
		"M06":
			var wounded = people().filter(func(m): return m.health <= 40)
			wounded.sort_custom(func(a,b): return a.health < b.health)
			if wounded.size() < 2 or not _camp_replacement() or not pay({"medicine":1}): return false
			if o == 2:
				var success = chance(30 if best("medical").get("medical",0) >= 70 else 15)
				for m in wounded.slice(0,2): change(m,"health",10 if success else -10)
			else:
				var treated = wounded[0] if o == 0 else target
				heal(treated,20)
				for m in wounded.slice(0,2):
					if m.id != treated.id: change(m,"health",-10); change(m,"trust",-2 if o == 0 else -5)
		"M07":
			if not _camp_replacement(2) or not pay({"medicine":1}): return false
			var p = (90 if s.facts.get("basic_nursing",false) else 80) if o == 0 else (90 if o == 1 else 95)
			if chance(p): heal(target,20)
			elif o == 0: change(target,"health",-10)
			if o == 0: _stat("elin","fatigue",-20)
			if o == 2: _stat("elin","health",-10); s.facts.rest_refused_day = s.day
		"M08":
			if o < 2:
				var student = "sofia" if o == 0 else "ajie"
				if not _camp_replacement(2) or not teach("elin",student,"medical"): return false
				s.facts.basic_nursing = person(student).training.get("medical",0) > 0
				if o == 1: _stat("ajie","fatigue",10)
		"M09":
			if o == 0:
				if not pay({"fuel":3}): return false
				s.daily.hours += 1; s.facts.next_u = -10; _stat("ajie","trust",2)
			elif o != 2: return fail("追问不结算")
		"M10":
			if o == 0: s.daily.hours += 1; s.exposure = mini(100,s.exposure+1); s.facts.radio = s.facts.get("radio",0)+1
			elif o == 1:
				if not _note("军用频段时刻"): return false
			else: s.facts.radio_off = true; _stat("ajie","trust",-3)
		"M11":
			if o == 0:
				s.daily.hours += 2
				if chance(85): gain({"water":18})
			elif o == 1:
				if not pay({"fuel":3}): return false
				if chance(65): gain({"water":18})
				else: s.daily.hours += 2
			else: _stat("ajie","trust",-2)
			s.facts.water_point_until = 0
		"M12":
			if o == 0:
				if not pay({"fuel":3}): return false
				s.daily.route_override = "safe"; s.facts.road_excluded = true; _stat("zhang","trust",3); _stat("ajie","trust",-1)
			elif o == 1: s.daily.route_override = "unknown"; s.facts.next_u = 10; _stat("ajie","trust",3); _stat("zhang","trust",-1)
			else: s.daily.route_override = "resource"; s.daily.hours += 1; _stat("zhang","trust",1); _stat("ajie","trust",1)
		"M13":
			if o == 0: s.daily.hours += 0.5; all_change("trust",2); _institution()
			elif o == 1: s.daily.hours += 0.25; _stat("sofia","trust",1)
			else: s.institution = maxi(0,s.institution-1); _stat("sofia","trust",-4)
		"M14":
			s.daily.hours += 0.5
			if target.joined == 1:
				for m in people():
					if m.joined > 1 and not m.get("registered",false): target = m; break
			if o == 0: change(target,"trust",3); change(target,"like",2); target.registered = true
			elif o == 1: change(target,"trust",1); target.registered = true
			else:
				change(target,"trust",-5)
				if chance(25): s.facts["departure_proposal_"+target.id] = true
		"M15":
			if o == 0: change(target,"trust",-2); _stat("sofia","trust",2); _institution()
			elif o == 1: change(target,"trust",-1); s.facts["skip_food_"+target.id] = s.day+1
			else: s.private_risk = mini(100,s.private_risk+1); _stat("sofia","trust",-3); s.facts.forgiven = int(s.facts.get("forgiven",0))+1
		"T01","T03":
			if o == 0:
				if not _camp_replacement() or not pay({"parts":3}): return false
				_repair(15); _stat("zhang","trust",5 if id == "T01" else 0)
			elif o == 1: return fail("追问不结算")
			elif id == "T01" and o == 2: s.facts.front_unrepaired = true; s.facts.broken_promise = true
			else:
				_stat("zhang","trust",-5 if id == "T01" else -4); s.facts.front_unrepaired = true
		"T02","T07","T10","N-F05":
			if id == "N-F05": owner = str(s.facts.get("rest_target","elin"))
			if o == 0:
				if id == "T07":
					if not _camp_replacement(): return false
					all_change("fatigue",-20)
				else: _stat(owner,"fatigue",-20); s.daily.hours += 0.5
				_stat(owner,"trust",2 if id == "T10" else 3)
				var replacement = person("captain")
				for m in people():
					if m.id != owner and m.health >= 30 and m.fatigue < replacement.fatigue: replacement = m
				change(replacement,"fatigue",10)
			elif o == 1 and id == "N-F05": s.facts.rest_promise = owner; s.daily.hours += 0.5
			elif o == 1 and id != "T02": return fail("追问不收费")
			else:
				_stat(owner,"fatigue",10); _stat(owner,"trust",-3 if id == "T10" else -5)
				if id == "T02": _stat(owner,"health",-10)
				s.facts.rest_refused_day = s.day; s.facts.rest_target = owner
		"T04","T08","T09","T11":
			if o == 1: return fail("追问只显示原文信息")
			if o == 0:
				s.facts.next_route = "safe" if id == "T04" else ("unknown" if id == "T09" else "resource")
				_stat(owner,"trust",4 if id == "T09" else 3)
				if id == "T11": s.facts.warehouse_promise = true
			else: _stat(owner,"trust",-3)
		"T06":
			if o == 0:
				var to_drop = 10.0
				for key in ["fuel","water","parts","food"]:
					var kg = {"fuel":0.8,"water":1.0,"parts":1.0,"food":0.5}[key]
					var amount = minf(s.resources[key],ceilf(to_drop/kg)); s.resources[key] -= amount; to_drop -= amount*kg
					if to_drop <= 0: break
				_stat("elin","trust",5)
			elif o == 2: depart(target.id,s.position == "避难点"); _stat("elin","trust",-15); all_change("like",-3); s.facts.rest_refused_day = s.day
			else: return fail("追问显示距离，不丢弃人物")
		"T12":
			if o == 0:
				if not _note("阿杰公开路线"): return false
				_stat("ajie","trust",5); _stat("ajie","like",2); _stat("sofia","trust",1)
			elif o == 2: _stat("ajie","trust",-3); s.facts.private_map = true
			else: return fail("追问不结算")
		"T13":
			if o == 0: s.private_risk = maxi(0,s.private_risk-10); _stat("sofia","trust",3)
			elif o == 2: _stat("sofia","trust",-3); s.private_risk = mini(100,s.private_risk+5)
			else: return fail("追问不结算")
		"T14":
			if o == 0: s.facts.skip_captain_food = s.day; _stat("sofia","trust",3)
			elif o == 2: s.facts.panic = true
			else: return fail("追问仅显示库存日数")
			s.daily.hours += 0.5
		"T15":
			var pool = people().filter(func(m): return m.id != "captain"); pool.sort_custom(func(a,b): return a.trust < b.trust)
			if not pool.is_empty(): target = pool[0]
			if o == 0: change(target,"trust",10); s.daily.hours += 1
			elif o == 2: s.pending.append({"kind":"depart","target":target.id,"day":s.day+1})
			else: return fail("追问不结算")
		"N-F01":
			if not _camp_replacement(2): return false
			if o == 0:
				if not _note("补记已验证方法"): return false
			elif o == 1:
				if not teach(str(args.get("teacher","zhang")),target.id,str(args.get("role","repair"))): return false
			elif o == 2: s.knowledge = maxi(0,s.knowledge-3); target.understanding.repair = maxi(0,target.understanding.get("repair",0)-5)
			elif o == 3:
				for m in people().slice(0,2): m.understanding.repair = mini(100,m.understanding.get("repair",0)+5)
				s.knowledge = mini(100,s.knowledge+1)
			s.facts.knowledge_loss_due = 0
		"N-F02":
			if o == 0:
				if not pay({"water":2,"food":2}): return false
				_mediate(); _institution()
			elif o == 1:
				if not pay({"water":2}): return false
				for m in people(): change(m,"trust",8 if m.group == "A" else -8)
			else: all_change("trust",-5); all_change("like",-8)
			s.daily.hours += 1; s.facts.ration_dispute_due = 0
		"N-F03":
			if o == 0: s.daily.hours += 1; s.private_risk = maxi(0,s.private_risk-10); _stat("sofia","trust",3)
			elif o == 1:
				s.daily.hours += 0.5
				if chance(85 if not qualified("logistics").is_empty() else 65): s.private_risk = maxi(0,s.private_risk-5)
				else: s.private_risk = mini(100,s.private_risk+5); _stat("sofia","trust",-2)
			else: s.private_risk = mini(100,s.private_risk+5); _stat("sofia","trust",-3)
		"N-F06":
			if chance(50 if lowest().health <= 40 else 35): all_change("trust",-3); all_change("like",-2)
			s.facts.panic = false
			if o == 0: all_change("trust",2); s.daily.hours += 0.5
			elif o == 1: _stat("sofia","trust",2)
			else: all_change("trust",-2); all_change("like",-1)
		"N-F08":
			if o == 0: _faction("east",-5); s.daily.hours += 1
			elif o == 1:
				if not pay({"water":3,"food":3}): return false
				s.daily.hours += 0.5
			else:
				if not pay({"fuel":3}): return false
				s.tracking = mini(100,s.tracking+15); _faction("east",-15); s.daily.hours += 1
			s.facts.false_registration = false
		"N-F09":
			if o == 0:
				if not _trade("guild",int(args.get("offer",0))): return false
			elif o == 1: s.daily.hours += 2; all_change("fatigue",10); gain({str(args.get("resource","water")):12}); _faction("guild",5)
			elif o == 2: gain({"water":10,"food":10,"fuel":12}); s.raids += 1; damage_car(5,true); _faction("guild",-30); all_change("trust",-10); s.tracking = mini(100,s.tracking+15)
			s.facts.warehouse_promise = false; s.daily.supply_claimed = true
		"N-F11":
			if o == 0:
				s.daily.hours += 1
				if chance(40):
					if not _note("完整刹车页",2): return false
					s.facts.brake_missing = false
			elif o == 1:
				if not pay({"parts":2}) or not _note("完整刹车页",2): return false
				s.facts.brake_missing = false
			s.facts.brake_number = false
		"N-X03":
			if o == 0: change(target,"trust",2)
			elif o == 1:
				if s.resources.water < 1: return fail("队长无可转让的一升水")
				s.daily.transfer_water = target.id; change(target,"trust",3); change(target,"like",2)
			else: s.daily.skip_water = target.id; change(target,"trust",-5)
		"N-X05":
			if o == 0: change(target,"trust",2); change(target,"like",3)
			elif o == 1: change(target,"trust",3); target.registered = true; _stat("sofia","trust",1)
			else: change(target,"trust",-4); change(target,"like",-2)
			s.daily.hours += 0.5
		"N-X06":
			if o == 0: _stat("sister","fatigue",-10); _stat("sister","like",3); s.daily.noise += 5
			elif o == 1: _stat("sister","trust",2); _stat("sister","like",3); s.daily.hours += 0.5
			else: _stat("sister","fatigue",10); _stat("sister","like",-3)
		"N-X07":
			if o < 2:
				if s.records.is_empty() or s.pages < 2: return fail("需要可读抄本与复制页")
				s.pages -= 2; s.stored_copy = true; s.facts.copy_location = s.legs; s.knowledge = mini(100,s.knowledge+1); s.daily.hours += 2
		"N-X08","N-X09":
			if o == 0:
				if people().size() >= 8 or not pay({"water":2,"food":2}): return fail("满员或资源不足")
				var m = member("xuwei" if id == "N-X08" else "luzhi","许卫" if id == "N-X08" else "陆芷",[80,20,45,40,35 if id == "N-X08" else 55,35,35,55 if id == "N-X08" else 35],"B" if id == "N-X08" else "A")
				m.joined = s.day; s.members.append(m); s.daily.hours += 1
			elif o == 1:
				if id == "N-X08":
					if not pay({"water":2,"food":2}): return false
					_stat("elin","trust",3)
				else:
					if not pay({"parts":2}): return false
					_repair(8); s.daily.hours += 1
			s.facts["father_ready" if id == "N-X08" else "luzhi_ready"] = false
		_: return fail("未实现的人物卡："+id)
	return true

func camp(action: String, args: Dictionary = {}) -> bool:
	if s.phase != "camp" or s.daily.camp_used: return fail("唯一营地行动已使用")
	if not s.daily.get("camp_checked",false):
		s.daily.camp_action = action; s.daily.camp_role = args.get("role","repair"); s.daily.camp_args = args.duplicate(true)
		s.daily.camp_checked = true
		var id = "N-F01" if _eligible("N-F01") else _draw_card("camp",35)
		if id != "": s.daily.card = id; s.phase = "camp_event"; return true
	var result = super.camp(action,args)
	if result:
		if action in ["read","teach","record"]: s.facts.quiet_nights = 0; s.facts.any_teaching = action == "teach" or s.facts.get("any_teaching",false)
		if action == "rest": s.facts.quiet_nights = int(s.facts.get("quiet_nights",0))+1
	return result

func _camp_effect(id: String, o: int, target: Dictionary, args: Dictionary) -> bool:
	var n = int(id.substr(1)); var pending = s.daily.get("camp_args",{}).duplicate(true)
	var role = str(pending.get("role","repair")); var student = person(str(pending.get("target",target.id)))
	if student.is_empty(): student = target
	var original_action = str(s.daily.camp_action)
	if n <= 5 or n >= 27:
		s.phase = "camp"
		if not super.camp(original_action,pending): return false
		s.phase = "camp_event"
	else:
		if not _camp_replacement(2): return false
	match n:
		1:
			if o < 2:
				if not _note("刹车缺页编号" if o == 1 else "刹车补页",1): return false
				if o == 1: s.facts.brake_number = true
				else: s.facts.brake_missing = not chance(70)
			else: student.understanding[role] = mini(100,student.understanding.get(role,0)+1)
		2:
			if o < 2:
				if not pay({"medicine":1}): return false
				var p = (45 if s.facts.get("dose_failed",false) else 60) if o == 0 else 80
				if chance(p): heal(target,10 if o == 0 else 20); s.facts.local_dose = o == 1
				else:
					if o == 0: change(target,"health",-10); s.facts.dose_failed = true
				if o == 1: s.daily.hours += 1
			else: _stat("elin","trust",-2)
		3:
			if o == 0: student.understanding.scout = mini(100,student.understanding.get("scout",0)+1); s.facts.next_u = -10
			elif o == 1: s.facts.water_point_until = s.day+3
			else:
				if not _note("地图双线",1): return false
				s.daily.hours += 1
		4:
			if o == 0:
				_faction("east",5); s.institution = maxi(0,s.institution-1)
				for m in people():
					if m.id != "captain" and m.group == "B": change(m,"trust",-2)
			elif o == 1: _institution(); _rebalance(2,0); _stat("sofia","trust",2)
			else:
				if not _note("并列配给规则",1): return false
				if chance(25): s.facts.ration_dispute_due = s.day+1
		5:
			if o == 0: student.understanding[role] = mini(100,student.understanding.get(role,0)+2); s.facts.next_teaching = 10
			elif o == 1:
				if chance(55): student.understanding[role] = mini(100,student.understanding.get(role,0)+1)
			else:
				s.daily.hours += 1
				if chance(85 if s.facts.get("comparison_failed",false) else 70): s.knowledge = mini(100,s.knowledge+1); s.facts.calibrated_copy = true
				else: s.facts.comparison_failed = true
		6:
			if o == 0:
				if not teach("zhang",student.id,"repair"): return false
			elif chance(85 if o == 1 else 40): change(student,"repair",3); student.understanding.repair = mini(100,student.understanding.get("repair",0)+5); s.knowledge = mini(100,s.knowledge+1)
			else: damage_car(2); change(student,"fatigue",10)
		7:
			if o < 2:
				var learner = "sofia" if o == 0 else "ajie"
				if not teach("elin",learner,"medical"): return false
				if person(learner).training.get("medical",0) > 0: s.facts.basic_nursing = true
			else: s.facts.teaching_promise = true
		8,9,10:
			if o < 2:
				var teacher = "ajie" if n == 8 else ("sofia" if n == 9 else str(pending.get("teacher","zhang")))
				var taught_role = "scout" if n == 8 else ("logistics" if n == 9 else role)
				if not teach(teacher,student.id,taught_role): return false
				if o == 1: s.daily.hours += 1
				if n == 8: s.facts.next_u = -5
				if n == 9 and student.training.get("logistics",0) > 0: _institution()
			else:
				if n == 10:
					all_change("fatigue",-10); s.facts.cancelled_teaching = int(s.facts.get("cancelled_teaching",0))+1
					if s.facts.cancelled_teaching >= 2: s.facts.knowledge_loss_due = s.day+1; s.facts.cancelled_teaching = 0
				else: s.knowledge = mini(100,s.knowledge+1)
		11,12,13,14,15:
			if o < 2:
				var points = (4 if o == 0 else 3) if n in [11,14] else (4 if o == 0 else (2 if n == 12 else 1))
				if n == 15: points = 4
				if not _note(content.cards[id].title+str(s.legs),points): return false
				if n == 11 and not chance(90 if o == 0 else 98): s.facts.next_u = 5
				if n == 12: s.facts.next_risk = -10 if o == 0 else -5
				if n == 14:
					if chance(85 if o == 0 else 95): s.facts.radio = s.facts.get("radio",0)+1
				if n == 15:
					if o == 0: _institution()
					else: _rebalance(2 if chance(75) else -2,-2)
			else:
				if n == 13: s.pending.append({"kind":"knowledge_forget","day":s.day+2,"target":target.id})
				if n == 15: all_change("trust",1); s.pending.append({"kind":"rule_forget","day":s.day+7,"target":target.id})
		16,17,18,19,20:
			var faction = str(args.get("faction",s.contacts[0] if not s.contacts.is_empty() else "guild"))
			if o == 2:
				if n in [16,19]: _faction(faction,-1)
				return true
			if n == 16:
				if o == 0:
					if s.books.repair <= 0: return fail("没有实体技术手册")
					s.books.repair -= 1; gain({"medicine":2})
				else:
					if s.records.is_empty(): return fail("没有实体可读抄本")
					s.records.pop_back(); gain({"medicine":1})
			elif n == 17:
				if o == 0:
					if s.books.scout <= 0: return false
					s.books.scout -= 1
				elif s.pages >= 1: s.pages -= 1
				else: return false
				if chance(70 if o == 0 else 85): s.facts.water_point_until = s.day+3
				else: s.facts.next_u = 10
			elif n == 18:
				if s.pages < 1: return false
				s.pages -= 1; gain({"parts":3 if o == 0 else 1})
				if o == 0: _institution()
				if o == 0 and not chance(70): s.facts.ration_dispute_due = s.day+1
			elif n == 19:
				if o == 0:
					if s.records.is_empty(): return false
					s.records.pop_back(); gain({"water":10})
					if chance(75): s.knowledge = mini(100,s.knowledge+2); _faction(faction,2)
				else:
					if s.pages < 1: return false
					s.pages -= 1; gain({"water":5})
			elif n == 20:
				if o == 0:
					if not pay({"parts":3}): return false
					s.daily.camp_used = false; s.phase = "camp"
					if not super.camp(original_action,pending): return false
					s.daily.hours -= 2; s.phase = "camp_event"; return true
				else: _faction(faction,-3 if chance(65) else -5); return true
			s.trades += 1; _faction(faction,5)
		21,22,23,24,25:
			var book = {21:"repair",22:"scout",23:"logistics",24:"medical",25:"copy"}[n]
			if o == 0:
				if book == "copy":
					if s.records.is_empty(): return false
					s.records.pop_back(); s.knowledge = maxi(0,s.knowledge-5)
				else:
					if s.books.get(book,0) < 1: return false
					if n in [21,22]: s.books[book] -= 1
					if book not in s.records and n == 21: s.knowledge = maxi(0,s.knowledge-5)
					if n == 22 and not chance(50): s.facts.next_u = 15
				all_change("fatigue",-10 if n in [21,22,25] else -5)
			elif o == 1:
				if n == 23:
					if s.pages < 1: return false
					s.pages -= 1; s.daily.hours += 1
					if not chance(80): s.knowledge = maxi(0,s.knowledge-1); s.private_risk = mini(100,s.private_risk+3)
				elif n == 25 and not chance(75): s.knowledge = maxi(0,s.knowledge-3); s.records.clear()
				all_change("fatigue",-5)
			else: all_change("fatigue",10)
		26:
			if o == 0: all_change("fatigue",-20)
			elif o == 1:
				for m in people():
					if m.health < 50: change(m,"health",10); change(m,"fatigue",-20)
					else: change(m,"fatigue",-10)
			else:
				for m in people(): change(m,"fatigue",20 if m.id == target.id else -20)
			if not chance([70,85,95][mini(o,2)]): s.tracking = mini(100,s.tracking+10)
		27:
			if o == 0: all_change("fatigue",-10)
			elif o == 1: change(target,"like",-2)
			else: s.daily.hours += 1; all_change("like",2)
		28:
			if o == 0:
				_stat("ajie","fatigue",10)
				if chance(35): s.facts.next_u = 10
			elif o == 1:
				if not _note("无线电梦境校准",1): return false
				s.facts.radio_accuracy = 95
			else: all_change("fatigue",-10); s.facts.radio_off = true
		29:
			if o == 0:
				if on_foot(): all_change("fatigue",10)
				elif not pay({"fuel":2}): return false
				s.daily.hours += 2; s.tracking = maxi(0,s.tracking-20); s.facts.next_event_rate = 10
			elif o == 1:
				if chance(80): s.facts.next_event_mod = -10
				else: s.facts.next_u = 10
			else: all_change("fatigue",-20); s.facts.next_event_mod = 15
		30:
			if o == 0: all_change("trust",2); all_change("fatigue",-10); s.facts.quiet_nights = 0
			elif o == 1:
				if not _note("今晚的沉默",1): return false
				s.facts.panic = true
			else:
				all_change("fatigue",-20); s.facts.quiet_nights = int(s.facts.get("quiet_nights",0))+1
				if s.facts.quiet_nights >= 3:
					s.facts["knowledge_loss_due" if chance(50) else "ration_dispute_due"] = s.day+1; s.facts.quiet_nights = 0
		_: return fail("未实现的营地卡："+id)
	if n <= 20: s.facts.quiet_nights = 0
	return true

func device(id: String) -> bool:
	if s.phase not in ["stop","camp"]: return false
	if id == "water":
		if not has_mod("SP04") or "purifier" in s.daily.used or not (s.daily.weather == "雨" or s.position == "避难点"): return fail("净水箱需雨或已确认淡水源，每日一次")
		if not _device_power(): return false
		gain({"water":3}); s.daily.used.append("purifier")
	elif id == "cold":
		if not has_mod("SP27") or "cold" in s.daily.used: return false
		if not _device_power(): return false
		s.facts.cold_until = s.day+1; s.daily.used.append("cold")
	elif id == "lure":
		if not has_mod("SP30") or "assist" in s.daily.used or not pay({"parts":1}): return false
		s.tracking = maxi(0,s.tracking-10); s.exposure = mini(100,s.exposure+5); s.daily.hours += 0.5; s.daily.used.append("assist")
	else: return false
	return true

func _device_power() -> bool:
	if "power" not in s.daily.used and (s.daily.get("charged",false) or s.daily.get("sun",false)):
		s.daily.used.append("power"); return true
	return pay({"fuel":1})

func _opportunity_effect(id: String, o: int, target: Dictionary, args: Dictionary) -> bool:
	match id:
		"S01":
			if o == 0:
				if not _camp_replacement(2): return false
				_stat("ajie","trust",5); _stat("sofia","trust",5); s.facts.broken_promise = false
			elif o == 1: _stat("ajie","trust",-5); _stat("sofia","trust",-5); s.facts.ration_dispute_due = s.day+1
			else: _stat("ajie","trust",10); _stat("sofia","trust",-10)
		"S02":
			var amount = floori(s.resources.food/3.0)
			if has_mod("SP28") and "antitheft" not in s.daily.used: amount = maxi(0,amount-3); s.daily.used.append("antitheft")
			s.resources.food -= amount; s.facts.theft_done = true
			if o == 0:
				s.daily.hours += 1
				if chance(90 if not qualified("logistics").is_empty() else 70): gain({"food":amount}); all_change("trust",-1); change(target,"trust",-4)
				else: all_change("trust",-5)
			elif o == 1:
				if not pay({"food":mini(5,people().size())}): return false
				s.daily.food_prepaid = mini(5,people().size()); _institution()
			else: change(target,"trust",-3); s.private_risk = mini(100,s.private_risk+2); _stat("sofia","trust",-5)
		"S03":
			if o == 0:
				s.daily.hours += 1; _rebalance(3,-2); s.knowledge = mini(100,s.knowledge+2); s.facts.evacuation_record = true
			elif o == 1: _stat("ajie","trust",10); _stat("sofia","trust",-5)
			else: all_change("trust",-5); _rebalance(-3,0)
		"S04": return _person_effect(id,o,target,args)
		"S05":
			if o == 0:
				for key in ["repair","medical","scout"]: s.books[key] += 2
			elif o == 1:
				if not _camp_replacement(2) or not _note("学校三种验证方法",10): return false
				for key in ["repair","medical","scout"]: s.books[key] += 1; target.understanding[key] = mini(100,target.understanding.get(key,0)+10)
			else: _stat("elin","trust",-5)
		"R01":
			if "guild" not in s.contacts: s.contacts.append("guild")
			if o == 0:
				if not _trade("guild",int(args.get("offer",0))): return false
				s.daily.hours += 1
			elif o == 1: _stat("sofia","trust",-1)
			else:
				if not pay({"fuel":3}): return false
				s.daily.hours += 1
		"R02":
			if o == 0:
				if not pay({"water":3,"food":3}): return false
				_stat("elin","trust",3); _faction("east",5)
			elif o == 1:
				if not pay({"water":2,"food":2}): return false
				s.position = "避难点"; s.daily.hours += 2; all_change("fatigue",5); s.facts.father_ready = true
				s.pending.append({"kind":"father","day":s.day+1,"target":"captain"})
			else: _stat("elin","trust",-5)
		"R03":
			if o == 0:
				gain({"food":8}); s.daily.hours += 1
				if chance(20 if s.daily.noise < 50 else 35):
					if s.resources.food >= 3: pay({"food":3})
					else: change(target,"health",-10)
				s.daily.supply_claimed = true
			elif o == 1:
				s.daily.hours += 2
				if chance(60): gain({"fuel":20})
				s.daily.supply_claimed = true
			else: s.daily.noise = maxi(0,s.daily.noise-10); s.tracking = maxi(0,s.tracking-10)
		"R04":
			if o < 2: gain({"medicine":3 if o == 0 else 2}); s.daily.hours += 1 if o == 0 else 0.5; s.daily.supply_claimed = true
			if o == 0: _stat("elin","health",-10)
			if o == 2: _stat("elin","trust",-8)
		"R05":
			if o == 0: _faction("east",5); s.daily.hours += 0.5
			elif o == 1: s.facts.false_registration = true
			else:
				if not pay({"fuel":3}): return false
				s.daily.hours += 2
		"R06":
			if o == 0: gain({"parts":12,"food":6}); s.daily.hours += 1
			elif o == 1: gain({"parts":8,"food":4}); s.daily.hours += 3; all_change("trust",5); all_change("like",2)
			else: gain({"parts":10}); all_change("trust",2); s.daily.hours += 1
			s.facts.old_marker = true; s.facts["wreck_"+str(s.legs)] = true
		"R07":
			if o < 2:
				if not pay({"water":8,"medicine":1} if o == 0 else {"water":8}): return false
				_faction("south",20 if o == 0 else 10)
				if o == 0: _repair(15)
				s.position = "避难点"
			else: _stat("elin","trust",-3)
		"R08":
			if o in [0,1]:
				if not pay({"water":5,"food":5}): return false
				if o == 0: s.position = "避难点"; s.daily.hours += 2; all_change("fatigue",5); _stat("elin","trust",5); _faction("east",10); s.facts.luzhi_ready = true; s.daily.card_candidates.append("N-X09")
				else: _stat("elin","trust",3)
			elif o == 2:
				if not pay({"fuel":2}): return false
				_stat("elin","trust",-8)
			else: s.daily.hours += 1; s.exposure = mini(100,s.exposure+2); _stat("elin","trust",1)
		_: return fail("未实现的停歇卡："+id)
	return true

func _rebalance(low: int, high: int) -> void:
	var a = []; var b = []; var av = 0.0; var bv = 0.0
	for m in people():
		if m.id == "captain": continue
		if m.group == "A": a.append(m); av += m.trust
		else: b.append(m); bv += m.trust
	if a.is_empty() or b.is_empty(): return
	var lower = a if av/a.size() <= bv/b.size() else b
	for m in people():
		if m.id != "captain": change(m,"trust",low if m in lower else high)
