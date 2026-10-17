extends Window
## Separate controls leave the actual management-page composition unobstructed.
const PREVIEW = preload("res://src/ui/garage_vehicle_preview.gd")
var management
var fields: Dictionary = {}
var sliders: Dictionary = {}
var status: Label
var output_dir = "res://.docs/美术/车辆管理3D调试_20261016"

func _ready() -> void:
	title = "车辆管理页 · 3D展示布局"
	size = Vector2i(470,750); min_size = Vector2i(450,720)
	theme = ConvoyTheme.create()
	close_requested.connect(hide)
	var background = ColorRect.new(); background.color = Color("0c1721"); background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(background)
	var margin = MarginContainer.new(); margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",20); margin.add_theme_constant_override("margin_right",20); margin.add_theme_constant_override("margin_top",18); margin.add_theme_constant_override("margin_bottom",18); add_child(margin)
	var column = VBoxContainer.new(); column.add_theme_constant_override("separation",6); margin.add_child(column)
	var heading = Label.new(); heading.text = "车辆3D展示布局"; heading.add_theme_font_size_override("font_size",25); column.add_child(heading)
	var note = Label.new(); note.text = "参数用于本页全部车型，车身角度为自旋转起始角。\n打开面板时暂停旋转，关闭面板后继续。"; note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; note.add_theme_font_size_override("font_size",15); column.add_child(note)
	_field(column,"x","位置 X",44,1308,1,"px")
	_field(column,"y","位置 Y",337,584,1,"px")
	_field(column,"rotation_degrees","车身旋转",-180,180,1,"°")
	_field(column,"scale_percent","车辆大小",10,85,1,"%")
	_field(column,"view_elevation_degrees","俯视角度",5,45,0.1,"°")
	var actions = HBoxContainer.new(); actions.add_theme_constant_override("separation",10); column.add_child(actions)
	for item in [["保存调整",save_adjustments],["恢复默认",reset_adjustments],["保存截图",save_capture]]:
		var button = Button.new(); button.text = item[0]; button.custom_minimum_size.y = 42; button.size_flags_horizontal = Control.SIZE_EXPAND_FILL; button.pressed.connect(item[1]); actions.add_child(button)
	var back = Button.new(); back.text = "返回车辆页"; back.custom_minimum_size.y = 38; back.pressed.connect(func(): management._go("equipment")); column.add_child(back)
	status = Label.new(); status.text = "初始参数待你调整。\n满意后保存，并告诉我「就这样」。\nF6 显示 / 隐藏此面板；Ctrl+S 保存。"; status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; status.add_theme_font_size_override("font_size",15); column.add_child(status)
	_read_fields()
	visibility_changed.connect(_sync_rotation); _sync_rotation()
	if is_instance_valid(management.vehicle_preview) and management.vehicle_preview.saved_by_user: status.text = "已读取此页面上次保存的参数，可继续调整。"

func _sync_rotation() -> void:
	if is_instance_valid(management.vehicle_preview): management.vehicle_preview.manual_adjustment = visible

func _field(column: VBoxContainer,key: String,label: String,minimum: float,maximum: float,step: float,suffix: String) -> void:
	var title_label = Label.new(); title_label.text = label; title_label.add_theme_font_size_override("font_size",17); column.add_child(title_label)
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation",12); column.add_child(row)
	var slider = HSlider.new(); slider.min_value = minimum; slider.max_value = maximum; slider.step = step; slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL; slider.custom_minimum_size = Vector2(220,32); row.add_child(slider)
	var number = SpinBox.new(); number.min_value = minimum; number.max_value = maximum; number.step = step; number.suffix = suffix; number.custom_minimum_size = Vector2(145,32); number.update_on_text_changed = false; row.add_child(number)
	fields[key] = number; sliders[key] = slider
	slider.value_changed.connect(func(value): number.set_value_no_signal(value); number.get_line_edit().text = str(value); _adjust(key,value))
	number.value_changed.connect(func(value): slider.set_value_no_signal(value); _adjust(key,value))

func _adjust(key: String,value: float) -> void:
	if is_instance_valid(management.vehicle_preview): management.vehicle_preview.set_adjustment(key,value)

func _read_fields() -> void:
	if not is_instance_valid(management.vehicle_preview): return
	var values: Dictionary = management.vehicle_preview.adjustment.duplicate(true)
	values.x = values.position[0]; values.y = values.position[1]
	for key in fields:
		fields[key].set_value_no_signal(values[key]); sliders[key].set_value_no_signal(values[key])
		fields[key].get_line_edit().text = str(values[key])

func save_adjustments() -> void:
	# Applying pending LineEdit contents also works when Save is clicked before Enter.
	for number in fields.values(): number.apply()
	if not is_instance_valid(management.vehicle_preview): status.text = "请先返回车辆页，再保存。"; return
	var result = management.vehicle_preview.save_adjustments()
	status.text = "已保存此页面的展示参数。\n确认当前效果后告诉我「就这样」。" if result == OK else "保存失败："+error_string(result)

func reset_adjustments() -> void:
	if not is_instance_valid(management.vehicle_preview): return
	management.vehicle_preview.reset_adjustments(); _read_fields()
	status.text = "已恢复本页初始值；尚未覆盖保存文件。"

func save_capture() -> void:
	await RenderingServer.frame_post_draw
	var result = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	var path = output_dir.path_join("用户调试_%d.png" % Time.get_unix_time_from_system())
	if result == OK: result = get_tree().root.get_texture().get_image().save_png(path)
	status.text = "已保存车辆页截图：\n"+path.get_file() if result == OK else "截图失败："+error_string(result)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.ctrl_pressed and event.keycode == KEY_S:
		save_adjustments(); set_input_as_handled()
