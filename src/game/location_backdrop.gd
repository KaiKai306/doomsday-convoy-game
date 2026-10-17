extends SubViewportContainer
const CATALOG = preload("res://src/game/location_catalog.gd")
var viewport: SubViewport
var art: Node2D
var location_id = ""
var config: Dictionary = {}
var camera_x = 0.0
var vehicle_signature = ""
var vehicle_root: Node2D
var actor_layer: Node2D
var mid: Node2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stretch = true
	viewport = SubViewport.new(); viewport.disable_3d = true
	viewport.size = Vector2i(maxi(1,int(size.x)),maxi(1,int(size.y)))
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.gui_disable_input = true
	add_child(viewport)

func display(id: String, vehicles: Array = []) -> void:
	if location_id != id:
		if is_instance_valid(art):
			viewport.remove_child(art); art.queue_free()
		if is_instance_valid(actor_layer):
			viewport.remove_child(actor_layer); actor_layer.queue_free()
		location_id = id; config = CATALOG.config(id)
		var path = CATALOG.scene_path(id)
		if config.is_empty() or not ResourceLoader.exists(path): return
		art = load(path).instantiate(); viewport.add_child(art)
		art.set_process(false); art.set_process_unhandled_input(false)
		if id != "camp_interior": art.auto_preview = false
		if id == "camp":
			mid = art.planes[1]; art.planes[2].z_index = 20
		else:
			mid = art.get_node("World/Mid"); art.get_node("World/Near").z_index = 20
		vehicle_root = Node2D.new(); vehicle_root.name = "ActualConvoy"; mid.add_child(vehicle_root)
		actor_layer = Node2D.new(); actor_layer.name = "WalkingActors"; actor_layer.z_index = 10; viewport.add_child(actor_layer)
		vehicle_signature = ""; set_camera(0)
	var signature = JSON.stringify(vehicles)
	if signature != vehicle_signature and is_instance_valid(vehicle_root):
		vehicle_signature = signature
		for child in vehicle_root.get_children(): vehicle_root.remove_child(child); child.queue_free()
		# Scene presentation no longer mounts convoy sprites. The vehicle array
		# remains owned by the rules engine, including inventory and durability.

func set_camera(value: float) -> void:
	var limit = float(config.get("camera_limit_source_canvas_pixels",25))
	camera_x = clampf(value,-limit,limit)
	if is_instance_valid(art) and location_id != "camp_interior":
		art.camera_x = camera_x; art._apply_scroll()
	if is_instance_valid(actor_layer): actor_layer.queue_redraw()

func source_to_view(point: Vector2) -> Vector2:
	return mid.get_global_transform()*point if is_instance_valid(mid) else point

func view_to_source(point: Vector2) -> Vector2:
	return mid.get_global_transform().affine_inverse()*point if is_instance_valid(mid) else point
