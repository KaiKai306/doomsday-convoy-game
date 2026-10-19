extends RefCounted
## Authoritative twenty-day rules. Commands are atomic; presentation never edits state.
const BOOKS = {"repair":"技术手册", "medical":"医书", "scout":"旧地图", "logistics":"账本"}
const RESOURCE_NAMES = {"water":"饮水", "food":"食物", "fuel":"燃料", "medicine":"药品", "parts":"零件", "tea":"茶叶", "incense":"香薰"}
const ENDINGS = ["全员死亡","无车之民","并入他者","黑旗车队","车队之王","商队","新聚落","共同体抵达","无名消失","车队分裂","孤独抵达","南边的灯","敌影同行","文化遗产","关键成员死亡","主角死亡","共存幻梦"]
const IMPORTANT = [2,5,8,10,12,15,18,20]
const SLOTS = {"front":"车前挡架","engine":"发动机","wheels":"车轮","roof":"车顶","rear":"后挂"}
var s: Dictionary = {}
var content: Dictionary = {}
var day_start: Dictionary = {}
var rng = RandomNumberGenerator.new()
var error = ""
static var manuscript_cache: Dictionary = {}

func _init() -> void:
	if manuscript_cache.is_empty(): manuscript_cache = JSON.parse_string(FileAccess.get_file_as_string("res://data/final/content.json"))
	content = manuscript_cache

func member(id: String, name: String, stats: Array, group: String) -> Dictionary:
	return {"id":id,"name":name,"health":stats[0],"fatigue":float(stats[1]),"trust":stats[2],"like":stats[3],"repair":stats[4],"medical":stats[5],"scout":stats[6],"logistics":stats[7],"group":group,"alive":true,"active":true,"understanding":{},"training":{},"self_study":{},"joined":1,"memory":"共同带车出发。","vehicle":0}

func new_game(seed_value: int = 0) -> void:
	rng.seed = seed_value if seed_value != 0 else int(Time.get_unix_time_from_system()*1000)
	s = {"schema":1,"spec":content.sha256,"day":1,"phase":"morning","resources":{"water":50,"food":45,"fuel":80,"medicine":5,"parts":25,"tea":3,"incense":2},"members":[member("captain","队长",[90,10,50,50,35,35,40,45],"A"),member("zhang","老张",[85,15,55,50,70,20,25,35],"A"),member("elin","艾琳",[90,10,55,50,20,75,30,40],"A"),member("ajie","阿杰",[90,10,50,45,25,25,65,30],"B"),member("sofia","索菲亚",[90,10,50,45,30,30,35,70],"B")],"vehicles":[vehicle("老伙计",80)],"main_vehicle":0,"cores":{},"books":{"repair":1,"medical":1,"scout":1,"logistics":1},"pages":20,"notebook":true,"knowledge":0,"institution":0,"tracking":0,"exposure":0,"private_risk":0,"factions":{"east":0,"south":0,"guild":0},"contacts":[],"legs":0,"edge_km":0.0,"distance":0.0,"foot_km":0.0,"foot_deadline":0,"position":"主路","clues":[],"south_pledge":false,"sister":"unresolved","trades":0,"raids":0,"stays":0,"split_nights":0,"inactive_mornings":0,"intent":"","ending":"","history":[],"facts":{},"pending":[],"card_history":{},"claimed":[],"records":[],"stored_copy":false,"observations":0,"obey":0,"last_observation":-10,"purchase_count":0,"goal":"south","daily":{},"rng":""}
	for m in s.members:
		var role: String = {"zhang":"repair","elin":"medical","ajie":"scout","sofia":"logistics"}.get(m.id,"")
		if role != "": m.understanding[role] = 60
	_begin_day()

func vehicle(name: String, durability: int) -> Dictionary:
	return {"name":name,"durability":durability,"capacity":300,"seats":8,"modules":{},"destroyed":false}

func people() -> Array:
	return s.members.filter(func(m): return m.alive and m.active)

func person(id: String) -> Dictionary:
	for m in s.members:
		if m.id == id: return m
	return {}

func living(id: String) -> bool:
	var m = person(id)
	return not m.is_empty() and m.alive and m.active

func cars() -> Array:
	return s.vehicles.filter(func(v): return not v.destroyed and v.durability > 0)

func car() -> Dictionary:
	if cars().is_empty(): return {}
	if int(s.main_vehicle) < s.vehicles.size() and not s.vehicles[int(s.main_vehicle)].destroyed and s.vehicles[int(s.main_vehicle)].durability > 0: return s.vehicles[int(s.main_vehicle)]
	s.main_vehicle = s.vehicles.find(cars()[0])
	return cars()[0]

func on_foot() -> bool:
	return cars().is_empty()

func has_mod(id: String, v: Dictionary = {}) -> bool:
	if not v.is_empty(): return id in v.modules.values()
	for c in cars():
		if id in c.modules.values(): return true
	return false

func qualified(role: String, health: int = 30, fatigue: float = 95, ability: int = 60) -> Array:
	return people().filter(func(m): return effective_ability(m,role) >= ability and m.health >= health and m.fatigue < fatigue and m.get("unavailable_until",0) < s.day)

func effective_ability(m: Dictionary, role: String) -> int:
	return int(m.get(role,0))+(-2 if role == "scout" and int(m.get("scout_penalty_day",-1)) == int(s.day) else 0)

func require_operator(role: String) -> bool:
	if not qualified(role).is_empty():
		s.facts.erase("support_until_"+role)
		return true
	var trainees = qualified(role,30,95,40)
	if trainees.is_empty(): return fail("缺少合格或能力40–59的见习"+BOOKS[role])
	if s.facts.has("support_until_"+role): return fail("临时支持已用；24小时内须学习至60，或寻求真实外援")
	if not pay({"medicine":1} if role == "medical" else {"parts":2}): return false
	s.facts["support_until_"+role] = s.day+1
	s.daily.trainee_used = role
	log_event("见习临时支持："+trainees[0].name+"，24小时内需学至60才能持续接替。")
	return true

func best(role: String) -> Dictionary:
	var pool = people().filter(func(m): return m.health >= 30 and m.fatigue < 95)
	pool.sort_custom(func(a,b): return a.get(role,0) > b.get(role,0))
	return pool[0] if not pool.is_empty() else {}

func trust() -> int:
	var pool = people().filter(func(m): return m.id != "captain")
	if pool.is_empty(): return 50
	var total = 0.0
	for m in pool: total += m.trust
	return roundi(total / pool.size())

func affection() -> float:
	var pool = people().filter(func(m): return m.id != "captain")
	var total = 0.0
	for m in pool: total += m.like
	return total / pool.size() if not pool.is_empty() else 0.0

func group_gap() -> float:
	var a = []; var b = []
	for m in people():
		if m.id != "captain":
			if m.group == "A": a.append(float(m.trust))
			else: b.append(float(m.trust))
	if a.is_empty() or b.is_empty(): return 0
	var av = 0.0; var bv = 0.0
	for n in a: av += n
	for n in b: bv += n
	return absf(av/a.size()-bv/b.size())

