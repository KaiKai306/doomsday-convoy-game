class_name DayDemo
extends Panel

signal return_to_menu

@onready var phase_title: Label = $PhaseTitle
@onready var phase_body: Label = $PhaseBody
@onready var phase_hint: Label = $PhaseHint
@onready var phase_actions: VBoxContainer = $PhaseActions

var game_state: GameState
var day_loop: DayLoop

func setup(state: GameState) -> void:
	game_state = state
	day_loop = DayLoop.new(game_state)
	day_loop.start_new_game()
	_show_phase(GameState.Phase.MORNING)

func _show_phase(next_phase: GameState.Phase) -> void:
	game_state.set_phase(next_phase)
	_clear_actions()
	phase_title.text = "第 %d 天 · %s" % [game_state.day, _phase_name(next_phase)]
	phase_hint.text = "当前资源：%s\n事件记录：%s" % [day_loop.resources_text(), day_loop.event_log_text()]

	match next_phase:
		GameState.Phase.MORNING:
			phase_body.text = "昨夜车队在临时营地停下。\n成员：5 人（队长、维修、医疗、侦察、后勤）\n车辆：掠夺者，耐久 80/100\n资源：饮水、食物、燃料、药品、零件\n\nNPC 事务：维修员请求优先分配零件；侦察员报告东侧路线有无线电信号。"
			_add_action("确认早晨准备", func(): _show_phase(GameState.Phase.ROUTE_SELECTION))
		GameState.Phase.ROUTE_SELECTION:
			phase_body.text = "选择今天的路线。路线会影响燃料消耗、抵达时间和移动突发概率。\n\n当前选择：%s" % day_loop.route_choice
			_add_action("安全路线（燃料 -4）", func(): _choose_route("安全路线"))
			_add_action("资源路线（燃料 -6）", func(): _choose_route("资源路线"))
			_add_action("未知路线（燃料 -5）", func(): _choose_route("未知路线"))
			_add_action("确认出发", func(): _start_travel())
		GameState.Phase.TRAVEL:
			phase_body.text = "车队正在沿“%s”前进……\n\n移动阶段暂时不打开完整对话菜单，只处理预设行动和即时突发。" % day_loop.route_choice
			_add_action("继续前进", func(): _finish_travel())
		GameState.Phase.REST_STOP:
			phase_body.text = "车队抵达停歇点。维修员希望立即使用零件修复车辆。你可以接受、拒绝或暂缓处理。"
			_add_action("接受请求（零件 -2，信任 +1）", func(): _resolve_dialogue("接受请求", 2, 1))
			_add_action("拒绝请求（保留零件，信任 -1）", func(): _resolve_dialogue("拒绝请求", 0, -1))
			_add_action("暂缓处理（信任 -0）", func(): _resolve_dialogue("暂缓处理", 0, 0))
		GameState.Phase.CAMP_ACTION:
			phase_body.text = "停歇对话结束。今晚只能执行一次主要营地行动。"
			_add_action("维修车辆（零件 -2，车辆状态 +10）", func(): _camp_action("维修车辆", 2))
			_add_action("阅读技术手册（知识 +1）", func(): _camp_action("阅读技术手册", 0))
			_add_action("让成员休息（疲劳 -1）", func(): _camp_action("让成员休息", 0))
		GameState.Phase.NIGHT_SETTLEMENT:
			phase_body.text = "夜间结算完成。今天的选择已经写入事件记录，资源会在下一天继续消耗。\n\n%s" % day_loop.event_log_text()
			_add_action("返回主菜单", func(): return_to_menu.emit())

func _choose_route(route_name: String) -> void:
	day_loop.choose_route(route_name)
	_show_phase(GameState.Phase.ROUTE_SELECTION)

func _start_travel() -> void:
	day_loop.start_travel()
	_show_phase(GameState.Phase.TRAVEL)

func _finish_travel() -> void:
	day_loop.resolve_travel_event()
	_show_phase(GameState.Phase.REST_STOP)

func _resolve_dialogue(result: String, parts_cost: int, trust_change: int) -> void:
	day_loop.resolve_dialogue(result, parts_cost, trust_change)
	_show_phase(GameState.Phase.CAMP_ACTION)

func _camp_action(action_name: String, parts_cost: int) -> void:
	day_loop.perform_camp_action(action_name, parts_cost)
	_show_phase(GameState.Phase.NIGHT_SETTLEMENT)

func _clear_actions() -> void:
	for child in phase_actions.get_children():
		child.queue_free()

func _add_action(label_text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(320, 54)
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(callback)
	phase_actions.add_child(button)

func _phase_name(current_phase: GameState.Phase) -> String:
	match current_phase:
		GameState.Phase.MORNING: return "早晨准备"
		GameState.Phase.ROUTE_SELECTION: return "路线选择"
		GameState.Phase.TRAVEL: return "移动阶段"
		GameState.Phase.REST_STOP: return "停歇对话"
		GameState.Phase.CAMP_ACTION: return "营地行动"
		GameState.Phase.NIGHT_SETTLEMENT: return "夜间结算"
		_: return "结束"
