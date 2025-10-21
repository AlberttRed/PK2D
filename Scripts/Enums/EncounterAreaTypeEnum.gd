class_name EncounterAreaTypeEnum
## Tipos de áreas donde pueden ocurrir encuentros salvajes

enum Values {
	NONE,
	LAND,        ## Hierba alta, tierra
	WATER,       ## Agua (surfing)
	CAVE,        ## Cuevas
	FISHING,     ## Pescando
	SAND,        ## Arena/playa
	ROCK_SMASH,  ## Romper rocas
	HEADBUTT,    ## Golpear árboles
}

## Convierte el enum a string legible
static func get_type_name(type: Values) -> String:
	match type:
		Values.NONE: return "None"
		Values.LAND: return "Land"
		Values.WATER: return "Water"
		Values.CAVE: return "Cave"
		Values.FISHING: return "Fishing"
		Values.SAND: return "Sand"
		Values.ROCK_SMASH: return "RockSmash"
		Values.HEADBUTT: return "Headbutt"
		_: return "Unknown"


## Convierte un string a enum
static func parse_type(type_str: String) -> Values:
	match type_str.to_lower():
		"none": return Values.NONE
		"land": return Values.LAND
		"water": return Values.WATER
		"cave": return Values.CAVE
		"fishing": return Values.FISHING
		"sand": return Values.SAND
		"rocksmash", "rock_smash": return Values.ROCK_SMASH
		"headbutt": return Values.HEADBUTT
		_: return Values.NONE