func weight() -> float:
	var total = 0.0
	var units = {"water":1.0,"food":0.5,"fuel":0.8,"medicine":0.1,"parts":1.0,"tea":0.1,"incense":0.1}
	for key in s.resources: total += s.resources[key] * units.get(key,0)
	for key in s.books: total += 0.5 * s.books[key]
	if s.notebook: total += 0.5
	for id in s.cores: total += content.modules[id].core_weight * s.cores[id]
	for v in cars():
		for id in v.modules.values(): total += content.modules[id].weight
	return total

func capacity() -> float:
	if on_foot():
		var result = 0.0
		for m in people(): result += 8 if m.health >= 30 else 2
		return result
	var result = 0.0
	for v in cars(): result += v.capacity + (150 if has_mod("SP03",v) else 0) + (80 if has_mod("SP28",v) else 0)
	return result

func can_pay(cost: Dictionary) -> bool:
	for key in cost:
		if cost[key] < 0 or s.resources.get(key,0) < cost[key]: return false
	return true

func pay(cost: Dictionary) -> bool:
	if not can_pay(cost): return fail("库存不足："+cost_text(cost))
	for key in cost: s.resources[key] -= cost[key]
	return true

func gain(items: Dictionary) -> void:
	for key in items: s.resources[key] = maxf(0,s.resources.get(key,0)+items[key])

func cost_text(cost: Dictionary) -> String:
	var bits: Array[String] = []
	for key in cost: bits.append("%s %s" % [RESOURCE_NAMES.get(key,key),str(cost[key])])
	return " / ".join(bits) if not bits.is_empty() else "无物资成本"

func change(m: Dictionary, key: String, amount: float) -> void:
	if m.is_empty() or not m.alive or not m.active: return
	var old = float(m.get(key,0))
	m[key] = clampf(old+amount,0,100)
	if old != m[key]: log_event("%s %s %+.1f → %.1f" % [m.name, {"health":"健康","fatigue":"疲劳","trust":"信任","like":"好感"}.get(key,key),m[key]-old,m[key]])

func all_change(key: String, amount: float) -> void:
	for m in people(): change(m,key,amount)

func log_event(text: String) -> void:
	s.daily.log.append(text)

func chance(percent: float) -> bool:
	if percent <= 0: return false
	if percent >= 100: return true
	var die = rng.randi_range(1,100)
	s.daily.draws.append({"p":percent,"roll":die})
	return die <= percent

func fail(text: String) -> bool:
	error = text
	return false

func _begin_day() -> void:
	s.phase = "morning"
	s.intent = ""
	s.daily = {"prepared":false,"camp_used":false,"tasks":0,"hours":0.0,"log":[],"draws":[],"route":"safe","style":"quiet","weather":"晴","supply":"","opportunity_used":false,"special_used":false,"used":[],"event":"","card":"","travel_done":false,"night_done":false,"night_travel":false,"noise":30,"distance":0.0,"rations":{},"card_candidates":[],"deferred":[],"rain_chain":false,"light":false,"sealed":true,"sudden":false,"supply_claimed":false}
	s.rng = str(rng.state)
	day_start = s.duplicate(true)
	_draw_day()

func _draw_day() -> void:
	var weather_die = rng.randi_range(1,100)
	s.daily.weather = "晴" if weather_die <= 60 else ("雨" if weather_die <= 80 else ("雾" if weather_die <= 90 else "沙尘"))
	log_event("第%d天 · %s · 人数%d · 今晚需水%d食%d" % [s.day,s.daily.weather,people().size(),people().size()*(2 if on_foot() else 1),people().size()])
	for item in s.pending.duplicate(true):
		if int(item.day) <= int(s.day):
			if item.kind not in ["depart","damage"]: continue
			s.pending.erase(item)
			if item.kind == "depart": depart(str(item.target),false)
			elif item.kind == "damage" and living(str(item.target)): change(person(str(item.target)),"health",float(item.get("amount",-10)))
	if s.day in [6,9,12]: s.facts["wreck_"+str(s.legs)] = true
	_check_deaths(false)
	if s.day == 2 and "east" not in s.contacts: s.contacts.append("east")
	if s.day == 5:
		if "south" not in s.contacts: s.contacts.append("south")
		add_clue("coordinates")
		log_event("固定求救信号：妹妹在南边外围救援站。第10天必须实际救援，期限不会延长。")
	if s.day == 8 and "guild" not in s.contacts: s.contacts.append("guild")
	if s.day > 10 and s.sister == "unresolved": s.sister = "missing"

func add_clue(source: String) -> void:
	if source not in s.clues: s.clues.append(source)

func prepare(action: String, target: String = "captain") -> bool:
	if s.phase != "morning" or s.daily.prepared: return fail("每天仅一次准备")
	match action:
		"water":
			if not pay({"water":2}): return false
			all_change("trust",2)
		"repair":
			if on_foot(): return fail("没有可维修车辆")
			if not require_operator("repair"): return false
			if not pay({"parts":2}): return false
			car().durability = mini(100,car().durability+8)
			s.facts.front_unrepaired = false
		"accounts": s.private_risk = maxi(0,s.private_risk-10)
		"aid":
			if not living(target): return fail("请选择存活队员")
			if not require_operator("medical"): return false
			if not pay({"medicine":1}): return false
			heal(person(target),20)
		"none":
			s.inactive_mornings += 1
			if s.inactive_mornings >= 3:
				all_change("trust",-5); s.inactive_mornings = 0
		_: return fail("未知准备行动")
	if action != "none": s.inactive_mornings = 0
	s.daily.prepared = true; s.daily.hours += 1
	log_event("准备完成："+action)
	return true

func finish_preparation() -> bool:
	if s.phase != "morning": return false
	if not s.daily.prepared: return fail("请先选择一次准备，包括不行动")
	s.phase = "route"
	return true

func supply_types() -> Array:
	var dir = str(s.facts.get("direction",""))
	if int(s.facts.get("direction_day",-10)) < int(s.day) and int(s.facts.get("direction_day",-10))+2 >= int(s.day):
		if dir == "north": return ["medicine","food"]
		if dir == "south": return ["fuel","parts"]
		if dir == "east": return ["water","food"]
	if s.day <= 4: return ["water","food"]
	if s.day <= 7: return ["fuel","parts"]
	if s.day <= 10: return ["medicine","food"]
	if s.day <= 14: return ["water","fuel"]
	if s.day <= 17: return ["food","parts"]
	return ["water","medicine"]

func direction(which: String) -> bool:
	if s.phase != "route" or s.day not in IMPORTANT or "direction" in s.daily.used: return fail("当前不能改变重要日方向")
	if which not in ["north","south","east"]: return false
	s.facts.direction = which; s.facts.direction_day = s.day; s.daily.used.append("direction")
	return true

