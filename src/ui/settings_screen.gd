class_name ConvoySettingsScreen
extends Control

signal closed
signal animation_changed(enabled: bool)
signal audio_changed

const BACKGROUND := preload("res://assets/settings/settings_background.png")
const VIDEO := preload("res://assets/settings/settings_background.ogv")
const KNOB := preload("res://assets/settings/tactical_knob.svg")
const FRAME := preload("res://src/ui/arwes_frame.gd")
const MOBILE := preload("res://src/ui/mobile_layout.gd")
const ICONS := [preload("res://assets/settings/icon_sound.svg"), preload("res://assets/settings/icon_display.svg"), preload("res://assets/settings/icon_controls.svg"), preload("res://assets/settings/icon_general.svg")]
const GOLD := Color("#e5ae73")
const TEXT := Color("#e8e7e2")
const MUTED := Color("#899ba9")
const DEFAULTS := {
	"master": 80, "music": 65, "effects": 85, "ambient": 70, "mute": false,
	"quality": 1, "fps": 1, "brightness": 50, "motion": true, "panel_alpha": 42,
	"button_size": 1, "opacity": 80, "vibration": true, "hand": 1,
	"language": 0, "text_size": 1, "subtitles": true, "auto_save": true,
}
const TAB_NAMES := ["声音", "画面", "操作", "通用"]
const TAB_DESCRIPTIONS := ["调整旅途中的声音层次", "让荒野清晰，也让旅途流畅", "找到适合你的触控方式", "按自己的习惯继续旅程"]

# Selections stay in memory. Audio preferences, background animation and panel
# opacity and automatic saving work at runtime; other controls await integration.
var values: Dictionary = DEFAULTS.duplicate()
var selected_tab := 0
var video: VideoStreamPlayer
var content: Control
var tab_buttons: Array[Button] = []
var section_title: Label
var section_description: Label
var animated := true
var panel_frame: Control
var feedback: ConvoyUIFeedback
var closing := false
var body: Control
var background: TextureRect

