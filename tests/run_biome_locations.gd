extends SceneTree
## Boundary snapshots are unit tests; genuine journey evidence is captured by
## run_story_locations. The all-scenes gallery below is an isolated art check.
const Rules = preload("res://src/game/world_rules.gd")
const Biomes = preload("res://src/game/biome_catalog.gd")
const Catalog = preload("res://src/game/location_catalog.gd")
const Saves = preload("res://src/game/save.gd")
const Walk = preload("res://src/game/camp_walk.gd")
var checks = 0
var failures = 0
var output = "res://.docs/美术/地貌与地点补齐_20261016/validation"
var ui

func _init(): call_deferred("run")
func check(ok: bool, label: String):
	checks += 1
	if not ok: failures += 1; print("FAIL ",label)

func settled():
	var deadline = Time.get_ticks_msec()+15000
	while ui.loading_screen.busy and Time.get_ticks_msec() < deadline: await process_frame
	check(not ui.loading_screen.busy,"scene transition finishes automatically")

func snapshot(day: int, moving: bool, last_day: int) -> Dictionary:
	var r = Rules.new(); r.new_game(81)
	var s: Dictionary = r.s.duplicate(true); s.day = day; s.phase = "camp"
	s.daily.travel_done = moving; s.daily.route = "resource" if moving else "stay"; s.daily.distance = 30 if moving else 0
	s.history = [{"day":last_day,"log":["行进 resource/quiet"]}]
	return s

func shot(name: String):
	await process_frame; await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(output.path_join(name+".png")) == OK,"capture "+name)

