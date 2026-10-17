extends "res://src/game/card_rules.gd"
## Map, request deadlines, cargo and fixed story orchestration. All are serialized.
const GOAL_ACTIONS = {"E02":"申请留在安全避难点","E03":"向盟友正式申请加入","E04":"接受黑旗集结，组织下一次掠夺","E05":"支付食物5零件2，建立强制秩序","E06":"支付水5食5，登记长期商路","E07":"在可居住点正式建点","E08":"为全队办理共同定居","E11":"独自办理定居","E12":"和妹妹一起留在南边","E13":"穿过已验证的巡游空隙，约定守规行进"}
const DEPARTURE_REQUESTS = ["M01","M02","M09","M12"]
const INQUIRIES = {"M01":[1],"M05":[1],"M09":[1],"T01":[1],"T03":[1],"T04":[1],"T05":[1],"T06":[1],"T07":[1],"T08":[1],"T09":[1],"T10":[1],"T11":[1],"T12":[1],"T13":[1],"T14":[1],"T15":[1]}
const ENV_EVENTS = {
	"EV01":{"title":"低速碰撞","text":"路肩有一辆横着的空车。刹车距离已经不够，驾驶者和主车将承受普通碰撞伤害。缓冲前挡架可分别减少车损4、驾驶者伤害5。","options":[{"key":"0","text":"制动避让","raw":"燃料2、耗时1小时，人员和车辆无伤。"},{"key":"1","text":"承受低速碰撞","raw":"主车耐久−8、所选驾驶者健康−10；SP12减车损4、驾驶者伤害5。"}]},
	"EV02":{"title":"普通散落物路障","text":"这是能清除的废铁与石块，前方仍然有通路。它与封死隧道不同。","options":[{"key":"0","text":"清障","raw":"零件4、燃料1、车损2、1小时；SP13使零件4改2。"},{"key":"1","text":"沿支路绕开","raw":"燃料3、2小时，人员无伤。"}]},
	"EV03":{"title":"油桶破损","text":"后挂旁的油桶已经裂开。本场景只有一次被动漏油损失；防漏发动机可保护至多3升。","options":[{"key":"0","text":"停下整理","raw":"零件1、1小时，保住燃料，人员无伤。"},{"key":"1","text":"舍弃破桶继续","raw":"被动损失燃料5；SP17全车每日一次，减至燃料2。"}]},
	"EV04":{"title":"扎胎前的铁片","text":"车轮前有散落铁片。普通爆胎概率40%；SP20减为20%，若爆胎则修胎零件3改1。只判一次，不防断轴。","options":[{"key":"0","text":"停下检查","raw":"耗时1小时，避开铁片，无额外判定。"},{"key":"1","text":"继续并准备修胎","raw":"一次爆胎判定；爆胎才耗零件3（SP20为1）、2小时。"}]},
	"EV05":{"title":"核对岔路","text":"地图上的支路与路牌不一致。只有选择实际验证时判一次U；扫描天线或观察台对同一判定只取一个−15。","options":[{"key":"0","text":"按已知主路","raw":"耗时1小时，维持当前主边进度，无侦察判定。"},{"key":"1","text":"验证支路","raw":"U=40−floor(合格侦察能力/5)，无岗另+10；失败额外2小时/燃料3，SP21改1小时/燃料2，徒步改疲劳+10。"}]},
	"EV06":{"title":"雨落在书箱上","text":"雨从车门缝灌进来。档案箱只保护事先放入的两册指定实体。","options":[{"key":"0","text":"停车收好书","raw":"耗时1小时，所有实体书保全。"},{"key":"1","text":"保人，继续前进","raw":"未被SP29保护的所选书受潮，当日不能阅读；已经保存于场外的抄本与主线历史不受影响。"}]},
	"EV07":{"title":"闷热中的食物","text":"箱中的食物开始变味。正在运行的冷链只保护事先装入的至多4份食物。","options":[{"key":"0","text":"就地挑拣","raw":"耗时1小时，损失食物2；生效冷链可保护实际装入的份额。"},{"key":"1","text":"尽快离开","raw":"损失食物5；生效冷链可保护实际装入的至多4份。"}]}}

func _draw_day() -> void:
	# Reopen a crisis only after its original cause has actually disappeared.
	for id in s.card_history:
		var h = s.card_history[id]
		if h.get("closed",false):
			expiry_mode = true
			var still_present = super._eligible(id)
			expiry_mode = false
			if not still_present: h.closed = false; h.cycle = 0
	s.daily.light = false
	s.daily.sealed = not s.facts.get("food_smell",false)
	s.daily.cold = 0
	s.daily.person_queue = []
	s.daily.device_requests = []
	s.daily.travel_start = {"legs":s.legs,"edge":s.edge_km,"distance":s.distance}
	s.daily.map_choice = "road"
	s.daily.mainline_choice = ""
	s.facts.radio_off = false
	if int(s.facts.get("next_route_day",-100)) == int(s.day): s.daily.route = str(s.facts.next_route)
	if int(s.facts.get("next_safe_exclusion_day",-100)) == int(s.day): s.daily.safe_accident_exclusion = true
	super._draw_day()
	if s.ending != "": return
	s.daily.cold = (2 if people().any(func(m): return m.health <= 30) else 1) if s.daily.weather in ["雨","沙尘"] else 0
	# Facts below describe visible map features, not free supplies or arrival.
	s.facts.warehouse = s.legs in [2,5,8,11,14]
	s.facts.fuel_depot = s.legs in [2,5,8,11,14]
	if s.legs in [3,6,9,12,15]: s.facts.old_marker = true
	s.facts.visible_pursuit = s.tracking >= 50 and s.facts.get("pursuit_warning",false)
	if s.tracking >= 40: s.facts.pursuit_warning = true; log_event("后方有跟随痕迹。追踪达到50后可能看见追兵；迎击将造成重伤。")
	if s.split_nights == 1: log_event("群体信任差已持续一夜；今晚若仍≥30，将必须决定调停或分流。")
	log_event("地图：当前章安全接纳点6千米；"+("废车点8千米已知；" if s.facts.get("wreck_"+str(s.legs),false) else "废车点尚未定位；")+"主边剩余%.0f千米。" % (30-s.edge_km))
	if s.day == 8: log_event("救援前提示：9/10日南线供给为燃料/零件，务必提前保留药品2。")
	_process_memory_due()

func prepare(action: String, target: String = "captain") -> bool:
	var hours_before = s.daily.hours
	if not super.prepare(action,target): return false
	if action == "none": s.daily.hours = hours_before
	if action == "water": s.facts.water_mornings = int(s.facts.get("water_mornings",0))+1
	else: s.facts.water_mornings = 0
	return true

func social(action: String, target: String = "", faction: String = "east", offer: int = 0) -> bool:
	if action == "proposal_talk":
		if not living(target) or not s.facts.get("departure_proposal_"+target,false) or not use_task(): return false
		change(person(target),"trust",10); s.facts.erase("departure_proposal_"+target); return true
	if action == "listen" and int(s.facts.get("listened_"+target,-100))+3 > int(s.day): return fail("同一话题须间隔三日后再谈")
	if action == "raid":
		var h = s.card_history.get("N-C01",{"count":0,"last":-100})
		if h.count >= 3 or int(s.day)-int(h.last) < 4: return fail("袭击运输员须间隔3个完整日，每局最多3次")
		if faction not in s.contacts or s.factions[faction] <= -30: return fail("此处没有愿意接近的中立运输员")
	if not super.social(action,target,faction,offer): return false
	if action == "raid": _remember("N-C01"); s.daily.used.append("raid")
	if action == "listen": s.facts["listened_"+target] = s.day
	return true

func depart(id: String, safe: bool) -> void:
	if living(id) and id != "captain": s.daily.someone_departed = true
	super.depart(id,safe)

func intel(action: String) -> bool:
	if s.day == 8 and action == "south" and s.daily.tasks >= 2: return fail("南线侦察占一项主要事务，今天已满")
	if not super.intel(action): return false
	if s.day == 8 and action == "south": s.daily.tasks += 1
	return true

func mainline(choice: String) -> bool:
	if s.phase != "route" or s.day not in IMPORTANT or s.daily.mainline_choice != "": return fail("本日主线选择已确认，或当前不是重要日路线阶段")
	match s.day:
		2:
			if choice == "frequency":
				if not intel("frequency"): return false
				s.goal = "south"
			elif choice in ["east","independent"]: s.goal = choice
			else: return false
		5:
			if choice == "rescue":
				if "frequency" not in s.clues and not intel("frequency"): return false
				s.goal = "south"
			elif choice != "continue": return false
		8:
			if choice == "rescue":
				if "entrance" not in s.clues and not intel("south"): return false
				s.goal = "south"
			elif choice not in ["east","guild","independent"]: return false
			else: s.goal = choice
		_:
			if choice not in ["south","east","guild","independent","shadow","continue"]: return false
			if choice != "continue": s.goal = choice
	s.daily.mainline_choice = choice
	s.facts["mainline_"+str(s.day)] = choice
	log_event("主线意向："+choice+"。需实际行进、支付与完成登记才能收束。")
	return true

func rescue(action: String) -> bool:
	if action == "inspect":
		if s.phase != "rescue" or s.legs < 6 or s.clues.size() < 3 or on_foot(): return fail("尚未实际抵达救援站外并确认现场")
		s.facts.rescue_site_confirmed = true
		log_event("已在站外确认妹妹病危受困、污染警示与撤离困难。门槛不足时强闯无法有效救护，会造成妹妹死亡。")
		return true
	if action == "force" and (not s.facts.get("rescue_site_confirmed",false) or rescue_missing().is_empty()): return fail("只有到站确认病危且准备不足时，才存在这个强闯坏选项")
	if action in ["abandon","missing"]:
		if s.phase != "rescue": return false
		s.sister = "abandoned" if action == "abandon" else "missing"
		s.phase = "route"
		log_event("明确放弃救援" if action == "abandon" else "承认未能完成，妹妹失联；不写确认死亡")
		return depart_route(str(s.daily.route),str(s.daily.style),str(s.daily.supply))
	var extra_fuel = 4*(cars().size()-1) if action in ["quiet","frontal"] else 0
	if s.resources.fuel < 12+extra_fuel and action in ["quiet","frontal"]: return fail("救援主车油12，随行副车另需基础油4")
	var result = super.rescue(action)
	if result and extra_fuel > 0: pay({"fuel":extra_fuel})
	return result

