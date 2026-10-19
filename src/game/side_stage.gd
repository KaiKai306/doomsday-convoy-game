extends Control
## Atlas presentation over the existing command UI. All commands, validation,
## confirmations and saving remain owned by release_game and the final rules.
const WALK = preload("res://src/game/camp_walk.gd")
const PANEL = preload("res://src/ui/reference_panel.gd")
const SKIN = preload("res://src/ui/convoy_skin.gd")
const ICON = preload("res://src/ui/reference_icon.gd")
const BIOMES = preload("res://src/game/biome_catalog.gd")
const PROSE = preload("res://src/game/presentation.gd")
const MOBILE = preload("res://src/ui/mobile_layout.gd")
const RESOURCE_HUD = preload("res://src/ui/resource_hud.gd")
const TOUCH_TEXT = preload("res://src/ui/touch_rich_text.gd")
const DESIGN = Vector2(1680,720)
const TRADE_CARDS = ["R01","N-F09","N-C01","C16","C17","C18","C19","C20"]
var host
var content: Control
var walk
var overlay: Control
var mode = "explore"
var action_kind = ""
var speaker = ""
var meeting = ""
var last_phase = ""
var epoch = 0
var forced = false
var busy = false
var encounter_seen: Dictionary = {}
var current_location = ""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var black = ColorRect.new(); black.color = Color("080e15"); black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); black.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(black)
	content = Control.new(); content.size = DESIGN; content.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(content)
	resized.connect(_fit); _fit()

func _fit() -> void:
	if not is_instance_valid(content): return
	MOBILE.fit_tall(content,DESIGN,MOBILE.safe_rect(self))
	if is_instance_valid(overlay) and visible: _render()

func should_show() -> bool:
	return not host.paused and host.view in ["journey","card"] and (host.engine.s.phase in ["morning","stop","camp","camp_event"] or forced)

func presentation_location() -> String:
	if host.developer_location != "": return host.developer_location
	var s = host.engine.s
	if last_phase == str(s.phase):
		if meeting == "tent" and s.phase in ["stop","camp"]: return "camp_interior"
		if meeting == "fire" and s.phase == "camp": return BIOMES.campsite(s)
	return BIOMES.scene_for(s,"journey",host.active_card,host.scene_context)

func sync() -> void:
	if not is_instance_valid(host) or host.engine.s.is_empty(): return
	var s = host.engine.s
	visible = should_show()
	if not visible:
		if is_instance_valid(walk): walk.lock_movement(true); walk.set_process_unhandled_key_input(false)
		return
	if last_phase != str(s.phase):
		last_phase = str(s.phase); meeting = ""; action_kind = ""; speaker = ""; forced = false
		mode = "actions" if s.phase == "camp" else "explore"
	if host.view == "card" or s.phase == "camp_event":
		var id = host.active_card if host.view == "card" else str(s.daily.card)
		if s.phase == "camp_event": host.active_card = id
		var key = "%d:%s" % [s.day,id]
		mode = "encounter" if id == "R01" and not encounter_seen.has(key) else "dialogue"
	elif mode in ["dialogue","encounter"]: mode = "explore"
	var location = presentation_location()
	if host._load_location(location,sync): return
	_ensure_walk(location)
	walk.set_process_unhandled_key_input(true)
	if mode == "action": host._stage_action_controls(action_kind)
	_render()
	host._sync_music(location)

