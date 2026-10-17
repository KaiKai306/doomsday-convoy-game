extends Control
var kind = "book"
var ink = Color("e5edf2")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func line(a: Vector2, b: Vector2, width: float = 3.0) -> void:
	draw_line(a,b,ink,width,true)

func _draw() -> void:
	draw_set_transform(size*0.5,0,Vector2.ONE*minf(size.x,size.y)/64.0)
	match kind:
		"book":
			for side in [-1,1]:
				var poly = PackedVector2Array([Vector2(0,-18),Vector2(side*12,-22),Vector2(side*25,-20),Vector2(side*25,20),Vector2(side*12,18),Vector2(0,23)])
				var path = poly.duplicate(); path.append(poly[0]); draw_polyline(path,ink,3,true)
			line(Vector2(0,-18),Vector2(0,23))
		"teach":
			draw_rect(Rect2(-1,-23,29,33),ink,false,3)
			draw_circle(Vector2(-19,-15),6,ink)
			line(Vector2(-19,-3),Vector2(-19,22),6)
			line(Vector2(-19,0),Vector2(7,-10),4)
			line(Vector2(-19,7),Vector2(-29,15),4)
			line(Vector2(13,10),Vector2(5,25)); line(Vector2(13,10),Vector2(24,25))
		"repair":
			line(Vector2(-20,21),Vector2(16,-15),8)
			draw_arc(Vector2(17,-17),11,-0.1,PI*1.52,26,ink,5,true)
			line(Vector2(-21,-20),Vector2(20,20),5)
			line(Vector2(-24,-17),Vector2(-16,-25),7)
		"trade":
			line(Vector2(-25,-10),Vector2(22,-10),5)
			line(Vector2(22,-10),Vector2(10,-21),5); line(Vector2(22,-10),Vector2(10,1),5)
			line(Vector2(25,12),Vector2(-22,12),5)
			line(Vector2(-22,12),Vector2(-10,1),5); line(Vector2(-22,12),Vector2(-10,23),5)
		"supplies":
			draw_style_box(_box(),Rect2(-20,-15,40,41))
			draw_arc(Vector2(0,-15),10,PI,TAU,20,ink,3,true)
			draw_rect(Rect2(-12,5,24,14),ink,false,2)
		"rest":
			line(Vector2(-26,-6),Vector2(-26,24),4); line(Vector2(25,1),Vector2(25,24),4)
			line(Vector2(-26,16),Vector2(25,16),5); line(Vector2(-12,2),Vector2(24,2),9)
			draw_circle(Vector2(-16,3),6,ink)
			draw_string(ThemeDB.fallback_font,Vector2(8,-12),"z",HORIZONTAL_ALIGNMENT_LEFT,-1,18,ink)
		"talk":
			draw_style_box(_box(),Rect2(-24,-20,48,33))
			draw_colored_polygon(PackedVector2Array([Vector2(-10,9),Vector2(-13,24),Vector2(4,10)]),ink)
			for x in [-12,0,12]: draw_circle(Vector2(x,-3),3,Color("152330"))
		"handshake":
			line(Vector2(-29,-8),Vector2(-12,10),10); line(Vector2(29,-8),Vector2(10,13),10)
			line(Vector2(-12,-5),Vector2(2,-11),6); line(Vector2(2,-11),Vector2(18,5),6)
			for i in 3: line(Vector2(-9+i*7,6+i*3),Vector2(-3+i*7,13+i*3),4)
	draw_set_transform(Vector2.ZERO)

func _box() -> StyleBoxFlat:
	var box = StyleBoxFlat.new(); box.bg_color = ink; box.set_corner_radius_all(5); return box
