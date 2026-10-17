extends Control
## Player-facing screens over the existing rules/controller. The legacy controls
## remain hidden command sources so validation, irreversible choices and saves agree.
const PANEL = preload("res://src/ui/reference_panel.gd")
const SKIN = preload("res://src/ui/convoy_skin.gd")
const GLYPH = preload("res://src/ui/management_glyph.gd")
const ROUTES = preload("res://src/ui/management_routes.gd")
const BIOMES = preload("res://src/game/biome_catalog.gd")
const ART = preload("res://src/game/vehicle_art.gd")
const PROSE = preload("res://src/game/presentation.gd")
const MOBILE = preload("res://src/ui/mobile_layout.gd")
const GARAGE_3D = preload("res://src/ui/garage_vehicle_preview.gd")
const DESIGN = Vector2(1680,720)
const GOLD = SKIN.GOLD
const WHITE = SKIN.TEXT
const MUTED = SKIN.MUTED
const ASSETS = "res://assets/ui/convoy_management/"
const NAV = [["journey","行程"],["equipment","车辆管理"],["team","车队成员"],["inventory","物资"],["knowledge","书籍岗位"],["factions","阵营"],["goals","目标"],["log","记录"]]
var host
var content: Control
var page: Control
var modal: Control
var epoch = 0
var busy = false
var selected_item = "water"
var last_view = ""
var modal_kind = ""
var journal: RichTextLabel
var textures: Dictionary = {}
var background_picture: TextureRect
var background_shade: ColorRect
var top_shade: ColorRect
var vehicle_preview

func _extra_height() -> float:
	return maxf(0,content.size.y-DESIGN.y)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var black = ColorRect.new(); black.color = Color("070c10"); black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(black)
	content = Control.new(); content.size = DESIGN; add_child(content)
	resized.connect(_fit); _fit()

func _fit() -> void:
	if not is_instance_valid(content): return
	MOBILE.fit_tall(content,DESIGN,MOBILE.safe_rect(self))
	if is_instance_valid(page): sync()

func sync() -> void:
	if not is_instance_valid(host) or host.engine.s.is_empty(): return
	host.canvas.hide()
	visible = not is_instance_valid(host.side_stage) or not host.side_stage.visible
	if not visible: return
	epoch += 1
	if last_view != host.view: modal_kind = ""; last_view = host.view
	if is_instance_valid(vehicle_preview):
		vehicle_preview.reparent(content); vehicle_preview.hide()
	if is_instance_valid(page): content.remove_child(page); page.queue_free()
	page = Control.new(); page.name = "PlayerInterface"; page.size = content.size; content.add_child(page)
	modal = null
	_background("terrain" if host.view == "route_map" or host.view == "journey" and host.engine.s.phase == "route" else "garage")
	if host.paused: _pause_page()
	else:
		match host.view:
			"equipment": _garage()
			"team": _team()
			"inventory": _inventory()
			"knowledge": _knowledge()
			"factions": _factions()
			"goals": _goals()
			"log": _logbook()
			_:
				if host.view == "route_map" or host.view == "journey" and host.engine.s.phase == "route": _map()
				else: _story()
		if modal_kind != "": _open_modal(modal_kind)
	var message = host.error_label.text
	if message != "" and message != "已自动保存": _text(page,message,Vector2(45,638+_extra_height()),Vector2(1590,25),16,GOLD)
	SKIN.polish_tree(page,SKIN.feedback_for(host))

func _texture(path: String) -> Texture2D:
	if not textures.has(path):
		textures[path] = load(path) if ResourceLoader.exists(path) else null
	return textures[path]

func _picture(parent: Node,path: String,point: Vector2,dimensions: Vector2,cover: bool = true) -> TextureRect:
	var picture = TextureRect.new(); picture.texture = _texture(path); picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.position = point; picture.size = dimensions; picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED if cover else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.clip_contents = true; picture.mouse_filter = Control.MOUSE_FILTER_IGNORE; parent.add_child(picture); return picture

func _background(key: String) -> void:
	var source = "garage_clean" if key == "garage" else key
	var path = ASSETS+source+"_source.png"
	if key == "garage" and host.view == "equipment":
		path = ASSETS+"garage_repair_20261016/source.png"
	var rect = Rect2(-content.position/content.scale,size/content.scale)
	background_picture = _picture(page,path,rect.position,rect.size)
	background_shade = ColorRect.new(); background_shade.color = Color(0.01,0.02,0.03,0.25 if key == "terrain" else 0.27); background_shade.position = rect.position; background_shade.size = rect.size; background_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE; page.add_child(background_shade)
	top_shade = ColorRect.new(); top_shade.color = Color(0.015,0.025,0.035,0.46); top_shade.position = rect.position; top_shade.size = Vector2(rect.size.x,87-rect.position.y); top_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE; page.add_child(top_shade)

func _panel(parent: Node,point: Vector2,dimensions: Vector2,selected: bool = false) -> Control:
	return SKIN.panel(parent,point,dimensions,selected)