func intel(action: String) -> bool:
	if s.phase != "route": return false
	if s.day == 2 and action == "frequency": add_clue("frequency"); return true
	if s.day == 5 and action == "frequency" and "frequency" not in s.clues:
		if not pay({"parts":2}): return false
		add_clue("frequency"); return true
	if s.day == 8 and action == "south" and "entrance" not in s.clues:
		if not pay({"fuel":4}): return false
		add_clue("entrance"); s.south_pledge = true; s.daily.hours += 1; s.facts.direction = "south"; s.facts.direction_day = 8
		log_event("南边入口侦察完成：9/10日当地供给为燃料/零件，请保留救援药品2。")
		return true
	return fail("该来源不可重复取得或日期不符")

func route_quote(route: String, style: String) -> Dictionary:
	var q = {"fuel":0.0,"wear":0.0,"hours":0.0,"fatigue":2.0,"distance":0.0,"noise":30,"event_rate":0.0,"vehicle_wear":{}}
	if route == "stay": return q
	if on_foot():
		q.fatigue = 20 + (15 if style == "fast" else 0); q.distance = 20 if style == "fast" else 10
		q.hours = 8; q.event_rate = 40 if style == "quiet" else (80 if style == "fast" else 60)
		return q
	var base = {"safe":[8,2,20],"resource":[8,3,35],"unknown":[6,4,50]}[route]
	var factor = 0.5 if s.edge_km == 15 else 1.0
	q.hours = 8*factor; q.fatigue = 6; q.distance = 30*factor; q.event_rate = base[2]
	for v in cars():
		var fuel = float(base[0] if v == car() else 4)*factor
		var wear = float(base[1])*factor
		var noise = 0
		if has_mod("SP01",v): fuel -= 3; wear += 1
		if has_mod("SP05",v): fuel += 1; noise += 5
		if has_mod("SP10",v): fuel += 1; noise -= 15
		if has_mod("SP23",v): fuel -= 1; noise -= 3
		if has_mod("SP21",v):
			fuel += 1; noise += 5
			if route == "unknown": wear -= 2
		if has_mod("SP02",v):
			fuel += 1
			if s.daily.weather in ["雨","沙尘"]:
				wear -= 2
				if v == car(): q.fatigue -= 2
		if has_mod("SP06",v):
			wear -= 1
			if v == car(): q.fatigue -= 1
		if has_mod("SP15",v):
			noise -= 5
			if route == "safe": wear -= 1
		if has_mod("SP16",v) and s.daily.weather == "沙尘": wear -= 2
		if has_mod("SP22",v) and s.daily.rain_chain and s.daily.weather == "雨":
			wear -= 2; fuel += 1
			if v == car(): q.hours += 0.5; q.fatigue += 1
		if has_mod("SP19",v) and style == "fast": wear += 1
		if has_mod("SP03",v): noise += 10
		if has_mod("SP09",v): noise += 3
		if has_mod("SP27",v): noise += 3
		if has_mod("SP28",v): noise += 5
		var installed_weight = 0
		for id in v.modules.values(): installed_weight += content.modules[id].weight
		if installed_weight >= 40: fuel += 1
		if v.modules.has("rear"): fuel += 1
		if s.edge_km == 15 and v == car(): fuel -= 2
		q.fuel += maxf(2,fuel); q.wear += maxf(0,wear); q.noise += noise
		q.vehicle_wear[str(s.vehicles.find(v))] = maxf(0,wear)
	match style:
		"quiet": q.fuel += 2; q.noise -= 15
		"fast":
			var boost = has_mod("SP19",car())
			q.fuel += 3 if boost else 2; q.hours -= 3 if boost else 2; q.fatigue += 6 if boost else 4; q.noise += 20 if boost else 15
		"detour": q.fuel += 3; q.hours += 2; q.distance += 10
	q.noise = clampi(q.noise,0,100)
	return q

func depart_route(route: String, style: String, supply: String = "") -> bool:
	if s.phase != "route" or route not in ["safe","resource","unknown","stay"] or style not in ["quiet","fast","detour"]: return false
	if weight() > capacity()+0.01: return fail("超载 %.1f 千克，先在库存丢弃或交换" % (weight()-capacity()))
	if not on_foot() and people().size() > 8: return fail("人口超过8人")
	if route == "resource" and supply not in supply_types(): return fail("请选择实际供给类别")
	s.daily.route = route; s.daily.style = style; s.daily.supply = supply
	if s.day == 10 and s.sister == "unresolved":
		s.phase = "rescue"; return true
	var q = route_quote(route,style)
	if not on_foot() and route != "stay" and car().durability <= 20:
		s.daily.card = "V09"; s.phase = "event"; return true
	if not pay({"fuel":q.fuel}): return false
	s.daily.night_travel = s.daily.hours+q.hours > 10
	s.daily.hours += q.hours; s.daily.noise = q.noise; s.daily.distance = q.distance
	all_change("fatigue",q.fatigue)
	if route == "stay": s.stays += 1
	elif on_foot(): s.foot_km += q.distance
	else:
		for v in cars():
			var own_wear = q.vehicle_wear.get(str(s.vehicles.find(v)),0)
			v.durability = maxf(0,v.durability-own_wear)
		s.distance += q.distance
		var progress = 15.0 if s.edge_km == 15 else 30.0
		s.edge_km += progress
		if s.edge_km >= 30: s.legs += 1; s.edge_km = 0
		s.position = "主路"
	s.daily.travel_done = true
	log_event("行进 %s/%s：燃料%.1f，%.1f小时，真实完成主边%d" % [route,style,q.fuel,q.hours,s.legs])
	_check_deaths(false); _check_vehicle_loss()
	if s.ending != "": return true
	# Fixed signal and rescue replace the ordinary travel slot, never the weather.
	if s.day not in [5,10] and route != "stay":
		var id = _draw_card("travel",q.event_rate)
		if id != "": s.daily.card = id; s.phase = "event"; return true
	_arrive()
	return true

func _arrive() -> void:
	if s.ending != "": return
	if s.daily.route == "resource" and not s.daily.supply_claimed and not on_foot():
		var key = "supply_%d" % s.legs
		if key not in s.claimed:
			gain({s.daily.supply:{"water":12,"food":10,"fuel":12,"parts":4,"medicine":1}[s.daily.supply]}); s.claimed.append(key)
		s.daily.supply_claimed = true
	if has_mod("SP25") and s.daily.weather == "雨": gain({"water":2}); log_event("集雨装置：水+2，全队每日一次")
	s.daily.charged = has_mod("SP18") and s.daily.distance >= 15
	s.daily.sun = has_mod("SP26") and s.daily.weather == "晴" and s.daily.hours >= 4
	s.phase = "stop"
	_build_person_pool()
	if s.day in [4,7,9]: log_event("固定招募占当天唯一停歇机会，以及一项主要事务。")

