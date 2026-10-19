extends Node
## Disposable gameplay session. The normal menu and gameplay instance remain suspended.
signal exit_requested
const STATE = preload("res://src/developer/developer_state.gd")
const SAVES = preload("res://src/game/save.gd")
const MODELS = preload("res://src/showcase/vehicle_preview_models.gd")
const MOBILE = preload("res://src/ui/mobile_layout.gd")
const SAVE_DIRECTORY = "user://developer_saves"
const REPORT_DIRECTORY = "user://developer_reports"
var presets = STATE.new()
var host
var layer: CanvasLayer
var shade: ColorRect
var panel: PanelContainer
var badge: Button
var tabs: TabContainer
var status: Label
var summary: Label
var fields: Dictionary = {}
var audit: Array = []
var busy = false
var panel_open = true
var vehicle_editor
var selected_scene = ""
var guides = false
var freeze_parallax = false
var elapsed = 0.0
var save_directory = SAVE_DIRECTORY

func start(payload: Dictionary = {}) -> void:
	host = load("res://scenes/release_game.tscn").instantiate()
	host.save_system = SAVES.new(save_directory); host.auto_save_enabled = false
	add_child(host); host.activate_music(); host.setup(null,payload)
	host.auto_save_enabled = true
	host.return_to_menu.connect(func(): exit_requested.emit())
	layer = CanvasLayer.new(); layer.layer = 100; add_child(layer)
	_build()
	get_viewport().size_changed.connect(_fit); _fit()
	await _settle()
	_set_panel(true)
	_note("已进入独立测试会话，F8 收起 / 打开面板。")

func _build() -> void:
	var root = Control.new(); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.mouse_filter = Control.MOUSE_FILTER_IGNORE; layer.add_child(root)
	root.theme = ConvoyTheme.create()
	shade = ColorRect.new(); shade.color = Color(0.005,0.012,0.02,0.82); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.add_child(shade)
	panel = PanelContainer.new(); panel.size = Vector2(1180,660); root.add_child(panel)
	panel.minimum_size_changed.connect(func(): call_deferred("_fit"))
	var style = StyleBoxFlat.new(); style.bg_color = Color("101c28"); style.border_color = Color("aa8156"); style.set_border_width_all(1); style.set_corner_radius_all(10); style.content_margin_left = 22; style.content_margin_right = 22; style.content_margin_top = 16; style.content_margin_bottom = 16; panel.add_theme_stylebox_override("panel",style)
	var column = VBoxContainer.new(); column.add_theme_constant_override("separation",10); panel.add_child(column)
	_label(column,"开发者模式",29)
	summary = _label(column,"正在载入测试会话…",16)
	tabs = TabContainer.new(); tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL; column.add_child(tabs)
	_story_tab(_tab("剧情与流程"))
	_resources_tab(_tab("资源与车队"))
	_art_tab(_tab("场景与美术"))
	_tools_tab(_tab("存档与排错"))
	status = _label(column,"",16); status.custom_minimum_size.y = 44; status.max_lines_visible = 2
	var footer = _row(column)
	_button(footer,"收起面板 · F8",func(): toggle_panel(),"hide_panel")
	_button(footer,"退出开发模式，返回原进度",func(): if not busy: exit_requested.emit(),"exit_developer")
	badge = Button.new(); badge.text = "开发模式 · 测试存档  |  F8 面板"; badge.custom_minimum_size = Vector2(315,36); root.add_child(badge); badge.pressed.connect(toggle_panel)

func _fit() -> void:
	if not is_instance_valid(panel): return
	var safe = MOBILE.safe_rect(host)
	var design = Vector2(maxf(1180,panel.get_combined_minimum_size().x),maxf(660,panel.get_combined_minimum_size().y))
	var factor = minf(1.0,minf(safe.size.x/design.x,safe.size.y/design.y))
	panel.size = design; panel.scale = Vector2.ONE*factor; panel.position = safe.position+(safe.size-design*factor)*0.5
	badge.position = Vector2(maxf(safe.position.x,safe.get_center().x-157.5),safe.position.y+4)

