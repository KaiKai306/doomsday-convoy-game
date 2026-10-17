extends SceneTree
var checks := 0
var failures := 0
var menu: Node
var values: Array[float] = []
var output: String

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL ", label)

func wait_for_menu() -> void:
	var deadline := Time.get_ticks_msec() + 30000
	while not is_instance_valid(menu) and Time.get_ticks_msec() < deadline:
		await process_frame
	check(is_instance_valid(menu), "startup reaches the actual main menu")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	output = args[0] if not args.is_empty() else "res://.godot/startup-audit"
	DirAccess.make_dir_recursive_absolute(output)
	var boot = load("res://scenes/boot.tscn").instantiate()
	boot.startup_log_path = output.path_join("startup.log")
	boot.progress_changed.connect(func(value: float): values.append(value))
	boot.startup_finished.connect(func(node: Node): menu = node)
	root.add_child(boot)
	await process_frame
	check(boot.screen.visible, "loading screen is visible before menu loading")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(output.path_join("startup-loading.png")) == OK, "loading page screenshot")
	await wait_for_menu()
	check(not values.is_empty() and values[0] == 0.0, "progress starts at zero")
	check(not values.is_empty() and values[-1] == 1.0, "progress reaches completion")
	for index in range(1, values.size()):
		check(values[index] >= values[index - 1], "progress never moves backwards")
	if is_instance_valid(menu):
		check(menu.is_startup_ready(), "menu initialization completed")
		check(not ResourceLoader.has_cached("res://scenes/release_game.tscn"), "boot does not load the full gameplay scene")
		check(not ResourceLoader.has_cached("res://src/game/world_rules.gd"), "boot does not initialize gameplay rules")
		check(not menu.settings.is_inside_tree(), "hidden settings UI is deferred until opened")
		menu.save_system = load("res://src/game/save.gd").new(output.path_join("saves"))
		menu._start_game_transition()
		await process_frame
		check(menu.transitioning, "new game guards repeated taps while preparing")
		var start_deadline := Time.get_ticks_msec() + 30000
		while menu.transitioning and Time.get_ticks_msec() < start_deadline:
			await process_frame
		check(is_instance_valid(menu.day_demo), "menu action loads gameplay on demand")
		if not is_instance_valid(menu.day_demo):
			quit(1)
			return
		var deadline := Time.get_ticks_msec() + 20000
		while menu.day_demo.loading_screen.busy and Time.get_ticks_msec() < deadline:
			await process_frame
		check(menu.day_demo.engine.s.day == 1, "new game starts on day one")
		check(not menu.day_demo.loading_screen.busy, "opening location finishes loading")
		menu.queue_free()
		await process_frame
	menu = null
	current_scene = null
	var broken = load("res://scenes/boot.tscn").instantiate()
	broken.menu_scene_path = "res://scenes/nonexistent_startup_test.tscn"
	broken.startup_log_path = output.path_join("failure.log")
	broken.startup_finished.connect(func(node: Node): menu = node)
	root.add_child(broken)
	var deadline := Time.get_ticks_msec() + 5000
	while not broken.failed and Time.get_ticks_msec() < deadline:
		await process_frame
	check(broken.failed and broken.screen.visible, "missing resource keeps a visible error screen")
	check(broken.retry.visible, "failure offers retry")
	check(not broken.busy, "failure stops the progress poll")
	broken.menu_scene_path = "res://scenes/main.tscn"
	broken.retry.pressed.emit()
	await wait_for_menu()
	if is_instance_valid(menu):
		check(menu.is_startup_ready(), "retry recovers to a usable menu")
		menu.queue_free()
		await process_frame
	menu = null
	current_scene = null
	# Force the stall deadline to expire between media stages, then resume the
	# same loader requests. This also verifies retry never launches duplicate work.
	var stalled = load("res://scenes/boot.tscn").instantiate()
	stalled.startup_log_path = output.path_join("timeout.log")
	stalled.stall_timeout_msec = -1
	stalled.startup_finished.connect(func(node: Node): menu = node)
	root.add_child(stalled)
	var stall_deadline := Time.get_ticks_msec() + 5000
	while not stalled.failed and Time.get_ticks_msec() < stall_deadline:
		await process_frame
	check(stalled.failed and stalled.retry.visible and not stalled.busy, "stalled media offers a visible retry instead of waiting forever")
	stalled.stall_timeout_msec = 30000
	stalled.retry.pressed.emit()
	await wait_for_menu()
	if is_instance_valid(menu):
		check(menu.is_startup_ready(), "timeout retry resumes to a usable menu")
		menu.queue_free()
		await process_frame
	print("STARTUP_TEST checks=", checks, " failures=", failures)
	quit(failures)
