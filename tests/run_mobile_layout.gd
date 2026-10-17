extends SceneTree
const MOBILE = preload("res://src/ui/mobile_layout.gd")
const SAVES = preload("res://src/game/save.gd")
const OUTPUT = "res://.docs/美术/手机横屏适配_20261016/"
var checks = 0
var failures = 0
var main
var ui
var evidence: Array = []
var profiles = [
	{"id":"16x9","size":Vector2i(1280,720),"insets":Vector4.ZERO},
	{"id":"19_5x9","size":Vector2i(1560,720),"insets":Vector4.ZERO},
	{"id":"20x9","size":Vector2i(1600,720),"insets":Vector4.ZERO},
	{"id":"21x9_notch","size":Vector2i(1680,720),"insets":Vector4(70,8,24,28)},
	{"id":"22x9","size":Vector2i(1760,720),"insets":Vector4.ZERO},
	{"id":"phone_2340x1080","size":Vector2i(2340,1080),"insets":Vector4(92,16,32,48)},
	{"id":"small_960x432","size":Vector2i(960,432),"insets":Vector4(28,0,12,12)}
]
func _init() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL ",label)
func settled() -> void:
	await process_frame; await process_frame
	if is_instance_valid(ui):
		while ui.loading_screen.busy: await process_frame
	await process_frame
func device(profile: Dictionary) -> void:
	root.set_meta("mobile_safe_insets",profile.insets)
	root.size = profile.size
	await settled()
	main._fit(); main.settings._fit()
	if is_instance_valid(ui):
		ui.management_screen._fit(); ui.side_stage._fit(); ui.side_stage.walk._fit(); ui.confirmation._fit(); ui.loading_screen._fit()
	await settled()
func bounds(control: Control) -> Rect2:
	return control.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,control.size)
func safe(control: Control,label: String) -> void:
	var area = MOBILE.safe_rect(main).grow(1)
	check(area.encloses(bounds(control)),label+" inside phone safe area")
func covers(control: Control,label: String) -> void:
	check(bounds(control).grow(1).encloses(root.get_visible_rect()),label+" covers entire phone display")
func shot(name: String) -> void:
	await settled()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(OUTPUT+name+".png") == OK,"capture "+name)
func button_text(node: Node,title: String) -> Button:
	for child in node.get_children():
		if child is Button and child.text == title: return child
		var nested = button_text(child,title)
		if nested != null: return nested
	return null
func button_meta(node: Node,key: String,value) -> Button:
	for child in node.get_children():
		if child is Button and child.has_meta(key) and child.get_meta(key) == value: return child
		var nested = button_meta(child,key,value)
		if nested != null: return nested
	return null
func click(button: Button) -> void:
	var point = button.get_global_rect().get_center()
	var motion = InputEventMouseMotion.new(); motion.position = point; root.push_input(motion,true)
	var down = InputEventMouseButton.new(); down.position = point; down.button_index = MOUSE_BUTTON_LEFT; down.pressed = true; down.button_mask = MOUSE_BUTTON_MASK_LEFT; root.push_input(down,true)
	var up = down.duplicate(); up.pressed = false; up.button_mask = 0; root.push_input(up,true)
	await settled()