func _ensure_walk(location: String) -> void:
	var live_ids: Array = host.engine.people().map(func(m): return m.id)
	if is_instance_valid(walk) and current_location == location and walk.members.map(func(m): return m.id) == live_ids: return
	if is_instance_valid(walk): walk.get_parent().remove_child(walk); walk.queue_free()
	current_location = location
	walk = WALK.new(); walk.name = "AtlasWalk"; walk.atlas_mode = true; walk.location_id = location
	walk.members = host.engine.people().duplicate(true); walk.vehicles = host.engine.s.vehicles.duplicate(true)
	# The scene covers the complete display, independently of safe-area UI.
	add_child(walk); move_child(walk,1)
	walk.interacted.connect(open_member)
	walk.closed.connect(back)
	if BIOMES.opening_available(host.engine.s) and location in ["forest_gas_station","gas_station_interior"]:
		var inside = location == "gas_station_interior"
		# Door coordinates refer to the accepted 16:9 center; account for the
		# installed outpainting rather than anchoring the prompt to the screen.
		var center = walk.backdrop.config.get("preserved_center",[0,0,2048,1152])
		# The user's exterior reference places the captain at the left end of
		# the walk path, beside the shutter/storefront corner (center x = 155).
		var door_x = float(center[0])+(160.0 if inside else 155.0)
		walk.configure_entrance({"source_x":door_x,"label":"返回站外" if inside else "进入内屋","short_label":"离开" if inside else "进入","radius":110 if inside else 55},SKIN.feedback_for(host))
		walk.entrance_used.connect(host._toggle_opening_room)
		if inside: walk.place_player_at(door_x+80)
		elif host.scene_context.has("opening_return_x"): walk.place_player_at(float(host.scene_context.opening_return_x))

func _render() -> void:
	epoch += 1
	if is_instance_valid(overlay): content.remove_child(overlay); overlay.queue_free()
	overlay = Control.new(); overlay.name = "AtlasInterface"; overlay.size = content.size; overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE; content.add_child(overlay)
	walk.entrance_enabled = BIOMES.opening_available(host.engine.s)
	var focus = ""
	if mode == "member": focus = speaker
	elif mode == "dialogue" and host.active_card not in TRADE_CARDS: focus = str(_owner().get("id",""))
	walk.focus_member(focus)
	walk.lock_movement(mode != "explore" or host.loading_screen.busy)
	_header()
	match mode:
		"dialogue": _dialogue()
		"member": _member_dialogue()
		"encounter": _encounter()
		"actions": _actions()
		"action": _action_detail()
		"drawer": _drawer()
		"queue": _queue_panel(Vector2(1100,90),520,true)
		_: pass
	if host.error_label.text != "" and host.error_label.text != "已自动保存":
		_label(overlay,host.error_label.text,Vector2(300,679),Vector2(1080,30),17,Color("ffc47a"))
	var extra = maxf(0,content.size.y-DESIGN.y)
	for child in overlay.get_children():
		if not child is Control: continue
		if child.position.y >= 300 or child.position.y >= 90 and mode == "dialogue" and host.active_card not in TRADE_CARDS:
			child.position.y += extra
		elif child.position.y >= 90: child.position.y += extra*0.5
	SKIN.polish_tree(overlay,SKIN.feedback_for(host))
	SKIN.polish_tree(walk.content,SKIN.feedback_for(host))
	SKIN.polish_tree(walk.hud,SKIN.feedback_for(host))

func _panel(parent: Node, point: Vector2, dimensions: Vector2, blue: bool = false) -> Control:
	return SKIN.panel(parent,point,dimensions,blue)

func _label(parent: Node, text: String, point: Vector2, dimensions: Vector2, font_size: int = 20, ink: Color = Color("e5edf2")) -> Label:
	var label = Label.new(); label.text = text; label.position = point; label.size = dimensions; label.add_theme_font_size_override("font_size",font_size); label.add_theme_color_override("font_color",ink); label.mouse_filter = Control.MOUSE_FILTER_IGNORE; parent.add_child(label)
	if font_size >= 23: SKIN.title(label)
	return label

func _rich(parent: Node, text: String, point: Vector2, dimensions: Vector2, font_size: int = 18) -> RichTextLabel:
	var label = TOUCH_TEXT.new(); label.bbcode_enabled = true; label.text = text; label.position = point; label.size = dimensions; label.add_theme_font_size_override("normal_font_size",font_size); label.add_theme_color_override("default_color",SKIN.TEXT); parent.add_child(label); return label

func _style(color: Color, border: Color) -> StyleBoxFlat:
	var box = StyleBoxFlat.new(); box.bg_color = color; box.border_color = border; box.set_border_width_all(1); box.corner_detail = 1; box.set_corner_radius_all(8); box.content_margin_left = 16; box.content_margin_right = 16; box.content_margin_top = 6; box.content_margin_bottom = 6; return box

