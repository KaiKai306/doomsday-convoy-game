extends Control
const STAGE = preload("res://src/showcase/vehicle_stage_3d.gd")
const ART = preload("res://scenes/gas_station_parallax.tscn")
const SETTINGS_PATH = "res://data/showcase_vehicle_layout.json"
const DEFAULT_SCALE = 50.0
var art: Node2D
var stage: Node2D
var dock: PanelContainer
var status: Label
var studio := false
var camera_x := 0.0
var capturing := false
var output_dir := "res://.docs/美术/加油站3D车辆样板_20261016"
var toggles: Dictionary = {}
var rotation_slider: HSlider
var scale_slider: HSlider
var elevation_slider: HSlider
var adjustment_controls: Array[Control] = []
var comparison_button: Button
var capture_errors := 0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	RenderingServer.set_default_clear_color(Color("#080e16"))
	art = ART.instantiate(); art.auto_preview = false; add_child(art)
	art.set_process(false); art.set_process_unhandled_input(false)
	stage = STAGE.new(); stage.name = "Vehicle3DStage"
	art.get_node("World/Mid").add_child(stage); stage.position = Vector2(1980,935)
	stage.scale = Vector2.ONE * 0.5
	art.get_node("World/Near").z_index = 20
	_ui()
	if not "--showcase-capture" in OS.get_cmdline_user_args(): _load_adjustments()
	DisplayServer.window_set_title("加油站车辆调试 · 角度与大小")
	get_viewport().size_changed.connect(_layout); _layout()
	call_deferred("_settle_layout")
	if "--showcase-capture" in OS.get_cmdline_user_args():
		capturing = true; call_deferred("capture_suite")

func _settle_layout() -> void:
	# FlowContainer computes its wrapping height after receiving its width.
	await get_tree().process_frame; await get_tree().process_frame
	_layout()

func _ui() -> void:
	var theme_value := Theme.new(); theme_value.default_font_size = 16
	if FileAccess.file_exists("C:/Windows/Fonts/msyh.ttc"):
		var font := SystemFont.new(); font.font_names = PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei"])
		theme_value.default_font = font
	theme = theme_value
	var header := MarginContainer.new(); header.position = Vector2(34,24); add_child(header)
	var title_col := VBoxContainer.new(); header.add_child(title_col)
	var eyebrow := Label.new(); eyebrow.text = "末日车队  /  车辆与环境"; eyebrow.add_theme_font_size_override("font_size",15)
	eyebrow.modulate = Color("#a6c2d5"); title_col.add_child(eyebrow)
	var title := Label.new(); title.text = "加油站 · 车辆调试"; title.add_theme_font_size_override("font_size",30); title_col.add_child(title)
	var note := Label.new(); note.text = "拖动滑杆或输入数值，实时调整车辆；满意后点击「保存调整」。"; note.modulate = Color("#c1cbd0"); title_col.add_child(note)
	dock = PanelContainer.new(); add_child(dock)
	var panel := StyleBoxFlat.new(); panel.bg_color = Color(0.025,0.047,0.065,0.96)
	panel.border_color = Color("#345064"); panel.set_border_width_all(1); panel.set_corner_radius_all(12)
	panel.content_margin_left = 20; panel.content_margin_right = 20; panel.content_margin_top = 14; panel.content_margin_bottom = 14
	dock.add_theme_stylebox_override("panel",panel)
	var column := VBoxContainer.new(); column.add_theme_constant_override("separation",9); dock.add_child(column)
	var row := HFlowContainer.new(); row.add_theme_constant_override("h_separation",14); row.add_theme_constant_override("v_separation",4); column.add_child(row)
	var label := Label.new(); label.text = "车辆改装"; label.custom_minimum_size.x = 88; row.add_child(label)
	_toggle(row,"侧面装甲 + 前护杠","armor")
	_toggle(row,"车尾补给箱","cargo")
	_toggle(row,"车顶射灯","lamps")
	var separator := VSeparator.new(); row.add_child(separator)
	var warm_toggle := CheckButton.new(); warm_toggle.text = "站棚暖光"; warm_toggle.button_pressed = true
	warm_toggle.toggled.connect(func(value: bool): stage.set_warm(value)); row.add_child(warm_toggle)
	toggles.warm = warm_toggle
	var shadow_toggle := CheckButton.new(); shadow_toggle.text = "地面投影"; shadow_toggle.button_pressed = true
	shadow_toggle.toggled.connect(func(value: bool): stage.set_shadows(value)); row.add_child(shadow_toggle)
	toggles.shadows = shadow_toggle
	comparison_button = Button.new(); comparison_button.text = "查看中性光对照"
	comparison_button.pressed.connect(_toggle_comparison)
	row.add_child(comparison_button)
	var adjustments := HFlowContainer.new(); adjustments.add_theme_constant_override("h_separation",20); adjustments.add_theme_constant_override("v_separation",8); column.add_child(adjustments)
	rotation_slider = _adjustment(adjustments,"车身旋转",-180,180,1,0,"°")
	rotation_slider.value_changed.connect(func(value: float): stage.set_angle(value))
	scale_slider = _adjustment(adjustments,"车辆大小",10,200,1,DEFAULT_SCALE,"%")
	scale_slider.value_changed.connect(func(value: float): stage.scale = Vector2.ONE * value / 100.0)
	elevation_slider = _adjustment(adjustments,"俯视角度",5,45,0.1,stage.view_elevation,"°")
	elevation_slider.value_changed.connect(func(value: float): stage.set_view_elevation(value))
	var actions := HFlowContainer.new(); actions.add_theme_constant_override("h_separation",12); column.add_child(actions)
	for entry in [["保存调整",_save_adjustments],["恢复默认",_reset_adjustments],["保存截图",func(): save_capture("manual")]]:
		var button := Button.new(); button.text = entry[0]; button.custom_minimum_size = Vector2(108,34)
		button.pressed.connect(entry[1]); actions.add_child(button); adjustment_controls.append(button)
	status = Label.new(); status.text = "A / D 平移视差 · R 恢复默认 · Ctrl+S 保存调整 · P 截图"
	status.modulate = Color("#9ab3c2"); status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(status)

