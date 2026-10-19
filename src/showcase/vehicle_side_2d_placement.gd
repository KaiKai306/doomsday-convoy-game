extends Control
## A standalone real-scene editor. Only the user's Save and Apply writes layouts.
const BACKDROP = preload("res://src/game/walk_backdrop.gd")
const RENDERER = preload("res://src/game/vehicle_side_2d.gd")
const LAYOUT = preload("res://src/game/vehicle_side_2d_layout.gd")
const THEME = preload("res://src/ui/convoy_theme.gd")
const DESIGN = Vector2(1680,720)
const SCENES = ["camp","gas_station","journey_road"]
const TITLES = ["室外营地","废弃加油站","旅途公路"]
const NAMES = ["旧皮卡","银色轿车","旧式轿车","旅行面包车","深灰越野车","深色短面包车","厢式货车","沙色越野车"]
var backdrop
var preview: Control
var dock: PanelContainer
var scene_selector: OptionButton
var vehicle_selector: OptionButton
var facing_selector: OptionButton
var save_button: Button
var asset_status: Label
var status: Label
var fields: Dictionary = {}
var sliders: Dictionary = {}
var drafts: Dictionary = {}
var current: Dictionary = {}
var displayed_art: Dictionary = {}
var current_scene = "camp"
var current_vehicle = "V01"
var syncing = false
var camera_x = 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = THEME.create()
	RenderingServer.set_default_clear_color(Color("08121c"))
	preview = Control.new(); preview.name = "ActualScene"; preview.size = DESIGN; preview.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(preview)
	backdrop = BACKDROP.new(); backdrop.name = "ProductionWalkBackdrop"
	backdrop.canvas_size = DESIGN; backdrop.size = DESIGN; backdrop.full_map = true
	preview.add_child(backdrop)
	_build_ui()
	backdrop.display(current_scene,[]); _load_current()
	get_viewport().size_changed.connect(_layout); resized.connect(_layout)
	call_deferred("_layout")
	DisplayServer.window_set_title("末日车队 · 2D车辆场景手动摆放")

func _build_ui() -> void:
	dock = PanelContainer.new(); dock.name = "PlacementControls"; add_child(dock)
	var style = StyleBoxFlat.new(); style.bg_color = Color("10202c"); style.border_color = Color("3f6476"); style.set_border_width_all(1)
	style.content_margin_left = 18; style.content_margin_right = 18; style.content_margin_top = 12; style.content_margin_bottom = 12
	dock.add_theme_stylebox_override("panel",style)
	var column = VBoxContainer.new(); column.add_theme_constant_override("separation",8); dock.add_child(column)
	var selectors = HBoxContainer.new(); selectors.add_theme_constant_override("separation",12); column.add_child(selectors)
	var heading = Label.new(); heading.text = "2D车辆摆放"; heading.add_theme_font_size_override("font_size",22); selectors.add_child(heading)
	scene_selector = OptionButton.new(); scene_selector.custom_minimum_size = Vector2(160,36)
	for title in TITLES: scene_selector.add_item(title)
	selectors.add_child(scene_selector); scene_selector.item_selected.connect(_select_scene)
	vehicle_selector = OptionButton.new(); vehicle_selector.custom_minimum_size = Vector2(200,36)
	for index in LAYOUT.VEHICLE_IDS.size(): vehicle_selector.add_item(LAYOUT.VEHICLE_IDS[index]+" · "+NAMES[index])
	selectors.add_child(vehicle_selector); vehicle_selector.item_selected.connect(_select_vehicle)
	facing_selector = OptionButton.new(); facing_selector.custom_minimum_size = Vector2(145,36)
	facing_selector.add_item("朝右 · 独立素材"); facing_selector.add_item("朝左 · 独立素材")
	selectors.add_child(facing_selector); facing_selector.item_selected.connect(_select_facing)
	var note = Label.new(); note.text = "平面旋转，不支持改变俯视角度"; note.add_theme_font_size_override("font_size",15); note.modulate = Color("bdd2dd"); selectors.add_child(note)
	var grid = GridContainer.new(); grid.columns = 4; grid.add_theme_constant_override("h_separation",18); column.add_child(grid)
	_field(grid,"x","接地点 X（源图像素）",-512,3200,1,"px")
	_field(grid,"y","接地点 Y（源图像素）",-256,1408,1,"px")
	_field(grid,"scale_percent","统一缩放（100% = 原图）",1,200,0.1,"%")
	_field(grid,"rotation_degrees","平面旋转（绕轮胎接地点）",-180,180,0.1,"°")
	var actions = HBoxContainer.new(); actions.add_theme_constant_override("separation",12); column.add_child(actions)
	save_button = Button.new(); save_button.text = "保存调整并应用"; save_button.custom_minimum_size = Vector2(190,38); save_button.pressed.connect(save_adjustments); actions.add_child(save_button)
	for item in [["恢复默认",reset_adjustments],["保存截图",save_capture],["重新读取素材",_render_vehicle]]:
		var button = Button.new(); button.text = item[0]; button.custom_minimum_size = Vector2(130,38); button.pressed.connect(item[1]); actions.add_child(button)
	var keys = Label.new(); keys.text = "A / D 预览视差 · Ctrl+S 保存 · P 截图"; keys.add_theme_font_size_override("font_size",15); actions.add_child(keys)
	asset_status = Label.new(); asset_status.add_theme_font_size_override("font_size",15); column.add_child(asset_status)
	status = Label.new(); status.add_theme_font_size_override("font_size",15); status.text = "当前为预览初值。亲手调整满意后，点击保存即确认此场景、此车型。"; column.add_child(status)

