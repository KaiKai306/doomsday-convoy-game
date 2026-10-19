extends RefCounted
## Furniture belongs to a location; a character's animation and identity do not.
## Explicit source-space anchors follow the same transform as the painted mid layer.
const DATA = preload("res://data/member_activities.json")
const FRONT_ROOT = "res://assets/characters/front_standing_20261017/"
const FRONT_MANIFEST = preload("res://assets/characters/front_standing_20261017/manifest.json")

## The same fallback is used before placement and after an unavailable action.
## Never substitute a sideways activity drawing for a front standing body.
static func front_pose(member_id: String) -> Dictionary:
	var pose: Dictionary = FRONT_MANIFEST.data.get("characters",{}).get(member_id,{}).duplicate(true)
	pose.kind = "standing"
	pose.source_facing = "front"
	pose.facing = "front"
	pose.activity_label = ""
	pose.texture = pose.get("texture",FRONT_ROOT+member_id+".png")
	return pose

static func spawn_x(location: String, source_width: float, fallback: float, variant: String = "atlas") -> float:
	var scene = _compatible_scene(location,source_width,variant)
	if not scene.has("player_spawn_x"): return fallback
	return float(scene.player_spawn_x)+(source_width-float(scene.get("source_width",source_width)))*0.5

static func _compatible_scene(location: String, source_width: float, variant: String = "atlas") -> Dictionary:
	var scenes: Dictionary = DATA.data.get("legacy_scenes",{}) if variant == "legacy" else {}
	var scene: Dictionary = scenes.get(location,DATA.data.get("scenes",{}).get(location,{}))
	if not scene.has("source_width"):
		return {}
	if not is_equal_approx(float(scene.source_width),source_width) and scene.get("coordinate_policy","exact") != "preserved_center":
		# A different source image may depict different furniture. Only an
		# explicitly compatible padded canvas may reuse the original anchors.
		return {}
	return scene

static func arrange(members: Array, location: String, source_width: float, variant: String = "atlas") -> Dictionary:
	var data: Dictionary = DATA.data
	var scene = _compatible_scene(location,source_width,variant)
	var offset_x = (source_width-float(scene.get("source_width",source_width)))*0.5
	var seats: Array = scene.get("seats",[])
	var taken: Array = []
	var result: Dictionary = {}
	# Stable IDs keep a reordering of the rules roster from shuffling the seats.
	var ordered: Array = members.duplicate()
	ordered.sort_custom(func(a,b):
		var a_priority = int(scene.get("members",{}).get(str(a.id),{}).get("seat_priority",10))
		var b_priority = int(scene.get("members",{}).get(str(b.id),{}).get("seat_priority",10))
		return str(a.id)<str(b.id) if a_priority==b_priority else a_priority<b_priority)
	for member in ordered:
		var id = str(member.id)
		var character: Dictionary = data.get("characters",{}).get(id,{})
		var placement: Dictionary = scene.get("members",{}).get(id,{}).duplicate(true)
		var pose: Dictionary = front_pose(id)
		# An activity belongs to this member at this location. Character-level
		# art and the presence of furniture alone never select an activity.
		var activity: Dictionary = placement.get("activity",{})
		var activity_kind = str(activity.get("kind",""))
		var selected: Dictionary = {}
		if activity_kind == "seated":
			var preference: Array = placement.get("preferred_seats",[])
			for wanted in preference:
				for seat in seats:
					if seat.id == wanted and not taken.has(wanted) and seat.has("point") and seat.has("floor_y"):
						selected = seat
						break
				if not selected.is_empty(): break
		if not selected.is_empty():
			taken.append(selected.id)
			placement.point = selected.point.duplicate()
			placement.floor_y = float(selected.floor_y)
			placement.seat_id = str(selected.id)
			pose = character.get(str(activity.get("art","seated_art")),{}).duplicate(true)
			pose.kind = "seated"
			pose.facing = selected.get("facing",placement.get("facing",character.get("facing","right")))
			pose.activity_label = pose.get("activity_label",character.get("label",""))
		elif activity_kind == "standing":
			var art: Dictionary = character.get(str(activity.get("art","standing_art")),{})
			if not art.is_empty():
				pose = art.duplicate(true)
				pose.kind = "standing"
				pose.facing = placement.get("facing",pose.get("source_facing",character.get("facing","front")))
				pose.activity_label = pose.get("activity_label",character.get("standing_label",""))
		if not activity.is_empty() and placement.has("action_label"):
			pose.activity_label = str(placement.action_label)
		if placement.has("point"):
			placement.point[0] = float(placement.point[0])+offset_x
		placement.pose = pose
		result[id] = placement
	return result
