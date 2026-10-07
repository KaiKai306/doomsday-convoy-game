extends Control

@onready var status_label: Label = %StatusLabel

func _ready() -> void:
	status_label.text = "Demo 版式占位\nGodot 4.7.2 · 背景美术待替换"

func _on_new_game_pressed() -> void:
	status_label.text = "新游戏入口已接通\n下一步：进入第 1 天早晨阶段"

func _on_options_pressed() -> void:
	status_label.text = "选项入口已预留\n下一步：接入画面、音频和触控设置"

func _on_exit_pressed() -> void:
	status_label.text = "退出按钮已触发\nDemo 阶段暂不关闭应用"

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
