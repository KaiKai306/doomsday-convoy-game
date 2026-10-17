class_name CampKeyedArt
extends Control

const ART := "res://assets/camp/scene_keyed/"
const WORLD_SIZE := Vector2(3168, 1344)
var textures: Dictionary = {}
var composition: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	composition = JSON.parse_string(FileAccess.get_file_as_string(ART + "composition.json"))
	for file in composition.layers:
		textures[file] = load(ART + str(file))
	resized.connect(queue_redraw)
	queue_redraw()

func _draw() -> void:
	if textures.is_empty(): return
	draw_rect(Rect2(Vector2.ZERO, size), Color("#080e16"))
	# Vehicle source layers stay available in the asset library, off stage.
	var factor := minf(size.x / WORLD_SIZE.x, size.y / WORLD_SIZE.y)
	var origin := (size - WORLD_SIZE * factor) * 0.5
	draw_set_transform(origin, 0, Vector2.ONE * factor)
	draw_texture_rect_region(textures["01_bg_sky.png"], Rect2(Vector2.ZERO, WORLD_SIZE), Rect2(0, 0, 2112, 896))
	draw_texture_rect_region(textures["91_L2_mountain.png"], Rect2(0, 0, 3168, 1144), Rect2(0, 200, 3168, 1144))
	draw_texture(textures["95_L3_camp_flat.png"], Vector2.ZERO)
	draw_texture(textures["93_L4_fore.png"], Vector2.ZERO)
	draw_set_transform(Vector2.ZERO)
