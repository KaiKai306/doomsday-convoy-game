extends Node2D
## Shared renderer for outdoor three-plane art scenes.
## World coordinates are source-image pixels; gameplay can use the Mid plane.

@export var canvas_size := Vector2(2688, 1152)
@export var camera_limit := 25.0
@export var auto_preview := true
@export var protect_top := false
@export var cover_viewport := false
@export var parking_area := Rect2()
@export var additional_parking_areas: Array[Rect2] = []
var camera_x := 0.0
var elapsed := 0.0
var show_parking := false
@onready var world: Node2D = $World
@onready var planes: Array[Parallax2D] = [$World/Far, $World/Mid, $World/Near]
@onready var parking_overlay := Node2D.new()

func _ready() -> void:
	parking_overlay.name = "ParkingOverlay"
	parking_overlay.z_index = 10
	add_child(parking_overlay)
	parking_overlay.draw.connect(_draw_parking)
	get_viewport().size_changed.connect(_layout)
	_layout()

func _layout() -> void:
	var viewport := get_viewport_rect().size
	var factor := minf(viewport.x / canvas_size.x, viewport.y / canvas_size.y) * 1.045
	if cover_viewport: factor = maxf(viewport.x / canvas_size.x, viewport.y / canvas_size.y) * 1.045
	world.scale = Vector2.ONE * factor
	world.position = (viewport - canvas_size * factor) * 0.5
	if protect_top:
		world.position.y = maxf(0.0, world.position.y)
	_apply_scroll()

func _apply_scroll() -> void:
	for plane in planes:
		plane.scroll_offset = Vector2(-camera_x * plane.scroll_scale.x, 0)
	parking_overlay.queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	var direction := Input.get_axis("move_left", "move_right")
	if direction != 0:
		auto_preview = false
		camera_x = clampf(camera_x + direction * delta * 35, -camera_limit, camera_limit)
	elif auto_preview:
		camera_x = sin(elapsed * 0.45) * camera_limit
	_apply_scroll()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		auto_preview = false
		camera_x = clampf(camera_x - event.relative.x / world.scale.x * 0.12, -camera_limit, camera_limit)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			auto_preview = not auto_preview
		if event.keycode == KEY_V:
			show_parking = not show_parking
			parking_overlay.queue_redraw()

func _draw_parking() -> void:
	if not show_parking or parking_area.size == Vector2.ZERO or not is_instance_valid(world):
		return
	var origin := world.position + Vector2(-camera_x * 0.5, 0) * world.scale
	var areas: Array[Rect2] = [parking_area]
	areas.append_array(additional_parking_areas)
	for area in areas:
		var rect := Rect2(origin + area.position * world.scale, area.size * world.scale)
		parking_overlay.draw_rect(rect, Color(0.3, 0.75, 0.95, 0.08))
		parking_overlay.draw_rect(rect, Color(0.3, 0.75, 0.95, 0.85), false, 2.0)

## Mount a 2D vehicle scene at the parking anchor, with its origin at the wheel baseline.
func mount_vehicle(vehicle: Node2D, anchor_name: String = "VehicleMount") -> void:
	var anchor := get_node_or_null("World/Mid/" + anchor_name)
	if anchor != null:
		anchor.add_child(vehicle)
		vehicle.position = Vector2.ZERO
