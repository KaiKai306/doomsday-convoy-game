extends SceneTree
const Walk = preload("res://src/game/camp_walk.gd")
const Rules = preload("res://src/game/world_rules.gd")
var checks = 0
var failures = 0
func _init(): call_deferred("run")
func check(ok: bool, label: String):
	checks += 1
	if not ok: failures += 1; print("FAIL ",label)
func touch(id: int, down: bool, point: Vector2) -> InputEventScreenTouch:
	var e = InputEventScreenTouch.new(); e.index=id; e.pressed=down; e.position=point; return e
func drag(id: int, point: Vector2) -> InputEventScreenDrag:
	var e = InputEventScreenDrag.new(); e.index=id; e.position=point; return e
func run():
	root.size=Vector2i(1280,720)
	var rules=Rules.new();rules.new_game(81);var before=rules.checkpoint()
	var walk=Walk.new(); walk.members=rules.people().duplicate(true);root.add_child(walk)
	await process_frame; walk.set_process(false)
	var stick=walk.joystick;var center=stick.size*0.5
	stick._gui_input(touch(0,true,center))
	check(stick.owner_pointer==0 and is_zero_approx(walk.direction),"centered joystick has no drift")
	stick._input(drag(0,stick.get_global_transform_with_canvas()*(center+Vector2(50,0))))
	check(walk.direction>0.95,"drag uses horizontal analogue axis")
	var start=walk.player_x;walk._process(0.1)
	check(walk.player_x>start,"joystick moves captain through real movement controller")
	stick._gui_input(touch(1,true,center-Vector2(50,0)))
	check(stick.owner_pointer==0 and walk.direction>0.95,"second finger cannot steal joystick")
	stick._input(touch(1,false,Vector2.ZERO))
	check(stick.owner_pointer==0 and walk.direction>0.95,"unrelated release preserves held joystick")
	stick._input(drag(0,stick.get_global_transform_with_canvas()*(center+Vector2(400,300))))
	check(stick.knob.length()<=stick.radius()*0.55+0.001 and walk.direction>0,"drag outside circle clamps knob without losing ownership")
	stick._input(touch(0,false,Vector2(-800,-800)))
	check(stick.owner_pointer==stick.NONE and walk.direction==0,"release outside scene stops joystick")
	start=walk.player_x;walk._process(0.1)
	check(is_equal_approx(start,walk.player_x),"release cancels movement destination")
	stick._gui_input(touch(2,true,center+Vector2(2,40)))
	check(is_zero_approx(walk.direction),"vertical-only drag does not move in side view")
	var canceled=touch(2,false,Vector2.ZERO);canceled.canceled=true;stick._input(canceled)
	check(stick.owner_pointer==stick.NONE,"canceled touch releases pointer")
	var mouse=InputEventMouseButton.new();mouse.button_index=MOUSE_BUTTON_LEFT;mouse.pressed=true;mouse.position=center+Vector2(-60,0)
	stick._gui_input(mouse);check(walk.direction< -0.95,"mouse drag can operate joystick")
	mouse.pressed=false;mouse.position=Vector2(2000,0);stick._input(mouse)
	check(walk.direction==0,"global mouse release stops joystick")
	walk.player_x=walk.npcs[0].x+45;walk.destination=walk.player_x;walk._refresh_actors()
	check(walk.talk.enabled,"near real teammate enables hand")
	var emissions=[];walk.interacted.connect(func(id):emissions.append(id))
	stick._gui_input(touch(3,true,center+Vector2(45,0)))
	var hand=walk.talk;hand._gui_input(touch(4,true,hand.size*0.5))
	var release=touch(4,false,hand.get_global_transform_with_canvas()*(hand.size*0.5));hand._input(release)
	check(emissions==[walk.npcs[0].id],"hand emits nearest actual member ID")
	check(stick.owner_pointer==3 and walk.direction>0,"interaction finger never releases movement finger")
	walk._notification(Control.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	check(walk.direction==0 and stick.owner_pointer==stick.NONE and hand.owner_pointer==hand.NONE,"focus loss clears both controls")
	check(walk.destination==walk.player_x and not walk.is_walking,"focus loss stops destination and animation")
	walk._notification(Control.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	walk.player_x=walk.backdrop.source_to_view(Vector2(1893,806)).x;walk.destination=walk.player_x;walk._refresh_actors()
	check(not hand.enabled,"distant teammate disables hand")
	hand._gui_input(touch(5,true,hand.size*0.5));hand._input(touch(5,false,hand.get_global_transform_with_canvas()*(hand.size*0.5)))
	check(emissions.size()==1,"disabled hand cannot invent an interaction")
	walk.player_x=walk.npcs[0].x+35;walk.destination=walk.player_x
	var e=InputEventKey.new();e.physical_keycode=KEY_E;e.pressed=true;walk._unhandled_key_input(e)
	check(emissions.size()==2 and emissions[-1]==walk.npcs[0].id,"keyboard E preserves real talk action")
	var foot=walk.backdrop.source_to_view(Vector2(900,806))
	check(foot.y>490 and foot.y<530,"shared walking line sits at about 70 percent height")
	for dimensions in [Vector2(960,600),Vector2(1560,720),Vector2(2340,1080),Vector2(1280,720)]:
		walk.size=dimensions;walk._fit()
		var rect=walk.content.get_transform()*Rect2(Vector2.ZERO,Vector2(1280,720))
		check(Rect2(Vector2.ZERO,dimensions).grow(0.1).encloses(rect),"scene and circular HUD fit "+str(dimensions))
	check(rules.checkpoint()==before,"viewing, moving and talking signals preserve rules and RNG")
	walk.queue_free();await process_frame
	print("SIDE_WALK_INPUT checks=",checks," failures=",failures);quit(failures)
