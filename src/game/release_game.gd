extends Control
signal return_to_menu
const RULES = preload("res://src/game/world_rules.gd")
const SAVES = preload("res://src/game/save.gd")
const PROSE = preload("res://src/game/presentation.gd")
const LOCATIONS = preload("res://src/game/location_catalog.gd")
const BIOMES = preload("res://src/game/biome_catalog.gd")
const BACKDROP = preload("res://src/game/location_backdrop.gd")
const LOADING = preload("res://src/ui/scene_loading.gd")
const ARCHIVE_SCREEN = preload("res://src/ui/archive_screen.gd")
const MUSIC = preload("res://src/audio/music_catalog.gd")
var scene_backdrop
var scene_caption: Label
var engine = RULES.new()
var save_system = SAVES.new()
var canvas: Control
var heading: Label
var resources: Label
var information: RichTextLabel
var choices: VBoxContainer
var error_label: Label
var confirmation
var paused = false
var view = "journey"
var selected_target = "captain"
var selected_role = "repair"
var selected_faction = "east"
var route = "resource"
var style = "quiet"
var selected_supply = "water"
var pending_command: Dictionary = {}
var game_state
var active_card = ""
var selected_vehicle = 0
var selected_slot = "front"
var selected_offer = 0
var scene_context: Dictionary = {}
var preview_site = ""
var developer_location = ""
var side_stage
var management_screen
var loading_screen
var archive_screen
var auto_save_enabled = true
var play_seconds = 0.0
var last_music_cue = ""

func _ready() -> void:
	theme = ConvoyTheme.create()
	canvas = Control.new(); canvas.size = Vector2(1280,720); canvas.hide(); add_child(canvas)
	var background = ColorRect.new(); background.color = Color("152024"); background.size = canvas.size; canvas.add_child(background)
	heading = _label("",26); heading.position = Vector2(28,16); heading.size = Vector2(1080,38); canvas.add_child(heading)
	var home = Button.new(); home.text = "暂停"; home.position = Vector2(1160,18); home.size = Vector2(90,38); home.pressed.connect(_pause); canvas.add_child(home)
	resources = _label("",16); resources.position = Vector2(28,62); resources.size = Vector2(1220,52); canvas.add_child(resources)
	var nav = HBoxContainer.new(); nav.position = Vector2(28,118); nav.size = Vector2(1220,44); canvas.add_child(nav)
	for item in [["journey","行程"],["team","成员"],["inventory","库存"],["equipment","车辆配件"],["knowledge","书籍岗位"],["factions","阵营事务"],["goals","目标"],["log","因果记录"]]:
		var b = Button.new(); b.text = item[1]; b.custom_minimum_size = Vector2(145,42); var key = str(item[0]); b.pressed.connect(func(): view = key; refresh()); nav.add_child(b)
	scene_backdrop = BACKDROP.new(); scene_backdrop.position = Vector2(28,178); scene_backdrop.size = Vector2(570,244); canvas.add_child(scene_backdrop)
	scene_caption = _label("",17); scene_caption.position = Vector2(38,424); scene_caption.size = Vector2(550,28); canvas.add_child(scene_caption)
	information = RichTextLabel.new(); information.position = Vector2(28,458); information.size = Vector2(570,192); information.bbcode_enabled = true; information.scroll_active = true; information.add_theme_font_size_override("normal_font_size",18); canvas.add_child(information)
	var scroll = ScrollContainer.new(); scroll.position = Vector2(624,178); scroll.size = Vector2(628,472); canvas.add_child(scroll)
	choices = VBoxContainer.new(); choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL; choices.add_theme_constant_override("separation",9); scroll.add_child(choices)
	error_label = _label("",16); error_label.position = Vector2(28,668); error_label.size = Vector2(1220,40); error_label.add_theme_color_override("font_color",Color("f1ba79")); canvas.add_child(error_label)
	confirmation = load("res://src/ui/convoy_confirmation.gd").new(); confirmation.title = "确认不可逆选择"; confirmation.min_size = Vector2i(660,240); confirmation.confirmed.connect(_confirm); add_child(confirmation)
	loading_screen = LOADING.new(); loading_screen.name = "SceneLoading"; add_child(loading_screen)
	loading_screen.started.connect(func():
		if is_instance_valid(side_stage) and is_instance_valid(side_stage.walk): side_stage.walk.lock_movement(true)
	)
	loading_screen.finished.connect(func():
		if is_instance_valid(side_stage) and is_instance_valid(side_stage.walk): side_stage.walk.lock_movement(not side_stage.visible or side_stage.mode != "explore")
	)
	get_viewport().size_changed.connect(_fit); _fit()

func _label(text: String, font_size: int) -> Label:
	var label = Label.new(); label.text = text; label.add_theme_font_size_override("font_size",font_size); return label

func _fit() -> void:
	var size_value = get_viewport_rect().size; var scale_value = minf(size_value.x/1280,size_value.y/720)
	canvas.scale = Vector2.ONE*scale_value; canvas.position = (size_value-Vector2(1280,720)*scale_value)/2

func setup(state = null, saved: Dictionary = {}) -> bool:
	game_state = state
	var director = get_node_or_null("/root/MusicDirector")
	if director != null and director.current_cue == "": activate_music()
	if saved.is_empty(): engine.new_game()
	elif not engine.restore(saved): return false
	scene_context = saved.get("presentation",{}).duplicate(true) if saved.get("presentation",{}) is Dictionary else {}
	_restore_interface(saved)
	preview_site = ""
	refresh(); _autosave(); return true

func _autosave() -> void:
	if not auto_save_enabled: return
	if not save_progress(SAVES.AUTO_SLOT): error_label.text = "自动存档写入失败，请勿退出。"

func _process(delta: float) -> void:
	if not engine.s.is_empty() and not paused and engine.s.phase != "ending" and not loading_screen.busy:
		play_seconds += delta

