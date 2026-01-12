class_name MovementTypeEnum

## Tipos de movimiento para NPCs

enum Type {
	NONE,                    ## El NPC no tiene movimiento automático
	RANDOM,                  ## El NPC se mueve aleatoriamente por el mapa
	PATH,                    ## El NPC sigue una ruta predefinida (movimiento + mirada)
	RANDOM_TURNING,          ## El NPC permanece fijo pero gira aleatoriamente
	LOOK_PATTERN,            ## El NPC sigue un patrón de mirada fijo (solo orientación, sin movimiento)
	RANDOM_VERTICAL,         ## El NPC se mueve aleatoriamente solo verticalmente (UP/DOWN)
	RANDOM_HORIZONTAL,       ## El NPC se mueve aleatoriamente solo horizontalmente (LEFT/RIGHT)
	RANDOM_TURNING_HORIZONTAL, ## El NPC permanece fijo pero gira aleatoriamente entre LEFT y RIGHT
	RANDOM_TURNING_VERTICAL    ## El NPC permanece fijo pero gira aleatoriamente entre UP y DOWN
}