func _tab(title: String) -> VBoxContainer:
	var scroll = ScrollContainer.new(); scroll.name = title; scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; tabs.add_child(scroll)
	var box = VBoxContainer.new(); box.size_flags_horizontal = Control.SIZE_EXPAND_FILL; box.add_theme_constant_override("separation",12); scroll.add_child(box)
	return box

func _label(parent: Node,text: String,font_size: int = 18) -> Label:
	var label = Label.new(); label.text = text; label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; label.add_theme_font_size_override("font_size",font_size); parent.add_child(label); return label

func _row(parent: Node) -> HBoxContainer:
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation",12); parent.add_child(row); return row

func _button(parent: Node,text: String,callback: Callable,id: String = "") -> Button:
	var button = Button.new(); button.text = text; button.custom_minimum_size = Vector2(150,42); button.size_flags_horizontal = Control.SIZE_EXPAND_FILL; button.set_meta("developer_action",id); button.pressed.connect(func(): if not busy: callback.call()); parent.add_child(button); return button

func _picker(parent: Node,key: String,items: Array) -> OptionButton:
	var option = OptionButton.new(); option.custom_minimum_size = Vector2(180,42); option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for item in items:
		option.add_item(str(item[1])); option.set_item_metadata(option.item_count-1,item[0])
	parent.add_child(option); fields[key] = option; return option

func _number(parent: Node,key: String,title: String,value: float,minimum: float,maximum: float,step: float = 1) -> SpinBox:
	var box = VBoxContainer.new(); box.size_flags_horizontal = Control.SIZE_EXPAND_FILL; parent.add_child(box); _label(box,title,16)
	var number = SpinBox.new(); number.min_value = minimum; number.max_value = maximum; number.step = step; number.value = value; number.custom_minimum_size = Vector2(110,40); box.add_child(number); fields[key] = number; return number

func _selected(key: String):
	return fields[key].get_selected_metadata()

func _value(key: String) -> float:
	fields[key].apply(); return fields[key].value

func _story_tab(box: VBoxContainer) -> void:
	_label(box,"载入可继续操作的剧情预设",22)
	_label(box,"标准行程支持 1–20 天；救援路线包含核查频段、南下准备与救援前置。",16)
	var row = _row(box)
	_number(row,"day","天数",1,1,20)
	_picker(row,"route",[["E09","标准行程 · 20天"],["E12","救援路线 · 至第12天"]])
	_picker(row,"phase",[["morning","晨间准备"],["route","路线选择"],["stop","停歇事务"],["camp","营地行动"],["night","夜间结算"]])
	_button(box,"载入所选天数与阶段",load_day,"load_day")
	var quick = _row(box)
	_button(quick,"救援现场预设",func(): load_preset(10,"rescue","E12"),"rescue_preset")
	var endings: Array = []
	for i in host.engine.ENDINGS.size(): endings.append(["E%02d" % (i+1),"E%02d · %s" % [i+1,host.engine.ENDINGS[i]]])
	_picker(quick,"ending",endings)
	_button(quick,"预览所选结局",func(): load_preset(1,"ending",str(_selected("ending")),true),"preview_ending")
	_label(box,"指定事件测试",22)
	var events: Array = []
	for id in host.engine.content.cards: events.append([id,id+" · "+str(host.engine.content.cards[id].title)])
	var cards = _picker(box,"event",events); cards.item_selected.connect(func(_i): _event_info())
	fields.event_info = _label(box,"",16); _event_info()
	_button(box,"进入所选事件（强制测试入口）",trigger_event,"trigger_event")
	_label(box,"强制入口跳过抽取条件，选项仍按游戏规则验证；事件条件可在上方核对。",15)

