extends SceneTree
const ART = preload("res://src/game/vehicle_art.gd")
const BACKDROP = preload("res://src/game/location_backdrop.gd")
var checks = 0
var failures = 0
func _init(): call_deferred("run")
func check(ok: bool, label: String):
	checks += 1
	if not ok: failures += 1; print("FAIL ",label)
func run():
	var vehicles = [{"name":"老伙计","durability":80},{"name":"商会旧车","durability":50}]
	var before = vehicles.duplicate(true)
	check(ART.model_id(vehicles[0],0)=="V01","primary legacy art identity retained")
	check(ART.model_id(vehicles[1],1)=="V05","secondary legacy art identity retained")
	check(ART.facing(vehicles[1],"camp",1)=="left","independent direction retained in art library")
	for id in ["V01","V02","V03","V04","V05","V06","V07","V08"]:
		for direction in ["left","right"]:
			var car = ART.create({"visual_id":id,"facing":direction,"durability":80},0,0,[120,510,590,350],"camp")
			var body = car.get_node("Body")
			check(body.texture.resource_path.ends_with("%s_%s.png" % [id,direction]),id+direction+" library texture retained")
			var image: Image = body.texture.get_image()
			check(image.get_pixel(0,0).a<0.01 and image.get_pixel(image.get_width()/2,image.get_height()/2).a>0.99,id+direction+" transparency retained")
			check(Rect2(120,510,590,350).grow(2).encloses(car.get_meta("source_rect")),id+direction+" library positioning retained")
			car.free()
	var backdrop = BACKDROP.new(); backdrop.size = Vector2(1280,720); root.add_child(backdrop)
	for location in ART.LIGHTING.data:
		backdrop.display(location,vehicles)
		check(backdrop.vehicle_root.get_child_count()==0,location+" production display contains no vehicles")
		var car = ART.create(vehicles[0],0,0,[120,510,590,350],location)
		var material: ShaderMaterial = car.get_node("Body").material
		var tint: Vector3 = material.get_shader_parameter("ambient_tint")
		check(tint.z>tint.x and material.get_shader_parameter("exposure_stops")<0,location+" reusable library lighting retained")
		car.free()
	backdrop.display("camp",[]); backdrop.display("camp",vehicles)
	check(backdrop.vehicle_root.get_child_count()==0,"refresh cannot restore removed scene cars")
	check(vehicles==before,"scene removal preserves vehicle inventory and durability")
	backdrop.queue_free(); await process_frame
	print("VEHICLE_ART checks=",checks," failures=",failures); quit(failures)