func archive_metadata() -> Dictionary:
	var location = BIOMES.scene_for(engine.s,"journey",active_card,scene_context)
	var config = LOCATIONS.config(location)
	var thumbnail = "res://assets/settings/settings_background.png"
	# Prefer the production atlas already shipped for this location. Legacy
	# biome full images are source previews deliberately excluded from APKs.
	for path in ["res://assets/locations/atlas_widescreen_20261016/"+location+"/full.jpg",str(config.get("art_root",""))+"full.jpg","res://assets/locations/side_walk_20261016/"+location+"/full.jpg","res://assets/locations/"+location+"/source.png"]:
		if path.begins_with("res://assets/") and ResourceLoader.exists(path): thumbnail = path; break
	return {"play_seconds":play_seconds,"location":location,"location_title":str(config.get("title","荒野旅途")),"thumbnail":thumbnail,"note":"车队 %d 人，已行进 %.0f 千米。%s。" % [engine.people().size(),engine.s.distance,SAVES.PHASE_NAMES.get(engine.s.phase,"旅程继续")]}

func progress_payload() -> Dictionary:
	var payload = engine.checkpoint()
	payload.presentation = scene_context.duplicate(true)
	payload.interface = {"view":view,"active_card":active_card,"selected_target":selected_target,"selected_role":selected_role,"selected_faction":selected_faction,"selected_vehicle":selected_vehicle,"selected_slot":selected_slot,"route":route,"style":style,"selected_supply":selected_supply}
	return payload

func save_progress(slot: String,note: String = "") -> bool:
	var payload = progress_payload()
	var metadata = archive_metadata()
	if note != "": metadata.note = note.left(240)
	return save_system.save_payload(payload,slot,metadata)

func _restore_interface(saved: Dictionary) -> void:
	var info: Dictionary = saved.get("save_info",{}) if saved.get("save_info") is Dictionary else {}
	play_seconds = maxf(0,float(info.get("play_seconds",0)))
	var ui: Dictionary = saved.get("interface",{}) if saved.get("interface") is Dictionary else {}
	view = str(ui.get("view","journey"))
	if view not in ["journey","route_map","card","team","inventory","equipment","knowledge","factions","goals","log"]: view = "journey"
	active_card = str(ui.get("active_card",""))
	if view == "card" and not engine.content.cards.has(active_card): view = "journey"
	selected_target = str(ui.get("selected_target","captain"))
	if engine.person(selected_target).is_empty(): selected_target = str(engine.s.members[0].id)
	selected_role = str(ui.get("selected_role","repair")); selected_faction = str(ui.get("selected_faction","east"))
	if not engine.BOOKS.has(selected_role): selected_role = "repair"
	if selected_faction not in ["east","south","guild"]: selected_faction = "east"
	selected_vehicle = clampi(int(ui.get("selected_vehicle",0)),0,maxi(0,engine.s.vehicles.size()-1))
	selected_slot = str(ui.get("selected_slot","front"))
	if not engine.SLOTS.has(selected_slot): selected_slot = "front"
	route = str(ui.get("route",engine.s.daily.get("route","resource"))); style = str(ui.get("style","quiet"))
	if route not in ["safe","resource","unknown","stay"]: route = "resource"
	if style not in ["quiet","fast","detour"]: style = "quiet"
	selected_supply = str(ui.get("selected_supply",engine.supply_types()[0]))
	if selected_supply not in engine.supply_types(): selected_supply = engine.supply_types()[0]

func _open_archive() -> void:
	if loading_screen.busy or confirmation.visible: return
	if not paused: paused = true; refresh()
	if not is_instance_valid(archive_screen):
		archive_screen = ARCHIVE_SCREEN.new(); archive_screen.feedback = preload("res://src/ui/convoy_skin.gd").feedback_for(self)
		add_child(archive_screen)
		archive_screen.closed.connect(func(): refresh())
		archive_screen.load_requested.connect(_load_archive)
	archive_screen.move_to_front()
	archive_screen.open_screen(save_system,self)

func _load_archive(payload: Dictionary) -> void:
	if not engine.restore(payload):
		archive_screen.show(); archive_screen.notice = "存档无法恢复："+engine.error; archive_screen._render(); return
	scene_context = payload.get("presentation",{}).duplicate(true) if payload.get("presentation") is Dictionary else {}
	_restore_interface(payload); preview_site = ""; paused = false; pending_command.clear()
	if is_instance_valid(side_stage): side_stage.last_phase = ""; side_stage.forced = false
	if is_instance_valid(management_screen): management_screen.modal_kind = ""
	_autosave(); refresh()

func _button(label: String, action: String, args: Dictionary = {}, irreversible: bool = false) -> void:
	var b = Button.new(); b.text = label; b.custom_minimum_size = Vector2(590,48); b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.set_meta("action_id",action); b.set_meta("command_args",args.duplicate(true))
	# Validate without committing. RNG, all current state, and morning snapshot are restored.
	var before = engine.checkpoint(); var old_error = engine.error
	var can_execute = engine.command(action,args); var reason = engine.error
	engine.restore(before); engine.error = old_error
	b.disabled = not can_execute; b.tooltip_text = reason if not can_execute else label
	if not can_execute and reason != "": b.text += " 〔"+reason+"〕"
	b.pressed.connect(func(): _issue(action,args,irreversible,label)); choices.add_child(b)

func _local(label: String, callback: Callable) -> void:
	var b = Button.new(); b.text = label; b.custom_minimum_size = Vector2(590,42); b.pressed.connect(callback); choices.add_child(b)

func _issue(action: String, args: Dictionary, irreversible: bool, label: String) -> void:
	if loading_screen.busy: return
	if irreversible:
		pending_command = {"action":action,"args":args}; confirmation.dialog_text = label+"\n\n将产生所列后果。重试当天会撤销今天全部进度，不能只保留收益。"; confirmation.popup_centered(); return
	_run(action,args)

