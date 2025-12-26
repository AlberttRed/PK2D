extends EventTrigger
class_name ActionTrigger

## ActionTrigger - Se dispara cuando el jugador pulsa el botón de acción frente al evento
##
## Responde a la señal ACTION.
## El Player ya detecta el evento en frente (event_in_front()).


func can_fire(
	signal_type: EventTriggerSignal.SignalType,
	context: OverworldContext,
	event: Event,
	instigator: Node
) -> bool:
	# Solo se activa con ACTION
	return signal_type == EventTriggerSignal.SignalType.ACTION