func _button(parent: Node, text: String, point: Vector2, dimensions: Vector2, callback: Callable, gold: bool = false) -> Button:
	var button = Button.new(); button.text = text; button.position = point; button.size = dimensions; button.custom_minimum_size.y = dimensions.y; button.add_theme_font_size_override("font_size",18)
	button.add_theme_stylebox_override("normal",_style(Color(0.025,0.05,0.08,0.86),Color("b49961") if gold else Color(0.65,0.75,0.83,0.55)))
	button.add_theme_stylebox_override("hover",_style(Color("24445b"),Color("93d5ff")))
	button.add_theme_stylebox_override("focus",_style(Color(0.12,0.25,0.34,0.55),Color("89d8ff")))
	button.add_theme_stylebox_override("pressed",_style(Color("684e27") if gold else Color("1b608b"),Color("ffd88e") if gold else Color("97dfff")))
	button.pressed.connect(callback); parent.add_child(button); SKIN.button(button,gold,SKIN.feedback_for(host)); return button

func _header() -> void:
	var s = host.engine.s
	var title = str(walk.backdrop.config.get("title",current_location))
	_label(overlay,"第 %d 天  ·  %s" % [s.day,title],Vector2(32,19),Vector2(700,32),22)
	var supplies = RESOURCE_HUD.new(); supplies.position = Vector2(32,53); overlay.add_child(supplies); supplies.display(s.resources)
	_button(overlay,"今日安排",Vector2(1075,20),Vector2(130,40),func(): host.view = "journey"; mode = "drawer"; host.refresh())
	_button(overlay,"车队",Vector2(1218,20),Vector2(110,40),func(): host.view = "team"; host.refresh())
	_button(overlay,"暂停",Vector2(1341,20),Vector2(110,40),host._pause)
	_button(overlay,"‹ 返回",Vector2(1464,20),Vector2(180,40),back)
	if mode != "explore": return
	var x = 500.0
	var queue = _visible_queue()
	if not queue.is_empty():
		_button(overlay,"待办事务 · %d" % queue.size(),Vector2(x,628),Vector2(180,44),func(): mode = "queue"; _render()); x += 194
	if s.phase == "camp":
		_button(overlay,"营地行动",Vector2(x,628),Vector2(160,44),func(): mode = "actions"; _render()); x += 174
	if s.phase in ["stop","camp"]:
		_button(overlay,"营帐会议" if meeting != "tent" else "返回现场",Vector2(x,628),Vector2(160,44),func(): meeting = "" if meeting == "tent" else "tent"; sync())

func open_member(id: String) -> void:
	speaker = id; host.selected_target = id
	for row in _visible_queue():
		if str(row.owner) == id: open_card(str(row.id),id); return
	mode = "member"; _render()

func open_card(id: String, owner: String = "") -> void:
	if owner != "": speaker = owner; host.selected_target = owner
	host.active_card = id; host.view = "card"; host.refresh()

func _portrait(parent: Node, id: String, point: Vector2, dimensions: Vector2) -> void:
	var key = {"captain":"captain","zhang":"mechanic","elin":"medic","ajie":"scout","sofia":"quartermaster","xuning":"xuning","chenchuan":"chenchuan","duheng":"duheng","linyue":"linyue","cenbai":"cenbai","sister":"sister"}.get(id,"")
	if key == "": return
	var picture = TextureRect.new(); picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; picture.texture = load("res://assets/ui/status_overview/%s.png" % key); picture.position = point; picture.size = dimensions; picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED; picture.clip_contents = true; picture.mouse_filter = Control.MOUSE_FILTER_IGNORE; parent.add_child(picture)
	picture.set_meta("atlas_portrait",true)

func _owner() -> Dictionary:
	for row in _visible_queue():
		if row.id == host.active_card: return host.engine.person(str(row.owner))
	return host.engine.person(speaker if speaker != "" else host.selected_target)

func _person_title(person: Dictionary) -> String:
	var role = {"zhang":"机械师","elin":"医护员","ajie":"侦察员","sofia":"后勤员","captain":"队长"}.get(str(person.get("id","")),"队友")
	return role+" · "+str(person.get("name","车队"))

