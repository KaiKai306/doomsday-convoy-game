extends RefCounted
## Scene/vehicle placement only. Existing 3D showcase and garage files are untouched.
const DIRECTORY = "res://data/vehicle_placements/side_2d/"
const ART_ROOT = "res://assets/vehicles/side_2d_20261017/"
const VEHICLE_IDS = ["V01","V02","V03","V04","V05","V06","V07","V08"]
const COORDINATE_SPACE = "walk_backdrop source canvas before plane padding; position is the wheel-baseline midpoint; scale 100% = native PNG pixels; rotation is 2D in-plane"

static func valid_scene(scene_id: String) -> bool:
	return not scene_id.is_empty() and scene_id.is_valid_identifier()

static func path_for(scene_id: String, vehicle_id: String) -> String:
	if not valid_scene(scene_id) or vehicle_id not in VEHICLE_IDS: return ""
	return DIRECTORY+scene_id+"/"+vehicle_id+".json"

static func defaults(scene_id: String, vehicle_id: String, source_size: Vector2) -> Dictionary:
	var initial = {"camp":[850.0,780.0],"gas_station":[1980.0,955.0],"journey_road":[1344.0,780.0]}
	var position_value: Array = initial.get(scene_id,[source_size.x*0.5,source_size.y*0.7])
	return {"schema":1,"renderer":"side_2d","scene_id":scene_id,"vehicle_id":vehicle_id,
		"coordinate_space":COORDINATE_SPACE,"source_size":[source_size.x,source_size.y],
		"position":position_value.duplicate(),"rotation_degrees":0.0,"scale_percent":32.0,
		"facing":"left","asset_root":ART_ROOT,"user_confirmed":false}

static func number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func valid_record(record: Dictionary, scene_id: String, vehicle_id: String) -> bool:
	if not valid_scene(scene_id) or vehicle_id not in VEHICLE_IDS: return false
	if record.get("renderer","") != "side_2d" or record.get("scene_id","") != scene_id or record.get("vehicle_id","") != vehicle_id: return false
	if record.get("facing","") not in ["left","right"]: return false
	for key in ["position","source_size"]:
		var pair = record.get(key)
		if not pair is Array or pair.size() != 2 or not number(pair[0]) or not number(pair[1]): return false
	if float(record.source_size[0]) <= 0 or float(record.source_size[1]) <= 0: return false
	if not number(record.get("scale_percent")) or not number(record.get("rotation_degrees")): return false
	return float(record.scale_percent) >= 1.0 and float(record.scale_percent) <= 200.0 and absf(float(record.rotation_degrees)) <= 180.0

static func read_record(scene_id: String, vehicle_id: String) -> Dictionary:
	var path = path_for(scene_id,vehicle_id)
	if path.is_empty() or not FileAccess.file_exists(path): return {}
	var value = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not value is Dictionary or not valid_record(value,scene_id,vehicle_id): return {}
	return value.duplicate(true)

static func load_confirmed(scene_id: String, vehicle_id: String, source_size: Vector2) -> Dictionary:
	var record = read_record(scene_id,vehicle_id)
	if record.is_empty() or record.get("user_confirmed",false) != true or record.get("asset_root","") != ART_ROOT: return {}
	var saved_size = Vector2(float(record.source_size[0]),float(record.source_size[1]))
	# A different art canvas requires the user to review its composition again.
	if not saved_size.is_equal_approx(source_size): return {}
	return record

static func save_confirmed(record: Dictionary, art: Dictionary) -> Error:
	# This function is called only by the explicit Save and Apply UI action.
	var scene_id = str(record.get("scene_id","")); var vehicle_id = str(record.get("vehicle_id",""))
	if not valid_record(record,scene_id,vehicle_id): return ERR_INVALID_DATA
	if art.is_empty() or art.get("reference_only",true) or art.get("asset_root","") != ART_ROOT: return ERR_UNAVAILABLE
	if art.get("id","") != vehicle_id or art.get("facing","") != record.facing: return ERR_INVALID_DATA
	var asset_path = str(art.get("path",""))
	if not FileAccess.file_exists(asset_path): return ERR_FILE_NOT_FOUND
	var asset_sha256 = FileAccess.get_sha256(asset_path)
	if asset_sha256.is_empty(): return ERR_FILE_CANT_READ
	var path = path_for(scene_id,vehicle_id)
	if path.is_empty(): return ERR_INVALID_PARAMETER
	var error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	if error != OK: return error
	var saved = record.duplicate(true)
	saved.merge({"schema":1,"renderer":"side_2d","asset_root":ART_ROOT,"coordinate_space":COORDINATE_SPACE,
		"user_confirmed":true,"confirmation":"用户在实际场景2D车辆摆放窗口点击「保存调整并应用」",
		"asset_path":asset_path,"asset_sha256":asset_sha256,"asset_size":art.get("size",[]),
		"asset_ground_y":art.get("ground_y"),"asset_wheel_x":art.get("wheel_x",[]),
		"confirmed_at_unix":Time.get_unix_time_from_system()},true)
	var file = FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(saved,"\t")); file.flush(); file.close()
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(path+".tmp"),ProjectSettings.globalize_path(path))
