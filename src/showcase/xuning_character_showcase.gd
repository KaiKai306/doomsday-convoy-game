extends Control
const STAGE = preload("res://src/showcase/xuning_character_stage.gd")
var viewport: SubViewport
var stage: Node3D
var angle_slider: HSlider
var status: Label
var turn := false
var green := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new(); background.color = Color("171c24")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(background)
	var margin := MarginContainer.new(); margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","top","right","bottom"]: margin.add_theme_constant_override("margin_"+side,18)
	add_child(margin)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation",20); margin.add_child(row)
	var view := SubViewportContainer.new(); view.stretch = true
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL; view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(view)
	viewport = SubViewport.new(); viewport.size = Vector2i(850,760)
	viewport.own_world_3d = true; viewport.msaa_3d = Viewport.MSAA_4X
	view.add_child(viewport)
	stage = STAGE.new(); viewport.add_child(stage); stage.set_angle(35)
	var panel := VBoxContainer.new(); panel.custom_minimum_size.x = 280
	panel.add_theme_constant_override("separation",12); row.add_child(panel)
	_label(panel,"许宁 · 三维角色样张",24)
	_label(panel,"细心、克制、有原则的医护",16)
	var poses := OptionButton.new(); poses.name = "PoseSelector"; poses.add_item("站姿：护住药包"); poses.add_item("坐姿：整理绷带")
	panel.add_child(poses)
	poses.item_selected.connect(func(index: int): stage.set_pose("standing" if index == 0 else "seated"))
	_label(panel,"旋转观察",16)
	angle_slider = _slider(panel,-180,180,35)
	angle_slider.value_changed.connect(func(value: float): stage.set_angle(value))
	var spin := CheckButton.new(); spin.text = "自动旋转"; panel.add_child(spin)
	spin.toggled.connect(func(value: bool): turn = value)
	_label(panel,"观察俯仰",16)
	_slider(panel,-10,35,5).value_changed.connect(func(value: float): stage.elevation=value; stage.refresh_camera())
	_label(panel,"观察距离",16)
	_slider(panel,1.8,3.4,2.5).value_changed.connect(func(value: float): stage.zoom=value; stage.refresh_camera())
	var chair := CheckButton.new(); chair.name = "ChairToggle"; chair.text = "显示独立测试椅"; panel.add_child(chair)
	chair.toggled.connect(func(value: bool): stage.set_chair(value))
	var chroma := CheckButton.new(); chroma.name = "GreenToggle"; chroma.text = "绿幕背景"; panel.add_child(chroma)
	chroma.toggled.connect(func(value: bool): green=value; stage.set_green(value))
	var export_button := Button.new(); export_button.text = "导出当前角度 PNG"
	panel.add_child(export_button); export_button.pressed.connect(_export)
	status = _label(panel,"站位以脚底为基准\n坐姿座面高度：46 厘米\n椅子与人物模型分开",16)
	_label(panel,"两种静态姿势可切换\n面部和手指细节仍需验收",15)

func _label(parent: Node, text: String, font_size: int) -> Label:
	var result := Label.new(); result.text = text; result.add_theme_font_size_override("font_size",font_size)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; parent.add_child(result); return result

func _slider(parent: Node, low: float, high: float, value: float) -> HSlider:
	var result := HSlider.new(); result.min_value=low; result.max_value=high; result.step=0.1; result.value=value
	parent.add_child(result); return result

func _process(delta: float) -> void:
	if turn and angle_slider != null:
		angle_slider.value = wrapf(angle_slider.value+delta*18.0,-180.0,180.0)

func _export() -> void:
	var dir := "res://.docs/美术/许宁角色姿势样张_20261016/user_exports"
	DirAccess.make_dir_recursive_absolute(dir)
	var prefix := dir.path_join("xuning_%s_%03d" % [stage.pose,int(stage.angle)])
	var was_turning := turn
	turn = false
	var had_chair: bool = stage.chair_visible
	stage.set_chair(false); viewport.transparent_bg = true
	await get_tree().process_frame; await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image(); image.convert(Image.FORMAT_RGBA8)
	var result := image.save_png(prefix+"_alpha.png")
	var chroma := Image.create(image.get_width(),image.get_height(),false,Image.FORMAT_RGBA8)
	chroma.fill(Color(0,1,0)); chroma.blend_rect(image,Rect2i(Vector2i.ZERO,image.get_size()),Vector2i.ZERO)
	result = maxi(result,chroma.save_png(prefix+"_green.png"))
	viewport.transparent_bg = false; stage.set_chair(had_chair); turn=was_turning
	status.text = "已保存绿幕与透明两张 PNG\n位置：样张目录 user_exports" if result == OK else "保存失败，请查看目录权限"
