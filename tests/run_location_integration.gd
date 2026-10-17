extends SceneTree
const Catalog = preload("res://src/game/location_catalog.gd")
const Rules = preload("res://src/game/world_rules.gd")
const Walk = preload("res://src/game/camp_walk.gd")
var checks = 0
var failures = 0
var capture_dir = "res://.docs/美术/主流程补图/gameplay"
const LOCATIONS = ["camp","camp_interior","gas_station","tunnel_entrance","snow_camp","journey_road","abandoned_clinic","old_water_tower","rescue_station_exterior","rescue_station_interior","settlement_reception","neutral_market"]
func _init(): call_deferred("run")
func check(ok: bool, label: String):
	checks += 1
	if not ok: failures += 1; print("FAIL ",label)
func shot(name: String):
	await process_frame; await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(capture_dir.path_join(name+".png"))
func run():
	root.size = Vector2i(1280,720)
	if not OS.get_environment("LOCATION_CAPTURE_DIR").is_empty():
		capture_dir = OS.get_environment("LOCATION_CAPTURE_DIR")
	DirAccess.make_dir_recursive_absolute(capture_dir)
	var engine = Rules.new(); engine.new_game(81)
	var before = engine.checkpoint()
	for page in ["journey","knowledge","inventory","team","goals","card"]:
		check(Catalog.resolve(engine.s,page,"R01") == "gas_station","new game stays at gas station on "+page)
	check(not preload("res://src/game/presentation.gd").morning(engine).contains("火灰") and preload("res://src/game/presentation.gd").morning(engine).contains("加油站"),"opening prose matches gas station")
	var s = engine.s.duplicate(true); s.phase = "stop"; s.day = 4
	s.daily.travel_done = true; s.daily.route = "resource"
	check(Catalog.resolve(s) == "abandoned_clinic","day 4 arrived clinic")
	s.day = 7; check(Catalog.resolve(s) == "old_water_tower","day 7 arrived water tower")
	s.day = 8; s.phase = "route"
	check(Catalog.resolve(s) == "journey_road","day 8 route selection is not rescue arrival")
	s.clues.append("entrance"); s.facts.direction_day = 8
	s.south_pledge = true
	check(Catalog.resolve(s) == "rescue_station_exterior","paid scouting presents rescue exterior")
	s.day = 10; s.phase = "rescue"
	s.legs = 6; s.clues = ["frequency","coordinates","entrance"]
	check(Catalog.resolve(s) == "rescue_station_exterior","actual rescue uses station not sealed tunnel")
	s.phase = "rescue_seats"; check(Catalog.resolve(s) == "rescue_station_interior","successful full-team rescue reaches interior")
	s.phase = "stop"; s.daily.travel_done = true; s.sister = "alive"
	check(Catalog.resolve(s) == "rescue_station_interior","joined sister stop remains inside rescue room")
	s.sister = "missing"; check(Catalog.resolve(s) != "rescue_station_interior","failed rescue does not claim room entry")
	s.day = 12; s.phase = "route"; s.goal = "south"
	check(Catalog.resolve(s,"goals") != "settlement_reception","goal tab does not teleport to settlement")
	s.daily.map_choice = "sealed_tunnel"
	check(Catalog.resolve(s) == "tunnel_entrance","selected sealed branch uses tunnel preview")
	s.phase = "stop"; s.position = "避难点"; check(Catalog.resolve(s) == "settlement_reception","actual refuge arrival changes scene")
	s.position = "南边正式定居区"; check(Catalog.resolve(s) == "settlement_reception","actual settlement arrival changes scene")
	s.position = "商会登记处"; check(Catalog.resolve(s) == "neutral_market","actual guild arrival changes scene")
	s = engine.s.duplicate(true); s.phase = "stop"; s.daily.opportunity_card = "R03"
	check(Catalog.resolve(s) == "gas_station","actual gas station encounter changes scene")
	s.daily.opportunity_card = "R01"; check(Catalog.resolve(s) == "neutral_market","actual trader encounter changes scene")
	s.phase = "camp"; check(Catalog.resolve(s) == "camp","stale trader opportunity cannot replace campsite")
	s.phase = "camp_event"; s.daily.card = "R03"; check(Catalog.resolve(s) == "camp","stale card cannot replace night event campsite")
	s.phase = "stop"; s.daily.opportunity_card = "R04"; check(Catalog.resolve(s) == "abandoned_clinic","medical opportunity reaches clinic")
	s.phase = "event"; s.daily.card = "N-C04"; check(Catalog.resolve(s) == "tunnel_entrance","actual sealed tunnel event retains entrance")
	s.phase = "ending"; check(Catalog.resolve(s) == "tunnel_entrance","immediate tunnel failure retains actual site")
	s.daily.card = ""; s.daily.opportunity_card = ""; s.day = 12; s.daily.travel_done = true; s.daily.camp_used = false
	check(Catalog.resolve(s) == "journey_road","immediate road failure does not invent a campsite")
	s.phase = "route"; s.day = 1; s.daily.travel_done = false; check(Catalog.resolve(s) == "gas_station","planning before first departure stays at gas station")
	s.phase = "rescue"; s.day = 10; s.legs = 2; s.clues = ["frequency","coordinates","entrance"]
	check(Catalog.resolve(s) == "journey_road","remote rescue decision does not claim arrival")
	s.legs = 6; s.clues = []; check(Catalog.resolve(s) == "journey_road","unlocated rescue decision does not claim arrival")
	s.clues = ["frequency","coordinates","entrance"]; s.vehicles = []
	check(Catalog.resolve(s) == "journey_road","stranded walkers cannot claim rescue arrival")
	s = engine.s.duplicate(true); s.phase = "camp"; s.day = 10; s.sister = "alive"; s.daily.travel_done = true
	check(Catalog.resolve(s) == "camp","post-rescue camp leaves treatment room")
	s.day = 9; s.phase = "stop"; check(Catalog.resolve(s) == "journey_road","day nine supply stop uses roadside")
	s.day = 4; s.daily.route = "stay"; check(Catalog.resolve(s) == "journey_road","staying put does not imply distant clinic arrival")
	s.position = "已抵达目标"; s.intent = "E13"; s.daily.terminal_entered = true
	check(Catalog.resolve(s) == "journey_road","patrol traversal is not settlement arrival")
	s.intent = "E08"; check(Catalog.resolve(s) == "settlement_reception","completed common settlement action reaches reception")
	s = engine.s.duplicate(true)
	s.daily.opportunity_card = ""; s.phase = "camp"; s.day = 5; s.facts.direction = "north"; s.facts.direction_day = 5
	check(Catalog.resolve(s) == "camp","choosing north has not yet entered snow terrain")
	s.day = 6; check(Catalog.resolve(s) == "camp","north direction without travel does not imply arrival")
	s.daily.travel_done = true; s.daily.route = "resource"
	check(Catalog.resolve(s) == "snow_camp","following northern leg enters snow camp")
	s.day = 7; s.daily.route = "stay"; s.history = [{"day":6,"log":["行进 resource/quiet：真实完成主边6"]}]
	check(Catalog.resolve(s) == "snow_camp","staying at a reached northern campsite preserves terrain")
	s.phase = "morning"; s.daily.travel_done = false
	check(Catalog.resolve(s) == "snow_camp","saved next morning preserves northern campsite")
	s.day = 8; check(Catalog.resolve(s) == "camp","north terrain expires after two days")
	check(Catalog.resolve(s,"knowledge") == "camp_interior","camp planning uses static tent interior")
	check(engine.checkpoint() == before,"scene selection preserves complete rules state and RNG")
	var vehicles: Array = engine.s.vehicles.duplicate(true); vehicles.append(engine.vehicle("第二辆车",70))
	for id in LOCATIONS:
		var config = Catalog.config(id)
		check(not config.is_empty() and ResourceLoader.exists(Catalog.scene_path(id)),id+" has production scene and ground")
		if config.is_empty(): continue
		var path: Array = config.walk_path
		var safe = true
		for i in 101:
			var p = Catalog.foot_at(path,lerpf(float(path[0][0]),float(path[-1][0]),i/100.0))
			for r in config.get("blockers",[]):
				if Rect2(r[0],r[1],r[2],r[3]).grow(12).has_point(p): safe = false
			for r in config.get("parking_areas_canvas_pixels",[]):
				if Rect2(r[0],r[1],r[2],r[3]).grow(12).has_point(p): safe = false
		check(safe,id+" continuous lane avoids vehicles and solid props")
		var walk = Walk.new(); walk.location_id = id; walk.members = engine.people().duplicate(true); walk.vehicles = vehicles
		root.add_child(walk); await process_frame; walk.set_process(false)
		check(walk.npcs.size() == 4,id+" uses actual current teammates")
		path = walk.walk_path
		check(walk.backdrop.vehicle_root.get_child_count() == 0,id+" has no displayed vehicles while convoy data remains")
		walk.direction = -1; walk._process(30); await process_frame
		var source = walk.backdrop.view_to_source(Vector2(walk.player_x,0)).x
		check(absf(source-float(path[0][0])) < 2,id+" held left stops at ground boundary")
		walk.direction = 1; walk._process(30); await process_frame
		source = walk.backdrop.view_to_source(Vector2(walk.player_x,0)).x
		check(absf(source-float(path[-1][0])) < 2,id+" held right stops at ground boundary")
		walk.direction = 0; walk.destination = walk.player_x
		var destination = walk.destination
		var click = InputEventMouseButton.new(); click.button_index = MOUSE_BUTTON_LEFT; click.pressed = true; click.position = Vector2(640,200)
		walk._gui_input(click)
		check(walk.destination == destination,id+" wall or sky clicks cannot leave lane")
		walk.backdrop.display(id,[])
		check(walk.backdrop.vehicle_root.get_child_count() == 0,id+" on foot removes cars")
		walk.backdrop.display(id,vehicles)
		walk.player_x = walk.npcs[0].x; walk.destination = walk.player_x
		check(walk.nearest().get("id","") == walk.npcs[0].id,id+" proximity resolves current teammate ID")
		await shot(id)
		walk.queue_free(); await process_frame
	check(engine.checkpoint() == before,"walking rendering and vehicle mounting preserve state and RNG")
	print("LOCATION_INTEGRATION checks=",checks," failures=",failures)
	quit(failures)

