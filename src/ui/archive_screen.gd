extends Control
## Title-page selection and in-game archives share the same six real save slots.
signal closed
signal load_requested(payload: Dictionary)
signal new_game_requested(slot: String)

const SKIN = preload("res://src/ui/convoy_skin.gd")
const MOBILE = preload("res://src/ui/mobile_layout.gd")
const COVER = preload("res://assets/settings/settings_background.png")
const DESIGN = Vector2(1280,720)
const GOLD = Color("f0bd7e")
const TEXT = Color("f4f1e9")
const MUTED = Color("c5ced5")
var save_system
var source
var feedback
var body: Control
var page: Control
var confirmation: Control
var background: TextureRect
var selected_slot = "slot_1"
var mode = "load"
var card_page = 0
var notice = ""
var entries: Dictionary = {}
var note_edit: TextEdit
var pending_action: Callable

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = ConvoyTheme.create()
	background = TextureRect.new(); background.texture = COVER; background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED; background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background); background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade = ColorRect.new(); shade.color = Color(0.008,0.018,0.028,0.2); shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body = Control.new(); body.size = DESIGN; add_child(body)
	if feedback == null: feedback = SKIN.FEEDBACK.new(); add_child(feedback)
	resized.connect(_fit); _fit(); hide()

func _fit() -> void:
	if is_instance_valid(body): MOBILE.fit(body,DESIGN,MOBILE.safe_rect(self))

func open_screen(store,game = null,intent: String = "load") -> void:
	save_system = store; source = game; mode = "save" if is_instance_valid(source) else intent
	clear_confirmation(); notice = ""; card_page = 0
	_reload()
	selected_slot = "slot_1"
	if mode in ["save","new"]:
		for slot in save_system.manual_slots():
			if not entries[slot].exists: selected_slot = slot; break
	else:
		var latest = save_system.latest_slot()
		if latest != "": selected_slot = latest
	if selected_slot.begins_with("slot_"): card_page = (int(selected_slot.trim_prefix("slot_"))-1)/3
	_render(); _fit(); show()

func close_screen() -> void:
	clear_confirmation(); hide(); closed.emit()

func _reload() -> void:
	entries.clear()
	for slot in save_system.manual_slots(): entries[slot] = save_system.slot_info(slot)
	entries.auto = save_system.slot_info("auto")

func _label(parent: Node,value: String,point: Vector2,dimensions: Vector2,font_size: int = 18,ink: Color = TEXT) -> Label:
	var label = Label.new(); label.text = value; label.position = point; label.size = dimensions
	label.add_theme_font_size_override("font_size",font_size); label.add_theme_color_override("font_color",ink)
	label.add_theme_color_override("font_outline_color",Color(0.005,0.01,0.015,0.95)); label.add_theme_constant_override("outline_size",3)
	label.add_theme_color_override("font_shadow_color",Color(0,0,0,0.85)); label.add_theme_constant_override("shadow_offset_y",1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE; label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label); return label

func _button(parent: Node,title: String,point: Vector2,dimensions: Vector2,callback: Callable,primary: bool = false,action: String = "") -> Button:
	var button = Button.new(); button.text = title; button.position = point; button.size = dimensions
	button.add_theme_font_size_override("font_size",18); button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.set_meta("archive_action",action); button.pressed.connect(callback); parent.add_child(button)
	SKIN.button(button,primary,feedback)
	button.add_theme_color_override("font_color",GOLD); button.add_theme_color_override("font_disabled_color",Color("98a2ab"))
	for event in [button.mouse_entered,button.mouse_exited,button.focus_entered,button.focus_exited,button.button_down,button.button_up,button.draw]:
		event.connect(func(): _button_contrast(button))
	_button_contrast(button); return button

func _button_contrast(button: Button) -> void:
	var border = button.get_node("ArwesFrame")
	var highlighted = not button.disabled and (button.is_hovered() or button.has_focus())
	var primary = bool(button.get_meta("title_primary",false))
	border.fill = Color(0.065,0.045,0.025,0.94) if primary else Color(0.012,0.025,0.038,0.91 if highlighted else 0.86)
	border.line = GOLD if primary or highlighted else Color("9babb6")
	if button.disabled: border.fill.a = 0.72; border.line = Color("63717b")
	border.queue_redraw()

