class_name ConvoyArwesFrame
extends Control

# Godot port of ARWES Kranox/Nefrex geometry. See third_party/arwes/LICENSE.
enum Shape { KRANOX, NEFREX, RAIL }
var shape := Shape.NEFREX
var fill := Color(0.024, 0.045, 0.065, 0.45)
var line := Color("#bb8855")
var active := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 2 or h < 2: return
	if shape == Shape.RAIL:
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w - 12, 0), Vector2(w, 12), Vector2(w, h), Vector2(0, h)]), PackedColorArray([fill]))
		draw_line(Vector2(0, 0), Vector2(0, h), line, 3 if active else 1, true)
		draw_line(Vector2(0, h), Vector2(w - 18, h), Color(line, 0.35), 1, true)
		if active:
			draw_line(Vector2(0, 1), Vector2(w - 14, 1), Color(line, 0.65), 1, true)
			for i in range(3): draw_line(Vector2(w - 16 - i * 5, h - 12), Vector2(w - 12 - i * 5, h - 16), line, 1, true)
		return
	var ss := 7.0 if shape == Shape.NEFREX else 10.0
	var sw := 1.0
	var p := 2.0
	if shape == Shape.NEFREX:
		# Nefrex defaults: chamfer at left-top and right-bottom, independent fill.
		var points := PackedVector2Array([Vector2(p, p + ss), Vector2(p + ss, p), Vector2(w - p, p), Vector2(w - p, h - p - ss), Vector2(w - p - ss, h - p), Vector2(p, h - p)])
		draw_polygon(points, PackedColorArray([fill]))
		draw_polyline(PackedVector2Array([Vector2(p, p + ss + 12), Vector2(p, p + ss), Vector2(p + ss, p), Vector2(minf(w - p, 65), p)]), line, sw, true)
		draw_polyline(PackedVector2Array([Vector2(w - p, h - p - ss - 12), Vector2(w - p, h - p - ss), Vector2(w - p - ss, h - p), Vector2(maxf(p, w - 65), h - p)]), line, sw, true)
		draw_line(Vector2(17, h - p), Vector2(w - 70, h - p), Color(line, 0.22), 1, true)
		draw_line(Vector2(70, p), Vector2(w - 17, p), Color(line, 0.22), 1, true)
	else:
		# Kranox background path, ported from createFrameKranoxSettings.ts.
		var sll := 12.0
		var lll := 38.0
		var points := PackedVector2Array([
			Vector2(p + ss * 2, h - p - sw * 2), Vector2(p + ss, h - p - sw * 2 - ss),
			Vector2(p + ss, p + sw * 2 + lll + ss * 3 + sll), Vector2(p, p + sw * 2 + lll + ss * 2 + sll),
			Vector2(p, p + sw * 2 + ss * 2 + sll), Vector2(p + ss, p + sw * 2 + sll + ss),
			Vector2(p + ss, p + sw + ss), Vector2(p + ss * 2 - sw, p + sw * 2),
			Vector2(w - p - ss * 2, p + sw * 2), Vector2(w - p - ss, p + sw * 2 + ss),
			Vector2(w - p - ss, h - p - sw * 2 - ss * 3 - sll - lll), Vector2(w - p, h - p - sw * 2 - ss * 2 - sll - lll),
			Vector2(w - p, h - p - sw * 2 - ss * 2 - sll), Vector2(w - p - ss, h - p - sw * 2 - ss - sll),
			Vector2(w - p - ss, h - p - sw - ss), Vector2(w - p - ss * 2 + sw, h - p - sw * 2)
		])
		draw_polygon(points, PackedColorArray([fill]))
		var outline := points.duplicate()
		outline.append(points[0])
		draw_polyline(outline, Color(line, 0.28), 1, true)
		draw_polyline(PackedVector2Array([Vector2(p + ss - 2, p + ss + sll), Vector2(p + ss - 2, p + ss), Vector2(p + ss * 2 - 2, p), Vector2(p + ss * 2 + 64, p)]), line, 1.5, true)
		draw_polyline(PackedVector2Array([Vector2(w - p - ss + 2, h - p - ss - sll), Vector2(w - p - ss + 2, h - p - ss), Vector2(w - p - ss * 2 + 2, h - p), Vector2(w - p - ss * 2 - 64, h - p)]), line, 1.5, true)
		# Fine scratches remain on the border; the scene behind stays untouched.
		for i in range(16):
			var x := 105.0 + fmod(i * 41.7, maxf(1, w - 160))
			draw_line(Vector2(x, p + 1), Vector2(x + 3, p + 2), Color(line, 0.28), 1)
