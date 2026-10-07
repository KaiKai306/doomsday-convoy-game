class_name DayDemo
extends Panel

signal return_to_menu

const SAVE_SYSTEM_SCRIPT = preload("res://src/core/save_system.gd")

@onready var phase_title: Label = $PhaseTitle
@onready var phase_body: Label = $PhaseBody
@onready var phase_hint: Label = $PhaseHint
@onready var phase_actions: VBoxContainer = $PhaseActions
@onready var pause_button: Button = $PauseButton
@onready var pause_overlay: ColorRect = $PauseOverlay
@onready var pause_status: Label = $PauseOverlay/PauseCard/Status

var game_state: GameState
var day_loop: DayLoop
var save_system = SAVE_SYSTEM_SCRIPT.new()

func _ready() -> void:
	pause_button.pressed.connect(_toggle_pause)
	$PauseOverlay/PauseCard/Actions/Continue.pressed.connect(_continue_game)
	$PauseOverlay/PauseCard/Actions/Save.pressed.connect(_save_progress)
	$PauseOverlay/PauseCard/Actions/Load.pressed.connect(_load_progress)
	$PauseOverlay/PauseCard/Actions/Menu.pressed.connect(_leave_to_menu)

func setup(state: GameState) -> void:
	game_state = state
	day_loop = DayLoop.new(game_state, DemoContent.new())
	day_loop.start_new_game()
	_show_phase(GameState.Phase.MORNING)

func _toggle_pause() -> void:
	_set_pause_visible(not pause_overlay.visible)

func _set_pause_visible(visible: bool) -> void:
	pause_overlay.visible = visible
	pause_button.disabled = visible
	if visible:
		pause_status.text = "游戏已暂停"
		pause_overlay.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(pause_overlay, "modulate:a", 1.0, 0.18)

func _continue_game() -> void:
	_set_pause_visible(false)

func _save_progress() -> void:
	if day_loop == null:
		pause_status.text = "当前没有可保存的游戏"
		return
	if save_system.save_to_file(game_state, day_loop):
		pause_status.text = "已保存：第 %d 天 · %s" % [game_state.day, _phase_name(game_state.phase)]
	else:
		pause_status.text = "保存失败，请检查存档目录"

func _load_progress() -> void:
	if day_loop == null:
		pause_status.text = "当前没有可读取的游戏"
		return
	var snapshot: Dictionary = save_system.load_from_file()
	if snapshot.is_empty() or not save_system.restore(snapshot, game_state, day_loop):
		pause_status.text = "没有找到可用存档"
		return
	_set_pause_visible(false)
	_show_phase(game_state.phase)

func _leave_to_menu() -> void:
	_set_pause_visible(false)
	return_to_menu.emit()

func _show_phase(next_phase: GameState.Phase) -> void:
	game_state.set_phase(next_phase)
	_clear_actions()
	phase_title.text = "第 %d 天 · %s" % [game_state.day, _phase_name(next_phase)]
	phase_hint.text = "当前资源：%s\n事件记录：%s" % [day_loop.resources_text(), day_loop.event_log_text()]
	phase_title.modulate.a = 0.0
	phase_body.modulate.a = 0.0
	phase_hint.modulate.a = 0.0
	phase_actions.modulate.a = 0.0

	match next_phase:
		GameState.Phase.MORNING:
			phase_body.text = "昨夜车队在临时营地停下。\n成员：%s\n车辆：%s\n资源：饮水、食物、燃料、药品、零件\n\n今日 NPC 事务：\n%s" % [day_loop.content.members_summary(), day_loop.content.vehicle_summary(), day_loop.transaction_summary()]
			_add_action("确认早晨准备", func(): _show_phase(GameState.Phase.ROUTE_SELECTION))
		GameState.Phase.ROUTE_SELECTION:
			phase_body.text = "选择今天的路线。路线会影响燃料消耗、抵达时间和移动突发概率。\n\n当前选择：%s" % day_loop.route_choice
			_add_action("安全路线（燃料 -%d）" % day_loop.content.route_fuel_cost("安全路线"), func(): _choose_route("安全路线"))
			_add_action("资源路线（燃料 -%d）" % day_loop.content.route_fuel_cost("资源路线"), func(): _choose_route("资源路线"))
			_add_action("未知路线（燃料 -%d）" % day_loop.content.route_fuel_cost("未知路线"), func(): _choose_route("未知路线"))
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
			phase_body.text = "夜间结算完成。今天的选择已经写入事件记录，资源会在下一天继续消耗。\n\n当天记录：\n%s\n\n下一日因果：\n%s" % [day_loop.event_log_text(), day_loop.next_day_effects_text()]
			_add_action("进入第 %d 天" % (game_state.day + 1), func(): _advance_day())
			_add_action("返回主菜单", func(): return_to_menu.emit())

	_animate_phase_content()

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

func _advance_day() -> void:
	day_loop.advance_to_next_day()
	_show_phase(GameState.Phase.MORNING)

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
	button.modulate.a = 0.0
	button.scale = Vector2(0.96, 0.96)
	var delay := maxf(0.0, float(phase_actions.get_child_count() - 1) * 0.045)
	var tween := create_tween().set_parallel()
	tween.tween_property(button, "modulate:a", 1.0, 0.22).set_delay(delay)
	tween.tween_property(button, "scale", Vector2.ONE, 0.26).set_delay(delay)

func _animate_phase_content() -> void:
	var tween := create_tween().set_parallel()
	tween.tween_property(phase_title, "modulate:a", 1.0, 0.22)
	tween.tween_property(phase_body, "modulate:a", 1.0, 0.30).set_delay(0.06)
	tween.tween_property(phase_hint, "modulate:a", 1.0, 0.24).set_delay(0.12)
	tween.tween_property(phase_actions, "modulate:a", 1.0, 0.26).set_delay(0.16)

func _phase_name(current_phase: GameState.Phase) -> String:
	match current_phase:
		GameState.Phase.MORNING: return "早晨准备"
		GameState.Phase.ROUTE_SELECTION: return "路线选择"
		GameState.Phase.TRAVEL: return "移动阶段"
		GameState.Phase.REST_STOP: return "停歇对话"
		GameState.Phase.CAMP_ACTION: return "营地行动"
		GameState.Phase.NIGHT_SETTLEMENT: return "夜间结算"
		_: return "结束"