func _dialogue() -> void:
	var id = host.active_card; var person = _owner(); var personal = _visible_queue().any(func(row): return row.id == id)
	var trade = id in TRADE_CARDS
	# Trading parties have no accepted individual portrait; use the atlas vector
	# handshake rather than mislabel a teammate as a merchant.
	var point = Vector2(440,102) if trade else Vector2(260,350 if personal else 397)
	var width = 800.0 if trade else (940.0 if personal else 1160.0)
	var info = _panel(overlay,point,Vector2(width,125 if personal else 140),personal)
	if trade:
		var icon = ICON.new(); icon.kind = "handshake"; icon.position = Vector2(18,22); icon.size = Vector2(76,76); info.add_child(icon)
	else: _portrait(info,str(person.get("id","")),Vector2(12,10),Vector2(105,105 if personal else 120))
	var title = str(host.engine.card_data(id).get("title",id))
	_label(info,title if trade else _person_title(person),Vector2(130,10),Vector2(width-160,30),23)
	var text = host.information.text
	var start = text.find("\n\n")
	if start >= 0: text = text.substr(start+2)
	_rich(info,text,Vector2(130,44),Vector2(width-150,57 if personal else 78),18)
	if personal:
		_label(info,"需求  "+title+"    ·    紧急度  "+["低","中","高"][clampi(host.engine._tier(id),0,2)]+"    ·    截止  "+_deadline(id,str(person.get("id",""))),Vector2(130,95),Vector2(width-150,25),16,Color("9ccce7"))
	elif not trade:
		_label(info,"好感度  %.0f" % float(person.get("like",0)),Vector2(width-180,12),Vector2(165,28),16,Color("eed197"))
	var responses = _panel(overlay,Vector2(point.x,253) if trade else Vector2(point.x,483 if personal else 545),Vector2(width,360 if trade else (222 if personal else 160)),personal)
	var scroll = ScrollContainer.new(); scroll.position = Vector2(18,12); scroll.size = responses.size-Vector2(36,24); responses.add_child(scroll)
	var list = VBoxContainer.new(); list.size_flags_horizontal = Control.SIZE_EXPAND_FILL; list.add_theme_constant_override("separation",6); scroll.add_child(list)
	_forward_choices(list,true)
	if personal: _queue_panel(Vector2(1260,100),365,false)

func _forward_choices(list: VBoxContainer, dialogue: bool = false, filter_kind: String = "") -> void:
	var index = 0
	for original in host.choices.get_children():
		if original is Button and not original is OptionButton:
			if "查看现场" in original.text or "靠近队友" in original.text or "在营地走动" in original.text: continue
			if dialogue and original.get_meta("action_id","") == "" and "只查看" in original.text: continue
			if filter_kind != "" and not _matches(original,filter_kind): continue
			var saved_epoch = epoch
			var button = _button(list,original.text,Vector2.ZERO,Vector2(100,44),func(): _forward(original,saved_epoch),dialogue and index == 0)
			button.name = "AtlasResponse_%d" % index; button.size_flags_horizontal = Control.SIZE_EXPAND_FILL; button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.disabled = original.disabled; button.tooltip_text = original.tooltip_text
			for key in original.get_meta_list(): button.set_meta(key,original.get_meta(key))
			index += 1
		elif original is OptionButton:
			# A personal request already identifies its owner; trade acts on the
			# caravan. Keep book/role/offer pickers where the rules need them.
			if dialogue and original.get_meta("picker_kind","") == "target": continue
			var source = original; var picker = OptionButton.new(); picker.custom_minimum_size = Vector2(100,40); picker.add_theme_font_size_override("font_size",18); picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			for i in source.item_count: picker.add_item(source.get_item_text(i))
			picker.select(source.selected); picker.item_selected.connect(func(i): source.item_selected.emit(i)); list.add_child(picker)
	if index == 0: _label(list,"暂无符合条件的行动",Vector2.ZERO,Vector2(500,30),18,Color("a8bdcc"))

func _forward(original: Button, saved_epoch: int) -> void:
	if busy or host.confirmation.visible or epoch != saved_epoch or not is_instance_valid(original) or original.disabled: return
	busy = true; original.pressed.emit(); busy = false
	if epoch == saved_epoch and visible: _render()

