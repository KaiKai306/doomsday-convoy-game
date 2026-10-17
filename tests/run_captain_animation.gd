extends SceneTree
const Walk = preload("res://src/game/camp_walk.gd")
var checks = 0
var failures = 0
func _init(): call_deferred("run")
func check(ok: bool, label: String):
	checks += 1
	if not ok: failures += 1; print("FAIL ",label)
func capture(walk: Control, label: String):
	if DisplayServer.get_name() == "headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/captain-qa/"+label+".png")
func run():
	root.size = Vector2i(1280,720)
	DirAccess.make_dir_recursive_absolute("res://.godot/captain-qa")
	var walk = Walk.new(); walk.location_id = "abandoned_clinic"
	root.add_child(walk); await process_frame; walk.set_process(false)
	var sprite = walk.captain_sprite
	check(sprite.animation == "idle_right" and not sprite.flip_h,"spawn uses approved right standing pose")
	check(walk.CAPTAIN_WALK.get_frame_count("walk_right") == 42,"all 42 approved frames installed")
	check(walk.CAPTAIN_WALK.get_animation_speed("walk_right") == 24,"24 FPS preserved")
	walk.direction = 1; walk._process(0.2)
	check(walk.is_walking and sprite.animation == "walk_right" and not sprite.flip_h,"moving right starts walk")
	var frame = sprite.frame
	await create_timer(0.15).timeout
	check(sprite.frame != frame,"walk frames advance during actual playback")
	await capture(walk,"walk_right")
	walk.direction = 0; walk.destination = walk.player_x; walk._process(0.02)
	check(not walk.is_walking and sprite.animation == "idle_right","release stops facing right")
	await capture(walk,"idle_right")
	walk.direction = -1; walk._process(0.1)
	check(walk.is_walking and sprite.flip_h,"moving left mirrors approved right walk")
	await capture(walk,"walk_left")
	walk.direction = 0; walk.destination = walk.player_x; walk._process(0.02)
	check(sprite.animation == "idle_left" and not sprite.flip_h,"left stop uses native left pose without double flip")
	await capture(walk,"idle_left")
	walk.destination = walk.player_x+50; walk._process(0.02)
	check(walk.is_walking and not sprite.flip_h,"click destination starts correctly facing walk")
	walk._process(1); walk._process(0.02)
	check(not walk.is_walking,"arrival returns to standing")
	walk.direction = -1; walk._process(30); walk._process(0.02)
	check(not walk.is_walking and sprite.animation == "idle_left","held direction at boundary stands still")
	var foot = walk.backdrop.source_to_view(walk.CATALOG.foot_at(walk.walk_path,walk.backdrop.view_to_source(Vector2(walk.player_x,0)).x))
	check(sprite.position.distance_to(foot)<0.01,"animated feet remain on scene lane after camera motion")
	walk.direction = 1; walk._process(0.1); walk._notification(Control.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	check(not walk.is_walking and sprite.animation == "idle_right","focus loss immediately returns to standing")
	walk.queue_free(); await process_frame
	print("CAPTAIN_ANIMATION checks=",checks," failures=",failures)
	quit(failures)
