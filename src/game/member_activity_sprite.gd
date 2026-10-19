extends Sprite2D
## A member keeps the Sprite2D interface used by scene lighting and positioning.
## Seated art is anchored at the underside of the pelvis touching the seat,
## never at the canvas center or at a standing character's full-body height.

const LAYOUT = preload("res://src/game/member_activity_layout.gd")
const CHARACTER_ROOT = "res://assets/characters/"
const SEATED = {
	"chenchuan": {"directory":"chen_chuan", "anchor":Vector2(111.64035,340.16319), "sole_x":123.0, "label":"检修电机"},
	"duheng": {"directory":"du_heng", "anchor":Vector2(97.56872,360.43651), "sole_x":125.0, "label":"查看地图"},
	"linyue": {"directory":"lin_yue", "anchor":Vector2(105.96602,347.83599), "sole_x":174.0, "label":"清点绑带"},
	"cenbai": {"directory":"cen_bai", "anchor":Vector2(106.88270,357.61645), "sole_x":140.0, "label":"练习绳结"},
	# Manually annotated on the 340 x 640 frame_0000: pelvis (89,372),
	# near shoe sole (121,625). Unlike the four manifests, this clip has
	# no pre-existing seat-origin prefab; its measured leg height is 253 px.
	"xuning": {"directory":"xu_ning", "animation":"seated_medical_bag", "anchor":Vector2(89,372), "sole_x":121.0, "seat_to_sole_native":253.0, "label":"整理医疗包"},
}

var kind: String = "standing"
var activity_label: String = ""
## Display offsets already include the Sprite2D's current scale and mirror.
var top_offset: Vector2:
	get:
		return _display_point(_top_native)
var sole_offset: Vector2:
	get:
		return _display_point(_sole_native)

var _anchor = Vector2.ZERO
var _top_native = Vector2.ZERO
var _sole_native = Vector2.ZERO
var _frames: SpriteFrames
var _animation: StringName = &""
var _frame_ends = PackedFloat64Array()
var _cycle_seconds = 0.0
var _elapsed = 0.0
var _frame_index = -1
var _source_facing = "left"


func configure(member_id: String, _standing_art_id: String, pose: Dictionary, standing_height: float) -> void:
	set_process(false)
	_frames = null
	_animation = &""
	_frame_ends.clear()
	_cycle_seconds = 0.0
	_elapsed = 0.0
	_frame_index = -1
	_source_facing = "left"
	kind = "standing"
	activity_label = ""
	texture = null
	centered = false
	flip_v = false
	flip_h = false
	region_enabled = false
	hframes = 1
	vframes = 1
	offset = Vector2.ZERO
	scale = Vector2.ONE
	_anchor = Vector2.ZERO
	_top_native = Vector2.ZERO
	_sole_native = Vector2.ZERO
	var requested_kind = str(pose.get("kind","standing"))
	var seated_ready = requested_kind == "seated" and _configure_seated(member_id,pose)
	if not seated_ready:
		var standing_ready = requested_kind == "standing" and _configure_standing(pose,standing_height)
		if not standing_ready:
			# A failed seated action becomes a front standing body. The caller
			# can observe kind and move its origin from the seat to the floor.
			_configure_standing(LAYOUT.front_pose(member_id),standing_height)
	if texture == null:
		return
	var facing = str(pose.get("facing",_source_facing))
	# Front art has no left/right facing and must retain its original anatomy.
	flip_h = _source_facing in ["left","right"] and facing in ["left","right"] and facing != _source_facing
	_update_offset()
	if _frames != null:
		# String.hash is deterministic and does not read or modify global RNG.
		_elapsed = float(posmod(member_id.hash(),104729)) / 104729.0 * _cycle_seconds
		_update_animation_frame()
		set_process(true)


func _configure_seated(member_id: String, pose: Dictionary) -> bool:
	var definition: Dictionary = SEATED.get(member_id,{})
	var custom_art = _configure_custom_art(pose)
	if not custom_art and (pose.has("frames") or pose.has("texture")):
		return false
	var art_pose: Dictionary = pose
	if custom_art:
		# New member poses supply their own anatomical anchor and leg height.
		if not pose.has("anchor") and definition.is_empty():
			return false
	else:
		if definition.is_empty():
			return false
		var animation_name = StringName(definition.get("animation","seated_activity"))
		var path = CHARACTER_ROOT+str(definition.directory)+"/animations/"+str(animation_name)+"/"+str(animation_name)+".tres"
		if not _configure_animation(_frames_from(path),animation_name):
			return false
	if texture == null:
		_frames = null
		return false
	var native_leg_height = float(art_pose.get("seat_to_sole_native",definition.get("seat_to_sole_native",240.0)))
	if native_leg_height <= 0.0:
		_frames = null
		return false
	kind = "seated"
	_source_facing = str(art_pose.get("source_facing","right"))
	activity_label = str(art_pose.get("activity_label",definition.get("label","坐着休息")))
	_anchor = _point(art_pose.get("anchor",definition.get("anchor",Vector2.ZERO)))
	_top_native = _point(art_pose.get("top_anchor",Vector2(texture.get_width()*0.5,0)))
	var sole_x = texture.get_width()*0.5 if custom_art else float(definition.get("sole_x",texture.get_width()*0.5))
	_sole_native = _point(art_pose.get("sole_anchor",Vector2(sole_x,_anchor.y+native_leg_height)))
	var display_scale = maxf(0.001,float(pose.get("seat_to_sole",48.0))) / native_leg_height
	var max_body_height = float(pose.get("max_body_height",0.0))
	var native_body_height = absf(_sole_native.y-_top_native.y)
	if max_body_height > 0.0 and native_body_height > 0.0:
		# A high bed/box must not enlarge the person's entire body. Keep the
		# pelvis on the seat; shoes may then hang above the scene's ground.
		display_scale = minf(display_scale,max_body_height/native_body_height)
	scale = Vector2.ONE * display_scale
	return true