func touch(point: Vector2,pressed: bool) -> void:
	var event = InputEventScreenTouch.new(); event.index = 3; event.position = point; event.pressed = pressed; root.push_input(event,true)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	check(ProjectSettings.get_setting("display/window/handheld/orientation") == DisplayServer.SCREEN_SENSOR_LANDSCAPE,"mobile build allows both landscape rotations")
	check(ProjectSettings.get_setting("display/window/stretch/aspect") == "expand","engine expands logical canvas for phone aspect")
	main = load("res://scenes/main.tscn").instantiate(); main.save_system = SAVES.new("res://.godot/mobile_layout_saves"); root.add_child(main)
	await settled(); await create_timer(0.3).timeout
	for profile in profiles:
		await device(profile)
		covers(main.cover,"title "+profile.id); covers(main.cover_video,"title video "+profile.id); safe(main.menu,"menu "+profile.id)
		if profile.id in ["16x9","20x9","phone_2340x1080"]: await shot("主页_"+profile.id)
		main._open_settings(); await create_timer(0.3).timeout
		covers(main.settings.background,"settings "+profile.id); safe(main.settings.body,"settings controls "+profile.id)
		if profile.id == "20x9": await shot("设置_"+profile.id)
		main.settings.close_screen(); main.menu.show()
	main._start_game(); ui = main.day_demo; await settled()
	ui.engine.new_game(81); ui.view = "equipment"; ui.refresh(); await settled()
	for profile in profiles:
		await device(profile)
		ui.view = "equipment"; ui.refresh(); await settled()
		var before = ui.engine.checkpoint()
		covers(ui.management_screen.background_picture,"garage "+profile.id); safe(ui.management_screen.content,"garage controls "+profile.id)
		var departure = button_text(ui.management_screen.page,"出发  ›")
		safe(departure,"garage departure "+profile.id)
		check(departure.size.y >= 48,"departure has phone touch height "+profile.id)
		await shot("车辆_"+profile.id)
		await click(button_meta(ui.management_screen.page,"garage_vehicle",0))
		await click(button_meta(ui.management_screen.page,"garage_vehicle_detail",0))
		safe(ui.management_screen.modal.get_child(1),"vehicle details "+profile.id)
		var engine_slot = button_meta(ui.management_screen.page,"vehicle_slot","engine")
		safe(engine_slot,"vehicle slot "+profile.id)
		await shot("改装_"+profile.id)
		await click(engine_slot)
		safe(ui.management_screen.modal.get_child(1),"module details "+profile.id)
		ui.management_screen._close_modal(); ui.management_screen._close_modal(); await settled()
		departure = button_text(ui.management_screen.page,"出发  ›")
		await click(departure)
		check(ui.view == "route_map","phone coordinates activate map entry "+profile.id)
		covers(ui.management_screen.background_picture,"map "+profile.id)
		await click(button_text(ui.management_screen.page,"快速"))
		check(ui.style == "fast","phone map style click "+profile.id)
		await shot("地图_"+profile.id)
		var menu = button_text(ui.management_screen.page,"菜单")
		safe(menu,"map menu "+profile.id)
		await click(menu)
		safe(ui.management_screen.modal.get_child(1),"navigation menu "+profile.id)
		await click(button_meta(ui.management_screen.page,"menu_view","inventory"))
		check(ui.view == "inventory" and ui.management_screen.modal_kind == "","top phone menu opens inventory "+profile.id)
		ui.view = "journey"; ui.refresh(); await settled()
		var walk = ui.side_stage.walk
		covers(walk.content,"world scene "+profile.id); safe(ui.side_stage.content,"scene overlays "+profile.id)
		safe(walk.hud,"touch HUD "+profile.id); safe(walk.joystick,"joystick "+profile.id); safe(walk.talk,"interaction "+profile.id)
		check(absf(walk.content.scale.x-walk.content.scale.y) < 0.001,"scene and actors retain proportions "+profile.id)
		var start_x = walk.player_x
		var press_point = walk.joystick.get_global_transform()*Vector2(walk.joystick.size.x*0.78,walk.joystick.size.y*0.5)
		touch(press_point,true); await process_frame; walk._process(0.1)
		check(walk.joystick.owner_pointer == 3 and walk.player_x > start_x,"safe-area joystick receives real touch "+profile.id)
		touch(Vector2.ZERO,false); await process_frame
		check(walk.joystick.owner_pointer == walk.joystick.NONE and walk.direction == 0,"touch release outside joystick clears motion "+profile.id)
		await shot("场景_"+profile.id)
		ui.side_stage.open_member(str(walk.npcs[0].id)); await settled()
		for panel in ui.side_stage.overlay.get_children():
			if panel is Control: safe(panel,"dialogue panel "+profile.id)
		check(walk.input_locked,"dialogue blocks movement on phone "+profile.id)
		if profile.id == "20x9": await shot("对话_"+profile.id)
		ui.side_stage.back(); await settled()
		ui._pause(); await settled(); safe(ui.management_screen.content,"pause "+profile.id)
		if profile.id == "20x9": await shot("暂停_"+profile.id)
		ui.confirmation.dialog_text = "手机横屏确认窗口：按钮应完整显示，并避开刘海与底部手势区。"; ui.confirmation.popup_centered()
		safe(ui.confirmation.frame,"confirmation "+profile.id)
		if profile.id == "20x9": await shot("确认_"+profile.id)
		ui.confirmation.hide(); ui._pause(); await settled()
		check(ui.engine.checkpoint() == before,"phone resize and navigation preserve gameplay "+profile.id)
		evidence.append({"profile":profile.id,"window":str(root.size),"logical_canvas":str(root.get_visible_rect().size),"safe_area":str(MOBILE.safe_rect(main))})
	var file = FileAccess.open(OUTPUT+"verification.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"graphical":DisplayServer.get_name() != "headless","profiles":evidence},"\t")); file.close()
	main.queue_free(); await process_frame
	print("MOBILE_LAYOUT checks=",checks," failures=",failures); quit(1 if failures else 0)