func _text(parent: Node,value: String,point: Vector2,dimensions: Vector2,font_size: int = 20,ink: Color = WHITE) -> Label:
	var label = Label.new(); label.text = value; label.position = point; label.size = dimensions; label.add_theme_font_size_override("font_size",font_size); label.add_theme_color_override("font_color",ink); label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; parent.add_child(label); return label

func _rich(parent: Node,value: String,point: Vector2,dimensions: Vector2,font_size: int = 18) -> RichTextLabel:
	var label = RichTextLabel.new(); label.text = value; label.bbcode_enabled = true; label.position = point; label.size = dimensions; label.add_theme_font_size_override("normal_font_size",font_size); label.add_theme_color_override("default_color",WHITE); parent.add_child(label); return label

func _box(fill: Color,border: Color) -> StyleBoxFlat:
	var box = StyleBoxFlat.new(); box.bg_color = fill; box.border_color = border; box.set_border_width_all(1); box.corner_detail = 1; box.set_corner_radius_all(7)
	box.content_margin_left = 16; box.content_margin_right = 16; box.content_margin_top = 8; box.content_margin_bottom = 8; return box

func _button(parent: Node,title: String,point: Vector2,dimensions: Vector2,callback: Callable,gold: bool = false) -> Button:
	var b = Button.new(); b.text = title; b.position = point; b.size = dimensions; b.custom_minimum_size = dimensions; b.add_theme_font_size_override("font_size",19)
	b.add_theme_stylebox_override("normal",_box(Color("713d14") if gold else Color(0.025,0.045,0.06,0.92),GOLD if gold else Color("78878d")))
	b.add_theme_stylebox_override("hover",_box(Color("365365"),Color("b5d8e6")))
	b.add_theme_stylebox_override("pressed",_box(Color("915b21") if gold else Color("284657"),Color("f6d290")))
	b.add_theme_stylebox_override("disabled",_box(Color(0.035,0.045,0.05,0.9),Color("46525a")))
	b.add_theme_stylebox_override("focus",_box(Color(0.1,0.2,0.24,0.2),Color("c5dfeb")))
	b.add_theme_color_override("font_color",WHITE); b.add_theme_color_override("font_disabled_color",Color("78848a"))
	b.pressed.connect(callback); parent.add_child(b); SKIN.button(b,gold,SKIN.feedback_for(host)); return b

func _glyph(parent: Node,kind: String,point: Vector2,dimensions: Vector2,ink: Color = WHITE) -> void:
	var glyph = GLYPH.new(); glyph.kind = kind; glyph.position = point; glyph.size = dimensions; glyph.ink = ink; parent.add_child(glyph)

func _bar(parent: Node,title: String,value: String,ratio: float,point: Vector2,width: float,color: Color = GOLD) -> void:
	_text(parent,title,point,Vector2(85,24),15,MUTED)
	_text(parent,value,point+Vector2(width-120,0),Vector2(120,24),15,WHITE).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var track = ColorRect.new(); track.color = Color("303c40"); track.position = point+Vector2(88,9); track.size = Vector2(width-220,7); track.mouse_filter = Control.MOUSE_FILTER_IGNORE; parent.add_child(track)
	var fill = ColorRect.new(); fill.color = color; fill.size = Vector2(track.size.x*clampf(ratio,0,1),7); fill.mouse_filter = Control.MOUSE_FILTER_IGNORE; track.add_child(fill)

func _header(title: String,subtitle: String) -> void:
	_glyph(page,"vehicle",Vector2(35,22),Vector2(44,44),GOLD)
	SKIN.title(_text(page,title,Vector2(95,11),Vector2(950,48),36,GOLD))
	_text(page,subtitle,Vector2(97,56),Vector2(1010,25),16,MUTED)
	_text(page,"第 %02d 天  /  20    ·    %s" % [host.engine.s.day,host.engine.s.daily.weather],Vector2(1050,20),Vector2(280,35),20).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if not host.paused: _button(page,"菜单",Vector2(1350,23),Vector2(144,40),func(): _open_modal("navigation"))
	_button(page,"暂停",Vector2(1520,23),Vector2(116,40),host._pause)

func _go(view_name: String) -> void:
	modal_kind = ""; host.view = view_name; host.refresh()

func _proxy(parent: Node,original: Button,point: Vector2,dimensions: Vector2,title: String = "") -> Button:
	var saved_epoch = epoch; var source = original
	var b = _button(parent,original.text if title == "" else title,point,dimensions,func():
		if busy or host.loading_screen.busy or saved_epoch != epoch or host.confirmation.visible or not is_instance_valid(source) or source.disabled: return
		busy = true; source.pressed.emit(); busy = false
		if saved_epoch == epoch and not host.loading_screen.busy: sync())
	b.disabled = original.disabled; b.tooltip_text = original.tooltip_text
	for key in original.get_meta_list(): b.set_meta(key,original.get_meta(key))
	return b

func _command(parent: Node,title: String,action: String,args: Dictionary,point: Vector2,dimensions: Vector2,gold: bool = false) -> Button:
	var before = host.engine.checkpoint(); var old_error = host.engine.error
	var available = host.engine.command(action,args); var reason = host.engine.error
	host.engine.restore(before); host.engine.error = old_error
	var saved_epoch = epoch
	var b = _button(parent,title,point,dimensions,func():
		if busy or host.loading_screen.busy or saved_epoch != epoch or host.confirmation.visible: return
		busy = true; host._issue(action,args,false,title); busy = false,gold)
	b.disabled = not available; b.tooltip_text = reason if not available else title; b.set_meta("action_id",action); b.set_meta("command_args",args.duplicate(true)); return b