func _ready() -> void:
	if feedback == null:
		feedback = ConvoyUIFeedback.new()
		add_child(feedback)
		feedback.preferences = func(): return values
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = ConvoyTheme.create()
	background = TextureRect.new()
	background.texture = BACKGROUND
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	video = VideoStreamPlayer.new()
	video.stream = VIDEO
	video.expand = true
	video.size = size
	video.mouse_filter = Control.MOUSE_FILTER_IGNORE
	video.finished.connect(func():
		if visible and animated: video.play()
	)
	add_child(video)
	body = Control.new(); body.name = "SafeSettingsControls"; body.size = Vector2(1280,720); add_child(body)
	_rect(Vector2.ZERO, Vector2(1280,720), Color(0.01, 0.02, 0.03, 0.08))
	var heading := _label(self, "旅途设置", Vector2(62, 51), Vector2(520, 65), 46, GOLD)
	var title_font := SystemFont.new()
	title_font.font_names = PackedStringArray(["STZhongsong", "SimSun"])
	heading.add_theme_font_override("font", title_font)
	heading.add_theme_color_override("font_shadow_color", Color("#663813"))
	heading.add_theme_constant_override("shadow_offset_x", 1)
	heading.add_theme_constant_override("shadow_offset_y", 2)
	_label(self, "CONVOY  /  FIELD CONTROL", Vector2(66, 116), Vector2(400, 24), 11, Color("#a88c6b"))
	_rect(Vector2(65, 150), Vector2(846, 1), Color(0.75, 0.58, 0.37, 0.32))
	_rect(Vector2(65, 150), Vector2(64, 2), GOLD)
	for i in range(4):
		var tab := _button("  " + TAB_NAMES[i], Vector2(65, 188 + i * 72), Vector2(164, 56), func(): _select_tab(i))
		tab.alignment = HORIZONTAL_ALIGNMENT_LEFT
		tab.icon = ICONS[i]
		tab.add_theme_constant_override("h_separation", 15)
		tab.add_theme_color_override("icon_normal_color", Color.WHITE)
		tab.add_theme_font_size_override("font_size", 21)
		tab.get_node("ArwesFrame").shape = 2
		tab.set_meta("setting_tab", i)
		tab_buttons.append(tab)
	_label(self, "末日车队  /  05", Vector2(67, 517), Vector2(175, 28), 14, GOLD)
	_label(self, "把今天熬过去。\n把明天留给彼此。", Vector2(67, 553), Vector2(190, 60), 13, Color("#a29686"))
	panel_frame = FRAME.new()
	panel_frame.shape = 0
	panel_frame.position = Vector2(262, 174)
	panel_frame.size = Vector2(666, 444)
	panel_frame.fill.a = float(values.panel_alpha) / 100.0
	body.add_child(panel_frame)
	section_title = _label(self, "", Vector2(299, 197), Vector2(420, 32), 24, TEXT)
	section_description = _label(self, "", Vector2(299, 237), Vector2(490, 25), 13, MUTED)
	_rect(Vector2(299, 276), Vector2(596, 1), Color(0.7, 0.55, 0.35, 0.22))
	content = Control.new()
	content.position = Vector2(299, 289)
	content.size = Vector2(604, 305)
	body.add_child(content)
	_rect(Vector2(65, 639), Vector2(846, 1), Color(0.75, 0.58, 0.37, 0.22))
	_button("恢复默认", Vector2(284, 657), Vector2(150, 46), _restore_defaults)
	_button("返回旅途  →", Vector2(738, 653), Vector2(180, 50), _close_animated, true)
	_label(self, "版本 %s" % str(ProjectSettings.get_setting("application/config/version", "0.6.0")), Vector2(67, 668), Vector2(175, 22), 11, MUTED)
	_label(self, "篝火未熄，旅途继续。", Vector2(980, 658), Vector2(235, 25), 13, Color("#c7b299"))
	_select_tab(0)
	resized.connect(_fit); _fit()
	hide()

func _fit() -> void:
	if not is_instance_valid(body): return
	MOBILE.fit(body,Vector2(1280,720),MOBILE.safe_rect(self))
	MOBILE.cover(video,Vector2(1280,720),size)

func open_screen() -> void:
	closing = false
	_fit()
	show()
	feedback.enter(body)
	video.visible = animated
	if animated: video.play()

func close_screen() -> void:
	video.stop()
	hide()
	closed.emit()

func _close_animated() -> void:
	if closing: return
	closing = true
	await feedback.leave(body)
	close_screen()
	closing = false

func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_close_animated()
		get_viewport().set_input_as_handled()

func _style(fill: Color, border: Color, radius: int = 5) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = fill
	result.border_color = border
	result.set_border_width_all(1)
	result.set_corner_radius_all(radius)
	result.content_margin_left = 16
	result.content_margin_right = 16
	return result

func _rect(pos: Vector2, dimensions: Vector2, color: Color) -> void:
	var rect := ColorRect.new()
	rect.position = pos
	rect.size = dimensions
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(rect)

func _label(parent: Node, text: String, pos: Vector2, dimensions: Vector2, font_size: int, color: Color) -> Label:
	if parent == self: parent = body
	var label := ConvoyTheme.label(text, font_size, color)
	label.position = pos
	label.size = dimensions
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	label.add_theme_constant_override("shadow_offset_y", 1)
	parent.add_child(label)
	return label

