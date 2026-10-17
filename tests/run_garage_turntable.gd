extends SceneTree
const PREVIEW = preload("res://src/ui/garage_vehicle_preview.gd")
const SAVES = preload("res://src/game/save.gd")
const OUT = "res://.docs/美术/车辆切换与自旋转_20261016/"
var ui
var checks = 0
var failures = 0
var signatures: Dictionary = {}

func _init() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL ",label)
func settled() -> void:
	await process_frame; await process_frame
	while ui.loading_screen.busy: await process_frame
	await process_frame; await process_frame
func rendered() -> void:
	await settled(); await RenderingServer.frame_post_draw
func button_meta(node: Node,key: String,value) -> Button:
	for child in node.get_children():
		if child is Button and child.has_meta(key) and child.get_meta(key) == value: return child
		var found = button_meta(child,key,value)
		if found != null: return found
	return null
func tap(button: Button) -> void:
	check(button != null,"requested touch control exists")
	if button == null: return
	var point = button.get_global_rect().get_center()
	var down = InputEventScreenTouch.new(); down.index = 0; down.position = point; down.pressed = true; root.push_input(down,true)
	var up = down.duplicate(); up.pressed = false; root.push_input(up,true)
	await settled()
func shot(label: String) -> void:
	await rendered()
	check(root.get_texture().get_image().save_png(OUT+label+".png") == OK,"capture "+label)
func scroll_to(index: int) -> void:
	var card_button = button_meta(ui.management_screen.page,"garage_vehicle",index)
	var scroll = card_button.get_parent().get_parent().get_parent()
	scroll.ensure_control_visible(card_button.get_parent()); await settled()