func _image(parent: Node,path: String,point: Vector2,dimensions: Vector2) -> void:
	var picture = TextureRect.new(); picture.texture = load(path) if path.begins_with("res://assets/") and ResourceLoader.exists(path) else COVER
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.position = point; picture.size = dimensions; picture.clip_contents = true; picture.mouse_filter = Control.MOUSE_FILTER_IGNORE; parent.add_child(picture)

static func duration(seconds: float) -> String:
	var total = maxi(0,int(seconds)); return "%02d:%02d:%02d" % [total/3600,(total/60)%60,total%60]

func _render() -> void:
	if is_instance_valid(page): body.remove_child(page); page.queue_free()
	note_edit = null
	page = Control.new(); page.size = DESIGN; body.add_child(page)
	SKIN.title(_label(page,"存档位" if is_instance_valid(source) else "旅途存档",Vector2(65,40),Vector2(700,65),46,GOLD))
	_label(page,"CONVOY  /  JOURNEY ARCHIVE",Vector2(68,108),Vector2(520,26),12,Color("a88c6b"))
	var line = ColorRect.new(); line.position = Vector2(66,142); line.size = Vector2(1148,1); line.color = Color(0.75,0.58,0.37,0.32); line.mouse_filter = Control.MOUSE_FILTER_IGNORE; page.add_child(line)
	if is_instance_valid(source): _game_layout()
	else: _menu_layout()
	_label(page,notice,Vector2(68,621),Vector2(1142,28),15,GOLD)
	_label(page,"手动存档独立保留，自动存档记录最近的旅程。",Vector2(68,684),Vector2(520,22),12,MUTED)

func _select(slot: String) -> void:
	selected_slot = slot; notice = ""; _render()