func preset(id: String, value: bool) -> bool:
	if s.phase not in ["morning","route","camp"]: return false
	if id == "light": s.daily.light = value
	elif id == "rain_chain":
		if s.daily.weather != "雨" or not has_mod("SP22"): return fail("需雨天且装有防滑链")
		s.daily.rain_chain = value
	elif id == "sealed":
		s.daily.sealed = value
		if value: s.facts.food_smell = false
	else: return false
	return true

func _eligible(id: String) -> bool:
	if id == "N-F01": return false # Night replacement only.
	if id == "T13": return living("sofia") and not s.facts.get("theft_ledger",{}).is_empty() and not s.facts.theft_ledger.get("resolved",false) and super._eligible_crisis_history(id)
	if id == "S02" and people().filter(func(m): return m.id != "captain" and m.health >= 30).is_empty(): return false
	if id == "N-F06": return s.facts.get("panic",false) and int(s.facts.get("panic_day",s.day)) <= int(s.day) and super._eligible_crisis_history(id)
	if id == "N-F03": return int(s.facts.get("forgiven",0)) >= 2 or int(s.facts.get("accounts_due",-100)) in [int(s.day),int(s.day)-1]
	if id == "M13": return living("sofia") and (int(s.facts.get("water_mornings",0)) >= 3 or s.institution >= 2) and not s.facts.get("public_rules",false) and super._eligible_crisis_history(id)
	if id == "M14": return living("sofia") and people().any(func(m): return m.joined > 1 and not m.get("registered",false) and not m.get("registration_seen",false))
	if id == "C28" and (not living("ajie") or s.facts.get("radio_off",false)): return false
	if id == "N-C02" and not s.facts.get("pursuit_warning",false): return false
	if id == "N-C03" and not s.facts.get("mechanical_warning",false): return false
	if id == "C01" and (car().get("durability",100) > 60 or not s.facts.get("brake_missing",false)): return false
	if id == "C02" and s.resources.medicine > 3 and lowest().get("health",100) > 40: return false
	if id == "C03" and not s.facts.get("yesterday_unknown",false): return false
	if id == "C04" and group_members("A").is_empty() or id == "C04" and group_members("B").is_empty(): return false
	if id in ["C06","C07","C08","C09"]:
		var roles = {"C06":"repair","C07":"medical","C08":"scout","C09":"logistics"}
		if s.daily.get("camp_role","") != roles[id]: return false
		if id == "C07" and lowest().get("health",100) > 50: return false
		if id == "C08" and s.facts.get("radio",0) == 0 and s.records.is_empty(): return false
		if id == "C09" and (not s.facts.get("public_rules",false) or not people().any(func(m): return m.joined > 1)): return false
	if id == "C10" and BOOKS.keys().filter(func(role): return not qualified(role).is_empty()).size() < 2: return false
	if id == "C12" and not s.daily.get("accident",false): return false
	if id == "C14" and s.daily.get("ordinary_signal",false) == false: return false
	if id == "C15" and s.institution < 2: return false
	if id == "C16" and s.resources.medicine > 2: return false
	if id == "C19" and s.records.is_empty(): return false
	if id == "C20" and s.factions.get(str(s.daily.get("camp_args",{}).get("faction","guild")),0) > 0: return false
	if id.begins_with("C2") and int(id.substr(1)) <= 25:
		var n = int(id.substr(1)); var cold = s.daily.get("cold",0)
		if cold < (2 if n == 21 else 1): return false
		if n == 21 and (s.resources.fuel >= 5 or s.books.repair < 1): return false
		if n == 22 and (car().get("durability",100) > 20 or s.books.scout < 1): return false
		if n in [23,24] and s.resources.fuel > 5: return false
		if n == 24 and (lowest().get("health",100) > 30 or s.books.medical < 1): return false
		if n == 25 and (s.records.size() != 1 or s.books.values().any(func(v): return v > 0)): return false
	if id == "C26" and people().any(func(m): return m.fatigue < 50): return false
	if id == "C27" and not s.members.any(func(m): return not m.alive and s.day-int(m.get("death_day",-10)) <= 3 and not m.get("memorial_done",false)): return false
	if id == "C29": return s.daily.get("camp_action","") == "rest" and s.tracking >= 40 and super._eligible(id)
	if id == "C30" and s.facts.get("quiet_nights",0) < 2: return false
	return super._eligible(id)

func _tier(id: String) -> int:
	if id in ["T13","V09","V10"]: return 2
	if id in ["C21","C22","C24"] or id == "C29" and s.tracking >= 70: return 2
	if id == "C29" or id == "C30": return 1
	return super._tier(id)

func group_members(group: String) -> Array:
	return people().filter(func(m): return m.id != "captain" and m.group == group)

func lower_group() -> String:
	var a = group_members("A"); var b = group_members("B")
	if a.is_empty(): return "B"
	if b.is_empty(): return "A"
	var av = 0.0; var bv = 0.0
	for m in a: av += m.trust
	for m in b: bv += m.trust
	return "A" if av/a.size() < bv/b.size() else "B"

func _build_person_pool() -> void:
	if s.daily.get("people_drawn",false): return
	s.daily.people_drawn = true; s.daily.card_candidates = []; s.daily.person_queue = []
	var backlog = s.facts.get("person_backlog",[]).duplicate(true)
	var by_person = {}
	for id in content.cards:
		if content.cards[id].pool != "person" or id in ["N-F01","N-F07","N-F10","N-X01","N-X02","N-X03","N-X04","N-X05"] or not _eligible(id): continue
		var owner = speaker(id)
		if not by_person.has(owner): by_person[owner] = []
		by_person[owner].append(id)
	for m in people():
		if m.joined <= 1: continue
		var pool = []
		for id in ["N-X03","N-X04","N-X05"]:
			var h = s.facts.get("request_history",{}).get(id+":"+m.id,{"count":0,"last":-100})
			if h.count >= 3 or int(s.day)-int(h.last) < 4: continue
			if id == "N-X03" and s.resources.water < people().size()*(2 if on_foot() else 1) and not m.get("water_cause_closed",false): pool.append(id)
			if id == "N-X04" and m.health >= 30 and m.fatigue < 80 and BOOKS.keys().any(func(role): return qualified(role).any(func(teacher): return teacher.id != m.id and teacher.understanding.get(role,0) >= 50)): pool.append(id)
			if id == "N-X05" and (m.trust <= 35 or not m.get("registered",false)): pool.append(id)
		if not pool.is_empty():
			if not by_person.has(m.id): by_person[m.id] = []
			by_person[m.id].append_array(pool)
	for owner in by_person:
		var top = 0
		for id in by_person[owner]: top = maxi(top,_tier(id))
		var pool = by_person[owner].filter(func(id): return _tier(id) == top)
		var carried = backlog.filter(func(row): return row.owner == owner and row.id in pool and int(row.first) >= int(s.day)-1)
		if not carried.is_empty():
			_add_request(str(carried[0].id),owner,int(carried[0].first))
		elif chance([35,70,100][top]): _add_request(str(pool[rng.randi_range(0,pool.size()-1)]),owner,s.day)
	# A crisis that lost this character's tie must still have a visible deadline.
	for owner in by_person:
		for id in by_person[owner]:
			if _tier(id) == 2 and not s.daily.person_queue.any(func(row): return row.id == id and row.owner == owner):
				s.daily.person_queue.append({"id":id,"owner":owner,"first":s.day,"hidden":true})
	s.daily.person_queue.sort_custom(func(a,b):
		if _tier(a.id) != _tier(b.id): return _tier(a.id) > _tier(b.id)
		if (a.id in DEPARTURE_REQUESTS) != (b.id in DEPARTURE_REQUESTS): return a.id in DEPARTURE_REQUESTS
		return a.first < b.first if a.first != b.first else a.id < b.id)
	for row in s.daily.person_queue:
		if not row.get("hidden",false): s.daily.card_candidates.append(row.id)
		if _tier(row.id) == 2: log_event("到期提醒："+content.cards[row.id].title+"，"+("出发前" if row.id in DEPARTURE_REQUESTS else "今夜前")+"未回应将执行默认后果。")
	if by_person.values().any(func(ids): return "N-F06" in ids): _enter_panic()
	s.facts.person_backlog = []

func _add_request(id: String, owner: String, first: int) -> void:
	s.daily.person_queue.append({"id":id,"owner":owner,"first":first,"hidden":false})

func _expire_requests(departure: bool) -> void:
	for row in s.daily.get("person_queue",[]).duplicate(true):
		if (row.id in DEPARTURE_REQUESTS) != departure: continue
		if not departure and _tier(row.id) < 2 and int(row.first) == int(s.day):
			s.facts.person_backlog.append(row); continue
		_default_request(row)
		s.daily.person_queue.erase(row); s.daily.card_candidates.erase(row.id)
		if s.ending != "": return