func rescue_missing(frontal: bool = false) -> Array:
	var missing: Array[String] = []
	if s.day != 10 or s.sister != "unresolved": missing.append("只允许第10天首次救援")
	if s.clues.size() < 3: missing.append("三来源情报")
	if not s.south_pledge: missing.append("第8天南线承诺")
	if s.legs < 6: missing.append("至少6条已完成主边，尚未抵达救援站")
	if on_foot() or car().durability < 40: missing.append("主车耐久40")
	var cost = {"fuel":12,"parts":7 if frontal else 5,"medicine":2,"water":mini(8,people().size()+1),"food":mini(8,people().size()+1)}
	for k in cost:
		if s.resources[k] < cost[k]: missing.append("%s≥%d" % [RESOURCE_NAMES[k],cost[k]])
	for role in ["medical","scout"]:
		if qualified(role,50,70.001).is_empty(): missing.append("%s60，健康50且疲劳≤70的执行者" % BOOKS[role])
	return missing

func rescue(action: String) -> bool:
	if s.phase != "rescue": return false
	if action in ["quiet","frontal"]:
		var missing = rescue_missing(action == "frontal")
		if not missing.is_empty(): return fail("救援缺项："+"；".join(missing))
		if not pay({"fuel":12,"parts":7 if action == "frontal" else 5,"medicine":2}): return false
		car().durability -= 18 if action == "frontal" else 8
		var participants: Array = []
		for role in ["medical","scout"]:
			var id = qualified(role,50,70.001)[0].id
			if id not in participants: participants.append(id)
		for id in participants: change(person(id),"fatigue",10)
		all_change("fatigue",6)
		if action == "frontal": all_change("trust",2)
		s.daily.hours += 8; s.daily.travel_done = true
		s.sister = "rescued_pending"
		log_event("第10天救援成功100%%：燃料12、零件%d、药2、车损%d；费用替代本日普通路段。" % [7 if action == "frontal" else 5,18 if action == "frontal" else 8])
		if people().size() >= 8: s.phase = "rescue_seats"
		else: _join_sister(); _arrive()
		return true
	if action == "force":
		if s.legs < 6 or s.clues.size() < 3: return fail("未实际到站并确认现场，不能强闯隔离走廊")
		s.sister = "confirmed_dead"
		var victims: Array = []
		for role in ["medical","scout"]:
			var m = best(role)
			if not m.is_empty() and m.id not in victims: victims.append(m.id)
		for id in victims: change(person(id),"health",-20)
		_check_deaths(true)
	elif action in ["abandon","missing"]: s.sister = "abandoned" if action == "abandon" else "missing"
	else: return false
	all_change("fatigue",2); s.daily.hours += 8; s.daily.route = "stay"; s.daily.travel_done = true
	_arrive()
	return true

func rescue_seat(id: String) -> bool:
	if s.phase != "rescue_seats": return false
	if id == "leave_sister": s.sister = "rescued_not_joined"
	else:
		if not living(id) or id == "captain": return fail("只能选择现有队友离队")
		depart(id,true); _join_sister()
	_arrive()
	return true

func _join_sister() -> void:
	var m = member("sister","妹妹",[45,40,65,70,20,35,45,40],"B")
	m.joined = 10; m.memory = "第10天实际救出并随车同行。"
	s.members.append(m); s.sister = "alive"

func depart(id: String, safe: bool) -> void:
	var m = person(id)
	if m.is_empty() or id == "captain": return
	m.active = false; m.memory = "安全安置离队" if safe else "自行离队，去向未知"
	if id == "sister": s.sister = "safe_departed" if safe else "rescued_unknown"
	log_event(m.name+"离队："+m.memory)

func fixed_recruitment_pending() -> bool:
	return s.phase == "stop" and s.day in [4,7,9] and not s.daily.get("opportunity_used",false)

func task_limit() -> int:
	# The fixed recruitment reply itself needs one of the two daily task slots.
	# Keeping it reserved prevents spending both on other stop actions first.
	return 1 if fixed_recruitment_pending() else 2

func recruit(choice: String) -> bool:
	if s.phase != "stop" or s.day not in [4,7,9] or s.daily.opportunity_used: return fail("当前没有固定招募机会")
	var candidates = {4:["xuning","chenchuan"],7:["duheng","linyue"],9:["cenbai"]}[int(s.day)]
	if choice != "none" and choice not in candidates: return false
	if choice == "none":
		# Explicitly refusing is a mandatory reply, not a benefit. Older saves
		# may already have used both slots before this reservation existed; keep
		# that state recoverable instead of locking the stop phase forever.
		if s.daily.tasks < 2: s.daily.tasks += 1
		s.daily.hours += 0.5
	else:
		if s.daily.tasks >= 2: return fail("主要事务已满，只能点「都不招募」")
		if people().size() >= 8: return fail("满8人，无法加入")
		if not pay({"water":2,"food":2}): return false
		var spec = {"xuning":["许宁",[80,20,45,40,25,65,35,35],"A"],"chenchuan":["陈川",[80,20,45,40,65,25,35,35],"A"],"duheng":["杜衡",[80,20,45,40,35,35,65,30],"B"],"linyue":["林悦",[80,20,45,40,35,35,30,65],"B"],"cenbai":["岑柏",[80,20,45,40,45,45,45,45],"B"]}[choice]
		var m = member(choice,spec[0],spec[1],spec[2]); m.joined = s.day
		for role in BOOKS:
			if m[role] >= 60: m.understanding[role] = 50
		s.members.append(m)
		s.daily.hours += 1
		s.daily.tasks += 1
	s.facts["recruit_day_"+str(s.day)] = choice
	s.daily.opportunity_used = true
	log_event("固定招募选择："+choice+"。互斥永久保留。")
	return true

func use_task(hours: float = 1.0) -> bool:
	if s.phase != "stop": return fail("停歇主要事务每天最多两项")
	if fixed_recruitment_pending() and s.daily.tasks >= 1:
		return fail("请先回应固定招募：今天只剩另一项主要事务")
	if s.daily.tasks >= 2: return fail("停歇主要事务每天最多两项")
	s.daily.tasks += 1; s.daily.hours += hours
	return true

func heal(target: Dictionary, base: int) -> void:
	if target.is_empty() or target.health <= 0 or not target.alive: return
	var bonus = 0
	if not qualified("medical").is_empty():
		bonus = (10 if has_mod("SP07") else 0)+(5 if has_mod("SP08") else 0)
		if has_mod("SP08"): change(target,"fatigue",-5)
	change(target,"health",base+bonus)