func _resources_tab(box: VBoxContainer) -> void:
	_label(box,"资源数量",22)
	var grid = GridContainer.new(); grid.columns = 4; grid.add_theme_constant_override("h_separation",12); grid.add_theme_constant_override("v_separation",8); box.add_child(grid)
	for key in host.engine.RESOURCE_NAMES: _number(grid,"resource_"+key,host.engine.RESOURCE_NAMES[key],host.engine.s.resources[key],0,10000,0.1)
	var row = _row(box)
	_button(row,"应用资源数值",apply_resources,"apply_resources")
	_button(row,"补充常用物资",refill,"refill")
	_label(box,"车队与配件",22)
	row = _row(box)
	var cars: Array = []
	for id in MODELS.NAMES: cars.append([id,id+" · "+MODELS.NAMES[id]])
	_picker(row,"vehicle",cars)
	_button(row,"添加所选车辆",add_vehicle,"add_vehicle")
	_button(row,"恢复全部车辆耐久",repair_vehicles,"repair_vehicles")
	_button(row,"获得全部配件核心",grant_modules,"grant_modules")
	_label(box,"成员状态",22)
	var members: Array = []
	for member in host.engine.s.members: members.append([member.id,member.name])
	var picker = _picker(box,"member",members); picker.item_selected.connect(func(_i): _read_member())
	row = _row(box)
	for spec in [["health","健康"],["fatigue","疲劳"],["trust","信任"],["like","好感"]]: _number(row,"member_"+spec[0],spec[1],0,0,100)
	row = _row(box)
	_button(row,"应用成员数值",apply_member,"apply_member")
	_button(row,"恢复在队成员健康与体力",heal_members,"heal_members")
	_read_member()

func _art_tab(box: VBoxContainer) -> void:
	_label(box,"场景浏览",22)
	_label(box,"进入实际场景查看背景、角色和视差。场景浏览保留当前剧情进度。",16)
	var scenes: Array = []
	for location in presets.locations(): scenes.append([location.id,location.title+" · "+location.id])
	_picker(box,"scene",scenes)
	var row = _row(box)
	_button(row,"进入所选场景",func(): show_scene(str(_selected("scene"))),"show_scene")
	_button(row,"返回当前剧情现场",clear_scene,"clear_scene")
	var check = CheckBox.new(); check.text = "显示行走路径与交互范围"; check.toggled.connect(func(on): guides = on; _sync_art()); box.add_child(check)
	check = CheckBox.new(); check.text = "固定视差镜头"; check.toggled.connect(func(on): freeze_parallax = on; _sync_art()); box.add_child(check)
	_label(box,"车辆管理页",22)
	_label(box,"沿用你已确认的布局。切换车型后可缓慢自旋转；F6 打开已有手动调试面板。",16)
	row = _row(box)
	_button(row,"打开车辆展示",open_garage,"open_garage")
	_button(row,"打开车辆布局调试 · F6",open_vehicle_editor,"vehicle_editor")
	_label(box,"位置、大小、角度由你调整；保存入口和各场景独立配置继续沿用。",15)

func _tools_tab(box: VBoxContainer) -> void:
	_label(box,"测试快照",22)
	_label(box,"快照保存到独立开发存档，可在重启游戏后恢复。",16)
	var slots: Array = []
	for slot in SAVES.new(save_directory).manual_slots(): slots.append([slot,"测试快照 "+slot.trim_prefix("slot_")])
	_picker(box,"snapshot",slots)
	var row = _row(box)
	_button(row,"保存当前快照",save_snapshot,"save_snapshot")
	_button(row,"恢复所选快照",load_snapshot,"load_snapshot")
	_button(row,"重置测试进度",reset_test,"reset_test")
	_label(box,"状态与运行记录",22)
	fields.diagnostics = RichTextLabel.new(); fields.diagnostics.custom_minimum_size.y = 150; fields.diagnostics.bbcode_enabled = false; fields.diagnostics.selection_enabled = true; box.add_child(fields.diagnostics)
	row = _row(box)
	_button(row,"刷新状态与事件标记",refresh_diagnostics,"diagnostics")
	_button(row,"导出截图与运行记录",export_report,"export_report")

func _event_info() -> void:
	if not fields.has("event_info"): return
	var card: Dictionary = host.engine.content.cards[_selected("event")]
	var history: Dictionary = host.engine.s.card_history.get(_selected("event"),{})
	fields.event_info.text = "条件："+str(card.get("eligibility","无额外抽取条件"))+"\n已处理 %d 次；最近：%s；%s" % [int(history.get("count",0)),"第%d天" % int(history.last) if int(history.get("last",-1)) > 0 else "尚未处理","本轮已关闭" if history.get("closed",false) else "本轮未关闭"]

