extends Node3D
## One character, independent static pose meshes and optional separate test chair.
var rig: Node3D
var camera: Camera3D
var environment: Environment
var chair: Node3D
var pose := "standing"
var angle := 0.0
var elevation := 5.0
var zoom := 2.50
var chair_visible := false

func _ready() -> void:
	rig = Node3D.new(); rig.name = "CharacterRig"; add_child(rig)
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("202630")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.78
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var world := WorldEnvironment.new(); world.environment = environment; add_child(world)
	var key := DirectionalLight3D.new(); key.light_energy = 0.7
	key.rotation_degrees = Vector3(-35,-25,0); add_child(key)
	var fill := DirectionalLight3D.new(); fill.light_energy = 0.25
	fill.rotation_degrees = Vector3(-15,150,0); add_child(fill)
	camera = Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.near = 0.01; camera.far = 30; add_child(camera); camera.current = true
	set_pose("standing")
	refresh_camera()

func set_pose(value: String) -> void:
	if value not in ["standing","seated"]: return
	for child in rig.get_children():
		rig.remove_child(child); child.queue_free()
	var state := GLTFState.new(); var document := GLTFDocument.new()
	var path := "res://assets/characters/xu_ning/xu_ning_%s.glb" % value
	if document.append_from_file(ProjectSettings.globalize_path(path),state) != OK:
		push_error("Character mesh unavailable: "+path); return
	var model := document.generate_scene(state)
	model.name = "XuNing_"+value; rig.add_child(model)
	_prepare_materials(model)
	pose = value
	if chair != null: chair.queue_free()
	chair = Node3D.new(); chair.name = "SeparateTestChair"; rig.add_child(chair)
	_build_chair()
	chair.visible = chair_visible and pose == "seated"

func _prepare_materials(node: Node) -> void:
	if node is MeshInstance3D:
		for surface in range(node.mesh.get_surface_count()):
			var material := ShaderMaterial.new()
			material.shader = preload("res://src/showcase/character_scan.gdshader")
			node.set_surface_override_material(surface,material)
	for child in node.get_children(): _prepare_materials(child)

func _box(at: Vector3, dimensions: Vector3, color: Color) -> void:
	var instance := MeshInstance3D.new(); var mesh := BoxMesh.new(); mesh.size = dimensions
	var mat := StandardMaterial3D.new(); mat.albedo_color = color; mat.roughness = 0.9
	instance.mesh = mesh; instance.material_override = mat; chair.add_child(instance); instance.position = at

func _build_chair() -> void:
	# Top of the common seat is y=0.46m. Furniture never belongs to character GLBs.
	_box(Vector3(0,0.44,0),Vector3(0.43,0.04,0.43),Color("8b6c4c"))
	for x in [-0.18,0.18]:
		for z in [-0.18,0.18]:
			_box(Vector3(x,0.21,z),Vector3(0.035,0.42,0.035),Color("454a50"))
	_box(Vector3(0,0.72,-0.20),Vector3(0.43,0.28,0.035),Color("8b6c4c"))

func set_angle(value: float) -> void:
	angle = value; rig.rotation_degrees.y = value

func set_chair(value: bool) -> void:
	chair_visible = value
	if chair != null: chair.visible = value and pose == "seated"

func set_green(value: bool) -> void:
	environment.background_color = Color(0,1,0) if value else Color("202630")

func refresh_camera() -> void:
	camera.size = zoom
	var target := Vector3(0,0.88,0)
	var radians := deg_to_rad(elevation)
	camera.position = target+Vector3(0,sin(radians)*4,cos(radians)*4)
	camera.look_at(target)