func _default_request(row: Dictionary) -> void:
	var id = str(row.id); var target = person(str(row.owner))
	var sick = lowest()
	match id:
		"M01": _stat("zhang","trust",-4)
		"M02": _stat("zhang","trust",-2); _stat("sofia","trust",-2)
		"M03": s.facts.marker_resolved = true; log_event("旧标记留在原地，没有领取零件。")
		"M04","N-X04": change(target,"trust",-2)
		"M05","T05":
			if s.facts.get("fever_upgraded",false) or s.daily.get("fever_handled",false): return # N-F04 owns this patient/cause.
			if sick.get("health",100) <= 40:
				change(sick,"health",-10); _stat("elin","trust",-6); s.facts.delayed_care = true; s.facts.fever_upgraded = id == "M05"; s.facts.fever_target = sick.id
		"M06":
			var wounded = people().filter(func(m): return m.health <= 40)
			wounded.sort_custom(func(a,b): return a.health < b.health)
			for m in wounded.slice(0,2): change(m,"health",-10)
			_stat("elin","trust",-6); s.facts.delayed_care = true
		"M07": _stat("elin","trust",-3); s.facts.delayed_care = true
		"M13": _stat("sofia","trust",-4)
		"M14":
			for m in people():
				if m.joined > 1 and not m.get("registered",false) and not m.get("registration_seen",false):
					change(m,"trust",-2); m.registration_seen = true; _queue_proposal(m); break
		"M15": s.private_risk = mini(100,s.private_risk+1); _stat("sofia","trust",-3)
		"T01":
			_stat("zhang","trust",-5); s.facts.front_unrepaired = true
			s.pending.append({"kind":"fatigue","target":"zhang","amount":10,"day":s.day+1})
		"T02","T07","T10","N-F05":
			if id == "N-F05": target = person(str(s.facts.get("rest_target","elin")))
			if id != "T02" and not (id == "N-F05" and int(s.facts.get("rest_penalty_covered_day",-100)) == int(s.day)):
				change(target,"trust",-3 if id == "T10" else (-4 if id == "T07" else -5))
			change(target,"fatigue",10)
			if id == "T02": change(target,"health",-10); _refuse_zhang_rest()
			if id == "T10": target.scout_penalty_day = s.day+1
			if id != "N-F05": s.facts.rest_refused_day = s.day; s.facts.rest_target = row.owner
		"T03": _stat("zhang","trust",-4); s.facts.front_unrepaired = true
		"T04","T08","T09","T11": change(target,"trust",-3)
		"T12": _stat("ajie","trust",-3); s.facts.private_map = true
		"T13": _stat("sofia","trust",-3); s.private_risk = mini(100,s.private_risk+5)
		"T14": s.facts.panic = true
		"T15":
			var pool = people().filter(func(m): return m.id != "captain")
			pool.sort_custom(func(a,b): return a.trust < b.trust)
			if not pool.is_empty(): s.pending.append({"kind":"depart","target":pool[0].id,"day":s.day+1})
		"N-F02": all_change("trust",-5); all_change("like",-8); s.facts.ration_dispute_due = 0
		"N-F03": s.private_risk = mini(100,s.private_risk+5); _stat("sofia","trust",-3)
		"N-F04":
			s.daily.fever_handled = true
			var patient = person(str(s.facts.get("fever_target",sick.get("id","captain"))))
			change(patient,"health",-15); _stat("elin","trust",-8)
			if patient.get("health",0) > 0: s.pending.append({"kind":"damage","target":patient.id,"amount":-5,"day":s.day+1})
			s.facts.fever_upgraded = false; s.facts.delayed_care = false
		"N-F06":
			_enter_panic()
			all_change("trust",-2); all_change("like",-1); s.facts.panic = false
		"N-F08": _faction("east",-5); s.daily.hours += 1; s.facts.false_registration = false
		"N-X05": change(target,"trust",-4); change(target,"like",-2)
		"N-X06": _stat("sister","fatigue",10); _stat("sister","like",-3)
	_remember(id)
	if id in ["M01","M02"]: s.card_history[id].closed = int(s.card_history[id].get("cycle",0)) >= 2
	_check_deaths(false)
	log_event("未回应到期："+content.cards[id].title+"（默认后果已结算一次）")

func _enter_panic() -> void:
	if s.daily.get("panic_entered",false): return
	s.daily.panic_entered = true
	if chance(50 if lowest().get("health",100) <= 40 else (20 if s.facts.get("panic_honest",false) else 35)):
		all_change("trust",-3); all_change("like",-2)
	s.facts.panic = false

func _enter_theft() -> void:
	if not s.facts.get("theft_ledger",{}).is_empty(): return
	var suspects = people().filter(func(m): return m.id != "captain" and m.health >= 30)
	suspects.sort_custom(func(a,b): return a.trust < b.trust if a.trust != b.trust else a.id < b.id)
	if suspects.is_empty(): return
	normalize_cargo()
	var stolen = floori(s.resources.food/3.0)
	var protected = 0
	if "antitheft" not in s.daily.used:
		for v in cars():
			if has_mod("SP28",v): protected += mini(3,int(v.cargo.get("food",0)))
	protected = mini(stolen,mini(3,protected))
	s.resources.food -= stolen-protected
	s.daily.used.append("antitheft")
	s.facts.theft_ledger = {"resource":"food","amount":stolen-protected,"owner":suspects[0].id,"resolved":false,"day":s.day}
	s.facts.theft_done = true
	log_event("清点失窃：食物%d，防盗箱保住%d；实际扣%d，已登记待追索账。" % [stolen,protected,stolen-protected])

func _queue_proposal(m: Dictionary) -> void:
	if m.is_empty() or m.id == "captain": return
	s.pending.append({"kind":"proposal","target":m.id,"day":s.day+1})

func _note(label: String, knowledge: int = 4, pages: int = 1) -> bool:
	if not s.notebook: return fail("没有可写入的实体笔记本")
	var fresh = label not in s.records
	if not super._note(label,knowledge,pages): return false
	if not s.facts.has("record_values"): s.facts.record_values = {}
	if fresh: s.facts.record_values[label] = knowledge
	return true

func lose_unrecorded(amount: int) -> void:
	var protected = 0
	for value in s.facts.get("record_values",{}).values(): protected += int(value)
	s.knowledge -= mini(amount,maxi(0,int(s.knowledge)-protected))

func camp(action: String, args: Dictionary = {}) -> bool:
	if s.phase == "camp" and not s.daily.camp_used and s.facts.get("knowledge_loss_due",0) == s.day:
		s.daily.camp_action = "knowledge_loss"; s.daily.camp_args = args.duplicate(true); s.daily.card = "N-F01"; s.phase = "camp_event"; return true
	if s.phase == "camp" and not s.daily.camp_used:
		if action == "read" and int(s.facts.get("wet_"+str(args.get("role","repair")),-1)) == int(s.day): return fail("这册书今天受潮，次日才能阅读")
		# Validate the underlying action before any event can reserve its slot.
		var validator = load("res://src/game/rules.gd").new()
		validator.restore(checkpoint())
		if not validator.camp(action,args): return fail(validator.error)
	var result = super.camp(action,args)
	if result and s.daily.camp_used:
		if action == "burn_book": s.daily.cold = 0
		if action == "read": s.facts.last_reader = args.get("target","captain")
		if action == "record":
			if not s.facts.has("record_values"): s.facts.record_values = {}
			s.facts.record_values[str(args.get("label","共同配给规则"))] = 4
		if action == "rest" and s.daily.sealed: s.facts.food_smell = false
	return result

func _camp_effect(id: String, o: int, target: Dictionary, args: Dictionary) -> bool:
	var n = int(id.substr(1)); var pending = s.daily.get("camp_args",{})
	var role = str(pending.get("role","repair")); var student = person(str(pending.get("target",target.id)))
	if student.is_empty(): student = target
	if n < 6 or n > 25:
		var result = super._camp_effect(id,o,target,args)
		if result and n == 5 and o == 0: student["j_bonus_"+role] = 10
		if result and n == 1 and o == 0 and s.facts.get("brake_missing",false): s.facts.brake_fault_once = 5
		return result
	if not _camp_replacement(2): return false
	match n:
		6:
			if o == 0: return teach("zhang",student.id,"repair")
			var success = chance(85 if o == 1 else 40)
			if success:
				change(student,"repair",3); student.understanding.repair = mini(100,student.understanding.get("repair",0)+5)
				if o == 1: s.knowledge = mini(100,s.knowledge+1)
				else: change(student,"trust",4)
			else:
				damage_car(2)
				if o == 1: change(student,"fatigue",10)
				else: _stat("zhang","trust",-3)
		7:
			if o == 2: s.facts.teaching_promise = true; return true
			var who = "sofia" if o == 0 else "ajie"
			if not teach("elin",who,"medical"): return false
			if s.daily.get("last_teaching_success",false): person(who).basic_nursing = true; s.facts.basic_nursing = true
		8:
			if o == 2:
				s.knowledge = mini(100,s.knowledge+1); s.facts.next_u = -5; return true
			s.daily.j_modifier = 10 if o == 1 else 0
			if not teach("ajie",student.id,"scout"): return false
			if s.daily.get("last_teaching_success",false): s.facts.next_u = -5
			elif o == 0: _stat("ajie","fatigue",10)
			if o == 1: s.daily.hours += 1
		9:
			if o == 2: s.knowledge = mini(100,s.knowledge+1); change(student,"trust",-2); return true
			s.daily.j_modifier = 10 if o == 1 else 0
			if not teach("sofia",student.id,"logistics"): return false
			if s.daily.get("last_teaching_success",false):
				student.accurate_accounts = int(student.get("accurate_accounts",0))+1
				if o == 1: _institution()
			else: s.private_risk = mini(100,s.private_risk+2)
			if o == 1: s.daily.hours += 1
		10:
			if o == 2:
				all_change("fatigue",-10); s.facts.cancelled_teaching = int(s.facts.get("cancelled_teaching",0))+1
				if s.facts.cancelled_teaching >= 2: s.facts.knowledge_loss_due = s.day+1; s.facts.cancelled_teaching = 0
				return true
			var selected_role = role
			if o == 0:
				for key in BOOKS:
					if qualified(key).is_empty(): selected_role = key; break
			else:
				var highest = -1
				for key in BOOKS:
					if student[key] > highest: highest = student[key]; selected_role = key
				if not chance(60): s.daily.j_modifier = -15
			var teachers = qualified(selected_role).filter(func(m): return m.id != student.id and m.understanding.get(selected_role,0) >= 50)
			if teachers.is_empty(): return fail("该岗位目前没有合格教师，可选择休息")
			if not teach(teachers[0].id,student.id,selected_role): return false
			if o == 0:
				for key in BOOKS:
					for m in qualified(key):
						if m.id != teachers[0].id: change(m,"trust",-1)
		11:
			if o == 2:
				s.pending.append({"kind":"route_memory","day":s.day+1,"remaining":3,"label":"路线%d" % s.legs}); return true
			if not _note("路线%d" % s.legs,4 if o == 0 else 3): return false
			if not chance(90 if o == 0 else 98): s.facts.next_u = 5; s.facts.uncalibrated = true
		12:
			if o == 2: return true
			if not _note("失败经验%d" % s.legs,4 if o == 0 else 2): return false
			s.facts.next_risk = -10 if o == 0 else -5
		13:
			if o == 2: s.pending.append({"kind":"knowledge_forget","day":s.day+2,"target":target.id}); return true
			if not _note("纪念"+target.id,4 if o == 0 else 1): return false
		14:
			if o == 2: return true
			var accurate = chance(85 if o == 0 else 95)
			if not _note("普通频段%d" % s.day,(4 if o == 0 else 3) if accurate else 1): return false
			if accurate: s.facts.radio = int(s.facts.get("radio",0))+1
			else: s.facts.uncalibrated = true
		15:
			if o == 2: all_change("trust",1); s.pending.append({"kind":"rule_forget","day":s.day+7,"target":target.id}); return true
			if not _note("规矩修订%d" % s.institution): return false
			if o == 0: _institution()
			else: _rebalance(2 if chance(75) else -2,-2)
		16,17,18,19,20:
			return _exchange_event(n,o,pending)
		21,22,23,24,25:
			return _burn_event(n,o)
	s.facts.quiet_nights = 0
	return true

