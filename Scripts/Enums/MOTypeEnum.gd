class_name MOTypeEnum

## Enum para los tipos de Máquinas Ocultas (MO) disponibles
## Cada MO permite interactuar con el entorno de forma específica

enum Type {
	CUT,           ## CORTE - Corta árboles pequeños que bloquean el camino
	SURF,          ## SURF - Permite navegar sobre agua
	STRENGTH,      ## FUERZA - Empuja rocas pesadas
	FLASH,         ## DESTELLO - Ilumina cuevas oscuras
	ROCK_SMASH,    ## GOLPE ROCA - Rompe rocas frágiles
	WATERFALL,     ## CASCADA - Sube cascadas
	DIVE,          ## BUCEO - Se sumerge bajo el agua
	ROCK_CLIMB,    ## TREPARROCAS - Escala paredes rocosas
	FLY,           ## VUELO - Vuela a ciudades visitadas
	WHIRLPOOL,     ## TORBELLINO - Atraviesa remolinos de agua
	DEFOG,         ## DESPEJAR - Despeja niebla densa
	HEADBUTT       ## GOLPE CABEZA - Golpea árboles para hacer caer Pokemon
}

## Convierte el enum a String para logs y señales
static func type_to_string(mo_type: int) -> String:
	match mo_type:
		Type.CUT: return "CUT"
		Type.SURF: return "SURF"
		Type.STRENGTH: return "STRENGTH"
		Type.FLASH: return "FLASH"
		Type.ROCK_SMASH: return "ROCK_SMASH"
		Type.WATERFALL: return "WATERFALL"
		Type.DIVE: return "DIVE"
		Type.ROCK_CLIMB: return "ROCK_CLIMB"
		Type.FLY: return "FLY"
		Type.WHIRLPOOL: return "WHIRLPOOL"
		Type.DEFOG: return "DEFOG"
		Type.HEADBUTT: return "HEADBUTT"
		_: return "UNKNOWN"

## Convierte un String a enum (útil para cargar desde datos guardados)
static func from_string(mo_name: String) -> int:
	match mo_name.to_upper():
		"CUT": return Type.CUT
		"SURF": return Type.SURF
		"STRENGTH": return Type.STRENGTH
		"FLASH": return Type.FLASH
		"ROCK_SMASH": return Type.ROCK_SMASH
		"WATERFALL": return Type.WATERFALL
		"DIVE": return Type.DIVE
		"ROCK_CLIMB": return Type.ROCK_CLIMB
		"FLY": return Type.FLY
		"WHIRLPOOL": return Type.WHIRLPOOL
		"DEFOG": return Type.DEFOG
		"HEADBUTT": return Type.HEADBUTT
		_: return -1

## Obtiene la descripción de una MO
static func get_description(mo_type: int) -> String:
	match mo_type:
		Type.CUT: return "Corta árboles pequeños"
		Type.SURF: return "Navega sobre agua"
		Type.STRENGTH: return "Empuja rocas pesadas"
		Type.FLASH: return "Ilumina cuevas oscuras"
		Type.ROCK_SMASH: return "Rompe rocas frágiles"
		Type.WATERFALL: return "Sube cascadas"
		Type.DIVE: return "Se sumerge bajo el agua"
		Type.ROCK_CLIMB: return "Escala paredes rocosas"
		Type.FLY: return "Vuela a ciudades visitadas"
		Type.WHIRLPOOL: return "Atraviesa remolinos"
		Type.DEFOG: return "Despeja la niebla"
		Type.HEADBUTT: return "Golpea árboles"
		_: return "Desconocido"

## Verifica si una MO requiere interacción directa con un objeto
## (true) o afecta al jugador/entorno general (false)
static func requires_target(mo_type: int) -> bool:
	match mo_type:
		Type.CUT, Type.STRENGTH, Type.ROCK_SMASH, Type.HEADBUTT:
			return true  # Necesitan un objeto/evento específico
		Type.SURF, Type.FLASH, Type.WATERFALL, Type.DIVE, Type.ROCK_CLIMB, Type.FLY, Type.WHIRLPOOL, Type.DEFOG:
			return false  # Afectan al jugador o entorno general
		_:
			return true

