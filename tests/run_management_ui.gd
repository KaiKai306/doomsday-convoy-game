extends SceneTree
const GAME = preload("res://src/game/release_game.gd")
const SAVES = preload("res://src/game/save.gd")
var ui
var checks = 0
var failures = 0
const OUTPUT = "res://.docs/美术/车辆与路线界面_20261016/"
func _init() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL ",label)
func buttons(node: Node) -> Array:
	var result: Array = []
	for c in node.get_children():
		if c is Button: result.append(c)
		result.append_array(buttons(c))
	return result
func find_action(action: String,id: String = "") -> Button:
	for b in buttons(ui.management_screen.page):
		if b.get_meta("action_id","") == action and (id == "" or b.get_meta("command_args",{}).get("id","") == id): return b
	return null
func find_meta(key: String,value) -> Button:
	for b in buttons(ui.management_screen.page):
		if b.has_meta(key) and b.get_meta(key) == value: return b
	return null
func find_text(value: String) -> Button:
	for b in buttons(ui.management_screen.page):
		if b.text == value: return b
	return null
func shot(name: String) -> void:
	await process_frame; await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUTPUT+name+".png")
func settled() -> void:
	await process_frame
	while ui.loading_screen.busy: await process_frame
	await process_frame
func click(button: Button) -> void:
	var point = button.get_global_rect().get_center()
	var motion = InputEventMouseMotion.new(); motion.position = point; motion.global_position = point; root.push_input(motion,true)
	var down = InputEventMouseButton.new(); down.position = point; down.global_position = point; down.button_index = MOUSE_BUTTON_LEFT; down.button_mask = MOUSE_BUTTON_MASK_LEFT; down.pressed = true; root.push_input(down,true)
	var up = down.duplicate(); up.pressed = false; up.button_mask = 0; root.push_input(up,true)
	await settled()
