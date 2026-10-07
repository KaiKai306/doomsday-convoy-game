class_name GameState
extends Node

## 第一阶段只保存跨场景的最小状态；具体规则会在垂直切片中逐步加入。

signal day_changed(day: int)
signal phase_changed(phase: Phase)

enum Phase {
	MORNING,
	ROUTE_SELECTION,
	TRAVEL,
	REST_STOP,
	CAMP_ACTION,
	NIGHT_SETTLEMENT,
	ENDING,
}

const DEFAULT_RESOURCES: Dictionary = {
	"water": 20,
	"food": 20,
	"fuel": 30,
	"medicine": 5,
	"parts": 10,
}

var day: int = 1
var phase: Phase = Phase.MORNING
var resources: Dictionary = DEFAULT_RESOURCES.duplicate()

func reset(initial_resources: Dictionary = DEFAULT_RESOURCES) -> void:
	day = 1
	phase = Phase.MORNING
	resources = initial_resources.duplicate()

func set_phase(next_phase: Phase) -> void:
	if phase == next_phase:
		return
	phase = next_phase
	phase_changed.emit(phase)

func advance_day() -> void:
	day += 1
	day_changed.emit(day)
