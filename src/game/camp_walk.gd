extends Control
const CATALOG = preload("res://src/game/location_catalog.gd")
const BACKDROP = preload("res://src/game/walk_backdrop.gd")
const CONTROLS = preload("res://src/game/walk_controls.gd")
const SKIN = preload("res://src/ui/convoy_skin.gd")
const MOBILE = preload("res://src/ui/mobile_layout.gd")
const ACTOR_LIGHT = preload("res://src/game/walk_actor.gdshader")
const CAPTAIN_WALK = preload("res://assets/characters/captain/walk.tres")
const CAPTAIN_IDLE = preload("res://assets/characters/captain/idle.tres")
const NPC_ROOT = "res://assets/characters/side_walk_20261016/"
const CAPTAIN_HEIGHT = 190.0
const NPC_HEIGHT = 166.0
signal interacted(member_id: String)
signal entrance_used
signal closed
var members: Array = []
var vehicles: Array = []
var location_id = "camp"
var content: Control
var hud: Control
var backdrop
var walk_path: Array = []
var player_x = 120.0
var destination = 120.0
var direction = 0.0
var held_directions: Dictionary = {}
var hint: Label
var npcs = []
var captain_sprite: AnimatedSprite2D
var facing_left = false
var is_walking = false
var joystick
var talk
var window_focused = true
var atlas_mode = false
var input_locked = false
var design_size = Vector2(1280,720)
var focused_member = ""
var exploration_x = 0.0
var entrance: Dictionary = {}
var entrance_enabled = true
var entrance_button: Button
var talk_caption: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg = ColorRect.new(); bg.color = Color("080e15"); bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); bg.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(bg)
	if atlas_mode: design_size = Vector2(1680,720)
	content = Control.new(); content.size = design_size; content.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(content)
	hud = Control.new(); hud.name = "SafeTouchControls"; hud.size = design_size; hud.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(hud)
	backdrop = BACKDROP.new(); backdrop.size = design_size; backdrop.canvas_size = design_size; backdrop.full_map = atlas_mode; content.add_child(backdrop); backdrop.display(location_id,vehicles)
	walk_path = backdrop.config.get("walk_path",[])
	player_x = backdrop.source_to_view(CATALOG.foot_at(walk_path,float(backdrop.config.get("spawn_x",610)))).x; destination = player_x
	backdrop.actor_layer.draw.connect(_draw_actors)
	captain_sprite = AnimatedSprite2D.new(); captain_sprite.name = "CaptainAnimation"
	captain_sprite.offset = Vector2(0,-241.5); captain_sprite.scale = Vector2.ONE*(CAPTAIN_HEIGHT/483.0)
	captain_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	captain_sprite.material = _material(); backdrop.actor_layer.add_child(captain_sprite)
	var present = members.filter(func(m): return m.id != "captain")
	for index in present.size():
		var m = present[index]; var positions: Array = backdrop.config.get("npc_x",[350,1010,1350,1690])
		var x = float(positions[index]) if present.size() <= positions.size() else lerpf(float(walk_path[0][0])+105,float(walk_path[-1][0])-103,float(index)/maxi(1,present.size()-1))
		var sprite = Sprite2D.new(); sprite.name = "Member_"+str(m.id)
		var art_id = _art_id(m)
		var path = NPC_ROOT+art_id+".png"
		if ResourceLoader.exists(path):
			sprite.texture = load(path); sprite.centered = false
			sprite.scale = Vector2.ONE*(NPC_HEIGHT/sprite.texture.get_height())
			sprite.offset = Vector2(-sprite.texture.get_width()*0.5,-sprite.texture.get_height())
			sprite.material = _material(); sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		backdrop.actor_layer.add_child(sprite)
		npcs.append({"id":m.id,"name":m.name,"source_x":x,"x":backdrop.source_to_view(CATALOG.foot_at(walk_path,x)).x,"sprite":sprite,"art_id":art_id})
	_update_captain(0)
	var title = Label.new(); title.text = str(backdrop.config.get("title","营地")); title.position = Vector2(34,23); title.add_theme_font_size_override("font_size",23); title.add_theme_constant_override("outline_size",5); title.add_theme_color_override("font_outline_color",Color(0.02,0.03,0.05,0.8)); title.mouse_filter = Control.MOUSE_FILTER_IGNORE; hud.add_child(title)
	joystick = CONTROLS.new(); joystick.name = "MoveJoystick"; joystick.position = Vector2(40,530); joystick.size = Vector2(148,148)
	joystick.axis_changed.connect(func(_value): _sync_direction(); destination = player_x); hud.add_child(joystick)
	talk = CONTROLS.new(); talk.name = "InteractHand"; talk.kind = "hand"; talk.position = Vector2(1110,558); talk.size = Vector2(110,110); talk.pressed.connect(interact); hud.add_child(talk)
	_label("移动",Vector2(40,683),148,18)
	talk_caption = _label("交谈",Vector2(1110,683),110,18)
	hint = _label("A / D 移动 · E / 空格交谈",Vector2(420,678),440,15)
	hint.modulate = Color(0.78,0.86,0.92,0.65)
	var back = Button.new(); back.name = "CloseWalk"; back.text = "‹  返回"; back.position = Vector2(1132,23); back.size = Vector2(114,44); back.add_theme_font_size_override("font_size",19)
	var style = StyleBoxFlat.new(); style.bg_color = Color(0.025,0.045,0.065,0.6); style.set_corner_radius_all(22); style.set_border_width_all(1); style.border_color = Color(0.75,0.84,0.91,0.35)
	back.add_theme_stylebox_override("normal",style); back.pressed.connect(func(): closed.emit()); hud.add_child(back)
	if atlas_mode:
		talk.position.x = design_size.x-150
		for child in hud.get_children():
			if child is Label and child.position.x == 1110: child.position.x = design_size.x-150
		title.hide(); back.hide(); hint.position.x = (design_size.x-hint.size.x)*0.5
	resized.connect(_fit); _fit(); _refresh_actors()