func run():
	root.size = Vector2i(1280,720); DirAccess.make_dir_recursive_absolute(output)
	for row in [[6,"forest"],[7,"desert"],[10,"desert"],[11,"pine"],[14,"pine"],[15,"snow"],[20,"snow"]]:
		check(Biomes.region_for_day(row[0]) == row[1],"date boundary "+str(row[0]))
	for day in [7,11,15]:
		var s = snapshot(day,false,day-1)
		check(Biomes.region(s) == Biomes.region_for_day(day-1),"stay keeps previous terrain "+str(day))
		s.phase = "morning"
		check(Biomes.scene_for(s) == Biomes.region_for_day(day-1)+"_camp","morning keeps previous camp "+str(day))
		s.phase = "route"
		check(Biomes.scene_for(s) == Biomes.region_for_day(day)+"_road","route is target preview "+str(day))
		s = snapshot(day,true,day-1)
		check(Biomes.region(s) == Biomes.region_for_day(day),"real movement enters region "+str(day))
		check(Biomes.scene_for(s) == ("snow_camp" if day == 15 else Biomes.region_for_day(day)+"_camp"),"new region camp "+str(day))
	for day in [3,8,12,17]:
		var s = snapshot(day,true,day)
		for source in Biomes.SOURCES:
			check(not Catalog.config(Biomes.source_site(source,s)).is_empty(),"source terrain art "+source+" day "+str(day))
	for fixed in Biomes.FIXED:
		check(not Catalog.config(Biomes.fixed_site(fixed)).is_empty(),"fixed landmark art "+fixed)
	ui = load("res://scenes/release_game.tscn").instantiate()
	ui.save_system = Saves.new("res://.godot/biome-audit/saves"); root.add_child(ui); await process_frame; ui.setup(); await settled()
	var before = ui.engine.checkpoint()
	check(ui.scene_backdrop.location_id == "forest_gas_station","production opening exterior")
	ui._toggle_opening_room(); await settled()
	check(ui.scene_backdrop.location_id == "gas_station_interior","opening room accessible")
	check(ui.engine.checkpoint() == before,"room entry preserves resources and RNG")
	var disk = ui.save_system.load_from_file()
	check(disk.presentation.opening_inside,"interior choice saved independently")
	check(ui.setup(null,disk),"disk continue loads room"); await settled()
	check(ui.scene_backdrop.location_id == "gas_station_interior","disk continue restores room")
	ui._toggle_opening_room(); await settled()
	check(ui.scene_backdrop.location_id == "forest_gas_station" and ui.engine.checkpoint() == before,"room exit preserves rules")
	ui._toggle_opening_room(); await settled(); ui._run("prepare",{"id":"none"}); ui._run("finish_prepare",{})
	ui._run("depart",{"route":"resource","style":"quiet","supply":"water"}); await settled()
	check(not ui.scene_context.get("opening_inside",false),"departure clears room view")
	# Event boundary snapshots are unit checks, separate from actual route evidence.
	for day in [3,8,12,17]:
		var boundary = snapshot(day,true,day); boundary.phase = "event"; boundary.daily.card = "V05"; boundary.daily.supply = "water"
		boundary.resources.fuel = 10; boundary.facts.fuel_depot = true
		ui.engine.new_game(81); ui.engine.s = boundary; ui.scene_context.clear(); ui.view = "journey"; ui.refresh(); await settled()
		var event_before = ui.engine.checkpoint()
		check(ui.scene_backdrop.location_id == Biomes.road(boundary),"remote oil depot remains road before decision")
		ui.active_card = "V05"; ui.view = "card"; ui.refresh(); await settled()
		check(ui.engine.checkpoint() == event_before and ui.scene_context.is_empty(),"oil depot preview cannot travel or change RNG")
		var expected = Rules.new(); expected.restore(event_before)
		check(expected.command("card",{"id":"V05","option":0}),"oil-depot unit action legal")
		ui._run("card",{"id":"V05","option":0}); await settled()
		check(ui.engine.checkpoint() == expected.checkpoint(),"oil-depot presentation preserves event cost/result")
		check(ui.scene_backdrop.location_id == Biomes.site_in_region("fuel_depot",boundary),"completed depot decision reaches regional depot")
		var depot_save = ui.save_system.load_from_file()
		check(ui.setup(null,depot_save),"depot disk restore"); await settled()
		check(ui.scene_backdrop.location_id == Biomes.site_in_region("fuel_depot",boundary),"depot disk continue retains region")
	var fixtures = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/final_endings_paths.json"))
	var reached = {}; var preview_checked = false; var replay_commands = 0
	for fixture in fixtures:
		var r = Rules.new(); r.new_game(int(fixture.seed))
		for entry in fixture.commands:
			var prior = r.checkpoint()
			check(r.command(entry.action,entry.args),"genuine fixture "+fixture.target); replay_commands += 1
			if r.s.phase == "stop":
				for loc in r.content.locations:
					if loc.chapter != r.s.legs or reached.has(loc.id): continue
					# An alternative legal branch from a genuine fixture checkpoint.
					# Never add resources, move the party, or mutate the fixture replay.
					var branch = Rules.new(); branch.restore(r.checkpoint())
					var args = {"location":loc.id,"id":loc.choices[0]}
					if not branch.command("acquire",args): continue
					prior = r.checkpoint(); ui.engine.restore(prior); ui.scene_context.clear(); ui.view = "equipment"; ui.refresh(); await settled()
					if not preview_checked:
						for button in ui.choices.get_children():
							if button.text.contains("（支路预览）"):
								button.pressed.emit(); await settled(); check(ui.view == "site_preview","preview opens explicitly")
								check(ui.engine.checkpoint() == prior,"landmark preview preserves rules and RNG"); preview_checked = true; break
					ui.view = "equipment"; ui._run("acquire",args); await settled()
					check(ui.engine.checkpoint() == branch.checkpoint(),"acquisition presentation preserves exact legal result")
					var site = Biomes.fixed_site(loc.id)
					check(ui.scene_backdrop.location_id == site,"successful actual acquisition displays site "+site)
					await shot("acquired_"+loc.id)
					reached[loc.id] = {"fixture_prefix":fixture.target,"day":r.s.day,"scene":site,"evidence":"legal acquisition branch; not the unmodified ending fixture"}
					var site_disk = ui.save_system.load_from_file()
					check(ui.setup(null,site_disk),"disk loads acquired site"); await settled()
					check(ui.scene_backdrop.location_id == site,"disk continue retains acquired site")
					var dawn = ui.engine.day_start.duplicate(true)
					ui._run("retry",{}); await settled()
					check(ui.scene_context.is_empty() and ui.engine.s.phase == "morning" and ui.engine.s.day == dawn.day and ui.engine.s.resources == dawn.resources and ui.engine.s.members == dawn.members and ui.engine.s.claimed == dawn.claimed and ui.engine.s.legs == dawn.legs,"retry clears site and restores dawn quantities before the fresh daily draw")
		check(r.checkpoint().current == Rules.canonical(fixture.final),"exact ending state "+fixture.target)
	check(preview_checked and not reached.is_empty(),"real acquisition and preview witnesses")
	ui.queue_free(); await process_frame
	var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://assets/locations/biomes_20261016/manifest.json"))
	var gallery = []
	var members = Rules.new(); members.new_game(81)
	for id in manifest.locations:
		var walk = Walk.new(); walk.location_id = id; walk.members = members.people().duplicate(true)
		root.add_child(walk); await process_frame; walk.set_process(false)
		check(walk.backdrop.config.presentation_source == "biomes_20261016","production walker loads new art "+id)
		check(walk.backdrop.planes.size() == 3,"three plates "+id)
		check(walk.backdrop.vehicle_root.get_child_count() == 0,"no vehicle mounted "+id)
		for plane in walk.backdrop.planes: check(plane.get_child(0).texture != null,"plate texture "+id)
		var foot = walk.backdrop.source_to_view(Vector2(1000,806)); check(foot.y > 490 and foot.y < 530,"shared horizontal ground "+id)
		for camera in [-24,24]:
			walk.backdrop.set_camera(camera); walk._refresh_actors()
			var far = walk.backdrop.planes[0]; var sprite = far.get_child(0)
			var bounds = far.get_transform()*Rect2(Vector2.ZERO,sprite.texture.get_size())
			check(bounds.encloses(Rect2(0,0,1280,720)),"camera covers viewport "+id+" "+str(camera))
			if id in ["gas_station_interior","forest_camp","desert_camp","pine_road","snow_road","communications_station","research_relay","snow_checkpoint"]:
				await shot(id+("_left" if camera < 0 else "_right"))
		walk.backdrop.set_camera(0); walk._refresh_actors(); await shot(id)
		gallery.append({"id":id,"file":id+".png","evidence":"isolated production walk / not a story arrival"})
		walk.queue_free(); await process_frame
	var file = FileAccess.open(output.path_join("verification.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"graphical":DisplayServer.get_name() != "headless","gallery":gallery,"genuine_acquisitions":reached,"replay_commands":replay_commands},"\t")); file.close()
	print("BIOME_LOCATIONS checks=",checks," scenes=",gallery.size()," failures=",failures); quit(failures)
