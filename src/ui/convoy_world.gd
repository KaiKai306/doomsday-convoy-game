class_name ConvoyWorld
extends Control

## Replaceable vector scenery; no design reference image is shipped as art.
var phase: int = 0
var day: int = 1
var progress: float = 0.0
var clock_time: float = 0.0
var moving := false
var paused := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true

func _process(delta: float) -> void:
	if paused: return
	clock_time += delta
	queue_redraw()

func _polygon(points: Array, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array(points), color)

func _draw() -> void:
	var s := size
	if s.x <= 0 or s.y <= 0: return
	draw_set_transform(Vector2.ZERO, 0, s / Vector2(700, 480))
	var night := phase in [GameState.Phase.CAMP_ACTION, GameState.Phase.NIGHT_SETTLEMENT, GameState.Phase.STOP_DIALOGUE, GameState.Phase.ENDING, -1]
	draw_rect(Rect2(0, 0, 700, 480), Color("#0a1425") if night else Color("#263b4b"))
	for i in range(28):
		var p := Vector2(fmod(i * 137.0 + 39, 700), fmod(i * 57.0, 185))
		draw_circle(p, 1.0, Color(0.66, 0.78, 0.84, 0.5 if night else 0.12))
	for i in range(6, 0, -1):
		draw_circle(Vector2(537, 87), 30 + i * 7, Color(0.67, 0.78, 0.83, 0.012))
	draw_circle(Vector2(537, 87), 29, Color("#a1b8be") if night else Color("#d2c2a2"))
	_polygon([Vector2(0, 214), Vector2(76, 166), Vector2(163, 206), Vector2(253, 142), Vector2(340, 203), Vector2(452, 175), Vector2(568, 214), Vector2(700, 163), Vector2(700, 480), Vector2(0, 480)], Color("#1b2b38"))
	_polygon([Vector2(0, 253), Vector2(190, 221), Vector2(315, 254), Vector2(470, 216), Vector2(700, 258), Vector2(700, 480), Vector2(0, 480)], Color("#223442"))
	# Ruined utility buildings and distant towers.
	for i in range(7):
		var x := 43.0 + i * 102
		var h := 18.0 + fmod(i * 23.0, 50.0)
		draw_rect(Rect2(x, 235 - h, 35 + i % 3 * 9, h), Color("#14232e"))
		draw_line(Vector2(x + 9, 238 - h), Vector2(x + 9, 223 - h), Color("#14232e"), 3)
	_landmark()
	_polygon([Vector2(0, 364), Vector2(700, 243), Vector2(700, 333), Vector2(0, 474)], Color("#111e2b"))
	draw_line(Vector2(0, 364), Vector2(700, 243), Color("#4a5660"), 2)
	draw_line(Vector2(0, 474), Vector2(700, 333), Color("#3c4953"), 2)
	for i in range(11):
		var x := fmod(i * 92.0 - (clock_time * 65.0 if moving else 0.0) + 9000, 850) - 75
		draw_line(Vector2(x, 417 - x * 0.19), Vector2(x + 37, 410 - x * 0.19), Color("#b5a27d"), 3)
	if not moving and phase != GameState.Phase.TRAVEL_EVENT:
		_tent(Vector2(125, 296), Color("#61716a"))
		_tent(Vector2(211, 256), Color("#485d65"))
		for i in range(8, 0, -1):
			draw_circle(Vector2(301, 306), i * 10.0, Color(0.96, 0.48, 0.18, 0.018))
		draw_ellipse_shadow(Vector2(301, 313), Vector2(22, 7))
		draw_line(Vector2(289, 314), Vector2(312, 304), Color("#9b7050"), 4)
		draw_line(Vector2(289, 305), Vector2(312, 315), Color("#9b7050"), 4)
		_polygon([Vector2(291, 309), Vector2(300, 283 + sin(clock_time * 7) * 3), Vector2(306, 298), Vector2(313, 309)], Color("#ee9a54"))
		_polygon([Vector2(297, 309), Vector2(301, 295), Vector2(306, 309)], Color("#ffe0a0"))
		for i in range(5):
			_person(Vector2(260 + i * 22, 341 + sin(i * 2.0) * 8), Color("#b7a38a") if i == 0 else Color("#738994"))
	for i in range(20):
		var x := fmod(i * 83.0 + 47, 700)
		var y := 390 + fmod(i * 41.0, 90)
		draw_line(Vector2(x, y), Vector2(x + 4, y - 5), Color("#394853"), 1)
	draw_set_transform(Vector2.ZERO)

