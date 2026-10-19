extends RefCounted
## Production and placement preview share this source-space 2D renderer.
## Production accepts only confirmed layouts and the new independent side artwork.
const LAYOUT = preload("res://src/game/vehicle_side_2d_layout.gd")
const LEGACY_ART = preload("res://src/game/vehicle_art.gd")
const ENVIRONMENT = preload("res://src/game/vehicle_environment.gdshader")
const SHADOW = preload("res://assets/vehicles/realistic_20261015/ground_shadow.png")
const REFERENCE_ROOT = "res://assets/vehicles/realistic_20261015/"

static func _find_in(root: String, vehicle_id: String, facing: String, reference_only: bool) -> Dictionary:
	var path = root+"manifest.json"
	if not FileAccess.file_exists(path): return {}
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not manifest is Dictionary or not manifest.get("vehicles",[]) is Array: return {}
	for item in manifest.get("vehicles",[]):
		if not item is Dictionary or item.get("id","") != vehicle_id or item.get("facing","") != facing: continue
		var filename = str(item.get("file",""))
		if filename.is_empty() or filename.is_absolute_path() or ".." in filename: return {}
		var texture_path = root+filename
		if not ResourceLoader.exists(texture_path): return {}
		var texture = load(texture_path) as Texture2D
		if texture == null or not LAYOUT.number(item.get("ground_y")): return {}
		var ground = float(item.ground_y)
		if ground < 0 or ground > texture.get_height(): return {}
		if not item.get("wheel_x",[]) is Array: return {}
		for wheel in item.get("wheel_x",[]):
			if not LAYOUT.number(wheel) or float(wheel) < 0.0 or float(wheel) > 1.0: return {}
		var record = item.duplicate(true)
		record.merge({"path":texture_path,"asset_root":root,"reference_only":reference_only,
			"size":[texture.get_width(),texture.get_height()],"texture":texture},true)
		return record
	return {}

static func find_art(vehicle_id: String, facing: String, allow_reference: bool = false) -> Dictionary:
	var art = _find_in(LAYOUT.ART_ROOT,vehicle_id,facing,false)
	if art.is_empty() and allow_reference: art = _find_in(REFERENCE_ROOT,vehicle_id,facing,true)
	return art

static func asset_matches_confirmation(placement: Dictionary, art: Dictionary) -> bool:
	if art.is_empty() or art.get("reference_only",true): return false
	if placement.get("asset_path","") != art.get("path",""): return false
	# Anchors belong to the approved composition too: changing only a manifest
	# must not move a saved vehicle while its image fingerprint stays the same.
	if placement.get("asset_ground_y") != art.get("ground_y"): return false
	if placement.get("asset_wheel_x",[]) != art.get("wheel_x",[]): return false
	var expected = str(placement.get("asset_sha256",""))
	# Exported textures have import remaps rather than raw PNG bytes. Keep the
	# original source fingerprint in the manifest; editor runs still hash the
	# real file so local edits invalidate an old confirmation immediately.
	var actual = FileAccess.get_sha256(str(art.path)) if FileAccess.file_exists(str(art.path)) else str(art.get("file_sha256",""))
	return not expected.is_empty() and expected == actual

