class_name Nature
extends Resource

@export var id: String = ""  # nombre en inglés, minúsculas (ej. "jolly")
@export var display_name: String = ""  # nombre en español, primera letra mayúscula (ej. "Alegre")
@export var increased_stat: StatTypes.Stat
@export var decreased_stat: StatTypes.Stat

func get_stat_multiplier(stat: StatTypes.Stat) -> float:
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
