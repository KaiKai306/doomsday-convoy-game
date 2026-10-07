extends Control

@onready var status_label: Label = %StatusLabel
@onready var menu: VBoxContainer = $Menu
@onready var title_label: Label = $Title
@onready var subtitle_label: Label = $Subtitle
@onready var shade: ColorRect = $Shade
@onready var demo_panel: Panel = $DemoPanel
@onready var game_state: GameState = $GameState

var _day_loop: DayLoop
var _day_panel: Panel
var _phase_title: Label
var _phase_body: Label
var _phase_hint: Label
var _phase_actions: VBoxContainer
func _ready() -> void:
	status_label.text = "Demo 版式占位\nGodot 4.7.2 · 背景美术待替换"

func _on_new_game_pressed() -> void:
	_day_loop = DayLoop.new(game_state)
	_day_loop.start_new_game()
	menu.hide()
	title_label.hide()
	subtitle_label.hide()
	shade.hide()
	demo_panel.hide()
	_build_day_demo()
	_show_phase(GameState.Phase.MORNING)

func _on_options_pressed() -> void:
	status_label.text = "选项入口已预留\n下一步：接入画面、音频和触控设置"

func _on_exit_pressed() -> void:
	status_label.text = "退出按钮已触发\nDemo 阶段暂不关闭应用"

func _build_day_demo() -> void:
	if is_instance_valid(_day_panel):
		return
	_day_panel = Panel.new()
	_day_panel.name = "DayDemo"
	_day_panel.position = Vector2(58, 48)
	_day_panel.size = Vector2(1164, 624)
	add_child(_day_panel)

	var heading := Label.new()
	heading.position = Vector2(32, 24)
	heading.size = Vector2(760, 44)
	heading.add_theme_font_size_override("font_size", 28)
	heading.add_theme_color_override("font_color", Color("e6b35d"))
	_day_panel.add_child(heading)
	_phase_title = heading

	_phase_body = Label.new()
	_phase_body.position = Vector2(32, 88)
	_phase_body.size = Vector2(740, 180)
	_phase_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_phase_body.add_theme_font_size_override("font_size", 20)
	_phase_body.add_theme_color_override("font_color", Color("d0d4cc"))
	_day_panel.add_child(_phase_body)

	_phase_hint = Label.new()
	_phase_hint.position = Vector2(32, 492)
	_phase_hint.size = Vector2(740, 72)
	_phase_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_phase_hint.add_theme_color_override("font_color", Color("9ca6a0"))
	_day_panel.add_child(_phase_hint)

	_phase_actions = VBoxContainer.new()
	_phase_actions.position = Vector2(790, 92)
	_phase_actions.size = Vector2(320, 450)
	_phase_actions.add_theme_constant_override("separation", 12)
	_day_panel.add_child(_phase_actions)

func _show_phase(next_phase: GameState.Phase) -> void:
	game_state.set_phase(next_phase)
	_clear_actions()
	_phase_title.text = "第 %d 天 · %s" % [game_state.day, _phase_name(next_phase)]
	_phase_hint.text = "当前资源：%s\n事件记录：%s" % [_day_loop.resources_text(), _day_loop.event_log_text()]

	match next_phase:
		GameState.Phase.MORNING:
			_phase_body.text = "昨夜车队在临时营地停下。\n成员：5 人（队长、维修、医疗、侦察、后勤）\n车辆：掠夺者，耐久 80/100\n资源：饮水、食物、燃料、药品、零件\n\nNPC 事务：维修员请求优先分配零件；侦察员报告东侧路线有无线电信号。"
			_add_action("确认早晨准备", func(): _show_phase(GameState.Phase.ROUTE_SELECTION))
		GameState.Phase.ROUTE_SELECTION:
			_phase_body.text = "选择今天的路线。路线会影响燃料消耗、抵达时间和移动突发概率。\n\n当前选择：%s" % _day_loop.route_choice
			_add_action("安全路线（燃料 -4）", func(): _choose_route("安全路线"))
			_add_action("资源路线（燃料 -6）", func(): _choose_route("资源路线"))
			_add_action("未知路线（燃料 -5）", func(): _choose_route("未知路线"))
			_add_action("确认出发", func(): _start_travel())
		GameState.Phase.TRAVEL:
			_phase_body.text = "车队正在沿“%s”前进……\n\n移动阶段暂时不打开完整对话菜单，只处理预设行动和即时突发。" % _day_loop.route_choice
			_add_action("继续前进", func(): _finish_travel())
		GameState.Phase.REST_STOP:
			_phase_body.text = "车队抵达停歇点。维修员希望立即使用零件修复车辆。你可以接受、拒绝或暂缓处理。"
			_add_action("接受请求（零件 -2，信任 +1）", func(): _resolve_dialogue("接受请求", 2, 1))
			_add_action("拒绝请求（保留零件，信任 -1）", func(): _resolve_dialogue("拒绝请求", 0, -1))
			_add_action("暂缓处理（信任 -0）", func(): _resolve_dialogue("暂缓处理", 0, 0))
		GameState.Phase.CAMP_ACTION:
			_phase_body.text = "停歇对话结束。今晚只能执行一次主要营地行动。"
			_add_action("维修车辆（零件 -2，车辆状态 +10）", func(): _camp_action("维修车辆", 2))
			_add_action("阅读技术手册（知识 +1）", func(): _camp_action("阅读技术手册", 0))
			_add_action("让成员休息（疲劳 -1）", func(): _camp_action("让成员休息", 0))
		GameState.Phase.NIGHT_SETTLEMENT:
			_phase_body.text = "夜间结算完成。今天的选择已经写入事件记录，资源会在下一天继续消耗。\n\n%s" % _day_loop.event_log_text()
			_add_action("返回主菜单", func(): _return_to_menu())

