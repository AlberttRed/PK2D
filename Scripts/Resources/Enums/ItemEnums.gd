## Enums para clasificación y uso de items
## Define la taxonomía de items del juego (bolsillos, tipos lógicos, objetivos, contextos)

class_name ItemEnums

## Bolsillos del Bag donde se organizan los items
enum Pocket {
	ITEMS = 1,        # Items generales (pociones, repelentes, etc.)
	MEDICINE = 2,    # Medicina (pociones, antidotos, etc.)
	BALLS = 3,       # Poké Balls
	TM_HM = 4,       # TMs y HMs
	BERRIES = 5,     # Bayas
	KEY_ITEMS = 6,   # Objetos clave
	MACHINES = 7,    # Máquinas (TMs/HMs en algunas generaciones)
	BATTLE_ITEMS = 8 # Items de combate (X Attack, etc.)
}

## Clasificación lógica del tipo de item
enum Kind {
	GENERIC = 0,        # Genérico (sin categoría específica)
	HEAL_HP = 1,        # Cura HP
	HEAL_PP = 2,        # Cura PP
	CURE_STATUS = 3,    # Cura estados alterados
	REVIVE = 4,         # Revive Pokémon debilitados
	POKEBALL = 5,       # Poké Ball (para capturar)
	TM_HM = 6,          # TM o HM (enseña movimiento)
	HELD = 7,           # Objeto que se puede llevar (held item)
	KEY = 8,            # Objeto clave (no consumible, único)
	EVOLUTION = 9,      # Objeto de evolución
	STAT_BOOST = 10,    # Aumenta estadísticas (X Attack, etc.)
	REPEL = 11,         # Repelente
	BERRY = 12          # Baya
}

## Tipo de objetivo sobre el que puede aplicarse el item
enum TargetType {
	NONE = 0,           # No requiere objetivo (ej: repelente)
	POKEMON = 1,        # Requiere un Pokémon específico
	PARTY_SLOT = 2,    # Requiere un slot del party
	MOVE_SLOT = 3,     # Requiere un slot de movimiento
	PARTY = 4          # Afecta a todo el party
}

## Contextos donde puede usarse el item
enum UseContext {
	OVERWORLD = 1,     # En el overworld (fuera de combate)
	PARTY_MENU = 2,    # En el menú del party
	BATTLE = 4         # En combate
	# Nota: Se pueden combinar con operaciones bitwise (OVERWORLD | PARTY_MENU)
}

## Helper para verificar si un contexto está habilitado
static func has_context(contexts: int, context: UseContext) -> bool:
	return (contexts & context) != 0

## Helper para combinar contextos
static func combine_contexts(contexts: Array[UseContext]) -> int:
	var result := 0
	for ctx in contexts:
		result |= ctx
	return result

