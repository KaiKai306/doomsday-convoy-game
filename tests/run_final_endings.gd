extends SceneTree
const Rules = preload("res://src/game/world_rules.gd")
var failures = 0
var paths = []
var driver = preload("res://tests/final_route_pilot.gd").new()
func _init(): call_deferred("run")
func run():
	for index in range(1,18):
		var target = "E%02d" % index
		if not OS.get_cmdline_user_args().is_empty() and target not in OS.get_cmdline_user_args(): continue
		var won = false
		var last = {}
		var max_observations = 0
		var seen_crises = {}
		var candidates = []
		if target in ["E13","E15","E16"]: candidates.append({"E13":1299,"E15":7,"E16":18}[target])
		for candidate in range(1,3001 if target in ["E13","E15"] else (151 if target == "E16" else 31)):
			if candidate not in candidates: candidates.append(candidate)
		for seed_value in candidates:
			var r = Rules.new(); r.new_game(seed_value); driver.commands = []
			var steps = 0
			while r.s.ending == "" and steps < 550:
				steps += 1
				if seed_value % 100 == 0 and steps == 1: print("SEARCH ",target," seed=",seed_value," observations=",max_observations," third_events=",seen_crises.get("N-X02",0))
				max_observations = maxi(max_observations,int(r.s.observations))
				if r.s.phase == "event": seen_crises[r.s.daily.card] = int(seen_crises.get(r.s.daily.card,0))+1
				if not driver.pilot(r,target): break
			last = {"ending":r.s.ending,"day":r.s.day,"phase":r.s.phase,"error":r.error,"stock":r.s.resources,"people":r.people().map(func(m): return [m.id,m.health,m.trust,m.like]),"legs":r.s.legs,"knowledge":r.s.knowledge,"observations":r.s.observations,"trades":r.s.trades,"tracking":r.s.tracking}
			if r.s.ending == target:
				paths.append({"target":target,"seed":seed_value,"commands":driver.commands.duplicate(true),"history":r.s.history.duplicate(true),"final":r.s.duplicate(true)})
				print("LEGAL_ENDING ",target," seed=",seed_value," day=",r.s.day," commands=",driver.commands.size())
				var witness = FileAccess.open("res://.godot/witness_"+target+".json",FileAccess.WRITE); witness.store_string(JSON.stringify(paths.back())); witness.close()
				won = true; break
		if not won: failures += 1; print("MISSING_PATH ",target," ",last," max_observations=",max_observations," events=",seen_crises)
		await process_frame
	var f = FileAccess.open("res://.godot/final_endings_paths.json",FileAccess.WRITE); f.store_string(JSON.stringify(paths)); f.close()
	print("FULL_ENDINGS paths=",paths.size()," failures=",failures)
	quit(failures)

