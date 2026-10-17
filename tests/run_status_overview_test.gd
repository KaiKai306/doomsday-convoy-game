extends SceneTree

var failures := 0
var checks := 0
var capture := false
var output := ""
var ui: DayDemo

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	capture = "--capture" in args
	output = args[0] if not args.is_empty() else ProjectSettings.globalize_path("res://.godot/status-overview-qa")
	DirAccess.make_dir_recursive_absolute(output)
	# Graphical captures use an invisible host window and an off-screen viewport.
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	ui = load("res://scenes/day_demo.tscn").instantiate()
	viewport.add_child(ui)
	await process_frame
	ui.set_process(false)
	var state := GameState.new()
	ui.add_child(state)
	ui.setup(state)
	await process_frame
	await process_frame
	var original := _state()
	_press("team")
	var overview := ui.team_overlay
	_check(ui.team_open and overview.visible and ui.world.paused, "总览打开并暂停行进")
	_check(overview.team_cards.get_child_count() == 5, "显示现有五名成员")
	_check(overview.resource_values.water.text == "%d 份" % state.resources.water, "资源显示真实库存")
	_check(overview.stop_label.text.contains("今日目标"), "未出发不假装抵达")
	_check(overview.resource_bars.water.size.y <= 8, "资源细条不覆盖配给提示")
	_check(Rect2(Vector2.ZERO, overview.map_surface.size).encloses(overview.map_surface.get_child(0).get_rect()), "地图图片约束在地图面板内")
	await _capture(viewport, "01_status_overview_1280x720")
	_press("map_next")
	_check(overview.map_page == 1 and overview.page_label.text == "2/2", "十个地点翻到第二页")
	for i in range(5):
		_press("stop_%d" % i)
		_check(overview.selected_stop == i + 6 and overview.stop_label.text.contains(ui.day_loop.content.stop_name(i + 6)), "地点闭包 %d 对应真实名称" % (i + 6))
	_press("map_next")
	_check(overview.map_page == 1, "末页不会越界")
	await _capture(viewport, "02_route_page_two")
	_press("map_previous")
	_press("map_previous")
	_check(overview.map_page == 0, "首页不会越界")
	for member in state.members:
		_press("member_" + str(member.name))
		_check(overview.member_detail.visible and overview.detail_name.text.contains(member.name), "可查看成员 " + str(member.name))
		_check(overview.detail_summary.text.contains(str(member.last_memory)), "成员记忆来自实际状态")
		await _capture(viewport, "portrait_detail_" + StatusOverview.PORTRAITS[str(member.name)])
		_press("close_member_detail")
		_check(not overview.member_detail.visible and ui.team_open, "详情返回总览")
	_check(_state() == original, "翻页与成员详情不修改玩法状态")
	_press("close_team")
	_check(not ui.team_open and not ui.world.paused and _state() == original, "关闭总览保留当前阶段及状态")
	# Actual travel must remain frozen while the overview is open.
	state.phase = GameState.Phase.TRAVEL
	ui.day_loop.travel_progress = 0.2
	ui.refresh()
	_press("team")
	ui._process(30)
	_check(is_equal_approx(ui.day_loop.travel_progress, 0.2) and state.phase == GameState.Phase.TRAVEL, "总览暂停实际行进计时")
	ui._toggle_pause()
	_check(not ui.paused and not ui.pause_overlay.visible, "总览不会叠加存档菜单")
	_press("member_老张")
	_cancel()
	_check(ui.team_open and not overview.member_detail.visible, "Escape先关闭成员详情")
	_cancel()
	_check(not ui.team_open and not overview.visible and state.phase == GameState.Phase.TRAVEL, "Escape返回原游戏阶段")
	ui._process(0.05)
	_check(ui.day_loop.travel_progress > 0.2, "关闭后恢复行进")
	# Warning values and long memories are fixtures, not fabricated defaults.
	state.day = 7
	state.phase = GameState.Phase.REST_STOP
	state.resources.water = 1
	state.resources.food = 0
	state.resources.fuel = 0
	state.resources.parts = 0
	state.resources.medicine = 0
	state.team_trust = 29
	state.members[1].health = 65
	state.members[2].fatigue = 75
	state.members[3].trust = 25
	state.members[1].last_memory = "我记得你在道路维修点分给我一份零件。".repeat(20)
	state.sync_fatigue()
	ui.refresh()
	_press("team")
	_check(overview.map_page == 1 and overview.selected_stop == 7 and overview.stop_label.text.contains("当前"), "重新打开定位当天已抵达地点")
	for key in ["water", "food", "fuel", "medicine", "parts", "trust"]:
		_check(overview.resource_hints[key].text.begins_with("不足"), "实际不足警示 " + key)
	_check(StatusOverview.member_condition(state.members[1]).text == "受伤", "真实受伤状态")
	_check(StatusOverview.member_condition(state.members[2]).text == "疲惫", "真实疲劳状态")
	_check(StatusOverview.member_condition(state.members[3]).text == "不安", "真实低信任状态")
	await _capture(viewport, "03_warnings_day_seven")
	_press("member_老张")
	await process_frame
	await process_frame
	_check(overview.detail_summary.size.y > overview.detail_scroll.size.y, "长记忆可滚动且不挤占按钮")
	await _capture(viewport, "04_member_detail_long_memory")
	state.members[1].health = 80
	state.members[1].last_memory = "照料后恢复了一些精神。"
	await process_frame
	await process_frame
	_check(overview.detail_summary.text.contains("80 / 100") and overview.detail_summary.text.contains("照料后"), "打开详情也同步真实变化")
	await _capture(viewport, "05_member_detail")
	_press("close_member_detail")
	state.resources.water = 150
	await process_frame
	await process_frame
	_check(overview.resource_values.water.text == "150 份" and state.resources.water == 150, "超初始资源不截断真实数值")
	for resolution in [Vector2i(960, 600), Vector2i(1560, 720)]:
		viewport.size = resolution
		await process_frame
		await process_frame
		for action in ["close_team", "map_next", "member_老张"]:
			var button := _find(ui, action) as Button
			_check(Rect2(Vector2.ZERO, Vector2(resolution)).encloses(button.get_global_rect()), "按钮适配 %s %s" % [resolution, action])
		await _capture(viewport, "06_status_%dx%d" % [resolution.x, resolution.y])
	var before_return := _state()
	_press("close_team")
	_check(state.day == 7 and state.phase == GameState.Phase.REST_STOP and before_return == _state(), "底部按钮只返回当前阶段")
	_check(ui.exploration.active and not ui.exploration.blocked, "返回停歇点恢复营地操作")
	for phase in GameState.Phase.values():
		state.phase = phase
		ui.refresh()
		var before := _state()
		_press("team")
		_press("close_team")
		_check(_state() == before, "总览返回保持阶段 %d 的完整存档状态" % phase)
	print("STATUS_OVERVIEW_TEST_%s checks=%d failures=%d" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	ui.queue_free()
	await process_frame
	quit(1 if failures else 0)

func _state() -> String:
	return JSON.stringify(ui.save_system.snapshot(ui.game_state, ui.day_loop))

func _cancel() -> void:
	var event := InputEventAction.new()
	event.action = "ui_cancel"
	event.pressed = true
	ui.team_overlay._unhandled_key_input(event)

func _find(node: Node, action: String) -> Node:
	if node.get_meta("action_id", "") == action: return node
	for child in node.get_children():
		var found := _find(child, action)
		if found != null: return found
	return null

func _press(action: String) -> void:
	var button := _find(ui, action) as Button
	if button == null:
		_check(false, "未找到 " + action)
		return
	button.pressed.emit()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _capture(viewport: SubViewport, name: String) -> void:
	if not capture: return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var picture := viewport.get_texture().get_image()
	_check(picture != null and not picture.is_empty(), "实际渲染 " + name)
	if picture != null: picture.save_png(output.path_join(name + ".png"))
