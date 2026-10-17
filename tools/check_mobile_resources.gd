extends SceneTree
## Read-only runtime/export audit. Outputs go to an explicit temporary directory.
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("MOBILE_RESOURCE_FAIL ", message)

func json_file(path: String) -> Variant:
	check(FileAccess.file_exists(path), "JSON included: " + path)
	if not FileAccess.file_exists(path): return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(data is Dictionary, "valid JSON: " + path)
	return data if data is Dictionary else {}

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("Usage: -- <mobile_export_resources.json> <temporary_output_directory>")
		quit(2)
		return
	var manifest: Dictionary = json_file(args[0])
	check(ResourceLoader.exists("res://scenes/boot.tscn"), "startup scene included")
	check(ResourceLoader.exists("res://scenes/release_game.tscn"), "main game scene included")
	for path in manifest.get("export_resources", []):
		check(ResourceLoader.exists(str(path)), "selected resource: " + str(path))
	var wide: Dictionary = json_file("res://assets/locations/atlas_widescreen_20261016/manifest.json")
	for id in wide.get("locations", {}):
		var cfg: Dictionary = wide.locations[id]
		for plane in ["far.png", "mid.png", "near.png"]:
			check(ResourceLoader.exists(str(cfg.art_root) + plane), str(id) + "/" + plane)
		check(ResourceLoader.exists("res://assets/locations/atlas_widescreen_20261016/" + str(id) + "/full.jpg"), "management picture: " + str(id))
		var scene := "res://scenes/camp_three_parallax.tscn" if id == "camp" else "res://scenes/" + str(id) + "_parallax.tscn"
		check(ResourceLoader.exists(scene), "dynamic scene: " + str(id))
	json_file("res://assets/locations/biomes_20261016/manifest.json")
	json_file("res://assets/locations/side_walk_20261016/manifest.json")
	json_file("res://assets/vehicles/realistic_20261015/manifest.json")
	json_file("res://data/final/location_walks.json")
	json_file("res://data/final/vehicle_scene_lighting.json")
	json_file("res://data/vehicle_placements/vehicle_management/V05.json")
	var content: Dictionary = json_file("res://data/final/content.json")
	check(not content.is_empty(), "authoritative content included")
	# Run the actual menu and opening scene. Use an isolated save destination.
	var saves = load("res://src/game/save.gd").new(args[1].path_join("save"))
	var main = load("res://scenes/main.tscn").instantiate()
	main.save_system = saves
	root.add_child(main)
	for frame in range(3): await process_frame
	check(main.cover.texture != null and main.cover_video.stream != null, "menu still/video")
	check(main.menu_music.stream != null, "menu audio")
	await capture(args[1].path_join("packed-main-menu.png"))
	main._start_game()
	for frame in range(5): await process_frame
	check(is_instance_valid(main.day_demo), "new game opens")
	if is_instance_valid(main.day_demo):
		var ui = main.day_demo
		await settle(ui)
		check(ui.engine.s.day == 1, "game begins day one")
		ui.view = "equipment"
		ui.refresh()
		await settle(ui)
		check(is_instance_valid(ui.management_screen), "management interface assembled")
		if is_instance_valid(ui.management_screen):
			check(is_instance_valid(ui.management_screen.vehicle_preview), "garage vehicle preview retained")
			if is_instance_valid(ui.management_screen.vehicle_preview):
				check(ui.management_screen.vehicle_preview.stage.ready_ok, "exported vehicle model loads successfully")
		await capture(args[1].path_join("packed-vehicle-page.png"))
	main.queue_free()
	await process_frame
	print("MOBILE_RESOURCES checks=", checks, " failures=", failures)
	quit(failures)

func settle(ui) -> void:
	var deadline := Time.get_ticks_msec() + 20000
	while ui.loading_screen.busy and Time.get_ticks_msec() < deadline:
		await create_timer(0.025).timeout
	for frame in range(3): await process_frame
	check(not ui.loading_screen.busy, "scene transition completes")

func capture(path: String) -> void:
	if DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