func _button(text: String, pos: Vector2, dimensions: Vector2, action: Callable, primary := false, parent: Node = self) -> Button:
	if parent == self: parent = body
	var button := Button.new()
	button.text = text
	button.position = pos
	button.size = dimensions
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", GOLD if primary else MUTED)
	button.add_theme_color_override("font_hover_color", Color("#f5d3aa"))
	button.add_theme_color_override("font_focus_color", Color("#f5d3aa"))
	for state in ["normal", "hover", "pressed", "focus"]:
		var empty := StyleBoxEmpty.new()
		empty.content_margin_left = 12
		empty.content_margin_right = 12
		button.add_theme_stylebox_override(state, empty)
	var border := FRAME.new()
	border.name = "ArwesFrame"
	border.size = dimensions
	border.show_behind_parent = true
	border.fill = Color(0.13, 0.1, 0.07, 0.66) if primary else Color(0.03, 0.055, 0.075, 0.3)
	border.line = GOLD if primary else Color("#637079")
	button.add_child(border)
	button.set_meta("accent", primary)
	button.mouse_entered.connect(func(): _refresh_button(button, true))
	button.mouse_exited.connect(func(): _refresh_button(button, false))
	button.focus_entered.connect(func(): _refresh_button(button, true))
	button.focus_exited.connect(func(): _refresh_button(button, false))
	button.pressed.connect(action)
	parent.add_child(button)
	feedback.bind_button(button)
	return button

func _refresh_button(button: Button, hover: bool = false) -> void:
	var frame := button.get_node("ArwesFrame")
	var accent := bool(button.get_meta("accent", false))
	frame.active = accent or hover
	frame.line = GOLD if accent or hover else Color("#61717a")
	frame.fill = Color(0.22, 0.14, 0.075, 0.5 if hover else 0.35) if accent else Color(0.03, 0.055, 0.075, 0.35 if hover else 0.2)
	frame.queue_redraw()

func _select_tab(index: int) -> void:
	selected_tab = index
	for i in range(tab_buttons.size()):
		var active := i == index
		tab_buttons[i].set_meta("accent", active)
		_refresh_button(tab_buttons[i])
		tab_buttons[i].add_theme_color_override("font_color", GOLD if active else MUTED)
	section_title.text = TAB_NAMES[index] + "设置"
	section_description.text = TAB_DESCRIPTIONS[index]
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	match index:
		0:
			_slider("master", "总音量", "控制游戏的整体音量", 0)
			_slider("music", "背景音乐", "陪伴旅途的旋律", 66)
			_slider("effects", "音效", "引擎、脚步与界面反馈", 132)
			_slider("ambient", "环境声音", "风声、荒野与营地篝火", 198)
			_toggle("mute", "全部静音", "保留画面，暂时安静", 264)
		1:
			_segments("quality", "画面品质", "兼顾细节与设备性能", ["流畅", "均衡", "精致"], 0)
			_segments("fps", "帧率", "更流畅的画面会增加耗电", ["30 帧", "60 帧"], 62)
			_slider("brightness", "画面亮度", "让暗处的细节更容易辨认", 124)
			_slider("panel_alpha", "面板不透明度", "只调节底板，文字与边框保持清晰", 186)
			_toggle("motion", "动态背景", "关闭后显示静态封面，更省电", 248)
		2:
			_segments("button_size", "触控按钮大小", "选择舒适的点按范围", ["标准", "较大", "最大"], 0)
			_slider("opacity", "按钮不透明度", "兼顾场景视野与按钮辨识", 78)
			_toggle("vibration", "振动反馈", "重要操作时给予轻微反馈", 156)
			_segments("hand", "惯用手", "调整常用操作区域的位置", ["左手", "右手"], 234)
		3:
			_segments("language", "语言", "界面与剧情文字", ["简体中文"], 0)
			_segments("text_size", "文字大小", "调整剧情与对话的阅读字号", ["标准", "较大", "最大"], 78)
			_toggle("subtitles", "剧情字幕", "显示对话与重要声音提示", 156)
			_toggle("auto_save", "自动存档", "行动后自动记录最近的旅途", 234)
	if visible: feedback.enter(content, Vector2(0, 7))

func _row_labels(title: String, detail: String, y: float) -> void:
	_label(content, title, Vector2(0, y), Vector2(230, 28), 19, TEXT)
	_label(content, detail, Vector2(0, y + 31), Vector2(260, 23), 12, MUTED)

