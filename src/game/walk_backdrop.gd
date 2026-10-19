extends SubViewportContainer
## Separate side-view stages keep action-panel art and rules-location resolution intact.
const CATALOG = preload("res://src/game/location_catalog.gd")
const ASSET_ROOT = "res://assets/locations/side_walk_20261016/"
const SOURCE_SIZE = Vector2(2048,1152)
var viewport: SubViewport
var actor_layer: Node2D
var vehicle_root: Node2D
var mid: Node2D
var planes: Array[Node2D] = []
var config: Dictionary = {}
var location_id = ""
var camera_x = 0.0
var existing_scene: Node2D
var full_map = false
var canvas_size = Vector2(1280,720)
var source_size = SOURCE_SIZE
var padding = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE; stretch = true
	viewport = SubViewport.new(); viewport.disable_3d = true; viewport.size = Vector2i(canvas_size)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS; viewport.gui_disable_input = true
	add_child(viewport)

func display(id: String, _vehicles: Array = []) -> void:
	if location_id == id: return
	for child in viewport.get_children():
		viewport.remove_child(child); child.queue_free()
	planes.clear(); existing_scene = null; mid = null
	source_size = SOURCE_SIZE
	location_id = id
	config = {"title":CATALOG.config(id).get("title",id),"walk_path":[[155,806],[1893,806]],"spawn_x":610,"npc_x":[350,1010,1350,1690],"camera_limit_source_canvas_pixels":24,"warm_x":1250,"warm_radius":620,"warm_strength":0.3,"interior":id in ["camp_interior","rescue_station_interior"]}
	var art_root = str(CATALOG.config(id).get("art_root",ASSET_ROOT+id+"/"))
	config.merge(CATALOG.config(id),true)
	var manifest_path = ASSET_ROOT+"manifest.json"
	if FileAccess.file_exists(manifest_path):
		var manifest = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
		config.merge(manifest.locations.get(id,{}),true)
	# The atlas stage opts into verified outpainting; older clients retain their
	# established coordinate system and vehicle-free composition.
	if full_map:
		var wide_path = "res://assets/locations/atlas_widescreen_20261016/manifest.json"
		if FileAccess.file_exists(wide_path):
			var wide = JSON.parse_string(FileAccess.get_file_as_string(wide_path))
			if wide is Dictionary and wide.get("locations",{}).has(id):
				config.merge(wide.locations[id],true); art_root = str(config.art_root)
	padding = float(config.get("plane_padding",0)) if full_map else 0.0
	# A new art batch may be installed one location at a time. Keep the
	# already integrated story scene visible until all three new plates exist.
	var complete_stage = true
	for filename in ["far.png","mid.png","near.png"]:
		if not ResourceLoader.exists(art_root+filename): complete_stage = false
	if not complete_stage:
		_display_existing_scene(id)
		return
	config.presentation_source = "biomes_20261016" if art_root.contains("biomes_20261016") else "side_walk_20261016"
	if art_root.contains("atlas_widescreen"): config.presentation_source = "atlas_widescreen_20261016"
	for i in 3:
		var plane = Node2D.new(); plane.name = ["Far","Mid","Near"][i]
		viewport.add_child(plane); planes.append(plane)
		var sprite = Sprite2D.new(); sprite.centered = false
		var path = art_root+["far.png","mid.png","near.png"][i]
		if ResourceLoader.exists(path): sprite.texture = load(path)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		plane.add_child(sprite)
		if i == 0 and sprite.texture: source_size = sprite.texture.get_size()-Vector2(padding*2,padding*2)
	planes[2].z_index = 20; mid = planes[1]
	vehicle_root = Node2D.new(); vehicle_root.name = "ActualConvoy"; mid.add_child(vehicle_root)
	actor_layer = Node2D.new(); actor_layer.name = "WalkingActors"; actor_layer.z_index = 10; viewport.add_child(actor_layer)
	set_camera(0)

func _display_existing_scene(id: String) -> void:
	config = CATALOG.config(id)
	config.presentation_source = "existing_story_scene"
	existing_scene = load(CATALOG.scene_path(id)).instantiate()
	viewport.add_child(existing_scene)
	existing_scene.set_process(false); existing_scene.set_process_unhandled_input(false)
	if id != "camp_interior": existing_scene.auto_preview = false
	if id == "camp":
		mid = existing_scene.planes[1]; existing_scene.planes[2].z_index = 20
	else:
		mid = existing_scene.get_node("World/Mid"); existing_scene.get_node("World/Near").z_index = 20
	# Native story plates may be 2688 wide. Their existing Mid transform
	# already maps those source pixels; report that same canvas to activities
	# rather than rejecting correct scene anchors as incompatible with 2048.
	padding = 0.0
	for child in mid.get_children():
		if child is Sprite2D and child.texture != null:
			source_size = child.texture.get_size()
			break
	vehicle_root = Node2D.new(); vehicle_root.name = "ActualConvoy"; mid.add_child(vehicle_root)
	actor_layer = Node2D.new(); actor_layer.name = "WalkingActors"; actor_layer.z_index = 10; viewport.add_child(actor_layer)
	set_camera(0)

func set_camera(value: float) -> void:
	var limit = minf(24,float(config.get("camera_limit_source_canvas_pixels",24)))
	camera_x = clampf(value,-limit,limit)
	if is_instance_valid(existing_scene):
		if location_id != "camp_interior":
			existing_scene.camera_x = camera_x; existing_scene._apply_scroll()
		if is_instance_valid(actor_layer): actor_layer.queue_redraw()
		return
	# 8% overscan and bounded travel keep repaired layer edges outside the view.
	var factor = minf(canvas_size.x/source_size.x,canvas_size.y/source_size.y) if full_map else maxf(1280.0/SOURCE_SIZE.x,720.0/SOURCE_SIZE.y)*1.08
	for i in planes.size():
		planes[i].scale = Vector2.ONE*factor
		planes[i].position = canvas_size*0.5-(source_size*0.5+Vector2.ONE*padding)*factor-Vector2(camera_x*[0.12,0.5,1.0][i]*factor,0)
	if is_instance_valid(actor_layer): actor_layer.queue_redraw()

func source_to_view(point: Vector2) -> Vector2:
	return mid.get_global_transform()*(point+Vector2.ONE*padding) if is_instance_valid(mid) else point

func view_to_source(point: Vector2) -> Vector2:
	return mid.get_global_transform().affine_inverse()*point-Vector2.ONE*padding if is_instance_valid(mid) else point
