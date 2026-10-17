extends Node2D

const ART := "res://assets/camp/parallax_three/"
const CANVAS := Vector2(2688, 1152)
var planes: Array[Parallax2D] = []
var camera_x := 0.0
var auto_preview := true
var elapsed := 0.0

func _ready() -> void:
	var files := ["01_far_sky_mountains.png", "02_mid_camp.png", "03_near_ground.png"]
	var speeds := [0.12, 0.5, 1.0]
	for i in range(3):
		var plane := Parallax2D.new()
		plane.name = ["FarSkyMountains", "MidCamp", "NearGround"][i]
		plane.scroll_scale = Vector2(speeds[i], 0)
		plane.ignore_camera_scroll = true
		plane.follow_viewport = false
		add_child(plane)
		var sprite := Sprite2D.new()
		sprite.texture = load(ART + files[i])
		sprite.centered = false
		plane.add_child(sprite)
		planes.append(plane)
	get_viewport().size_changed.connect(_layout)
	_layout()

func _layout() -> void:
	var viewport := get_viewport_rect().size
	var factor := minf(viewport.x / CANVAS.x, viewport.y / CANVAS.y) * 1.045
	for plane in planes:
		plane.scale = Vector2.ONE * factor
		plane.position = (viewport - CANVAS * factor) * 0.5
	_apply_scroll()

func _apply_scroll() -> void:
	for plane in planes:
		plane.scroll_offset = Vector2(-camera_x * plane.scroll_scale.x, 0)

func _process(delta: float) -> void:
	elapsed += delta
	var direction := Input.get_axis("move_left", "move_right")
	if direction != 0:
		auto_preview = false
		camera_x = clampf(camera_x + direction * delta * 35, -25, 25)
	elif auto_preview:
		camera_x = sin(elapsed * 0.45) * 25
	_apply_scroll()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		auto_preview = false
		camera_x = clampf(camera_x - event.relative.x * 0.12, -25, 25)
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		auto_preview = not auto_preview
