extends RefCounted
## Replay verified commands on a disposable rules instance before applying a preset.
const RULES = preload("res://src/game/world_rules.gd")
const PATHS = "res://data/developer/story_paths.json"
var paths: Array = []
var cache: Dictionary = {}
var error = ""

func _init() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATHS))
	if parsed is Array: paths = parsed

func scenario(day: int,phase: String = "morning",route: String = "E09",ending: bool = false) -> Dictionary:
	error = ""
	var key = "%s:%d:%s:%s" % [route,day,phase,ending]
	if cache.has(key): return cache[key].duplicate(true)
	for path in paths:
		if path.target != route: continue
		var rules = RULES.new(); rules.new_game(int(path.seed))
		for step in path.commands:
			if not ending and int(rules.s.day) == day and rules.s.phase == phase:
				cache[key] = rules.checkpoint(); return cache[key].duplicate(true)
			if int(rules.s.day) != int(step.day) or rules.s.phase != step.phase or not rules.command(str(step.action),step.args):
				error = "剧情预设与当前规则不一致：第%d天 / %s。%s" % [rules.s.day,rules.s.phase,rules.error]; return {}
		if ending and rules.s.ending == route:
			cache[key] = rules.checkpoint(); return cache[key].duplicate(true)
		error = "这条路线没有所选阶段，请选择其他天数或标准行程。"; return {}
	error = "剧情预设文件缺少这条路线。"; return {}

func locations() -> Array:
	var result: Array = []
	var catalog = preload("res://src/game/location_catalog.gd")
	for file in DirAccess.get_files_at("res://scenes"):
		if not file.ends_with("_parallax.tscn"): continue
		var id = file.trim_suffix("_parallax.tscn")
		if id == "camp_three": id = "camp"
		if catalog.config(id).is_empty(): continue
		result.append({"id":id,"title":catalog.config(id).get("title",id)})
	result.sort_custom(func(a,b): return a.id < b.id)
	return result
