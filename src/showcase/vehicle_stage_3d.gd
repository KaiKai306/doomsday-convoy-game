extends Node2D
## Real-time vehicle render and a separate, physically cast shadow pass.
const MODEL_PATH = "res://assets/showcase_vehicle/v05_detail.glb"
const RENDER_SIZE = Vector2i(1400, 1000)
const DEFAULT_ELEVATION = 15.109575
const PREVIEW_MODELS = preload("res://src/showcase/vehicle_preview_models.gd")
var model_id = "V05"
var viewport: SubViewport
var shadow_viewport: SubViewport
var rig: Node3D
var shadow_rig: Node3D
var camera: Camera3D
var shadow_camera: Camera3D
var moon: DirectionalLight3D
var fill: DirectionalLight3D
var warm: OmniLight3D
var ambient: WorldEnvironment
var vehicle_sprite: Sprite2D
var shadow_sprite: Sprite2D
var modules: Dictionary = {}
var shadow_modules: Dictionary = {}
var angle := 0.0
var view_elevation := DEFAULT_ELEVATION
var warm_enabled := true
var shadows_enabled := true
var studio_enabled := false
var lights: Array[OmniLight3D] = []
var ready_ok := false

func _ready() -> void:
	viewport = _viewport("VehicleRender", true)
	shadow_viewport = _viewport("ShadowRender", false)
	rig = Node3D.new(); rig.name = "VehicleRig"; viewport.add_child(rig)
	shadow_rig = Node3D.new(); shadow_rig.name = "ShadowRig"; shadow_viewport.add_child(shadow_rig)
	var model := _load_model()
	if model == null: return
	rig.add_child(model)
	_create_modules(rig, modules)
	var shadow_model := model.duplicate()
	shadow_rig.add_child(shadow_model)
	_create_modules(shadow_rig, shadow_modules)
	_shadow_only(shadow_rig)
	_build_lighting()
	_build_shadow_pass()
	camera = _camera(viewport)
	shadow_camera = _camera(shadow_viewport)
	shadow_sprite = Sprite2D.new(); shadow_sprite.centered = false
	shadow_sprite.texture = shadow_viewport.get_texture()
	var shadow_shader := Shader.new()
	shadow_shader.code = "shader_type canvas_item; void fragment(){vec3 c=vec3(0.0); for(int x=-1;x<=1;x++){for(int y=-1;y<=1;y++){c+=texture(TEXTURE,UV+vec2(float(x),float(y))*TEXTURE_PIXEL_SIZE*2.0).rgb/9.0;}} float a=clamp(1.0-dot(c,vec3(0.333333)),0.0,1.0); COLOR=vec4(0.006,0.012,0.025,a*0.82);}"
	var shadow_material := ShaderMaterial.new(); shadow_material.shader = shadow_shader
	shadow_sprite.material = shadow_material; add_child(shadow_sprite)
	vehicle_sprite = Sprite2D.new(); vehicle_sprite.centered = false
	vehicle_sprite.texture = viewport.get_texture(); add_child(vehicle_sprite)
	set_angle(0.0)
	set_module("armor", true); set_module("cargo", true); set_module("lamps", true)
	ready_ok = true

func _viewport(label: String, transparent: bool) -> SubViewport:
	var result := SubViewport.new(); result.name = label; result.size = RENDER_SIZE
	result.transparent_bg = transparent; result.own_world_3d = true
	result.msaa_3d = Viewport.MSAA_4X
	result.render_target_update_mode = SubViewport.UPDATE_ONCE
	result.gui_disable_input = true; add_child(result)
	return result

func _load_model() -> Node3D:
	if model_id != "V05": return PREVIEW_MODELS.new().create(model_id)
	var state := GLTFState.new(); var doc := GLTFDocument.new()
	var result := doc.append_from_file(ProjectSettings.globalize_path(MODEL_PATH), state)
	if result != OK:
		push_error("Showcase model unavailable: " + MODEL_PATH); return null
	var model := doc.generate_scene(state)
	model.name = "V05Body"
	_prepare_materials(model)
	return model

