extends RefCounted
## Presentation only. Legacy saves resolve from their original convoy index;
## filtering destroyed cars must not change the identity of surviving vehicles.
const ART = "res://assets/vehicles/realistic_20261015/"
const MANIFEST = preload("res://assets/vehicles/realistic_20261015/manifest.json")
const LIGHTING = preload("res://data/final/vehicle_scene_lighting.json")
const ENVIRONMENT = preload("res://src/game/vehicle_environment.gdshader")
const SHADOW = preload("res://assets/vehicles/realistic_20261015/ground_shadow.png")

static func model_id(vehicle: Dictionary, original_index: int) -> String:
	var requested = str(vehicle.get("visual_id", "")).to_upper()
	if requested in ["V01", "V02", "V03", "V04", "V05", "V06", "V07", "V08"]:
		return requested
	# Existing saves contain nicknames, durability and modules, with no art ID.
	return "V01" if original_index == 0 else "V05"

static func profile(location: String) -> Dictionary:
	return LIGHTING.data.get(location, LIGHTING.data.journey_road).duplicate(true)

static func facing(vehicle: Dictionary, location: String, slot: int) -> String:
	var requested = str(vehicle.get("facing", ""))
	if requested in ["left", "right"]: return requested
	var directions: Array = profile(location).facing
	return str(directions[mini(slot, directions.size()-1)])

static func create(vehicle: Dictionary, original_index: int, slot: int, rect: Array, location: String) -> Node2D:
	var id = model_id(vehicle, original_index)
	var direction = facing(vehicle, location, slot)
	var record: Dictionary = {}
	for entry in MANIFEST.data.vehicles:
		if entry.id == id and entry.facing == direction:
			record = entry
			break
	var texture: Texture2D = load(ART + record.file)
	var factor = minf(float(rect[2])/texture.get_width(), float(rect[3])/texture.get_height()) * 0.93
	var dimensions = Vector2(texture.get_width(), texture.get_height()) * factor
	var baseline = Vector2(float(rect[0])+float(rect[2])*0.5, float(rect[1])+float(rect[3]))
	var ground_y = float(record.ground_y) * factor
	var origin = baseline - Vector2(dimensions.x*0.5, ground_y)
	var root = Node2D.new()
	root.name = "Vehicle_%d_%s_%s" % [original_index, id, direction]
	root.set_meta("visual_id", id); root.set_meta("facing", direction)
	root.set_meta("original_index", original_index); root.set_meta("ground_position", baseline)
	root.set_meta("source_rect", Rect2(origin, dimensions))
	var lighting = profile(location)
	var angle = deg_to_rad(float(lighting.get("road_angle_degrees", 0)))
	var surface = Node2D.new(); surface.name = "Surface"
	surface.position = baseline; surface.rotation = angle
	root.add_child(surface)
	var shadow = Sprite2D.new(); shadow.name = "GroundContact"; shadow.texture = SHADOW
	shadow.position = Vector2(0, 1.5)
	shadow.scale = Vector2(dimensions.x*0.91/256.0, 20.0/64.0)
	surface.add_child(shadow)
	for wheel in record.get("wheel_x", [0.18, 0.80]):
		var contact = Sprite2D.new(); contact.texture = SHADOW
		contact.position = Vector2((float(wheel)-0.5)*dimensions.x, 1.0)
		contact.scale = Vector2(dimensions.x*0.13/256.0, 7.0/64.0)
		surface.add_child(contact)
	var body = Sprite2D.new(); body.name = "Body"; body.texture = texture; body.centered = false
	body.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	body.position = origin; body.scale = Vector2.ONE*factor
	# Rotate about the wheel baseline. Flat scenes keep the exact original fit.
	body.position = baseline + (origin-baseline).rotated(angle)
	body.rotation = angle
	var material = ShaderMaterial.new(); material.shader = ENVIRONMENT
	material.set_shader_parameter("exposure_stops", float(lighting.exposure))
	var tint: Array = lighting.tint
	material.set_shader_parameter("ambient_tint", Vector3(tint[0], tint[1], tint[2]))
	material.set_shader_parameter("saturation", float(lighting.saturation))
	material.set_shader_parameter("source_origin", origin)
	material.set_shader_parameter("source_size", dimensions)
	material.set_shader_parameter("ground_pivot", baseline)
	material.set_shader_parameter("surface_angle", angle)
	var warm: Array = lighting.warm_position
	material.set_shader_parameter("warm_position", Vector2(warm[0], warm[1]))
	material.set_shader_parameter("warm_radius", float(lighting.warm_radius))
	material.set_shader_parameter("warm_strength", float(lighting.warm_strength))
	body.material = material
	root.add_child(body)
	return root
