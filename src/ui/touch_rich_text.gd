extends RichTextLabel
## Read-only prose follows the finger; the native wheel and scrollbar still work.
## Acquire through GUI hit testing so clipped/covered readers cannot steal touches.
const NO_POINTER = -1
var touch_pointer = NO_POINTER
var touch_origin = Vector2.ZERO
var scroll_origin = 0.0
var touch_dragging = false

func _ready() -> void:
	selection_enabled = false
	set_process_input(false)

func _gui_input(event: InputEvent) -> void:
	if not scroll_active or not event is InputEventScreenTouch or not event.pressed or touch_pointer != NO_POINTER: return
	var bar = get_v_scroll_bar()
	if bar.max_value <= bar.page: return
	# Let the native scrollbar handle a touch on its thumb/track.
	if bar.visible and event.position.x >= bar.position.x: return
	touch_pointer = event.index
	touch_origin = event.position
	scroll_origin = bar.value
	touch_dragging = false
	set_process_input(true)
	accept_event()

func _input(event: InputEvent) -> void:
	if touch_pointer == NO_POINTER: return
	if not is_visible_in_tree():
		_release_touch()
		return
	if event is InputEventScreenDrag and event.index == touch_pointer:
		var local = get_global_transform_with_canvas().affine_inverse()*event.position
		var delta = touch_origin.y-local.y
		if absf(delta) >= 6: touch_dragging = true
		if touch_dragging: get_v_scroll_bar().value = scroll_origin+delta
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and event.index == touch_pointer and not event.pressed:
		_release_touch()
		get_viewport().set_input_as_handled()

func _release_touch() -> void:
	touch_pointer = NO_POINTER
	touch_dragging = false
	set_process_input(false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_release_touch()
