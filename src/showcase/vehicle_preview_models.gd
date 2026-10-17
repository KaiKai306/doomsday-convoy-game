extends RefCounted
## Real mesh previews for vehicles without supplied 3D art. +Y up, +Z front.
## V05 keeps its authored scan in vehicle_stage_3d.gd.
const NAMES = {"V01":"旧皮卡","V02":"银色轿车","V03":"旧式轿车","V04":"旅行面包车","V05":"深灰越野车","V06":"深色面包车","V07":"厢式货车","V08":"沙色越野车"}
var materials: Dictionary = {}

static func supports(id: String) -> bool:
	return NAMES.has(id)

func create(id: String) -> Node3D:
	if not supports(id) or id == "V05": return null
	var body = Node3D.new(); body.name = id+"SimplifiedBody"
	body.set_meta("visual_id",id); body.set_meta("simplified_preview",true)
	var colors = {"V01":"505b50","V02":"a1a7aa","V03":"4b5753","V04":"66716a","V06":"353d41","V07":"69736a","V08":"a19472"}
	materials.paint = _material(Color(colors[id]),0.48,0.73,true)
	materials.steel = _material(Color("505a5e"),0.65,0.53)
	materials.rubber = _material(Color("13191c"),0.02,0.96)
	materials.glass = _material(Color("162b35"),0.42,0.23)
	materials.chrome = _material(Color("949e9e"),0.77,0.36)
	materials.canvas = _material(Color("635943"),0.0,0.95,true)
	materials.lamp = _material(Color("c7c0a5"),0.25,0.28)
	materials.red = _material(Color("6c302c"),0.15,0.38)
	_box(body,Vector3(0,0.48,0),Vector3(1.62,0.18,4.12),materials.rubber,"Chassis")
	if id in ["V02","V03"]: _sedan(body,id == "V03")
	elif id in ["V04","V06"]: _van(body,id == "V04")
	elif id == "V07": _truck(body)
	elif id == "V01": _pickup(body)
	else: _suv(body)
	var radius = 0.36 if id in ["V02","V03"] else 0.42
	var axle = 1.42 if id in ["V04","V07"] else 1.36
	for x in [-0.94,0.94]:
		for z in [-axle,axle]: _wheel(body,Vector3(x,radius,z),radius)
	for z in [-2.23,2.23]:
		_box(body,Vector3(0,0.57,z),Vector3(1.94,0.13,0.13),materials.steel,"Bumper")
		for x in [-0.74,0.74]:
			_box(body,Vector3(x,0.97,z+signf(z)*0.035),Vector3(0.29,0.15,0.045),materials.lamp if z>0 else materials.red,"Lamp")
	_box(body,Vector3(0,0.94,2.268),Vector3(0.92,0.23,0.035),materials.rubber,"Grille")
	for x in [-0.38,-0.19,0.0,0.19,0.38]:
		_box(body,Vector3(x,0.94,2.293),Vector3(0.027,0.19,0.015),materials.chrome,"GrilleBar")
	for side in [-1.0,1.0]:
		_bar(body,Vector3(side*0.95,1.24,1.04),Vector3(side*1.14,1.23,1.1),0.022,materials.steel)
		_box(body,Vector3(side*1.15,1.25,1.1),Vector3(0.13,0.14,0.23),materials.steel,"Mirror")
		# Wear is deterministic and never consumes gameplay RNG.
		for i in range(14):
			var z = -1.8+float(i)*0.27
			_box(body,Vector3(side*0.966,0.76+sin(float(i)*7.1)*0.08,z),Vector3(0.005,0.009,0.07+float(i%3)*0.04),materials.steel,"PaintWear")
	return body

