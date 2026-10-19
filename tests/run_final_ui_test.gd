extends SceneTree
const Saves = preload("res://src/game/save.gd")
const Rules = preload("res://src/game/world_rules.gd")
var checks = 0
var failures = 0
var ui
func _init(): call_deferred("run")
func check(ok: bool, label: String):
	checks += 1
	if not ok: failures += 1; print("FAIL ",label)
func settled():
	var deadline = Time.get_ticks_msec()+15000
	while ui.loading_screen.busy and Time.get_ticks_msec() < deadline: await process_frame
	check(not ui.loading_screen.busy,"scene transition finishes automatically")
func capture(name: String):
	if is_instance_valid(ui): await settled()
	await process_frame; await process_frame
	if DisplayServer.get_name() != "headless": root.get_texture().get_image().save_png("res://.godot/final-qa/"+name+".png")
func action_button(ui, action: String, id: String = "") -> Button:
	for child in ui.choices.get_children():
		if child is Button and child.get_meta("action_id","") == action and (id == "" or child.get_meta("command_args",{}).get("id","") == id): return child
	return null
func setting_control(node: Node, key: String) -> Control:
	for child in node.get_children():
		if child is Control and child.get_meta("setting_key", "") == key: return child
		var nested = setting_control(child, key)
		if nested != null: return nested
	return null
func music_gain() -> float:
	var index = AudioServer.get_bus_index("ConvoyMusic")
	return 0.0 if AudioServer.is_bus_mute(index) else db_to_linear(AudioServer.get_bus_volume_db(index))
