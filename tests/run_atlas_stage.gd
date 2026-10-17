extends SceneTree
const RULES = preload("res://src/game/world_rules.gd")
const BIOMES = preload("res://src/game/biome_catalog.gd")
const SAVES = preload("res://src/game/save.gd")
var checks = 0
var failures = 0
var samples: Dictionary = {}
var ui
var evidence: Array = []
var output = "res://.docs/美术/示例图横版复刻_20261016/runtime"

func _init(): call_deferred("run")
func check(ok: bool, label: String):
	checks += 1
	if not ok: failures += 1; print("FAIL ",label)

func observe(r, seed: int, step: int):
	var id = BIOMES.scene_for(r.s)
	var keys: Array = []
	if r.s.phase in ["morning","stop","camp"]: keys.append(id)
	if id == "tunnel_entrance" and r.s.phase != "ending": keys.append(id)
	if r.s.phase == "camp" and not r.s.daily.camp_used: keys.append("camp_ready")
	if r.s.phase == "stop" and r.s.daily.get("opportunity_card","") == "R01": keys.append("merchant")
	if r.s.phase in ["morning","stop","camp"]:
		for row in r.s.daily.get("person_queue",[]):
			if not row.get("hidden",false) and not r.INQUIRIES.get(row.id,[]).is_empty():
				keys.append("person"); break
	for key in keys:
		if not samples.has(key): samples[key] = {"checkpoint":r.checkpoint(),"seed":seed,"step":step}

func restore_sample(key: String):
	await settled()
	check(samples.has(key),"legal fixture covers "+key)
	if not samples.has(key): return
	var sample = samples[key]
	check(ui.engine.restore(sample.checkpoint),"restore "+key)
	ui.view = "journey"; ui.paused = false; ui.active_card = ""; ui.scene_context.clear()
	ui.side_stage.forced = false; ui.side_stage.last_phase = ""; ui.side_stage.mode = "explore"; ui.side_stage.meeting = ""
	ui.refresh(); await settled(); await process_frame
	ui.side_stage.walk.set_process(false)

func shot(name: String, key: String):
	await settled()
	await process_frame; await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(output.path_join(name+".png")) == OK,"render "+name)
	evidence.append({"reference":name,"source":key,"seed":samples.get(key,{}).get("seed",-1),"step":samples.get(key,{}).get("step",-1),"day":ui.engine.s.day,"phase":ui.engine.s.phase,"scene":ui.side_stage.current_location,"mode":ui.side_stage.mode})

func settled():
	var deadline = Time.get_ticks_msec()+15000
	while ui.loading_screen.busy and Time.get_ticks_msec() < deadline: await process_frame
	check(not ui.loading_screen.busy,"scene transition finishes automatically")

func find_button(node: Node, action: String, id: String = "") -> Button:
	for child in node.get_children():
		if child is Button and child.get_meta("action_id","") == action and (id == "" or child.get_meta("command_args",{}).get("id","") == id): return child
		var nested = find_button(child,action,id)
		if nested != null: return nested
	return null