func _exchange_event(n: int, o: int, pending: Dictionary) -> bool:
	var faction = str(pending.get("faction",s.contacts[0] if not s.contacts.is_empty() else "guild"))
	if faction not in s.contacts or s.factions.get(faction,0) <= -30 or "trade_"+faction in s.daily.used: return fail("需要同处非敌视交易者，且今日尚未交易")
	if o == 2:
		if n in [16,19]: _faction(faction,-1)
		return true
	if n == 16:
		if o == 0:
			if s.books.repair < 1: return fail("没有技术手册")
			s.books.repair -= 1; gain({"medicine":2})
			if not s.records.any(func(label): return "维修" in label or "刹车" in label) and not chance(70 if not s.records.is_empty() else 40): lose_unrecorded(1)
		else:
			if s.records.is_empty(): return fail("没有可交付抄本")
			s.records.pop_back(); gain({"medicine":1})
	elif n == 17:
		if o == 0:
			if s.books.scout < 1: return false
			s.books.scout -= 1; lose_unrecorded(1)
		elif not _note("交换路线抄段",0): return false
		if chance(70 if o == 0 else 85): s.facts.water_point_until = s.day+3
		else: s.facts.next_u = 10
	elif n == 18:
		if not _note("向协作者介绍规则",0): return false
		gain({"parts":3 if o == 0 else 1})
		if o == 0:
			_institution()
			if not chance(70): s.facts.ration_dispute_due = s.day+1
		else: _faction(faction,3)
	elif n == 19:
		var resource = str(pending.get("resource","water"))
		if resource not in ["water","food","parts"]: return false
		if o == 0:
			if s.records.is_empty(): return false
			s.records.pop_back(); gain({resource:{"water":10,"food":8,"parts":4}[resource]})
			if chance(75): s.knowledge = mini(100,s.knowledge+2); _faction(faction,2)
		else:
			if not _note("传播短段",0): return false
			gain({resource:{"water":5,"food":4,"parts":2}[resource]})
	elif n == 20:
		if o == 0:
			if not pay({"parts":3}): return false
			var role = str(pending.get("role","repair")); var resource = str(pending.get("resource","water"))
			if s.books.get(role,0) < 1 or resource not in ["water","food","parts"]: return false
			s.books[role] -= 1; gain({resource:{"water":10,"food":8,"parts":4}[resource]})
		else:
			if chance(65): _faction(faction,-3)
			else:
				var role = str(pending.get("role","repair"))
				if s.books.get(role,0) < 1: return false
				s.books[role] -= 1; s.exposure = mini(100,s.exposure+1); _faction(faction,-5); s.facts["surcharge_"+faction] = true
			return true
	s.trades += 1; _faction(faction,5); s.daily.used.append("trade_"+faction)
	return true

func _burn_event(n: int, o: int) -> bool:
	var cold = int(s.daily.get("cold",0))
	if n == 21:
		if o == 0:
			if s.books.repair < 1: return false
			s.books.repair -= 1; s.daily.cold = 0; all_change("fatigue",-10); lose_unrecorded(5)
		elif o == 1:
			if not s.facts.get("brake_missing",false): return fail("没有真实废缺页")
			s.daily.cold = maxi(0,cold-1); all_change("fatigue",-5)
			if not chance(60): lose_unrecorded(1)
		elif o == 2:
			if s.facts.get("wood_used_"+str(s.legs),false): return fail("此处废木已用")
			s.facts["wood_used_"+str(s.legs)] = true; s.daily.cold = maxi(0,cold-1); all_change("fatigue",-5)
		else: s.daily.cold = maxi(0,cold-1); all_change("fatigue",10)
	elif n == 22:
		if o == 0:
			s.books.scout -= 1; s.daily.cold = 0; all_change("fatigue",-10)
			if not s.records.any(func(label): return "路线" in label) and not chance(75 if not s.records.is_empty() else 50): s.facts.next_u = 15; lose_unrecorded(1)
		elif o == 1: s.facts.water_point_until = 0; s.daily.cold = maxi(0,cold-1); all_change("fatigue",-5)
		else: all_change("fatigue",10)
	elif n == 23:
		if o == 0: lose_unrecorded(1); s.private_risk = mini(100,s.private_risk+3); all_change("fatigue",-5)
		elif o == 1:
			if not _note("账本保留页",0): return false
			s.daily.hours += 1; all_change("fatigue",-5)
			if not chance(80): lose_unrecorded(1); s.private_risk = mini(100,s.private_risk+3)
		else: all_change("fatigue",10)
		s.daily.cold = maxi(0,cold-1)
	elif n == 24:
		if o == 0:
			if s.facts.get("medical_blank_burned",false): return false
			s.facts.medical_blank_burned = true
		elif o == 1:
			if not s.records.any(func(label): return "医疗" in label) and not chance(85 if not s.records.is_empty() else 60): lose_unrecorded(1)
		else: all_change("fatigue",10); return true
		all_change("fatigue",-5); s.daily.cold = maxi(0,cold-1)
	elif n == 25:
		if o == 0: s.records.clear(); lose_unrecorded(5); all_change("fatigue",-10); s.daily.cold = 0
		elif o == 1:
			if not chance(75): s.records.clear(); lose_unrecorded(3)
			all_change("fatigue",-5); s.daily.cold = maxi(0,cold-1)
		elif o == 2:
			if s.facts.get("wood_used_"+str(s.legs),false): return fail("此处废木已用")
			s.facts["wood_used_"+str(s.legs)] = true; all_change("fatigue",10); s.daily.cold = 0
		else: pass # Actual cold damage is settled once at night.
	return true

func _remember(id: String) -> void:
	super._remember(id)
	if _tier(id) == 2:
		var h = s.card_history[id]; h.cycle = int(h.get("cycle",0))+1; h.closed = true
	if id in ["N-X03","N-X04","N-X05"]:
		var owner = str(s.daily.get("request_owner",speaker(id)))
		if not s.facts.has("request_history"): s.facts.request_history = {}
		var key = id+":"+owner
		var h = s.facts.request_history.get(key,{"count":0,"last":-100})
		h.count += 1; h.last = s.day; s.facts.request_history[key] = h

func resolve_card(id: String, option: int, args: Dictionary = {}) -> bool:
	if id in ENV_EVENTS: return resolve_environment(id,option,args)
	if option in INQUIRIES.get(id,[]): return fail("追问仅供阅读；阅读后仍须作最终答复")
	if option < 0 or option >= (5 if id == "V09" else content.cards.get(id,{}).get("options",[]).size()): return fail("没有这个选项")
	if id in ["M01","M02"] and s.phase != "morning": return fail("这项维修必须在晨间准备结束前回应")
	var resolved_args = args.duplicate(true)
	var row_index = -1
	var queue = s.daily.get("person_queue",[])
	for i in range(queue.size()):
		if queue[i].id == id and not queue[i].get("hidden",false):
			if row_index == -1 or queue[i].owner == args.get("target",""): row_index = i
	if row_index >= 0 and id.begins_with("N-X"): resolved_args.target = queue[row_index].owner
	if row_index >= 0: s.daily.request_owner = queue[row_index].owner
	if id in ["M05","T05","N-F04","S04"]: resolved_args.target = str(s.facts.get("fever_target",lowest().get("id","captain")))
	if id == "M14":
		for m in people():
			if m.joined > 1 and not m.get("registered",false) and not m.get("registration_seen",false): resolved_args.target = m.id; break
	if id == "M04":
		resolved_args.role = "repair"
		if person(str(resolved_args.get("target","captain"))).get("joined",1) <= 1:
			for m in people():
				if m.joined > 1: resolved_args.target = m.id; break
	if id in ["M06","M07"] and person(str(resolved_args.get("target","captain"))).get("health",100) > 40: resolved_args.target = lowest().id
	var before_hours = s.daily.hours
	var before_tasks = s.daily.tasks
	if id == "N-X09" and s.daily.get("r08_followup",false): s.daily.tasks = maxi(0,s.daily.tasks-1)
	var result = super.resolve_card(id,option,resolved_args)
	if not result: return false
	if row_index >= 0 and row_index < s.daily.person_queue.size(): s.daily.person_queue.remove_at(row_index)
	if id == "N-X09" and s.daily.get("r08_followup",false):
		s.daily.tasks = before_tasks; s.daily.r08_followup = false
	if id == "R08" and option == 0 and s.facts.get("luzhi_ready",false):
		s.daily.r08_followup = true; _add_request("N-X09","captain",s.day)
	if id in ["M03","M15","T12","T13"] and s.daily.hours == before_hours: s.daily.hours += 1
	if id == "N-X05" and option == 2: _queue_proposal(person(str(resolved_args.get("target",""))))
	if id == "T01" and option == 2: s.facts.repair_promise_due = s.day+1
	if id in ["M05","T05"] and option == 2: s.facts.fever_target = resolved_args.target
	if id == "T14" and option == 2: s.facts.panic_day = s.day+1
	if id == "T13" and option == 2: s.facts.accounts_due = s.day+1
	if id == "M01" and option == 2: s.card_history[id].closed = int(s.card_history[id].get("cycle",0)) >= 2
	if id in ["C26","C27","C28","C29"]: s.facts.quiet_nights = int(s.facts.get("quiet_nights",0))+1
	if id == "C27":
		for m in s.members:
			if not m.alive and not m.get("memorial_done",false) and s.day-int(m.get("death_day",-100)) <= 3:
				m.memorial_done = true
				if option == 0: s.facts.keepsakes = int(s.facts.get("keepsakes",0))+1
				break
	return true

