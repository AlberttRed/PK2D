extends RefCounted

class_name MoveLearnResult

## Nivel en el que se evalúa el aprendizaje (normalmente el nivel recién alcanzado).
var level: int = 0
## Movimientos detectados para este nivel/tipo.
var offered_moves: Array[Move] = []
## Movimientos aprendidos automáticamente (había hueco).
var learned_moves: Array[Move] = []
## Movimientos pendientes por falta de hueco (4 movimientos).
var pending_moves: Array[Move] = []
## True si hay al menos un movimiento que requiere decisión del jugador.
var requires_decision: bool = false
