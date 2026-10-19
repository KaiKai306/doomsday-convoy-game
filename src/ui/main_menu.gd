extends Control

const DAY_SCENE_PATH := "res://scenes/release_game.tscn"
const FINAL_SAVES := preload("res://src/game/save.gd")
const TITLE_IMAGE := preload("res://assets/title/cover_user_20261018.png")
const TITLE_BACKGROUND := Color("#0a101b")
const TITLE_SIZE := Vector2(1280, 720)
const SETTINGS_SCREEN := preload("res://src/ui/settings_screen.gd")
const ARCHIVE_SCREEN_PATH := "res://src/ui/archive_screen.gd"
const ARWES_FRAME := preload("res://src/ui/arwes_frame.gd")
const UI_FEEDBACK := preload("res://src/ui/ui_feedback.gd")
const SCENE_LOADING := preload("res://src/ui/scene_loading.gd")
const MOBILE := preload("res://src/ui/mobile_layout.gd")
const GOLD := Color("#e5ae73")
const MENU_ICONS := [preload("res://assets/title/icon_journey.svg"), preload("res://assets/title/icon_archive.svg"), preload("res://assets/settings/icon_general.svg"), preload("res://assets/title/icon_exit.svg")]
var frame: Control
var menu: Control
var cover_video: VideoStreamPlayer
var cover: TextureRect
var cover_art: TextureRect
var game_state: GameState
var day_demo: Control
var save_system := FINAL_SAVES.new()
var message: Label
var continue_button: Button
var confirmation: Control
var settings: Control
var save_hint: Label
var animated_cover := true
var feedback: ConvoyUIFeedback
var transitioning := false
var menu_loading
var music_director: Node
var menu_music: AudioStreamPlayer:
	get:
		return music_director.active_player if is_instance_valid(music_director) else null
var archive_screen: Control
var developer_session
var developer_previous_mode = Node.PROCESS_MODE_INHERIT
var developer_frame_visible = true
var developer_save_directory = "user://developer_saves"
var startup_ready := false

func _ready() -> void:
	theme = ConvoyTheme.create()
	feedback = UI_FEEDBACK.new()
	add_child(feedback)
	feedback.preferences = func(): return settings.values if is_instance_valid(settings) else {}
	game_state = GameState.new()
	add_child(game_state)
	menu_loading = SCENE_LOADING.new(); menu_loading.name = "MenuLoading"; add_child(menu_loading)
	menu_loading.finished.connect(func(): transitioning = false)
	frame = Control.new()
	frame.size = TITLE_SIZE
	add_child(frame)
	get_viewport().size_changed.connect(_fit)
	_fit()
	cover = TextureRect.new()
	var fill_image := Image.create(1, 1, false, Image.FORMAT_RGB8)
	fill_image.fill(TITLE_BACKGROUND)
	cover.texture = ImageTexture.create_from_image(fill_image)
	cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cover.stretch_mode = TextureRect.STRETCH_SCALE
	cover.size = TITLE_SIZE
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(cover)
	cover_art = TextureRect.new()
	cover_art.name = "UserCoverArt"
	cover_art.texture = TITLE_IMAGE
	cover_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cover_art.stretch_mode = TextureRect.STRETCH_SCALE
	cover_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover.add_child(cover_art)
	cover_video = VideoStreamPlayer.new()
	cover_video.expand = true
	cover_video.size = TITLE_SIZE
	cover_video.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover_video.finished.connect(_play_cover)
	frame.add_child(cover_video)
	_play_cover()
	menu = Control.new()
	menu.size = TITLE_SIZE
	frame.add_child(menu)
	_build_title()
	_title_button("新游戏", "从这里，驶向未知", 277, _start_game_transition, "new_game", 0)
	continue_button = _title_button("存档", "选择、读取与管理旅程", 353, _continue_transition, "continue_game", 1)
	save_hint = continue_button.get_node("Hint")
	_refresh_continue()
	_title_button("设置", "声音 / 画面 / 操作", 429, _open_settings, "settings", 2)
	_title_button("退出游戏", "暂别荒野，旅途未完", 505, _open_exit, "exit", 3)
	message = ConvoyTheme.label("", 16, ConvoyTheme.GOLD)
	message.position = Vector2(68, 590)
	message.size = Vector2(455, 52)
	menu.add_child(message)
	_build_settings()
	_build_exit()
	_build_menu_music()
	_fit()
	feedback.enter(menu)
	startup_ready = true
	if "--developer" in OS.get_cmdline_user_args() and OS.is_debug_build(): call_deferred("_enter_developer_mode")

func is_startup_ready() -> bool:
	return startup_ready

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F8 and OS.is_debug_build():
		if is_instance_valid(developer_session): developer_session.toggle_panel()
		elif not transitioning: _enter_developer_mode()
		get_viewport().set_input_as_handled()