func _landmark() -> void:
	match day:
		1:
			draw_line(Vector2(76, 240), Vector2(76, 192), Color("#6c7979"), 4)
			draw_line(Vector2(218, 225), Vector2(218, 179), Color("#6c7979"), 4)
			_polygon([Vector2(57, 190), Vector2(199, 165), Vector2(240, 178), Vector2(94, 206)], Color("#526568"))
			draw_line(Vector2(93, 206), Vector2(240, 178), Color("#b3a282"), 3)
			draw_rect(Rect2(106, 216, 17, 26), Color("#745d50"))
		2:
			draw_circle(Vector2(160, 237), 70, Color("#45535e"))
			draw_circle(Vector2(160, 243), 52, Color("#091421"))
			draw_rect(Rect2(75, 248, 170, 60), Color("#223442"))
		3:
			for x in [125, 190]: draw_line(Vector2(x, 175), Vector2(x, 250), Color("#78898c"), 4)
			draw_line(Vector2(125, 178), Vector2(190, 247), Color("#78898c"), 2)
			draw_line(Vector2(190, 175), Vector2(125, 250), Color("#78898c"), 2)
			draw_rect(Rect2(113, 126, 90, 52), Color("#657a7d"))
			draw_line(Vector2(113, 126), Vector2(203, 126), ConvoyTheme.GOLD, 2)
		4:
			_polygon([Vector2(0, 253), Vector2(190, 221), Vector2(315, 254), Vector2(290, 267), Vector2(100, 246)], Color("#8fa5ae"))
			for i in range(30):
				var p := Vector2(fmod(i * 97.0 - clock_time * 9 + 7000, 700), fmod(i * 61.0 + clock_time * 12, 310))
				draw_circle(p, 1.4, Color("#bfcbd0"))
		5:
			draw_line(Vector2(106, 248), Vector2(106, 143), Color("#89958c"), 4)
			draw_line(Vector2(220, 227), Vector2(220, 123), Color("#89958c"), 4)
			draw_line(Vector2(106, 143), Vector2(220, 123), Color("#89958c"), 5)
			_polygon([Vector2(220, 123), Vector2(261, 133), Vector2(220, 146)], ConvoyTheme.GOLD)

func draw_ellipse_shadow(p: Vector2, extent: Vector2) -> void:
	var factor := size / Vector2(700, 480)
	draw_set_transform(p * factor, 0, extent * factor)
	draw_circle(Vector2.ZERO, 1, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO, 0, size / Vector2(700, 480))

func _tent(p: Vector2, color: Color) -> void:
	_polygon([p + Vector2(-47, 13), p + Vector2(4, -34), p + Vector2(53, -13), p + Vector2(36, 30)], color)
	_polygon([p + Vector2(-47, 13), p + Vector2(4, -34), p + Vector2(6, 21)], color.darkened(0.4))
	draw_line(p + Vector2(4, -34), p + Vector2(36, 30), color.lightened(0.2), 2)

func _person(p: Vector2, color: Color) -> void:
	draw_ellipse_shadow(p + Vector2(0, 13), Vector2(7, 3))
	draw_line(p, p + Vector2(-3, 12), color.darkened(0.3), 3)
	draw_line(p, p + Vector2(4, 12), color.darkened(0.3), 3)
	draw_rect(Rect2(p + Vector2(-5, -10), Vector2(10, 12)), color)
	draw_circle(p + Vector2(0, -15), 4, Color("#d1b99b"))

func _car(p: Vector2, color: Color, lead: bool) -> void:
	var bob := sin(clock_time * 12) if moving else 0.0
	p.y += bob
	draw_ellipse_shadow(p + Vector2(3, 25), Vector2(69, 16))
	for x in [-40, 42]:
		draw_rect(Rect2(p + Vector2(x, 5), Vector2(13, 22)), Color("#090f16"))
		draw_circle(p + Vector2(x + 7, 23), 6, Color("#46505a"))
	_polygon([p + Vector2(-64, -4), p + Vector2(46, -25), p + Vector2(71, -9), p + Vector2(71, 14), p + Vector2(-45, 38), p + Vector2(-64, 20)], color.darkened(0.3))
	_polygon([p + Vector2(-64, -4), p + Vector2(-43, -35), p + Vector2(40, -52), p + Vector2(46, -25)], color.lightened(0.08))
	_polygon([p + Vector2(46, -25), p + Vector2(40, -52), p + Vector2(65, -37), p + Vector2(71, -9)], Color("#91a6a5"))
	draw_line(p + Vector2(-40, -31), p + Vector2(36, -46), Color("#b3ae94"), 2)
	draw_line(p + Vector2(-48, 25), p + Vector2(68, 1), color.lightened(0.3), 2)
	draw_rect(Rect2(p + Vector2(-24, -43), Vector2(25, 9)), Color("#46555b"))
	if lead:
		draw_line(p + Vector2(10, -47), p + Vector2(10, -75), Color("#a3adae"), 2)
		draw_circle(p + Vector2(10, -76), 2, ConvoyTheme.GOLD)
		draw_line(p + Vector2(60, -2), p + Vector2(70, -4), Color("#efc98e"), 4)
