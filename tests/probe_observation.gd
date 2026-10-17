extends SceneTree
func _init(): call_deferred("run")
func run():
	for seed_value in range(1,101):
		var r = load("res://src/game/world_rules.gd").new(); r.new_game(seed_value)
		var driver = load("res://tests/final_route_pilot.gd").new()
		var steps = 0; var last_obs = 0
		while r.s.ending == "" and steps < 350:
			steps += 1
			if r.s.observations != last_obs:
				print("OBS ",seed_value," day=",r.s.day," count=",r.s.observations," obey=",r.s.obey," hist=",r.s.card_history.get("N-X02",{})); last_obs = r.s.observations
			if r.s.observations >= 2 and r.s.phase == "route": print("THIRD ",seed_value," d=",r.s.day," qualified=",r._eligible("N-X02")," last=",r.s.last_observation)
			if not driver.pilot(r,"E13"): break
		if seed_value < 5 or r.s.observations > 0: print("RESULT ",seed_value," ",r.s.ending," d",r.s.day," ",r.s.phase," ",r.error," hp=",r.person("captain").health," dur=",r.car().get("durability",0))
	quit()