func _enter_developer_mode() -> void:
	if not OS.is_debug_build() or is_instance_valid(developer_session) or transitioning: return
	if is_instance_valid(day_demo) and day_demo.loading_screen.busy: return
	var payload: Dictionary = day_demo.progress_payload() if is_instance_valid(day_demo) else {}
	developer_frame_visible = frame.visible
	if is_instance_valid(day_demo):
		developer_previous_mode = day_demo.process_mode
		day_demo.hide(); day_demo.process_mode = Node.PROCESS_MODE_DISABLED
	frame.hide(); cover_video.stop()
	developer_session = load("res://src/developer/developer_session.gd").new()
	developer_session.save_directory = developer_save_directory
	add_child(developer_session)
	developer_session.exit_requested.connect(_exit_developer_mode)
	developer_session.start(payload)

func _exit_developer_mode() -> void:
	if not is_instance_valid(developer_session): return
	remove_child(developer_session); developer_session.queue_free(); developer_session = null
	frame.visible = developer_frame_visible
	if is_instance_valid(day_demo):
		day_demo.process_mode = developer_previous_mode; day_demo.show()
	if frame.visible: _play_cover(); _play_menu_music()
	elif is_instance_valid(day_demo): day_demo.activate_music()

func _build_menu_music() -> void:
	music_director = get_node("/root/MusicDirector")
	music_director.bind_preferences(settings)
	_play_menu_music()

func _play_menu_music() -> void:
	music_director.activate(self)
	music_director.request(self,"main_menu")

func _build_exit() -> void:
	confirmation = Control.new()
	confirmation.name = "ExitConfirmation"
	confirmation.size = TITLE_SIZE
	menu.add_child(confirmation)
	var shade := ColorRect.new()
	shade.size = TITLE_SIZE
	shade.color = Color(0.005, 0.012, 0.02, 0.78)
	confirmation.add_child(shade)
	var panel := ARWES_FRAME.new()
	panel.shape = ConvoyArwesFrame.Shape.KRANOX
	panel.position = Vector2(405, 241)
	panel.size = Vector2(470, 238)
	panel.fill.a = 0.92
	confirmation.add_child(panel)
	_menu_label(confirmation, "旅途未完", Vector2(443, 269), Vector2(385, 39), 28, GOLD)
	_menu_label(confirmation, "确认离开这段旅途？\n未保存的进度不会自动保留。", Vector2(445, 320), Vector2(385, 60), 16, ConvoyTheme.MUTED)
	var stay := _exit_button("留下", Vector2(441, 405), _close_exit, "exit_cancel", true)
	var leave := _exit_button("离开游戏", Vector2(647, 405), _quit_animated, "exit_confirm", false)
	stay.focus_next = leave.get_path()
	stay.focus_previous = leave.get_path()
	leave.focus_next = stay.get_path()
	leave.focus_previous = stay.get_path()
	confirmation.hide()

func _exit_button(text: String, pos: Vector2, callback: Callable, id: String, primary: bool) -> Button:
	var button := ConvoyTheme.button(text, callback, id)
	button.position = pos
	button.size = Vector2(192, 44)
	button.custom_minimum_size = Vector2(192, 44)
	button.add_theme_font_size_override("font_size", 19)
	for state in ["normal", "disabled", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", GOLD)
	button.add_theme_color_override("font_hover_color", GOLD)
	button.add_theme_color_override("font_focus_color", GOLD)
	var border := ARWES_FRAME.new()
	border.name = "ArwesFrame"
	border.show_behind_parent = true
	border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.add_child(border)
	button.set_meta("primary", primary)
	for event in [button.mouse_entered, button.mouse_exited, button.focus_entered, button.focus_exited, button.button_down, button.button_up]:
		event.connect(func(): _style_menu_button(button))
	confirmation.add_child(button)
	_style_menu_button(button)
	feedback.bind_button(button)
	return button

func _open_exit() -> void:
	if transitioning: return
	confirmation.show()
	feedback.enter(confirmation, Vector2(0, 8))
	for child in confirmation.get_children():
		if child is Button and child.get_meta("action_id", "") == "exit_cancel": child.grab_focus()

func _close_exit() -> void:
	if transitioning: return
	transitioning = true
	await feedback.leave(confirmation)
	confirmation.hide()
	for child in menu.get_children():
		if child is Button and child.get_meta("action_id", "") == "exit": child.grab_focus()
	transitioning = false

func _quit_animated() -> void:
	if transitioning: return
	transitioning = true
	await feedback.leave(menu)
	get_tree().quit()

func _unhandled_key_input(event: InputEvent) -> void:
	if confirmation.visible and event.is_action_pressed("ui_cancel"):
		_close_exit()
		get_viewport().set_input_as_handled()

func _build_title() -> void:
	var plate := ARWES_FRAME.new()
	plate.shape = ConvoyArwesFrame.Shape.KRANOX
	plate.position = Vector2(64, 48)
	plate.size = Vector2(548, 175)
	plate.fill = Color(0.024, 0.045, 0.065, 0.12)
	menu.add_child(plate)
	var title := _menu_label(menu, "末日车队", Vector2(92, 62), Vector2(490, 108), 84, GOLD)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["STZhongsong", "SimSun"])
	title.add_theme_font_override("font", font)
	title.add_theme_color_override("font_shadow_color", Color("#663813"))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 3)
	_menu_label(menu, "CONVOY  /  INTO THE WASTELAND", Vector2(98, 180), Vector2(470, 22), 12, Color("#a88c6b"))
	_menu_label(menu, "把今天熬过去。把明天留给彼此。", Vector2(68, 237), Vector2(490, 26), 14, Color("#a29686"))
	var line := ColorRect.new()
	line.position = Vector2(65, 654)
	line.size = Vector2(547, 1)
	line.color = Color(0.75, 0.58, 0.37, 0.28)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(line)
	_menu_label(menu, "版本 %s" % str(ProjectSettings.get_setting("application/config/version", "0.6.0")), Vector2(67, 668), Vector2(360, 24), 11, Color("#899ba9"))
	_menu_label(menu, "篝火未熄，旅途继续。", Vector2(974, 659), Vector2(250, 26), 13, Color("#a29686"))

