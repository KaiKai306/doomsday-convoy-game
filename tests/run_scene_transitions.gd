extends SceneTree
const SAVES = preload("res://src/game/save.gd")
var checks = 0
var failures = 0
var ui
var output = "res://.docs/美术/站房入口与加载_20261016"

func _init(): call_deferred("run")
func check(ok: bool, label: String):
	checks += 1
	if not ok: failures += 1; print("FAIL ",label)

func settled():
	var deadline = Time.get_ticks_msec()+15000
	while ui.loading_screen.busy and Time.get_ticks_msec() < deadline: await process_frame
	check(not ui.loading_screen.busy,"load automatically finishes before timeout")
	await process_frame

func shot(name: String):
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(output.path_join(name+".png")) == OK,"capture "+name)

func key(code: Key):
	var event = InputEventKey.new(); event.physical_keycode = code; event.pressed = true
	Input.parse_input_event(event); await process_frame
	event = InputEventKey.new(); event.physical_keycode = code; event.pressed = false
	Input.parse_input_event(event); await process_frame

func no_fixed_door(node: Node) -> bool:
	for child in node.get_children():
		if child is Button and ("进入内屋" in child.text or "返回站外" in child.text or "进入加油站内屋" in child.text): return false
		if not no_fixed_door(child): return false
	return true

func run():
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1680,720)
	var main = load("res://scenes/main.tscn").instantiate()
	main.save_system = SAVES.new("res://.godot/door_transition_test/save"); root.add_child(main)
	await process_frame; main._start_game(); ui = main.day_demo
	check(ui.loading_screen.busy and ui.loading_screen.screen.visible,"new game shows loading cover immediately")
	check(ui.scene_backdrop.location_id == "","cover precedes synchronous scene assembly")
	await shot("01_加载画面")
	await settled()
	var stage = ui.side_stage; var walk = stage.walk; walk.set_process(false)
	var before = ui.engine.checkpoint()
	check(stage.current_location == "forest_gas_station" and not walk.input_locked,"auto enters station and unlocks exploration")
	check(no_fixed_door(stage.overlay) and no_fixed_door(ui.choices),"no fixed screen or menu entrance remains")
	check(not walk.entrance_button.visible and not walk.can_use_entrance(),"spawn is outside door proximity")
	await shot("02_站外远离门口")
	walk.entrance_button.pressed.emit()
	check(not ui.scene_context.get("opening_inside",false),"stale door button cannot enter from a distance")
	var reference_x = float(walk.backdrop.config.preserved_center[0])+155.0
	check(is_equal_approx(float(walk.entrance.source_x),reference_x),"exterior entrance matches captain position in user reference")
	walk._hold("test",-1,true); walk._process(0.65)
	check(not walk.entrance_button.visible,"old entrance beside mechanic no longer triggers")
	walk._process(0.37)
	check(not walk.entrance_button.visible,"approaching storefront still hides prompt before reaching marked position")
	walk._process(0.17); walk._hold("test",0,false)
	check(walk.entrance_button.visible and walk.can_use_entrance(),"walking toward actual station door reveals entrance")
	check(absf(walk.backdrop.view_to_source(Vector2(walk.player_x,0)).x-reference_x) < 1,"captain reaches user-marked storefront position")
	check(absf(walk.entrance_button.position.x+95-walk.backdrop.source_to_view(Vector2(walk.entrance.source_x,806)).x) < 1,"prompt follows door world position")
	await shot("03_靠近站房门口")
	walk._hold("test",1,true); walk._process(0.5); walk._hold("test",0,false)
	check(not walk.entrance_button.visible,"walking away hides entrance")
	walk.place_player_at(walk.entrance.source_x+45)
	ui._pause(); check(not walk.entrance_button.visible and walk.input_locked,"pause hides entrance and stops movement")
	walk.entrance_button.pressed.emit(); check(not ui.scene_context.get("opening_inside",false),"paused stale prompt cannot enter")
	ui._pause(); check(walk.entrance_button.visible,"resume rechecks proximity")
	stage.open_member(walk.npcs[0].id)
	check(not walk.entrance_button.visible and walk.input_locked,"dialogue blocks door interaction")
	stage.back(); check(not walk.input_locked,"dialogue exit restores exploration")
	walk.place_player_at(walk.entrance.source_x+45)
	var return_x = walk.backdrop.view_to_source(Vector2(walk.player_x,0)).x
	await key(KEY_E)
	check(ui.loading_screen.busy and walk.input_locked,"E at door starts covered transition and locks old walk")
	check(ui.scene_context.opening_inside and stage.current_location == "forest_gas_station","scene assembly waits behind the cover")
	var paused = ui.paused
	await key(KEY_ESCAPE); await key(KEY_SPACE)
	check(ui.paused == paused and ui.scene_context.opening_inside,"loading swallows pause and repeated interaction keys")
	await settled(); walk = stage.walk; walk.set_process(false)
	check(stage.current_location == "gas_station_interior" and walk.entrance_button.visible,"interior spawns by usable exit")
	ui._pause(); check(not ui.loading_screen.busy,"pause does not change the world scene or show loading")
	ui._pause(); check(not ui.loading_screen.busy and walk.entrance_button.visible,"resume restores interior without a scene transition")
	check(ui.engine.checkpoint() == before,"entry preserves full rules state and RNG")
	await shot("04_内屋出口")
	var disk = ui.save_system.load_from_file()
	check(disk.presentation.opening_inside and is_equal_approx(float(disk.presentation.opening_return_x),return_x),"save stores room and exterior return position")
	walk.entrance_button.pressed.emit(); check(ui.loading_screen.busy,"click exit starts loading")
	await settled(); walk = stage.walk; walk.set_process(false)
	check(stage.current_location == "forest_gas_station" and absf(walk.backdrop.view_to_source(Vector2(walk.player_x,0)).x-return_x) < 0.1,"exit returns to exact outside door position")
	check(ui.engine.checkpoint() == before,"exit preserves full rules state and RNG")
	await shot("05_返回站外")
	check(ui.setup(null,disk),"saved interior restores successfully"); await settled()
	check(stage.current_location == "gas_station_interior" and ui.scene_context.opening_inside,"continue restores inside through loading screen")
	ui._toggle_opening_room(); await settled()
	ui._run("prepare",{"id":"none"}); ui._run("finish_prepare",{}); await settled()
	ui._run("depart",{"route":"resource","style":"quiet","supply":"water"})
	check(ui.loading_screen.busy,"real departure also shows loading")
	await settled()
	check(ui.scene_backdrop.location_id != "forest_gas_station" and not ui.scene_context.get("opening_inside",false),"departure clears opening presentation")
	var payload = ui.engine.checkpoint()
	main._return_to_menu(); check(main.menu_loading.busy,"return to main menu uses the same loading cover")
	await main.menu_loading.finished
	check(main.day_demo == null and main.frame.visible and not main.transitioning,"loading automatically returns to main menu")
	main._continue(); ui = main.day_demo
	check(ui.loading_screen.busy,"continue starts with a loading cover"); await settled()
	check(ui.engine.checkpoint() == payload,"continue preserves exact saved state")
	var file = FileAccess.open(output.path_join("verification.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"graphical":DisplayServer.get_name() != "headless"},"\t")); file.close()
	main.queue_free(); await process_frame
	print("SCENE_TRANSITIONS checks=",checks," failures=",failures); quit(failures)
