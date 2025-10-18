class_name MoveSpeedEnum

## Enum para velocidades de movimiento de NPCs (similar a RPG Maker)

enum Type {
	SLOWEST,   ## Muy lento (0.5x)
	SLOWER,    ## Lento (0.75x)
	NORMAL,    ## Normal (1.0x)
	FASTER,    ## Rápido (1.5x)
	FASTEST    ## Muy rápido (2.0x)
}

## Convierte el enum a multiplicador de velocidad
static func to_multiplier(speed: int) -> float:
	match speed:
		Type.SLOWEST: return 0.5
		Type.SLOWER: return 0.75
		Type.NORMAL: return 1.0
		Type.FASTER: return 1.5
		Type.FASTEST: return 2.0
		_: return 1.0