func _person_effect(id: String, o: int, target: Dictionary, args: Dictionary) -> bool:
	if id == "S04" and o == 2:
		var wounded = people().filter(func(m): return m.health <= 40)
		wounded.sort_custom(func(a,b): return a.health < b.health)
		if wounded.size() < 2: return fail("分药必须有两名真实在场伤员")
		if not _camp_replacement() or not pay({"medicine":1}): return false
		var success = chance(30 if best("medical").get("medical",0) >= 70 else 15)
		for m in wounded.slice(0,2): change(m,"health",10 if success else -10)
		return true
	if id == "T02":
		if o == 0:
			_stat("zhang","fatigue",-20); _stat("zhang","trust",3); s.facts.refused_rest_count = 0
			var substitutes = people().filter(func(m): return m.id != "zhang" and m.health >= 30 and m.fatigue < 80)
			substitutes.sort_custom(func(a,b): return a.fatigue < b.fatigue if a.fatigue != b.fatigue else a.id < b.id)
			var substitute = person("captain") if substitutes.is_empty() else substitutes[0]
			change(substitute,"fatigue",10); s.daily.watch = substitute.id
		else:
			all_change("fatigue",10); _stat("zhang","health",-10); _refuse_zhang_rest()
		s.daily.hours += 0.5; return true
	if id == "T13":
		var ledger = s.facts.get("theft_ledger",{})
		if ledger.is_empty() or ledger.get("resolved",false): return fail("没有尚未处理的真实失窃记录")
		if o == 0:
			s.daily.hours += 1
			if chance(90 if not qualified("logistics").is_empty() else 70):
				gain({str(ledger.resource):ledger.amount}); ledger.resolved = true
				for m in people(): change(m,"trust",-5 if m.id == ledger.owner else 2)
				s.private_risk = maxi(0,s.private_risk-10)
			else: all_change("trust",-3)
		elif o == 2:
			# Replacing the missing share spends existing goods; the original
			# stolen amount is already outside the inventory and is never debited again.
			var share = mini(int(ledger.amount),people().size())
			if not pay({str(ledger.resource):share}): return false
			s.daily.food_prepaid = int(s.daily.get("food_prepaid",0))+share
			s.private_risk = mini(100,s.private_risk+1); _stat("sofia","trust",-3); _stat(str(ledger.owner),"trust",-3)
			ledger.resolved = true; s.facts.accounts_due = s.day+1
		else: return false
		return true
	if id == "N-F06":
		_enter_panic()
		if o == 0: all_change("trust",2); s.daily.hours += 0.5; s.facts.supply_promise = true
		elif o == 1: _stat("sofia","trust",2)
		else: all_change("trust",-2); all_change("like",-1)
		return true
	if id in ["T04","T08","T09","T11"]:
		if o == 0:
			s.facts.next_route = "safe" if id == "T04" else ("unknown" if id == "T09" else "resource")
			s.facts.next_route_day = s.day+1
			_stat(speaker(id),"trust",4 if id == "T09" else (2 if id == "T11" else 3))
			if id == "T04": _stat("ajie","trust",-3); s.facts.next_safe_exclusion_day = s.day+1
			if id == "T08": s.facts.medical_direction_day = s.day+1
			if id == "T09": s.facts.next_u = 10; s.facts.scout_refused = 0; s.facts.scout_promise = false
			if id == "T11": s.facts.warehouse_promise = true
		else:
			_stat(speaker(id),"trust",-5 if id == "T09" else (-2 if id == "T11" else -3))
			if id == "T09": s.facts.scout_promise = true
		s.daily.hours += 0.5; return true
	var repair_action = (id in ["M01","T01","T03"] and o == 0) or id == "M02"
	if id == "M14":
		s.daily.hours += 0.5
		target.registration_seen = true
		if o == 0: change(target,"trust",3); change(target,"like",2); target.registered = true
		elif o == 1: change(target,"trust",1); target.registered = true
		else: change(target,"trust",-5); _queue_proposal(target)
		return true
	var medical_action = id in ["M05","T05","N-F04"] and o == 0 or id in ["M06","M07"]
	if repair_action and not require_operator("repair"): return false
	if medical_action and not require_operator("medical"): return false
	var result = super._person_effect(id,o,target,args)
	if not result: return false
	if id in ["M05","T05","N-F04"]: s.daily.fever_handled = true
	if id == "S04": _stat("elin","trust",5 if o == 0 else -9)
	if id == "T10" and o == 2: person("ajie").scout_penalty_day = s.day+1
	if id in ["T02","T10","N-F05"] and o == 0:
		var owner = "zhang" if id == "T02" else ("ajie" if id == "T10" else str(s.facts.get("rest_target","elin")))
		var replacement = people().filter(func(m): return m.id != owner and m.health >= 30 and m.fatigue < 95)
		replacement.sort_custom(func(a,b): return a.fatigue < b.fatigue if a.fatigue != b.fatigue else a.id < b.id)
		s.daily.watch = replacement[0].id if not replacement.is_empty() else "captain"
	if id == "N-X03": target.water_cause_closed = true
	if id == "N-X04" and o == 2: s.pending.append({"kind":"learning_promise","target":target.id,"role":args.get("role","repair"),"day":s.day+2,"promised":s.day})
	if id == "N-X05" and o == 0:
		if "listen_"+target.id in s.daily.used: return fail("同一人今天已倾听")
		s.daily.used.append("listen_"+target.id)
	if id == "N-X06" and o == 0: target.unavailable_until = s.day
	if id == "N-F03": s.facts.forgiven = 0; s.facts.accounts_due = -100
	if id == "T12" and o == 0: s.facts.private_map = false; s.facts.scout_promise = false
	if id == "M08" and o < 2 and s.daily.get("last_teaching_success",false):
		person("sofia" if o == 0 else "ajie").basic_nursing = true; s.facts.basic_nursing = true
	return true

func _refuse_zhang_rest() -> void:
	s.facts.rest_refused_day = s.day; s.facts.rest_target = "zhang"
	s.facts.refused_rest_count = int(s.facts.get("refused_rest_count",0))+1
	if s.facts.refused_rest_count >= 3:
		person("zhang").repair_refusal_until = s.day+1; _stat("zhang","trust",-8)
		s.facts.rest_penalty_covered_day = s.day+1; s.facts.refused_rest_count = 0

func _opportunity_effect(id: String, o: int, target: Dictionary, args: Dictionary) -> bool:
	if id != "S02": return super._opportunity_effect(id,o,target,args)
	_enter_theft()
	var ledger = s.facts.theft_ledger
	if o == 0:
		s.daily.hours += 1
		if chance(90 if not qualified("logistics").is_empty() else 70):
			gain({"food":ledger.amount}); ledger.resolved = true
			for m in people(): change(m,"trust",-5 if m.id == ledger.owner else -1)
		else: all_change("trust",-5)
	elif o == 1:
		if not pay({"food":5}): return false
		s.daily.food_prepaid = 5; ledger.resolved = true; _institution()
	else:
		_stat(str(ledger.owner),"trust",-3); s.private_risk = mini(100,s.private_risk+2); _stat("sofia","trust",-5)
	return true

func _expire_opportunity() -> void:
	var id = str(s.daily.get("opportunity_card",""))
	if id == "": return
	s.daily.opportunity_card = ""
	match id:
		"S01": _stat("ajie","trust",-5); _stat("sofia","trust",-5); s.facts.ration_dispute_due = s.day+1
		"S02":
			_enter_theft(); var ledger = s.facts.theft_ledger
			_stat(str(ledger.owner),"trust",-3); _stat("sofia","trust",-5); s.private_risk = mini(100,s.private_risk+2)
		"S03": all_change("trust",-5); _rebalance(-3,0)
		"S04":
			change(lowest(),"health",-10); _stat("elin","trust",-15); s.facts.delayed_care = true
		"R01":
			if "guild" not in s.contacts: s.contacts.append("guild")
			_stat("sofia","trust",-1)
		"R03": s.daily.noise = maxi(0,s.daily.noise-10); s.tracking = maxi(0,s.tracking-10)
		"R05":
			if s.resources.fuel >= 3: pay({"fuel":3}); s.daily.hours += 2
			else: _faction("east",5); s.daily.hours += 0.5
		"R08": s.daily.hours += 1; s.exposure = mini(100,s.exposure+2); _stat("elin","trust",1)
	_remember(id); _check_deaths(false)

func finish_preparation() -> bool:
	if s.phase != "morning" or not s.daily.prepared: return super.finish_preparation()
	_expire_requests(true)
	if s.ending != "": return true
	return super.finish_preparation()