func _read_member() -> void:
	var member: Dictionary = host.engine.person(str(_selected("member")))
	for key in ["health","fatigue","trust","like"]:
		if fields.has("member_"+key): fields["member_"+key].value = member.get(key,0)

func _read_controls() -> void:
	for key in host.engine.RESOURCE_NAMES: fields["resource_"+key].value = host.engine.s.resources[key]
	var picker: OptionButton = fields.member; var selected = _selected("member"); picker.clear()
	for member in host.engine.s.members:
		picker.add_item(member.name); picker.set_item_metadata(picker.item_count-1,member.id)
		if member.id == selected: picker.select(picker.item_count-1)
	_read_member(); _event_info(); refresh_diagnostics()

func _note(message: String) -> void:
	if is_instance_valid(status): status.text = message; status.tooltip_text = message
	audit.append({"time":Time.get_datetime_string_from_system(),"message":message})
	if audit.size() > 200: audit.pop_front()
	refresh_diagnostics()

func refresh_diagnostics() -> void:
	if not fields.has("diagnostics"): return
	var s: Dictionary = host.engine.s
	fields.diagnostics.text = "存档目录：%s\n阶段：第%d天 / %s；当前事件：%s\n规则消息：%s\n事件标记：\n%s\n最近操作：\n%s" % [ProjectSettings.globalize_path(host.save_system.save_directory),s.day,s.phase,s.daily.get("card",""),host.engine.error,JSON.stringify(s.facts,"  "),JSON.stringify(audit.slice(maxi(0,audit.size()-8)),"  ")]

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed < 0.5 or not is_instance_valid(host) or host.engine.s.is_empty(): return
	elapsed = 0
	summary.text = "测试会话  ·  第 %02d 天 / %s  ·  %d FPS  ·  独立开发存档" % [host.engine.s.day,SAVES.PHASE_NAMES.get(host.engine.s.phase,host.engine.s.phase),Engine.get_frames_per_second()]
	_sync_art()

func toggle_panel() -> void:
	if busy: return
	if is_instance_valid(vehicle_editor) and vehicle_editor.visible: vehicle_editor.hide()
	_set_panel(not panel_open)

func _set_panel(open: bool) -> void:
	panel_open = open; panel.visible = open; shade.visible = open; badge.visible = not open
	host.process_mode = Node.PROCESS_MODE_DISABLED if open else Node.PROCESS_MODE_INHERIT
	if is_instance_valid(host.side_stage) and is_instance_valid(host.side_stage.walk):
		host.side_stage.walk.lock_movement(open or host.paused or host.side_stage.mode != "explore")

func _settle() -> void:
	host.process_mode = Node.PROCESS_MODE_INHERIT
	await get_tree().process_frame
	while host.loading_screen.busy: await get_tree().process_frame
	await get_tree().process_frame; await get_tree().process_frame
	_sync_art()
	if panel_open: host.process_mode = Node.PROCESS_MODE_DISABLED

func load_day() -> void:
	load_preset(int(_value("day")),str(_selected("phase")),str(_selected("route")))

func load_preset(day: int,phase: String,route: String,ending: bool = false) -> void:
	var payload = presets.scenario(day,phase,route,ending)
	if payload.is_empty(): _note(presets.error); return
	await apply_payload(payload)
	_note("已载入%s：第%d天 · %s；前置状态随预设恢复。" % [route,host.engine.s.day,SAVES.PHASE_NAMES.get(host.engine.s.phase,host.engine.s.phase)])
	_set_panel(false)

func apply_payload(payload: Dictionary) -> bool:
	if busy: return false
	var validator = STATE.RULES.new()
	if not validator.restore(payload): _note("载入失败："+validator.error); return false
	busy = true
	if is_instance_valid(vehicle_editor): vehicle_editor.hide()
	host.process_mode = Node.PROCESS_MODE_INHERIT
	host.paused = false; host.confirmation.hide(); host.pending_command.clear()
	if is_instance_valid(host.archive_screen): host.archive_screen.hide()
	host.developer_location = str(payload.get("developer",{}).get("location",""))
	if is_instance_valid(host.side_stage):
		host.side_stage.last_phase = ""; host.side_stage.mode = "explore"; host.side_stage.forced = false; host.side_stage.encounter_seen.clear()
	if is_instance_valid(host.management_screen): host.management_screen.modal_kind = ""
	host.setup(null,payload)
	if host.developer_location != "":
		host.side_stage.last_phase = str(host.engine.s.phase); host.side_stage.forced = true; host.refresh()
	await _settle(); busy = false; _read_controls(); return true