func camp(action: String, args: Dictionary = {}) -> bool:
	if s.phase != "camp" or s.daily.camp_used: return fail("唯一营地行动已用")
	var target = person(str(args.get("target","captain")))
	var role = str(args.get("role","repair"))
	match action:
		"rest":
			var wounded = people().filter(func(m): return m.health < 50)
			all_change("fatigue",-20)
			if has_mod("SP08") and not qualified("medical").is_empty():
				for m in wounded.slice(0,2): change(m,"fatigue",-5)
		"care":
			if target.is_empty() or not target.alive or not target.active: return fail("请选择存活目标")
			if not require_operator("medical"): return false
			if not pay({"medicine":1}): return false
			heal(target,25); change(target,"fatigue",-10)
		"repair":
			if on_foot(): return fail("没有可维修车辆")
			if not require_operator("repair"): return false
			if not pay({"parts":3}): return false
			car().durability = minf(100,car().durability+15); s.facts.front_unrepaired = false
		"gather":
			var resource = str(args.get("resource",""))
			if resource not in supply_types() or (on_foot() and resource == "fuel"): return fail("当地无此供给")
			var site = "gather_%d_%s" % [s.legs,s.position]
			if site in s.claimed: return fail("该停歇点已搜集")
			gain({resource:{"water":18,"food":16,"fuel":20,"parts":6,"medicine":2}[resource]}); s.claimed.append(site)
		"read":
			if role not in BOOKS or s.books.get(role,0) <= 0 or target.is_empty() or not target.alive or not target.active or target.health < 30 or target.fatigue >= 95: return fail("读者或书籍不合格")
			var before = target.understanding.get(role,0)
			target.understanding[role] = mini(100,before+25)
			if target.understanding[role] > before: s.knowledge = mini(100,s.knowledge+5)
		"teach":
			if not teach(str(args.get("teacher","")),str(args.get("target","")),role): return false
		"self_study":
			if target.is_empty() or target.health < 30 or target.fatigue >= 95 or target.get(role,0) < 40 or target.get(role,0) >= 60 or target.understanding.get(role,0) < 50 or s.books.get(role,0) <= 0 or target.self_study.get(role,false): return fail("应急自学需能力40–59、理解50、对应书及工具，每人每岗位一次")
			if not pay({"medicine":1} if role == "medical" else {"parts":2}): return false
			target[role] = mini(60,target[role]+20); target.self_study[role] = true
		"record":
			var label = str(args.get("label","共同配给规则"))
			if not s.notebook or s.pages < 1: return fail("没有笔记本或空白页")
			s.pages -= 1
			if label not in s.records: s.records.append(label); s.knowledge = mini(100,s.knowledge+4)
		"tea":
			if not pay({"water":2,"tea":1}): return false
			all_change("like",3); s.tracking = mini(100,s.tracking+2); _ritual("tea")
		"incense":
			if not pay({"incense":1}): return false
			all_change("fatigue",-5); s.exposure = mini(100,s.exposure+3); _ritual("incense")
		"install":
			if not install(str(args.get("module","")),int(args.get("vehicle",s.main_vehicle))): return false
		"remove":
			var v = s.vehicles[int(args.get("vehicle",s.main_vehicle))]
			var slot = str(args.get("slot",""))
			if v.destroyed or not v.modules.has(slot): return fail("该部位没有可拆核心")
			var id = v.modules[slot]; s.cores[id] = s.cores.get(id,0)+1; v.modules.erase(slot)
		"new_car":
			if not on_foot() or not s.facts.get("wreck_"+str(s.legs),false) or s.position != "废车点" or qualified("repair").is_empty(): return fail("需实际抵达已知废车点和合格维修者")
			if not pay({"parts":6,"fuel":10}): return false
			s.vehicles.append(vehicle("修复的旧车",50)); s.main_vehicle = s.vehicles.size()-1; s.foot_deadline = 0
		"second_car":
			if s.day < 15 or "guild" not in s.contacts or s.factions.guild <= -30 or cars().size() >= 2: return fail("第15日起，非敌视商会报价，最多两车")
			if not pay({"parts":12,"fuel":10}): return false
			s.vehicles.append(vehicle("商会旧车",50)); s.foot_deadline = 0
		"exchange_book":
			if s.books.get(role,0) <= 0: return fail("没有可交换的实体书")
			var reward = str(args.get("resource","water"))
			if reward not in ["water","food","parts"] or s.contacts.is_empty(): return false
			s.books[role] -= 1; gain({reward:{"water":10,"food":8,"parts":4}[reward]}); s.trades += 1; _faction(str(s.contacts[0]),5)
		"burn_book":
			if s.books.get(role,0) <= 0: return false
			s.books[role] -= 1; all_change("fatigue",-10)
			if role not in s.records: s.knowledge = maxi(0,s.knowledge-5)
		_: return fail("未知营地行动")
	s.daily.camp_used = true; s.daily.hours += 2
	log_event("唯一营地行动："+action)
	_check_deaths(false)
	return true

func teach(teacher_id: String, student_id: String, role: String) -> bool:
	var teacher = person(teacher_id); var student = person(student_id)
	if teacher.is_empty() or student.is_empty() or teacher_id == student_id or role not in BOOKS: return fail("请选择不同的教师学员和岗位")
	if not teacher.alive or not teacher.active or teacher.health < 30 or teacher.fatigue >= 95 or teacher.get(role,0) < 60 or teacher.understanding.get(role,0) < 50 or not student.alive or not student.active or student.health < 30 or student.fatigue >= 95 or s.books.get(role,0) <= 0: return fail("教师需能力60理解50；双方健康30疲劳<95，且有书")
	var score = clampi(teacher[role]-20+floori(student.trust/5.0)+int(s.daily.get("j_modifier",0))+int(student.get("j_bonus_"+role,0)),5,95)
	student.erase("j_bonus_"+role); s.daily.erase("j_modifier")
	var streak = int(student.training.get(role,0))
	var success = streak >= 2 and student[role] >= 50 or chance(score)
	s.daily.last_teaching_success = success
	var before = student[role]+student.understanding.get(role,0)
	student.understanding[role] = mini(100,student.understanding.get(role,0)+(15 if success else 5))
	if success: student[role] = mini(100,student[role]+10)
	student.training[role] = 0 if not success or streak >= 2 else streak+1
	if not student.has("last_learning"): student.last_learning = {}
	student.last_learning[role] = s.day
	if student[role]+student.understanding[role] > before: s.knowledge = mini(100,s.knowledge+(5 if success else 1))
	log_event("教学%s：概率%d%%，实际%s" % [student.name,100 if streak >= 2 and student[role] >= 50 else score,"成功" if success else "未成功"])
	return true

func _ritual(kind: String) -> void:
	var streak = int(s.facts.get("ritual_count",0))+1 if s.facts.get("ritual_kind","") == kind else 1
	s.facts.ritual_kind = kind; s.facts.ritual_count = streak
	if streak >= 3: all_change("trust",3); s.facts.ritual_count = 0

func install(id: String, vehicle_index: int) -> bool:
	if not content.modules.has(id) or vehicle_index < 0 or vehicle_index >= s.vehicles.size(): return false
	var v = s.vehicles[vehicle_index]; var mod = content.modules[id]
	if v.destroyed or v.durability <= 0 or qualified("repair").is_empty() or s.cores.get(id,0) < 1: return fail("车辆、维修者或实体核心不合格")
	if not pay({"parts":mod.cost}): return false
	var old = v.modules.get(mod.slot,"")
	if old != "": s.cores[old] = s.cores.get(old,0)+1
	s.cores[id] -= 1; v.modules[mod.slot] = id
	return true

