extends Control

@onready var status_label: Label = %StatusLabel

func _ready() -> void:
    status_label.text = "开发原型已启动\nGodot 4.7.2 · 第一个垂直切片准备中"