func _adjustment(row: Container, title: String, minimum: float, maximum: float, increment: float, initial: float, suffix: String) -> HSlider:
	var group := HBoxContainer.new(); group.custom_minimum_size = Vector2(472,34); group.add_theme_constant_override("separation",10); row.add_child(group)
	var label := Label.new(); label.text = title; label.custom_minimum_size.x = 76; group.add_child(label)
	var slider := HSlider.new(); slider.min_value = minimum; slider.max_value = maximum; slider.step = increment; slider.value = initial
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL; slider.custom_minimum_size.x = 240; group.add_child(slider)
	var number := SpinBox.new(); number.min_value = minimum; number.max_value = maximum; number.step = increment; number.value = initial; number.suffix = suffix
	number.custom_minimum_size.x = 126; number.update_on_text_changed = false; group.add_child(number)
	slider.value_changed.connect(func(value: float): number.set_value_no_signal(value))
	number.value_changed.connect(func(value: float): slider.value = value)
	adjustment_controls.append(slider); adjustment_controls.append(number)
	return slider

func _reset_adjustments() -> void:
	rotation_slider.value = 0; scale_slider.value = DEFAULT_SCALE; elevation_slider.value = STAGE.DEFAULT_ELEVATION
	camera_x = 0; art.camera_x = 0; art._apply_scroll()
	status.text = "已恢复默认：旋转 0° · 大小 50%% · 俯视 %.1f°；点击保存可保留。" % STAGE.DEFAULT_ELEVATION

func _save_adjustments() -> void:
	# Commit a SpinBox edit even when Save is clicked before Enter.
	for control in adjustment_controls:
		if control is SpinBox: control.apply()
	var file := FileAccess.open(SETTINGS_PATH,FileAccess.WRITE)
	if file == null:
		status.text = "保存失败：%s" % error_string(FileAccess.get_open_error()); return
	file.store_string(JSON.stringify({"rotation_degrees":rotation_slider.value,"scale_percent":scale_slider.value,"view_elevation_degrees":elevation_slider.value},"\t")); file.close()
	status.text = "已保存：旋转 %.0f° · 大小 %.0f%% · 俯视 %.1f°；下次打开自动恢复。" % [rotation_slider.value,scale_slider.value,elevation_slider.value]

func _load_adjustments() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH): return
	var saved = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
	if not saved is Dictionary: return
	if saved.get("rotation_degrees") is float or saved.get("rotation_degrees") is int: rotation_slider.value = saved.rotation_degrees
	if saved.get("scale_percent") is float or saved.get("scale_percent") is int: scale_slider.value = saved.scale_percent
	if saved.get("view_elevation_degrees") is float or saved.get("view_elevation_degrees") is int: elevation_slider.value = saved.view_elevation_degrees
	status.text = "已载入上次保存的车辆角度和大小。"

func _toggle(row: Container, title: String, module: String) -> void:
	var button := CheckButton.new(); button.text = title; button.button_pressed = true
	button.toggled.connect(func(value: bool): stage.set_module(module,value)); row.add_child(button)
	toggles[module] = button

func _toggle_comparison() -> void:
	studio = not studio; stage.set_studio(studio)
	comparison_button.text = "恢复场景光照" if studio else "查看中性光对照"

func _layout() -> void:
	if not is_instance_valid(dock): return
	var visible_size := get_viewport_rect().size
	dock.size.x = visible_size.x-56
	var dock_height := maxf(160.0,dock.get_combined_minimum_size().y) + 28.0
	dock.position = Vector2(28,visible_size.y-dock_height); dock.size.y = dock_height-28
	# Reserve the bottom dock; retain the complete 21:9 composition above it.
	var available := Vector2(visible_size.x,visible_size.y-dock_height-12)
	var factor := minf(available.x/2688.0,available.y/1152.0)
	art.world.scale = Vector2.ONE*factor
	art.world.position = Vector2((available.x-2688*factor)/2.0,maxf(0.0,(available.y-1152*factor)/2.0))
	art._apply_scroll()

