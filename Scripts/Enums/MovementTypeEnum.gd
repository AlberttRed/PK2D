class_name MovementTypeEnum

## Tipos de movimiento para NPCs

enum Type {
	NONE,           ## El NPC no tiene movimiento automático
	RANDOM,         ## El NPC se mueve aleatoriamente por el mapa
	PATH,           ## El NPC sigue una ruta predefinida (movimiento + mirada)
	RANDOM_TURNING, ## El NPC permanece fijo pero gira aleatoriamente
	LOOK_PATTERN    ## El NPC sigue un patrón de mirada fijo (solo orientación, sin movimiento)
}

