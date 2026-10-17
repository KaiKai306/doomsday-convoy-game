extends Control
var kind = "parts"
var ink = Color("d3d8d7")
func _ready() -> void: mouse_filter = Control.MOUSE_FILTER_IGNORE
func line(a: Vector2,b: Vector2,w: float = 2.0) -> void: draw_line(a,b,ink,w,true)
func _draw() -> void:
	draw_set_transform(size*0.5,0,Vector2.ONE*minf(size.x,size.y)/64.0)
	match kind:
		"parts","engine","repair":
			draw_arc(Vector2.ZERO,15,0,TAU,32,ink,5,true); draw_arc(Vector2.ZERO,5,0,TAU,24,ink,2,true)
			for i in 8:
				var d = Vector2.from_angle(i*TAU/8); line(d*16,d*25,7)
		"water","fuel":
			if kind == "water":
				var p = PackedVector2Array([Vector2(0,-26),Vector2(-16,0),Vector2(-17,14),Vector2(-8,24),Vector2(8,24),Vector2(17,14),Vector2(16,0),Vector2(0,-26)])
				draw_polyline(p,ink,3,true); draw_arc(Vector2(0,10),10,0,PI,20,ink,2,true)
			else:
				draw_rect(Rect2(-17,-21,34,45),ink,false,3); draw_rect(Rect2(-8,-28,17,8),ink,false,2)
				line(Vector2(-11,-12),Vector2(11,14)); line(Vector2(11,-12),Vector2(-11,14))
		"medicine":
			draw_rect(Rect2(-19,-22,38,45),ink,false,2); line(Vector2(-12,1),Vector2(12,1),7); line(Vector2(0,-11),Vector2(0,13),7)
		"food","rear","supplies":
			var p = PackedVector2Array([Vector2(-24,-12),Vector2(0,-24),Vector2(24,-12),Vector2(24,17),Vector2(0,29),Vector2(-24,17),Vector2(-24,-12),Vector2(0,0),Vector2(24,-12)])
			draw_polyline(p,ink,2,true); line(Vector2(0,0),Vector2(0,29)); line(Vector2(-12,-18),Vector2(12,-6))
		"wheels":
			draw_arc(Vector2.ZERO,23,0,TAU,40,ink,5,true); draw_arc(Vector2.ZERO,11,0,TAU,32,ink,3,true)
			for i in 8:
				var d = Vector2.from_angle(i*TAU/8); line(d*17,d*25,3)
		"roof","front":
			draw_rect(Rect2(-27,-13,54,29),ink,false,3)
			for x in [-18,-6,6,18]: line(Vector2(x,-11),Vector2(x,13))
			line(Vector2(-23,16),Vector2(-23,25),3); line(Vector2(23,16),Vector2(23,25),3)
		"vehicle":
			var p = PackedVector2Array([Vector2(-28,10),Vector2(-26,-7),Vector2(-12,-11),Vector2(-5,-23),Vector2(13,-23),Vector2(22,-7),Vector2(29,-2),Vector2(29,12),Vector2(-28,12)])
			draw_polyline(p,ink,3,true); draw_circle(Vector2(-16,14),7,ink); draw_circle(Vector2(17,14),7,ink)
		_:
			draw_arc(Vector2.ZERO,21,0,TAU,32,ink,2,true); line(Vector2(-12,0),Vector2(12,0)); line(Vector2(0,-12),Vector2(0,12))
	draw_set_transform(Vector2.ZERO)