func _confirm() -> void:
	_run(pending_command.action,pending_command.args); pending_command.clear()

func _run(action: String, args: Dictionary) -> void:
	if engine.command(action,args):
		developer_location = ""
		preview_site = ""
		if action in ["next","retry","depart","begin_camp","visit","walk"]: scene_context.clear()
		if action == "acquire": _remember_site(BIOMES.fixed_site(str(args.get("location",""))))
		if action == "card" and str(args.get("id","")) == "V05" and int(args.get("option",-1)) == 0: _remember_site(BIOMES.site_in_region("fuel_depot",engine.s))
		if action == "next": route = str(engine.s.daily.route)
		if action == "retry": paused = false; view = "journey"
		if action in ["card","next","retry","rescue","rescue_seat","goal","depart","begin_camp","settle"]: view = "journey"
		error_label.text = "已自动保存" if auto_save_enabled else ""; _autosave()
	else: error_label.text = engine.error
	refresh()

func refresh() -> void:
	if engine.s.is_empty() or not is_instance_valid(choices): return
	var location = preview_site if view == "site_preview" else BIOMES.scene_for(engine.s,view,active_card,scene_context)
	if developer_location != "": location = developer_location
	var target = side_stage.presentation_location() if is_instance_valid(side_stage) and side_stage.should_show() else location
	if paused and loading_screen.loaded_location != "": target = loading_screen.loaded_location
	if _load_location(target,refresh,location): return
	_refresh_now(location)

func _load_location(location: String, render: Callable, additional: String = "") -> bool:
	return loading_screen.request(location,render,additional)

func _refresh_now(location: String) -> void:
	for child in choices.get_children(): choices.remove_child(child); child.queue_free()
	var s = engine.s
	scene_backdrop.display(location,s.vehicles)
	scene_caption.text = str(scene_backdrop.config.get("title","当前路段"))+(" · 地点预览" if view == "site_preview" else (" · 路线预览" if s.phase == "route" and (location.ends_with("_road") or location == "tunnel_entrance") else " · 当前现场"))
	heading.text = "末日车队  第%d / 20天 · %s · %s" % [s.day,s.daily.weather,{"morning":"晨间准备","route":"路线预设","rescue":"实际救援","rescue_seats":"满员安置","event":"途中事件","stop":"停歇事务","camp":"营地行动","camp_event":"营地事件","night":"夜间结算","split":"群体分裂决定","ending":"旅程终局"}.get(s.phase,s.phase)]
	resources.text = "%s\n人数%d/8 · 货重%.1f/%.1f千克 · 主边%d + %.0f/30千米 · %.1f/12小时 · 事务%d/2 · 情报%d/3" % [engine.cost_text(s.resources),engine.people().size(),engine.weight(),engine.capacity(),s.legs,s.edge_km,s.daily.hours,s.daily.tasks,s.clues.size()]
	if paused: _pause_choices(); _sync_side_stage(); return
	match view:
		"site_preview": _site_preview_view()
		"card": _card_view(active_card)
		"team": _team_view()
		"inventory": _inventory_view()
		"equipment": _equipment_view()
		"knowledge": _knowledge_view()
		"factions": _faction_view()
		"goals": _goal_view()
		"log":
			information.text = "[b]今日实际变化[/b]\n\n"+PROSE.journal(s.daily.log)
			for row in s.history: _local("第%d天记录" % row.day,func(): information.text = PROSE.journal(row.log))
		_: _journey_view()
	_sync_side_stage()

