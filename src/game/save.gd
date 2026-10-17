extends RefCounted
const DEFAULT_DIRECTORY = "user://saves"
var save_directory: String
func _init(directory: String = DEFAULT_DIRECTORY) -> void:
	save_directory = directory
	if OS.has_feature("editor") and directory.begins_with("user://"):
		save_directory = "res://.godot/player_saves/"+directory.trim_prefix("user://").replace("/","_")

func save_payload(payload: Dictionary) -> bool:
	var absolute = ProjectSettings.globalize_path(save_directory)
	var mkdir_error = DirAccess.make_dir_recursive_absolute(absolute)
	if mkdir_error != OK:
		push_error("Save directory: %s error=%d" % [absolute,mkdir_error]); return false
	var path = absolute.path_join("final_autosave.json")
	var json = JSON.stringify(payload)
	var file = FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file == null:
		push_error("Cannot write %s code=%d directory_exists=%s" % [path+".tmp",FileAccess.get_open_error(),DirAccess.dir_exists_absolute(absolute)]); return false
	file.store_string(JSON.stringify({"payload":json,"sha256":json.sha256_text()})); file.flush(); file.close()
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(path+".bak"): DirAccess.remove_absolute(path+".bak")
		if DirAccess.rename_absolute(path,path+".bak") != OK: return false
	return DirAccess.rename_absolute(path+".tmp",path) == OK

func load_from_file(_slot: String = "slot_1") -> Dictionary:
	for suffix in ["",".bak"]:
		var file = FileAccess.open(save_directory.path_join("final_autosave.json")+suffix,FileAccess.READ)
		if file == null: continue
		var wrapper = JSON.parse_string(file.get_as_text())
		if wrapper is Dictionary and wrapper.get("payload") is String and wrapper.get("sha256","") == str(wrapper.payload).sha256_text():
			var data = JSON.parse_string(wrapper.payload)
			if data is Dictionary and data.get("schema",0) == 1: return data
	return {}
