extends CanvasLayer
## Shared presentation boundary: draw the cover before loading/assembling a
## location, then reveal only after its first rendered frame is ready.
signal started
signal finished
const BACKGROUND = preload("res://assets/settings/settings_background.png")
const BLUR = preload("res://src/ui/scene_loading.gdshader")
const CATALOG = preload("res://src/game/location_catalog.gd")
const MOBILE = preload("res://src/ui/mobile_layout.gd")
var busy = false
var applying = false
var loaded_location = ""
var target_location = ""
var progress = 0.0
var screen: Control
var title: Label
var track: ColorRect
var fill: ColorRect
var status: Label
var queued: Dictionary = {}
var held_resources: Array[Resource] = []

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	screen = Control.new(); screen.name = "SceneLoadingScreen"
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_STOP; add_child(screen)
	var background = TextureRect.new(); background.texture = BACKGROUND
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var blur = ShaderMaterial.new(); blur.shader = BLUR; background.material = blur; screen.add_child(background)
	title = ConvoyTheme.label("末日车队",84,Color("eee8dd")); title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font = SystemFont.new(); font.font_names = PackedStringArray(["STZhongsong","SimSun"]); title.add_theme_font_override("font",font)
	title.add_theme_color_override("font_shadow_color",Color(0.015,0.025,0.04,0.8)); title.add_theme_constant_override("shadow_offset_y",3); screen.add_child(title)
	track = ColorRect.new(); track.color = Color(0.8,0.84,0.88,0.22); track.mouse_filter = Control.MOUSE_FILTER_IGNORE; screen.add_child(track)
	fill = ColorRect.new(); fill.color = Color("d9dee2"); fill.mouse_filter = Control.MOUSE_FILTER_IGNORE; track.add_child(fill)
	status = ConvoyTheme.label("正在加载…",13,Color("a3a9af")); status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; status.mouse_filter = Control.MOUSE_FILTER_IGNORE; screen.add_child(status)
	get_viewport().size_changed.connect(_fit); _fit(); screen.hide()

func _fit() -> void:
	var area = MOBILE.safe_rect(screen); var dimensions = area.size
	var factor = minf(dimensions.x/1280.0,dimensions.y/720.0)
	title.position = area.position+Vector2(dimensions.x*0.05,dimensions.y*0.09); title.size = Vector2(600,120)*factor
	title.add_theme_font_size_override("font_size",maxi(20,int(84*factor)))
	track.size = Vector2(360*factor,maxf(2,2*factor)); track.position = area.position+Vector2((dimensions.x-track.size.x)*0.5,dimensions.y*0.90)
	status.position = track.position+Vector2(-40*factor,10*factor); status.size = Vector2(track.size.x+80*factor,24*factor)
	status.add_theme_font_size_override("font_size",maxi(10,int(13*factor)))
	set_progress(progress)

func set_progress(value: float) -> void:
	progress = clampf(value,0,1)
	fill.size = Vector2(track.size.x*progress,track.size.y)

func request(location: String, render: Callable, additional: String = "") -> bool:
	if applying: return false
	if busy:
		queued = {"location":location,"render":render,"additional":additional}
		return true
	if location == loaded_location: return false
	busy = true; target_location = location; set_progress(0.02); screen.modulate.a = 1; screen.show()
	status.text = "正在加载…"
	var focused = get_viewport().gui_get_focus_owner()
	if focused: focused.release_focus()
	started.emit()
	_load.call_deferred(location,render,additional)
	return true

func _resources_for(location: String) -> Array[String]:
	var paths: Array[String] = []
	var scene = CATALOG.scene_path(location)
	if ResourceLoader.exists(scene): paths.append(scene)
	var manifest_path = "res://assets/locations/atlas_widescreen_20261016/manifest.json"
	if FileAccess.file_exists(manifest_path):
		var manifest = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
		var config: Dictionary = manifest.get("locations",{}).get(location,{})
		for plane in ["far.png","mid.png","near.png"]:
			var path = str(config.get("art_root",""))+plane
			if ResourceLoader.exists(path): paths.append(path)
	return paths

func _draw_frame() -> void:
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func _load(location: String, render: Callable, additional: String) -> void:
	# At least one opaque cover frame precedes any synchronous scene assembly.
	await _draw_frame()
	var began = Time.get_ticks_msec()
	var paths = _resources_for(location)
	if additional != "" and additional != location:
		for path in _resources_for(additional):
			if not paths.has(path): paths.append(path)
	var requested: Array[String] = []
	var scenes: Array[String] = []
	for path in paths:
		if path.get_extension() in ["tscn", "scn", "gd"]:
			scenes.append(path)
		elif ResourceLoader.load_threaded_request(path) == OK:
			requested.append(path)
	var remaining = requested.duplicate()
	held_resources.clear()
	while not remaining.is_empty():
		var total = float(requested.size()-remaining.size())
		for path in remaining.duplicate():
			var amount: Array = []
			var state = ResourceLoader.load_threaded_get_status(path,amount)
			if state == ResourceLoader.THREAD_LOAD_LOADED:
				held_resources.append(ResourceLoader.load_threaded_get(path)); remaining.erase(path); total += 1
			elif state in [ResourceLoader.THREAD_LOAD_FAILED,ResourceLoader.THREAD_LOAD_INVALID_RESOURCE]:
				remaining.erase(path); total += 1
			elif not amount.is_empty(): total += float(amount[0])
		set_progress(maxf(progress,0.05+0.77*total/maxi(1,requested.size())))
		await get_tree().process_frame
	# Keep script initialization on the main thread. Textures are already warm,
	# and the opaque cover is visible before scene parsing/assembly begins.
	for index in scenes.size():
		set_progress(0.82 + 0.03 * index / maxi(1,scenes.size()))
		status.text = "正在准备场景…"
		await _draw_frame()
		var resource = load(scenes[index])
		if resource != null: held_resources.append(resource)
	set_progress(0.86); status.text = "正在进入场景…"
	await _draw_frame()
	applying = true
	if render.is_valid(): render.call()
	applying = false; loaded_location = location
	# Include newly created subviewports and GPU uploads before revealing them.
	await _draw_frame(); await _draw_frame()
	set_progress(1.0); status.text = "加载完成"
	await _draw_frame()
	# Cached door transitions stay short, but the cover remains readable.
	var remaining_time = 0.40-float(Time.get_ticks_msec()-began)/1000.0
	if remaining_time > 0: await get_tree().create_timer(remaining_time).timeout
	var fade = create_tween(); fade.tween_property(screen,"modulate:a",0.0,0.16); await fade.finished
	held_resources.clear(); screen.hide(); busy = false
	finished.emit()
	if not queued.is_empty():
		var next = queued; queued = {}
		if not request(next.location,next.render,next.additional) and next.render.is_valid(): next.render.call()

func _input(_event: InputEvent) -> void:
	if busy: get_viewport().set_input_as_handled()
