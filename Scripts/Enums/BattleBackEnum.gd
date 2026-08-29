class_name BattleBackEnum
## Escenario de fondo de combate (backdrop). Nombres alineados con PNG en Battlebacks/.


enum Values {
	INHERIT,
	FIELD,
	FOREST,
	MOUNTAIN,
	CAVE,
	CAVE_DARK,
	CAVE_DARKER,
	WATER,
	SNOW,
	UNDERWATER,
	INDOOR_A,
	INDOOR_B,
	INDOOR_C,
	ELITE_A,
	ELITE_B,
	ELITE_C,
	ELITE_D,
	CHAMPION,
}


## Sufijo del nombre de archivo PNG (p. ej. Field, EliteA, CaveDark).
static func to_key_name(value: Values) -> String:
	match value:
		Values.INHERIT: return ""
		Values.FIELD: return "Field"
		Values.FOREST: return "Forest"
		Values.MOUNTAIN: return "Mountain"
		Values.CAVE: return "Cave"
		Values.CAVE_DARK: return "CaveDark"
		Values.CAVE_DARKER: return "CaveDarker"
		Values.WATER: return "Water"
		Values.SNOW: return "Snow"
		Values.UNDERWATER: return "Underwater"
		Values.INDOOR_A: return "IndoorA"
		Values.INDOOR_B: return "IndoorB"
		Values.INDOOR_C: return "IndoorC"
		Values.ELITE_A: return "EliteA"
		Values.ELITE_B: return "EliteB"
		Values.ELITE_C: return "EliteC"
		Values.ELITE_D: return "EliteD"
		Values.CHAMPION: return "Champion"
		_: return "Field"


static func get_display_name(value: Values) -> String:
	match value:
		Values.INHERIT: return "Inherit"
		Values.FIELD: return "Field"
		Values.FOREST: return "Forest"
		Values.MOUNTAIN: return "Mountain"
		Values.CAVE: return "Cave"
		Values.CAVE_DARK: return "Cave Dark"
		Values.CAVE_DARKER: return "Cave Darker"
		Values.WATER: return "Water"
		Values.SNOW: return "Snow"
		Values.UNDERWATER: return "Underwater"
		Values.INDOOR_A: return "Indoor A"
		Values.INDOOR_B: return "Indoor B"
		Values.INDOOR_C: return "Indoor C"
		Values.ELITE_A: return "Elite A"
		Values.ELITE_B: return "Elite B"
		Values.ELITE_C: return "Elite C"
		Values.ELITE_D: return "Elite D"
		Values.CHAMPION: return "Champion"
		_: return "Unknown"


## Backdrops cuyas bases no llevan suffix Grass/Sand/Water (set emparejado fijo).
static func uses_fixed_base_set(value: Values) -> bool:
	match value:
		Values.ELITE_A, Values.ELITE_B, Values.ELITE_C, Values.ELITE_D, Values.CHAMPION, Values.INDOOR_A, Values.INDOOR_B, Values.INDOOR_C, Values.UNDERWATER:
			return true
		_:
			return false