func _menu_label(parent: Control, text: String, position_value: Vector2, dimensions: Vector2, font_size: int, color: Color) -> Label:
	var label := ConvoyTheme.label(text, font_size, color)
	label.position = position_value
	label.size = dimensions
	parent.add_child(label)
	return label

func _title_button(description: String, hint: String, y: float, callback: Callable, id: String, index: int) -> Button:
	var button := ConvoyTheme.button("", callback, id)
	button.tooltip_text = description
	button.custom_minimum_size = Vector2(320, 64)
	button.position = Vector2(65, y)
	button.size = Vector2(320, 64)
	for state in ["normal", "disabled", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var border := ARWES_FRAME.new()
	border.name = "ArwesFrame"
	border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.add_child(border)
	var icon := TextureRect.new()
	icon.texture = MENU_ICONS[index]
	icon.position = Vector2(24, 21)
	icon.size = Vector2(24, 24)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)
	_menu_label(button, description, Vector2(73, 5), Vector2(206, 35), 25, GOLD)
	var helper := _menu_label(button, hint, Vector2(75, 41), Vector2(220, 19), 11, Color("#899ba9"))
	helper.name = "Hint"
	_menu_label(button, "%02d" % (index + 1), Vector2(283, 11), Vector2(32, 21), 11, Color("#a88c6b"))
	button.set_meta("primary", index == 0)
	for event in [button.mouse_entered, button.mouse_exited, button.focus_entered, button.focus_exited, button.button_down, button.button_up]:
		event.connect(func(): _style_menu_button(button))
	menu.add_child(button)
	_style_menu_button(button)
	feedback.bind_button(button)
	return button

func _style_menu_button(button: Button) -> void:
	var border: Control = button.get_node("ArwesFrame")
	var highlighted := not button.disabled and (button.is_hovered() or button.has_focus())
	var primary: bool = button.get_meta("primary", false)
	border.fill = Color(0.22, 0.14, 0.07, 0.35 if highlighted else 0.19) if primary or highlighted else Color(0.024, 0.045, 0.065, 0.26)
	if button.is_pressed(): border.fill.a = 0.55
	border.line = GOLD if primary or highlighted else Color("#899ba9")
	button.modulate = Color(0.52, 0.57, 0.62) if button.disabled else Color.WHITE
	border.queue_redraw()

func _refresh_continue() -> void:
	continue_button.disabled = false
	continue_button.tooltip_text = "选择、读取与管理旅程"
	save_hint.text = "六个存档位 · 保存每一段旅程"
	_style_menu_button(continue_button)

func _play_cover() -> void:
	# The user-selected static cover stays visible when motion preferences change.
	# Keep this idle node for existing menu lifecycle and layout callers.
	cover_video.stop()
	cover_video.hide()

func _build_settings() -> void:
	settings = SETTINGS_SCREEN.new()
	settings.feedback = feedback
	# Keep preference values ready without building hidden controls/video at boot.
	settings.animation_changed.connect(func(enabled: bool):
		animated_cover = enabled
		_play_cover()
	)
	settings.closed.connect(func():
		menu.show()
		feedback.enter(menu, Vector2(-14, 0))
		_play_cover()
	)

