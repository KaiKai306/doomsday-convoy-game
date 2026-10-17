extends SceneTree
const Rules = preload("res://src/game/world_rules.gd")
var failures = 0
var paths = []
func _init(): call_deferred("run")
func run():
 for target in ["E12","E09","E06"]:
  var won = false
  for seed_value in range(1,31):
   var r = Rules.new(); r.new_game(seed_value)
   var steps = 0
   var trace = []
   while r.s.ending == "" and steps < 350:
    steps += 1
    var ok = pilot(r,target)
    trace.append({"day":r.s.day,"phase":r.s.phase,"error":r.error,"resources":r.s.resources.duplicate(),"ok":ok})
    if not ok: break
   if r.s.ending == target:
    paths.append({"target":target,"seed":seed_value,"history":r.s.history,"final":r.s.duplicate(true)})
    print("LEGAL_FULL_RUN ",target," seed=",seed_value," day=",r.s.day," steps=",steps)
    won = true
    break
   if seed_value == 30: print("PATH_FAILED ",target," ending=",r.s.ending," last=",trace.slice(maxi(0,trace.size()-3)))
  if not won: failures += 1
 var f=FileAccess.open("res://.godot/final_full_paths.json",FileAccess.WRITE);f.store_string(JSON.stringify(paths));f.close()
 print("FULL_PATHS ",paths.size()," failures=",failures)
 quit(failures)
func pilot(r,target):
 var s=r.s
 match s.phase:
  "morning":
   if s.daily.prepared:return r.command("finish_prepare")
   var a="repair" if not r.on_foot() and r.car().durability < 58 and s.resources.parts >= 2 else "accounts"
   return r.command("prepare",{"id":a})
  "route":
   if s.day == 2 and "frequency" not in s.clues:return r.command("intel",{"id":"frequency"})
   if s.day == 8 and not s.south_pledge:return r.command("intel",{"id":"south"})
   var supplies=r.supply_types()
   var resource=supplies[0]
   if "water" in supplies and s.resources.water < 18:resource="water"
   elif "food" in supplies and s.resources.food < 18:resource="food"
   elif "fuel" in supplies:resource="fuel"
   elif "parts" in supplies and s.resources.parts < 8:resource="parts"
   elif "food" in supplies:resource="food"
   return r.command("depart",{"route":"stay" if s.resources.fuel < 10 else "resource","style":"quiet","supply":resource})
  "rescue":return r.command("rescue",{"id":"quiet"})
  "rescue_seats":return r.command("rescue_seat",{"id":"leave_sister"})
  "event","camp_event":
   for o in [0,1,2,3,4]:
    if r.command("card",{"id":s.daily.card,"option":o,"target":"captain","teacher":"zhang"}):return true
   return false
  "stop":
   if s.day in [4,7,9] and not s.daily.opportunity_used:return r.command("recruit",{"id":"none"})
   if s.day >= 12 and target != "E09" and s.intent == "" and r.ending_missing(target).is_empty() and s.daily.tasks < 2:return r.command("goal",{"id":target})
   if target == "E06" and s.trades < 4 and s.daily.tasks < 2:
    for faction in s.contacts:
     if "trade_"+faction not in s.daily.used and s.resources.parts >= 3:return r.command("social",{"id":"trade","faction":faction,"offer":2})
   if s.daily.tasks < 2:
    for faction in s.contacts:
     if "trade_"+faction in s.daily.used:continue
     if s.resources.fuel < 12 and s.resources.parts >= 2:return r.command("social",{"id":"trade","faction":faction,"offer":2})
     if s.resources.water < r.people().size()*(3 if s.day == 9 else 2) and s.resources.food >= 4:return r.command("social",{"id":"trade","faction":faction,"offer":1})
     if s.resources.food < r.people().size()*2 and s.resources.fuel >= 15:return r.command("social",{"id":"trade","faction":faction,"offer":0})
   return r.command("begin_camp")
  "camp":
   if s.daily.camp_used:return r.command("settle")
   var supplies=r.supply_types()
   for resource in ["water","food"]:
    if resource in supplies and s.resources[resource] < r.people().size()*2:
     if r.command("camp",{"id":"gather","resource":resource}):return true
   if not r.on_foot() and r.car().durability < 45 and s.resources.parts >= 3:return r.command("camp",{"id":"repair"})
   return r.command("camp",{"id":"rest"})
  "night":return r.command("next")
  "split":return r.command("split",{"id":"mediate"})
 return false