func _journey_view() -> void:
	var s = engine.s
	information.text = "[b]今天的计划[/b]\n"+_day_description()+"\n\n目前位置："+str(scene_backdrop.config.get("title",s.position))+"\n信任%d / 好感%.1f / 知识%d / 制度%d\n妹妹状态：%s\n%s" % [engine.trust(),engine.affection(),s.knowledge,s.institution,_sister_status(),PROSE.journal(s.daily.log.slice(maxi(0,s.daily.log.size()-8)))]+_story_text()
	if engine.fixed_recruitment_pending():
		var recruitment_hint = "[b]固定招募尚未回应[/b]\n今天两项主要事务中的一项已留给本次招募。请先选择一名候选或点「都不招募」，再安排其他停歇事务。"
		if s.daily.tasks >= 2: recruitment_hint += "\n你已用完两项主要事务，现在直接点「都不招募」即可完成回应。"
		else: recruitment_hint += "\n回应前只能先完成一项其他事务。"
		information.text = recruitment_hint+"\n\n"+information.text
	if s.phase in ["morning","rescue","rescue_seats"]: _local("查看现场，靠近队友交谈",_open_side_stage)
	match s.phase:
		"morning":
			_target_picker()
			for item in [["water","分水：水2，所有个人信任+2"],["repair","小修：件2，主车耐久+8，清前桥"],["accounts","清账：私藏风险−10"],["aid","急救：药1，所选成员健康+20"],["none","不行动：连续3晨不行动信任−5"]]: _button(item[1],"prepare",{"id":item[0],"target":selected_target})
			_button("准备结束，进入路线选择","finish_prepare")
			_person_cards()
		"route":
			_mainline_choices()
			if s.day in engine.IMPORTANT:
				for item in [["north","随后两天去北部：药品 / 食物"],["south","随后两天去南部：燃料 / 零件"],["east","随后两天去东部：饮水 / 食物"]]: _button(item[1],"direction",{"id":item[0]})
			if s.day in [2,5]: _button("核查旧频段：第2天免费，第5天补核零件2","intel",{"id":"frequency"})
			if s.day == 8: _button("侦察南边入口：燃料4 / 1小时，情报+1并承诺南下","intel",{"id":"south"})
			_person_cards()
			_button("照明："+("关闭车灯" if s.daily.light else "打开车灯（增加夜行被发现资格）"),"preset",{"id":"light","value":not s.daily.light})
			_button("按当前主路前进","map_choice",{"id":"road"})
			if s.legs >= 3 and not engine.on_foot(): _button("尝试进入已标封死隧道支路（先停车确认；强冲会全灭）","map_choice",{"id":"sealed_tunnel"},true)
			if engine.on_foot():
				_button("徒步到当前章安全避难点：6千米，疲劳+20","walk",{"id":"避难点"})
				_button("徒步到已知废车支点：8千米，疲劳+20","walk",{"id":"废车点"})
			for item in [["safe","安全"],["resource","资源"],["unknown","未知"],["stay","主动停留"]]:
				var key = str(item[0]); _local(("✓ " if route == key else "")+item[1],func(): route = key; refresh())
			for item in [["quiet","低噪音"],["fast","快速"],["detour","绕行"]]:
				var key = str(item[0]); _local(("✓ " if style == key else "")+item[1],func(): style = key; refresh())
			if selected_supply not in engine.supply_types(): selected_supply = engine.supply_types()[0]
			for resource in engine.supply_types():
				var key = str(resource); _local(("✓ " if selected_supply == key else "")+"路段供给："+engine.RESOURCE_NAMES[key],func(): selected_supply = key; refresh())
			var q = engine.route_quote(route,style)
			_button("确认出发：燃料%.1f / %.1f小时 / 疲劳+%.1f / 移动出现率%.0f%%" % [q.fuel,q.hours,q.fatigue,q.event_rate],"depart",{"route":route,"style":style,"supply":selected_supply})
		"rescue":
			information.text = "[b]第10天 实际救援[/b]\n\n"+"\n".join(engine.rescue_missing())+"\n\n救援标准：燃料12、件5、药2、耐久8，替代本日普通行驶费用。满8人成功后才安排一人离队。"
			_button("低声进入：满足条件则100%救出","rescue",{"id":"quiet"},true)
			_button("正面突破：额外件2、车损10，100%救出","rescue",{"id":"frontal"},true)
			_button("明确主动放弃救援","rescue",{"id":"abandon"},true)
			_button("承认未能完成，记录失联","rescue",{"id":"missing"},true)
			_button("在已到达站外确认现场情况","rescue",{"id":"inspect"})
			_button("强闯隔离走廊：无法救出且妹妹确认死亡，执行者健康−20","rescue",{"id":"force"},true)
		"rescue_seats":
			information.text = "妹妹已成功救出。当前满8人，须让一名现有队友由救援点照料者安全接纳，再让妹妹上车。"
			for m in engine.people():
				if m.id != "captain": _button("安全安置"+m.name+"，妹妹加入","rescue_seat",{"id":m.id},true)
			_button("妹妹由照料者安置，获救未随行","rescue_seat",{"id":"leave_sister"},true)
		"event","camp_event": _card_view(s.daily.card)
		"stop":
			_local("在当前地点走动，靠近队友交谈",_open_side_stage)
			if s.day in [4,7,9] and not s.daily.opportunity_used:
				var pairs = {4:[["xuning","许宁 医疗65"],["chenchuan","陈川 维修65"]],7:[["duheng","杜衡 侦察65"],["linyue","林悦 后勤65"]],9:[["cenbai","岑柏 四项45"]]}[int(s.day)]
				for entry in pairs: _button("招募"+entry[1]+"：水2食2 / 1小时，互斥永久","recruit",{"id":entry[0]},true)
				_button("都不招募：0.5小时，占一次事务","recruit",{"id":"none"},true)
			_person_cards()
			if s.daily.get("opportunity_card","") != "": _local("停歇机会："+engine.content.cards[s.daily.opportunity_card].title,func(): active_card = s.daily.opportunity_card; view = "card"; refresh())
			if not s.daily.get("source",{}).is_empty():
				_target_picker()
				var source = s.daily.source
				_button("拆检"+source.name+"：1小时，占机会，成功率%d%%，侦察60另+10；失败件2" % source.chance,"salvage",{"target":selected_target})
			_button("驾车进入当前章安全接纳点：燃料1/1小时/占事务","visit",{"id":"refuge"})
			_button("驾车进入已知废车支点：燃料1/1小时/占事务","visit",{"id":"wreck"})
			_button("事务处理完，安排唯一营地行动","begin_camp")
		"camp":
			_local("在营地走动，靠近队友交谈",_open_side_stage)
			_target_picker()
			for item in [["rest","全队休息：疲劳−20"],["care","照料所选成员：药1，健康+25、疲劳−10"],["repair","完整维修：零件3，耐久+15"],["tea","茶仪式：水2茶1，好感+3"],["incense","香仪式：香1，疲劳−5"]]: _button(item[1],"camp",{"id":item[0],"target":selected_target})
			for key in engine.supply_types(): _button("当地搜集："+engine.RESOURCE_NAMES[key],"camp",{"id":"gather","resource":key})
			_button("修复已到达废车点的车辆：件6燃料10","camp",{"id":"new_car"})
			_button("商会购买第二车：件12油10，第15日起","camp",{"id":"second_car"})
			_button("食物密封："+("取消密封，次日留下气味" if s.daily.sealed else "重新密封"),"preset",{"id":"sealed","value":not s.daily.sealed})
			_button("夜间配给与结算","settle")
			_button("安排所选成员守夜","watch",{"id":selected_target})
			_button("本夜不安排守夜","watch",{"id":""})
			for resource in ["water","food"]:
				_button("所选成员本夜不领"+engine.RESOURCE_NAMES[resource]+"：缺水健康−15/疲劳+10，缺食−8/+5，连续短缺另伤","ration",{"id":resource,"target":selected_target,"amount":0},true)
				_button("恢复所选成员完整"+engine.RESOURCE_NAMES[resource]+"配给","ration",{"id":resource,"target":selected_target,"amount":2 if resource == "water" and engine.on_foot() else 1})
		"night":
			information.text = "[b]第%d夜实际结算[/b]\n\n%s" % [s.day,"\n".join(s.daily.log)]
			_button("进入下一天","next")
		"split":
			information.text = "两个群体的信任差已连续两夜≥30。配给已结算，请决定。"
			_button("调停：水2食2 / 1小时","split",{"id":"mediate"})
			_button("安全分流低信任群体：每人水1食1/1小时，需本人同意与接纳点","split",{"id":"safe"},true)
			_button("明确各走各路：12日起进入分裂结局，之前低信任群体离队","split",{"id":"separate"},true)
		"ending":
			var e = engine.content.endings[s.ending]; var epilogue = engine.content.epilogues[engine.epilogue_id()]
			information.text = "[b]"+e.title+"[/b]\n\n"+PROSE.ending(engine)+"\n\n[b]"+epilogue.title+"[/b]\n"+PROSE.epilogue(engine)
			_button("重试最后一天：放弃本日所有结果并重新随机","retry",{},true)
			_local("返回主菜单",func(): _autosave(); return_to_menu.emit())

