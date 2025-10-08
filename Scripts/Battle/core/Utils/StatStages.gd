# StatStages.gd
class_name StatStages
extends RefCounted

var stages: Dictionary = {}

func _init():
	reset()

func reset() -> void:
	for stat in StatsEnum.Values.values():
		stages[stat] = 0

func get_stat(stat: StatsEnum.Values) -> int:
	return stages.get(stat, 0)

func increase(stat: StatsEnum.Values, amount: int = 1) -> bool:
	if not stages.has(stat): return false
	var current = stages[stat]
	if current >= 6: return false
	stages[stat] = min(current + amount, 6)
	return true

func decrease(stat: StatsEnum.Values, amount: int = 1) -> bool:
	if not stages.has(stat): return false
	var current = stages[stat]
	if current <= -6: return false
	stages[stat] = max(current - amount, -6)
	return true

func set_stat(stat: StatsEnum.Values, value: int) -> void:
	stages[stat] = clamp(value, -6, 6)

func get_multiplier(stat: StatsEnum.Values) -> float:
	var stage := get_stat(stat)
	var is_acc_eva := stat == StatsEnum.Values.ACCURACY or stat == StatsEnum.Values.EVASION
	if is_acc_eva:
		return (3.0 + stage) / 3.0 if stage >= 0 else 3.0 / (3.0 - stage)
	else:
		return (2.0 + stage) / 2.0 if stage >= 0 else 2.0 / (2.0 - stage)

func get_stage_label(stat: StatsEnum.Values) -> String:
	var s = get_stat(stat)
	if s == 0:
		return "normal"
	elif s > 0:
		return "+%d" % s
	else:
		return "%d" % s