func _field(parent: GridContainer, key: String, label: String, low: float, high: float, step: float, suffix: String) -> void:
	var group = VBoxContainer.new(); group.size_flags_horizontal = Control.SIZE_EXPAND_FILL; parent.add_child(group)
	var title = Label.new(); title.text = label; title.add_theme_font_size_override("font_size",15); group.add_child(title)
	var row = HBoxContainer.new(); group.add_child(row)
	var slider = HSlider.new(); slider.min_value = low; slider.max_value = high; slider.step = step; slider.custom_minimum_size = Vector2(155,30); slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(slider)
	var number = SpinBox.new(); number.min_value = low; number.max_value = high; number.step = step; number.suffix = suffix; number.custom_minimum_size = Vector2(120,30); number.update_on_text_changed = false; row.add_child(number)
	fields[key] = number; sliders[key] = slider
	slider.value_changed.connect(func(value):
		if syncing: return
		number.set_value_no_signal(value); number.get_line_edit().text = str(value); _change(key,value))
	number.value_changed.connect(func(value):
		if syncing: return
		slider.set_value_no_signal(value); _change(key,value))

func _key() -> String:
	return current_scene+"/"+current_vehicle

func _commit_fields() -> void:
	if current.is_empty(): return
	var before = [float(current.position[0]),float(current.position[1]),float(current.scale_percent),float(current.rotation_degrees)]
	syncing = true
	for number in fields.values(): number.apply()
	current.position = [fields.x.value,fields.y.value]
	current.scale_percent = fields.scale_percent.value; current.rotation_degrees = fields.rotation_degrees.value
	var after = [float(current.position[0]),float(current.position[1]),float(current.scale_percent),float(current.rotation_degrees)]
	if before != after: current.user_confirmed = false
	for key in fields: sliders[key].set_value_no_signal(fields[key].value)
	syncing = false

func _cache_current() -> void:
	if current.is_empty(): return
	_commit_fields(); drafts[_key()] = current.duplicate(true)

func _select_scene(index: int) -> void:
	_cache_current(); current_scene = SCENES[index]; camera_x = 0
	backdrop.display(current_scene,[]); _load_current()

func _select_vehicle(index: int) -> void:
	_cache_current(); current_vehicle = LAYOUT.VEHICLE_IDS[index]; _load_current()

func _select_facing(index: int) -> void:
	if syncing or current.is_empty(): return
	_commit_fields(); current.facing = "right" if index == 0 else "left"; current.user_confirmed = false
	drafts[_key()] = current.duplicate(true); _render_vehicle()

func _load_current() -> void:
	current = drafts.get(_key(),{}).duplicate(true)
	if current.is_empty(): current = LAYOUT.read_record(current_scene,current_vehicle)
	if not current.is_empty():
		var saved_size = Vector2(float(current.source_size[0]),float(current.source_size[1]))
		if not saved_size.is_equal_approx(backdrop.source_size): current = {}
	if current.is_empty(): current = LAYOUT.defaults(current_scene,current_vehicle,backdrop.source_size)
	if current.get("user_confirmed",false):
		var art = RENDERER.find_art(current_vehicle,str(current.facing),false)
		if not RENDERER.asset_matches_confirmation(current,art): current.user_confirmed = false
	_sync_fields(); _render_vehicle()
	status.text = "已读取此场景、此车型的保存记录。调整后再次保存才会替换。" if current.get("user_confirmed",false) else "当前为未确认预览。亲手调整满意后，点击保存即确认此场景、此车型。"

func _sync_fields() -> void:
	syncing = true
	var values = current.duplicate(true); values.x = current.position[0]; values.y = current.position[1]
	for key in fields:
		fields[key].set_value_no_signal(float(values[key])); sliders[key].set_value_no_signal(float(values[key]))
		fields[key].get_line_edit().text = str(values[key])
	facing_selector.select(0 if current.facing == "right" else 1)
	syncing = false