func _configure_standing(pose: Dictionary, standing_height: float) -> bool:
	_frames = null
	texture = null
	if not _configure_custom_art(pose):
		return false
	kind = "standing"
	_source_facing = str(pose.get("source_facing","front"))
	activity_label = str(pose.get("activity_label",""))
	_anchor = _point(pose.get("anchor",Vector2(texture.get_width()*0.5,texture.get_height())))
	_top_native = _point(pose.get("top_anchor",Vector2(texture.get_width()*0.5,0)))
	_sole_native = _point(pose.get("sole_anchor",_anchor))
	# Fixed canvases may contain transparent margins. Scale from the measured
	# body height so front standing fallbacks preserve each member's stature.
	var native_height = maxf(0.001,float(pose.get("height_native",texture.get_height())))
	var height_ratio = float(pose.get("height_ratio",1.0))
	scale = Vector2.ONE * maxf(0.001,standing_height*height_ratio) / native_height
	return true


func _configure_custom_art(pose: Dictionary) -> bool:
	if _configure_animation(_frames_from(pose.get("frames")),StringName(pose.get("animation","activity"))):
		return true
	texture = _texture_from(pose.get("texture"))
	return texture != null


func _configure_animation(frames: SpriteFrames, animation_name: StringName) -> bool:
	_frames = null
	_frame_ends.clear()
	_cycle_seconds = 0.0
	if frames == null or not frames.has_animation(animation_name):
		return false
	var fps = frames.get_animation_speed(animation_name)
	if fps <= 0.0 or frames.get_frame_count(animation_name) == 0:
		return false
	for index in frames.get_frame_count(animation_name):
		if frames.get_frame_texture(animation_name,index) == null:
			_frame_ends.clear()
			_cycle_seconds = 0.0
			return false
		_cycle_seconds += maxf(0.0001,frames.get_frame_duration(animation_name,index)/fps)
		_frame_ends.append(_cycle_seconds)
	_frames = frames
	_animation = animation_name
	texture = _frames.get_frame_texture(_animation,0)
	return true


func _process(delta: float) -> void:
	if _frames == null or _cycle_seconds <= 0.0:
		return
	_elapsed = fposmod(_elapsed+delta,_cycle_seconds)
	_update_animation_frame()


func _update_animation_frame() -> void:
	var next_index = 0
	while next_index < _frame_ends.size()-1 and _elapsed >= _frame_ends[next_index]:
		next_index += 1
	if next_index == _frame_index:
		return
	_frame_index = next_index
	texture = _frames.get_frame_texture(_animation,_frame_index)
	_update_offset()


func _update_offset() -> void:
	# Sprite2D.flip_h flips UVs inside the same drawing rectangle; offset
	# itself is not reflected. Move its left edge so the mirrored anatomical
	# anchor (width - anchor.x) still touches this node's origin.
	offset = Vector2(_anchor.x-texture.get_width() if flip_h else -_anchor.x,-_anchor.y)


func _display_point(point: Vector2) -> Vector2:
	if texture == null:
		return Vector2.ZERO
	var mirrored = Vector2(texture.get_width()-point.x,point.y) if flip_h else point
	return (mirrored+offset)*scale


func _texture_from(value: Variant) -> Texture2D:
	if value is Texture2D:
		return value
	if (value is String or value is StringName) and not str(value).is_empty() and ResourceLoader.exists(str(value)):
		return load(str(value)) as Texture2D
	return null


func _frames_from(value: Variant) -> SpriteFrames:
	if value is SpriteFrames:
		return value
	if (value is String or value is StringName) and not str(value).is_empty() and ResourceLoader.exists(str(value)):
		return load(str(value)) as SpriteFrames
	return null


func _point(value: Variant) -> Vector2:
	if value is Vector2 or value is Vector2i:
		return Vector2(value)
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]),float(value[1]))
	return Vector2.ZERO
