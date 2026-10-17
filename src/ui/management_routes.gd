extends Control
## Diagram coordinates are presentation only; distances come from route_quote.
var selected = "resource"
var paths = {
	"safe":[Vector2(300,380),Vector2(410,450),Vector2(590,428),Vector2(730,345),Vector2(870,315)],
	"resource":[Vector2(300,380),Vector2(430,300),Vector2(525,205),Vector2(680,155),Vector2(815,130)],
	"unknown":[Vector2(300,380),Vector2(470,390),Vector2(650,365),Vector2(840,425),Vector2(1015,415)]
}
const COLORS = {"safe":Color("6fc7ed"),"resource":Color("e8a153"),"unknown":Color("e46a61")}
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
	for key in paths:
		var curve = Curve2D.new()
		for p in paths[key]: curve.add_point(p)
		var points = curve.get_baked_points()
		var color = COLORS[key]; color.a = 1.0 if selected == key else 0.4
		draw_polyline(points,Color(0.02,0.03,0.04,0.9),8,true)
		for i in range(1,points.size()):
			if i % 4 < 2: draw_line(points[i-1],points[i],color,3.0 if selected == key else 2.0,true)
		var end = paths[key][-1]
		draw_circle(end,19,Color(color,0.15)); draw_arc(end,20,0,TAU,40,color,2,true)
	var center = Vector2(70,96)
	draw_arc(center,28,0,TAU,48,Color("9ca9ae"),1,true)
	for dir in [Vector2.UP,Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT]:
		draw_line(center-dir*35,center+dir*35,Color(0.7,0.78,0.82,0.6),1,true)
	draw_colored_polygon(PackedVector2Array([center+Vector2(0,-29),center+Vector2(-6,8),center+Vector2(6,8)]),Color("d5b77e"))
	draw_string(ThemeDB.fallback_font,center+Vector2(-5,-41),"N",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("d6dadd"))
