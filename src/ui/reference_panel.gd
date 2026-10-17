extends Control
## Small clipped corners and hairline frames from the supplied interface atlas.
var fill = Color(0.025,0.045,0.065,0.92)
var ink = Color(0.72,0.79,0.83,0.7)
var accent = Color(0.46,0.72,0.9,0.0)
var cut = 10.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var c = minf(cut,minf(size.x,size.y)*0.25)
	var points = PackedVector2Array([Vector2(c,1),Vector2(size.x-c,1),Vector2(size.x-1,c),Vector2(size.x-1,size.y-c),Vector2(size.x-c,size.y-1),Vector2(c,size.y-1),Vector2(1,size.y-c),Vector2(1,c)])
	draw_colored_polygon(points,fill)
	var outline = points.duplicate(); outline.append(points[0])
	draw_polyline(outline,ink,1.2,true)
	if accent.a > 0:
		draw_line(Vector2(c+10,3),Vector2(size.x-c-10,3),accent,2,true)
		draw_line(Vector2(c+10,size.y-3),Vector2(size.x-c-10,size.y-3),Color(accent,accent.a*0.3),1,true)