func _label(text: String, point: Vector2, width: float, font_size: int) -> Label:
	var label = Label.new(); label.text = text; label.position = point; label.size = Vector2(width,25); label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; label.add_theme_font_size_override("font_size",font_size); label.mouse_filter = Control.MOUSE_FILTER_IGNORE; hud.add_child(label); return label

func _fit() -> void:
	if not is_instance_valid(content): return
	MOBILE.cover(content,design_size,size)
	MOBILE.fit_tall(hud,design_size,MOBILE.safe_rect(self))
	var extra = hud.size.y-design_size.y
	joystick.position = Vector2(40,530+extra)
	talk.position = Vector2(design_size.x-150 if atlas_mode else 1110,558+extra)
	for child in hud.get_children():
		if child is Label:
			if child == hint: child.position.y = 678+extra
			elif child == talk_caption or child.text == "移动": child.position.y = 683+extra

func _art_id(member: Dictionary) -> String:
	if str(member.id) in ["zhang","elin","ajie","sofia"]: return str(member.id)
	# Extra recruits retain their real interaction ID and use a role body until
	# individual full-body art exists; they never become duplicate rule members.
	var best = "ajie"; var score = -1.0
	for role in {"repair":"zhang","medical":"elin","scout":"ajie","logistics":"sofia"}:
		if float(member.get(role,0))>score:
			score = float(member.get(role,0)); best = {"repair":"zhang","medical":"elin","scout":"ajie","logistics":"sofia"}[role]
	return best

func _material() -> ShaderMaterial:
	var material = ShaderMaterial.new(); material.shader = ACTOR_LIGHT
	material.set_shader_parameter("ambient_tint",Vector3(0.82,0.9,1) if backdrop.config.get("interior",false) else Vector3(0.73,0.85,1))
	material.set_shader_parameter("exposure_stops",-0.22 if backdrop.config.get("interior",false) else -0.42)
	return material

