extends SceneTree
const Rules = preload("res://src/game/world_rules.gd")
const Prose = preload("res://src/game/presentation.gd")
const Saves = preload("res://src/game/save.gd")
const Pilot = preload("res://tests/final_route_pilot.gd")
var checks = 0
var failures = 0
func _init(): call_deferred("run")
func check(ok: bool, label: String):
	checks += 1
	if not ok: failures += 1; print("FAIL ",label)
func fresh():
	var r = Rules.new(); r.new_game(81); return r
func request(r,id:String,owner:String):
	r.s.daily.card_candidates = [id]; r.s.daily.person_queue = [{"id":id,"owner":owner,"first":r.s.day,"hidden":false}]
func run():
	var r = fresh()
	check(not r._eligible("N-F05") and "N-F05" not in r.s.daily.card_candidates,"first dawn has no invented previous rest refusal")
	check(not Prose.story(r).contains("{守夜") and not Prose.story(r).contains("守夜人取"),"dawn prose contains no placeholders or implementation instructions")
	r.s.facts.last_night = {"watcher":"zhang","injured":true,"footprints":true,"departed":true}
	var rng_before = r.rng.state
	check(Prose.morning(r).contains("他后来睡着了") and r.rng.state == rng_before,"watch report uses injury priority with no new die")
	r.person("zhang").active = false
	check(not Prose.morning(r).contains("老张") and Prose.morning(r).contains("你把火"),"absent watcher and mechanic never speak at dawn")
	r = fresh(); r.s.day = 4; r.s.phase = "stop"; r.s.daily.opportunity_used = true
	check(r.command("social",{"id":"raid","faction":"east"}) == false,"cannot raid uncontacted transport")
	r.s.contacts = ["east","south","guild"]
	check(r.command("social",{"id":"raid","faction":"east"}),"first raid is a real task")
	var snapshot = r.checkpoint()
	check(not r.command("social",{"id":"raid","faction":"south"}) and r.checkpoint() == snapshot,"same-day raid fails atomically")
	r.s.day = 7; r.s.daily.tasks = 0
	check(not r.command("social",{"id":"raid","faction":"south"}),"three intervening full days have not elapsed")
	r.s.day = 8
	check(r.command("social",{"id":"raid","faction":"south"}),"raid becomes legal on fourth subsequent day")
	r = fresh(); r.s.phase = "stop"; r.s.resources.food = 18; r.s.facts.private_allocation = true
	r.s.daily.opportunity_card = "S02"; r.car().modules.rear = "SP28"; r.normalize_cargo()
	r._enter_theft()
	check(r.s.resources.food == 15 and r.s.facts.theft_ledger.amount == 3,"entry theft protects only three real foods in equipped car")
	r._enter_theft()
	check(r.s.resources.food == 15,"viewing theft twice never debits twice")
	check(r.command("card",{"id":"S02","option":2}) and r._eligible("T13"),"private warning exposes an actual unpaid theft ledger")
	r.s.day += 1; r.s.phase = "morning"; r.s.daily.tasks = 0; request(r,"T13","sofia")
	# Find an ordinary seed for the recovery die; seed only controls RNG, not quantities.
	r.rng.seed = 81
	check(r.command("card",{"id":"T13","option":0}),"public recovery executes against the original ledger")
	check(r.s.resources.food <= 18,"recovery never exceeds the recorded stolen amount")
	if r.s.facts.theft_ledger.resolved: check(not r._eligible("T13"),"resolved theft cannot pay out twice")
	r = fresh(); r.s.day = 3; r.s.facts.panic = true; r.s.facts.panic_day = 3; r.s.daily.panic_entered = false
	request(r,"N-F06","sofia"); r._enter_panic(); var draws = r.s.daily.draws.size()
	check(r.command("card",{"id":"N-F06","option":0}) and r.s.daily.draws.size() == draws,"panic is rolled once at entry and never again on choice")
	r = fresh(); r.s.day = 4; request(r,"T10","ajie")
	check(r.command("card",{"id":"T10","option":2}) and r.person("ajie").scout == 65,"refusing scout rest preserves permanent ability")
	r.s.day = 5; check(r.effective_ability(r.person("ajie"),"scout") == 63,"temporary scout penalty applies next day")
	r.s.day = 6; check(r.effective_ability(r.person("ajie"),"scout") == 65,"temporary scout penalty expires")
	r = fresh(); r.person("zhang").active = false; r.person("captain").repair = 45
	check(r.require_operator("repair"),"one trainee support can be paid")
	r.s.day += 2
	check(not r.require_operator("repair"),"waiting does not recharge one-use trainee support")
	r = fresh(); r.s.phase = "stop"; r.s.day = 11; r.s.daily.tasks = 1; r.s.daily.opportunity_card = "R08"
	check(r.command("card",{"id":"R08","option":0}) and r.s.daily.tasks == 2,"R08 rescue consumes the last available task")
	check(r.command("card",{"id":"N-X09","option":0}) and r.living("luzhi") and r.s.daily.tasks == 2,"Lu Zhi recruitment shares the same R08 task at the limit")
	r = fresh(); r.car().modules.rear = "SP27"; r.normalize_cargo(); r.s.facts.cold_until = 3
	check(r.command("container",{"id":"cold_food","vehicle":0}),"cold food must be assigned to an actual container")
	r.car().modules.rear = "SP29"
	check(r.command("prepare",{"id":"none"}) and r.s.facts.cold_food == 0,"removing a cooler cancels its protection")
	check(r.command("container",{"id":"archive","role":"repair","vehicle":0}),"archive accepts a real book")
	check(r.command("drop_item",{"id":"repair"}) and r.s.facts.archive_books.is_empty(),"discarded book does not retain archive protection")
	r = fresh(); r.car().durability = 20
	check(r.command("prepare",{"id":"none"}) and r.command("finish_prepare"),"prepare a real immobile route")
	var stock = r.s.resources.duplicate()
	check(r.command("depart",{"route":"resource","style":"quiet","supply":"water"}) and r.s.daily.card == "V09","immobile car forces one breakdown before travel")
	check(r.command("card",{"id":"V09","option":0}) and r.s.phase == "route" and r.s.legs == 0 and r.s.resources.water == stock.water and r.s.resources.fuel == stock.fuel,"pre-departure repair grants neither road supplies nor distance")
	r = fresh(); r.s.phase = "event"; r.s.daily.card = "V05"; r.s.daily.travel_done = true
	r.s.daily.travel_start = {"legs":2,"edge":0,"distance":60}; r.s.daily.road_id = 3
	r.s.legs = 3; r.s.distance = 90; r.s.daily.route = "resource"; r.s.daily.supply = "water"
	var water = r.s.resources.water
	check(r.command("card",{"id":"V05","option":1}) and r.s.legs == 2 and r.s.edge_km == 15 and r.s.resources.water == water+12,"first half of road retains one stable road supply identity")
	r.s.daily.supply_claimed = false; r.s.legs = 3; r.s.edge_km = 0; r._arrive()
	check(r.s.resources.water == water+12,"remaining half cannot pay the same road supply twice")
	check(r.content.endings.E12.title == "南边的灯" and r.content.endings.E12.text.contains("灯是在傍晚亮起来的"),"illustration appendix never overwrites the actual ending story")
	for index in range(1,18):
		r.s.ending = "E%02d" % index; r.s.phase = "ending"
		if index == 17: r.s.foot_deadline = r.s.day
		var text_value = Prose.ending(r)
		check(not text_value.contains("判定：") and not text_value.contains("插画待") and not text_value.contains("[记账者]") and not text_value.contains("正文。"),"ending prose resolves real variants "+r.s.ending)
	r.s.ending = "E12"; r.s.sister = "alive"
	check(Prose.epilogue(r).contains("登记单") and not Prose.epilogue(r).contains("条件："),"South Lights uses the short living-sister epilogue")
	r.s.ending = "E01"; r.s.sister = "missing"; r.s.clues = []
	check(not Prose.epilogue(r).contains("最后一次收到信号的日子"),"early termination never invents the day-five signal")
	await save_journey("E12",1)
	await save_journey("E09",1)
	print("FINAL_REGRESSIONS checks=",checks," failures=",failures)
	quit(failures)

func save_journey(target: String, seed_value: int):
	var r = Rules.new(); r.new_game(seed_value)
	var restored = Rules.new()
	var driver = Pilot.new(); var saves = Saves.new("res://.godot/continuation_test")
	var steps = 0; var phases = {}; var days = {}
	while r.s.ending == "" and steps < 250:
		steps += 1; phases[r.s.phase] = true; days[int(r.s.day)] = true
		if not saves.save_payload(r.checkpoint()) or not restored.restore(saves.load_from_file()): check(false,"disk save restores "+target); return
		if not driver.pilot(r,target): check(false,"legal continuation strategy "+target+" "+r.error); return
		var command = driver.commands.back()
		if not restored.command(command.action,command.args) or r.checkpoint() != restored.checkpoint():
			check(false,"resumed command matches RNG, history, current state and dawn snapshot "+str(command)); return
		await process_frame
	check(r.s.ending == target,"whole saved journey reaches "+target)
	check(phases.has("night") and phases.has("morning") and days.has(10) and days.has(12),"disk reload crosses recruitment and fixed rescue/arrival dates "+target)
	print("SAVE_CONTINUATION ",target," commands=",steps," phases=",phases.keys()," days=",days.size())
