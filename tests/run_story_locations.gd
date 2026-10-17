extends SceneTree
## Replay real journeys, then render the production main UI and its walk view.
const Rules = preload("res://src/game/world_rules.gd")
const Catalog = preload("res://src/game/biome_catalog.gd")
const BaseCatalog = preload("res://src/game/location_catalog.gd")
const Saves = preload("res://src/game/save.gd")
const REQUIRED = ["forest_gas_station","forest_road","forest_camp","desert_road","desert_camp","pine_road","pine_camp","snow_road","camp_interior","forest_clinic","old_water_tower","rescue_station_exterior","rescue_station_interior","settlement_reception","neutral_market","tunnel_entrance","snow_camp"]
var checks = 0
var failures = 0
var samples = {}
var transitions = []
var output = "res://.docs/美术/地貌与地点补齐_20261016/story"
var ui

func _init(): call_deferred("run")
func check(ok: bool, label: String):
	checks += 1
	if not ok: failures += 1; print("FAIL ",label)

func settled():
	var deadline = Time.get_ticks_msec()+15000
	while ui.loading_screen.busy and Time.get_ticks_msec() < deadline: await process_frame
	check(not ui.loading_screen.busy,"scene transition finishes automatically")

func observe(r, witness: String, step: int):
	var before = r.checkpoint()
	var id = Catalog.scene_for(r.s)
	check(Catalog.scene_for(r.s,"goals","R03") == id,"goal/card previews cannot move the party")
	check(r.checkpoint() == before,"scene resolver preserves state and RNG")
	var prefer_rescue_journey = witness == "E12" and samples.get(id,{}).get("witness","") != "E12" and id != "neutral_market"
	var prefer_registered_market = id == "neutral_market" and r.s.position == "商会登记处" and samples.get(id,{}).get("checkpoint",{}).get("current",{}).get("position","") != "商会登记处"
	if not samples.has(id) or prefer_rescue_journey or prefer_registered_market: samples[id] = {"checkpoint":before,"view":"journey","witness":witness,"step":step}
	if r.s.phase == "camp" and Catalog.scene_for(r.s,"knowledge") == "camp_interior" and (not samples.has("camp_interior") or witness == "E12" and samples.camp_interior.witness != "E12"):
		samples.camp_interior = {"checkpoint":before,"view":"knowledge","witness":witness,"step":step}
	if witness in ["E12","E09"]:
		var row = {"witness":witness,"step":step,"day":r.s.day,"phase":r.s.phase,"scene":id,"position":r.s.position}
		if transitions.is_empty() or transitions[-1].witness != witness or transitions[-1].scene != id or transitions[-1].phase != r.s.phase or transitions[-1].day != r.s.day: transitions.append(row)
	if r.s.day == 1 and r.s.phase == "morning": check(id == "forest_gas_station","real opening is forest gas station")
	if r.s.phase == "rescue" and not BaseCatalog.rescue_site_reached(r.s): check(id != "rescue_station_exterior","remote rescue remains on road")
	if r.s.phase == "camp" and r.s.position == "主路":
		var built_here = r.s.intent == "E07" and r.s.daily.get("terminal_entered",false)
		check(id == Catalog.build_site(r.s) if built_here else id in ["forest_camp","desert_camp","pine_camp","snow_camp"],"camp or actually established settlement retains current site")
	if r.s.phase == "stop" and r.s.daily.travel_done and r.s.daily.route != "stay" and r.s.position == "主路":
		if r.s.day == 4: check(id == "forest_clinic","legal day four arrival reaches clinic")
		if r.s.day == 7: check(id == "old_water_tower","legal day seven arrival reaches tower")
	if witness == "E12" and r.s.day == 8 and r.s.phase == "route" and r.s.south_pledge: check(id == "rescue_station_exterior","paid scouting shows exterior only")
	if witness == "E12" and r.s.day == 10 and r.s.phase == "stop" and r.s.sister == "alive": check(id == "rescue_station_interior","real successful rescue reaches treatment room")

func perform(r, action: String, args: Dictionary = {}) -> bool:
	var ok = r.command(action,args)
	check(ok,"legal northern branch "+action+" "+r.error)
	if ok: observe(r,"north_branch",0)
	return ok