func _process(delta: float) -> void:
	if capturing: return
	if get_viewport().gui_get_focus_owner() is LineEdit: return
	var direction := Input.get_axis("move_left","move_right")
	if direction != 0:
		camera_x = clampf(camera_x+direction*delta*35,-25,25)
		art.camera_x = camera_x; art._apply_scroll()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.ctrl_pressed and event.keycode == KEY_S:
		_save_adjustments(); get_viewport().set_input_as_handled(); return
	if get_viewport().gui_get_focus_owner() is LineEdit: return
	if event.keycode == KEY_R:
		_reset_adjustments()
	if event.keycode == KEY_P: save_capture("manual")
	if event.keycode == KEY_ESCAPE: get_tree().quit()

func save_capture(tag: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	var file := output_dir.path_join(tag+".png")
	var result := get_viewport().get_texture().get_image().save_png(file)
	if result != OK: capture_errors += 1; push_error("Cannot save " + file)
	print("SHOWCASE_CAPTURE ",file)

func capture_suite() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Actual GPU rendering required"); get_tree().quit(1); return
	await get_tree().process_frame; await get_tree().process_frame
	if not stage.ready_ok: get_tree().quit(2); return
	await get_tree().create_timer(1.0).timeout
	var results: Array = []
	await save_capture("01_加油站_完整改装")
	results.append(stage.get_snapshot())
	for module in ["armor","cargo","lamps"]: toggles[module].button_pressed = false
	await get_tree().process_frame; await get_tree().process_frame
	await save_capture("02_加油站_基础车体"); results.append(stage.get_snapshot())
	for module in ["armor","cargo","lamps"]: toggles[module].button_pressed = true
	comparison_button.pressed.emit()
	await get_tree().process_frame; await get_tree().process_frame
	await save_capture("03_中性光对照"); results.append(stage.get_snapshot())
	# Changing the warm-light request cannot contaminate the neutral comparison.
	toggles.warm.button_pressed = false; toggles.warm.button_pressed = true
	if stage.warm.visible: capture_errors += 1; push_error("Neutral lighting state was contaminated")
	comparison_button.pressed.emit(); rotation_slider.value = 115
	await get_tree().process_frame; await get_tree().process_frame
	await save_capture("04_后侧改装"); results.append(stage.get_snapshot())
	var reset := InputEventKey.new(); reset.keycode = KEY_R; reset.pressed = true
	_unhandled_key_input(reset)
	if stage.angle != 0 or rotation_slider.value != 0: capture_errors += 1; push_error("Reset failed")
	for offset in [-25,25]:
		art.camera_x = offset; art._apply_scroll()
		await get_tree().process_frame; await get_tree().process_frame
		await save_capture("05_视差_%s" % offset)
	art.camera_x = 0; art._apply_scroll()
	for module in ["armor","cargo","lamps"]:
		toggles[module].button_pressed = false
		await get_tree().process_frame; await get_tree().process_frame
		await save_capture("06_单项关闭_"+module); results.append(stage.get_snapshot())
		toggles[module].button_pressed = true
	toggles.warm.button_pressed = false
	await get_tree().process_frame; await get_tree().process_frame
	await save_capture("07_关闭站棚暖光"); results.append(stage.get_snapshot())
	toggles.warm.button_pressed = true; toggles.shadows.button_pressed = false
	await get_tree().process_frame; await get_tree().process_frame
	await save_capture("08_关闭地面投影"); results.append(stage.get_snapshot())
	toggles.shadows.button_pressed = true
	# Save render passes separately to verify alpha and true geometry-cast shadows.
	await RenderingServer.frame_post_draw
	stage.viewport.get_texture().get_image().save_png(output_dir.path_join("vehicle_pass.png"))
	stage.shadow_viewport.get_texture().get_image().save_png(output_dir.path_join("shadow_pass.png"))
	# Check the project's default 1280x720 size through the same layout path.
	get_window().size = Vector2i(1280,720)
	await get_tree().process_frame; await get_tree().process_frame; _layout()
	await get_tree().process_frame; await get_tree().process_frame
	await save_capture("09_默认尺寸1280x720")
	for button in toggles.values() + adjustment_controls:
		var bounds: Rect2 = button.get_global_rect()
		if bounds.end.x > size.x or bounds.end.y > size.y: capture_errors += 1; push_error("Controls outside viewport")
	var file := FileAccess.open(output_dir.path_join("capture_states.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"states":results,"errors":capture_errors,"renderer":RenderingServer.get_video_adapter_name()},"\t")); file.close()
	print("SHOWCASE_CAPTURE_SUITE_OK ",results.size()," states, errors=",capture_errors)
	get_tree().quit(capture_errors)
