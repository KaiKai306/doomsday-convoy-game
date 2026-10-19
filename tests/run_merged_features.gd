extends SceneTree
## Exercise the incoming archive, music and animation systems against real resources.
const SAVES = preload("res://src/game/save.gd")
const RULES = preload("res://src/game/world_rules.gd")
const MUSIC = preload("res://src/audio/music_catalog.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("MERGED_FAIL ",detail)

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var output := args[0] if not args.is_empty() else "res://.godot/merged-checks"
	var fixture := args[1] if args.size() > 1 else "res://tests/fixtures/v062_autosave.json"
	DirAccess.make_dir_recursive_absolute(output)
	var store = SAVES.new(output.path_join("saves"))
	DirAccess.make_dir_recursive_absolute(store.save_directory)
	var old_file := FileAccess.open(store.slot_path("auto"),FileAccess.WRITE)
	old_file.store_string(FileAccess.get_file_as_string(fixture))
	old_file.close()
	var legacy: Dictionary = store.load_from_file()
	check(not legacy.is_empty() and int(legacy.current.day) == 1,"actual 0.6.2 autosave loads with no migration or data clearing")
	check(store.manual_slots().size() == 6,"six independent manual slots")
	for slot in store.manual_slots():
		check(store.save_payload(legacy,slot,{"note":slot}),"write "+slot)
		check(store.slot_info(slot).note == slot,"metadata belongs to "+slot)
	check(not store.save_payload(legacy,"../invalid"),"invalid slot cannot write outside save directory")
	check(store.save_payload(legacy,"slot_1",{"note":"newer"}),"overwrite creates a valid backup")
	var damaged := FileAccess.open(store.slot_path("slot_1"),FileAccess.WRITE)
	damaged.store_string("damaged"); damaged.close()
	check(store.slot_info("slot_1").recovered,"damaged primary restores its healthy backup")
	check(store.delete_slot("slot_1") and not store.slot_info("slot_1").exists,"deleting a slot also removes backup resurrection")
	check(store.slot_info("slot_2").usable,"deleting one slot preserves another")
	for day in [4,7,9]:
		var rules = RULES.new(); rules.new_game(81)
		rules.s.day = day; rules.s.phase = "stop"
		rules.s.daily.tasks = 1; rules.s.daily.opportunity_used = false
		check(not rules.use_task(),"fixed recruitment reserves the remaining task on day "+str(day))
		rules.s.daily.tasks = 2
		var resources: Dictionary = rules.s.resources.duplicate(true)
		check(rules.command("recruit",{"id":"none"}),"old two-task stop can explicitly decline recruitment on day "+str(day))
		check(rules.s.resources == resources and rules.s.daily.tasks == 2,"recovery grants no resources or extra task")
		check(rules.command("begin_camp",{}),"recruitment recovery can continue to camp")
	for id in MUSIC.all_tracks():
		var stream = load(str(MUSIC.track(id).path)) as AudioStreamOggVorbis
		check(stream != null and stream.get_length() > 5.0,"packed music track "+str(id))
	check(MUSIC.cue_for("main_menu",{}) == "main_menu","menu has its own cue")
	check(MUSIC.cue_for("forest_gas_station",{"phase":"morning"}) == "forest_gas_station","opening location selects its music")
	var vehicles = load("res://src/game/vehicle_side_2d.gd")
	for id in ["V01","V02","V03","V04","V05","V06","V07","V08"]:
		for facing in ["left","right"]:
			var art: Dictionary = vehicles.find_art(id,facing)
			var fingerprint = {"asset_path":art.get("path",""),"asset_ground_y":art.get("ground_y"),"asset_wheel_x":art.get("wheel_x",[]),"asset_sha256":art.get("file_sha256","")}
			check(vehicles.asset_matches_confirmation(fingerprint,art),"vehicle fingerprint works without exported raw PNG: "+id+" "+facing)
	var activities = load("res://data/member_activities.json").data
	var clips: Dictionary = {}
	collect_frames(activities,clips)
	for path in clips:
		var frames = load(path) as SpriteFrames
		check(frames != null,"activity animation included: "+path)
		if frames == null: continue
		for animation in frames.get_animation_names():
			var count = frames.get_frame_count(animation)
			check(count > 1,"activity keeps its frame sequence")
			for index in count:
				var texture = frames.get_frame_texture(animation,index)
				check(texture != null and texture.get_width() > 0 and texture.get_height() > 0,"activity frame available")
		frames = null
		await process_frame
	var main = load("res://scenes/main.tscn").instantiate()
	main.save_system = store; root.add_child(main)
	main._start_game_transition()
	check(main.archive_screen.visible and main.archive_screen.mode == "new","new game asks for a real archive slot")
	main.archive_screen.selected_slot = "slot_6"
	main.archive_screen._primary()
	check(is_instance_valid(main.archive_screen.confirmation) and not is_instance_valid(main.day_demo),"occupied slot requires confirmation before replacing progress")
	main.archive_screen.confirm_action()
	var deadline := Time.get_ticks_msec()+30000
	while main.transitioning and Time.get_ticks_msec() < deadline: await process_frame
	check(is_instance_valid(main.day_demo),"confirmed archive action enters gameplay")
	check(main.day_demo.archive_metadata().thumbnail == "res://assets/locations/atlas_widescreen_20261016/forest_gas_station/full.jpg","opening save thumbnail uses the shipped map rather than an excluded source preview")
	check(store.slot_info("slot_6").usable and store.slot_info("auto").usable,"new journey saves selected manual slot and autosave")
	if is_instance_valid(main.day_demo):
		while main.day_demo.loading_screen.busy and Time.get_ticks_msec() < deadline: await process_frame
		check(not main.day_demo.loading_screen.busy,"new archive journey finishes its opening scene")
	main.queue_free(); await process_frame
	print("MERGED_FEATURES checks=",checks," failures=",failures," animation_clips=",clips.size())
	quit(failures)

func collect_frames(value: Variant, paths: Dictionary) -> void:
	if value is Dictionary:
		for key in value:
			if key == "frames" and value[key] is String: paths[value[key]] = true
			else: collect_frames(value[key],paths)
	elif value is Array:
		for item in value: collect_frames(item,paths)