func _choose_route(route_name: String) -> void:
	_day_loop.choose_route(route_name)
	_show_phase(GameState.Phase.ROUTE_SELECTION)

func _start_travel() -> void:
	_day_loop.start_travel()
	_show_phase(GameState.Phase.TRAVEL)

func _finish_travel() -> void:
	_day_loop.resolve_travel_event()
	_show_phase(GameState.Phase.REST_STOP)

func _resolve_dialogue(result: String, parts_cost: int, trust_change: int) -> void:
	_day_loop.resolve_dialogue(result, parts_cost, trust_change)
	_show_phase(GameState.Phase.CAMP_ACTION)

func _camp_action(action_name: String, parts_cost: int) -> void:
	_day_loop.perform_camp_action(action_name, parts_cost)
	_show_phase(GameState.Phase.NIGHT_SETTLEMENT)

func _return_to_menu() -> void:
	if is_instance_valid(_day_panel):
		_day_panel.queue_free()
		_day_panel = null
	menu.show()
	title_label.show()
	subtitle_label.show()
	shade.show()
	demo_panel.show()
	_day_loop = null
	status_label.text = "Demo 已完成第 1 天\n可以再次开始测试"

func _clear_actions() -> void:
	for child in _phase_actions.get_children():
		child.queue_free()

func _add_action(label_text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(320, 54)
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(callback)
	_phase_actions.add_child(button)

func _phase_name(current_phase: GameState.Phase) -> String:
	match current_phase:
		GameState.Phase.MORNING: return "早晨准备"
		GameState.Phase.ROUTE_SELECTION: return "路线选择"
		GameState.Phase.TRAVEL: return "移动阶段"
		GameState.Phase.REST_STOP: return "停歇对话"
		GameState.Phase.CAMP_ACTION: return "营地行动"
		GameState.Phase.NIGHT_SETTLEMENT: return "夜间结算"
		_: return "结束"

func _draw() -> void:
	# 临时背景只使用几何图形，正式背景资源稍后替换。
	draw_rect(Rect2(Vector2.ZERO, size), Color("111820"))
	draw_circle(Vector2(size.x * 0.78, size.y * 0.24), 92.0, Color("8d8063"))
	draw_circle(Vector2(size.x * 0.78, size.y * 0.24), 78.0, Color("b2a27a"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, size.y * 0.70),
		Vector2(size.x * 0.26, size.y * 0.53),
		Vector2(size.x * 0.48, size.y * 0.69),
		Vector2(size.x * 0.67, size.y * 0.56),
		Vector2(size.x, size.y * 0.70),
		Vector2(size.x, size.y),
		Vector2(0, size.y),
	]), Color("1f2b2d"))
	draw_line(Vector2(0, size.y * 0.70), Vector2(size.x, size.y * 0.70), Color("92764d"), 3.0)
