class_name BattleBaseVariantEnum
## Variante de base bajo los Pokémon (Grass, Sand, Water…). Suffix en PNG de Battlebacks/.


enum Values {
	INHERIT,
	NONE,
	GRASS,
	SAND,
	WATER,
	PUDDLE,
	MUD,
}


## Sufijo del nombre de archivo PNG (vacío = sin variant).
static func to_key_name(value: Values) -> String:
	match value:
		Values.INHERIT, Values.NONE:
			return ""
		Values.GRASS: return "Grass"
		Values.SAND: return "Sand"
		Values.WATER: return "Water"
		Values.PUDDLE: return "Puddle"
		Values.MUD: return "Mud"
		_: return ""


static func get_display_name(value: Values) -> String:
	match value:
		Values.INHERIT: return "Inherit"
		Values.NONE: return "None"
		Values.GRASS: return "Grass"
		Values.SAND: return "Sand"
		Values.WATER: return "Water"
		Values.PUDDLE: return "Puddle"
		Values.MUD: return "Mud"
		_: return "Unknown"