func run():
	DirAccess.make_dir_recursive_absolute("res://.godot/final-qa")
	root.size = Vector2i(1280,720)
	var main = load("res://scenes/main.tscn").instantiate(); main.save_system = Saves.new("user://final_menu_test_saves"); root.add_child(main)
	await process_frame
	await capture("01_menu")
	await create_timer(0.55).timeout
	check(main.menu_music.playing and main.music_director.current_cue == "main_menu","main page plays its music cue")
	check(main.menu_music.stream.get_length() > 5.0,"menu music contains a usable loop recording")
	check(is_equal_approx(music_gain(),0.52),"BGM obeys default master and music volumes")
	main.menu_music.seek(main.menu_music.stream.get_length()-0.12)
	await create_timer(0.4).timeout
	check(main.menu_music.playing and main.menu_music.get_playback_position() < 1.0,"BGM wraps at the end and keeps playing")
	main._open_settings(); await create_timer(0.3).timeout
	check(main.settings.visible and main.menu_music.playing,"settings keeps main page music playing")
	var music = setting_control(main.settings.content,"music")
	music.value = 0; await create_timer(0.2).timeout
	check(is_zero_approx(music_gain()),"music slider zero silences BGM")
	music.value = 40; setting_control(main.settings.content,"master").value = 50
	await create_timer(0.2).timeout
	check(is_equal_approx(music_gain(),0.2),"BGM updates from live music and master sliders")
	setting_control(main.settings.content,"mute").pressed.emit(); await create_timer(0.2).timeout
	check(is_zero_approx(music_gain()),"mute silences BGM")
	main.settings._restore_defaults(); await create_timer(0.2).timeout
	check(is_equal_approx(music_gain(),0.52),"restore defaults reapplies music volume")
	main.settings.close_screen()
	main._start_game()
	ui = main.day_demo; await settled()
	await create_timer(0.25).timeout
	check(main.menu_music.playing and main.music_director.current_cue != "main_menu","gameplay replaces menu music with the scene cue")
	check(ui != null and ui.engine.s.day == 1 and ui.engine.s.members.size() == 5,"main menu opens new twenty-day engine")
	ui.engine.new_game(81); ui.refresh(); await settled()
	for size_value in [Vector2i(960,600),Vector2i(1560,720),Vector2i(2340,1080),Vector2i(1280,720)]:
		root.size = size_value; await process_frame; ui._fit()
		# canvas_items stretches logical coordinates into the physical window.
		# Include that transform so the small-window check measures actual pixels.
		var physical_rect = root.get_final_transform() * ui.canvas.get_global_transform() * Rect2(Vector2.ZERO,ui.canvas.size)
		check(physical_rect.position.x >= -0.1 and physical_rect.position.y >= -0.1 and physical_rect.end.x <= root.size.x+0.1 and physical_rect.end.y <= root.size.y+0.1,"functional panels fit landscape "+str(size_value))
		if size_value == Vector2i(960,600): await capture("02_morning_960x600")
	await capture("02_morning")
	check(not ui.information.text.contains("建立五人基线") and not ui.information.text.contains("教会实际"),"day plan addresses the player without authoring notes")
	var before = ui.engine.checkpoint()
	for page in ["journey","team","inventory","equipment","knowledge","factions","goals","log"]:
		ui.view = page; ui.refresh(); await settled()
		check(ui.choices.get_child_count() > 0 or page == "log","page renders "+page)
	# Cargo ledger is normalized by the vehicle page. Preview commands must preserve
	# gameplay quantities, random state, and morning snapshot.
	check(ui.engine.s.resources == before.current.resources and ui.engine.s.rng == before.current.rng and ui.engine.day_start == before.day_start,"all panel previews preserve gameplay RNG and dawn snapshot")
	ui.view = "goals"; ui.refresh(); await settled()
	check(action_button(ui,"goal","E12") != null and action_button(ui,"goal","E12").disabled and action_button(ui,"goal","E12").text.contains("尚缺"),"unavailable arrival action explains its missing requirements")
	var saved = ui.engine.checkpoint()
	for id in ui.engine.content.cards:
		ui._card_view(id)
		if ui.engine.checkpoint() != saved: check(false,"card preview mutates state "+id)
	check(ui.engine.checkpoint() == saved,"all 109 card views render without resolving actions")
	ui.view = "journey"; ui._run("prepare",{"id":"accounts"}); ui._run("finish_prepare",{}); await settled()
	check(ui.information.text.contains("准备完成：清账") and not ui.information.text.contains("accounts"),"journal uses player-readable action names")
	await capture("03_routes")
	ui._run("depart",{"route":"resource","style":"quiet","supply":"water"}); await settled()
	if ui.engine.s.phase == "event":
		for o in range(5):
			if ui.engine.command("card",{"id":ui.engine.s.daily.card,"option":o}): break
		ui.refresh(); await settled()
	check(ui.engine.s.phase == "stop","route reaches stop in rendered scene")
	await capture("04_stop")
	ui._open_camp_walk(); await process_frame
	var walk = ui.canvas.get_child(ui.canvas.get_child_count()-1)
	check(walk.npcs.size() == 4,"side-view camp contains current living teammates")
	walk.player_x = walk.npcs[0].x
	check(walk.nearest().id == walk.npcs[0].id,"camp proximity enables correct NPC")
	walk.set_process(false)
	var touch = InputEventScreenTouch.new(); touch.index = 0; touch.pressed = true
	walk._direction_input(touch,-1)
	var second_touch = InputEventScreenTouch.new(); second_touch.index = 1; second_touch.pressed = true
	walk._direction_input(second_touch,1)
	check(walk.direction == 0,"opposite touch directions cancel")
	touch.pressed = false; walk._input(touch)
	check(walk.direction == 1,"lifting one finger preserves the other held direction")
	var start_x = walk.player_x; walk._process(0.1)
	check(walk.player_x > start_x,"remaining touch moves the player")
	second_touch.pressed = false; walk._input(second_touch)
	start_x = walk.player_x; walk._process(0.1)
	check(walk.direction == 0 and walk.player_x == start_x,"release outside button stops held movement")
	touch.pressed = true; walk._direction_input(touch,1)
	walk.notification(Control.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	check(walk.direction == 0 and walk.destination == walk.player_x,"focus loss clears movement")
	walk.player_x = walk.npcs[0].x
	await capture("05_camp_walk")
	walk.closed.emit(); await process_frame; await settled()
	ui.view = "equipment"; ui.refresh(); await capture("06_equipment")
	var payload = ui.engine.checkpoint(); ui._autosave()
	main._return_to_menu(); await main.menu_loading.finished
	check(main.menu_music.playing,"return to main page resumes BGM")
	main._continue(); ui = main.day_demo; await settled()
	check(main.day_demo != null and main.day_demo.engine.checkpoint().current == payload.current,"menu continue restores current phase all state")
	ui = main.day_demo
	var witness = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/final_endings_paths.json"))
	var rescue_route = witness.filter(func(row): return row.target == "E12")[0]
	var real_rescue = Rules.new(); real_rescue.new_game(int(rescue_route.seed))
	for command in rescue_route.commands:
		if real_rescue.s.day == 10 and real_rescue.s.phase == "rescue": break
		if not real_rescue.command(command.action,command.args): check(false,"rescue UI fixture replays a legal opening"); break
	check(real_rescue.s.day == 10 and real_rescue.s.phase == "rescue" and real_rescue.rescue_missing().is_empty(),"rescue panel starts from a real ten-day journey")
	ui.engine.restore(real_rescue.checkpoint()); ui.view = "journey"; ui.refresh(); await settled()
	check(not action_button(ui,"rescue","quiet").disabled and not action_button(ui,"rescue","abandon").disabled,"prepared real journey permits rescue or explicit abandonment")
	await capture("07_rescue")
	ui.view = "goals"; ui.refresh(); await capture("09_goals")
	ui._pause()
	var retry_before = ui.engine.checkpoint()
	ui._issue("retry",{},true,"重试当天")
	check(ui.confirmation.visible and ui.engine.checkpoint() == retry_before,"irreversible retry waits for confirmation without mutating the game")
	ui.confirmation.hide(); ui._confirm(); await settled()
	check(not ui.paused and ui.view == "journey" and ui.engine.s.day == 10 and ui.engine.s.phase == "morning","confirmed retry exits pause and restores the current day's morning")
	var continue_rescue = false
	for command in rescue_route.commands:
		if int(command.day) == 10 and command.phase == "rescue": continue_rescue = true
		if continue_rescue and not real_rescue.command(command.action,command.args): check(false,"rendered ending follows legal rescue route"); break
	check(real_rescue.s.ending == "E12","ending screenshot uses completed real journey")
	ui.engine.restore(real_rescue.checkpoint()); ui.view = "journey"; ui.refresh(); await capture("08_ending")
	check(ui.information.text.contains("南边") and ui.choices.get_child_count() >= 2,"ending text epilogue retry and menu render")
	main.queue_free(); await process_frame
	print("FINAL_UI checks=",checks," failures=",failures)
	quit(failures)
