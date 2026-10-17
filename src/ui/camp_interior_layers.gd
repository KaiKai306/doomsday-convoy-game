extends Node2D
## Three static, independently editable image layers for the tent interior.

const CANVAS_SIZE := Vector2(2688, 1152)

func _ready() -> void:
	get_viewport().size_changed.connect(_layout)
	_layout()

func _layout() -> void:
	var viewport := get_viewport_rect().size
	var factor := minf(viewport.x / CANVAS_SIZE.x, viewport.y / CANVAS_SIZE.y)
	$World.scale = Vector2.ONE * factor
	$World.position = (viewport - CANVAS_SIZE * factor) * 0.5
