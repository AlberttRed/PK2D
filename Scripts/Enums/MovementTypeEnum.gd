class_name MovementTypeEnum

## Tipos de movimiento para NPCs

enum Type {
	NONE,           ## El NPC no tiene movimiento automático
	RANDOM,         ## El NPC se mueve aleatoriamente por el mapa
	PATH,           ## El NPC sigue una ruta predefinida
	LOOK_AT_PLAYER  ## El NPC permanece fijo pero gira para mirar al jugador
}