func _material(color: Color,metallic: float,roughness: float,weathered: bool = false) -> StandardMaterial3D:
	var result = StandardMaterial3D.new(); result.albedo_color = color
	result.metallic = metallic; result.roughness = roughness
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	if weathered:
		var noise = FastNoiseLite.new(); noise.seed = 827; noise.frequency = 0.12
		var texture = NoiseTexture2D.new(); texture.width = 128; texture.height = 128; texture.noise = noise
		var ramp = Gradient.new(); ramp.set_color(0,Color(0.52,0.48,0.42)); ramp.set_color(1,Color(0.92,0.93,0.9)); texture.color_ramp = ramp
		result.albedo_texture = texture; result.uv1_triplanar = true; result.uv1_scale = Vector3.ONE*2.0
	return result

func _box(parent: Node3D,at: Vector3,dimensions: Vector3,material: Material,label: String = "Panel") -> MeshInstance3D:
	var mesh = MeshInstance3D.new(); var box = BoxMesh.new(); box.size = dimensions
	mesh.mesh = box; mesh.material_override = material; mesh.name = label; parent.add_child(mesh); mesh.position = at
	return mesh

func _bar(parent: Node3D,a: Vector3,b: Vector3,radius: float,material: Material) -> void:
	var mesh = MeshInstance3D.new(); var cylinder = CylinderMesh.new()
	cylinder.top_radius = radius; cylinder.bottom_radius = radius; cylinder.height = a.distance_to(b); cylinder.radial_segments = 10
	mesh.mesh = cylinder; mesh.material_override = material; parent.add_child(mesh)
	mesh.position = (a+b)*0.5; mesh.quaternion = Quaternion(Vector3.UP,(b-a).normalized())

func _panel(parent: Node3D,points: Array,material: Material) -> void:
	var surface = SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(1,points.size()-1):
		for p in [points[0],points[i],points[i+1]]: surface.add_vertex(p)
	surface.generate_normals()
	var mesh = MeshInstance3D.new(); mesh.mesh = surface.commit(); mesh.material_override = material; parent.add_child(mesh)

func _prism(parent: Node3D,profile: PackedVector2Array,width: float,material: Material) -> void:
	var triangles = Geometry2D.triangulate_polygon(profile)
	var surface = SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.0,1.0]:
		for i in range(0,triangles.size(),3):
			var order = [i,i+1,i+2] if side<0 else [i+2,i+1,i]
			for index in order:
				var point = profile[triangles[index]]; surface.add_vertex(Vector3(side*width*0.5,point.y,point.x))
	for i in profile.size():
		var a = profile[i]; var b = profile[(i+1)%profile.size()]
		var vertices = [Vector3(-width*0.5,a.y,a.x),Vector3(width*0.5,a.y,a.x),Vector3(width*0.5,b.y,b.x),Vector3(-width*0.5,b.y,b.x)]
		for index in [0,1,2,0,2,3]: surface.add_vertex(vertices[index])
	surface.generate_normals()
	var mesh = MeshInstance3D.new(); mesh.mesh = surface.commit(); mesh.material_override = material; parent.add_child(mesh)

func _windows(parent: Node3D,profile: PackedVector2Array,width: float,divisions: Array) -> void:
	# Dark opaque windows sit in actual side planes; they are not camera-facing images.
	for side in [-1.0,1.0]:
		var points: Array = []
		for p in profile: points.append(Vector3(side*width*0.5,p.y,p.x))
		_panel(parent,points,materials.glass)
		for z in divisions:
			_box(parent,Vector3(side*(width*0.5+0.012),1.49,z),Vector3(0.035,0.44,0.065),materials.paint,"WindowPillar")
		for z in divisions:
			_box(parent,Vector3(side*0.977,1.12,z-0.28),Vector3(0.025,0.035,0.17),materials.chrome,"DoorHandle")
	# Front/rear glass follows the roof's slope.
	for indices in [[0,profile.size()-1],[1,2]]:
		var a = profile[indices[0]]; var b = profile[indices[1]]
		_panel(parent,[Vector3(-width*0.47,a.y,a.x),Vector3(width*0.47,a.y,a.x),Vector3(width*0.47,b.y,b.x),Vector3(-width*0.47,b.y,b.x)],materials.glass)