func run():
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1680,720)
	var fixtures = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/final_endings_paths.json"))
	for fixture in fixtures:
		var r = RULES.new(); r.new_game(int(fixture.seed)); observe(r,int(fixture.seed),0)
		var step = 0
		for command in fixture.commands:
			step += 1
			if not r.command(command.action,command.args): check(false,"fixture remains legal"); break
			observe(r,int(fixture.seed),step)
	var main = load("res://scenes/main.tscn").instantiate(); main.save_system = SAVES.new("res://.godot/atlas_test/menu"); root.add_child(main)
	await process_frame; main._start_game(); await process_frame
	ui = main.day_demo; ui.save_system = SAVES.new("res://.godot/atlas_test/game"); await settled()
	root.content_scale_size = Vector2i.ZERO; root.size = Vector2i(1680,720)
	await process_frame; await process_frame
	await restore_sample("forest_gas_station")
	check(ui.side_stage.visible and ui.side_stage.current_location == "forest_gas_station","production starts at real gas station in horizontal stage")
	for npc in ui.side_stage.walk.npcs: check(npc.sprite.texture != null,"living teammate has visible body "+str(npc.id))
	await shot("33_gas_station","forest_gas_station")
	var initial = ui.engine.checkpoint(); ui._toggle_opening_room(); await settled()
	check(ui.side_stage.current_location == "gas_station_interior" and ui.engine.checkpoint() == initial,"opening indoor visit changes presentation only")
	await shot("extra_opening_room","forest_gas_station")
	ui._toggle_opening_room(); await settled()
	await restore_sample("camp_ready")
	var stage = ui.side_stage; var before = ui.engine.checkpoint()
	stage.mode = "explore"; stage.sync(); await shot("23_exploration","camp_ready")
	stage.meeting = "tent"; stage.sync(); await shot("31_tent_meeting","camp_ready")
	check(stage.current_location == "camp_interior" and stage.walk.npcs.size() == ui.engine.people().size()-1,"tent uses actual living team")
	stage.meeting = "fire"; stage.sync(); await shot("32_fire_meeting","camp_ready")
	stage.meeting = ""; stage.mode = "actions"; stage.sync(); await shot("54_camp_actions","camp_ready")
	check(stage.overlay.find_child("CampCard_repair",true,false) != null,"six action cards mounted in production")
	for kind in ["read","teach","repair","trade","supplies","rest"]:
		stage.action_kind = kind; stage.mode = "action"; stage.sync()
		check(ui.engine.checkpoint() == before,"view action preserves full state and RNG "+kind)
	var start_x = stage.walk.player_x
	stage.walk._hold("test",1,true); stage.walk._process(0.5)
	check(stage.walk.player_x == start_x and stage.walk.input_locked,"modal blocks keyboard and held movement")
	stage.back(); check(not stage.walk.input_locked and stage.walk.direction == 0,"back restores stopped exploration")
	stage.action_kind = "rest"; stage.mode = "action"; stage.sync()
	var rest = find_button(stage.overlay,"camp","rest")
	check(rest != null and not rest.disabled,"real camp rest is available")
	if rest:
		rest.pressed.emit(); rest.pressed.emit()
		check(ui.engine.s.daily.camp_used or ui.engine.s.phase == "camp_event","camp action uses actual unique slot or replacement event")
		check(ui.engine.s.daily.hours <= before.current.daily.hours+2,"stale response cannot submit a second action")
	await restore_sample("person")
	stage = ui.side_stage
	var row = stage._visible_queue().filter(func(item): return not ui.engine.INQUIRIES.get(item.id,[]).is_empty())[0]
	stage.open_card(row.id,row.owner); await process_frame
	for picture in stage.overlay.find_children("*","TextureRect",true,false):
		if picture.get_meta("atlas_portrait",false): check(picture.size.x <= 110 and picture.size.y <= 125,"portrait keeps atlas bounds "+str(picture.size))
	before = ui.engine.checkpoint()
	check(stage.mode == "dialogue" and stage.walk.input_locked,"real person card remains in scene")
	await shot("24_teammate_dialogue","person"); await shot("53_person_queue","person")
	var inquiry: Button
	for original in ui.choices.get_children():
		if original is Button and "仅显示信息" in original.text: inquiry = original; break
	check(inquiry != null,"real person inquiry is exposed")
	if inquiry:
		stage._forward(inquiry,stage.epoch)
		check(ui.engine.checkpoint() == before,"inquiry cannot resolve card or change RNG")
		check(find_button(stage.overlay,"card",row.id) != null,"inquiry retains final responses")
	var reply = find_button(stage.overlay,"card",row.id)
	if reply and not reply.disabled:
		var old_epoch = stage.epoch; reply.pressed.emit(); var after = ui.engine.checkpoint(); reply.pressed.emit()
		check(ui.engine.checkpoint() == after and stage.epoch != old_epoch,"respond once and invalidate stale choice")
	await restore_sample("merchant")
	stage = ui.side_stage; stage.open_card("R01"); await process_frame
	check(stage.mode == "encounter","merchant encounter has approach step")
	await shot("26_merchant_encounter","merchant")
	stage.encounter_seen["%d:R01" % ui.engine.s.day] = true; stage.sync()
	await shot("28_negotiation","merchant")
	check(stage.mode == "dialogue" and find_button(stage.overlay,"card","R01") != null,"negotiation uses actual trade card and quotation")
	stage.back(); await shot("36_market","merchant")
	await restore_sample("tunnel_entrance"); ui._open_side_stage(); await process_frame
	await shot("34_tunnel","tunnel_entrance")
	await restore_sample("snow_camp"); ui.side_stage.mode = "explore"; ui.side_stage.sync(); await process_frame
	await shot("35_snow_camp","snow_camp")
	stage = ui.side_stage; before = ui.engine.checkpoint()
	for dimensions in [Vector2i(960,600),Vector2i(1280,720),Vector2i(1680,720),Vector2i(2340,1080)]:
		root.size = dimensions; await process_frame; stage._fit()
		var rect = stage.content.get_transform()*Rect2(Vector2.ZERO,Vector2(1680,720))
		check(Rect2(Vector2.ZERO,stage.size).grow(0.1).encloses(rect),"21:9 stage fits "+str(dimensions))
		check(stage.walk.backdrop.vehicle_root.get_child_count() == 0,"unconfirmed vehicles remain unmounted")
		await shot("layout_%dx%d" % [dimensions.x,dimensions.y],"snow_camp")
	check(ui.engine.checkpoint() == before,"resizing does not change story")
	ui._pause(); check(not stage.visible and stage.walk.input_locked,"pause hides stage and clears movement")
	ui._pause(); check(stage.visible,"resume restores stage")
	var file = FileAccess.open(output.path_join("verification.json"),FileAccess.WRITE); file.store_string(JSON.stringify({"checks":checks,"failures":failures,"graphical":DisplayServer.get_name() != "headless","evidence":evidence},"\t")); file.close()
	main.queue_free(); await process_frame
	print("ATLAS_STAGE checks=",checks," failures=",failures); quit(failures)