func _light(sprite: CanvasItem, source_x: float) -> void:
	if not sprite.material: return
	var falloff = pow(clampf(1.0-absf(source_x-float(backdrop.config.get("warm_x",1250)))/float(backdrop.config.get("warm_radius",620)),0,1),2)
	sprite.material.set_shader_parameter("warm_amount",falloff*float(backdrop.config.get("warm_strength",0.3)))

func _process(delta: float) -> void:
	if walk_path.is_empty(): return
	if input_locked: _update_captain(0); return
	var left = backdrop.source_to_view(CATALOG.foot_at(walk_path,float(walk_path[0][0]))).x
	var right = backdrop.source_to_view(CATALOG.foot_at(walk_path,float(walk_path[-1][0]))).x
	var old_x = player_x
	var keyboard = Input.get_axis("move_left","move_right") if window_focused else 0.0
	var input = clampf(keyboard+direction,-1,1)
	if absf(input)>0.01: player_x = clampf(player_x+input*240*delta,left,right); destination = player_x
	else: player_x = move_toward(player_x,clampf(destination,left,right),240*delta)
	var source_x = clampf(backdrop.view_to_source(Vector2(player_x,0)).x,float(walk_path[0][0]),float(walk_path[-1][0]))
	var target_x = backdrop.view_to_source(Vector2(destination,0)).x
	var displacement = player_x-old_x
	if absf(displacement)>0.001:
		backdrop.set_camera((source_x/backdrop.source_size.x-0.5)*48)
		player_x = backdrop.source_to_view(CATALOG.foot_at(walk_path,source_x)).x
		destination = backdrop.source_to_view(CATALOG.foot_at(walk_path,target_x)).x
	_update_captain(displacement); _refresh_actors()

func _refresh_actors() -> void:
	for npc in npcs:
		var foot = backdrop.source_to_view(CATALOG.foot_at(walk_path,npc.source_x)); npc.x = foot.x; npc.sprite.position = foot
		_light(npc.sprite,npc.source_x)
	var nearby = nearest()
	var at_entrance = can_use_entrance()
	if is_instance_valid(entrance_button):
		entrance_button.visible = at_entrance
		var foot = CATALOG.foot_at(walk_path,float(entrance.source_x))
		entrance_button.position = backdrop.source_to_view(foot-Vector2(0,360))-entrance_button.size*0.5
	if is_instance_valid(talk):
		talk.enabled = at_entrance or not nearby.is_empty(); talk.queue_redraw()
		talk.tooltip_text = str(entrance.get("label",""))+" · E / 空格" if at_entrance else "靠近队友交谈 · E / 空格"
	if is_instance_valid(talk_caption): talk_caption.text = str(entrance.get("short_label","进入")) if at_entrance else "交谈"
	if is_instance_valid(hint):
		hint.text = str(entrance.get("label",""))+" · E / 空格" if at_entrance else ("与"+str(nearby.name)+"交谈 · E / 空格" if not nearby.is_empty() else "A / D 移动 · E / 空格交谈")
	backdrop.actor_layer.queue_redraw()

func configure_entrance(options: Dictionary, feedback: Node = null) -> void:
	entrance = options.duplicate(true)
	if not is_instance_valid(entrance_button):
		entrance_button = Button.new(); entrance_button.name = "BuildingEntrance"
		entrance_button.size = Vector2(190,44); entrance_button.focus_mode = Control.FOCUS_NONE
		entrance_button.add_theme_font_size_override("font_size",19)
		entrance_button.pressed.connect(use_entrance); content.add_child(entrance_button)
		SKIN.button(entrance_button,true,feedback)
	entrance_button.text = str(entrance.get("label",""))
	_refresh_actors()