func _wheel(parent: Node3D,at: Vector3,radius: float) -> void:
	var tire = MeshInstance3D.new(); var torus = TorusMesh.new()
	torus.inner_radius = radius*0.51; torus.outer_radius = radius; torus.rings = 28; torus.ring_segments = 12
	tire.mesh = torus; tire.material_override = materials.rubber; parent.add_child(tire); tire.position = at; tire.rotation_degrees.z = 90
	var hub = MeshInstance3D.new(); var cylinder = CylinderMesh.new()
	cylinder.top_radius = radius*0.53; cylinder.bottom_radius = radius*0.53; cylinder.height = 0.21; cylinder.radial_segments = 24
	hub.mesh = cylinder; hub.material_override = materials.steel; parent.add_child(hub); hub.position = at; hub.rotation_degrees.z = 90
	for i in range(20):
		var angle = TAU*float(i)/20
		var tread = _box(parent,at+Vector3(0,sin(angle)*radius,cos(angle)*radius),Vector3(0.25,0.045,0.075),materials.rubber,"Tread")
		tread.rotation.x = -angle
	for i in range(6):
		var angle = TAU*float(i)/6
		_box(parent,at+Vector3(signf(at.x)*0.118,sin(angle)*radius*0.32,cos(angle)*radius*0.32),Vector3(0.025,0.04,0.04),materials.chrome,"WheelBolt")

func _rack(parent: Node3D,height: float,length: float = 2.5,center: float = -0.2) -> void:
	for x in [-0.7,0.7]:
		_bar(parent,Vector3(x,height,center-length*0.5),Vector3(x,height,center+length*0.5),0.028,materials.steel)
	for z in [-0.5,0.0,0.5]:
		_bar(parent,Vector3(-0.7,height,center+z*length),Vector3(0.7,height,center+z*length),0.025,materials.steel)
	for item in [[-0.34,-0.65,0.7],[0.34,0.2,0.9]]:
		_box(parent,Vector3(item[0],height+0.18,center+item[1]*0.6),Vector3(0.58,0.34,item[2]),materials.canvas,"Luggage")
		for z in [-0.2,0.2]:
			_box(parent,Vector3(item[0],height+0.36,center+item[1]*0.6+z),Vector3(0.59,0.025,0.035),materials.rubber,"Strap")

func _sedan(parent: Node3D,boxy: bool) -> void:
	_prism(parent,PackedVector2Array([Vector2(-2.17,0.65),Vector2(2.17,0.65),Vector2(2.15,0.99),Vector2(1.25,1.1),Vector2(-1.55,1.1),Vector2(-2.17,0.96)]),1.9,materials.paint)
	var roof = 1.67 if boxy else 1.59
	var cabin = PackedVector2Array([Vector2(-1.45,1.08),Vector2(1.27,1.08),Vector2(0.69,roof),Vector2(-0.94,roof)])
	_prism(parent,cabin,1.68,materials.paint)
	_windows(parent,PackedVector2Array([Vector2(-1.3,1.18),Vector2(1.08,1.18),Vector2(0.64,roof-0.065),Vector2(-0.88,roof-0.065)]),1.69,[-0.15])
	_rack(parent,roof+0.06,1.55,-0.15)