func _target_picker() -> void:
	var names: Array[String] = []; var ids: Array[String] = []
	for m in engine.people(): names.append(m.name); ids.append(m.id)
	if selected_target not in ids and not ids.is_empty(): selected_target = ids[0]
	var option = OptionButton.new(); option.custom_minimum_size = Vector2(590,40)
	option.set_meta("picker_kind","target")
	for name in names: option.add_item(name)
	option.select(maxi(0,ids.find(selected_target))); option.item_selected.connect(func(i): selected_target = ids[i]; refresh()); choices.add_child(option)

func _person_cards() -> void:
	for row in engine.s.daily.get("person_queue",[]):
		if row.get("hidden",false): continue
		var key = str(row.id); var owner = str(row.owner)
		_local("人物事务："+engine.person(owner).get("name","车队")+" · "+engine.content.cards[key].title,func(): selected_target = owner; active_card = key; view = "card"; refresh())
	for m in engine.people():
		if engine.s.facts.get("departure_proposal_"+m.id,false):
			var id = str(m.id); _local(m.name+"提出离队，前往协商",func(): selected_target = id; view = "team"; refresh())

func _card_view(id: String) -> void:
	if engine.card_data(id).is_empty(): view = "journey"; refresh(); return
	for child in choices.get_children(): choices.remove_child(child); child.queue_free()
	var card = engine.card_data(id)
	information.text = "[b]"+card.title+"[/b]\n\n"+PROSE.card(engine,id,selected_target)
	_target_picker()
	if id in ["M04","N-X04","N-F01","C06","C08","C09","C10"]:
		_role_picker()
	if id in ["R01","N-F09","N-C01"]:
		var offers = OptionButton.new(); offers.custom_minimum_size = Vector2(590,42)
		offers.set_meta("picker_kind","offer")
		for label in ["燃料6换食10","食4换水10","件3换燃料12","水6换药1","药1换件4"]: offers.add_item(label+"（有合格后勤支付优惠1）")
		offers.select(selected_offer); offers.item_selected.connect(func(i): selected_offer = i; refresh()); choices.add_child(offers)
	var teachers = engine.qualified(selected_role).filter(func(m): return m.understanding.get(selected_role,0) >= 50 and m.id != selected_target)
	var teacher_id = str(teachers[0].id) if not teachers.is_empty() else ""
	for option in card.options:
		var i = int(option.key); var label = str(option.raw)
		if i in engine.INQUIRIES.get(id,[]):
			_local(option.text+"（仅显示信息）",func(): information.text = "[b]"+card.title+"[/b]\n\n"+PROSE.card(engine,id,selected_target)+"\n\n"+PROSE.inquiry(engine,id,i,selected_target))
		elif id == "V05" and i == 0:
			for deal in [["pay","交食物5，获得燃料20"],["refuse","拒交，获得燃料5"],["rob","强抢燃料20：掠夺+1、阵营−30、信任−10"]]:
				_button(deal[1],"card",{"id":id,"option":0,"target":selected_target,"deal":deal[0]},deal[0] == "rob")
		else:
			_button("%d. %s" % [i+1,label],"card",{"id":id,"option":i,"target":selected_target,"role":selected_role,"teacher":teacher_id,"offer":selected_offer},_dangerous(label) or id in ["T06","N-C03"] and i == 2)
			if id == "N-C02" and i == 1 or id == "N-C05" and i == 2: _button(option.text+"，使用诱导发射器：另件1/0.5小时/追踪−10暴露+5","card",{"id":id,"option":i,"target":selected_target,"assist":true})
	if id == "V09":
		_button("弃主车，按实际携行重量转移货物","card",{"id":id,"option":3},true)
		_button("请求已到达安全点的修理外援：水5/3小时/耐久+10","card",{"id":id,"option":4})
	_local("只查看，返回当前阶段",func(): view = "journey"; refresh())

func _dangerous(text: String) -> bool:
	return "强冲" in text or "迎击" in text or "抢" in text or "断后" in text or "弃" in text or "离队" in text or "烧" in text

func _team_view() -> void:
	information.text = "[b]存活、岗位与成员历史[/b]\n信任与好感独立，离队不等于死亡。\n\n"
	for m in engine.s.members:
		information.text += "%s %s\n健康%.0f 疲劳%.1f 信任%.0f 好感%.0f\n修%.0f 医%.0f 侦%.0f 后%.0f · %s\n\n" % [m.name,"在队" if m.alive and m.active else ("死亡" if not m.alive else "离队"),m.health,m.fatigue,m.trust,m.like,m.repair,m.medical,m.scout,m.logistics,PROSE.readable(m.memory)]
	_target_picker()
	_button("倾听所选队友：1小时、信任+2好感+3，占事务","social",{"id":"listen","target":selected_target})
	_button("由已确认安全点接纳所选队友：水1食1，占事务","social",{"id":"safe_depart","target":selected_target},true)
	if engine.s.facts.get("departure_proposal_"+selected_target,false): _button("协商挽留：1小时、信任+10，取消此次离队提议","social",{"id":"proposal_talk","target":selected_target})