func _changed(message: String) -> void:
	busy = true; host.process_mode = Node.PROCESS_MODE_INHERIT
	host.refresh(); await _settle(); busy = false; _read_controls(); _note(message)

func apply_resources() -> void:
	var changes: Array[String] = []
	for key in host.engine.RESOURCE_NAMES:
		var value = _value("resource_"+key)
		if not is_equal_approx(host.engine.s.resources[key],value): changes.append("%s：%s → %s" % [host.engine.RESOURCE_NAMES[key],host.engine.s.resources[key],value])
		host.engine.s.resources[key] = value
	host.engine.normalize_cargo()
	await _changed("；".join(changes) if not changes.is_empty() else "资源数值未改变。")

func refill() -> void:
	for key in {"water":80,"food":80,"fuel":100,"parts":40,"medicine":15}: host.engine.s.resources[key] = maxf(host.engine.s.resources[key],{"water":80,"food":80,"fuel":100,"parts":40,"medicine":15}[key])
	host.engine.normalize_cargo(); await _changed("已补充饮水、食物、燃料、零件和药品。")

func add_vehicle() -> void:
	if host.engine.s.vehicles.size() >= 8: _note("测试车队最多保留8辆车。可重置测试进度后重新选择。" ); return
	var id = str(_selected("vehicle")); var car: Dictionary = host.engine.vehicle(MODELS.NAMES[id],100)
	car.visual_id = id; host.engine.s.vehicles.append(car); host.engine.normalize_cargo()
	await _changed("已添加 "+id+" · "+MODELS.NAMES[id]+"。")

func repair_vehicles() -> void:
	for car in host.engine.s.vehicles: car.durability = 100; car.destroyed = false
	await _changed("全部车辆耐久已恢复至100。")

func grant_modules() -> void:
	for id in host.engine.content.modules: host.engine.s.cores[id] = maxi(1,int(host.engine.s.cores.get(id,0)))
	host.engine.normalize_cargo(); await _changed("已获得全部配件核心，可在车辆页测试安装。")

func apply_member() -> void:
	var member: Dictionary = host.engine.person(str(_selected("member")))
	for key in ["health","fatigue","trust","like"]: member[key] = _value("member_"+key)
	await _changed("已更新 "+str(member.name)+" 的健康、疲劳、信任与好感。")

func heal_members() -> void:
	for member in host.engine.people(): member.health = 100; member.fatigue = 0
	await _changed("在队成员健康已恢复至100，疲劳归零。")

func trigger_event() -> void:
	var id = str(_selected("event")); var card: Dictionary = host.engine.content.cards[id]
	var s: Dictionary = host.engine.s
	if s.ending != "": _note("请先载入一个非结局剧情预设。" ); return
	var owner = str(host.engine.speaker(id))
	if not host.engine.living(owner): owner = "captain"
	match str(card.get("pool","travel")):
		"person":
			s.phase = "morning"; s.daily.prepared = false
			if id not in s.daily.card_candidates: s.daily.card_candidates.append(id)
			s.daily.person_queue = s.daily.person_queue.filter(func(row): return row.id != id)
			host.engine._add_request(id,owner,int(s.day))
		"opportunity": s.phase = "stop"; s.daily.opportunity_card = id; s.daily.opportunity_used = false
		"camp":
			s.phase = "camp_event"; s.daily.card = id; s.daily.camp_used = false
			s.daily.camp_action = "rest"; s.daily.camp_args = {"target":owner,"role":"repair","teacher":"zhang","faction":"guild"}
		_: s.phase = "event"; s.daily.card = id
	host.developer_location = ""; host.active_card = id; host.selected_target = owner; host.view = "card"; host.paused = false
	await _changed("已进入事件 "+id+" · "+card.title+"。抽取条件已跳过，选项仍由规则验证。")
	_set_panel(false)

