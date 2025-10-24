class_name NatureData
extends Resource

@export var id: String = ""  # nombre en inglés, minúsculas (ej. "jolly")
@export var display_name: String = ""  # nombre en español, primera letra mayúscula (ej. "Alegre")
@export var increased_stat: StatsEnum.Values
@export var decreased_stat: StatsEnum.Values

func get_stat_multiplier(stat) -> float:  # stat: StatsEnum.Values (int)
	if increased_stat == decreased_stat:
		return 1.0
	elif stat == increased_stat:
		return 1.1
	elif stat == decreased_stat:
		return 0.9
	else:
		return 1.0

func print_info():
	var inc := str(increased_stat)
	var dec := str(decreased_stat)
	print("[Nature] %s (%s) | +%s -%s" % [display_name, id, inc, dec])

