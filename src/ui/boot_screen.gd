extends CanvasLayer
## Keep the first screen independent of the menu's resource dependency graph.
signal progress_changed(value: float)
signal startup_finished(menu: Node)
signal startup_failed(message: String)

@export var menu_scene_path := "res://scenes/main.tscn"
@export var startup_log_path := "user://startup.log"
var progress := 0.0
var busy := false
var failed := false
var screen: Control
var panel: Control
var title: Label
var status: Label
var percentage: Label
var bar: ProgressBar
var retry: Button
var started_at := 0

func _ready() -> void:
	layer = 200
	process_mode = Node.PROCESS_MODE_ALWAYS
	screen = Control.new()
	screen.name = "StartupLoadingScreen"
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(screen)
	var background := ColorRect.new()
	background.color = Color("101923")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(background)
	panel = Control.new()
	screen.add_child(panel)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Noto Sans CJK SC", "Noto Sans SC", "Microsoft YaHei", "sans-serif"])
	var theme := Theme.new()
	theme.default_font = font
	screen.theme = theme
	title = _label("末日车队", 68, Color("e5ae73"))
	title.position = Vector2(0, 0)
	title.size = Vector2(800, 110)
	status = _label("正在准备…", 24, Color("d3dbe1"))
	status.position = Vector2(0, 150)
	status.size = Vector2(800, 50)
	bar = ProgressBar.new()
	bar.position = Vector2(140, 220)
	bar.size = Vector2(520, 12)
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var track := StyleBoxFlat.new()
	track.bg_color = Color("293746")
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("e5ae73")
	bar.add_theme_stylebox_override("background", track)
	bar.add_theme_stylebox_override("fill", fill)
	panel.add_child(bar)
	percentage = _label("0%", 22, Color("9baab8"))
	percentage.position = Vector2(0, 250)
	percentage.size = Vector2(800, 40)
	retry = Button.new()
	retry.text = "重新尝试"
	retry.position = Vector2(290, 310)
	retry.size = Vector2(220, 64)
	retry.add_theme_font_size_override("font_size", 25)
	retry.pressed.connect(_begin)
	panel.add_child(retry)
	get_viewport().size_changed.connect(_fit)
	_fit()
	_begin.call_deferred()

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	return label

func _fit() -> void:
	var dimensions := get_viewport().get_visible_rect().size
	var factor := maxf(0.1, minf(dimensions.x / 1100.0, dimensions.y / 650.0))
	panel.size = Vector2(800, 380)
	panel.scale = Vector2.ONE * factor
	panel.position = (dimensions - panel.size * factor) * 0.5

func _begin() -> void:
	if busy: return
	failed = false
	retry.hide()
	screen.modulate.a = 1.0
	_set_progress(0.0)
	status.text = "正在准备…"
	_trace("BOOT_START " + str(ProjectSettings.get_setting("application/config/version", "")))
	# Submit an opaque frame before requesting any game resources.
	await _draw_frame()
	if not ResourceLoader.exists(menu_scene_path):
		_fail("Main menu resource is missing: " + menu_scene_path)
		return
	var error := ResourceLoader.load_threaded_request(menu_scene_path, "PackedScene")
	if error != OK:
		_fail("Menu load request failed: " + str(error))
		return
	started_at = Time.get_ticks_msec()
	busy = true
	status.text = "正在加载游戏资源…"

func _process(_delta: float) -> void:
	if not busy: return
	var amount: Array = []
	var state := ResourceLoader.load_threaded_get_status(menu_scene_path, amount)
	if state == ResourceLoader.THREAD_LOAD_LOADED:
		busy = false
		_open_menu.call_deferred()
	elif state in [ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE]:
		_fail("Main menu resource failed to load")
	elif not amount.is_empty():
		_set_progress(maxf(progress, float(amount[0]) * 0.85))
	if busy and Time.get_ticks_msec() - started_at > 15000:
		status.text = "首次加载可能稍久，请稍候…"

func _open_menu() -> void:
	_set_progress(0.85)
	status.text = "正在准备主菜单…"
	await _draw_frame()
	var packed := ResourceLoader.load_threaded_get(menu_scene_path) as PackedScene
	if packed == null:
		_fail("Main menu is not a valid PackedScene")
		return
	var menu := packed.instantiate()
	if menu == null or not menu.has_method("is_startup_ready"):
		if menu != null: menu.free()
		_fail("Main menu script did not initialize")
		return
	get_tree().root.add_child(menu)
	if not menu.is_startup_ready():
		menu.queue_free()
		_fail("Main menu initialization did not complete")
		return
	_set_progress(0.95)
	await _draw_frame()
	_set_progress(1.0)
	status.text = "加载完成"
	await _draw_frame()
	get_tree().current_scene = menu
	var fade := create_tween()
	fade.tween_property(screen, "modulate:a", 0.0, 0.15)
	await fade.finished
	_trace("BOOT_MENU_READY")
	startup_finished.emit(menu)
	queue_free()

func _set_progress(value: float) -> void:
	progress = clampf(value, 0.0, 1.0)
	bar.value = progress * 100.0
	percentage.text = "%d%%" % roundi(progress * 100.0)
	progress_changed.emit(progress)

func _fail(detail: String) -> void:
	busy = false
	failed = true
	status.text = "游戏资源未能载入，请重试或更新安装包。"
	percentage.text = "加载未完成"
	retry.show()
	_trace("BOOT_FAILED " + detail)
	startup_failed.emit(detail)

func _trace(message: String) -> void:
	print(message)
	var file := FileAccess.open(startup_log_path, FileAccess.READ_WRITE if FileAccess.file_exists(startup_log_path) else FileAccess.WRITE)
	if file != null:
		if file.get_length() > 65536:
			file.close()
			file = FileAccess.open(startup_log_path, FileAccess.WRITE)
		if file != null:
			file.seek_end()
			file.store_line(message)

func _draw_frame() -> void:
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw

func _input(_event: InputEvent) -> void:
	if not failed: get_viewport().set_input_as_handled()