static func create(placement: Dictionary, plane_padding: float = 0.0, allow_reference: bool = false) -> Node2D:
	var scene_id = str(placement.get("scene_id","")); var vehicle_id = str(placement.get("vehicle_id",""))
	if not LAYOUT.valid_record(placement,scene_id,vehicle_id): return null
	var art = find_art(vehicle_id,str(placement.facing),allow_reference)
	if art.is_empty(): return null
	if not allow_reference:
		if placement.get("user_confirmed",false) != true or not asset_matches_confirmation(placement,art): return null
	var texture: Texture2D = art.texture
	var factor = float(placement.scale_percent)/100.0
	var dimensions = texture.get_size()*factor
	var wheels: Array[float] = []
	for wheel in art.get("wheel_x",[]):
		if LAYOUT.number(wheel) and float(wheel) >= 0.0 and float(wheel) <= 1.0:
			wheels.append(float(wheel)*texture.get_width())
	# Keep the documented wheel-baseline midpoint fixed when changing facing
	# or rotating. The transparent crop's center is not necessarily that point.
	var ground_x = texture.get_width()*0.5
	if wheels.size() >= 2: ground_x = (wheels.min()+wheels.max())*0.5
	var at = Vector2(float(placement.position[0]),float(placement.position[1]))
	var angle = deg_to_rad(float(placement.rotation_degrees))
	var root = Node2D.new(); root.name = "SideVehicle_%s_%s" % [vehicle_id,placement.facing]
	root.set_meta("side_vehicle_2d",true); root.set_meta("visual_id",vehicle_id)
	root.set_meta("facing",placement.facing); root.set_meta("reference_only",art.reference_only)
	root.set_meta("placement",placement.duplicate(true)); root.set_meta("asset_path",art.path)
	root.set_meta("ground_position",at)
	# A single parent transform moves the body, future attachments and contact shadows.
	# Padding belongs to the background plates, never to the saved source coordinates.
	root.position = at+Vector2.ONE*plane_padding
	root.rotation = angle; root.scale = Vector2.ONE*factor
	var shadow = Sprite2D.new(); shadow.name = "GroundContact"; shadow.texture = SHADOW
	shadow.position = Vector2(texture.get_width()*0.5-ground_x,2)
	shadow.scale = Vector2(texture.get_width()*0.91/256.0,maxf(18.0,texture.get_height()*0.045)/64.0)
	root.add_child(shadow)
	for wheel in wheels:
		var contact = Sprite2D.new(); contact.name = "WheelContact"; contact.texture = SHADOW
		contact.position = Vector2(wheel-ground_x,1)
		contact.scale = Vector2(texture.get_width()*0.13/256.0,maxf(7.0,texture.get_height()*0.018)/64.0)
		root.add_child(contact)
	var body = Sprite2D.new(); body.name = "Body"; body.texture = texture; body.centered = false
	body.position = Vector2(-ground_x,-float(art.ground_y))
	body.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var light = LEGACY_ART.profile(scene_id)
	var material = ShaderMaterial.new(); material.shader = ENVIRONMENT
	material.set_shader_parameter("exposure_stops",float(light.exposure))
	material.set_shader_parameter("ambient_tint",Vector3(light.tint[0],light.tint[1],light.tint[2]))
	material.set_shader_parameter("saturation",float(light.saturation))
	material.set_shader_parameter("source_origin",at+body.position*factor)
	material.set_shader_parameter("source_size",dimensions)
	material.set_shader_parameter("ground_pivot",at); material.set_shader_parameter("surface_angle",angle)
	material.set_shader_parameter("warm_position",Vector2(light.warm_position[0],light.warm_position[1]))
	material.set_shader_parameter("warm_radius",float(light.warm_radius))
	material.set_shader_parameter("warm_strength",float(light.warm_strength))
	body.material = material; root.add_child(body)
	return root

static func apply_convoy(backdrop, vehicles: Array) -> Dictionary:
	# Call after walk_backdrop.display() and after a convoy/layout change. Never
	# call every frame: loading configuration and validating asset hashes are event work.
	var result = {"mounted":[],"skipped":[]}
	if not is_instance_valid(backdrop) or not is_instance_valid(backdrop.vehicle_root): return result
	for child in backdrop.vehicle_root.get_children():
		if child.get_meta("side_vehicle_2d",false):
			backdrop.vehicle_root.remove_child(child); child.queue_free()
	var seen: Dictionary = {}
	for index in vehicles.size():
		var vehicle = vehicles[index]
		if not vehicle is Dictionary or vehicle.get("destroyed",false) or float(vehicle.get("durability",100)) <= 0: continue
		var id = LEGACY_ART.model_id(vehicle,index)
		if seen.has(id):
			result.skipped.append({"id":id,"reason":"This scene has one placement per visual vehicle ID"}); continue
		seen[id] = true
		var record = LAYOUT.load_confirmed(str(backdrop.location_id),id,backdrop.source_size)
		if record.is_empty():
			result.skipped.append({"id":id,"reason":"No confirmed placement for this scene/source canvas"}); continue
		var node = create(record,float(backdrop.padding),false)
		if node == null:
			result.skipped.append({"id":id,"reason":"Confirmed new side artwork is absent or changed; no reference fallback"}); continue
		node.set_meta("original_index",index); backdrop.vehicle_root.add_child(node)
		result.mounted.append(id)
	return result
