extends SceneTree
const PREVIEW = preload("res://src/ui/garage_vehicle_preview.gd")
const EDITOR = preload("res://src/showcase/garage_vehicle_placement.gd")
const SAVES = preload("res://src/game/save.gd")
const OUT = "res://.docs/美术/车辆管理3D调试_20261016/"
const TEMP = "res://.godot/garage_3d_test/V05.json"
var checks = 0
var failures = 0
var ui

func _init() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL ",label)
func settled() -> void:
	await process_frame; await process_frame
	while ui.loading_screen.busy: await process_frame
	await process_frame; await process_frame
func rendered() -> void:
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
func image_in(node: Node,path: String) -> bool:
	if node is TextureRect and node.texture != null and node.texture.resource_path == path: return true
	for child in node.get_children():
		if image_in(child,path): return true
	return false
func shot(label: String) -> void:
	await rendered()
	check(root.get_texture().get_image().save_png(OUT+label+".png") == OK,"capture "+label)
func run() -> void:
	if DisplayServer.get_name() == "headless": print("Graphical rendering required"); quit(2); return
	DirAccess.make_dir_recursive_absolute(OUT)
	var gas_before = FileAccess.get_file_as_string("res://data/showcase_vehicle_layout.json")
	root.size = Vector2i(1600,900)
	ui = load("res://scenes/release_game.tscn").instantiate(); ui.save_system = SAVES.new("user://garage_3d_test_saves"); root.add_child(ui)
	ui.setup(); await settled(); ui.engine.new_game(81); ui.view = "equipment"; ui.refresh(); await settled()
	var management = ui.management_screen
	check(image_in(management.page,"res://assets/vehicles/realistic_20261015/V05_right.png"),"first card uses V05 asset")
	if not PREVIEW.has_confirmed_placement(): check(not is_instance_valid(management.vehicle_preview),"unconfirmed initial placement is restricted to debug preview")
	var before = ui.engine.checkpoint()
	root.set_meta("garage_vehicle_debug",true); ui.refresh(); await settled()
	var preview = management.vehicle_preview
	preview.turntable_enabled = false
	preview.settings_path = TEMP; preview.reset_adjustments()
	check(preview.stage.ready_ok,"real 3D vehicle stage loaded")
	check(preview.stage.rig.get_child_count() > 0 and preview.stage.camera != null,"mesh and camera are present")
	check(not preview.stage.modules.armor.visible and not preview.stage.modules.cargo.visible,"uninstalled add-on geometry stays hidden")
	await shot("01_车辆管理_V05_初始调试")
	var model_image: Image = preview.stage.viewport.get_texture().get_image()
	check(model_image.get_used_rect().size.x > 150 and model_image.get_used_rect().size.y > 100,"GPU render contains opaque vehicle geometry")
	check(model_image.get_pixel(0,0).a < 0.01,"3D viewport background is transparent")
	var initial_pixels = model_image.get_data()
	var foot: Vector2 = preview.stage.vehicle_sprite.position
	preview.set_adjustment("rotation_degrees",67); await rendered()
	check(preview.stage.viewport.get_texture().get_image().get_data() != initial_pixels,"rotation changes actual 3D render")
	check(is_equal_approx(preview.stage.rig.rotation.y,preview.stage.shadow_rig.rotation.y),"body and cast-shadow geometry rotate together")
	preview.set_adjustment("scale_percent",51)
	check(preview.stage.vehicle_sprite.position.is_equal_approx(foot) and is_equal_approx(preview.stage.scale.x,0.51),"size changes preserve the ground pivot")
	preview.set_adjustment("view_elevation_degrees",18.5)
	check(preview.stage.camera.position.is_equal_approx(preview.stage.shadow_camera.position),"body and shadow use matching elevation")
	var editor = EDITOR.new(); editor.management = management; root.add_child(editor); editor.hide()
	# Text is intentionally not submitted with Enter before Save.
	editor.fields.x.get_line_edit().text = "754"
	editor.fields.scale_percent.get_line_edit().text = "47"
	editor.save_adjustments()
	var stored = JSON.parse_string(FileAccess.get_file_as_string(TEMP))
	check(stored.position[0] == 754 and stored.scale_percent == 47,"save commits pending numeric input without Enter")
	check(stored.scene_id == "vehicle_management" and stored.vehicle_id == "V05" and stored.user_confirmed == false,"saved draft identifies this page and awaits user confirmation")
	var retained_stage = preview.stage
	ui.refresh(); await settled()
	check(management.vehicle_preview == preview and preview.stage == retained_stage,"refresh retains the model and current slider values")
	check(preview.adjustment.position[0] == 754 and preview.adjustment.scale_percent == 47,"refresh preserves unsaved working placement")
	preview.reset_adjustments(); preview.load_adjustments(); preview.apply_adjustments()
	check(preview.adjustment.position[0] == 754 and preview.adjustment.scale_percent == 47 and preview.adjustment.rotation_degrees == 67,"saved placement reads back exactly")
	check(ui.engine.checkpoint() == before,"model display and adjustment preserve all gameplay state and RNG")
	ui.view = "inventory"; ui.refresh(); await settled()
	check(not preview.visible,"3D model hides outside the garage")
	ui.view = "equipment"; ui.refresh(); await settled()
	check(preview.visible and preview.stage == retained_stage,"returning to garage reuses the same model")
	var draft_before_reset = FileAccess.get_file_as_string(TEMP)
	editor.reset_adjustments()
	check(FileAccess.get_file_as_string(TEMP) == draft_before_reset,"reset never overwrites saved adjustments")
	for resolution in [Vector2i(1280,720),Vector2i(1600,720),Vector2i(960,432)]:
		root.size = resolution; await settled(); management._fit(); await settled()
		var rect: Rect2 = preview.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,preview.size)
		check(preload("res://src/ui/mobile_layout.gd").safe_rect(ui).grow(1).encloses(rect),"3D region stays within safe area "+str(resolution))
		var controls_y = management.content.size.y-125
		check(preview.position.y+preview.size.y < controls_y,"3D clipping area cannot cover bottom actions "+str(resolution))
		await shot("02_V05_"+str(resolution.x)+"x"+str(resolution.y))
	management._open_modal("vehicle"); await shot("03_车辆详情仍可使用")
	check(management.modal_kind == "vehicle","3D preview preserves selected-vehicle detail flow")
	management._close_modal()
	check(FileAccess.get_file_as_string("res://data/showcase_vehicle_layout.json") == gas_before,"gas-station confirmed placement is unchanged")
	var file = FileAccess.open(OUT+"verification.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"renderer":RenderingServer.get_video_adapter_name(),"placement":"unconfirmed initial debug values","model":PREVIEW.STAGE.MODEL_PATH},"\t")); file.close()
	print("GARAGE_VEHICLE_3D checks=",checks," failures=",failures)
	editor.queue_free(); ui.queue_free(); await process_frame; quit(1 if failures else 0)