func depart_route(route: String, style: String, supply: String = "") -> bool:
	if s.phase == "route" and route != "stay" and not on_foot() and car().durability <= 20 and _lost_repair_without_replacement():
		_end("E15"); log_event("维修岗位已死亡，当前车辆必须修复，现场无可接替、临时支持或修理外援。")
		return true
	if not on_foot():
		for v in cars():
			if vehicle_weight(v) > vehicle_capacity(v)+0.01: return fail(v.name+"超载，请在车辆面板实际转移或丢弃货物")
	if s.daily.get("route_override","") != "": route = s.daily.route_override
	s.daily.travel_start = {"legs":s.legs,"edge":s.edge_km,"distance":s.distance}
	s.daily.road_id = int(s.legs)+1
	s.daily.pretravel_breakdown = route != "stay" and not on_foot() and car().durability <= 20
	if s.daily.get("map_choice","") == "sealed_tunnel":
		if s.legs < 3 or on_foot(): return fail("须实际抵达第三章以后标明封死的支路入口")
		s.facts.sealed_tunnel_attempt = true; s.daily.card = "N-C04"; s.phase = "event"
		log_event("已停车到封闭入口：出口完全堵死，强冲将导致全队死亡。可退回。")
		return true
	if not on_foot() and car().durability <= 40: s.facts.mechanical_warning = true
	return super.depart_route(route,style,supply)

func _lost_repair_without_replacement() -> bool:
	if not s.members.any(func(m): return not m.alive and "repair" in m.get("lost_roles",[])): return false
	if not qualified("repair").is_empty() or s.position == "避难点": return false
	if not qualified("repair",30,95,40).is_empty() and not s.facts.has("support_until_repair"): return false
	return true

func breakdown_probability() -> int:
	return clampi(super.breakdown_probability()+int(s.facts.get("next_b",0))+int(s.facts.get("next_risk",0)),0,60)

func _undo_progress() -> void:
	if s.daily.get("progress_undone",false): return
	s.daily.progress_undone = true
	var start = s.daily.get("travel_start",{})
	if start.is_empty(): return
	s.legs = start.legs; s.edge_km = start.edge; s.distance = start.distance

func _arrive() -> void:
	if s.daily.get("pretravel_breakdown",false) and not s.daily.travel_done:
		s.daily.pretravel_breakdown = false; s.phase = "route"
		log_event("抢修已完成；车尚未行驶，须重新确认出发，才支付路费并取得实际路段补给。")
		return
	if s.daily.route == "resource" and not s.daily.supply_claimed and not on_foot():
		var key = "supply_%d" % int(s.daily.get("road_id",s.legs))
		if key not in s.claimed:
			gain({s.daily.supply:{"water":12,"food":10,"fuel":12,"parts":4,"medicine":1}[s.daily.supply]}); s.claimed.append(key)
		s.daily.supply_claimed = true
	var rain_taken = "rain" in s.daily.used
	super._arrive()
	if s.ending != "": return
	if s.daily.get("opportunity_card","") == "S02": _enter_theft()
	if has_mod("SP25") and s.daily.weather == "雨":
		if rain_taken: s.resources.water -= 2
		elif weight() > capacity(): s.resources.water -= 2; log_event("集雨未运行：需先清出2千克载重。")
		else: s.daily.used.append("rain")
	if s.daily.get("source_drawn",false) or s.day in [4,5,7,9,10] or s.daily.get("opportunity_card","") != "": return
	s.daily.source_drawn = true
	# One real stop opportunity, never an extra independent daily loot roll.
	if s.daily.opportunity_used or s.daily.get("opportunity_drawn",false): return

func _draw_card(pool: String, rate: float) -> String:
	if pool == "travel":
		var candidates = []
		for id in content.cards:
			if content.cards[id].pool == pool and _eligible(id): candidates.append(id)
		for id in ["N-X01","N-X02","N-F10"]:
			if _eligible(id): candidates.append(id)
		for id in ["N-C04","N-C05"]:
			if id in candidates: return id
		if not on_foot():
			if s.daily.style != "detour": candidates.append_array(["EV01","EV02","EV04"])
			if s.resources.fuel > 0: candidates.append("EV03")
			if s.daily.weather == "雨" and s.books.values().any(func(n): return n > 0): candidates.append("EV06")
			if s.resources.food > 0 and s.daily.weather == "晴": candidates.append("EV07")
		if s.daily.route == "unknown": candidates.append("EV05")
		if s.daily.style == "detour" or s.daily.get("safe_accident_exclusion",false) or s.facts.get("road_excluded",false): candidates = candidates.filter(func(id): return id not in ["V02","V09"])
		if s.facts.has("next_event_rate"): rate = s.facts.next_event_rate; s.facts.erase("next_event_rate")
		rate = clampf(rate+s.facts.get("next_event_mod",0),0,100); s.facts.erase("next_event_mod")
		if candidates.is_empty() or not chance(rate): return ""
		var selected = str(candidates[rng.randi_range(0,candidates.size()-1)])
		if selected in ["V02","V09"]:
			var breakdown = chance(breakdown_probability())
			s.facts.erase("next_b"); s.facts.erase("next_risk")
			if not breakdown: return ""
		if selected == "N-F10":
			var brake_failed = chance((35 if s.daily.weather == "雨" else 25)+int(s.facts.get("brake_fault_once",0)))
			s.facts.erase("brake_fault_once")
			if not brake_failed: return ""
		return selected
	if pool == "opportunity" and s.day not in [4,5,7,9,10]:
		# Random dismantling is another candidate in the one stop pool.
		var candidates = []
		for id in content.cards:
			if content.cards[id].pool == pool and _eligible(id): candidates.append(id)
		if _eligible("N-F09"): candidates.append("N-F09")
		for id in candidates:
			if _tier(id) == 2: return id
		var source = source_here()
		if not source.is_empty() and source.id+"_"+str(s.legs) not in s.claimed: candidates.append("SOURCE")
		if candidates.is_empty() or not chance(rate): return ""
		var chosen = str(candidates[rng.randi_range(0,candidates.size()-1)])
		if chosen == "SOURCE": s.daily.source = source; return ""
		return chosen
	return super._draw_card(pool,rate)

func source_here() -> Dictionary:
	# Source placement follows the visible chapter feature, with a three-core pool.
	if content.sources.is_empty() or s.legs < 1: return {}
	return content.sources[(int(s.legs)-1)%content.sources.size()]

func salvage_source(executor: String, recycle: bool = false) -> bool:
	var source = s.daily.get("source",{})
	if s.phase != "stop" or source.is_empty() or s.daily.special_used or s.daily.opportunity_used or s.day in [4,5,7,9,10]: return fail("当前没有到达的拆检机会，或今日额度已用")
	var m = person(executor)
	if not living(executor) or m.health < 30 or m.fatigue >= 95: return fail("执行者须健康30且疲劳<95")
	var key = source.id+"_"+str(s.legs)
	if key in s.claimed or not use_task(): return false
	s.claimed.append(key); s.daily.special_used = true; s.daily.opportunity_used = true
	if chance(source.chance+(10 if m.scout >= 60 else 0)):
		var core = str(source.choices[rng.randi_range(0,source.choices.size()-1)])
		if recycle: gain({"parts":3})
		else: s.cores[core] = s.cores.get(core,0)+1
		log_event("拆检成功："+core+("，当场回收普通件3" if recycle else "核心1"))
	else: gain({"parts":2}); log_event("拆检未得核心，普通件+2")
	return true

func set_map_choice(choice: String) -> bool:
	if s.phase != "route" or choice not in ["road","sealed_tunnel"]: return false
	if choice == "sealed_tunnel" and s.legs < 3: return fail("尚未到达标有封闭警示的支路")
	s.daily.map_choice = choice; return true

func visit(place: String) -> bool:
	if s.phase != "stop" or on_foot() or place not in ["refuge","wreck"]: return false
	if place == "wreck" and not s.facts.get("wreck_"+str(s.legs),false): return fail("当前章没有已定位废车支点")
	if s.position == ("避难点" if place == "refuge" else "废车点"): return fail("已在此地点")
	if not use_task() or not pay({"fuel":1}): return false
	s.position = "避难点" if place == "refuge" else "废车点"
	s.facts.safe_reception = place == "refuge"
	log_event("实际进入章内支点："+s.position+"，燃料1、1小时，未增加主边。")
	return true

func walk_to(place: String) -> bool:
	if s.position == place and s.phase == "route": return fail("已在该点，可主动停留休整")
	if not super.walk_to(place): return false
	s.facts.safe_reception = place == "避难点"
	return true

func ending_missing(id: String, after_night: bool = false) -> Array:
	var missing = super.ending_missing(id,after_night)
	if id in ["E03","E06","E08","E11","E12"] and s.legs < 8: missing.append("目标正式入口至少8条主边；本地避难点不能当远方聚落")
	if id == "E02" and s.factions.get(str(s.goal),0) >= 60: missing.append("当前接纳点须非盟友，盟友可申请正式加入")
	if on_foot() and id in ["E03","E08","E11","E12"] and s.position != "避难点" and not s.daily.get("terminal_entered",false): missing.append("须先实际走到当前已标记的6千米入口")
	if id == "E07" and s.position != "避难点" and s.legs < 8: missing.append("先抵达已知可居住点")
	return missing

func complete_goal(id: String) -> bool:
	if s.intent != "": return fail("今天已完成终局行动，先完成营地和夜间结算")
	if id == "E03": s.facts.join_faction = s.goal if s.goal in ["east","south","guild"] else "south"
	if not super.complete_goal(id): return false
	if id not in ["E04","E05"]:
		s.distance += 6; s.daily.terminal_entered = true
		if id not in ["E02","E07"]: s.position = "南边正式定居区" if id == "E12" else ("商会登记处" if id == "E06" else "已抵达目标")
	log_event(GOAL_ACTIONS.get(id,id)+"；最后6千米包含本日燃料，待夜间核验。")
	return true

func _check_deaths(sudden: bool) -> void:
	for m in s.members:
		if m.alive and m.active and m.health <= 0:
			m.death_day = s.day
			m.lost_roles = BOOKS.keys().filter(func(role): return m[role] >= 60)
	super._check_deaths(sudden)

