extends SceneTree
## Isolated art and geometry audit using the production walker. Story-arrival
## evidence remains in run_atlas_stage; this gallery does not claim arrivals.
const WALK = preload("res://src/game/camp_walk.gd")
const RULES = preload("res://src/game/world_rules.gd")
const OUTPUT = "res://.docs/美术/示例图横版复刻_20261016/runtime_widescreen"
const SAMPLES = ["forest_camp","gas_station_interior","forest_gas_station","desert_road","pine_road","snow_road","neutral_market","snow_checkpoint"]
var checks = 0
var failures = 0
var gallery: Array = []

func _init(): call_deferred("run")

func check(ok: bool, label: String):
	checks += 1
	if not ok: failures += 1; print("FAIL ",label)

func shot(name: String, full_size: bool = false):
	await process_frame; await process_frame
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var picture = root.get_texture().get_image()
	if not full_size: picture.resize(1008,432,Image.INTERPOLATE_LANCZOS)
	check(picture.save_png(OUTPUT.path_join(name+".png")) == OK,"render "+name)

func run():
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	root.content_scale_size = Vector2i.ZERO; root.size = Vector2i(1680,720)
	var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://assets/locations/atlas_widescreen_20261016/manifest.json"))
	var brief = JSON.parse_string(FileAccess.get_file_as_string("res://.docs/美术/示例图横版复刻_20261016/widescreen/brief.json"))
	check(manifest.locations.size() == brief.jobs.size()+3,"all edited and three native maps integrated")
	var rules = RULES.new(); rules.new_game(81)
	var art_members = rules.people().duplicate(true)
	# A larger real roster from the fixture exercises overflow placement. This
	# remains an isolated art check, independent of the fixture's ending state.
	var fixtures = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/final_endings_paths.json"))
	for fixture in fixtures:
		if fixture.final.members.size() > art_members.size(): art_members = fixture.final.members.duplicate(true)
	for id in manifest.locations:
		var cfg = manifest.locations[id]
		var walk = WALK.new(); walk.atlas_mode = true; walk.location_id = id; walk.members = art_members.duplicate(true)
		root.add_child(walk); await process_frame; walk.set_process(false)
		var backdrop = walk.backdrop
		check(backdrop.config.get("presentation_source","") == "atlas_widescreen_20261016","production loads wide map "+id)
		check(backdrop.planes.size() == 3,"three planes "+id)
		check(backdrop.vehicle_root.get_child_count() == 0,"vehicle composition preserved "+id)
		check(backdrop.source_size == Vector2(2688,1152),"full 21:9 map "+id)
		var center = cfg.preserved_center
		for index in 3:
			check(backdrop.planes[index].get_child(0).texture != null,"plane readable "+id+str(index))
		# Reversible coordinate conversions use the padding-aware production API.
		var foot = Vector2(float(center[0])+1000,806)
		check(backdrop.view_to_source(backdrop.source_to_view(foot)).distance_to(foot) < 0.01,"coordinate round trip "+id)
		check(absf(backdrop.source_to_view(foot).y-503.75) < 0.1,"horizontal actor ground "+id)
		for npc in walk.npcs:
			check(npc.source_x >= walk.walk_path[0][0] and npc.source_x <= walk.walk_path[-1][0],"NPC inside accepted path "+id+str(npc.id))
		var first_positions: Array = []
		for camera in [-24,0,24]:
			backdrop.set_camera(camera); walk._refresh_actors()
			var expected = 0.0 if cfg.get("interior",false) else float(camera)
			check(is_equal_approx(backdrop.camera_x,expected),"camera range "+id+str(camera))
			for i in 3:
				var plane = backdrop.planes[i]; var sprite = plane.get_child(0)
				var bounds = plane.get_transform()*Rect2(Vector2.ZERO,sprite.texture.get_size())
				check(bounds.grow(0.01).encloses(Rect2(0,0,1680,720)),"plane covers viewport "+id+str(i)+str(camera))
				if camera == -24: first_positions.append(plane.position.x)
				elif camera == 24:
					var displacement = (48*[0.12,0.5,1.0][i]*0.625) if not cfg.get("interior",false) else 0.0
					check(absf(first_positions[i]-plane.position.x-displacement) < 0.01,"independent depth speed "+id+str(i))
			if camera == 0: await shot(id)
			if id in SAMPLES: await shot(id+"_camera_"+str(camera),true)
		if id in ["forest_camp","desert_road","pine_road","snow_road"]:
			for camera in [-18,-12,-6,6,12,18]:
				backdrop.set_camera(camera); walk._refresh_actors()
				await shot(id+"_camera_"+str(camera),true)
		gallery.append({"id":id,"title":cfg.get("title",id),"interior":cfg.get("interior",false),"file":id+".png","evidence":"isolated production atlas walker; not a story arrival"})
		walk.queue_free(); await process_frame
	var file = FileAccess.open(OUTPUT.path_join("verification.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"graphical":DisplayServer.get_name() != "headless","gallery":gallery},"\t")); file.close()
	print("ATLAS_WIDESCREEN checks=",checks," maps=",gallery.size()," failures=",failures)
	quit(failures)
