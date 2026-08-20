class_name PhaseValidationContext
extends RefCounted

## Resultado compartido de fases de validación (ailments, stats, movimiento, cambio, huida).

var rejected: bool = false
var blocking_effect: PersistentBattleEffect = null
var rejection_message: Dictionary = {}
## Identificador de bloqueo para mensajería (p. ej. "mist", "safeguard").
var block_reason: String = ""