func _process_memory_due() -> void:
	for item in s.pending.duplicate(true):
		if int(item.day) > int(s.day): continue
		match str(item.kind):
			"fatigue":
				if living(str(item.target)): change(person(str(item.target)),"fatigue",float(item.amount))
			"learning_promise":
				if living(str(item.target)) and int(person(str(item.target)).get("last_learning",{}).get(str(item.role),-100)) < int(item.promised): change(person(str(item.target)),"trust",-2)
			"proposal":
				if living(str(item.target)) and chance(25): s.facts["departure_proposal_"+str(item.target)] = true
			"knowledge_forget":
				if chance(40): lose_unrecorded(2)
			"rule_forget":
				if chance(50): s.institution = maxi(0,s.institution-1)
			"route_memory":
				if str(item.label) not in s.records and not chance(30) and int(item.remaining) > 1:
					s.pending.append({"kind":"route_memory","day":s.day+1,"remaining":int(item.remaining)-1,"label":item.label})
				else: log_event("未补记的普通路线资料已遗忘或过期；主线与已存记录保留。")
			"father": s.facts.father_ready = true
			_ : continue
		s.pending.erase(item)

func split_decision(action: String) -> bool:
	if action != "safe":
		if action == "separate" and s.day < 12:
			if s.phase != "split": return false
			for m in group_members(lower_group()).duplicate(): depart(m.id,false)
			s.split_nights = 0; _finish_night(); return true
		return super.split_decision(action)
	if s.phase != "split" or s.position != "避难点": return fail("安全分流须已确认安全接纳点")
	var leaving = group_members(lower_group())
	if leaving.any(func(m): return m.trust < 30): return fail("拟离队成员尚未全部同意，信任至少30")
	if not pay({"water":leaving.size(),"food":leaving.size()}): return false
	for m in leaving.duplicate(): depart(m.id,true)
	s.daily.hours += 1; s.split_nights = 0
	var added = maxf(0,s.daily.hours-12)*2-s.daily.get("overtime_applied",0)
	if added > 0: all_change("fatigue",added)
	_check_deaths(false)
	if s.ending == "": _finish_night()
	return true

func settle() -> bool:
	if s.phase not in ["camp","stop"] or s.daily.night_done or not s.daily.camp_used: return super.settle()
	_expire_opportunity()
	if s.ending != "": return true
	var health_before = {}
	for m in people(): health_before[m.id] = m.health
	if not _run_devices(): return false
	_expire_requests(false)
	if s.ending != "": return true
	if s.daily.get("cold",0) > 0:
		all_change("health",-5*s.daily.cold); log_event("未解除寒冷%d级：全员健康−%d" % [s.daily.cold,5*s.daily.cold])
	_check_deaths(false)
	if s.ending != "": return true
	s.facts.yesterday_unknown = s.daily.route == "unknown"
	s.facts.yesterday_unknown_failure = s.daily.route == "unknown" and s.daily.get("accident",false)
	s.facts.food_smell = not s.daily.sealed and s.resources.food > 0
	if s.facts.get("rest_promise","") != "":
		_stat(str(s.facts.rest_promise),"trust",3 if s.daily.get("camp_action","") == "rest" else -6); s.facts.rest_promise = ""
	var result = super.settle()
	if result:
		s.facts.last_night = {"watcher":s.daily.get("watch",""),"injured":s.members.any(func(m): return health_before.has(m.id) and m.health < health_before[m.id]),"footprints":s.daily.get("event","") == "C29","departed":s.daily.get("someone_departed",false)}
		for m in people():
			if s.daily.rations.get(m.id,{}).get("water",0) >= (2 if on_foot() else 1): m.water_cause_closed = false
	return result

func _repair(amount: int) -> void:
	var bonus = int(s.facts.get("repair_bonus",0))
	s.facts.erase("repair_bonus")
	super._repair(amount+bonus)

func card_data(id: String) -> Dictionary:
	return ENV_EVENTS[id] if ENV_EVENTS.has(id) else content.cards.get(id,{})

func resolve_environment(id: String, option: int, args: Dictionary) -> bool:
	if s.phase != "event" or s.daily.card != id or option not in [0,1]: return false
	var m = person(str(args.get("target","captain")))
	if not living(str(m.get("id",""))): return false
	match id:
		"EV01":
			if option == 0:
				if not pay({"fuel":2}): return false
				s.daily.hours += 1
			else: damage_car(4 if has_mod("SP12",car()) else 8); change(m,"health",-5 if has_mod("SP12",car()) else -10)
		"EV02":
			if not pay({"parts":2 if has_mod("SP13",car()) else 4,"fuel":1} if option == 0 else {"fuel":3}): return false
			s.daily.hours += 1 if option == 0 else 2
			if option == 0: damage_car(2)
		"EV03":
			if option == 0:
				if not pay({"parts":1}): return false
				s.daily.hours += 1
			else:
				var saved = 3 if has_mod("SP17",car()) and "leak" not in s.daily.used else 0
				s.resources.fuel = maxf(0,s.resources.fuel-(5-saved)); s.daily.used.append("leak"); log_event("漏油原损5，设备保住%d，实际损失%d" % [saved,5-saved])
		"EV04":
			if option == 0: s.daily.hours += 1
			elif chance(20 if has_mod("SP20",car()) else 40):
				if not pay({"parts":1 if has_mod("SP20",car()) else 3}): return false
				s.daily.hours += 2
		"EV05":
			if option == 0: s.daily.hours += 1
			elif not scout_check(): return false
		"EV06":
			if option == 0: s.daily.hours += 1
			else:
				var role = str(args.get("role","repair"))
				if s.books.get(role,0) < 1: return fail("请选择实际携带的书")
				if role not in s.facts.get("archive_books",[]): s.facts["wet_"+role] = s.day
		"EV07":
			if option == 0: s.daily.hours += 1
			var loss = mini(int(s.resources.food),2 if option == 0 else 5)
			var protected = mini(loss,int(s.facts.get("cold_food",0))) if int(s.facts.get("cold_until",0)) >= int(s.day) else 0
			s.resources.food -= loss-protected; s.facts.cold_food = maxi(0,int(s.facts.get("cold_food",0))-protected)
			log_event("食物腐坏原损%d，冷链保住%d，实际损失%d" % [loss,protected,loss-protected])
	s.daily.accident = id; s.daily.event = id; s.daily.card = ""
	_check_deaths(true); _check_vehicle_loss()
	if s.ending == "": _arrive()
	return true

func scout_check(modifier: int = 0) -> bool:
	var pool = qualified("scout"); var ability = 0
	for m in pool: ability = maxi(ability,effective_ability(m,"scout"))
	var u = 40-floori(ability/5.0)+(10 if pool.is_empty() else 0)+modifier+int(s.facts.get("next_u",0))+(5 if s.facts.get("private_map",false) else 0)
	s.facts.erase("next_u")
	if has_mod("SP09") or has_mod("SP24"): u -= 15
	u = clampi(u,0,100)
	if chance(u):
		s.daily.hours += 1 if has_mod("SP21",car()) else 2
		if on_foot(): all_change("fatigue",10)
		elif not pay({"fuel":2 if has_mod("SP21",car()) else 3}): return false
		s.daily.accident = "U"; log_event("支路验证误判，U=%d%%，已结算一次代价" % u)
	else: log_event("支路验证正确，U=%d%%" % u)
	return true

func cargo_quantity(key: String) -> float:
	if key == "keepsakes": return float(s.facts.get("keepsakes",0))
	if key.begins_with("book_"): return float(s.books.get(key.trim_prefix("book_"),0))
	if key == "notebook": return 1.0 if s.notebook else 0.0
	if key.begins_with("core_"): return float(s.cores.get(key.trim_prefix("core_"),0))
	return float(s.resources.get(key,0))

func cargo_unit(key: String) -> float:
	if key == "keepsakes": return 0.5
	if key.begins_with("book_") or key == "notebook": return 0.5
	if key.begins_with("core_"): return float(content.modules[key.trim_prefix("core_")].core_weight)
	return {"water":1.0,"food":0.5,"fuel":0.8,"parts":1.0,"medicine":0.1,"tea":0.1,"incense":0.1}.get(key,0)

func cargo_keys() -> Array:
	var result = s.resources.keys()+["notebook","keepsakes"]
	for role in BOOKS: result.append("book_"+role)
	for id in s.cores: result.append("core_"+id)
	return result

func weight() -> float:
	return super.weight()+0.5*int(s.facts.get("keepsakes",0))

func normalize_cargo() -> void:
	if on_foot(): return
	for v in s.vehicles:
		if not v.has("cargo"): v.cargo = {}
	for key in cargo_keys():
		var remaining = cargo_quantity(key)
		# Preserve the recorded second-car load; newly obtained goods go to main.
		for v in cars():
			if v == car(): continue
			v.cargo[key] = minf(maxf(0,float(v.cargo.get(key,0))),remaining); remaining -= v.cargo[key]
		car().cargo[key] = remaining

func vehicle_capacity(v: Dictionary) -> float:
	return float(v.capacity)+(150 if has_mod("SP03",v) else 0)+(80 if has_mod("SP28",v) else 0)

func vehicle_weight(v: Dictionary) -> float:
	normalize_cargo()
	var total = 0.0
	for key in v.get("cargo",{}): total += float(v.cargo[key])*cargo_unit(key)
	for id in v.modules.values(): total += float(content.modules[id].weight)
	return total

func assign_vehicle(index: int, target: String) -> bool:
	if s.phase not in ["morning","route","stop","camp"] or index < 0 or index >= s.vehicles.size() or s.vehicles[index].destroyed or s.vehicles[index].durability <= 0: return fail("需停车且车辆可用")
	if target == "":
		normalize_cargo(); s.main_vehicle = index; normalize_cargo()
	elif living(target): person(target).vehicle = index
	else: return false
	return true