func _visible_queue() -> Array:
	return host.engine.s.daily.get("person_queue",[]).filter(func(row): return not row.get("hidden",false))

func _deadline(id: String, owner: String) -> String:
	if host.engine.s.facts.get("departure_proposal_"+owner,false): return "出发前"
	if id.begins_with("M"): return "晨间准备结束前"
	var card = host.engine.card_data(id)
	var rule = str(card.get("eligibility","")); var start = rule.find("截止")
	if start >= 0:
		var deadline = rule.substr(start+2)
		for mark in ["，","。","；","\n"]: deadline = deadline.get_slice(mark,0)
		return deadline
	return "当前事务窗口" if str(card.get("pool","")) == "person" else "当前事件结束前"

func _queue_panel(point: Vector2, width: float, expanded: bool) -> void:
	var queue = _visible_queue(); var height = minf(490,65+queue.size()*82)
	var panel = _panel(overlay,point,Vector2(width,maxf(125,height)),true)
	_label(panel,"对话队列   %d" % queue.size(),Vector2(20,14),Vector2(width-40,32),22)
	var scroll = ScrollContainer.new(); scroll.position = Vector2(14,54); scroll.size = Vector2(width-28,maxf(60,height-65)); panel.add_child(scroll)
	var list = VBoxContainer.new(); list.size_flags_horizontal = Control.SIZE_EXPAND_FILL; list.add_theme_constant_override("separation",8); scroll.add_child(list)
	for row in queue:
		var person = host.engine.person(str(row.owner)); var id = str(row.id); var owner = str(row.owner)
		var b = _button(list,_person_title(person)+"   "+["低","中","高"][clampi(host.engine._tier(id),0,2)]+"\n"+str(host.engine.card_data(id).get("title",id)),Vector2.ZERO,Vector2(width-28,70),func(): open_card(id,owner))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL; b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text = "       "+b.text.replace("\n","\n       ")
		_portrait(b,owner,Vector2(8,8),Vector2(46,54))
	if queue.is_empty(): _label(list,"当前没有待回应事务",Vector2.ZERO,Vector2(width-40,35),18)
	if expanded: _button(overlay,"返回现场",Vector2(point.x,point.y+height+16),Vector2(width,44),back)

func _member_dialogue() -> void:
	var person = host.engine.person(speaker)
	var panel = _panel(overlay,Vector2(260,410),Vector2(1160,120))
	_portrait(panel,speaker,Vector2(12,8),Vector2(105,104))
	_label(panel,_person_title(person),Vector2(135,12),Vector2(800,30),23)
	_label(panel,"健康 %.0f  ·  疲劳 %.0f  ·  信任 %.0f  ·  好感 %.0f" % [person.get("health",0),person.get("fatigue",0),person.get("trust",0),person.get("like",0)],Vector2(135,48),Vector2(990,30),18)
	_label(panel,"现在没有待回应的专属事务。可以倾听近况，或查看成员安排。",Vector2(135,82),Vector2(1000,25),17,Color("b8cad5"))
	host._stage_action_controls("member")
	var box = _panel(overlay,Vector2(260,538),Vector2(1160,165)); var list = VBoxContainer.new(); list.position = Vector2(18,12); list.size = Vector2(1124,140); box.add_child(list)
	_forward_choices(list)

func _encounter() -> void:
	var banner = _panel(overlay,Vector2(590,108),Vector2(500,64)); banner.line = SKIN.GOLD
	_label(banner,"遇到流浪车队 · 商队",Vector2(25,12),Vector2(450,42),27,Color("efd29a"))
	_button(overlay,"上前交谈",Vector2(685,620),Vector2(310,58),func(): encounter_seen["%d:%s" % [host.engine.s.day,host.active_card]] = true; mode = "dialogue"; _render(),true)