func show_scene(id: String) -> void:
	if preload("res://src/game/location_catalog.gd").config(id).is_empty(): _note("场景不存在。" ); return
	host.developer_location = id; host.view = "journey"; host.paused = false; host.active_card = ""
	if is_instance_valid(host.side_stage):
		host.side_stage.last_phase = str(host.engine.s.phase); host.side_stage.forced = true; host.side_stage.mode = "explore"; host.side_stage.meeting = ""
	await _changed("场景浏览："+id+"。剧情状态保持原样。")
	_set_panel(false)

func clear_scene() -> void:
	host.developer_location = ""
	if is_instance_valid(host.side_stage): host.side_stage.forced = false; host.side_stage.last_phase = ""
	await _changed("已返回当前剧情对应的现场。")
	_set_panel(false)

func _sync_art() -> void:
	if not is_instance_valid(host.side_stage) or not is_instance_valid(host.side_stage.walk): return
	host.side_stage.walk.developer_show_guides = guides
	host.side_stage.walk.developer_freeze_parallax = freeze_parallax
	if panel_open: host.side_stage.walk.lock_movement(true)
	if is_instance_valid(host.side_stage.walk.backdrop.actor_layer): host.side_stage.walk.backdrop.actor_layer.queue_redraw()

func open_garage() -> void:
	host.developer_location = ""; host.view = "equipment"; host.paused = false
	await _changed("已打开车辆展示，保留已确认布局。")
	_set_panel(false)

func open_vehicle_editor() -> void:
	await open_garage()
	if not is_instance_valid(vehicle_editor):
		vehicle_editor = load("res://src/showcase/garage_vehicle_placement.gd").new(); vehicle_editor.management = host.management_screen; add_child(vehicle_editor)
	vehicle_editor.show()

func _unhandled_key_input(event: InputEvent) -> void:
	if busy: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F6:
			if is_instance_valid(vehicle_editor) and vehicle_editor.visible: vehicle_editor.hide()
			else: open_vehicle_editor()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and panel_open:
			_set_panel(false); get_viewport().set_input_as_handled()

func snapshot_payload() -> Dictionary:
	var payload: Dictionary = host.progress_payload()
	payload.developer = {"location":host.developer_location}
	return payload

func save_snapshot() -> void:
	var slot = str(_selected("snapshot"))
	if host.save_system.save_payload(snapshot_payload(),slot,host.archive_metadata()): _note("已保存测试快照 "+slot+"。")
	else: _note("快照保存失败："+host.save_system.last_error)

func load_snapshot() -> void:
	var slot = str(_selected("snapshot")); var payload: Dictionary = host.save_system.load_from_file(slot)
	if payload.is_empty(): _note("所选测试快照为空或损坏。" ); return
	if await apply_payload(payload): _note("已恢复测试快照 "+slot+"，可继续操作。")

func reset_test() -> void:
	var rules = STATE.RULES.new(); rules.new_game(81)
	await apply_payload(rules.checkpoint()); _note("测试进度已重置到第一天，已有测试快照保留。")

func export_report() -> void:
	busy = true
	var folder = REPORT_DIRECTORY.path_join("report_%d" % Time.get_ticks_usec())
	var result = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	if result != OK: busy = false; _note("导出失败："+error_string(result)); return
	var report = {"timestamp":Time.get_datetime_string_from_system(),"fps":Engine.get_frames_per_second(),"adapter":RenderingServer.get_video_adapter_name(),"rules_error":host.engine.error,"ui_message":host.error_label.text,"audit":audit,"payload":snapshot_payload()}
	var file = FileAccess.open(folder.path_join("report.json"),FileAccess.WRITE)
	if file == null: busy = false; _note("运行记录写入失败。" ); return
	file.store_string(JSON.stringify(report,"\t")); file.close()
	var was_open = panel_open; _set_panel(false)
	if DisplayServer.get_name() != "headless":
		await get_tree().process_frame; await RenderingServer.frame_post_draw
		result = get_viewport().get_texture().get_image().save_png(folder.path_join("screen.png"))
	_set_panel(was_open); busy = false
	_note("已导出运行记录："+ProjectSettings.globalize_path(folder)+( "；截图写入失败。" if result != OK else ""))
