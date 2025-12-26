extends EventTrigger
class_name CollisionTrigger

## CollisionTrigger - Se dispara cuando un actor intenta entrar en el tile del evento pero colisiona
##
## Este trigger replica el comportamiento clásico de:
## - Puertas
## - Escaleras
## - Salidas
## - Trainers que te "paran"
##
## Nota importante: Este trigger no requiere overlap, se dispara en el intento fallido de movimiento.

## Si true, se activa cuando el jugador intenta entrar pero colisiona
@export var trigger_for_player: bool = true

## Si true, se activa cuando otro evento intenta entrar pero colisiona
@export var trigger_for_events: bool = false


func can_fire(
	signal_type: EventTriggerSignal.SignalType,
	context: OverworldContext,
	event: Event,
	instigator: Node
) -> bool:
	# Solo se activa con COLLISION
	if signal_type != EventTriggerSignal.SignalType.COLLISION:
		return false

	# Verificar si debe activarse para el instigator
	if instigator.is_in_group("Player"):
		return trigger_for_player
	elif instigator is Event:
		return trigger_for_events

	return false

