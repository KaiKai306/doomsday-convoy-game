extends Control
## A retained real 3D stage in the garage's free area. Placement is page-specific.
const STAGE = preload("res://src/showcase/vehicle_stage_3d.gd")
const MODELS = preload("res://src/showcase/vehicle_preview_models.gd")
const SETTINGS_PATH = "res://data/vehicle_placements/vehicle_management/V05.json"
const DEFAULTS = {"position":[730.0,568.0],"rotation_degrees":0.0,"scale_percent":43.0,"view_elevation_degrees":12.0}
var settings_path = SETTINGS_PATH
var adjustment: Dictionary = DEFAULTS.duplicate(true)
var stage
var extra_height = 0.0
var saved_by_user = false
var vehicle_id = "V05"
var selected_index = -1
var turntable_enabled = true
var turntable_paused = false
var manual_adjustment = false
var rotation_speed_degrees = 6.0
var rotation_offset = 0.0

static func card_model(vehicle: Dictionary,index: int) -> String:
	var id = preload("res://src/game/vehicle_art.gd").model_id(vehicle,index)
	# The user replaced the first garage card's old pickup with V05 on this page.
	return "V05" if index == 0 and not vehicle.has("visual_id") else id

static func has_confirmed_placement(path: String = SETTINGS_PATH) -> bool:
	if not FileAccess.file_exists(path): return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data is Dictionary and data.get("scene_id","") == "vehicle_management" and data.get("vehicle_id","") == "V05" and data.get("user_confirmed",false) == true

func _ready() -> void:
	# The confirmed 85% display extends beyond the old placeholder's rectangle.
	# UI remains above it; never slice the rotating roof or tire contact patches.
	name = "GarageVehicle3D"; mouse_filter = Control.MOUSE_FILTER_IGNORE; clip_contents = false
	load_adjustments()
	stage = STAGE.new(); stage.name = "V05Stage"; add_child(stage)
	apply_adjustments()

func configure(vehicle: Dictionary,extra: float,index: int = 0) -> void:
	extra_height = extra
	position = Vector2(44,337); size = Vector2(1264,247+extra)
	var next_id = card_model(vehicle,index)
	if next_id != vehicle_id or selected_index != index:
		vehicle_id = next_id; selected_index = index; rotation_offset = 0.0
	stage.set_vehicle_model(vehicle_id)
	# Only exterior attachments with a matching representation are shown.
	var fitted: Dictionary = vehicle.get("modules",{})
	stage.set_module("armor",str(fitted.get("front","")) in ["SP05","SP12","SP13"])
	stage.set_module("cargo",str(fitted.get("rear","")) != "")
	stage.set_module("lamps",false)
	apply_adjustments()

func apply_adjustments() -> void:
	if not is_instance_valid(stage) or not stage.ready_ok: return
	var at: Array = adjustment.position
	stage.position = Vector2(float(at[0]),float(at[1])+extra_height*0.5)-position
	stage.scale = Vector2.ONE*float(adjustment.scale_percent)/100.0
	stage.set_angle(float(adjustment.rotation_degrees)+rotation_offset)
	stage.set_view_elevation(float(adjustment.view_elevation_degrees))

func _process(delta: float) -> void:
	if not turntable_enabled or turntable_paused or manual_adjustment or not is_visible_in_tree() or not is_instance_valid(stage) or not stage.ready_ok: return
	rotation_offset = wrapf(rotation_offset+rotation_speed_degrees*delta,0,360)
	# Update every rendered frame; a throttled shadow/body pass makes slow rotation judder.
	stage.set_angle(float(adjustment.rotation_degrees)+rotation_offset)

func set_turntable_enabled(enabled: bool) -> void:
	turntable_enabled = enabled

func set_adjustment(key: String,value: float) -> void:
	rotation_offset = 0.0
	if key == "x": adjustment.position[0] = value
	elif key == "y": adjustment.position[1] = value
	else: adjustment[key] = value
	apply_adjustments()

func reset_adjustments() -> void:
	adjustment = DEFAULTS.duplicate(true); rotation_offset = 0.0; apply_adjustments()

func load_adjustments() -> void:
	if not FileAccess.file_exists(settings_path): return
	var data = JSON.parse_string(FileAccess.get_file_as_string(settings_path))
	if not data is Dictionary or data.get("scene_id","") != "vehicle_management" or data.get("vehicle_id","") != "V05": return
	var at = data.get("position",[])
	if at is Array and at.size() == 2 and _number(at[0]) and _number(at[1]):
		adjustment.position = [clampf(float(at[0]),44,1308),clampf(float(at[1]),337,584)]
	for key in ["rotation_degrees","scale_percent","view_elevation_degrees"]:
		if _number(data.get(key)): adjustment[key] = float(data[key])
	adjustment.rotation_degrees = clampf(adjustment.rotation_degrees,-180,180)
	adjustment.scale_percent = clampf(adjustment.scale_percent,10,85)
	adjustment.view_elevation_degrees = clampf(adjustment.view_elevation_degrees,5,45)
	saved_by_user = true

func _number(value) -> bool:
	return (value is float or value is int) and is_finite(float(value))

func save_adjustments() -> Error:
	var folder = ProjectSettings.globalize_path(settings_path.get_base_dir())
	var result = DirAccess.make_dir_recursive_absolute(folder)
	if result != OK: return result
	var data = adjustment.duplicate(true)
	data.merge({"schema":1,"scene_id":"vehicle_management","vehicle_id":"V05","user_confirmed":false,"coordinate_space":"management_screen.content; Y adds half of extra safe-area height; scale 100% = stage's 1400x1000 render","model":STAGE.MODEL_PATH})
	data.applies_to = "all vehicle previews on vehicle_management only"
	if FileAccess.file_exists(settings_path):
		var previous = JSON.parse_string(FileAccess.get_file_as_string(settings_path))
		if previous is Dictionary and previous.get("user_confirmed",false):
			var unchanged = true
			for key in ["position","rotation_degrees","scale_percent","view_elevation_degrees"]:
				if previous.get(key) != data[key]: unchanged = false
			data.user_confirmed = unchanged
			if unchanged: data.confirmation = previous.get("confirmation","")
	var file = FileAccess.open(settings_path+".tmp",FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data,"\t")); file.flush(); file.close()
	result = DirAccess.rename_absolute(ProjectSettings.globalize_path(settings_path+".tmp"),ProjectSettings.globalize_path(settings_path))
	if result == OK: saved_by_user = true
	return result