func run() -> void:
	if DisplayServer.get_name() == "headless": quit(2); return
	DirAccess.make_dir_recursive_absolute(OUT)
	var placement_before = FileAccess.get_file_as_string(PREVIEW.SETTINGS_PATH)
	var gas_before = FileAccess.get_file_as_string("res://data/showcase_vehicle_layout.json")
	root.size = Vector2i(1600,900)
	ui = load("res://scenes/release_game.tscn").instantiate(); ui.save_system = SAVES.new("user://garage_turntable_test"); root.add_child(ui)
	ui.setup(); await settled(); ui.engine.new_game(81)
	check(PREVIEW.card_model(ui.engine.s.vehicles[0],0) == "V05","legacy first pickup remains replaced by V05")
	ui.engine.s.vehicles = []
	for id in PREVIEW.MODELS.NAMES:
		var car: Dictionary = ui.engine.vehicle(PREVIEW.MODELS.NAMES[id],80)
		car.visual_id = id; ui.engine.s.vehicles.append(car)
	ui.selected_vehicle = 4; ui.view = "equipment"; ui.refresh(); await settled()
	var management = ui.management_screen; var preview = management.vehicle_preview
	check(is_instance_valid(preview) and PREVIEW.has_confirmed_placement(),"confirmed layout is enabled on formal page")
	preview.set_process(false)
	var pose = preview.adjustment.duplicate(true)
	check(pose.position == [777.0,584.0] and pose.rotation_degrees == -9 and pose.scale_percent == 85 and pose.view_elevation_degrees == 13.7,"exact user-confirmed pose loaded")
	var state_before = ui.engine.checkpoint()
	var stage = preview.stage
	for i in range(8):
		await scroll_to(i)
		await tap(button_meta(management.page,"garage_vehicle",i)); await rendered()
		var id = "V%02d" % (i+1)
		check(ui.selected_vehicle == i and preview.vehicle_id == id and stage.model_id == id and management.modal_kind == "","touch selects matching actual model "+id)
		check(management.vehicle_preview == preview and preview.stage == stage and preview.adjustment == pose,"switch retains stage and confirmed layout "+id)
		check(not stage.modules.armor.visible and not stage.modules.cargo.visible,"switch uses selected car's own modules "+id)
		var model_image: Image = stage.viewport.get_texture().get_image()
		var used = model_image.get_used_rect()
		check(used.size.x > 150 and used.size.y > 100 and used.position.x > 0 and used.end.x < model_image.get_width() and used.position.y > 0 and used.end.y < model_image.get_height(),"full geometry rendered within camera "+id)
		check(model_image.get_pixel(0,0).a < 0.01,"transparent runtime 3D background "+id)
		var signature = model_image.get_data().hex_encode().sha256_text()
		check(not signatures.has(signature),"distinct vehicle geometry and appearance "+id); signatures[signature] = id
		await shot("车型_"+id)
	check(ui.engine.checkpoint() == state_before,"switching eight models preserves gameplay and RNG")
	ui.selected_vehicle = 4; ui.refresh(); await settled()
	var phase = preview.rotation_offset; var pixels = stage.viewport.get_texture().get_image().get_data()
	preview._process(1.0); await rendered()
	check(is_equal_approx(preview.rotation_offset,phase+6) and stage.viewport.get_texture().get_image().get_data() != pixels,"time advances actual 3D pixels at 6 degrees per second")
	check(is_equal_approx(stage.rig.rotation.y,stage.shadow_rig.rotation.y),"body and real shadow rotate together")
	check(preview.adjustment == pose,"animation never overwrites the confirmed base angle")
	phase = preview.rotation_offset; ui.refresh(); await settled()
	check(is_equal_approx(preview.rotation_offset,phase),"page refresh preserves rotation phase")
	await tap(button_meta(management.page,"garage_spin_toggle",true))
	preview._process(2.0)
	check(is_equal_approx(preview.rotation_offset,phase),"pause button stops rotation")
	await tap(button_meta(management.page,"garage_spin_toggle",true))
	preview._process(0.5)
	check(preview.rotation_offset > phase,"resume button continues rotation")
	await tap(button_meta(management.page,"garage_vehicle_detail",4))
	phase = preview.rotation_offset; preview._process(1.0)
	check(management.modal_kind == "vehicle" and is_equal_approx(preview.rotation_offset,phase),"details remain reachable and pause rotation")
	management._close_modal(); preview._process(0.5)
	check(preview.rotation_offset > phase,"closing details resumes rotation")
	ui.view = "inventory"; ui.refresh(); await settled(); phase = preview.rotation_offset; preview._process(1.0)
	check(is_equal_approx(preview.rotation_offset,phase),"hidden garage stops rotation work")
	ui.view = "equipment"; ui.refresh(); await settled()
	ui.engine.s.vehicles[1].modules = {"front":"SP05","rear":"SP14"}
	ui.selected_vehicle = 1; ui.refresh(); await rendered()
	check(stage.modules.armor.visible and stage.shadow_modules.armor.visible and stage.modules.cargo.visible,"selected car's add-ons switch with its body and shadow")
	ui.selected_vehicle = 4; ui.refresh(); await rendered()
	check(not stage.modules.armor.visible and not stage.modules.cargo.visible,"previous car's add-ons do not leak")
	for resolution in [Vector2i(1600,720),Vector2i(960,432)]:
		root.size = resolution; await settled(); management._fit(); await settled()
		await shot("横屏_"+str(resolution.x)+"x"+str(resolution.y))
	root.size = Vector2i(1600,720); await settled(); management._fit(); await settled()
	for frame in range(12):
		preview._process(0.5); await shot("旋转_%02d" % frame)
	check(FileAccess.get_file_as_string(PREVIEW.SETTINGS_PATH) == placement_before,"confirmed layout file unchanged by selection and animation")
	check(FileAccess.get_file_as_string("res://data/showcase_vehicle_layout.json") == gas_before,"gas station layout remains unchanged")
	var file = FileAccess.open(OUT+"verification.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"renderer":RenderingServer.get_video_adapter_name(),"pose":pose,"rotation_speed_degrees":preview.rotation_speed_degrees,"models":PREVIEW.MODELS.NAMES,"simplified_models":["V01","V02","V03","V04","V06","V07","V08"],"settings_unchanged":true},"\t")); file.close()
	print("GARAGE_TURNTABLE checks=",checks," failures=",failures)
	ui.queue_free(); await process_frame; quit(1 if failures else 0)
