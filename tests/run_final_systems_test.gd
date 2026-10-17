extends SceneTree
const Rules = preload("res://src/game/world_rules.gd")
var checks = 0
var failures = 0
func _init(): call_deferred("run")
func check(ok: bool, label: String):
	checks += 1
	if not ok: failures += 1; print("FAIL ",label)
func run():
	var r = Rules.new(); r.new_game(88)
	check(r.content.days.size() == 20 and r.content.story.size() == 8 and r.content.sources.size() == 15,"full fixed day/story/source import")
	check(r.content.cards.M01.options.size() == 3 and r.content.cards.T01.options.size() == 4,"option references never become extra choices")
	# Boundary fixtures below deliberately exercise individual systems, not full runs.
	r.s.day = 2; r.s.phase = "route"
	check(r.command("direction",{"id":"south"}) and r.supply_types() == ["water","food"] and r.s.clues.is_empty(),"direction does not rewrite current supply or award intel")
	r.s.day = 3
	check(r.supply_types() == ["fuel","parts"],"direction covers subsequent day")
	r.s.day = 5
	check(r.supply_types() == ["fuel","parts"],"expired direction falls back to day-five supply band")
	r.new_game(9); r.s.phase = "route"; r.s.day = 8
	check(r.command("intel",{"id":"south"}) and r.s.daily.tasks == 1 and r.s.resources.fuel == 76,"entrance survey uses one task fuel4 hour1")
	var before = r.checkpoint()
	check(not r.command("intel",{"id":"south"}) and before.current == r.s,"no duplicate source or payment")
	r.new_game(10); r.s.phase = "camp"; r.s.resources.medicine = 0
	before = r.checkpoint()
	check(not r.command("camp",{"id":"care","target":"captain"}) and before.current == r.s,"invalid camp action cannot reserve random card")
	r.new_game(11); r.s.day = 4; r.s.phase = "stop"
	check(r.command("recruit",{"id":"xuning"}) and r.person("xuning").understanding.medical == 50,"new specialist starts with book understanding50")
	r.new_game(12); r.s.phase = "camp"; r.s.daily.camp_checked = true
	r.car().modules.roof = "SP07"; r.car().modules.rear = "SP08"; r.person("captain").health = 40; r.person("captain").fatigue = 30
	check(r.command("camp",{"id":"care","target":"captain"}) and r.person("captain").health == 80 and r.person("captain").fatigue == 15,"distinct medical devices stack once: 25+10+5 and fatigue10+5")
	r.new_game(13); r.person("zhang").active = false; r.person("captain").repair = 45
	check(r.command("prepare",{"id":"repair"}) and r.s.resources.parts == 21,"trainee repair pays support2 plus normal2")
	r.s.phase = "camp"; r.s.daily.camp_checked = true
	check(not r.command("camp",{"id":"repair"}),"temporary support cannot be reused without learning")
	r.new_game(14); r.s.phase = "stop"; r.s.day = 3; r.s.legs = 3
	check(r.command("acquire",{"location":"LOC-SP01","id":"SP05"}) and r.s.cores.SP05 == 1,"real fixed site core acquisition")
	before = r.checkpoint()
	check(not r.command("acquire",{"location":"LOC-SP04","id":"SP01"}) and before.current == r.s,"shared special opportunity cap")
	r.s.phase = "camp"; r.s.daily.camp_checked = true
	var parts = r.s.resources.parts
	check(r.command("camp",{"id":"install","module":"SP05","vehicle":0}) and r.car().modules.front == "SP05" and r.s.resources.parts == parts-12 and r.s.cores.SP05 == 0,"install consumes full recipe and unique core")
	r.new_game(15); r.s.vehicles.append(r.vehicle("副车",50)); r.s.vehicles[1].modules.engine = "SP01"; r.s.vehicles[0].modules.wheels = "SP06"
	var q = r.route_quote("safe","quiet")
	check(q.fuel == 12 and q.vehicle_wear["0"] == 1 and q.vehicle_wear["1"] == 3,"independent vehicle fuel floor wear and main fatigue")
	r.normalize_cargo(); r.s.phase = "route"
	check(r.command("transfer",{"id":"water","amount":20,"vehicle":1}) and r.s.vehicles[1].cargo.water == 20 and r.s.vehicles[0].cargo.water == 30,"cargo physically transfers, aggregate stock unchanged")
	check(r.command("assign_vehicle",{"vehicle":1,"target":"ajie"}) and r.person("ajie").vehicle == 1,"passenger assignment before travel")
	r.s.phase = "event"
	check(not r.command("assign_vehicle",{"vehicle":0,"target":"ajie"}),"cannot swap passenger during damage event")
	r.new_game(16); r.s.phase = "event"; r.s.daily.card = "EV01"; r.car().modules.front = "SP12"
	check(r.command("card",{"id":"EV01","option":1,"target":"captain"}) and r.car().durability == 76 and r.person("captain").health == 85,"ordinary collision uses SP12 only")
	r.new_game(17); r.s.phase = "event"; r.s.daily.card = "EV03"; r.car().modules.engine = "SP17"
	check(r.command("card",{"id":"EV03","option":1}) and r.s.resources.fuel == 78,"leak device protects3 of actual loss5")
	r.new_game(18); r.s.phase = "camp"; r.s.daily.camp_used = true; r.car().modules.rear = "SP04"; r.car().modules.engine = "SP18"; r.s.daily.charged = true; r.s.position = "避难点"
	var water = r.s.resources.water; var fuel = r.s.resources.fuel
	check(r.command("device",{"id":"water"}) and r.s.resources.water == water,"device request waits until camp end")
	check(r.command("settle") and r.s.resources.water == water+3-5 and r.s.resources.fuel == fuel,"one valid power supply replaces device fuel only")
	r.new_game(19); r.s.phase = "camp"; r.s.daily.camp_used = true; r.s.resources.water = 300; r.car().modules.rear = "SP04"; r.s.position = "避难点"
	check(r.command("device",{"id":"water"}),"device scheduling available")
	before = r.checkpoint()
	check(not r.command("settle") and before.current == r.s,"capacity failure rolls back device fuel and night costs")
	r.new_game(20); r.s.phase = "morning"; r.car().modules.rear = "SP29"
	check(r.command("container",{"id":"archive","role":"repair"}) and r.command("container",{"id":"archive","role":"medical"}) and not r.command("container",{"id":"archive","role":"scout"}),"two specified archive entities only")
	r.new_game(21); r.s.phase = "camp"; r.s.daily.camp_used = true
	check(r.command("ration",{"id":"water","target":"captain","amount":0}) and r.command("settle") and r.person("captain").health == 75 and r.s.resources.water == 46,"custom allocation consumes actual quantities and shortage once")
	r.new_game(22); r.s.phase = "rescue"; r.s.day = 10; r.s.legs = 6; r.s.clues = ["frequency","coordinates","entrance"]
	check(not r.command("rescue",{"id":"force"}),"no imagined confirmed sister death without observing site")
	check(r.command("rescue",{"id":"inspect"}) and r.command("rescue",{"id":"force"}) and r.s.sister == "confirmed_dead","observed unprepared force has explicit fatal consequence")
	r.new_game(23); r.s.phase = "rescue"; r.s.day = 10; r.s.daily.route = "safe"; r.s.daily.style = "quiet"
	check(r.command("rescue",{"id":"abandon"}) and r.s.resources.fuel == 70 and r.s.daily.travel_done,"abandoning rescue pays ordinary chosen travel")
	r.new_game(24); r.s.phase = "camp"; r.s.facts.knowledge_loss_due = 1
	check(r.command("camp",{"id":"rest"}) and r.s.daily.card == "N-F01" and r.s.daily.tasks == 0,"knowledge loss is compulsory camp replacement outside daytime slots")
	check(r.command("card",{"id":"N-F01","option":3}) and r.s.daily.camp_used,"oral fallback handles zero-paper zero-teacher knowledge crisis")
	r.new_game(25); r.s.phase = "route"; r.s.legs = 3
	check(r.command("map_choice",{"id":"sealed_tunnel"}) and r.command("depart",{"route":"safe","style":"quiet"}) and r.s.daily.card == "N-C04","physical tunnel crisis overrides random travel even good car")
	check(r.command("card",{"id":"N-C04","option":2}) and r.s.ending == "E01","explicit impossible tunnel batch death")
	r.new_game(26); r.s.phase = "split"; r.s.position = "避难点"; r.s.daily.overtime_applied = 0
	r.person("zhang").trust = 35; r.person("elin").trust = 35; r.person("ajie").trust = 80; r.person("sofia").trust = 80
	check(r.command("split",{"id":"safe"}) and not r.living("zhang") and r.living("ajie") and r.s.ending == "","safe split selects truly lower group and continues")
	r.new_game(27); r.s.day = 12; r.s.legs = 8; r.s.phase = "stop"; r.s.trades = 4; r.s.contacts = ["guild"]
	var distance = r.s.distance
	check(r.command("goal",{"id":"E06"}) and r.s.distance == distance+6 and r.s.ending == "" and not r.command("goal",{"id":"E06"}),"terminal action travels6km and cannot repeat payment")
	print("FINAL_SYSTEMS checks=",checks," failures=",failures)
	quit(failures)
