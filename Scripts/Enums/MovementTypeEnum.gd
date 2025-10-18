class_name MovementTypeEnum

## Tipos de movimiento para NPCs

enum Type {
	FIXED,          ## El NPC permanece en su posición sin moverse
	RANDOM,         ## El NPC se mueve aleatoriamente por el mapa
	PATH,           ## El NPC sigue una ruta predefinida
	LOOK_AT_PLAYER  ## El NPC permanece fijo pero gira para mirar al jugador
}

