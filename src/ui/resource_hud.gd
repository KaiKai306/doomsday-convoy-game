extends Control
## The scene HUD shows the five main supplies; inventory retains every resource.
const SKIN = preload("res://src/ui/convoy_skin.gd")
const ORDER = ["water","food","fuel","medicine","parts"]
const NAMES = {"water":"饮水","food":"食物","fuel":"燃料","medicine":"药品","parts":"零件"}
const ICON_ROOT = "res://assets/ui/resource_hud/lucide/"
const ICONS = {
	"water":preload("res://assets/ui/resource_hud/lucide/water.svg"),
	"food":preload("res://assets/ui/resource_hud/lucide/food.svg"),
	"fuel":preload("res://assets/ui/resource_hud/lucide/fuel.svg"),
	"medicine":preload("res://assets/ui/resource_hud/lucide/medicine.svg"),
	"parts":preload("res://assets/ui/resource_hud/lucide/parts.svg"),
}
const CHIP_SIZE = Vector2(148,44)
const GAP = 8.0
const TEXT = Color("f4f1e9")
const GOLD = Color("f0bd7e")
var amounts: Dictionary = {}

func _ready() -> void:
	name = "ResourceHUD"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(CHIP_SIZE.x*ORDER.size()+GAP*(ORDER.size()-1),CHIP_SIZE.y)
	for i in ORDER.size():
		var key: String = ORDER[i]
		var chip = SKIN.panel(self,Vector2(i*(CHIP_SIZE.x+GAP),0),CHIP_SIZE)
		chip.set_meta("hud_resource",key); chip.fill = Color(0.012,0.025,0.038,0.91); chip.line = Color(0.65,0.72,0.77,0.75)
		var icon = TextureRect.new(); icon.texture = ICONS[key]
		icon.position = Vector2(12,10); icon.size = Vector2(24,24); icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; icon.self_modulate = GOLD; icon.mouse_filter = Control.MOUSE_FILTER_IGNORE; chip.add_child(icon)
		_label(chip,NAMES[key],Vector2(45,10),Vector2(42,25),16,Color("c5ced5"))
		var amount = _label(chip,"0",Vector2(86,6),Vector2(48,32),22,TEXT)
		amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; amount.clip_text = true; amounts[key] = amount

func _label(parent: Node,value: String,point: Vector2,dimensions: Vector2,font_size: int,ink: Color) -> Label:
	var label = Label.new(); label.text = value; label.position = point; label.size = dimensions
	label.add_theme_font_size_override("font_size",font_size); label.add_theme_color_override("font_color",ink)
	label.add_theme_color_override("font_outline_color",Color(0,0,0,0.95)); label.add_theme_constant_override("outline_size",2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE; parent.add_child(label); return label

func display(resources: Dictionary) -> void:
	for key in ORDER:
		if amounts.has(key): amounts[key].text = str(snappedf(float(resources.get(key,0)),0.1)).trim_suffix(".0")