func _role_picker() -> void:
	var picker = OptionButton.new(); picker.custom_minimum_size = Vector2(590,42)
	picker.set_meta("picker_kind","role")
	var roles = engine.BOOKS.keys()
	for role in roles: picker.add_item(engine.BOOKS[role])
	picker.select(maxi(0,roles.find(selected_role))); picker.item_selected.connect(func(i): selected_role = roles[i]; refresh()); choices.add_child(picker)

func _inventory_view() -> void:
	information.text = "[b]真实库存与搬运[/b]\n"+engine.cost_text(engine.s.resources)+"\n\n货重%.1f / 容量%.1f千克\n徒步每名健康30者8千克，重伤者2千克。书、本、茶和香也计重。\n笔记剩余%d页" % [engine.weight(),engine.capacity(),engine.s.pages]
	for key in engine.s.resources:
		for amount in [1,5,10]: _button("永久丢弃%s%d" % [engine.RESOURCE_NAMES[key],amount],"drop",{"id":key,"amount":amount},true)
	for role in engine.BOOKS:
		_button("永久丢弃"+engine.BOOKS[role]+"1册","drop_item",{"id":role},true)
	_button("永久丢弃笔记本：失去剩余可写页","drop_item",{"id":"notebook"},true)
	for id in engine.s.cores:
		if engine.s.cores[id] > 0: _button("永久丢弃"+id+"核心1件","drop_item",{"id":id},true)

func _equipment_view() -> void:
	information.text = "[b]车辆与五部位[/b]\n\n"
	for i in range(engine.s.vehicles.size()):
		var v = engine.s.vehicles[i]; information.text += "%d %s 耐久%.1f %s\n" % [i+1,v.name,v.durability,"报废" if v.destroyed else "可用"]
		for slot in engine.SLOTS:
			var module_id = str(v.modules.get(slot,""))
			information.text += engine.SLOTS[slot]+"："+(engine.content.modules[module_id].name if module_id != "" else "未安装")+"\n"
		if not v.destroyed:
			information.text += "此车货重%.1f/%.1f千克\n" % [engine.vehicle_weight(v),engine.vehicle_capacity(v)]
			var index = i; _local(("✓ " if selected_vehicle == i else "")+"查看车辆%d" % (i+1),func(): selected_vehicle = index; refresh())
			_button("指定车辆%d为主车" % (i+1),"assign_vehicle",{"vehicle":i})
	information.text += "\n散装核心："
	var core_labels: Array[String] = []
	for key in engine.s.cores:
		if engine.s.cores[key] > 0: core_labels.append("%s %s ×%d" % [key,engine.content.modules[key].name,engine.s.cores[key]])
	information.text += "、".join(core_labels) if not core_labels.is_empty() else "暂无"
	_target_picker()
	_button("将所选成员安排到车辆%d" % (selected_vehicle+1),"assign_vehicle",{"vehicle":selected_vehicle,"target":selected_target})
	for slot in engine.SLOTS:
		var key = str(slot); _local(("✓ " if selected_slot == key else "")+engine.SLOTS[key],func(): selected_slot = key; refresh())
	_button("拆除所选车辆的"+engine.SLOTS[selected_slot]+"：营地2小时，仅取回核心","camp",{"id":"remove","vehicle":selected_vehicle,"slot":selected_slot})
	for key in engine.content.modules:
		var mod = engine.content.modules[key]
		if mod.slot != selected_slot: continue
		information.text += "\n%s %s：%s\n" % [key,mod.name,mod.effect]
		if engine.s.cores.get(key,0) > 0: _button("安装%s %s：件%d，成品%d千克" % [key,mod.name,mod.cost,mod.weight],"camp",{"id":"install","vehicle":selected_vehicle,"module":key})
		if engine.s.day >= 15: _button("商会补购%s核心：标价件8，合格后勤件7，全局最多2件" % key,"buy_core",{"id":key})
	for loc in engine.content.locations:
		if loc.chapter != engine.s.legs: continue
		var site_id = BIOMES.fixed_site(str(loc.id))
		if site_id != "":
			var target_site = site_id
			_local("查看"+loc.name+"（支路预览）",func(): preview_site = target_site; view = "site_preview"; refresh())
		for key in loc.choices: _button("%s：取%s（燃料1/2小时/占机会）" % [loc.name,key],"acquire",{"location":loc.id,"id":key})
	for item in [["water","运行净水箱：水+3，油1或设备供电"],["cold","开启冷链：油1或供电，防腐至次日营地"],["lure","追踪诱导：件1、0.5小时、追踪−10暴露+5"]]: _button(item[1],"device",{"id":item[0]})
	_button("取消本晚设备安排","device",{"id":"cancel"})
	_button("将本车最多4份食物实际放入冷藏箱","container",{"id":"cold_food","vehicle":selected_vehicle})
	for role in engine.BOOKS: _button("晨间指定档案保护："+engine.BOOKS[role]+"（最多两册，可取消）","container",{"id":"archive","role":role,"vehicle":selected_vehicle})
	_button("雨天启用防滑链","preset",{"id":"rain_chain","value":true})
	if engine.cars().size() > 1:
		for key in engine.cargo_keys(): _button("实际转移%s5单位到车辆%d" % [key,selected_vehicle+1],"transfer",{"id":key,"amount":5,"vehicle":selected_vehicle})
	_button("定位当前已知废车地带：一次事务/日，失败不生车","search_car")