func can_use_entrance() -> bool:
	if input_locked or not entrance_enabled or not is_visible_in_tree() or entrance.is_empty(): return false
	var source_x = backdrop.view_to_source(Vector2(player_x,0)).x
	return absf(source_x-float(entrance.source_x)) <= float(entrance.get("radius",110))

func use_entrance() -> void:
	# Validate again on activation: a visible button may have become stale after
	# walking away, opening a dialogue, or pausing the game.
	if not can_use_entrance(): return
	lock_movement(true); entrance_used.emit()

func place_player_at(source_x: float) -> void:
	var x = clampf(source_x,float(walk_path[0][0]),float(walk_path[-1][0]))
	backdrop.set_camera((x/backdrop.source_size.x-0.5)*48)
	player_x = backdrop.source_to_view(CATALOG.foot_at(walk_path,x)).x; destination = player_x
	_update_captain(0); _refresh_actors()

func _gui_input(event: InputEvent) -> void:
	if walk_path.is_empty() or input_locked: return
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and event.device != InputEvent.DEVICE_ID_EMULATION) or (event is InputEventScreenTouch and event.pressed):
		var point = content.get_transform().affine_inverse()*event.position
		var source = backdrop.view_to_source(point); var foot = CATALOG.foot_at(walk_path,source.x)
		if source.x>=float(walk_path[0][0]) and source.x<=float(walk_path[-1][0]) and absf(source.y-foot.y)<=55:
			destination = backdrop.source_to_view(foot).x; accept_event()

# Retained for keyboard/accessibility adapters and existing integration clients.
func _direction_input(event: InputEvent, value: float) -> void:
	if event is InputEventScreenTouch: _hold("touch_"+str(event.index),value,event.pressed)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT: _hold("mouse",value,event.pressed)

func _sync_direction() -> void:
	direction = joystick.axis if is_instance_valid(joystick) else 0.0
	for held in held_directions.values(): direction += held
	direction = clampf(direction,-1,1)