func _source(action: String,id: String = "") -> Button:
	for child in host.choices.get_children():
		if child is Button and child.get_meta("action_id","") == action and (id == "" or str(child.get_meta("command_args",{}).get("id","")) == id): return child
	return null

func _scroller(parent: Node,point: Vector2,dimensions: Vector2,columns: int = 1) -> GridContainer:
	var scroll = ScrollContainer.new(); scroll.position = point; scroll.size = dimensions; scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; parent.add_child(scroll)
	var grid = GridContainer.new(); grid.columns = columns; grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL; grid.add_theme_constant_override("h_separation",12); grid.add_theme_constant_override("v_separation",10); scroll.add_child(grid); return grid

func _actions(parent: Node,point: Vector2,dimensions: Vector2,filter: Callable = Callable(),columns: int = 1) -> void:
	var grid = _scroller(parent,point,dimensions,columns)
	for original in host.choices.get_children():
		if filter.is_valid() and not filter.call(original): continue
		if original is OptionButton:
			var source = original; var picker = OptionButton.new(); picker.custom_minimum_size = Vector2(100,44); picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			for i in source.item_count: picker.add_item(source.get_item_text(i))
			picker.select(source.selected); picker.item_selected.connect(func(i): source.item_selected.emit(i)); grid.add_child(picker)
		elif original is Button:
			var b = _proxy(grid,original,Vector2.ZERO,Vector2((dimensions.x-26)/columns-12,54)); b.size_flags_horizontal = Control.SIZE_EXPAND_FILL; b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; b.alignment = HORIZONTAL_ALIGNMENT_LEFT; b.add_theme_font_size_override("font_size",17)

