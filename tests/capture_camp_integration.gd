extends SceneTree

func _init() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var args := OS.get_cmdline_user_args()
	var output := args[0] if not args.is_empty() else ProjectSettings.globalize_path("res://.godot/parallax-qa/integration")
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 720)
	var demo: DayDemo = load("res://scenes/day_demo.tscn").instantiate()
	root.add_child(demo)
	await process_frame
	var state := GameState.new()
	demo.add_child(state)
	demo.setup(state)
	demo.day_loop._arrive_at_stop()
	state.phase = GameState.Phase.STOP_DIALOGUE
	state.camp_position = 490
	demo.refresh()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("停歇点_实际流程_1280x720.png"))
	root.size = Vector2i(960, 600)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("停歇点_实际流程_960x600.png"))
	print("CAMP_INTEGRATION_CAPTURE_READY")
	demo.queue_free()
	await process_frame
	quit()