func set_vehicle_model(id: String) -> bool:
	if not PREVIEW_MODELS.supports(id): return false
	if model_id == id: return true
	model_id = id
	if not ready_ok: return true
	var enabled: Dictionary = {}
	for key in modules: enabled[key] = modules[key].visible
	for parent in [rig,shadow_rig]:
		for child in parent.get_children(): parent.remove_child(child); child.free()
	modules.clear(); shadow_modules.clear(); lights.clear()
	var model = _load_model()
	if model == null: return false
	rig.add_child(model); shadow_rig.add_child(model.duplicate())
	_create_modules(rig,modules); _create_modules(shadow_rig,shadow_modules)
	_shadow_only(shadow_rig)
	for key in enabled: set_module(key,enabled[key])
	_request_render()
	return true

func _prepare_materials(node: Node) -> void:
	if node is MeshInstance3D:
		for surface in range(node.mesh.get_surface_count()):
			var original: Material = node.get_active_material(surface)
			if original is StandardMaterial3D:
				var material := ShaderMaterial.new()
				material.shader = preload("res://src/showcase/scan_paint.gdshader")
				node.set_surface_override_material(surface, material)
	for child in node.get_children(): _prepare_materials(child)

func _material(color: Color, metallic: float = 0.5, roughness: float = 0.65) -> StandardMaterial3D:
	var result := StandardMaterial3D.new(); result.albedo_color = color
	result.metallic = metallic; result.roughness = roughness
	var noise := FastNoiseLite.new(); noise.seed = 1437; noise.frequency = 0.13
	var texture := NoiseTexture2D.new(); texture.width = 128; texture.height = 128; texture.noise = noise
	var ramp := Gradient.new(); ramp.set_color(0,Color(0.48,0.46,0.42)); ramp.set_color(1,Color(0.94,0.95,0.93))
	texture.color_ramp = ramp; result.albedo_texture = texture
	return result

