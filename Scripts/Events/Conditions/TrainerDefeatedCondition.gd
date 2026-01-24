extends EventCondition
class_name TrainerDefeatedCondition

## Condición que verifica si un entrenador ha sido derrotado
## Consulta el flag configurado en StartBattleEventCommand.defeated_flag
## El flag se guarda en GameStateService cuando el jugador gana el combate

## Nombre del flag que indica si el trainer fue derrotado
## Debe coincidir con el defeated_flag configurado en StartBattleEventCommand
## Ejemplo: "rival_inicio_c_defeated" para el flag "rival_inicio_c_defeated"
@export var flag_name: String = ""

## Evalúa si el trainer ha sido derrotado
func evaluate(context: EventConditionContext) -> bool:
	if flag_name.is_empty():
		push_warning("TrainerDefeatedCondition: flag_name está vacío, retornando false")
		return false

	return context.game_state.get_event_flag(flag_name)

## Verifica si esta condición depende de una variable global específica
## Esta condición no depende de variables, solo de flags
func depends_on_variable(_variable_name: String) -> bool:
	return false

## Verifica si esta condición depende de un flag global específico
## Retorna true si flag_name coincide con el flag consultado
func depends_on_flag(flag_name_to_check: String) -> bool:
	return flag_name == flag_name_to_check

## Verifica si esta condición depende de un trainer específico
## Esta condición no depende de trainers directamente, solo de flags
func depends_on_trainer(_trainer_id: String) -> bool:
	return false