func _slider(key: String, title: String, detail: String, y: float) -> void:
	_row_labels(title, detail, y)
	var number := _label(content, "%d%%" % values[key], Vector2(547, y + 6), Vector2(57, 28), 18, GOLD)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var slider := HSlider.new()
	slider.position = Vector2(282, y - 3)
	slider.size = Vector2(246, 48)
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.value = values[key]
	slider.set_meta("setting_key", key)
	var track := _style(Color(0.08, 0.12, 0.15, 0.85), Color("#687174"), 0)
	track.content_margin_left = 0
	track.content_margin_right = 0
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	slider.add_theme_stylebox_override("slider", track)
	var fill := track.duplicate()
	fill.bg_color = GOLD
	fill.border_color = GOLD
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	slider.add_theme_icon_override("grabber", KNOB)
	slider.add_theme_icon_override("grabber_highlight", KNOB)
	for i in range(13):
		var tick := ColorRect.new()
		tick.position = Vector2(282 + i * 20.5, y + 37)
		tick.size = Vector2(1, 4 if i % 3 else 7)
		tick.color = Color(0.7, 0.57, 0.41, 0.35)
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(tick)
	slider.value_changed.connect(func(value: float):
		values[key] = int(value)
		number.text = "%d%%" % int(value)
		if key in ["master", "music"]: audio_changed.emit()
		if key == "panel_alpha":
			panel_frame.fill.a = value / 100.0
			panel_frame.queue_redraw()
	)
	content.add_child(slider)
	slider.drag_ended.connect(func(changed: bool):
		if changed: feedback.play_click()
	)

func _toggle(key: String, title: String, detail: String, y: float) -> void:
	_row_labels(title, detail, y)
	var toggle := _button("", Vector2(491, y + 3), Vector2(113, 46), func(): pass, false, content)
	toggle.set_meta("setting_key", key)
	_refresh_toggle(toggle, values[key])
	toggle.pressed.connect(func():
		values[key] = not values[key]
		_refresh_toggle(toggle, values[key])
		if key == "mute": audio_changed.emit()
		if key == "motion":
			animated = values[key]
			video.stop()
			video.visible = animated
			if animated and visible: video.play()
			animation_changed.emit(animated)
	)

func _refresh_toggle(button: Button, enabled: bool) -> void:
	button.text = "开启  ▪" if enabled else "关闭  −"
	button.add_theme_color_override("font_color", GOLD if enabled else MUTED)
	button.set_meta("accent", enabled)
	_refresh_button(button)

func _segments(key: String, title: String, detail: String, choices: Array, y: float) -> void:
	_row_labels(title, detail, y)
	var buttons: Array[Button] = []
	var width := (322.0 - (choices.size() - 1) * 7) / choices.size()
	for i in range(choices.size()):
		var button := _button(choices[i], Vector2(282 + i * (width + 7), y + 3), Vector2(width, 46), func(): pass, false, content)
		button.set_meta("setting_key", key)
		button.set_meta("setting_choice", i)
		buttons.append(button)
		button.pressed.connect(func():
			values[key] = i
			_update_segments(buttons, i)
		)
	_update_segments(buttons, values[key])

func _update_segments(buttons: Array[Button], index: int) -> void:
	for i in range(buttons.size()):
		buttons[i].add_theme_color_override("font_color", GOLD if i == index else MUTED)
		buttons[i].set_meta("accent", i == index)
		_refresh_button(buttons[i])

func _restore_defaults() -> void:
	values = DEFAULTS.duplicate()
	panel_frame.fill.a = float(values.panel_alpha) / 100.0
	panel_frame.queue_redraw()
	animated = values.motion
	video.visible = animated
	if visible and animated: video.play()
	animation_changed.emit(animated)
	_select_tab(selected_tab)
	audio_changed.emit()