func _hold(source: String, value: float, pressed: bool) -> void:
	if pressed: held_directions[source] = value
	else: held_directions.erase(source)
	_sync_direction(); destination = player_x

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and not event.pressed and held_directions.has("touch_"+str(event.index)): _hold("touch_"+str(event.index),0,false)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and held_directions.has("mouse"): _hold("mouse",0,false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		window_focused = false; held_directions.clear(); direction = 0; destination = player_x
		if is_instance_valid(joystick): joystick.release()
		if is_instance_valid(talk): talk.release()
		if is_instance_valid(captain_sprite): _update_captain(0)
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN: window_focused = true

func _position_captain() -> void:
	var source_x = backdrop.view_to_source(Vector2(player_x,0)).x
	captain_sprite.position = backdrop.source_to_view(CATALOG.foot_at(walk_path,source_x)); _light(captain_sprite,source_x)

func _update_captain(displacement: float) -> void:
	is_walking = absf(displacement)>0.001
	if is_walking: facing_left = displacement<0
	var frames = CAPTAIN_WALK if is_walking else CAPTAIN_IDLE
	var animation = "walk_right" if is_walking else ("idle_left" if facing_left else "idle_right")
	if captain_sprite.sprite_frames != frames: captain_sprite.sprite_frames = frames
	captain_sprite.flip_h = is_walking and facing_left
	if captain_sprite.animation != animation or not captain_sprite.is_playing(): captain_sprite.play(animation)
	_position_captain()

func nearest() -> Dictionary:
	var result = {}; var distance = 70.0
	for npc in npcs:
		if absf(player_x-npc.x)<distance: distance = absf(player_x-npc.x); result = npc
	return result

func interact() -> void:
	if input_locked: return
	if can_use_entrance(): use_entrance(); return
	var nearby = nearest()
	if not nearby.is_empty(): interacted.emit(str(nearby.id))

func _unhandled_key_input(event: InputEvent) -> void:
	if input_locked: return
	if event.is_action_pressed("interact") and not event.is_echo(): interact(); get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"): closed.emit(); get_viewport().set_input_as_handled()

func _draw_actors() -> void:
	var layer: Node2D = backdrop.actor_layer; var nearby = nearest(); var font = get_theme_default_font()
	for npc in npcs:
		if not npc.sprite.visible: continue
		var foot = backdrop.source_to_view(CATALOG.foot_at(walk_path,npc.source_x))
		layer.draw_set_transform(foot+Vector2(0,-1),0,Vector2(1,0.22)); layer.draw_circle(Vector2.ZERO,25,Color(0,0,0,0.4))
		var icon = foot+Vector2(0,-NPC_HEIGHT-23); var active = nearby.get("id","") == npc.id
		var color = Color("d2efff") if active else Color(0.88,0.94,1,0.57)
		layer.draw_set_transform(icon)
		layer.draw_circle(Vector2.ZERO,18,Color(0.02,0.04,0.065,0.65)); layer.draw_arc(Vector2.ZERO,18,0,TAU,40,color,1.5,true)
		layer.draw_style_box(_bubble_style(color),Rect2(-10,-7,20,13))
		layer.draw_colored_polygon(PackedVector2Array([Vector2(-4,4),Vector2(-5,10),Vector2(2,4)]),color)
		for x in [-5,0,5]: layer.draw_circle(Vector2(x,-1),1.4,Color("253544"))
		if npc.art_id == "zhang":
			layer.draw_circle(Vector2.ZERO,14,Color("152330"))
			layer.draw_line(Vector2(-6,6),Vector2(6,-6),color,4,true)
			layer.draw_arc(Vector2(6,-6),5,-0.1,PI*1.5,18,color,2,true)
		if active:
			var text_width = font.get_string_size(str(npc.name),HORIZONTAL_ALIGNMENT_LEFT,-1,18).x
			layer.draw_string_outline(font,Vector2(-text_width/2,-29),str(npc.name),HORIZONTAL_ALIGNMENT_LEFT,-1,18,5,Color("0a1320"))
			layer.draw_string(font,Vector2(-text_width/2,-29),str(npc.name),HORIZONTAL_ALIGNMENT_LEFT,-1,18,color)
	var foot = captain_sprite.position
	layer.draw_set_transform(foot+Vector2(0,1),0,Vector2(1,0.22))
	layer.draw_circle(Vector2.ZERO,38,Color(0.47,0.74,0.94,0.16)); layer.draw_arc(Vector2.ZERO,38,0,TAU,64,Color(0.72,0.88,1,0.82),3,true)
	layer.draw_set_transform(Vector2.ZERO)

func _bubble_style(color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new(); style.bg_color = color; style.set_corner_radius_all(5); return style

func lock_movement(locked: bool) -> void:
	input_locked = locked; held_directions.clear(); direction = 0; destination = player_x
	if is_instance_valid(joystick): joystick.release(); joystick.visible = not locked
	if is_instance_valid(talk): talk.release(); talk.visible = not locked
	if is_instance_valid(hint): hint.visible = not locked
	if is_instance_valid(talk_caption): talk_caption.visible = not locked
	for child in hud.get_children():
		if child is Label and child.text in ["移动","交谈"]: child.visible = not locked
	_refresh_actors()

func focus_member(id: String) -> void:
	if id == focused_member: return
	if focused_member == "": exploration_x = player_x
	focused_member = id
	if id == "": player_x = exploration_x
	else:
		for npc in npcs:
			if npc.id == id:
				var x = clampf(float(npc.source_x)-300,float(walk_path[0][0]),float(walk_path[-1][0]))
				player_x = backdrop.source_to_view(CATALOG.foot_at(walk_path,x)).x
	for npc in npcs: npc.sprite.visible = id == "" or npc.id == id
	destination = player_x; _update_captain(0); _refresh_actors()