func _change(key: String, value: float) -> void:
	if current.is_empty(): return
	if key == "x": current.position[0] = value
	elif key == "y": current.position[1] = value
	else: current[key] = value
	current.user_confirmed = false; drafts[_key()] = current.duplicate(true)
	_render_vehicle(); status.text = "调整仅在当前预览中生效；保存调整并应用后，正式场景读取此记录。"

func _render_vehicle() -> void:
	displayed_art.clear()
	if current.is_empty() or not is_instance_valid(backdrop.vehicle_root): return
	for child in backdrop.vehicle_root.get_children():
		if child.get_meta("side_vehicle_2d",false): backdrop.vehicle_root.remove_child(child); child.queue_free()
	var art = RENDERER.find_art(current_vehicle,str(current.facing),true)
	var node = RENDERER.create(current,float(backdrop.padding),true)
	if node != null: backdrop.vehicle_root.add_child(node)
	var reference = art.is_empty() or art.get("reference_only",true)
	save_button.disabled = reference or node == null
	if not save_button.disabled:
		displayed_art = {"asset_path":art.path,"asset_sha256":FileAccess.get_sha256(str(art.path)),
			"asset_ground_y":art.ground_y,"asset_wheel_x":art.get("wheel_x",[]).duplicate()}
	if art.is_empty(): asset_status.text = "素材未就绪：此车型/方向暂不能显示或保存。"
	elif reference: asset_status.text = "REFERENCE 参考预览：暂用旧素材，禁止保存为正式参数；新2D素材到位后点「重新读取素材」。"
	else: asset_status.text = "新2D素材：%s · %s · 原图 %d × %d · 每个场景独立保存" % [current_vehicle,current.facing,int(art["size"][0]),int(art["size"][1])]
	asset_status.modulate = Color("f1c77c") if reference else Color("bbddce")

func save_adjustments() -> void:
	_commit_fields()
	var art = RENDERER.find_art(current_vehicle,str(current.facing),false)
	if art.is_empty(): status.text = "保存失败：新2D素材尚未就绪。旧素材仅供参考。"; return
	# Ctrl+S must obey the same asset gate as the button. If artwork arrives or
	# changes while this window is open, first show it for the user's review.
	if save_button.disabled or not RENDERER.asset_matches_confirmation(displayed_art,art):
		status.text = "素材尚未在当前窗口确认：请点「重新读取素材」，看过当前素材后再保存。"
		return
	var result = LAYOUT.save_confirmed(current,art)
	if result != OK: status.text = "保存失败："+error_string(result); return
	current = LAYOUT.read_record(current_scene,current_vehicle); drafts[_key()] = current.duplicate(true)
	_render_vehicle()
	status.text = "已确认并保存：%s / %s；正式场景下次重建时应用。" % [current_scene,current_vehicle]
	print("SIDE_2D_PLACEMENT_SAVED ",LAYOUT.path_for(current_scene,current_vehicle))

func reset_adjustments() -> void:
	current = LAYOUT.defaults(current_scene,current_vehicle,backdrop.source_size); drafts[_key()] = current.duplicate(true)
	_sync_fields(); _render_vehicle()
	status.text = "预览已恢复初始值；已保存记录仍保留，点击保存才会替换此项。"

func save_capture() -> void:
	_commit_fields(); _render_vehicle()
	await RenderingServer.frame_post_draw
	var directory = "res://.docs/美术/2D车辆手动摆放_20261017"
	var result = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var path = directory.path_join("%s_%s_%s_%d.png" % [current_scene,current_vehicle,current.facing,Time.get_ticks_msec()])
	if result == OK: result = get_viewport().get_texture().get_image().save_png(path)
	status.text = "截图已保存："+path.get_file() if result == OK else "截图失败："+error_string(result)

func _layout() -> void:
	if not is_instance_valid(dock): return
	var screen = get_viewport_rect().size
	dock.size.x = maxf(1160,screen.x-32)
	var height = maxf(225,dock.get_combined_minimum_size().y)
	dock.position = Vector2(16,screen.y-height-12); dock.size.y = height
	var available = Vector2(screen.x,maxf(1,screen.y-height-24))
	var factor = minf(available.x/DESIGN.x,available.y/DESIGN.y)
	preview.scale = Vector2.ONE*factor; preview.position = (available-DESIGN*factor)*0.5

func _process(delta: float) -> void:
	if get_viewport().gui_get_focus_owner() is LineEdit: return
	var direction = Input.get_axis("move_left","move_right")
	if direction != 0:
		camera_x = clampf(camera_x+direction*delta*35,-24,24); backdrop.set_camera(camera_x)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.ctrl_pressed and event.keycode == KEY_S:
		save_adjustments(); get_viewport().set_input_as_handled(); return
	if get_viewport().gui_get_focus_owner() is LineEdit: return
	if event.keycode == KEY_P: save_capture()