func _open_settings() -> void:
	if transitioning: return
	transitioning = true
	await feedback.leave(menu)
	cover_video.stop()
	menu.hide()
	if not settings.is_inside_tree(): frame.add_child(settings)
	settings.open_screen()
	transitioning = false

func _exit_tree() -> void:
	if is_instance_valid(settings) and settings.get_parent() == null: settings.free()

func _build_archive() -> void:
	archive_screen = load(ARCHIVE_SCREEN_PATH).new(); archive_screen.feedback = feedback; frame.add_child(archive_screen)
	archive_screen.closed.connect(func(): menu.show(); _refresh_continue(); _play_cover())
	archive_screen.load_requested.connect(_load_archive_game)
	archive_screen.new_game_requested.connect(func(slot: String): _load_archive_game({},slot))

func _load_archive_game(payload: Dictionary, slot: String = "") -> void:
	if transitioning: return
	transitioning = true
	menu.show()
	await _prepare_game(payload)
	if is_instance_valid(day_demo):
		if slot != "" and not day_demo.save_progress(slot):
			day_demo.error_label.text = "新旅程已开始，但手动存档失败。请重新保存。"
	elif frame.visible:
		archive_screen.show(); menu.hide()
	transitioning = false

func _open_archive(intent: String = "load") -> void:
	if transitioning: return
	if not is_instance_valid(archive_screen): _build_archive()
	menu.hide(); cover_video.stop(); archive_screen.open_screen(save_system,null,intent)

func _start_game_transition() -> void:
	_open_archive("new")

func _continue_transition() -> void:
	_open_archive()

func _fit() -> void:
	var viewport_size := get_viewport_rect().size
	frame.scale = Vector2.ONE; frame.position = Vector2.ZERO; frame.size = viewport_size
	if is_instance_valid(cover): cover.size = viewport_size
	if is_instance_valid(cover_art):
		# Fit the entire artwork to display height and anchor it at the right.
		# Wider phones extend the matching dark left edge without cropping heads
		# or boots. Interactive controls keep their independent safe-area layout.
		cover_art.size = Vector2(viewport_size.y * TITLE_SIZE.x / TITLE_SIZE.y, viewport_size.y)
		cover_art.position = Vector2(viewport_size.x - cover_art.size.x, 0)
	if is_instance_valid(cover_video): MOBILE.cover(cover_video,TITLE_SIZE,viewport_size)
	if is_instance_valid(menu): MOBILE.fit(menu,TITLE_SIZE,MOBILE.safe_rect(self),Vector2(0,0.5))

func _start_game(saved: Dictionary = {}) -> void:
	if is_instance_valid(day_demo): return
	var packed := load(DAY_SCENE_PATH) as PackedScene
	if packed == null:
		message.text = "游戏资源未能载入，请更新安装包后重试。"
		return
	day_demo = packed.instantiate()
	add_child(day_demo)
	day_demo.save_system = save_system
	day_demo.auto_save_enabled = bool(settings.values.get("auto_save",true))
	day_demo.activate_music()
	if not day_demo.setup(game_state, saved):
		day_demo.queue_free()
		day_demo = null
		message.text = "存档不兼容或已损坏。可以开始新的旅程。"
		_play_menu_music()
		return
	frame.hide()
	cover_video.stop()
	menu_loading.loaded_location = ""
	day_demo.return_to_menu.connect(_return_to_menu)

func _prepare_game(saved: Dictionary = {}) -> void:
	menu_loading.loaded_location = ""
	menu_loading.request("game_start",func(): _start_game(saved))
	await menu_loading.finished

func _continue() -> void:
	var latest := save_system.latest_slot()
	var saved := save_system.load_from_file(latest) if latest != "" else {}
	if saved.is_empty():
		message.text = "还没有保存过旅途。请先开始新游戏。"
		return
	_start_game(saved)

func _return_to_menu() -> void:
	if transitioning: return
	transitioning = true
	if is_instance_valid(day_demo) and is_instance_valid(day_demo.side_stage) and is_instance_valid(day_demo.side_stage.walk): day_demo.side_stage.walk.lock_movement(true)
	if not menu_loading.request("main_menu",_show_main_menu):
		_show_main_menu(); transitioning = false

func _show_main_menu() -> void:
	if is_instance_valid(day_demo):
		day_demo.queue_free()
		day_demo = null
	frame.show()
	if is_instance_valid(archive_screen): archive_screen.hide()
	settings.hide(); menu.show()
	feedback.enter(menu, Vector2(-14, 0))
	_play_cover()
	_play_menu_music()
	_refresh_continue()
	message.text = ""