func _faction(id: String, amount: int) -> void:
	s.factions[id] = clampi(s.factions.get(id,0)+amount,-100,100)

func social(action: String, target: String = "", faction: String = "east", offer: int = 0) -> bool:
	if not use_task(): return false
	match action:
		"listen":
			if not living(target) or target == "captain" or "listen_"+target in s.daily.used: return fail("同一人每天只倾听一次")
			change(person(target),"trust",2); change(person(target),"like",3); s.daily.used.append("listen_"+target)
		"equal":
			if int(s.facts.get("equal_day",-10))+3 > int(s.day): return fail("平等决策冷却3日")
			if not pay({"water":2}): return false
			all_change("like",3); s.facts.equal_day = s.day; _institution()
		"favor":
			if "favor" in s.daily.used or not pay({"water":2}): return false
			for m in people(): change(m,"trust",8 if m.group == "A" else -8)
			s.daily.used.append("favor")
		"command":
			if int(s.facts.get("command_day",-10))+2 > int(s.day): return fail("强制命令冷却2日")
			all_change("trust",-5); all_change("like",-8); s.facts.command_day = s.day
		"mediate":
			if not pay({"water":2,"food":2}): return false
			_mediate()
		"contribute":
			if faction not in s.contacts or "contribute_"+faction in s.daily.used: return fail("该阵营尚未接触或今日已贡献")
			if not pay({"water":5,"food":5}): return false
			_faction(faction,15); s.daily.used.append("contribute_"+faction)
		"trade":
			if not _trade(faction,offer): return false
		"raid":
			if faction not in s.contacts: return false
			gain({"water":10,"food":10,"fuel":12}); damage_car(5,true); _faction(faction,-30); all_change("trust",-10); s.raids += 1; s.tracking = mini(100,s.tracking+15)
		"recover_pages":
			if s.facts.get("pages_recovered",false) or not pay({"parts":1}): return false
			s.pages += 5; s.facts.pages_recovered = true
		"store_copy":
			if s.records.is_empty() or s.pages < 2: return fail("需要已有可读记录及2页复制")
			s.pages -= 2; s.stored_copy = true; s.facts.copy_location = s.legs; s.knowledge = mini(100,s.knowledge+1)
		"safe_depart":
			if s.position != "避难点" or not living(target) or target == "captain" or person(target).trust < 30: return fail("需已确认安全接纳点、成员同意及真实资源移交")
			if not pay({"water":1,"food":1}): return false
			depart(target,true)
		_: return false
	_check_vehicle_loss(); _check_deaths(false)
	return true

func _trade(faction: String, offer: int) -> bool:
	if faction not in s.contacts or s.factions[faction] <= -30 or "trade_"+faction in s.daily.used: return fail("未接触、敌视或同一运输员今日已交易")
	var offers = [["fuel",6,"food",10],["food",4,"water",10],["parts",3,"fuel",12],["water",6,"medicine",1],["medicine",1,"parts",4]]
	if offer < 0 or offer >= offers.size(): return false
	var q = offers[offer]; var amount = maxi(1,int(q[1])+ (2 if qualified("logistics").is_empty() else -1))
	if not pay({q[0]:amount}): return false
	gain({q[2]:q[3]}); s.trades += 1; _faction(faction,5); s.daily.used.append("trade_"+faction)
	return true

func _institution() -> void:
	if "institution" in s.daily.used: return
	var a = false; var b = false
	for m in people():
		if m.id != "captain" and m.trust >= 50:
			if m.group == "A": a = true
			else: b = true
	if a and b:
		s.institution = mini(6,s.institution+1); s.daily.used.append("institution")
		if s.institution >= 3: s.facts.public_rules = true; s.private_risk = maxi(0,s.private_risk-10)

func _mediate() -> void:
	var average = trust()
	for m in people():
		if m.id != "captain": change(m,"trust",clampf(average-m.trust,-10,10))
	s.split_nights = 0

func acquire_core(location_id: String, core: String, salvage: bool = false) -> bool:
	if s.phase != "stop" or s.daily.opportunity_used or s.daily.special_used or s.day in [4,5,7,9,10] or s.daily.tasks >= 2: return fail("特殊获取每日一次，占机会和主要事务，固定日不扩容")
	var location: Dictionary = {}
	for loc in content.locations:
		if loc.id == location_id: location = loc; break
	if location.is_empty() or location.chapter != s.legs or location_id in s.claimed or core not in location.choices: return fail("该地点不在当前位置或已领取")
	if on_foot():
		if s.daily.distance+4 > (20 if s.daily.style == "fast" else 10): return fail("往返4千米超过今日徒步距离")
		all_change("fatigue",8); s.daily.distance += 4
	else:
		if not pay({"fuel":1}): return false
	if not use_task(2): return false
	s.daily.opportunity_used = true; s.daily.special_used = true; s.claimed.append(location_id)
	if salvage: gain({"parts":3})
	else: s.cores[core] = s.cores.get(core,0)+1
	return true

func buy_core(core: String) -> bool:
	if s.phase != "stop" or s.day < 15 or "guild" not in s.contacts or s.factions.guild <= -30 or s.purchase_count >= 2 or s.daily.special_used or "trade_guild" in s.daily.used or not content.modules.has(core): return fail("商会采购前置不满足或额度已用")
	var cost = 7 if not qualified("logistics").is_empty() else 8
	if not pay({"parts":cost}) or not use_task(): return false
	s.cores[core] = s.cores.get(core,0)+1; s.daily.special_used = true; s.daily.used.append("trade_guild"); s.purchase_count += 1; s.trades += 1; _faction("guild",5)
	return true

func drop(resource: String, quantity: float) -> bool:
	if s.phase not in ["morning","route","stop","camp","cargo"] or quantity <= 0 or quantity > s.resources.get(resource,0): return fail("丢弃数量无效")
	s.resources[resource] -= quantity; log_event("永久丢弃："+cost_text({resource:quantity}))
	return true

func walk_to(place: String) -> bool:
	if not on_foot() or s.phase != "route" or place not in ["避难点","废车点"]: return false
	if place == "废车点" and not s.facts.get("wreck_"+str(s.legs),false): return fail("当前位置尚无已知废车支点")
	if weight() > capacity(): return fail("先确认徒步保留清单，超出携行上限")
	s.daily.route = "foot"; s.daily.style = "quiet"; s.daily.distance = 6 if place == "避难点" else 8
	s.foot_km += s.daily.distance; s.daily.hours += 8; all_change("fatigue",20); s.position = place; s.daily.travel_done = true
	s.phase = "stop"; _build_person_pool()
	return true