func _knowledge_view() -> void:
	information.text = "[b]理解与能力分开[/b]\n阅读理解+25，知识+5，不直接提高岗位。正式教学按教师能力与学员信任计算；应急自学须能力40–59、理解50与书。\n\n书籍：\n"
	for role in engine.BOOKS: information.text += "%s ×%d\n" % [engine.BOOKS[role],engine.s.books.get(role,0)]
	information.text += "\n已验证记录：\n"+("\n".join(engine.s.records) if not engine.s.records.is_empty() else "暂无")
	_target_picker()
	for role in engine.BOOKS:
		var key = str(role); _local(("✓ " if selected_role == key else "")+engine.BOOKS[key],func(): selected_role = key; refresh())
	_button("阅读所选书籍与成员","camp",{"id":"read","target":selected_target,"role":selected_role})
	for teacher in engine.qualified(selected_role): _button("由"+teacher.name+"教学所选成员","camp",{"id":"teach","teacher":teacher.id,"target":selected_target,"role":selected_role})
	_button("应急自学：有书、理解50、能力40–59；件2或药1","camp",{"id":"self_study","target":selected_target,"role":selected_role})
	_button("记录已验证方法：1页，知识+4","camp",{"id":"record","label":"第%d章配给与路况" % engine.s.legs})
	_button("将已记录内容抄存当前位置：2页，知识+1，占事务","social",{"id":"store_copy"})
	_button("回收账本空页：零件1换5页，每局一次，占事务","social",{"id":"recover_pages"})
	for resource in ["water","food","parts"]: _button("交换所选书籍，获得"+engine.RESOURCE_NAMES[resource]+str({"water":10,"food":8,"parts":4}[resource])+"（占营地）","camp",{"id":"exchange_book","role":selected_role,"resource":resource,"faction":selected_faction},true)
	_button("焚烧所选书籍取暖：书永久失去，疲劳−10（占营地）","camp",{"id":"burn_book","role":selected_role},true)

func _faction_view() -> void:
	information.text = "[b]三阵营[/b]\n"
	for key in engine.s.factions: information.text += "%s：关系%d · %s\n" % [PROSE.readable(key),engine.s.factions[key],"已接触" if key in engine.s.contacts else "尚未接触"]
	information.text += "\n公平交易%d次，掠夺%d次\n\n所有关系动作占一项主要事务，每天最多两项。" % [engine.s.trades,engine.s.raids]
	for key in engine.s.contacts:
		var value = str(key); _local(("✓ " if selected_faction == key else "")+{"east":"东岸聚落","south":"南边定居点","guild":"公路商会"}[key],func(): selected_faction = value; refresh())
	for item in [["equal","公开平等决策：水2，好感+3"],["favor","偏袒A群体：水2，A信任+8/B−8"],["command","强制命令：信任−5好感−8"],["mediate","调停：水2食2，两群体靠近均值10"],["contribute","向所选阵营贡献：水5食5，关系+15"],["raid","袭击所选阵营运输员：水10食10油12，掠夺+1、关系−30、信任−10"]]: _button(item[1],"social",{"id":item[0],"faction":selected_faction},item[0] == "raid")
	var labels = ["燃料6换食物10","食物4换水10","零件3换燃料12","饮水6换药1","药1换零件4"]
	for i in range(labels.size()): _button("公平交易："+labels[i]+"（合格后勤优惠1）","social",{"id":"trade","faction":selected_faction,"offer":i})

func _goal_view() -> void:
	var intent = engine.content.endings.get(engine.s.intent,{}).get("title","尚未完成目标行动")
	information.text = "[b]实际完成目标[/b]\n第12天起允许正常收束。完成动作锁定意图，仍须当晚配给与伤亡核验。最后入口需真实推进至少8条主边，不能点击瞬移。\n\n当前：主边%d、方向%s\n%s\n\n灰色行动会列出当前缺少的条件。" % [engine.s.legs,PROSE.readable(engine.s.goal),intent]
	for id in ["E02","E03","E04","E05","E06","E07","E08","E11","E12","E13"]:
		var missing = engine.ending_missing(id)
		var label = engine.GOAL_ACTIONS[id]+("\n尚缺："+"；".join(missing) if not missing.is_empty() else "")
		_button(label,"goal",{"id":id},true)
	_local("继续今天的行程",func(): view = "journey"; refresh())

func _pause() -> void:
	if loading_screen.busy: return
	paused = not paused; refresh()

func _pause_choices() -> void:
	information.text = "[b]已暂停[/b]\n继续旅程读取当前进度；重试还原当天晨间快照，并撤销今天全部收益、伤亡、招募和随机结果。以前日期的历史保留。"
	_local("继续",func(): paused = false; refresh())
	_local("保存 / 读取",_open_archive)
	_button("重试当天：撤销今天全部进度并更换随机种子","retry",{},true)
	_local("返回主菜单",func(): _autosave(); return_to_menu.emit())

func _unhandled_key_input(event: InputEvent) -> void:
	if is_instance_valid(archive_screen) and archive_screen.visible: return
	if loading_screen.busy: return
	if event.is_action_pressed("ui_cancel"):
		if confirmation.visible: confirmation.hide()
		elif view != "journey": view = "journey"; refresh()
		else: _pause()
		get_viewport().set_input_as_handled()

func _day_description() -> String:
	return PROSE.day_plan(engine)

func _story_text() -> String:
	return PROSE.story(engine)

func _mainline_choices() -> void:
	var day = int(engine.s.day)
	var rows = {2:[["frequency","先核查旧频段，再沿南边方向走"],["east","先去东岸接触聚落"],["independent","先补足今天的水和食"]],5:[["rescue","确认去救她，并核对漏失的旧频段（缺失才付件2）"],["continue","保留坐标，先履行原计划"]],8:[["rescue","侦察南边入口并承诺救援：油4/1小时/占事务"],["east","继续已联系的东岸方向"],["guild","继续公路商会方向"],["independent","继续独立补给方向"]]}.get(day,[])
	if day in [12,15,18,20]: rows = [["south","向南边正式定居区行进"],["east","向东岸聚落行进"],["guild","向商会登记处行进"],["shadow","沿已观察的巡游规律行进"],["continue","保持当前目标，先完成今天的路"]]
	for row in rows: _button(row[1],"mainline",{"id":row[0]})

