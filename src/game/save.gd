extends RefCounted
const DEFAULT_DIRECTORY = "user://saves"
const AUTO_SLOT = "auto"
const MANUAL_SLOT_COUNT = 6
const RULES_PATH = "res://src/game/world_rules.gd"
const PHASE_NAMES = {"morning":"晨间准备","route":"路线选择","event":"途中事件","stop":"停歇事务","camp":"营地行动","camp_event":"营地事件","night":"夜间结算","rescue":"救援现场","rescue_seats":"安置队友","split":"车队协商","ending":"旅程终局"}
var save_directory: String
var last_error = ""
func _init(directory: String = DEFAULT_DIRECTORY) -> void:
	save_directory = directory
	if OS.has_feature("editor") and directory.begins_with("user://"):
		save_directory = "res://.godot/player_saves/"+directory.trim_prefix("user://").replace("/","_")

func valid_slot(slot: String) -> bool:
	return slot == AUTO_SLOT or slot in manual_slots()

func manual_slots() -> Array[String]:
	var slots: Array[String] = []
	for i in MANUAL_SLOT_COUNT: slots.append("slot_%d" % (i+1))
	return slots

func slot_path(slot: String) -> String:
	if not valid_slot(slot): return ""
	return ProjectSettings.globalize_path(save_directory).path_join("final_autosave.json" if slot == AUTO_SLOT else slot+".json")

func save_payload(payload: Dictionary,slot: String = AUTO_SLOT,metadata: Dictionary = {}) -> bool:
	last_error = ""
	if not valid_slot(slot) or not _well_formed(payload):
		last_error = "存档位或进度数据无效。"; return false
	var validator = load(RULES_PATH).new()
	if not validator.restore(payload): last_error = "当前进度无法保存："+validator.error; return false
	var absolute = ProjectSettings.globalize_path(save_directory)
	var mkdir_error = DirAccess.make_dir_recursive_absolute(absolute)
	if mkdir_error != OK:
		last_error = "无法创建存档目录。"; return false
	var path = slot_path(slot)
	var stored = payload.duplicate(true)
	var info: Dictionary = stored.get("save_info",{}).duplicate(true) if stored.get("save_info") is Dictionary else {}
	info.merge(metadata,true)
	info.saved_at = Time.get_unix_time_from_system()
	info.saved_time = Time.get_datetime_string_from_system(false,true).left(16)
	stored.save_info = info
	var json = JSON.stringify(stored)
	var file = FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file == null:
		last_error = "存档写入失败，请检查可用空间。"; return false
	file.store_string(JSON.stringify({"payload":json,"sha256":json.sha256_text()})); file.flush()
	var write_error = file.get_error(); file.close()
	if write_error != OK:
		last_error = "存档未完整写入，原进度仍保留。"; return false
	if FileAccess.file_exists(path):
		if _read_slot(slot).get("recovered",false):
			# Preserve the healthy backup when the primary file is already damaged.
			if DirAccess.remove_absolute(path) != OK: last_error = "无法替换损坏的存档，备份仍保留。"; return false
		else:
			if FileAccess.file_exists(path+".bak") and DirAccess.remove_absolute(path+".bak") != OK:
				last_error = "无法更新存档备份，原进度仍保留。"; return false
			if DirAccess.rename_absolute(path,path+".bak") != OK:
				last_error = "无法替换原存档，原进度仍保留。"; return false
	if DirAccess.rename_absolute(path+".tmp",path) != OK:
		last_error = "存档替换失败，可从备份恢复。"; return false
	return true

func _well_formed(payload: Dictionary) -> bool:
	if payload.get("schema",0) != 1: return false
	for key in ["current","day_start"]:
		if not payload.get(key) is Dictionary: return false
		var state: Dictionary = payload[key]
		for field in ["resources","daily","facts","cores","books"]:
			if not state.get(field) is Dictionary: return false
		for field in ["members","vehicles","clues","history"]:
			if not state.get(field) is Array: return false
		if not state.get("day") is float and not state.get("day") is int: return false
		if not state.get("phase") is String or not state.get("rng") is String: return false
		for member in state.members:
			if not member is Dictionary: return false
			for field in ["health","fatigue","trust","like","repair","medical","scout","logistics"]:
				if not member.get(field) is float and not member.get(field) is int: return false
	return true

func _read_slot(slot: String) -> Dictionary:
	var path = slot_path(slot)
	if path == "": return {}
	for suffix in ["",".bak"]:
		var file = FileAccess.open(path+suffix,FileAccess.READ)
		if file == null: continue
		var parsed = JSON.new()
		if parsed.parse(file.get_as_text()) != OK: continue
		var wrapper = parsed.data
		if wrapper is Dictionary and wrapper.get("payload") is String and wrapper.get("sha256","") == str(wrapper.payload).sha256_text():
			if parsed.parse(wrapper.payload) != OK: continue
			var data = parsed.data
			if data is Dictionary and _well_formed(data):
				var validator = load(RULES_PATH).new()
				if validator.restore(data): return {"payload":data,"recovered":suffix != "","modified":FileAccess.get_modified_time(path+suffix)}
	return {}

func load_from_file(slot: String = AUTO_SLOT) -> Dictionary:
	return _read_slot(slot).get("payload",{})

func slot_info(slot: String) -> Dictionary:
	var entry = _read_slot(slot)
	var exists = FileAccess.file_exists(slot_path(slot)) or FileAccess.file_exists(slot_path(slot)+".bak") if valid_slot(slot) else false
	var result = {"slot":slot,"exists":exists,"usable":not entry.is_empty(),"recovered":entry.get("recovered",false)}
	if entry.is_empty(): return result
	var payload: Dictionary = entry.payload; var state: Dictionary = payload.current
	var info: Dictionary = payload.get("save_info",{}) if payload.get("save_info") is Dictionary else {}
	result.merge(info,true)
	result.day = int(state.day)
	result.title = "第 %02d 天 · %s" % [state.day,info.get("location_title",PHASE_NAMES.get(state.phase,"荒野旅途"))]
	result.phase = PHASE_NAMES.get(state.phase,"荒野旅途")
	result.progress = 100 if state.phase == "ending" else clampi(int((float(state.day)-1.0)/20.0*100.0),0,99)
	result.saved_at = float(info.get("saved_at",entry.modified))
	result.saved_time = info.get("saved_time","旧版存档")
	result.play_seconds = float(info.get("play_seconds",0))
	result.note = str(info.get("note","这段旅途已保存，可继续当时的进度。"))
	return result

func latest_slot() -> String:
	var newest = ""; var timestamp = -1.0
	var slots: Array[String] = [AUTO_SLOT]; slots.append_array(manual_slots())
	for slot in slots:
		var info = slot_info(slot)
		if info.usable and float(info.saved_at) > timestamp:
			newest = slot; timestamp = float(info.saved_at)
	return newest

func delete_slot(slot: String) -> bool:
	last_error = ""
	var path = slot_path(slot)
	if path == "": last_error = "无效的存档位。"; return false
	# Remove the backup first so a deleted save cannot reappear through recovery.
	for suffix in [".bak",".tmp",""]:
		if FileAccess.file_exists(path+suffix) and DirAccess.remove_absolute(path+suffix) != OK:
			last_error = "删除失败，存档文件仍被占用。"; return false
	return true
