extends SceneTree
const Rules = preload("res://src/game/world_rules.gd")
func _init(): call_deferred("run")
func run():
	var cases = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/final_endings_paths.json"))
	var failures = 0; var steps = 0; var targets = {}
	for witness in cases:
		var r = Rules.new(); r.new_game(int(witness.seed))
		var valid = true
		for entry in witness.commands:
			steps += 1
			if int(r.s.day) != int(entry.day) or r.s.phase != entry.phase or not r.command(entry.action,entry.args):
				print("REPLAY_FAIL ",witness.target," step=",steps," ",entry," ",r.error); valid = false; break
		if valid and r.s.ending == witness.target and r.checkpoint().current == Rules.canonical(witness.final):
			targets[witness.target] = true; print("REPLAY_OK ",witness.target," seed=",witness.seed," day=",r.s.day," commands=",witness.commands.size())
		else: failures += 1; print("REPLAY_FINAL_MISMATCH ",witness.target)
	if targets.size() != 17: failures += 1
	print("FINAL_REPLAY endings=",targets.size()," commands=",steps," failures=",failures)
	quit(failures)
