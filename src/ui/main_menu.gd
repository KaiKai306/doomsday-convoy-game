extends Control

const DAY_DEMO_SCENE := preload("res://scenes/day_demo.tscn")

@onready var status_label: Label = %StatusLabel
@onready var menu: VBoxContainer = $Menu
@onready var title_label: Label = $Title
@onready var subtitle_label: Label = $Subtitle
@onready var shade: ColorRect = $Shade
@onready var demo_panel: Panel = $DemoPanel
@onready var game_state: GameState = $GameState

var _day_demo: DayDemo

func _ready() -> void:
	status_label.text = "Demo 版式占位\nGodot 4.7.2 · 背景美术待替换"

func _on_new_game_pressed() -> void:
	menu.hide()
	title_label.hide()
	subtitle_label.hide()
	shade.hide()
	demo_panel.hide()
	_day_demo = DAY_DEMO_SCENE.instantiate()
	_day_demo.position = Vector2(58, 48)
	add_child(_day_demo)
	_day_demo.return_to_menu.connect(_return_to_menu)
	_day_demo.setup(game_state)

func _on_options_pressed() -> void:
	status_label.text = "选项入口已预留\n下一步：接入画面、音频和触控设置"

func _on_exit_pressed() -> void:
	status_label.text = "退出按钮已触发\nDemo 阶段暂不关闭应用"

func _return_to_menu() -> void:
	if is_instance_valid(_day_demo):
		_day_demo.queue_free()
		_day_demo = null
	menu.show()
	title_label.show()
	subtitle_label.show()
	shade.show()
	demo_panel.show()
	status_label.text = "Demo 已完成第 1 天\n可以再次开始测试"

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
