extends SceneTree
const Rules = preload("res://src/game/world_rules.gd")
const Save = preload("res://src/game/save.gd")
var checks = 0
var failures = 0
func check(value: bool, label: String) -> void:
 checks += 1
 if not value: failures += 1; print("FAIL ",label)
func _init() -> void:
 call_deferred("run")
func run() -> void:
 var r = Rules.new(); r.new_game(81420)
 check(r.content.cards.size() == 109,"109 manuscript cards")
 check(r.content.modules.size() == 30,"30 modules")
 check(r.content.locations.size() == 15,"15 physical locations")
 check(r.content.endings.size() == 17 and r.content.epilogues.size() == 6,"17 endings and six epilogues")
 check(r.people().size() == 5 and r.s.resources.water == 50 and r.s.resources.food == 45 and r.s.resources.fuel == 80,"exact starting stock")
 check(r.person("zhang").repair == 70 and r.person("elin").medical == 75 and r.person("ajie").scout == 65,"actual starting roles")
 check(r.weight() > 150 and r.weight() < 175,"cargo includes fuel books notebook rituals")
 for p in [0,100]:
  var state_before = r.rng.state
  check(r.chance(p) == (p == 100) and r.rng.state == state_before,"0/100 without RNG")
 var before = r.checkpoint()
 check(not r.command("prepare",{"id":"bad"}) and r.s == before.current,"invalid commands atomic")
 check(r.command("prepare",{"id":"water"}) and r.s.resources.water == 48 and r.person("zhang").trust == 57,"water preparation changes individual trust")
 before = r.checkpoint()
 check(not r.command("prepare",{"id":"repair"}) and r.s == before.current,"one preparation")
 check(r.command("finish_prepare"),"route phase")
 var quote = r.route_quote("resource","quiet")
 check(quote.fuel == 10 and quote.wear == 3 and quote.hours == 8 and quote.fatigue == 6,"exact quiet resource route")
 before = r.checkpoint()
 r.s.resources.fuel = 1
 var low = r.checkpoint()
 check(not r.command("depart",{"route":"resource","style":"quiet","supply":"water"}) and r.s == low.current,"insufficient cost rollback")
 r.restore(before)
 check(r.command("depart",{"route":"resource","style":"quiet","supply":"water"}),"real travel command")
 if r.s.phase == "event":
  for option in [0,3,1,2,4]:
   if r.command("card",{"id":r.s.daily.card,"option":option}): break
 check(r.s.phase == "stop" and r.s.legs == 1,"arrival advances one real edge")
 check(r.command("begin_camp"),"camp stage")
 check(r.command("camp",{"id":"rest"}),"one camp action or event")
 if r.s.phase == "camp_event":
  for option in [0,1,2,3]:
   if r.command("card",{"id":r.s.daily.card,"option":option}): break
 check(r.command("settle"),"night settlement")
 before = r.checkpoint()
 check(not r.command("settle") and r.s == before.current,"no duplicate rations")
 var saved = r.checkpoint(); var restored = Rules.new()
 check(restored.restore(saved) and restored.checkpoint() == saved,"complete current plus dawn snapshot roundtrip")
 var save = Save.new("user://final_test_saves")
 var disk_saved = save.save_payload(saved)
 check(disk_saved and restored.restore(save.load_from_file()),"atomic disk save checksum")
 check(r.command("retry") and r.s.day == 1 and r.s.resources.water == 50 and r.s.daily.prepared == false,"retry undoes all current-day costs")
 # Explicit boundary snapshots below are not counted as full runs.
 r.new_game(5); r.s.day = 10; r.s.phase = "rescue"; r.s.legs = 6; r.s.clues = ["frequency","coordinates","entrance"]; r.s.south_pledge = true
 check(r.rescue_missing().is_empty(),"legal rescue gates")
 var fuel_before = r.s.resources.fuel; var health_before = r.car().durability
 check(r.command("rescue",{"id":"quiet"}) and r.living("sister"),"rescue certain success")
 check(r.s.resources.fuel == fuel_before-12 and r.car().durability == health_before-8,"dedicated rescue fee replaces route fee")
 check(r.person("elin").fatigue == 26 and r.person("ajie").fatigue == 26,"participant plus base fatigue once")
 r.new_game(6); r.s.phase = "stop"; r.s.day = 4
 check(r.command("recruit",{"id":"chenchuan"}) and r.person("chenchuan").group == "A","recruit group A")
 before = r.checkpoint()
 check(not r.command("recruit",{"id":"xuning"}) and r.s == before.current,"permanent mutual exclusion same day")
 r.new_game(7); r.s.phase = "camp"; r.s.daily.camp_checked = true
 check(r.command("camp",{"id":"read","role":"repair","target":"captain"}) and r.person("captain").understanding.repair == 25 and r.person("captain").repair == 35,"reading exact understanding without ability")
 r.new_game(8); r.s.phase = "camp"; r.s.daily.camp_checked = true; r.person("captain").repair = 45; r.person("captain").understanding.repair = 50
 check(r.command("camp",{"id":"self_study","role":"repair","target":"captain"}) and r.person("captain").repair == 60 and r.s.resources.parts == 23,"one-time self-study")
 r.new_game(9); r.s.phase = "camp"; r.s.daily.camp_used = true; r.s.resources.water = 0; r.s.resources.food = 0
 check(r.command("settle") and r.s.ending == "" and r.person("captain").health == 67,"empty stock hurts each person, not instant game over")
 r.new_game(10); r.all_change("health",-100); r._check_deaths(true)
 check(r.s.ending == "E01","batch all deaths precede captain death")
 r.new_game(11); r.s.knowledge = 50; r.s.stored_copy = true; r.all_change("health",-100); r._check_deaths(true)
 check(r.s.ending == "E14","readable recoverable legacy")
 r.new_game(12); r.change(r.person("captain"),"health",-100); r._check_deaths(true)
 check(r.s.ending == "E16","sudden captain death")
 r.new_game(13); r.s.day = 20; r.s.phase = "camp"; r.s.daily.camp_used = true
 check(r.command("settle") and r.s.ending == "E09" and not r.command("next"),"day20 no day21")
 r.new_game(14); r.s.phase = "stop"; r.s.day = 12; r.s.legs = 8; r.s.trades = 4; r.s.contacts = ["guild"]
 check(r.command("goal",{"id":"E06"}) and r.s.ending == "" and r.s.intent == "E06","goal intent not instant ending")
 r.s.phase = "camp"; r.s.daily.camp_used = true
 check(r.command("settle") and r.s.ending == "E06","goal after actual night")
 var ui = load("res://scenes/release_game.tscn").instantiate(); root.add_child(ui)
 ui.save_system = Save.new("user://final_ui_test_saves")
 check(ui.setup(null,{}),"Godot playable scene setup")
 ui.queue_free(); await process_frame
 print("FINAL_RULES_TEST checks=",checks," failures=",failures)
 quit(1 if failures > 0 else 0)