func _van(parent: Node3D,long_body: bool) -> void:
	var rear = -2.18 if long_body else -1.91
	_prism(parent,PackedVector2Array([Vector2(rear,0.68),Vector2(2.17,0.68),Vector2(2.17,1.32),Vector2(1.92,2.02),Vector2(rear,2.02)]),1.94,materials.paint)
	for side in [-1.0,1.0]:
		for z in ([-1.55,-0.58,0.39,1.32] if long_body else [-1.24,-0.1,1.1]):
			_box(parent,Vector3(side*0.976,1.59,z),Vector3(0.018,0.49,0.75),materials.glass,"SideWindow")
		_box(parent,Vector3(side*0.99,1.17,0.85),Vector3(0.02,0.04,0.18),materials.chrome,"DoorHandle")
	_panel(parent,[Vector3(-0.84,1.4,2.15),Vector3(0.84,1.4,2.15),Vector3(0.84,1.94,1.95),Vector3(-0.84,1.94,1.95)],materials.glass)
	_box(parent,Vector3(0,1.6,rear-0.012),Vector3(1.62,0.5,0.02),materials.glass,"RearWindow")
	_rack(parent,2.08,3.1 if long_body else 2.6,-0.1)

func _pickup(parent: Node3D) -> void:
	_box(parent,Vector3(0,0.83,0),Vector3(1.94,0.35,4.3),materials.paint)
	_prism(parent,PackedVector2Array([Vector2(-0.2,1.0),Vector2(1.2,1.0),Vector2(0.99,1.82),Vector2(-0.2,1.82)]),1.82,materials.paint)
	_windows(parent,PackedVector2Array([Vector2(-0.12,1.24),Vector2(1.05,1.24),Vector2(0.93,1.73),Vector2(-0.12,1.73)]),1.83,[0.1])
	for x in [-0.91,0.91]: _box(parent,Vector3(x,1.14,-1.24),Vector3(0.12,0.49,1.86),materials.paint,"BedSide")
	_box(parent,Vector3(0,1.14,-2.12),Vector3(1.88,0.49,0.1),materials.paint,"Tailgate")
	_box(parent,Vector3(0,1.19,-1.27),Vector3(1.15,0.56,1.12),materials.canvas,"BedSupplies")
	_rack(parent,1.87,1.0,0.4)

func _truck(parent: Node3D) -> void:
	_box(parent,Vector3(0,1.48,-0.8),Vector3(1.96,1.51,2.76),materials.paint,"CargoBox")
	_prism(parent,PackedVector2Array([Vector2(0.65,0.75),Vector2(2.16,0.75),Vector2(2.13,1.13),Vector2(1.53,1.2),Vector2(1.39,1.91),Vector2(0.65,1.91)]),1.9,materials.paint)
	for side in [-1.0,1.0]:
		_box(parent,Vector3(side*0.958,1.59,1.08),Vector3(0.018,0.47,0.61),materials.glass,"CabWindow")
		for z in [-2.03,-1.42,-0.8,-0.18,0.49]:
			_box(parent,Vector3(side*0.991,1.49,z),Vector3(0.025,1.34,0.035),materials.steel,"CargoRib")
	_panel(parent,[Vector3(-0.81,1.31,1.51),Vector3(0.81,1.31,1.51),Vector3(0.81,1.82,1.4),Vector3(-0.81,1.82,1.4)],materials.glass)
	for x in [-0.87,0.0,0.87]: _box(parent,Vector3(x,1.49,-2.195),Vector3(0.025,1.38,0.035),materials.steel,"CargoDoorSeam")

func _suv(parent: Node3D) -> void:
	_box(parent,Vector3(0,0.94,0),Vector3(1.94,0.58,4.28),materials.paint)
	_prism(parent,PackedVector2Array([Vector2(-1.92,1.15),Vector2(1.26,1.15),Vector2(0.85,1.97),Vector2(-1.92,1.97)]),1.82,materials.paint)
	_windows(parent,PackedVector2Array([Vector2(-1.8,1.31),Vector2(1.1,1.31),Vector2(0.79,1.88),Vector2(-1.8,1.88)]),1.83,[-1.0,-0.07,0.66])
	_rack(parent,2.04,2.7,-0.5)
	var spare = Node3D.new(); parent.add_child(spare); spare.position = Vector3(0,1.24,-2.25); spare.rotation_degrees.y = 90
	_wheel(spare,Vector3.ZERO,0.39)
