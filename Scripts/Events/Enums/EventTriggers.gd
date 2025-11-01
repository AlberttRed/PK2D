class_name EventTriggers

enum TriggerType {
	ACTION,           # Se activa al pulsar A frente al evento
	TOUCH,            # Se activa al entrar en la misma celda que el evento
	PLAYER_COLLISION, # Se activa cuando el jugador colisiona contra el evento (intenta entrar pero no puede)
	AUTORUN           # Se ejecuta automáticamente
}
