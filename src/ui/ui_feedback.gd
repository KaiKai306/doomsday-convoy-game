class_name ConvoyUIFeedback
extends Node

const CLICK := preload("res://assets/audio/ui_tactical_click.wav")
var preferences: Callable
var voices: Array[AudioStreamPlayer] = []
var next_voice := 0

func _ready() -> void:
	for i in range(4):
		var voice := AudioStreamPlayer.new()
		voice.stream = CLICK
		add_child(voice)
		voices.append(voice)

func play_click() -> void:
	var values: Dictionary = preferences.call() if preferences.is_valid() else {}
	if values.get("mute", false): return
	var gain := float(values.get("master", 80)) * float(values.get("effects", 85)) / 10000.0
	if gain <= 0.0: return
	var voice := voices[next_voice]
	next_voice = (next_voice + 1) % voices.size()
	voice.volume_db = linear_to_db(gain) - 7.0
	voice.play()

func bind_button(button: Button) -> void:
	button.pivot_offset = button.size * 0.5
	button.resized.connect(func(): button.pivot_offset = button.size * 0.5)
	button.button_down.connect(func():
		if button.disabled: return
		play_click()
		_scale_button(button, Vector2.ONE * 0.97, 0.055)
		var border := button.get_node_or_null("ArwesFrame")
		if border:
			var old_flash: Tween = button.get_meta("flash_tween") if button.has_meta("flash_tween") else null
			if old_flash: old_flash.kill()
			border.modulate = Color(1.6, 1.35, 1.1)
			var flash := button.create_tween()
			button.set_meta("flash_tween", flash)
			flash.tween_property(border, "modulate", Color.WHITE, 0.22)
	)
	button.button_up.connect(func():
		var bounce := _scale_button(button, Vector2.ONE * 1.012, 0.09)
		bounce.tween_property(button, "scale", Vector2.ONE, 0.09).set_trans(Tween.TRANS_SINE)
	)
	button.mouse_exited.connect(func():
		if not button.is_pressed(): _scale_button(button, Vector2.ONE, 0.1)
	)

func _scale_button(button: Button, target: Vector2, duration: float) -> Tween:
	var previous: Tween = button.get_meta("press_tween") if button.has_meta("press_tween") else null
	if previous: previous.kill()
	var tween := button.create_tween()
	button.set_meta("press_tween", tween)
	tween.tween_property(button, "scale", target, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	return tween

func enter(control: Control, offset := Vector2(14, 0)) -> void:
	var previous: Tween = control.get_meta("page_tween") if control.has_meta("page_tween") else null
	if previous: previous.kill()
	var target: Vector2 = control.get_meta("page_origin", control.position)
	control.set_meta("page_origin", target)
	control.position = target + offset
	control.modulate.a = 0.0
	var tween := control.create_tween().set_parallel(true)
	control.set_meta("page_tween", tween)
	tween.tween_property(control, "position", target, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "modulate:a", 1.0, 0.2)

func leave(control: Control) -> void:
	var previous: Tween = control.get_meta("page_tween") if control.has_meta("page_tween") else null
	if previous: previous.kill()
	var tween := control.create_tween()
	control.set_meta("page_tween", tween)
	tween.tween_interval(0.065)
	tween.tween_property(control, "modulate:a", 0.0, 0.14).set_trans(Tween.TRANS_SINE)
	await tween.finished