func clear_event(r):
	for safety in 8:
		if r.s.phase not in ["event","camp_event"]: return
		var accepted = false
		for option in 6:
			if r.command("card",{"id":r.s.daily.card,"option":option,"target":"captain"}): accepted = true; observe(r,"north_branch",0); break
		check(accepted,"northern event has legal resolution")
		if not accepted: return

func northern_branch():
	var r = Rules.new(); r.new_game(81)
	for day in range(1,4):
		if not perform(r,"prepare",{"id":"none"}): return
		if not perform(r,"finish_prepare"): return
		if day == 2 and not perform(r,"direction",{"id":"north"}): return
		if not perform(r,"depart",{"route":"resource","style":"quiet","supply":"medicine" if day == 3 else "water"}): return
		await clear_event(r)
		if not perform(r,"begin_camp"): return
		if day == 3: check(Catalog.scene_for(r.s) == "forest_camp","early north branch retains day-three forest"); return
		if not perform(r,"camp",{"id":"rest"}): return
		if not perform(r,"settle"): return
		await clear_event(r)
		if not perform(r,"next"): return

func shot(name: String):
	await process_frame; await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(output.path_join(name+".png")) == OK,"capture "+name)

func run():
	root.size = Vector2i(1280,720)
	DirAccess.make_dir_recursive_absolute(output)
	var fixtures = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/final_endings_paths.json"))
	for fixture in fixtures:
		var r = Rules.new(); r.new_game(int(fixture.seed)); observe(r,fixture.target,0)
		var step = 0
		for entry in fixture.commands:
			step += 1
			if not r.command(entry.action,entry.args): check(false,"story fixture "+fixture.target+" step "+str(step)); break
			observe(r,fixture.target,step)
		check(r.s.ending == fixture.target,"story journey retains ending "+fixture.target)
	await northern_branch()
	for id in REQUIRED: check(samples.has(id),"actual playable coverage "+id)
	var main = load("res://scenes/main.tscn").instantiate()
	main.save_system = Saves.new("res://.godot/story_location_audit/saves")
	root.add_child(main); await process_frame; main._start_game(); await process_frame
	ui = main.day_demo; await settled()
	var evidence = []
	for id in samples:
		if not samples.has(id): continue
		var sample: Dictionary = samples[id]
		check(ui.engine.restore(sample.checkpoint),"restore legitimate checkpoint "+id)
		ui.scene_context.clear(); ui.view = sample.view; ui.refresh(); await settled()
		check(ui.scene_backdrop.location_id == id,"production main UI scene "+id)
		if id == "forest_gas_station": check(ui.information.text.contains("加油站"),"opening location text matches art")
		await shot(id+"_main")
		var before = ui.engine.checkpoint()
		ui._open_camp_walk(); await process_frame
		var walk = ui.canvas.get_child(ui.canvas.get_child_count()-1)
		check(walk.location_id == id and walk.backdrop.location_id == id,"production walk uses same story site "+id)
		var has_scene_art = is_instance_valid(walk.backdrop.existing_scene)
		if not has_scene_art:
			has_scene_art = walk.backdrop.planes.size() == 3
			for plane in walk.backdrop.planes:
				has_scene_art = has_scene_art and plane.get_child(0).texture != null
		check(has_scene_art,"production walk has complete visible background "+id)
		var walk_art_source = walk.backdrop.config.get("presentation_source","")
		walk.set_process(false); await shot(id+"_walk")
		walk.closed.emit(); await process_frame; await settled()
		check(ui.engine.checkpoint() == before,"walk preserves real story checkpoint "+id)
		evidence.append({"id":id,"witness":sample.witness,"step":sample.step,"day":ui.engine.s.day,"phase":ui.engine.s.phase,"view":sample.view,"walk_art_source":walk_art_source,"main":id+"_main.png","walk":id+"_walk.png"})
	main.queue_free(); await process_frame
	var file = FileAccess.open(output.path_join("verification.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"graphical":DisplayServer.get_name() != "headless","samples":evidence,"transitions":transitions},"\t")); file.close()
	print("STORY_LOCATIONS checks=",checks," scenes=",samples.size()," failures=",failures)
	quit(failures)