func damage_car(amount: float, battle: bool = false) -> void:
	if on_foot(): return
	var v = car()
	if battle:
		if has_mod("SP23",v): amount += 2
		amount = maxf(0,amount-(8 if has_mod("SP05",v) else (5 if has_mod("SP13",v) else 0)))
	v.durability = maxf(0,v.durability-amount)
	log_event("车辆损伤：实际耐久−%.1f" % amount)
	_check_vehicle_loss()

func abandon_car() -> bool:
	if on_foot(): return false
	car().destroyed = true; _check_vehicle_loss()
	return true

func _check_vehicle_loss() -> void:
	for v in s.vehicles:
		if v.durability <= 0: v.destroyed = true
	if on_foot() and s.foot_deadline == 0:
		s.foot_deadline = 12 if s.day <= 12 else mini(20,s.day+1)
		log_event("最后车辆失去。徒步携行上限%.1f千克；最近安全支点6千米，废车支点8千米（需已知），截止第%d夜。" % [capacity(),s.foot_deadline])

func _check_deaths(sudden: bool) -> void:
	var captain_died = false
	for m in s.members:
		if m.alive and m.active and m.health <= 0:
			m.alive = false; m.memory = "第%d天死亡，不可急救复活。" % s.day
			if m.id == "captain": captain_died = true
			if m.id == "sister": s.sister = "rescued_dead"
	if people().is_empty(): _end("E14" if s.knowledge >= 50 and s.stored_copy else "E01")
	elif captain_died: _end("E16" if sudden else "E17")

func _end(id: String) -> void:
	s.ending = id; s.phase = "ending"
	if s.sister == "unresolved": s.sister = "missing"

func ending_missing(id: String, after_night: bool = false) -> Array:
	var m: Array[String] = []
	var n = people().size(); var c = n-1; var v = not on_foot(); var arrived = s.legs >= 8 or s.position == "避难点"
	if s.day < 12 and not (on_foot() and s.day == s.foot_deadline and id in ["E02","E03","E07"]): m.append("第12天起完成目标")
	if not arrived and id not in ["E04","E05","E10","E13"]: m.append("实际抵达至少8条主边的终点入口或本地徒步庇护点")
	match id:
		"E02":
			if v or c < 3 or s.position != "避难点": m.append("无车、至少3名队友且已到非盟友安全避难点")
		"E03":
			if c > 2 or s.factions.get(str(s.facts.get("join_faction","south")),0) < 60: m.append("队友≤2、目标阵营关系60")
		"E04":
			if not v or s.raids < 2 or trust() > 30: m.append("可用车、掠夺2次、全队信任≤30")
		"E05":
			var enemies = s.factions.values().filter(func(x): return x <= -30).size()
			if not v or c < 2 or affection() >= 30 or enemies < 2: m.append("可用车、队友2、好感<30、敌视阵营2")
		"E06":
			if not v or car().durability < 20 or s.trades < 4 or "guild" not in s.contacts: m.append("可用车耐久20、4次公平交易、接触商会")
		"E07":
			if s.stays < 3 or s.resources.fuel > 10 or n < 2: m.append("停留3次、燃料≤10、至少2人")
			if not after_night and (s.resources.water < n*(2 if on_foot() else 1) or s.resources.food < n): m.append("当晚足额配给")
			if after_night and not s.daily.get("full_rations",false): m.append("当晚实际足额配给")
		"E08":
			if c < 3 or affection() < 60 or s.factions.values().filter(func(x): return x >= 30).size() < 2: m.append("3名队友、好感60、2阵营友好30")
		"E10":
			if group_gap() < 30 or s.split_nights < 2: m.append("群体差30且连续2夜")
		"E11":
			if n != 1 or not living("captain"): m.append("队长独自存活")
		"E12":
			if not living("sister") or s.sister != "alive" or s.goal != "south": m.append("实际救出妹妹、仍在队存活，抵达南边正式定居区")
		"E13":
			if not v or s.observations < 3 or s.obey < 3: m.append("可用车、同一轮廓3条记录和连续3次遵规")
		_: m.append("不是可主动完成的目标")
	return m

func complete_goal(id: String) -> bool:
	if s.phase != "stop": return false
	var missing = ending_missing(id)
	if not missing.is_empty(): return fail("；".join(missing))
	if not use_task(): return false
	if id == "E05" and not pay({"food":5,"parts":2}): return false
	if id == "E06" and not pay({"water":5,"food":5}): return false
	s.intent = id; log_event("目标行动已完成，待当晚配给与伤亡检查后核验："+ENDINGS[int(id.substr(1))-1])
	return true

func settle() -> bool:
	if s.phase not in ["camp","stop"] or s.daily.night_done: return false
	if s.day in [4,7,9] and not s.daily.opportunity_used: return fail("先回应固定招募：可选一人，或点「都不招募」")
	if not s.daily.camp_used: return fail("先完成一次营地行动")
	s.daily.night_done = true
	var population = people().duplicate()
	var water_each = 2 if on_foot() else 1
	var full = true
	# Allocate one unit at a time in stable order so finite stock is never reused.
	var allocations = {}
	for m in population: allocations[m.id] = {"water":0.0,"food":0.0}
	for resource in ["water","food"]:
		var required = water_each if resource == "water" else 1
		for round_index in range(required):
			for m in population:
				var skip = resource == "food" and (s.facts.get("skip_captain_food",0) == s.day and m.id == "captain" or s.facts.get("skip_food_"+m.id,0) == s.day) or resource == "water" and s.daily.get("skip_water","") == m.id
				if s.daily.get("allocation_plan",{}).get(m.id,{}).get(resource,required) <= round_index: skip = true
				if skip: continue
				var allocated = minf(1,s.resources[resource]); s.resources[resource] -= allocated; allocations[m.id][resource] += allocated
	var transfer_to = str(s.daily.get("transfer_water",""))
	if allocations.has(transfer_to) and allocations.has("captain") and allocations.captain.water >= 1:
		allocations.captain.water -= 1; allocations[transfer_to].water += 1
	var prepaid = int(s.daily.get("food_prepaid",0))
	for m in population:
		if prepaid > 0 and allocations[m.id].food < 1: allocations[m.id].food += 1; prepaid -= 1
		var shortage_water = allocations[m.id].water < water_each
		var shortage_food = allocations[m.id].food < 1
		var hkey = "hunger_"+m.id; var wkey = "thirst_"+m.id
		s.facts[wkey] = int(s.facts.get(wkey,0))+1 if shortage_water else 0
		s.facts[hkey] = int(s.facts.get(hkey,0))+1 if shortage_food else 0
		if shortage_water:
			change(m,"health",-15-(10 if s.facts[wkey] >= 2 else 0)); change(m,"fatigue",10); full = false
		if shortage_food:
			change(m,"health",-8-(5 if s.facts[hkey] >= 2 else 0)); change(m,"fatigue",5); full = false
		if not shortage_water and not shortage_food:
			change(m,"fatigue",-2)
			if m.health >= 50 and m.fatigue < 80: change(m,"health",2)
		log_event("%s配给：水%.1f/%d 食%.1f/1" % [m.name,allocations[m.id].water,water_each,allocations[m.id].food])
	if prepaid > 0: s.resources.food += prepaid
	s.daily.rations = allocations; s.daily.full_rations = full
	var extra = maxf(0,s.daily.hours-12)*2
	if extra > 0: all_change("fatigue",extra); log_event("当日超时%.2f小时，疲劳+%.2f" % [s.daily.hours-12,extra])
	s.daily.overtime_applied = extra
	for m in people():
		if m.fatigue >= 80: change(m,"health",-5)
	_check_deaths(false)
	if s.ending != "": return true
	s.exposure = maxi(0,s.exposure-3)
	if s.daily.get("event","") == "": s.tracking = maxi(0,s.tracking-5)
	if group_gap() >= 30: s.split_nights += 1
	else: s.split_nights = 0
	if s.split_nights >= 2:
		s.phase = "split"; return true
	_finish_night()
	return true

