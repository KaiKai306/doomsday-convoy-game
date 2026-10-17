extends Control

const DAY_SCENE := preload("res://scenes/release_game.tscn")
const FINAL_SAVES := preload("res://src/game/save.gd")
const TITLE_IMAGE := preload("res://assets/settings/settings_background.png")
const TITLE_VIDEO := preload("res://assets/settings/settings_background.ogv")
const TITLE_MUSIC := preload("res://assets/audio/music_mainmenu_loop.ogg")
const TITLE_SIZE := Vector2(1280, 720)
const SETTINGS_SCREEN := preload("res://src/ui/settings_screen.gd")
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
var menu_music: AudioStreamPlayer
var music_fade: Tween
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
	cover.texture = TITLE_IMAGE
	cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	cover.size = TITLE_SIZE
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(cover)
	cover_video = VideoStreamPlayer.new()
	cover_video.stream = TITLE_VIDEO
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
	continue_button = _title_button("存档", "继续上次保存的旅程", 353, _continue_transition, "continue_game", 1)
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

func is_startup_ready() -> bool:
	return startup_ready

func _build_menu_music() -> void:
	menu_music = AudioStreamPlayer.new()
	menu_music.name = "MainMenuMusic"
	menu_music.stream = TITLE_MUSIC.duplicate()
	menu_music.stream.loop = true
	menu_music.volume_linear = 0.0
	add_child(menu_music)
	settings.audio_changed.connect(_apply_music_preferences)
	_play_menu_music()

func _menu_music_gain() -> float:
	if settings.values.get("mute", false): return 0.0
	return float(settings.values.master) * float(settings.values.music) / 10000.0

func _fade_menu_music(gain: float, seconds: float) -> Tween:
	if music_fade: music_fade.kill()
	music_fade = create_tween()
	music_fade.tween_property(menu_music, "volume_linear", gain, seconds)
	return music_fade

func _play_menu_music() -> void:
	if not menu_music.playing:
		menu_music.volume_linear = 0.0
		menu_music.play()
	_fade_menu_music(_menu_music_gain(), 0.5)

func _stop_menu_music() -> void:
	if menu_music.playing:
		_fade_menu_music(0.0, 0.2).tween_callback(menu_music.stop)

func _apply_music_preferences() -> void:
	if menu_music.playing and frame.visible:
		_fade_menu_music(_menu_music_gain(), 0.12)

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
	_menu_label(menu, "二十日框架测试版  /  0.6", Vector2(67, 668), Vector2(360, 24), 11, Color("#899ba9"))
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
	continue_button.disabled = save_system.load_from_file().is_empty()
	continue_button.tooltip_text = "暂无存档，请先开始新游戏" if continue_button.disabled else "继续上次保存的旅程"
	save_hint.text = "暂无存档 · 开始一段新旅程" if continue_button.disabled else "继续上次保存的旅程"
	_style_menu_button(continue_button)

func _play_cover() -> void:
	if animated_cover and frame.visible:
		cover_video.show()
		cover_video.play()

func _build_settings() -> void:
	settings = SETTINGS_SCREEN.new()
	settings.feedback = feedback
	frame.add_child(settings)
	settings.animation_changed.connect(func(enabled: bool):
		animated_cover = enabled
		cover_video.visible = enabled
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
	settings.open_screen()
	transitioning = false

func _start_game_transition() -> void:
	if transitioning: return
	transitioning = true
	await feedback.leave(menu)
	_start_game()
	if is_instance_valid(day_demo): feedback.enter(day_demo, Vector2.ZERO)
	transitioning = false
	if frame.visible: feedback.enter(menu)

func _continue_transition() -> void:
	if transitioning: return
	transitioning = true
	await feedback.leave(menu)
	_continue()
	if is_instance_valid(day_demo): feedback.enter(day_demo, Vector2.ZERO)
	transitioning = false
	if frame.visible: feedback.enter(menu)

func _fit() -> void:
	var viewport_size := get_viewport_rect().size
	frame.scale = Vector2.ONE; frame.position = Vector2.ZERO; frame.size = viewport_size
	if is_instance_valid(cover): cover.size = viewport_size
	if is_instance_valid(cover_video): MOBILE.cover(cover_video,TITLE_SIZE,viewport_size)
	if is_instance_valid(menu): MOBILE.fit(menu,TITLE_SIZE,MOBILE.safe_rect(self),Vector2(0,0.5))

func _start_game(saved: Dictionary = {}) -> void:
	if is_instance_valid(day_demo): return
	day_demo = DAY_SCENE.instantiate()
	add_child(day_demo)
	day_demo.save_system = save_system
	if not day_demo.setup(game_state, saved):
		day_demo.queue_free()
		day_demo = null
		message.text = "存档不兼容或已损坏。可以开始新的旅程。"
		return
	frame.hide()
	cover_video.stop()
	_stop_menu_music()
	menu_loading.loaded_location = ""
	day_demo.return_to_menu.connect(_return_to_menu)

func _continue() -> void:
	var saved := save_system.load_from_file()
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
	feedback.enter(menu, Vector2(-14, 0))
	_play_cover()
	_play_menu_music()
	_refresh_continue()
	message.text = ""
