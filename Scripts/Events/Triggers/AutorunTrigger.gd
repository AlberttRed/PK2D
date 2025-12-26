extends EventTrigger
class_name AutorunTrigger

## AutorunTrigger - Ejecuta el evento automáticamente cuando la página se activa
##
## Se dispara cuando la página del evento se activa (PAGE_ACTIVATED).
## Bloquea el control del jugador mientras se ejecuta.
##
## Si run_once es true, se recomienda usar flags para evitar que se ejecute múltiples veces.

## Si true, el evento solo se ejecutará una vez
## Se recomienda usar flags para controlar esto en lugar de lógica interna
@export var run_once: bool = false


func can_fire(
	signal_type: EventTriggerSignal.SignalType,
	context: OverworldContext,
	event: Event,
	instigator: Node
) -> bool:
	# Solo se activa con PAGE_ACTIVATED
	return signal_type == EventTriggerSignal.SignalType.PAGE_ACTIVATED