func _actions() -> void:
	var panel = _panel(overlay,Vector2(300,99),Vector2(1080,264),true)
	_label(panel,"营地行动",Vector2(410,12),Vector2(300,38),29)
	var items = [["read","book","阅读","理解 +25 · 知识 +5"],["teach","teach","教学","选择教师与学员"],["repair","repair","维修","零件 3 · 耐久 +15"],["trade","trade","交易","按实际报价交换"],["supplies","supplies","分配物资","安排配给与守夜"],["rest","rest","休息","全队疲劳 −20"]]
	for i in items.size():
		var item = items[i]; var key = str(item[0]); var x = 18+i*174
		var card = _button(panel,"",Vector2(x,62),Vector2(166,150),func(): action_kind = key; mode = "action"; sync())
		card.name = "CampCard_"+key
		var icon = ICON.new(); icon.kind = str(item[1]); icon.position = Vector2(57,14); icon.size = Vector2(52,52); card.add_child(icon)
		_label(card,str(item[2]),Vector2(8,73),Vector2(150,32),23).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label(card,str(item[3]),Vector2(5,113),Vector2(156,30),14,Color("afc6d5")).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label(panel,"今晚营地行动已完成" if host.engine.s.daily.camp_used else "每晚只能选择一次营地行动；配给与守夜单独安排。",Vector2(80,225),Vector2(920,27),17,Color("b8d3e4")).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_button(overlay,"返回营地",Vector2(590,629),Vector2(220,45),back)
	_button(overlay,"夜间安排与结算",Vector2(830,629),Vector2(260,45),func(): mode = "drawer"; host.view = "journey"; host.refresh())

func _action_detail() -> void:
	var names = {"read":"阅读","teach":"教学","repair":"维修","trade":"交易","supplies":"物资分配与守夜","rest":"休息"}
	var panel = _panel(overlay,Vector2(420,105),Vector2(840,510),true)
	_label(panel,str(names.get(action_kind,"营地行动")),Vector2(25,14),Vector2(790,36),26)
	var scroll = ScrollContainer.new(); scroll.position = Vector2(22,62); scroll.size = Vector2(796,424); panel.add_child(scroll)
	var list = VBoxContainer.new(); list.size_flags_horizontal = Control.SIZE_EXPAND_FILL; list.add_theme_constant_override("separation",9); scroll.add_child(list)
	_forward_choices(list,false,action_kind)
	_button(overlay,"返回营地行动",Vector2(690,635),Vector2(300,44),func(): mode = "actions"; _render())

func _matches(button: Button, kind: String) -> bool:
	var action = str(button.get_meta("action_id","")); var args = button.get_meta("command_args",{}); var id = str(args.get("id",""))
	if action == "": return true
	match kind:
		"read","teach": return action == "camp" and id == kind
		"repair","rest": return action == "camp" and id == kind
		"trade": return action == "social" and id == "trade" or action == "camp" and id == "exchange_book"
		"supplies": return action in ["watch","ration","preset","settle"]
	return true

func _drawer() -> void:
	var panel = _panel(overlay,Vector2(440,96),Vector2(800,570),true)
	panel.name = "TodayActions"
	_label(panel,"今日安排",Vector2(24,14),Vector2(750,35),26)
	var scroll = ScrollContainer.new(); scroll.position = Vector2(22,65); scroll.size = Vector2(756,483); scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; panel.add_child(scroll)
	var list = VBoxContainer.new(); list.size_flags_horizontal = Control.SIZE_EXPAND_FILL; list.add_theme_constant_override("separation",8); scroll.add_child(list); _forward_choices(list)
	var reading = _panel(overlay,Vector2(1260,96),Vector2(384,570),true)
	reading.name = "TodayReading"; reading.fill.a = 0.92; reading.shape = SKIN.FRAME.Shape.KRANOX
	_label(reading,"行程说明",Vector2(24,14),Vector2(336,35),26)
	var prose = _rich(reading,host.information.text,Vector2(24,65),Vector2(336,449),21)
	prose.name = "TodayProse"
	var hint = _label(reading,"在文字区域上下滑动",Vector2(24,526),Vector2(336,24),16,SKIN.GOLD)
	# A hint is useful only when there is more text beyond the reading area.
	prose.get_v_scroll_bar().changed.connect(func(): hint.visible = prose.get_v_scroll_bar().max_value > prose.get_v_scroll_bar().page)
	hint.visible = false

func back() -> void:
	if mode != "explore":
		mode = "explore"; action_kind = ""; host.view = "journey"; host.refresh()
	else:
		forced = false; host.view = "team"; host.refresh()

func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		back(); get_viewport().set_input_as_handled()
