class_name EventTriggerSignal

## EventTriggerSignal - Enum de señales que pueden activar un EventTrigger
##
## Define los diferentes tipos de señales que pueden activar un evento:
## - ACTION: El jugador pulsa el botón de acción frente al evento
## - TOUCH: Un actor entra en el tile del evento (overlap)
## - COLLISION: Un actor intenta entrar en el tile del evento pero colisiona
## - PAGE_ACTIVATED: La página del evento se activa (para autorun)

enum SignalType {
	ACTION,          # Se activa al pulsar A frente al evento
	TOUCH,           # Se activa al entrar en la misma celda que el evento
	COLLISION,       # Se activa cuando un actor intenta entrar pero colisiona
	PAGE_ACTIVATED   # Se activa cuando la página se activa (autorun)
}