func _card(slot: String,point: Vector2,compact: bool) -> void:
	var info: Dictionary = entries[slot]
	var height = 70 if compact else 134
	var card = _button(page,"",point,Vector2(604,height),func(): _select(slot),slot == selected_slot)
	card.set_meta("archive_slot",slot)
	var number = slot.trim_prefix("slot_")
	_label(card,"%02d" % int(number),Vector2(12,12),Vector2(32,height-20),18,GOLD if slot == selected_slot else MUTED)
	var thumb_size = Vector2(112,54) if compact else Vector2(180,114)
	if info.usable: _image(card,str(info.get("thumbnail","")),Vector2(52,8),thumb_size)
	else:
		var empty = ColorRect.new(); empty.color = Color(0.02,0.035,0.045,0.85); empty.position = Vector2(52,8); empty.size = thumb_size; empty.mouse_filter = Control.MOUSE_FILTER_IGNORE; card.add_child(empty)
		_label(empty,"—",Vector2.ZERO,thumb_size,28,MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var x = 178 if compact else 249
	if not info.usable:
		_label(card,"存档不可用" if info.exists else "空存档位",Vector2(x,12),Vector2(340,30),21,MUTED)
		_label(card,"文件损坏或版本不兼容" if info.exists else ("选择此处开始新旅程" if mode == "new" else "可在旅途中保存进度"),Vector2(x,43 if compact else 63),Vector2(345,26),13,MUTED)
		return
	_label(card,str(info.title),Vector2(x,10),Vector2(402 if compact else 340,32),18 if compact else 22,GOLD if slot == selected_slot else TEXT)
	if compact:
		_label(card,"%s  ·  %s" % [duration(info.play_seconds),info.saved_time],Vector2(x,42),Vector2(350,22),14,MUTED)
		_label(card,"%d%%" % info.progress,Vector2(548,40),Vector2(48,24),15,GOLD)
	else:
		_label(card,"游玩时长  "+duration(info.play_seconds),Vector2(x,51),Vector2(330,24),17,MUTED)
		_label(card,"旅程进度  %d%%  ·  %s" % [info.progress,info.phase],Vector2(x,78),Vector2(330,24),17,GOLD)
		_label(card,str(info.saved_time),Vector2(x,105),Vector2(330,24),16,MUTED)

func _menu_layout() -> void:
	_label(page,"选择一段旅程，\n继续驶向明天。",Vector2(68,167),Vector2(440,74),25,TEXT)
	_button(page,"新游戏",Vector2(65,266),Vector2(260,56),func(): mode = "new"; notice = "选择一个存档位开始新的旅程。"; _render(),mode == "new","new")
	var latest = save_system.latest_slot()
	var resume = _button(page,"继续游戏",Vector2(65,340),Vector2(260,56),func(): _load_slot(latest),selected_slot == "auto","continue")
	resume.disabled = latest == ""
	_button(page,"读取存档",Vector2(65,414),Vector2(260,56),func(): mode = "load"; notice = "选择存档后，点击读取。"; _render(),mode == "load","load_mode")
	if entries.auto.usable:
		_label(page,"最近自动存档\n%s\n%s" % [entries.auto.title,entries.auto.saved_time],Vector2(69,507),Vector2(480,92),16,MUTED)
	else: _label(page,"暂无自动存档。\n手动保存的旅程会列在右侧。",Vector2(69,515),Vector2(470,74),16,MUTED)
	_label(page,"手动存档  %d—%d / 6" % [card_page*3+1,card_page*3+3],Vector2(611,108),Vector2(350,26),15,MUTED)
	_button(page,"‹",Vector2(1108,96),Vector2(46,40),_change_page,false,"previous")
	_button(page,"›",Vector2(1168,96),Vector2(46,40),_change_page,false,"next")
	for i in 3: _card("slot_%d" % (card_page*3+i+1),Vector2(610,166+i*148),false)
	var info: Dictionary = entries[selected_slot]
	var primary = _button(page,"开始新旅程" if mode == "new" else "读取所选",Vector2(610,652),Vector2(184,48),_primary,true,"primary")
	primary.disabled = selected_slot == "auto" if mode == "new" else not info.usable
	var remove = _button(page,"删除存档",Vector2(812,652),Vector2(184,48),_delete,false,"delete")
	remove.disabled = not info.exists or selected_slot == "auto"
	_button(page,"返回  →",Vector2(1014,652),Vector2(200,48),close_screen,false,"back")

func _change_page() -> void:
	card_page = 1-card_page; selected_slot = "slot_%d" % (card_page*3+1); _render()

func _game_layout() -> void:
	_label(page,"选择槽位保存，或读取已有旅程。",Vector2(698,106),Vector2(480,26),15,MUTED)
	var auto = _button(page,"自动存档",Vector2(479,92),Vector2(190,40),func(): _select("auto"),selected_slot == "auto","auto")
	auto.disabled = not entries.auto.usable
	for i in 6: _card("slot_%d" % (i+1),Vector2(65,159+i*78),true)
	_detail()
	var info: Dictionary = entries[selected_slot]
	var save = _button(page,"保存",Vector2(610,652),Vector2(137,48),_primary,true,"primary"); save.disabled = selected_slot == "auto"
	var read = _button(page,"读取",Vector2(765,652),Vector2(137,48),func(): _load_slot(selected_slot),false,"read"); read.disabled = not info.usable
	var remove = _button(page,"删除",Vector2(920,652),Vector2(137,48),_delete,false,"delete"); remove.disabled = not info.exists or selected_slot == "auto"
	_button(page,"返回  →",Vector2(1075,652),Vector2(139,48),close_screen,false,"back")

func _detail() -> void:
	var info: Dictionary = entries[selected_slot]
	var preview: Dictionary = info
	if not info.usable: preview = source.archive_metadata()
	var panel = SKIN.panel(page,Vector2(697,159),Vector2(518,460))
	panel.fill = Color(0.012,0.025,0.038,0.91)
	_image(panel,str(preview.get("thumbnail","")),Vector2(18,16),Vector2(482,188))
	_label(panel,str(info.get("title","当前旅程 · 待保存")),Vector2(22,215),Vector2(476,35),24,GOLD)
	_label(panel,"游玩时长    "+duration(float(preview.get("play_seconds",0))),Vector2(23,262),Vector2(471,26),17)
	_label(panel,"保存时间    "+str(info.get("saved_time","尚未保存")),Vector2(23,297),Vector2(471,26),17,MUTED)
	_label(panel,"旅程进度    %d%%  ·  %s" % [int(info.get("progress",maxi(0,int(source.engine.s.day)-1)*5)),info.get("phase","当前进度")],Vector2(23,332),Vector2(471,26),17,GOLD)
	_label(panel,"备注"+("  ·  已从备份恢复" if info.get("recovered",false) else ""),Vector2(23,369),Vector2(471,24),14,MUTED)
	note_edit = TextEdit.new(); note_edit.position = Vector2(23,397); note_edit.size = Vector2(471,48)
	note_edit.text = str(preview.get("note","")); note_edit.editable = selected_slot != "auto"
	note_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY; note_edit.add_theme_font_size_override("font_size",14)
	note_edit.add_theme_color_override("font_color",TEXT); note_edit.add_theme_color_override("font_readonly_color",MUTED)
	panel.add_child(note_edit)

func _primary() -> void:
	if is_instance_valid(confirmation): return
	if is_instance_valid(source):
		var note = note_edit.text.left(240) if is_instance_valid(note_edit) else ""
		var slot = selected_slot
		var write = func():
			if source.save_progress(slot,note): notice = "已保存到存档位 %02d。" % int(slot.trim_prefix("slot_"))
			else: notice = save_system.last_error
			_reload(); _render()
		if entries[slot].exists: _confirm("覆盖这份存档？","此槽位原有的旅程将被当前进度替换。",write)
		else: write.call()
	elif mode == "new":
		var slot = selected_slot
		var start = func(): hide(); new_game_requested.emit(slot)
		if entries[slot].exists: _confirm("从这里重新出发？","此槽位原有的旅程将被新游戏替换。",start)
		else: start.call()
	else: _load_slot(selected_slot)

func _load_slot(slot: String) -> void:
	if slot == "" or is_instance_valid(confirmation): return
	var payload: Dictionary = save_system.load_from_file(slot)
	if payload.is_empty(): notice = "这份存档无法读取，请选择其他存档。"; _reload(); _render(); return
	var read = func(): hide(); load_requested.emit(payload)
	if is_instance_valid(source): _confirm("读取这段旅程？","当前尚未手动保存的进度将被所选存档替换。",read)
	else: read.call()

func _delete() -> void:
	if selected_slot == "auto" or not entries[selected_slot].exists or is_instance_valid(confirmation): return
	var slot = selected_slot
	_confirm("删除这份存档？","存档位 %02d 的旅程与备份将被移除。此操作无法撤销。" % int(slot.trim_prefix("slot_")),func():
		notice = "存档已删除。" if save_system.delete_slot(slot) else save_system.last_error
		_reload(); _render())

func _confirm(title: String,description: String,action: Callable) -> void:
	pending_action = action
	confirmation = Control.new(); confirmation.name = "ArchiveConfirmation"; confirmation.size = DESIGN; body.add_child(confirmation)
	var shade = ColorRect.new(); shade.size = DESIGN; shade.color = Color(0.005,0.012,0.02,0.83); confirmation.add_child(shade)
	var panel = SKIN.panel(confirmation,Vector2(364,230),Vector2(552,264),true)
	_label(panel,title,Vector2(30,25),Vector2(492,45),28,GOLD)
	_label(panel,description,Vector2(32,90),Vector2(486,64),18)
	_button(panel,"取消",Vector2(30,188),Vector2(226,48),clear_confirmation,false,"cancel")
	_button(panel,"确认",Vector2(285,188),Vector2(235,48),confirm_action,true,"confirm")

func clear_confirmation() -> void:
	if is_instance_valid(confirmation): body.remove_child(confirmation); confirmation.queue_free()
	confirmation = null; pending_action = Callable()

func confirm_action() -> void:
	if not pending_action.is_valid(): return
	var action = pending_action; clear_confirmation(); action.call()

func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"): return
	if is_instance_valid(confirmation): clear_confirmation()
	else: close_screen()
	get_viewport().set_input_as_handled()
