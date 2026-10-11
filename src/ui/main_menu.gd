extends Control

const DAY_SCENE := preload("res://scenes/day_demo.tscn")
var frame: Control
var menu: Control
var world: ConvoyWorld
var game_state: GameState
var day_demo: DayDemo
var save_system := SaveSystem.new()
var message: Label
var continue_button: Button
var confirmation: ConfirmationDialog

func _ready() -> void:
	theme = ConvoyTheme.create()
	game_state = GameState.new()
	add_child(game_state)
	frame = Control.new()
	frame.size = Vector2(1280, 720)
	add_child(frame)
	get_viewport().size_changed.connect(_fit)
	_fit()
	world = ConvoyWorld.new()
	world.phase = -1
	world.size = Vector2(1280, 720)
	frame.add_child(world)
	menu = Control.new()
	menu.size = Vector2(1280, 720)
	frame.add_child(menu)
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.055, 0.09, 0.91)
	shade.size = Vector2(510, 720)
	menu.add_child(shade)
	var text := VBoxContainer.new()
	text.position = Vector2(58, 65)
	text.size = Vector2(390, 580)
	menu.add_child(text)
	text.add_child(ConvoyTheme.label("DOOMSDAY  /  CONVOY", 16, ConvoyTheme.GOLD))
	text.add_child(ConvoyTheme.label("末日车队", 60))
	text.add_child(ConvoyTheme.label("把今天熬过去。\n把明天留给彼此。", 23, ConvoyTheme.MUTED))
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 25
	text.add_child(spacer)
	text.add_child(ConvoyTheme.button("开始新的旅程  →", _start_game, "new_game"))
	continue_button = ConvoyTheme.button("继续旅程", _continue, "continue_game")
	continue_button.disabled = save_system.load_from_file().is_empty()
	text.add_child(continue_button)
	text.add_child(ConvoyTheme.button("关于这段旅途", _about, "about"))
	text.add_child(ConvoyTheme.button("离开游戏", func(): confirmation.popup_centered(Vector2i(420, 180)), "exit"))
	message = ConvoyTheme.label("五日体验版 0.3\n营地探索 / 成员对话 / 共同记忆", 16, ConvoyTheme.MUTED)
	text.add_child(message)
	var intro := PanelContainer.new()
	intro.position = Vector2(790, 75)
	intro.size = Vector2(430, 150)
	menu.add_child(intro)
	intro.add_child(ConvoyTheme.label("01   向山口出发\n\n五个人，一辆旧车。\n每一次分配，都在决定车队的未来。", 20))
	var footer := ConvoyTheme.label("Game Jam 体验版 · 场景为程序绘制占位", 13, ConvoyTheme.MUTED)
	footer.position = Vector2(790, 676)
	footer.size.x = 450
	menu.add_child(footer)
	confirmation = ConfirmationDialog.new()
	confirmation.title = "离开游戏"
	confirmation.dialog_text = "确认离开这段旅途？"
	confirmation.ok_button_text = "离开"
	confirmation.cancel_button_text = "留下"
	confirmation.confirmed.connect(func(): get_tree().quit())
	add_child(confirmation)

func _fit() -> void:
	var viewport_size := get_viewport_rect().size
	var factor := minf(viewport_size.x / 1280.0, viewport_size.y / 720.0)
	frame.scale = Vector2.ONE * factor
	frame.position = (viewport_size - Vector2(1280, 720) * factor) / 2

func _start_game(saved: Dictionary = {}) -> void:
	if is_instance_valid(day_demo): return
	day_demo = DAY_SCENE.instantiate()
	add_child(day_demo)
	if not day_demo.setup(game_state, saved):
		day_demo.queue_free()
		day_demo = null
		message.text = "存档不兼容或已损坏。可以开始新的旅程。"
		return
	frame.hide()
	world.set_process(false)
	day_demo.return_to_menu.connect(_return_to_menu)

func _continue() -> void:
	var saved := save_system.load_from_file()
	if saved.is_empty():
		message.text = "还没有保存过旅途。请先开始新游戏。"
		return
	_start_game(saved)

func _return_to_menu() -> void:
	if is_instance_valid(day_demo):
		day_demo.queue_free()
		day_demo = null
	frame.show()
	world.set_process(true)
	continue_button.disabled = save_system.load_from_file().is_empty()
	message.text = "篝火还在。准备好后，再次上路。"

func _about() -> void:
	message.text = "每天：准备 → 选路 → 行进 → 对话 → 营地 → 夜晚\n试着让生存经验成为大家共享的知识。\n暂停菜单可以随时保存。"
