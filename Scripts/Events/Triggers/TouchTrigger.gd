extends EventTrigger
class_name TouchTrigger

## TouchTrigger - Se dispara cuando un actor entra en el tile del evento (overlap)
##
## Uso típico:
## - NPC que inicia diálogo al acercarte
## - Zonas invisibles de activación
## - Triggers de mapa

## Si true, se activa cuando el jugador entra en el tile
@export var trigger_for_player: bool = true

## Si true, se activa cuando otro evento entra en el tile
@export var trigger_for_events: bool = false


func can_fire(
	signal_type: EventTriggerSignal.SignalType,
	context: OverworldContext,
	event: Event,
	instigator: Node
) -> bool:
	# Solo se activa con TOUCH
	if signal_type != EventTriggerSignal.SignalType.TOUCH:
		return false

	# Verificar si debe activarse para el instigator
	if instigator.is_in_group("Player"):
		return trigger_for_player
	elif instigator is Event:
		return trigger_for_events

	return false

