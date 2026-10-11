extends SceneTree

## Exercise the public camp buttons independently of the five-day smoke test.
## Usage: godot --path . --script tests/run_knowledge_ui_test.gd -- <qa-directory> [--capture]
var failures := 0
var checks := 0
var capture := false
var output_dir := "res://.godot/knowledge-qa"
var ui: DayDemo
var state: GameState

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): output_dir = args[0]
	capture = "--capture" in args
	DirAccess.make_dir_recursive_absolute(output_dir)
	await _test_reading_and_cancel()
	await _test_teaching_boundaries()
	await _test_unavailable_teaching()
	await _test_pending_selection_and_load()
	await _test_repair()
	await _test_responsive_selection()
	await _dispose_fixture()
	print("KNOWLEDGE_UI_TEST_%s checks=%d failures=%d" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(failures)

func _fixture() -> void:
	await _dispose_fixture()
	state = GameState.new()
	ui = load("res://scenes/day_demo.tscn").instantiate()
	root.add_child(ui)
	ui.save_system = SaveSystem.new(output_dir + "/save")
	_check(ui.setup(state), "独立营地场景初始化")
	state.set_phase(GameState.Phase.CAMP_ACTION)
	ui.refresh()
	_press("camp_tab_daily")
	await _layout()

func _dispose_fixture() -> void:
	if ui != null:
		ui.queue_free()
		await process_frame
		ui = null
	if state != null:
		state.free()
		state = null

func _test_reading_and_cancel() -> void:
	await _fixture()
	state.member_named("阿遥").fatigue = 70
	state.member_named("周禾").health = 0
	state.member_named("许宁").trust = 30
	ui.refresh()
	var before := _snapshot()
	_press("camp_阅读技术手册")
	await _layout()
	_check(_snapshot() == before and state.phase == GameState.Phase.CAMP_ACTION, "打开读者选择不花费物资、不结算夜晚")
	_check(_disabled("read_阿遥") and _disabled("read_周禾"), "疲劳达到70或健康归零的读者禁用")
	_check(not _disabled("read_许宁"), "阅读不受仅适用于教学的信任门槛限制")
	await _click("read_阿遥", false)
	_check(_snapshot() == before, "点击禁用读者不会执行行动")
	await _capture("knowledge_reader_1280")
	await _click("cancel_assignment")
	_check(_snapshot() == before and ui.camp_action_choice.is_empty(), "真实点击返回后完整游戏状态不变")
	_press("camp_阅读技术手册")
	await _click("read_老赵")
	_check(state.phase == GameState.Phase.NIGHT_SETTLEMENT, "选定读者才执行今晚行动")
	_check(state.member_named("老赵").maintenance_knowledge and state.member_named("老赵").learned_from == "技术手册", "实际读者掌握知识且记录手册来源")
	for member in state.members:
		if member.name != "老赵": _check(not member.maintenance_knowledge, "阅读不向其他成员广播知识：" + str(member.name))

func _test_teaching_boundaries() -> void:
	await _fixture()
	_know("老赵", "技术手册")
	state.member_named("老赵").trust = 30
	ui.refresh()
	_check(_disabled("camp_教学与记录"), "教师信任等于30时教学入口禁用")
	state.member_named("老赵").trust = 31
	state.member_named("队长").trust = 30
	state.member_named("许宁").fatigue = 70
	state.member_named("周禾").health = 0
	state.member_named("阿遥").fatigue = 69
	state.member_named("阿遥").trust = 31
	ui.refresh()
	var before := _snapshot()
	_press("camp_教学与记录")
	_check(not _disabled("teacher_老赵") and _disabled("teacher_队长"), "符合条件的掌握者可教学，未掌握者不可担任教师")
	_press("teacher_老赵")
	await _layout()
	_check(_disabled("teach_老赵"), "教师不能向自己教学")
	_check(_disabled("teach_队长"), "学员信任等于30时禁用")
	_check(_disabled("teach_许宁") and _disabled("teach_周禾"), "学员疲劳达到70或健康归零时禁用")
	_check(not _disabled("teach_阿遥"), "健康、疲劳69、信任31的未掌握学员可选")
	await _click("teach_队长", false)
	_check(_snapshot() == before, "点击禁用学员不消耗行动或资源")
	await _click("change_teacher")
	_check(ui.knowledge_teacher.is_empty() and _snapshot() == before, "重新选择教师只清除界面选择")
	_press("teacher_老赵")
	await _click("teach_阿遥")
	_check(state.phase == GameState.Phase.NIGHT_SETTLEMENT, "实际点击学员完成一次教学")
	_check(state.member_named("阿遥").maintenance_knowledge and state.member_named("阿遥").learned_from == "老赵", "学员记录实际教师")
	_check(not state.member_named("队长").maintenance_knowledge and not state.member_named("许宁").maintenance_knowledge, "未选择的学员不会同步获得知识")
	_press("team")
	await _layout()
	_check(_card_text("老赵").contains("来源：技术手册"), "成员总览显示读者的手册来源")
	_check(_card_text("阿遥").contains("来源：老赵"), "成员总览显示学员的实际教师来源")
	_check(_inside_canvas(ui.team_overlay.get_child(0)), "成员总览外框位于画布内")
	var team_scroll := _ancestor(ui.team_cards, "ScrollContainer") as ScrollContainer
	if team_scroll != null:
		for card in ui.team_cards.get_children():
			if _text(card).begins_with("阿遥 · "): team_scroll.ensure_control_visible(card)
		await _layout()
	await _capture("knowledge_team_sources")
	_press("close_team")

func _test_unavailable_teaching() -> void:
	await _fixture()
	var before := _snapshot()
	_check(_disabled("camp_教学与记录"), "无掌握者时教学入口禁用")
	_check(not _disabled("camp_让成员休息"), "无教师时仍有休息出口")
	await _click("camp_让成员休息")
	_check(state.phase == GameState.Phase.NIGHT_SETTLEMENT and _snapshot() != before, "无教师时实际执行休息可继续游戏")
	await _fixture()
	for member in state.members: _know(str(member.name), "技术手册")
	ui.refresh()
	_check(_disabled("camp_教学与记录"), "所有成员已掌握时禁用无效教学入口")
	_check(not _disabled("camp_让成员休息"), "无新学员时返回后仍可休息")
	await _click("camp_让成员休息")
	_check(state.phase == GameState.Phase.NIGHT_SETTLEMENT, "无新学员不会阻断夜间结算")

func _test_pending_selection_and_load() -> void:
	await _fixture()
	_know("老赵", "技术手册")
	ui.refresh()
	var before := _snapshot()
	_press("camp_教学与记录")
	_press("teacher_老赵")
	await _click("camp_tab_medical")
	_check(ui.camp_action_choice.is_empty() and ui.knowledge_teacher.is_empty() and _find(ui, "teach_队长") == null, "切换营地页签清除待执行的教师和学员选择")
	_check(_snapshot() == before, "切换页签不消耗行动")
	_press("camp_tab_daily")
	_press("pause")
	_press("save")
	_check(not ui.save_system.load_from_file().is_empty(), "真实存档按钮写入营地状态")
	_press("resume")
	_press("camp_教学与记录")
	_press("teacher_老赵")
	_check(not ui.knowledge_teacher.is_empty(), "读档前有尚未执行的选择")
	_press("pause")
	await _click("load")
	_check(not ui.paused and ui.camp_action_choice.is_empty() and ui.knowledge_teacher.is_empty(), "读档清除尚未执行的界面选择并继续游戏")
	var restored := _snapshot()
	_check(_equivalent(restored, before) and _find(ui, "camp_让成员休息") != null, "读档恢复完整营地状态与常规行动入口")
	_check(state.member_named("老赵").learned_from == "技术手册", "文件读档保留个人知识来源")

func _test_repair() -> void:
	await _fixture()
	_know("老赵", "技术手册")
	state.vehicle_health = 50
	ui.refresh()
	_press("camp_维修车辆")
	_check(_button_text("repair_老赵").contains("耐久 +21"), "掌握者的维修按钮明确显示21点收益")
	_check(_button_text("repair_队长").contains("耐久 +15"), "未掌握者的维修按钮明确显示15点收益")
	await _capture("knowledge_repair_choices")
	var old_parts := int(state.resources.parts)
	await _click("repair_老赵")
	_check(state.vehicle_health == 71 and int(state.resources.parts) == old_parts - 2, "维修实际耐久增量与所选掌握者的显示收益一致")
	_check(state.phase == GameState.Phase.NIGHT_SETTLEMENT, "维修占用一次营地行动")
	await _fixture()
	state.vehicle_health = 50
	ui.refresh()
	_press("camp_维修车辆")
	await _click("repair_队长")
	_check(state.vehicle_health == 65, "未掌握成员实际修复15点耐久")
	await _fixture()
	_know("老赵", "技术手册")
	state.vehicle_health = 95
	ui.refresh()
	_press("camp_维修车辆")
	_check(_button_text("repair_老赵").contains("耐久 +5"), "接近耐久上限时按钮显示实际可获得的5点收益")
	await _click("repair_老赵")
	_check(state.vehicle_health == 100, "维修收益受100耐久上限约束")
	await _fixture()
	_press("camp_维修车辆")
	state.resources.parts = 1
	ui.refresh()
	var before := _snapshot()
	for member in state.members: _check(_disabled("repair_" + str(member.name)), "不足2个零件时禁用所有维修者：" + str(member.name))
	await _click("repair_队长", false)
	_check(_snapshot() == before, "零件不足的禁用维修按钮不修改状态")
	await _click("cancel_assignment")
	_check(_disabled("camp_维修车辆") and not _disabled("camp_让成员休息"), "取消后不足零件禁用维修入口并保留休息")

func _test_responsive_selection() -> void:
	await _fixture()
	_know("老赵", "技术手册")
	ui.refresh()
	_press("camp_教学与记录")
	_press("teacher_老赵")
	for dimensions in [Vector2i(1280, 720), Vector2i(960, 600), Vector2i(1560, 720)]:
		root.content_scale_size = dimensions
		root.size = dimensions
		await _layout()
		var suffix := "%dx%d" % [dimensions.x, dimensions.y]
		var scroll := _ancestor(ui.actions, "ScrollContainer") as ScrollContainer
		var panel := _ancestor(ui.actions, "PanelContainer") as PanelContainer
		_check(scroll != null and panel != null, "选择列表放在可滚动面板内 " + suffix)
		_check(_inside_canvas(panel) and _inside_canvas(ui.primary_actions), "选择面板及固定操作区不越过画布 " + suffix)
		_check(_viewport_contains(ui.canvas), "游戏画布不越过视口 " + suffix)
		for id in ["cancel_assignment", "change_teacher", "camp_tab_daily", "camp_tab_medical"]:
			_check(_inside_canvas(_find(ui, id)) and _viewport_contains(_find(ui, id)), "固定按钮在画布和视口内 " + id + " " + suffix)
			_check(_ancestor(_find(ui, id), "ScrollContainer") == null, "固定按钮不随成员列表滚走 " + id + " " + suffix)
		if scroll != null:
			scroll.scroll_vertical = 0
			await _layout()
			var cancel_rect := _find(ui, "cancel_assignment").get_global_rect()
			scroll.scroll_vertical = 10000
			await _layout()
			_check(_find(ui, "cancel_assignment").get_global_rect() == cancel_rect, "成员列表滚到底仍保留相同位置的返回按钮 " + suffix)
			scroll.scroll_vertical = 0
			await _layout()
		await _capture("knowledge_teaching_" + suffix)
		var before := _snapshot()
		await _click("change_teacher")
		_check(ui.knowledge_teacher.is_empty() and _snapshot() == before, "对应尺寸真实点击重新选择教师 " + suffix)
		_press("teacher_老赵")
	root.content_scale_size = Vector2i(1280, 720)
	root.size = Vector2i(1280, 720)
	await _layout()

func _know(member_name: String, source: String) -> void:
	var member := state.member_named(member_name)
	member.maintenance_knowledge = true
	member.learned_from = source

func _snapshot() -> Dictionary:
	return ui.save_system.snapshot(state, ui.day_loop)

func _equivalent(left: Variant, right: Variant) -> bool:
	# JSON loads numbers as floats; restore deliberately normalizes resource counts.
	if (left is int or left is float) and (right is int or right is float): return float(left) == float(right)
	if left is Dictionary and right is Dictionary:
		if left.size() != right.size(): return false
		for key in left:
			if not right.has(key) or not _equivalent(left[key], right[key]): return false
		return true
	if left is Array and right is Array:
		if left.size() != right.size(): return false
		for i in range(left.size()):
			if not _equivalent(left[i], right[i]): return false
		return true
	return left == right

func _find(node: Node, id: String) -> Button:
	if node is Button and str(node.get_meta("action_id", "")) == id: return node
	for child in node.get_children():
		var found := _find(child, id)
		if found != null: return found
	return null

func _disabled(id: String) -> bool:
	var button := _find(ui, id)
	_check(button != null, "存在按钮 " + id)
	return button == null or button.disabled

func _button_text(id: String) -> String:
	var button := _find(ui, id)
	_check(button != null, "存在收益按钮 " + id)
	return button.text if button != null else ""

func _press(id: String) -> void:
	var button := _find(ui, id)
	_check(button != null and not button.disabled, "按钮可用 " + id)
	if button != null and not button.disabled: button.pressed.emit()

func _click(id: String, enabled: bool = true) -> void:
	await _layout()
	var button := _find(ui, id)
	_check(button != null and button.disabled != enabled, "真实点击按钮状态 " + id)
	if button == null or button.disabled == enabled: return
	var scroll := _ancestor(button, "ScrollContainer") as ScrollContainer
	if scroll != null:
		scroll.ensure_control_visible(button)
		await _layout()
	var event := InputEventMouseButton.new()
	event.position = button.get_global_rect().get_center()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event, true)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await _layout()

func _ancestor(node: Node, class_name_key: String) -> Node:
	if node == null: return null
	var current := node.get_parent()
	while current != null:
		if current.is_class(class_name_key): return current
		current = current.get_parent()
	return null

func _inside_canvas(node: Node) -> bool:
	if not node is Control: return false
	return ui.canvas.get_global_rect().grow(0.5).encloses(node.get_global_rect())

func _viewport_contains(node: Node) -> bool:
	if not node is Control: return false
	return root.get_visible_rect().grow(0.5).encloses(node.get_global_rect())

func _card_text(member_name: String) -> String:
	for card in ui.team_cards.get_children():
		var text := _text(card)
		if text.begins_with(member_name + " · "): return text
	return ""

func _text(node: Node) -> String:
	if node is Label: return node.text
	var lines: Array[String] = []
	for child in node.get_children():
		var part := _text(child)
		if not part.is_empty(): lines.append(part)
	return "\n".join(lines)

func _layout() -> void:
	for frame in range(3): await process_frame

func _capture(name_key: String) -> void:
	if not capture: return
	await _layout()
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png(output_dir + "/" + name_key + ".png") == OK, "保存知识功能截图 " + name_key)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)