func tap(button: Button) -> void:
	check(button != null,"touch target exists")
	if button == null: return
	var down = InputEventScreenTouch.new(); down.index = 0; down.position = button.get_global_rect().get_center(); down.pressed = true; root.push_input(down,true)
	var up = down.duplicate(); up.pressed = false; root.push_input(up,true)
	await settled()
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	root.size = Vector2i(1680,720)
	ui = load("res://scenes/release_game.tscn").instantiate(); ui.save_system = SAVES.new("user://management_ui_test"); root.add_child(ui)
	await process_frame
	ui.setup(); await settled(); ui.engine.new_game(81); ui.view = "equipment"; ui.refresh(); await settled()
	check(ui.management_screen.visible and not ui.canvas.visible,"new player interface replaces old canvas")
	var departure: Button = null
	for b in buttons(ui.management_screen.page):
		if b.text == "出发  ›": departure = b
	departure.pressed.emit(); await settled()
	check(ui.view == "route_map" and ui.management_screen.visible,"garage departure opens map preview before morning preparation")
	check(find_action("depart") == null,"map preview before preparation cannot depart")
	ui.view = "equipment"; ui.refresh(); await settled()
	await shot("01_车辆管理")
	var normalized = ui.engine.checkpoint()
	for nav in ui.management_screen.NAV:
		check(find_text(str(nav[1])) == null,"garage removes bottom navigation button "+str(nav[1]))
	check(find_text("查看改装") == null and find_text("安装配件") == null,"modification controls stay hidden until a vehicle is opened")
	await tap(find_meta("garage_vehicle",0))
	check(ui.management_screen.modal_kind == "" and ui.selected_vehicle == 0,"touching vehicle selects its 3D display without a blocking modal")
	await tap(find_meta("garage_vehicle_detail",0))
	check(ui.management_screen.modal_kind == "vehicle" and find_meta("vehicle_slot","front") != null and find_meta("vehicle_slot","rear") != null,"selected vehicle detail action opens its five modification slots")
	await shot("06_车辆详情_改装槽位")
	await tap(find_meta("vehicle_slot","front"))
	check(ui.management_screen.modal_kind == "modules" and ui.selected_slot == "front","slot touch drills into that vehicle's compatible modules")
	ui.management_screen._close_modal()
	check(ui.management_screen.modal_kind == "vehicle","module back returns to vehicle details")
	ui.management_screen._close_modal()
	check(ui.management_screen.modal == null and find_text("查看改装") == null,"closing details restores uncluttered garage")
	await tap(find_text("菜单"))
	check(ui.management_screen.modal_kind == "navigation" and find_meta("menu_view","team") != null,"compact menu preserves access to other screens")
	await tap(find_meta("menu_view","team"))
	check(ui.view == "team" and ui.management_screen.modal_kind == "","menu navigation opens members and dismisses menu")
	check(ui.engine.checkpoint() == normalized,"vehicle details and compact navigation preserve complete gameplay state and RNG")
	for page in ["route_map","team","inventory","knowledge","factions","goals","log","equipment"]:
		ui.view = page; ui.refresh(); await settled()
		check(ui.management_screen.visible and not ui.canvas.visible,"no legacy canvas on "+page)
		for nav in ui.management_screen.NAV:
			check(find_text(str(nav[1])) == null,"no bottom navigation on "+page+" / "+str(nav[1]))
		var menu = find_text("菜单")
		check(menu != null and menu.position.y < 90,"top menu is reachable on "+page)
		await tap(menu)
		check(ui.management_screen.modal_kind == "navigation","top menu opens on "+page)
		await tap(find_meta("menu_view",page if page != "route_map" else "journey"))
		check(ui.view == (page if page != "route_map" else "journey") and ui.management_screen.modal_kind == "","top menu selection works on "+page)
		ui.view = page; ui.refresh(); await settled()
		check(ui.engine.s.resources == normalized.current.resources and ui.engine.s.rng == normalized.current.rng and ui.engine.day_start == normalized.day_start,"browsing preserves quantities RNG and dawn: "+page)
		if page in ["team","inventory","knowledge","factions"]: await shot("补充_"+page)
	ui.management_screen._open_modal("modules"); await shot("02_配件安装")
	var unavailable = find_action("camp","install")
	check(unavailable != null and unavailable.disabled and unavailable.tooltip_text != "","unavailable module installation explains actual rule restriction")
	ui.management_screen.modal_kind = ""; ui.view = "inventory"; ui.refresh(); await settled()
	var drop = find_action("drop","water"); var resources_before = ui.engine.s.resources.duplicate(true); drop.pressed.emit()
	check(ui.confirmation.visible and ui.engine.s.resources == resources_before,"irreversible inventory action opens styled confirmation before mutation")
	await shot("补充_确认弹窗"); ui.confirmation.hide()
	ui.management_screen.modal_kind = ""; ui.view = "journey"; ui._run("prepare",{"id":"accounts"}); await settled(); ui._run("finish_prepare",{}); await settled()
	check(ui.engine.s.phase == "route" and ui.management_screen.visible,"route phase opens illustrated map")
	await shot("03_路线地图")
	var route_snapshot = ui.engine.checkpoint()
	for route in ["safe","resource","unknown","stay"]:
		for style in ["quiet","fast","detour"]:
			ui.route = route; ui.style = style; ui.refresh(); await settled()
			check(ui.engine.checkpoint() == route_snapshot,"map selection has no gameplay side effects "+route+"/"+style)
	ui.route = "resource"; ui.style = "quiet"; ui.refresh(); await settled()
	for b in buttons(ui.management_screen.page):
		if b.text == "快速": await click(b); break
	check(ui.style == "fast","real mouse input activates homepage-style map controls")
	ui.style = "quiet"; ui.refresh(); await settled()
	ui.management_screen._open_modal("route"); await shot("04_主线与路况"); ui.management_screen.modal_kind = ""; ui.refresh(); await settled()
	var depart = find_action("depart"); var quote: Dictionary = ui.engine.route_quote(ui.route,ui.style); var fuel = ui.engine.s.resources.fuel
	check(depart != null and not depart.disabled,"real map departure is available")
	depart.pressed.emit(); var after = ui.engine.checkpoint(); depart.pressed.emit(); await settled()
	check(ui.engine.s.resources.fuel == fuel-quote.fuel,"map departure pays quoted fuel exactly once")
	check(ui.engine.checkpoint() == after,"stale departure button cannot dispatch twice")
	if ui.engine.s.phase == "event":
		await shot("补充_途中事件")
		for option in range(5):
			if ui.engine.command("card",{"id":ui.engine.s.daily.card,"option":option}): break
	ui.view = "journey"; ui.refresh(); await settled()
	check(not ui.canvas.visible,"legacy canvas remains hidden after actual travel")
	if ui.engine.s.phase == "stop": ui._run("begin_camp",{}); await settled()
	ui.view = "equipment"; ui.refresh(); await settled()
	ui.engine.s.cores.SP01 = 1; ui.engine.s.resources.parts = 100; ui.selected_slot = "engine"; ui.refresh(); await settled()
	await tap(find_meta("garage_vehicle",0)); await tap(find_meta("garage_vehicle_detail",0)); await tap(find_meta("vehicle_slot","engine"))
	var install: Button = null
	for b in buttons(ui.management_screen.page):
		if b.get_meta("command_args",{}).get("module","") == "SP01": install = b
	# SP01 is an actual engine core, with its manuscript material cost.
	check(install != null and not install.disabled,"owned core in camp enables real installation")
	if install != null and not install.disabled:
		var parts = ui.engine.s.resources.parts; install.pressed.emit()
		check(ui.engine.s.vehicles[0].modules.get("engine","") == "SP01" and ui.engine.s.resources.parts == parts-ui.engine.content.modules.SP01.cost,"module selection installs and consumes actual materials")
	ui.management_screen._close_modal(); await shot("07_车辆详情_安装后")
	check(ui.management_screen.modal_kind == "vehicle" and ui.engine.s.vehicles[0].modules.engine == "SP01","returning from install retains installed module in vehicle details")
	var single_vehicle = ui.engine.checkpoint()
	ui.engine.s.vehicles.append(ui.engine.vehicle("界面测试副车",60)); ui.management_screen.modal_kind = ""; ui.refresh(); await settled()
	await tap(find_meta("garage_vehicle",1)); await tap(find_meta("garage_vehicle_detail",1)); await tap(find_meta("vehicle_slot","engine"))
	var second_install = find_action("camp","install")
	check(ui.selected_vehicle == 1 and second_install != null and second_install.get_meta("command_args",{}).get("vehicle",-1) == 1,"second vehicle details bind installation to the selected car")
	check(ui.engine.s.vehicles[0].modules.engine == "SP01" and ui.engine.s.vehicles[1].modules.is_empty(),"viewing second vehicle never copies or installs first vehicle modules")
	ui.engine.restore(single_vehicle); ui.selected_vehicle = 0
	ui.management_screen.modal_kind = ""; ui.view = "equipment"; ui.refresh()
	await shot("05_改装后车辆管理")
	ui.management_screen._open_modal("vehicle")
	for resolution in [Vector2i(1280,720),Vector2i(960,600),Vector2i(2340,1080),Vector2i(1680,720)]:
		root.size = resolution; await process_frame; ui.management_screen._fit()
		var rect = root.get_final_transform()*ui.management_screen.content.get_global_transform()*Rect2(Vector2.ZERO,ui.management_screen.DESIGN)
		check(rect.position.x >= -0.1 and rect.position.y >= -0.1 and rect.end.x <= root.size.x+0.1 and rect.end.y <= root.size.y+0.1,"new interface fits "+str(resolution))
		var panel = ui.management_screen.modal.get_child(1)
		var detail_rect = root.get_final_transform()*panel.get_global_transform()*Rect2(Vector2.ZERO,panel.size)
		check(Rect2(Vector2.ZERO,Vector2(root.size)).encloses(detail_rect),"vehicle details stay within screen at "+str(resolution))
	ui.management_screen._close_modal()
	ui._pause(); check(ui.management_screen.visible and not ui.canvas.visible,"pause uses new visual presentation"); await shot("补充_暂停")
	ui._pause(); ui.view = "journey"; ui.side_stage.mode = "drawer"; ui.refresh(); await settled(); await shot("补充_营地安排")
	print("MANAGEMENT_UI checks=",checks," failures=",failures)
	ui.queue_free(); await process_frame; quit(1 if failures else 0)
