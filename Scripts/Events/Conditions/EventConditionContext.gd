## Contexto ligero (no Resource) que se pasa a las condiciones para evaluación
## Permite a las condiciones acceder al estado del juego y al evento que las evalúa
class_name EventConditionContext

## ID único del evento que está evaluando la condición
var event_uid: String

## Referencia al GameStateService para acceder a flags, variables y self-switches
var game_state: GameStateService

func _init(p_event_uid: String = "", p_game_state: GameStateService = null):
	event_uid = p_event_uid
	game_state = p_game_state if p_game_state else GameStateService