func _sister_status() -> String:
	return {"unresolved":"尚未到救援日","alive":"已救出，在队","safe_departed":"已安全安置","rescued_dead":"获救后死亡","confirmed_dead":"现场确认死亡","missing":"失联","abandoned":"主动放弃救援","rescued_unknown":"获救后离队，去向未知","rescued_not_joined":"获救，由救援点照料，未随车","rescued_pending":"已救出，正在安排座位"}.get(engine.s.sister,engine.s.sister)

func _open_camp_walk() -> void:
	if is_instance_valid(side_stage): side_stage.hide(); side_stage.walk.lock_movement(true)
	var walk = load("res://src/game/camp_walk.gd").new()
	walk.location_id = BIOMES.scene_for(engine.s,view,active_card,scene_context)
	walk.vehicles = engine.s.vehicles.duplicate(true)
	walk.members = engine.people().duplicate(true); canvas.add_child(walk)
	walk.closed.connect(func(): walk.queue_free(); _sync_side_stage())
	walk.interacted.connect(func(id):
		selected_target = id; walk.queue_free()
		for row in engine.s.daily.get("person_queue",[]):
			if row.owner == id and not row.get("hidden",false): active_card = row.id; view = "card"; refresh(); return
		view = "team"; refresh())

func _sync_side_stage() -> void:
	if not is_instance_valid(side_stage):
		side_stage = load("res://src/game/side_stage.gd").new(); side_stage.name = "HorizontalAtlasStage"; side_stage.host = self; add_child(side_stage)
	side_stage.sync()
	if not is_instance_valid(management_screen):
		management_screen = load("res://src/game/management_screen.gd").new(); management_screen.name = "ConvoyManagement"; management_screen.host = self; add_child(management_screen)
		side_stage.visibility_changed.connect(func(): if is_instance_valid(management_screen): management_screen.sync())
	management_screen.sync()
	_sync_music()

func activate_music() -> void:
	var director = get_node_or_null("/root/MusicDirector")
	if director == null: return
	director.activate(self)
	if last_music_cue != "": director.request(self,last_music_cue)
	_sync_music()

func _sync_music(location: String = "") -> void:
	var director = get_node_or_null("/root/MusicDirector")
	if director == null or not director.is_owner(self) or engine.s.is_empty(): return
	# Overlays and loading covers keep the last audible scene until the real
	# presentation has been assembled. Inactive developer hosts cannot claim it.
	if paused or loading_screen.busy and not loading_screen.applying: return
	if location == "":
		if is_instance_valid(side_stage) and side_stage.visible:
			location = side_stage.current_location
		else:
			location = preview_site if view == "site_preview" else BIOMES.scene_for(engine.s,view,active_card,scene_context)
			if developer_location != "": location = developer_location
	if developer_location != "":
		# The explicit art browser previews the selected place independently
		# of the suspended story's ending, event, route plan or lost vehicles.
		var preview_state = engine.s.duplicate()
		preview_state.phase = "preview"
		preview_state.erase("vehicles")
		last_music_cue = MUSIC.cue_for(location,preview_state,"journey")
	else:
		last_music_cue = MUSIC.cue_for(location,engine.s,view,active_card)
	director.request(self,last_music_cue)

func _open_side_stage() -> void:
	_sync_side_stage(); side_stage.forced = true; side_stage.last_phase = str(engine.s.phase); view = "journey"; side_stage.mode = "explore"; side_stage.sync()

func _stage_action_controls(kind: String) -> void:
	for child in choices.get_children(): choices.remove_child(child); child.queue_free()
	match kind:
		"read","teach": _knowledge_view()
		"repair","rest":
			_target_picker()
			_button("确认维修：零件3，耐久+15" if kind == "repair" else "确认休息：全队疲劳−20","camp",{"id":kind,"target":selected_target})
		"trade":
			_faction_view(); _knowledge_view()
		"supplies":
			_target_picker()
			for resource in ["water","food"]:
				_button("所选成员本夜不领"+engine.RESOURCE_NAMES[resource]+"（将产生短缺伤害）","ration",{"id":resource,"target":selected_target,"amount":0},true)
				_button("恢复所选成员完整"+engine.RESOURCE_NAMES[resource]+"配给","ration",{"id":resource,"target":selected_target,"amount":2 if resource == "water" and engine.on_foot() else 1})
			_button("安排所选成员守夜","watch",{"id":selected_target})
			_button("本夜不安排守夜","watch",{"id":""})
			_button("夜间配给与结算","settle")
		"member":
			_button("倾听近况：1小时，信任+2、好感+3，占事务","social",{"id":"listen","target":selected_target})
			if engine.s.facts.get("departure_proposal_"+selected_target,false): _button("协商挽留：1小时、信任+10","social",{"id":"proposal_talk","target":selected_target})
			_local("查看成员安排",func(): view = "team"; refresh())

func _remember_site(id: String) -> void:
	if id != "": scene_context = {"day":engine.s.day,"legs":engine.s.legs,"site":id}

func _toggle_opening_room() -> void:
	if loading_screen.busy or not BIOMES.opening_available(engine.s): return
	if not scene_context.get("opening_inside",false) and is_instance_valid(side_stage) and is_instance_valid(side_stage.walk):
		scene_context.opening_return_x = side_stage.walk.backdrop.view_to_source(Vector2(side_stage.walk.player_x,0)).x
	scene_context.opening_inside = not scene_context.get("opening_inside",false)
	view = "journey"; refresh(); _autosave()

func _site_preview_view() -> void:
	information.text = "[b]支路地点预览[/b]\n\n这里只查看地点。实际抵达取件仍须满足当前路线、机会额度并支付原行动成本。"
	_local("返回车辆配件",func(): preview_site = ""; view = "equipment"; refresh())