func split_decision(action: String) -> bool:
	if s.phase != "split": return false
	if action == "mediate":
		if not pay({"water":2,"food":2}): return false
		_mediate(); s.daily.hours += 1
	elif action == "separate":
		if s.day >= 12: _end("E10"); return true
		var group_a = []; var group_b = []
		for m in people():
			if m.id != "captain":
				if m.group == "A": group_a.append(m)
				else: group_b.append(m)
		var lowest_group = person("ajie").get("group","B")
		for m in people().duplicate():
			if m.group == lowest_group and m.id != "captain": depart(m.id,false)
		s.split_nights = 0
	else: return fail("请调停或明确分裂")
	var extra = maxf(0,s.daily.hours-12)*2-s.daily.overtime_applied
	if extra > 0: all_change("fatigue",extra)
	_check_deaths(false)
	if s.ending == "": _finish_night()
	return true

func _finish_night() -> void:
	if s.intent != "" and ending_missing(s.intent,true).is_empty(): _end(s.intent)
	elif on_foot() and s.day >= s.foot_deadline: _end("E17")
	elif s.day >= 20: _end("E09")
	else: s.phase = "night"
	s.history.append({"day":s.day,"log":s.daily.log.duplicate(),"resources":s.resources.duplicate(),"people":people().size(),"draws":s.daily.draws.duplicate(true)})

func next_day() -> bool:
	if s.phase != "night" or s.day >= 20: return false
	s.day += 1; _begin_day(); return true

func retry_day() -> bool:
	if day_start.is_empty(): return false
	var seed_value = int(Time.get_unix_time_from_system()*1000000)+rng.randi()
	s = day_start.duplicate(true); rng.seed = seed_value; s.rng = str(rng.state); day_start = s.duplicate(true); _draw_day()
	return true

func epilogue_id() -> String:
	match s.sister:
		"alive","safe_departed": return "S01"
		"rescued_dead": return "S02"
		"confirmed_dead": return "S03"
		"abandoned": return "S05"
		"rescued_not_joined","rescued_pending": return "S06"
	return "S04"

func checkpoint() -> Dictionary:
	s.rng = str(rng.state)
	return canonical({"schema":1,"spec":content.sha256,"current":s,"day_start":day_start})

# JSON has one number type and String keys. Normalize both sides of a save at
# this boundary; fractional fuel, time and rations remain fractional. RNG is
# intentionally a string, because its 64-bit state exceeds JSON's precision.
static func canonical(value: Variant) -> Variant:
	if value is Dictionary:
		var result = {}
		for key in value: result[str(key) if key is StringName else key] = canonical(value[key])
		return result
	if value is Array:
		var result = []
		for item in value: result.append(canonical(item))
		return result
	if value is float and is_finite(value) and value == floor(value) and absf(value) < 9007199254740992.0: return int(value)
	return value

func restore(payload: Dictionary) -> bool:
	if payload.get("schema",0) != 1 or payload.get("spec","") != content.sha256 or not payload.get("current") is Dictionary or not payload.get("day_start") is Dictionary: return fail("存档不兼容总稿版本")
	var incoming = canonical(payload.current)
	for key in ["resources","members","vehicles","daily","day","phase","rng","facts","history","clues","cores","books"]:
		if not incoming.has(key): return fail("存档缺字段："+key)
	if incoming.day < 1 or incoming.day > 20 or incoming.members.size() < 1: return fail("存档日期或人口无效")
	for key in RESOURCE_NAMES:
		if not incoming.resources.has(key) or not incoming.resources[key] is float and not incoming.resources[key] is int or incoming.resources[key] < 0: return fail("库存数据无效")
	for m in incoming.members:
		for key in ["health","fatigue","trust","like","repair","medical","scout","logistics"]:
			if not m.has(key) or m[key] < 0 or m[key] > 100: return fail("成员数据无效")
	s = incoming; day_start = canonical(payload.day_start); rng.state = int(s.rng)
	return true

func command(action: String, args: Dictionary = {}) -> bool:
	var before = checkpoint(); error = ""
	var result = false
	match action:
		"prepare": result = prepare(str(args.get("id","none")),str(args.get("target","captain")))
		"finish_prepare": result = finish_preparation()
		"direction": result = direction(str(args.id))
		"intel": result = intel(str(args.id))
		"depart": result = depart_route(str(args.route),str(args.style),str(args.get("supply","")))
		"rescue": result = rescue(str(args.id))
		"rescue_seat": result = rescue_seat(str(args.id))
		"recruit": result = recruit(str(args.id))
		"social": result = social(str(args.id),str(args.get("target","")),str(args.get("faction","east")),int(args.get("offer",0)))
		"camp": result = camp(str(args.id),args)
		"begin_camp":
			if s.phase == "stop":
				if fixed_recruitment_pending(): result = fail("请先回应固定招募：可选一人，或点「都不招募」")
				else: s.phase = "camp"; result = true
		"settle": result = settle()
		"next": result = next_day()
		"retry": result = retry_day()
		"drop": result = drop(str(args.id),float(args.amount))
		"acquire": result = acquire_core(str(args.location),str(args.id),bool(args.get("salvage",false)))
		"buy_core": result = buy_core(str(args.id))
		"goal": result = complete_goal(str(args.id))
		"split": result = split_decision(str(args.id))
		"walk": result = walk_to(str(args.id))
		"card": result = resolve_card(str(args.id),int(args.option),args)
		"device": result = device(str(args.id))
	if not result:
		var reason = error
		restore(before); error = reason if reason != "" else "当前阶段不能执行此项"
	else:
		_check_vehicle_loss()
		s.rng = str(rng.state)
	return result

func _draw_card(_pool: String, _rate: float) -> String:
	return ""

func _build_person_pool() -> void:
	s.daily.card_candidates = []

func resolve_card(_id: String, _option: int, _args: Dictionary = {}) -> bool:
	return fail("卡片执行器尚未加载")

func device(_id: String) -> bool:
	return false
