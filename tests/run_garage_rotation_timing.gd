extends SceneTree
## Sample the live render loop without screenshot readback or synthetic frame delays.
const PREVIEW = preload("res://src/ui/garage_vehicle_preview.gd")
const SAVES = preload("res://src/game/save.gd")
const OUT = "res://.docs/美术/车辆切换与自旋转_20261016/rotation_timing.json"
var ui
var checks = 0
var failures = 0

func _init() -> void: call_deferred("run")

func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL ",label)

func run() -> void:
	if DisplayServer.get_name() == "headless":
		print("Graphical rendering required"); quit(2); return
	var layout_before = FileAccess.get_file_as_string(PREVIEW.SETTINGS_PATH)
	var gas_before = FileAccess.get_file_as_string("res://data/showcase_vehicle_layout.json")
	root.size = Vector2i(1600,720)
	ui = load("res://scenes/release_game.tscn").instantiate()
	ui.save_system = SAVES.new("user://garage_rotation_timing_test")
	root.add_child(ui); ui.setup()
	while ui.loading_screen.busy: await process_frame
	ui.engine.new_game(81); ui.view = "equipment"; ui.refresh()
	while ui.loading_screen.busy: await process_frame
	var preview = ui.management_screen.vehicle_preview
	var pose: Dictionary = preview.adjustment.duplicate(true)
	var gameplay: Dictionary = ui.engine.checkpoint()
	for frame in range(120): await process_frame
	await RenderingServer.frame_post_draw
	var samples: Array[float] = []
	var angle_steps: Array[float] = []
	var previous_time = Time.get_ticks_usec()
	var previous_angle: float = preview.stage.angle
	var total_ms = 0.0
	var frozen_frames = 0
	var time_mismatches = 0
	var shadow_mismatches = 0
	while samples.size() < 600 and total_ms < 8000:
		await RenderingServer.frame_post_draw
		var now = Time.get_ticks_usec()
		var elapsed_ms = (now-previous_time)/1000.0
		var step = wrapf(preview.stage.angle-previous_angle,-180,180)
		samples.append(elapsed_ms); angle_steps.append(step); total_ms += elapsed_ms
		if step <= 0: frozen_frames += 1
		if absf(step-preview.rotation_speed_degrees*preview.get_process_delta_time()) > 0.0001: time_mismatches += 1
		if not is_equal_approx(preview.stage.rig.rotation.y,preview.stage.shadow_rig.rotation.y): shadow_mismatches += 1
		previous_time = now; previous_angle = preview.stage.angle
	preview.set_process(false)
	check(is_equal_approx(preview.rotation_speed_degrees,6.0),"one turn takes 60 seconds")
	check(frozen_frames == 0,"angle advances on every rendered frame")
	check(time_mismatches == 0,"unequal frame durations retain constant angular speed")
	check(shadow_mismatches == 0,"body and shadow stay synchronized on every sampled frame")
	preview.rotation_offset = 359.99
	preview.stage.set_angle(float(pose.rotation_degrees)+preview.rotation_offset)
	var before_wrap: float = preview.stage.angle
	preview._process(0.004)
	check(is_equal_approx(wrapf(preview.stage.angle-before_wrap,-180,180),0.024),"full-turn boundary remains continuous")
	var phase: float = preview.rotation_offset
	preview.set_turntable_enabled(false)
	for frame in range(10): await process_frame
	preview.set_process(true)
	for frame in range(10): await process_frame
	check(is_equal_approx(preview.rotation_offset,phase),"pause stays fixed across real frames")
	preview.set_turntable_enabled(true)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	check(wrapf(preview.rotation_offset-phase,0,360) < 1.0,"resume excludes time spent paused")
	check(preview.adjustment == pose and FileAccess.get_file_as_string(PREVIEW.SETTINGS_PATH) == layout_before,"animation preserves confirmed layout and file")
	check(FileAccess.get_file_as_string("res://data/showcase_vehicle_layout.json") == gas_before,"other scene placement remains unchanged")
	check(ui.engine.checkpoint() == gameplay,"animation preserves gameplay and RNG")
	samples.sort(); angle_steps.sort()
	var report = {"checks":checks,"failures":failures,"adapter":RenderingServer.get_video_adapter_name(),"window":[root.size.x,root.size.y],"frames":samples.size(),"fps":1000.0*samples.size()/total_ms,"mean_ms":total_ms/samples.size(),"p95_ms":samples[int(samples.size()*0.95)],"p99_ms":samples[int(samples.size()*0.99)],"max_ms":samples.back(),"min_angle_step":angle_steps.front(),"max_angle_step":angle_steps.back(),"frozen_frames":frozen_frames,"time_mismatches":time_mismatches,"shadow_mismatches":shadow_mismatches,"rotation_degrees_per_second":preview.rotation_speed_degrees,"pose":pose}
	DirAccess.make_dir_recursive_absolute(OUT.get_base_dir())
	var file = FileAccess.open(OUT,FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")); file.close()
	print("ROTATION_TIMING ",JSON.stringify(report))
	ui.queue_free(); await process_frame; quit(1 if failures else 0)