func _garage() -> void:
	_header("车队营地  |  车辆管理","选择车辆查看状态与改装    ·    车辆 %d    ·    总货重 %.1f / %.1f 千克" % [host.engine.s.vehicles.size(),host.engine.weight(),host.engine.capacity()])
	var cars: Array = host.engine.s.vehicles
	host.selected_vehicle = clampi(host.selected_vehicle,0,maxi(0,cars.size()-1))
	var row = _scroller(page,Vector2(42,110),Vector2(1596,224),maxi(4,cars.size()))
	row.get_parent().horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO; row.get_parent().vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	for i in maxi(4,cars.size()):
		var index = i; var card = _panel(row,Vector2.ZERO,Vector2(384,212),i == host.selected_vehicle and i < cars.size()); card.custom_minimum_size = Vector2(384,212)
		if i >= cars.size():
			_glyph(card,"vehicle",Vector2(161,48),Vector2(62,62),Color("47535c"))
			_text(card,"未编入车辆",Vector2(25,117),Vector2(334,30),20,MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_text(card,"在旅途中寻找可用车辆",Vector2(25,150),Vector2(334,27),15,Color("647782")).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			continue
		var v: Dictionary = cars[i]
		var art = GARAGE_3D.card_model(v,i); _picture(card,ART.ART+art+"_right.png",Vector2(22,31),Vector2(338,99),false)
		_text(card,str(v.name),Vector2(20,10),Vector2(290,30),22,GOLD if i == host.selected_vehicle else WHITE)
		_text(card,"主车" if i == host.engine.s.main_vehicle else ("报废" if v.destroyed else "随行"),Vector2(298,13),Vector2(68,25),15,MUTED)
		_bar(card,"耐久","%.0f / 100" % v.durability,float(v.durability)/100,Vector2(20,132),344)
		var load_value = host.engine.vehicle_weight(v); var capacity = host.engine.vehicle_capacity(v)
		_bar(card,"载重","%.0f / %.0f" % [load_value,capacity],load_value/maxf(1,capacity),Vector2(20,155),344,Color("7faab7"))
		var quote = host.engine.route_quote(host.route,host.style)
		_bar(card,"燃料·共用","%.0f" % host.engine.s.resources.fuel,float(host.engine.s.resources.fuel)/maxf(1,float(quote.fuel)),Vector2(20,178),344)
		var saved_epoch = epoch
		var click = Button.new(); click.flat = true; click.set_meta("skin_skip",true); click.set_meta("garage_vehicle",index); click.position = Vector2(2,2); click.size = Vector2(380,208); click.tooltip_text = "切换展示："+str(v.name); click.pressed.connect(func():
			if busy or host.loading_screen.busy or saved_epoch != epoch or host.confirmation.visible or index >= host.engine.s.vehicles.size(): return
			host.selected_vehicle = index; modal_kind = ""; host.refresh())
		card.add_child(click)
		if i == host.selected_vehicle: row.get_parent().call_deferred("ensure_control_visible",card)
	var extra = _extra_height()
	if cars.is_empty():
		_text(page,"目前没有车辆。可从整备事务中寻找废车。",Vector2(48,410),Vector2(1240,80),25,MUTED)
	else:
		var show_model = get_tree().root.get_meta("garage_vehicle_debug",false) or GARAGE_3D.has_confirmed_placement()
		if show_model:
			if not is_instance_valid(vehicle_preview):
				vehicle_preview = GARAGE_3D.new(); page.add_child(vehicle_preview)
			else: vehicle_preview.reparent(page)
			vehicle_preview.configure(cars[host.selected_vehicle],extra,host.selected_vehicle); vehicle_preview.show()
			page.move_child(vehicle_preview,3)
			vehicle_preview.turntable_paused = host.paused or modal_kind != ""
			var model_id = vehicle_preview.vehicle_id
			_text(page,model_id+" "+GARAGE_3D.MODELS.NAMES[model_id]+(" · 简化3D预览" if model_id != "V05" else " · 3D展示")+(" · 自动旋转" if vehicle_preview.turntable_enabled else " · 旋转已暂停"),Vector2(50,345),Vector2(880,30),17,MUTED)
		else:
			_text(page,"点击上方车辆切换展示",Vector2(50,345),Vector2(880,30),22,MUTED)
		var detail = _button(page,"状态与改装",Vector2(1074,337),Vector2(230,44),func(): _open_modal("vehicle"))
		detail.set_meta("garage_vehicle_detail",host.selected_vehicle)
		if show_model:
			var spin = _button(page,"暂停旋转" if vehicle_preview.turntable_enabled else "继续旋转",Vector2(894,337),Vector2(164,44),func():
				vehicle_preview.set_turntable_enabled(not vehicle_preview.turntable_enabled); host.refresh())
			spin.set_meta("garage_spin_toggle",true)
	_resources_panel(Vector2(1342,349+extra*0.45),Vector2(294,228))
	_button(page,"整备事务",Vector2(310,595+extra),Vector2(260,48),func(): _open_modal("equipment"))
	_button(page,"分配物资",Vector2(594,595+extra),Vector2(260,48),func(): _open_modal("cargo"))
	_button(page,"出发  ›",Vector2(878,595+extra),Vector2(320,48),func(): _go("route_map"),true)

func _vehicle_detail(panel: Control) -> void:
	if host.selected_vehicle < 0 or host.selected_vehicle >= host.engine.s.vehicles.size(): return
	var v: Dictionary = host.engine.s.vehicles[host.selected_vehicle]
	_text(panel,"耐久 %.0f / 100    ·    载重 %.0f / %.0f 千克    ·    燃料由车队共用" % [v.durability,host.engine.vehicle_weight(v),host.engine.vehicle_capacity(v)],Vector2(28,73),Vector2(1140,30),19,MUTED)
	var keys = host.engine.SLOTS.keys()
	var row = _scroller(panel,Vector2(27,123),Vector2(1146,361),5)
	for i in keys.size():
		var key = str(keys[i]); var card = _panel(row,Vector2.ZERO,Vector2(214,307),host.selected_slot == key); card.custom_minimum_size = Vector2(214,307)
		_module_icon(card,i,key,Vector2(70,17),Vector2(74,74))
		_text(card,host.engine.SLOTS[key],Vector2(18,103),Vector2(178,31),22).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var id = str(v.modules.get(key,"")); var mod: Dictionary = host.engine.content.modules.get(id,{})
		_text(card,str(mod.get("name","空槽位")),Vector2(18,145),Vector2(178,54),18,GOLD if id != "" else MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var available_cores = 0
		for module in host.engine.content.modules:
			if host.engine.content.modules[module].slot == key: available_cores += int(host.engine.s.cores.get(module,0))
		_text(card,"重量 %s kg · 核心 %d" % [str(mod.get("weight",0)),available_cores] if id != "" else "可用核心  %d" % available_cores,Vector2(14,211),Vector2(186,27),16,MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var button = _button(card,"查看改装",Vector2(16,255),Vector2(182,44),func(): host.selected_slot = key; modal_kind = "modules"; host.refresh())
		button.set_meta("vehicle_slot",key)
	_text(panel,"选择槽位，查看可安装配件与所需物资",Vector2(29,490),Vector2(1140,28),16,MUTED)

func _navigation(panel: Control) -> void:
	var grid = _scroller(panel,Vector2(27,83),Vector2(1146,426),2)
	for item in NAV:
		var key = str(item[0]); var active = host.view == key or key == "journey" and host.view == "route_map"
		var button = _button(grid,str(item[1]),Vector2.ZERO,Vector2(553,84),func(): _go(key),active)
		button.set_meta("menu_view",key)

func _module_icon(parent: Node,index: int,key: String,point: Vector2,dimensions: Vector2) -> void:
	if _texture(ASSETS+"module_"+key+".png") != null:
		_picture(parent,ASSETS+"module_"+key+".png",point,dimensions,false)
	else: _glyph(parent,key,point,dimensions)

func _resources_panel(point: Vector2,dimensions: Vector2) -> void:
	var panel = _panel(page,point,dimensions); _text(panel,"车队物资",Vector2(20,11),Vector2(230,30),22)
	var keys = ["fuel","parts","food","water"]
	for i in keys.size():
		var key = keys[i]; _glyph(panel,key,Vector2(20,52+i*41),Vector2(27,27),MUTED)
		_text(panel,host.engine.RESOURCE_NAMES[key],Vector2(61,51+i*41),Vector2(108,28),18,MUTED)
		_text(panel,str(host.engine.s.resources[key]),Vector2(170,51+i*41),Vector2(102,28),21).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func _route_title(key: String) -> String:
	return {"safe":"安全路段","resource":host.engine.RESOURCE_NAMES.get(host.selected_supply,"物资")+"补给线","unknown":"未知路段","stay":"原地停留"}.get(key,key)

func _route_site() -> String:
	if host.route == "stay": return BIOMES.campsite(host.engine.s)
	if host.route == "safe": return BIOMES.road(host.engine.s,true)
	if host.route == "unknown": return BIOMES.site_in_region("scrapyard",host.engine.s)
	return BIOMES.site_in_region({"water":"waterworks","food":"supply_warehouse","fuel":"fuel_depot","parts":"scrapyard"}.get(host.selected_supply,"gas_station"),host.engine.s)

func _map() -> void:
	var s = host.engine.s
	var extra = _extra_height()
	_header("大地图  /  路线选择","%s区域    ·    已完成主路 %d 段    ·    主边剩余 %.0f 千米" % [{"forest":"林地","desert":"荒漠","pine":"松林","snow":"雪原"}.get(BIOMES.region(s,true),"当前"),s.legs,30-s.edge_km])
	var map = Control.new(); map.position = Vector2(26,98+extra*0.35); map.size = Vector2(1190,480); page.add_child(map)
	var drawing = ROUTES.new(); drawing.size = map.size; drawing.selected = host.route; map.add_child(drawing)
	_text(map,"区域路线示意",Vector2(20,440),Vector2(280,26),15,MUTED)
	_glyph(map,"vehicle",Vector2(272,345),Vector2(56,48),Color("9ad8f2"))
	_button(map,"当前位置 · 停留",Vector2(214,400),Vector2(190,39),func(): host.route = "stay"; host.refresh(),host.route == "stay")
	for key in ["safe","resource","unknown"]:
		var id = str(key); var p: Vector2 = drawing.paths[key][-1]
		var b = _button(map,("◇  " if key == "unknown" else "◆  ")+_route_title(key),p+Vector2(-96,-64),Vector2(202,47),func(): host.route = id; host.refresh(),host.route == key)
		b.set_meta("route_id",key)
	_text(map,"荒废城镇",Vector2(105,200),Vector2(140,27),18,MUTED)
	_text(map,"山脉",Vector2(580,25),Vector2(140,27),18,MUTED)
	var selected = _panel(page,Vector2(1250,109+extra*0.35),Vector2(386,458),true)
	_text(selected,_route_title(host.route),Vector2(20,14),Vector2(340,35),25)
	var site = _route_site()
	_picture(selected,"res://assets/locations/atlas_widescreen_20261016/"+site+"/full.jpg",Vector2(17,61),Vector2(350,117))
	var q: Dictionary = host.engine.route_quote(host.route,host.style)
	var rows = [["行驶距离","%.0f km" % q.distance],["燃料消耗","%.1f" % q.fuel],["预计耗时","%.1f 小时" % q.hours],["疲劳增加","+%.0f" % q.fatigue],["途中事件","%.0f%%" % q.event_rate]]
	for i in rows.size():
		_text(selected,rows[i][0],Vector2(22,197+i*41),Vector2(180,28),18,MUTED)
		_text(selected,rows[i][1],Vector2(200,197+i*41),Vector2(160,28),22,GOLD if i == 4 else WHITE).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_text(selected,"风险  "+("低" if q.event_rate <= 20 else ("中" if q.event_rate <= 35 else "高"))+"    ·    噪声 %d" % q.noise,Vector2(22,411),Vector2(340,28),17,Color("e9b18a"))
	_text(page,"行驶方式",Vector2(49,590+extra),Vector2(110,25),18,MUTED)
	var styles = [["quiet","低噪音"],["fast","快速"],["detour","绕行"]]
	for i in styles.size():
		var key = str(styles[i][0]); _button(page,styles[i][1],Vector2(160+i*154,578+extra),Vector2(141,48),func(): host.style = key; host.refresh(),host.style == key)
	if host.route == "resource":
		var supplies = host.engine.supply_types()
		for i in supplies.size():
			var key = str(supplies[i]); _button(page,host.engine.RESOURCE_NAMES[key]+"供给",Vector2(649+i*153,578+extra),Vector2(140,48),func(): host.selected_supply = key; host.refresh(),host.selected_supply == key)
	var depart = _source("depart")
	if depart != null:
		var b = _proxy(page,depart,Vector2(1250,590+extra),Vector2(223,48),"确认出发  ›"); SKIN.button(b,true,SKIN.feedback_for(host))
	else:
		var b = _button(page,"等待晨间准备" if s.phase == "morning" else "今日行程已安排",Vector2(1250,590+extra),Vector2(223,48),func(): pass,true); b.disabled = true; b.tooltip_text = "先在当前行程中完成准备，即可确认出发。"
	_button(page,"返回车队",Vector2(1486,590+extra),Vector2(150,48),func(): _go("equipment"))
	_button(page,"主线与路况" if s.phase == "route" else "前往当前行程",Vector2(1010,578+extra),Vector2(196,48),func():
		if s.phase == "route": _open_modal("route")
		else: _go("journey"))
	_text(page,"无法出发："+depart.tooltip_text if depart != null and depart.disabled else "选择地点与行驶方式后确认出发",Vector2(50,630+extra),Vector2(1120,25),16,MUTED)

func _portrait(parent: Node,id: String,point: Vector2,dimensions: Vector2) -> void:
	var key = {"captain":"captain","zhang":"mechanic","elin":"medic","ajie":"scout","sofia":"quartermaster"}.get(id,"")
	if key != "": _picture(parent,"res://assets/ui/status_overview/"+key+".png",point,dimensions)
	else: _glyph(parent,"vehicle",point,dimensions,MUTED)

func _team() -> void:
	_header("车队成员","%d 人在队    ·    信任 %d    ·    好感 %.0f    ·    选择成员安排事务" % [host.engine.people().size(),host.engine.trust(),host.engine.affection()])
	var row = _scroller(page,Vector2(44,111),Vector2(1592,268),host.engine.s.members.size())
	row.get_parent().horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO; row.get_parent().vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	for m in host.engine.s.members:
		var id = str(m.id); var card = _panel(row,Vector2.ZERO,Vector2(300,252),id == host.selected_target); card.custom_minimum_size = Vector2(300,252)
		_portrait(card,id,Vector2(10,10),Vector2(110,142)); _text(card,m.name,Vector2(135,22),Vector2(150,32),24)
		_text(card,"在队" if m.active and m.alive else ("离队" if m.alive else "已故"),Vector2(135,64),Vector2(140,27),17,MUTED)
		_text(card,"信任 %.0f\n好感 %.0f" % [m.trust,m.like],Vector2(135,96),Vector2(145,60),17,GOLD)
		_bar(card,"健康","%.0f" % m.health,m.health/100.0,Vector2(15,163),270,Color("8cb79b"))
		_bar(card,"疲劳","%.0f" % m.fatigue,m.fatigue/100.0,Vector2(15,188),270)
		var saved_epoch = epoch
		var click = Button.new(); click.flat = true; click.set_meta("skin_skip",true); click.set_meta("team_member",id); click.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		click.tooltip_text = "查看"+str(m.name)+"的详情"
		for state in ["normal","hover","pressed","disabled","focus"]: click.add_theme_stylebox_override(state,StyleBoxEmpty.new())
		click.pressed.connect(func():
			if busy or host.loading_screen.busy or saved_epoch != epoch or host.confirmation.visible: return
			host.selected_target = id; host.refresh())
		card.add_child(click); click.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var person: Dictionary = host.engine.person(host.selected_target)
	var detail = _panel(page,Vector2(44,394),Vector2(720,239),true)
	_text(detail,str(person.get("name","成员"))+" · 岗位与经历",Vector2(24,16),Vector2(660,35),24)
	_text(detail,"维修 %.0f    医疗 %.0f    侦察 %.0f    后勤 %.0f" % [person.get("repair",0),person.get("medical",0),person.get("scout",0),person.get("logistics",0)],Vector2(24,66),Vector2(670,32),20,GOLD)
	_rich(detail,PROSE.readable(str(person.get("memory",""))),Vector2(24,112),Vector2(670,100),19)
	_actions(page,Vector2(790,395),Vector2(846,238),func(b): return not b is OptionButton)

func _inventory() -> void:
	_header("车队物资","货重 %.1f / %.1f 千克    ·    笔记 %d 页    ·    选择物资查看搬运选项" % [host.engine.weight(),host.engine.capacity(),host.engine.s.pages])
	var keys = host.engine.s.resources.keys()
	for i in keys.size():
		var key = str(keys[i]); var col = i%4; var row = i/4
		var card = _panel(page,Vector2(44+col*278,116+row*185),Vector2(261,164),selected_item == key)
		_glyph(card,key,Vector2(20,30),Vector2(63,63),GOLD)
		_text(card,host.engine.RESOURCE_NAMES[key],Vector2(105,24),Vector2(140,30),22)
		_text(card,str(host.engine.s.resources[key]),Vector2(105,68),Vector2(140,49),37)
		_button(card,"管理物资",Vector2(18,122),Vector2(225,31),func(): selected_item = key; sync()).add_theme_font_size_override("font_size",15)
	var detail = _panel(page,Vector2(1183,116),Vector2(453,402),true)
	_text(detail,host.engine.RESOURCE_NAMES.get(selected_item,selected_item),Vector2(24,22),Vector2(400,40),27)
	_text(detail,"丢弃会永久移除物资。\n操作前显示确认。",Vector2(24,78),Vector2(400,80),19,MUTED)
	_actions(detail,Vector2(22,178),Vector2(411,201),func(b): return b.get_meta("action_id","") == "drop" and b.get_meta("command_args",{}).get("id","") == selected_item)
	var weight_panel = _panel(page,Vector2(44,507),Vector2(1111,126)); _text(weight_panel,"携行空间",Vector2(24,15),Vector2(300,30),23)
	_bar(weight_panel,"货物","%.1f / %.1f kg" % [host.engine.weight(),host.engine.capacity()],host.engine.weight()/maxf(1,host.engine.capacity()),Vector2(24,70),1060)
	_button(page,"书籍、核心与其他物品",Vector2(1183,548),Vector2(453,55),func(): _open_modal("items"))

func _knowledge() -> void:
	_header("知识与岗位","知识 %d    ·    制度 %d    ·    已验证方法 %d 条" % [host.engine.s.knowledge,host.engine.s.institution,host.engine.s.records.size()])
	var keys = host.engine.BOOKS.keys()
	for i in keys.size():
		var key = str(keys[i]); var card = _panel(page,Vector2(44+i*400,117),Vector2(382,180),host.selected_role == key)
		_glyph(card,"roof" if key == "scout" else ("medicine" if key == "medical" else "parts"),Vector2(24,25),Vector2(64,64),GOLD)
		_text(card,host.engine.BOOKS[key],Vector2(112,25),Vector2(245,38),25)
		_text(card,"库存 %d 册" % host.engine.s.books.get(key,0),Vector2(112,73),Vector2(240,30),18,MUTED)
		_button(card,"选择岗位",Vector2(24,127),Vector2(334,35),func(): host.selected_role = key; host.refresh(),host.selected_role == key)
	var panel = _panel(page,Vector2(44,320),Vector2(470,315)); _text(panel,"学习安排",Vector2(24,18),Vector2(420,35),26)
	_rich(panel,"阅读可提高理解与知识。\n\n正式教学依教师能力与学员信任判定。应急自学需要对应书籍、理解与基础能力。",Vector2(24,76),Vector2(420,210),21)
	_actions(page,Vector2(540,320),Vector2(1096,315),Callable(),2)

func _factions() -> void:
	_header("阵营事务","公平交易 %d 次    ·    掠夺 %d 次    ·    每日主要事务 %d / 2" % [host.engine.s.trades,host.engine.s.raids,host.engine.s.daily.tasks])
	var keys = ["east","south","guild"]; var names = ["东岸聚落","南边定居点","公路商会"]
	for i in keys.size():
		var key = str(keys[i]); var panel = _panel(page,Vector2(44+i*537,116),Vector2(520,187),key == host.selected_faction)
		_glyph(panel,"roof" if i != 2 else "supplies",Vector2(26,28),Vector2(69,69),GOLD)
		_text(panel,names[i],Vector2(122,23),Vector2(350,36),26)
		_text(panel,"关系 %d    ·    %s" % [host.engine.s.factions[key],"已接触" if key in host.engine.s.contacts else "尚未接触"],Vector2(122,71),Vector2(365,30),19,MUTED)
		_button(panel,"选择阵营",Vector2(26,131),Vector2(466,37),func(): host.selected_faction = key; host.refresh(),key == host.selected_faction)
	_actions(page,Vector2(44,330),Vector2(1592,307),func(b): return b.get_meta("action_id","") != "",3)

func _goals() -> void:
	_header("旅程目标","选择目标查看条件并完成实际行动    ·    主路 %d 段" % host.engine.s.legs)
	var panel = _panel(page,Vector2(44,117),Vector2(1592,516))
	_actions(panel,Vector2(20,20),Vector2(1552,476),func(b): return b.get_meta("action_id","") == "goal",2)

func _logbook() -> void:
	_header("车队记录","沿途的选择与实际发生的变化")
	var panel = _panel(page,Vector2(331,116),Vector2(1305,517)); journal = _rich(panel,host.information.text,Vector2(30,25),Vector2(1245,467),21)
	_button(page,"今日记录",Vector2(44,116),Vector2(260,48),func(): journal.text = "[b]今日实际变化[/b]\n\n"+PROSE.journal(host.engine.s.daily.log),true)
	var grid = _scroller(page,Vector2(44,180),Vector2(260,450))
	for row in host.engine.s.history:
		var entry: Dictionary = row.duplicate(true); _button(grid,"第 %d 天" % row.day,Vector2.ZERO,Vector2(240,46),func(): journal.text = "[b]第 %d 天[/b]\n\n" % entry.day+PROSE.journal(entry.log))

func _story() -> void:
	var s = host.engine.s
	_header("末日车队  |  "+{"night":"夜间结算","split":"车队决定","ending":"旅程终局","event":"途中事件","rescue":"实际救援","rescue_seats":"安全安置","site_preview":"地点预览"}.get(host.view if host.view == "site_preview" else str(s.phase),"当前行程"),"第 %d 天    ·    %.1f / 12 小时    ·    事务 %d / 2" % [s.day,s.daily.hours,s.daily.tasks])
	var site = host.preview_site if host.view == "site_preview" else BIOMES.scene_for(s,host.view,host.active_card,host.scene_context)
	background_picture.texture = _texture("res://assets/locations/atlas_widescreen_20261016/"+site+"/full.jpg")
	var panel = _panel(page,Vector2(44,321+_extra_height()),Vector2(1592,319),true)
	_rich(panel,host.information.text,Vector2(24,22),Vector2(700,270),20)
	_actions(panel,Vector2(753,22),Vector2(815,270))

func _pause_page() -> void:
	_header("末日车队  |  已暂停","进度已自动保存")
	var panel = _panel(page,Vector2(460,160+_extra_height()*0.5),Vector2(760,440),true)
	_text(panel,"继续旅程",Vector2(40,28),Vector2(670,46),34)
	_rich(panel,host.information.text,Vector2(40,96),Vector2(680,100),19)
	_actions(panel,Vector2(40,212),Vector2(680,196))

func _open_modal(kind: String) -> void:
	if kind in ["vehicle","modules"] and host.engine.s.vehicles.is_empty(): return
	modal_kind = kind
	if is_instance_valid(vehicle_preview): vehicle_preview.turntable_paused = true
	if is_instance_valid(modal): page.remove_child(modal); modal.queue_free()
	modal = Control.new(); modal.name = "ManagementDetail"; modal.size = content.size; page.add_child(modal)
	var shade = ColorRect.new(); shade.color = Color(0,0.008,0.012,0.82); shade.position = -content.position/content.scale; shade.size = size/content.scale; modal.add_child(shade)
	var panel = _panel(modal,Vector2(240,95+_extra_height()*0.5),Vector2(1200,537),true)
	var vehicle_name = str(host.engine.s.vehicles[host.selected_vehicle].name) if kind in ["vehicle","modules"] else ""
	var titles = {"equipment":"车辆整备事务","cargo":"人员与物资分配","vehicle":vehicle_name+" · 改装槽位","modules":vehicle_name+" · "+host.engine.SLOTS.get(host.selected_slot,""),"navigation":"车队菜单","route":"主线、情报与路况","items":"书籍、核心与其他物品"}
	_text(panel,titles.get(kind,"详情"),Vector2(28,17),Vector2(740 if kind == "modules" else 1000,40),28)
	_button(panel,"‹ 车辆" if kind == "modules" else "关闭 ×",Vector2(1042,17),Vector2(130,44),_close_modal)
	if kind == "vehicle": _vehicle_detail(panel); SKIN.polish_tree(modal,SKIN.feedback_for(host)); return
	if kind == "navigation": _navigation(panel); SKIN.polish_tree(modal,SKIN.feedback_for(host)); return
	if kind == "modules": _module_choices(panel); SKIN.polish_tree(modal,SKIN.feedback_for(host)); return
	var filter = func(b):
		var action = str(b.get_meta("action_id","")); var args: Dictionary = b.get_meta("command_args",{})
		match kind:
			"route": return action != "depart" and (action != "" or b is OptionButton or "人物事务" in b.text or "离队" in b.text)
			"cargo": return action in ["assign_vehicle","transfer","container"] or b is OptionButton
			"equipment": return action not in ["assign_vehicle","transfer","container"] and not (action == "camp" and args.get("id","") in ["install","remove"]) and (action != "" or "查看" in b.text and not "查看车辆" in b.text)
			"items": return action == "drop_item"
		return true
	_actions(panel,Vector2(27,82),Vector2(1146,427),filter,2)
	SKIN.polish_tree(modal,SKIN.feedback_for(host))

func _module_choices(panel: Control) -> void:
	var slot = host.selected_slot
	var grid = _scroller(panel,Vector2(25,79),Vector2(1150,428),2)
	for id in host.engine.content.modules:
		var mod: Dictionary = host.engine.content.modules[id]
		if mod.slot != slot: continue
		var item = _panel(grid,Vector2.ZERO,Vector2(553,244)); item.custom_minimum_size = Vector2(553,244)
		_text(item,id+"  "+str(mod.name),Vector2(18,13),Vector2(510,30),22,GOLD)
		_rich(item,str(mod.effect),Vector2(18,51),Vector2(514,102),17)
		_text(item,"核心 %d    ·    零件 %d    ·    重量 %d kg" % [host.engine.s.cores.get(id,0),mod.cost,mod.weight],Vector2(18,163),Vector2(510,27),16,MUTED)
		_command(item,"安装", "camp",{"id":"install","vehicle":host.selected_vehicle,"module":id},Vector2(18,200),Vector2(248,34),true)
		if host.engine.s.day >= 15:
			_command(item,"补购核心","buy_core",{"id":id},Vector2(282,200),Vector2(248,34))
		else:
			_text(item,"核心在旅途中获取",Vector2(284,204),Vector2(245,28),15,MUTED)
	var remove = _source("camp","remove")
	if remove != null: _proxy(panel,remove,Vector2(795,20),Vector2(225,35),"拆除当前配件")

func _close_modal() -> void:
	if modal_kind == "modules":
		_open_modal("vehicle")
	else:
		modal_kind = ""; page.remove_child(modal); modal.queue_free(); modal = null
		if is_instance_valid(vehicle_preview): vehicle_preview.turntable_paused = false

func _unhandled_key_input(event: InputEvent) -> void:
	if visible and is_instance_valid(modal) and event.is_action_pressed("ui_cancel"):
		_close_modal(); get_viewport().set_input_as_handled()