func _box(parent: Node3D, label: String, at: Vector3, dimensions: Vector3, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new(); mesh.name = label
	var box := BoxMesh.new(); box.size = dimensions
	mesh.mesh = box; mesh.material_override = material
	parent.add_child(mesh); mesh.position = at
	return mesh

func _disc(parent: Node3D, at: Vector3, radius: float, depth: float, material: Material) -> void:
	var mesh := MeshInstance3D.new(); var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius; cylinder.bottom_radius = radius; cylinder.height = depth; cylinder.radial_segments = 24
	mesh.mesh = cylinder; mesh.material_override = material; parent.add_child(mesh)
	mesh.position = at; mesh.rotation_degrees.x = 90

func _bar(parent: Node3D, a: Vector3, b: Vector3, radius: float, material: Material) -> void:
	var mesh := MeshInstance3D.new(); var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius; cylinder.bottom_radius = radius
	cylinder.height = a.distance_to(b); cylinder.radial_segments = 12
	mesh.mesh = cylinder; mesh.material_override = material; parent.add_child(mesh)
	mesh.position = (a+b)*0.5
	var direction := (b-a).normalized()
	mesh.quaternion = Quaternion(Vector3.UP, direction)

func _create_modules(parent: Node3D, collection: Dictionary) -> void:
	var steel := _material(Color("#4d5b5d"), 0.38, 0.76)
	var edge := _material(Color("#7b857c"), 0.42, 0.65)
	var bolt := _material(Color("#9e8c68"), 0.75, 0.5)
	var armor := Node3D.new(); armor.name = "ArmorModule"; parent.add_child(armor); collection.armor = armor
	for sign_value in [-1.0, 1.0]:
		_box(armor, "DoorArmor", Vector3(sign_value*1.02,1.03,0.0), Vector3(0.075,0.58,1.42), steel)
		for y in [0.76,1.3]:
			_box(armor,"PlateSeam",Vector3(sign_value*1.064,y,0.0),Vector3(0.012,0.017,1.38),edge)
		_box(armor, "RockSlider", Vector3(sign_value*1.08,0.52,-0.1), Vector3(0.11,0.1,2.45), edge)
		for z in [-0.55,0.55]:
			_box(armor, "PlateBolt", Vector3(sign_value*1.066,1.22,z), Vector3(0.025,0.055,0.055), bolt)
	_box(armor, "FrontBumper", Vector3(0,0.57,2.37), Vector3(1.98,0.14,0.17), steel)
	_bar(armor, Vector3(-0.77,0.73,2.51), Vector3(-0.77,1.13,2.51), 0.045, edge)
	_bar(armor, Vector3(0.77,0.73,2.51), Vector3(0.77,1.13,2.51), 0.045, edge)
	_bar(armor, Vector3(-0.77,1.13,2.51), Vector3(0.77,1.13,2.51), 0.045, edge)
	var cargo := Node3D.new(); cargo.name = "CargoModule"; parent.add_child(cargo); collection.cargo = cargo
	var canvas := _material(Color("#80774d"), 0.0, 0.95)
	var olive := _material(Color("#465740"), 0.1, 0.85)
	# Add separate rear supplies; the scanned model's original roof luggage stays part of its body.
	for x in [-0.56,0.56]:
		_box(cargo,"RearCarrier",Vector3(x,0.84,-2.34),Vector3(0.82,0.07,0.55),steel)
		_box(cargo,"SupplyCrate",Vector3(x,1.13,-2.34),Vector3(0.65,0.51,0.43),canvas if x<0 else olive)
		_box(cargo,"CrateLid",Vector3(x,1.4,-2.34),Vector3(0.68,0.035,0.46),edge)
		for offset in [-0.2,0.2]:
			_box(cargo,"CrateBand",Vector3(x+offset,1.13,-2.57),Vector3(0.045,0.55,0.018),steel)
	var lamps := Node3D.new(); lamps.name = "LampsModule"; parent.add_child(lamps); collection.lamps = lamps
	_box(lamps,"LampRail",Vector3(0,2.0,0.92),Vector3(1.7,0.07,0.09),steel)
	var lens := _material(Color("#e5d6ae"),0.15,0.2)
	lens.albedo_texture = null
	lens.emission_enabled = true; lens.emission = Color("#ffc477"); lens.emission_energy_multiplier = 0.45
	for x in [-0.64,-0.22,0.22,0.64]:
		_disc(lamps,Vector3(x,2.11,0.94),0.12,0.12,steel)
		_disc(lamps,Vector3(x,2.11,1.006),0.096,0.014,lens)
	if parent == rig:
		var light := OmniLight3D.new(); light.position = Vector3(0,1.7,2.6)
		light.light_color = Color("#ffd496"); light.light_energy = 0.36; light.omni_range = 3.5
		lamps.add_child(light); lights.append(light)

func _shadow_only(node: Node) -> void:
	if node is MeshInstance3D: node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	for child in node.get_children(): _shadow_only(child)

func _build_lighting() -> void:
	ambient = WorldEnvironment.new(); ambient.environment = Environment.new()
	var env := ambient.environment
	env.background_mode = Environment.BG_COLOR; env.background_color = Color(0,0,0,0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_sky_contribution = 0.0
	env.ambient_light_color = Color("#9eb5d5"); env.ambient_light_energy = 0.85
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	viewport.add_child(ambient)
	moon = DirectionalLight3D.new(); moon.name = "Moon"
	moon.light_color = Color("#86aef0"); moon.light_energy = 1.25
	moon.position = Vector3(5,7,-4); moon.look_at_from_position(moon.position,Vector3.ZERO)
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 35; viewport.add_child(moon)
	fill = DirectionalLight3D.new(); fill.name = "SkyBounce"
	fill.light_color = Color("#7896bd"); fill.light_energy = 0.5
	viewport.add_child(fill); fill.position = Vector3(7,2,7); fill.look_at(Vector3(0,1,0))
	warm = OmniLight3D.new(); warm.name = "StationLight"
	warm.position = Vector3(1.0,3.2,5); warm.light_color = Color("#ffb666")
	warm.light_energy = 2.5; warm.omni_range = 11; warm.omni_attenuation = 0.6
	viewport.add_child(warm)

func _build_shadow_pass() -> void:
	var environment := WorldEnvironment.new(); environment.environment = Environment.new()
	var env := environment.environment
	env.background_mode = Environment.BG_COLOR; env.background_color = Color.WHITE
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE; env.ambient_light_energy = 0.18
	shadow_viewport.add_child(environment)
	var ground := MeshInstance3D.new(); var plane := PlaneMesh.new(); plane.size = Vector2(40,40)
	ground.mesh = plane
	var ground_material := StandardMaterial3D.new(); ground_material.albedo_color = Color.WHITE; ground_material.roughness = 1.0
	ground.material_override = ground_material
	shadow_viewport.add_child(ground); ground.position.y = -0.008
	var light := DirectionalLight3D.new(); light.light_color = Color.WHITE
	light.light_energy = 1.0; light.rotation = moon.rotation
	light.shadow_enabled = true; light.shadow_blur = 1.6; light.shadow_bias = 0.03
	light.directional_shadow_max_distance = 30
	shadow_viewport.add_child(light)

func _camera(parent: SubViewport) -> Camera3D:
	var result := Camera3D.new(); result.projection = Camera3D.PROJECTION_ORTHOGONAL
	result.size = 5.6; result.near = 0.05; result.far = 80
	parent.add_child(result); result.current = true
	result.position = Vector3(8,3.7,6); result.look_at(Vector3(0,1.0,0))
	return result

func set_angle(value: float) -> void:
	angle = value; rig.rotation.y = deg_to_rad(angle); shadow_rig.rotation.y = rig.rotation.y
	var foot := camera.unproject_position(Vector3.ZERO)
	vehicle_sprite.position = -foot; shadow_sprite.position = -foot
	_request_render()

func set_view_elevation(value: float) -> void:
	view_elevation = clampf(value,5.0,45.0)
	for view_camera in [camera,shadow_camera]:
		view_camera.position = Vector3(8,1.0+10.0*tan(deg_to_rad(view_elevation)),6)
		view_camera.look_at(Vector3(0,1.0,0))
	var foot := camera.unproject_position(Vector3.ZERO)
	vehicle_sprite.position = -foot; shadow_sprite.position = -foot
	_request_render()

func set_module(id: String, enabled: bool) -> void:
	if not modules.has(id): return
	modules[id].visible = enabled; shadow_modules[id].visible = enabled
	_request_render()

func set_warm(enabled: bool) -> void:
	warm_enabled = enabled; warm.visible = enabled and not studio_enabled
	_request_render(false)

func set_shadows(enabled: bool) -> void:
	shadows_enabled = enabled; shadow_sprite.visible = enabled

func set_studio(enabled: bool) -> void:
	studio_enabled = enabled
	moon.light_color = Color.WHITE if enabled else Color("#86aef0")
	ambient.environment.ambient_light_color = Color.WHITE if enabled else Color("#9eb5d5")
	ambient.environment.ambient_light_energy = 1.2 if enabled else 0.85
	fill.light_color = Color.WHITE if enabled else Color("#7896bd")
	warm.visible = warm_enabled and not enabled
	_request_render(false)

func _request_render(include_shadow: bool = true) -> void:
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	if include_shadow: shadow_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func get_snapshot() -> Dictionary:
	return {"angle":angle,"scale_percent":scale.x*100.0,"view_elevation_degrees":view_elevation,"armor":modules.armor.visible,"cargo":modules.cargo.visible,"lamps":modules.lamps.visible,"warm":warm.visible,"warm_requested":warm_enabled,"studio":studio_enabled,"shadows":shadow_sprite.visible,"model":MODEL_PATH if model_id == "V05" else "procedural:"+model_id,"visual_id":model_id,"simplified_preview":model_id != "V05"}