func transfer_cargo(key: String, amount: float, index: int) -> bool:
	if s.phase not in ["morning","route","stop","camp"] or index < 0 or index >= s.vehicles.size() or s.vehicles[index].destroyed or on_foot() or amount <= 0 or key not in cargo_keys(): return false
	normalize_cargo()
	var destination = s.vehicles[index]; var available = cargo_quantity(key)-float(destination.cargo.get(key,0))
	if amount > available or vehicle_weight(destination)+amount*cargo_unit(key) > vehicle_capacity(destination): return fail("来源货量不足或目标车辆装不下")
	var remaining = amount
	for v in cars():
		if v == destination: continue
		var moved = minf(remaining,v.cargo.get(key,0)); v.cargo[key] -= moved; remaining -= moved
	destination.cargo[key] = float(destination.cargo.get(key,0))+amount
	return true

func designate_container(id: String, role: String, index: int) -> bool:
	if s.phase not in ["morning","route","stop","camp"] or index < 0 or index >= s.vehicles.size(): return false
	normalize_cargo()
	var v = s.vehicles[index]
	if id == "archive":
		if s.phase != "morning" or not has_mod("SP29",v) or s.books.get(role,0) < 1 or v.cargo.get("book_"+role,0) < 1: return fail("晨间指定，须档案箱所在车辆实际携带该书")
		if not s.facts.has("archive_books"): s.facts.archive_books = []
		if s.facts.get("archive_vehicle",index) != index: s.facts.archive_books = []
		s.facts.archive_vehicle = index
		if role in s.facts.archive_books: s.facts.archive_books.erase(role)
		elif s.facts.archive_books.size() < 2: s.facts.archive_books.append(role)
		else: return fail("档案箱最多保护两册，请先取消一册")
	elif id == "cold_food":
		if not has_mod("SP27",v): return fail("该车没有冷藏箱")
		s.facts.cold_food = mini(4,int(v.cargo.get("food",0))); s.facts.cold_vehicle = index
	else: return false
	return true

func _maintain_containers() -> void:
	normalize_cargo()
	var archive = int(s.facts.get("archive_vehicle",-1))
	if archive >= 0:
		if archive >= s.vehicles.size() or s.vehicles[archive].destroyed or not has_mod("SP29",s.vehicles[archive]): s.facts.archive_books = []
		else: s.facts.archive_books = s.facts.get("archive_books",[]).filter(func(role): return s.vehicles[archive].cargo.get("book_"+role,0) >= 1)
	var cold = int(s.facts.get("cold_vehicle",-1))
	if cold >= 0:
		if cold >= s.vehicles.size() or s.vehicles[cold].destroyed or not has_mod("SP27",s.vehicles[cold]): s.facts.cold_food = 0; s.facts.cold_until = -1
		else: s.facts.cold_food = mini(int(s.facts.get("cold_food",0)),int(s.vehicles[cold].cargo.get("food",0)))

func drop_item(id: String) -> bool:
	if s.phase not in ["morning","route","stop","camp"]: return false
	if id == "notebook":
		if not s.notebook: return false
		s.notebook = false; s.pages = 0
	elif id in BOOKS:
		if s.books[id] < 1: return false
		s.books[id] -= 1
	elif content.modules.has(id):
		if s.cores.get(id,0) < 1: return false
		s.cores[id] -= 1
	else: return false
	log_event("永久丢弃实体："+id)
	return true

func search_car() -> bool:
	if not on_foot() or "search_car" in s.daily.used or not (s.facts.get("wreck_"+str(s.legs),false) or s.day in [6,9,12]): return fail("需当前位置是已知废车地带，每天最多一次")
	if not use_task(): return false
	s.daily.used.append("search_car")
	var ability = 0
	for m in qualified("scout"): ability = maxi(ability,effective_ability(m,"scout"))
	if chance(mini(90,ability+10+(15 if has_mod("SP09") else 0))): s.facts["wreck_"+str(s.legs)] = true; log_event("发现章内废车支点，仍需实际走到8千米支点并修复。")
	else: log_event("此次寻找未发现车辆，期限不延长。")
	return true

func device(id: String) -> bool:
	if id == "cancel": s.daily.device_requests = []; return true
	if id not in ["water","cold"] or s.phase not in ["stop","camp"]: return fail("牵引/诱导须附在对应事件撤离选项上，不能单独运行")
	if id in s.daily.get("device_requests",[]): return fail("设备已安排，待营地结束后运行")
	if not has_mod("SP04" if id == "water" else "SP27"): return fail("尚未装有该设备")
	if id == "water" and s.daily.weather != "雨" and s.position != "避难点": return fail("净水需雨或已确认淡水源")
	if not s.daily.has("device_requests"): s.daily.device_requests = []
	s.daily.device_requests.append(id); return true

func _run_devices() -> bool:
	for id in s.daily.get("device_requests",[]).duplicate():
		if id == "water" and weight()+3 > capacity(): return fail("净水运行前须清出3千克载重，或取消设备安排")
		if not _device_power(): return false
		if id == "water": gain({"water":3}); s.daily.used.append("purifier"); log_event("营地结束：净水箱饮水+3")
		else: s.facts.cold_until = s.day+1; log_event("冷链已启动，保护实际存入的至多4份食物，至次日营地")
	s.daily.device_requests = []
	return true

func _travel_effect(id: String, o: int, target: Dictionary, args: Dictionary) -> bool:
	if id == "V09" and o == 2:
		var pool = people().filter(func(m): return m.health >= 30 and m.fatigue < 95)
		var winch = has_mod("SP11",car()) and "assist" not in s.daily.used and s.resources.fuel >= 1 and not on_foot() and car().durability > 0
		if pool.size() < (2 if winch else 3): return fail("推车需3人；有效绞盘可2人，健康30疲劳<95")
		if winch:
			if not pay({"fuel":1}): return false
			s.daily.used.append("assist")
		for m in pool.slice(0,2 if winch else 3): change(m,"fatigue",12 if winch else 20)
		s.daily.hours += 3 if winch else 4; _undo_progress()
		if s.daily.get("pretravel_breakdown",false): s.daily.travel_done = true; s.daily.route = "stay"; s.daily.supply_claimed = true
		return true
	if id == "V09" and o == 4:
		if s.position != "避难点": return fail("此处没有真实可达修理外援，不能仅凭远程阵营联络修车")
	if id == "N-C03" and o == 2:
		if target.repair < 60 or not target.alive: return fail("须指定老张或实际合格维修接替者")
	var repairing = id in ["V02","V09","N-F10"] and o == 0
	if repairing and not require_operator("repair"): return false
	var result = super._travel_effect(id,o,target,args)
	if not result: return false
	if id in ["V08","N-X01","N-X02"]:
		s.last_observation = s.day
		if id == "V08" and o == 2: s.tracking = mini(100,s.tracking+5)
		if id == "N-X01" and o == 2: s.tracking = maxi(0,s.tracking-5)
	if id == "V09" and s.daily.get("pretravel_breakdown",false) and o in [1,2,3]:
		s.daily.travel_done = true; s.daily.route = "stay"; s.daily.supply_claimed = true
	if id == "N-C03" and o == 2 and s.ending == "" and not target.alive and target.get("lost_roles",[]).has("repair") and not on_foot() and car().durability <= 20 and qualified("repair",30,95,40).is_empty() and s.position != "避难点": _end("E15")
	if args.get("assist",false):
		if not (id == "N-C02" and o == 1 or id == "N-C05" and o == 2) or not has_mod("SP30") or "assist" in s.daily.used or not pay({"parts":1}): return fail("诱导只用于本次合法支点撤离，且全队每日辅助一次")
		s.daily.used.append("assist"); s.daily.hours += 0.5; s.tracking = maxi(0,s.tracking-10); s.exposure = mini(100,s.exposure+5)
	if id in ["V04","V07"] and o < 2: s.daily.ordinary_signal = true
	if id in ["V02","V06","V09","N-F10"]: s.daily.accident = id
	return true

func command(action: String, args: Dictionary = {}) -> bool:
	if action not in ["mainline","preset","map_choice","visit","salvage","assign_vehicle","transfer","container","drop_item","search_car","ration","watch"]:
		if action == "begin_camp" and s.daily.get("r08_followup",false): return fail("请先完成陆芷的当次同行答复，与救援合用一项事务")
		var result = super.command(action,args)
		if result and action == "begin_camp": _expire_opportunity()
		if result: _maintain_containers()
		return result
	var before = checkpoint(); error = ""; var ok = false
	match action:
		"mainline": ok = mainline(str(args.id))
		"preset": ok = preset(str(args.id),bool(args.value))
		"map_choice": ok = set_map_choice(str(args.id))
		"visit": ok = visit(str(args.id))
		"salvage": ok = salvage_source(str(args.get("target","captain")),bool(args.get("recycle",false)))
		"assign_vehicle": ok = assign_vehicle(int(args.get("vehicle",0)),str(args.get("target","")))
		"transfer": ok = transfer_cargo(str(args.id),float(args.amount),int(args.vehicle))
		"container": ok = designate_container(str(args.id),str(args.get("role","repair")),int(args.get("vehicle",s.main_vehicle)))
		"drop_item": ok = drop_item(str(args.id))
		"search_car": ok = search_car()
		"watch":
			var id = str(args.id)
			if s.phase in ["morning","route","stop","camp"] and (id == "" or living(id) and person(id).health >= 30 and person(id).fatigue < 95 and person(id).get("unavailable_until",0) < s.day): s.daily.watch = id; ok = true
		"ration":
			var target = str(args.target); var resource = str(args.id); var amount = int(args.amount)
			if s.phase in ["stop","camp"] and living(target) and resource in ["water","food"] and amount >= 0 and amount <= (2 if resource == "water" and on_foot() else 1):
				if not s.daily.has("allocation_plan"): s.daily.allocation_plan = {}
				if not s.daily.allocation_plan.has(target): s.daily.allocation_plan[target] = {}
				s.daily.allocation_plan[target][resource] = amount; ok = true
				if amount == 0: s.facts.private_allocation = true
	if not ok:
		var reason = error; restore(before); error = reason if reason != "" else "当前阶段不能执行此项"
	else: _maintain_containers(); s.rng = str(rng.state)
	return ok
