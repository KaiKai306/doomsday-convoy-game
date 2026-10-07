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
var _background_particles: Array[Dictionary] = []
var _background_time: float = 0.0

func _ready() -> void:
	status_label.text = "Demo 版式占位\nGodot 4.7.2 · 背景美术待替换"
	_init_background_particles()
	_animate_menu_in()

func _process(delta: float) -> void:
	_background_time += delta
	for particle in _background_particles:
		var position: Vector2 = particle["position"]
		position.x -= float(particle["speed"]) * delta
		position.y -= float(particle["drift"]) * delta
		if position.x < -12.0:
			position.x = size.x + 12.0
		if position.y < size.y * 0.28:
			position.y = size.y * 0.82
		particle["position"] = position
	queue_redraw()

func _init_background_particles() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 20261007
	for index in range(34):
		_background_particles.append({
			"position": Vector2(
				random.randf_range(0.0, 1280.0),
				random.randf_range(360.0, 690.0)
			),
			"speed": random.randf_range(6.0, 18.0),
			"drift": random.randf_range(1.0, 5.0),
			"size": random.randf_range(1.0, 2.8),
			"alpha": random.randf_range(0.16, 0.46),
		})

func _animate_menu_in() -> void:
	title_label.modulate.a = 0.0
	subtitle_label.modulate.a = 0.0
	menu.modulate.a = 0.0
	demo_panel.modulate.a = 0.0
	var tween := create_tween().set_parallel()
	tween.tween_property(title_label, "modulate:a", 1.0, 0.65)
	tween.tween_property(subtitle_label, "modulate:a", 1.0, 0.55).set_delay(0.12)
	tween.tween_property(menu, "modulate:a", 1.0, 0.55).set_delay(0.25)
	tween.tween_property(demo_panel, "modulate:a", 0.82, 0.55).set_delay(0.36)

func _on_new_game_pressed() -> void:
	menu.hide()
	title_label.hide()
	subtitle_label.hide()
	shade.hide()
	demo_panel.hide()
	_day_demo = DAY_DEMO_SCENE.instantiate()
	_day_demo.position = Vector2(58, 48)
	_day_demo.modulate.a = 0.0
	add_child(_day_demo)
	_day_demo.return_to_menu.connect(_return_to_menu)
	_day_demo.setup(game_state)
	var tween := create_tween()
	tween.tween_property(_day_demo, "modulate:a", 1.0, 0.35)

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
	_animate_menu_in()

func _draw() -> void:
	# 临时背景只使用几何图形，正式背景资源稍后替换。
	draw_rect(Rect2(Vector2.ZERO, size), Color("111820"))
	draw_circle(Vector2(size.x * 0.78, size.y * 0.24), 92.0, Color("8d8063"))
	var moon_color := Color("b2a27a")
	moon_color.a = 0.88 + sin(_background_time * 0.8) * 0.06
	draw_circle(Vector2(size.x * 0.78, size.y * 0.24), 78.0, moon_color)
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
	for particle in _background_particles:
		var particle_color := Color("e7b866")
		particle_color.a = float(particle["alpha"]) * (0.75 + sin(_background_time * 2.0 + float(particle["size"])) * 0.25)
		draw_circle(particle["position"], float(particle["size"]), particle_color)
