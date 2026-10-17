extends Node2D
## Animated paint, embers and soft illumination, attached to the Mid plane.
@export_range(0.0, 2.0) var intensity := 1.0
var elapsed := 0.0
var soft_disc: GradientTexture2D

func _ready() -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color.WHITE)
	gradient.add_point(0.25, Color(1, 1, 1, 0.5))
	gradient.add_point(0.65, Color(1, 1, 1, 0.08))
	gradient.set_color(gradient.get_point_count() - 1, Color(1, 1, 1, 0))
	soft_disc = GradientTexture2D.new()
	soft_disc.gradient = gradient
	soft_disc.width = 128
	soft_disc.height = 128
	soft_disc.fill = GradientTexture2D.FILL_RADIAL
	soft_disc.fill_from = Vector2(0.5, 0.5)
	soft_disc.fill_to = Vector2(1.0, 0.5)
	var glow_material := CanvasItemMaterial.new()
	glow_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = glow_material
	var art := get_parent().get_node("Art") as Sprite2D
	var flame_material := ShaderMaterial.new()
	flame_material.shader = load("res://src/ui/campfire_paint.gdshader")
	flame_material.set_shader_parameter("fire_position", position + Vector2(0, -100))
	flame_material.set_shader_parameter("strength", intensity)
	art.material = flame_material

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()

func glow(center: Vector2, radius: Vector2, color: Color) -> void:
	draw_texture_rect(soft_disc, Rect2(center - radius, radius * 2), false, color)

func _draw() -> void:
	if soft_disc == null or intensity <= 0:
		return
	var flicker := 0.78 + sin(elapsed * 8.3) * 0.1 + sin(elapsed * 17.7 + 1.2) * 0.07 + sin(elapsed * 29.1) * 0.05
	# Restrained warm spill follows the existing painted light, not a solid disc.
	glow(Vector2(0, -7), Vector2(320, 65), Color(1.0, 0.32, 0.055, 0.10 * flicker * intensity))
	glow(Vector2(0, -85), Vector2(95, 135), Color(1.0, 0.27, 0.025, 0.15 * flicker * intensity))
	glow(Vector2(-210, -125), Vector2(150, 135), Color(0.9, 0.25, 0.035, 0.018 * flicker * intensity))
	glow(Vector2(230, -130), Vector2(150, 140), Color(0.9, 0.25, 0.035, 0.018 * flicker * intensity))
	# Faint irregular drifting smoke; the original painted plume remains visible.
	for i in range(9):
		var age := fposmod(elapsed * 0.18 + float(i) / 9.0, 1.0)
		var center := Vector2(sin(age * 5 + i * 1.7) * (12 + age * 32), -105 - age * 350)
		var fade := sin(age * PI) * 0.018 * intensity
		glow(center, Vector2(25 + age * 60, 40 + age * 65), Color(0.38, 0.42, 0.48, fade))
	# Deterministic varied ember lifetimes and sideways wind.
	for i in range(32):
		var seed_value := float(i)
		var lifetime := 1.8 + fposmod(seed_value * 0.731, 2.4)
		var age := fposmod(elapsed / lifetime + seed_value * 0.618034, 1.0)
		var x := sin(seed_value * 13.7) * 36 + sin(age * 5 + seed_value) * age * 32
		var y := -45 - age * (145 + fposmod(seed_value * 37.3, 190))
		var alpha := sin(age * PI) * (0.35 + fposmod(seed_value * 0.17, 0.5)) * intensity
		var center := Vector2(x, y)
		var radius := 1.0 + fposmod(seed_value * 0.37, 1.6)
		glow(center, Vector2.ONE * radius * 4, Color(1.0, 0.27, 0.035, alpha * 0.4))
		draw_line(center, center + Vector2(-1.5, 3.5 + age * 3), Color(1.0, 0.55, 0.13, alpha), radius, true)
