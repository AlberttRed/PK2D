extends Resource
class_name EventTrigger

## EventTrigger - Clase base para todos los triggers de eventos
##
## Un EventTrigger define cuándo y cómo se activa un evento.
## Los triggers no evalúan condiciones (eso es responsabilidad de EventCondition),
## solo deciden si se dispara el evento basándose en la señal recibida.
##
## Cada EventPage tiene un EventTrigger que determina cómo se activa.
## El Event delega en el trigger cuando recibe una señal externa.

## Verifica si este trigger puede activarse con la señal dada
## Retorna true si el trigger debe activarse, false en caso contrario
func can_fire(
	signal_type: EventTriggerSignal.SignalType,
	context: OverworldContext,
	event: Event,
	instigator: Node
) -> bool:
	return false

## Activa el evento asociado a este trigger
## Se llama cuando can_fire() retorna true
func fire(
	signal_type: EventTriggerSignal.SignalType,
	context: OverworldContext,
	event: Event,
	instigator: Node
) -> void:
	event.trigger()

