extends EventCondition
class_name TrainerBattleResultCondition

## Condición que evalúa el resultado de un combate contra un entrenador
enum ResultType {
	VICTORY,    # Victoria (V) - Se ganó el combate
	DEFEAT,     # Derrota (D) - Se perdió el combate
	ANY         # Cualquiera - Existe el registro (se ha combatido, sin importar el resultado)
}

## Nombre del trainer (resource_id, nombre del .res sin extensión)
## Ejemplo: "brock" para "res://Resources/Trainers/brock.tres"
@export var trainer_name: String = ""

## Tipo de resultado a verificar
@export var result_type: ResultType = ResultType.VICTORY

## Evalúa si el resultado del combate cumple con la condición
func evaluate(context: EventConditionContext) -> bool:
	if trainer_name.is_empty():
		push_warning("TrainerBattleResultCondition: trainer_name está vacío, retornando false")
		return false

	# Debug: mostrar qué key estamos buscando
	print("TrainerBattleResultCondition: Buscando resultado para trainer_name='%s'" % trainer_name)

	# Debug: mostrar todas las keys disponibles en defeated_trainers
	var all_keys = context.game_state.defeated_trainers.keys()
	print("TrainerBattleResultCondition: Keys disponibles en defeated_trainers: %s" % all_keys)

	# Obtener el resultado del combate desde GameStateService
	var battle_result = context.game_state.get_trainer_battle_result(trainer_name)
	print("TrainerBattleResultCondition: Resultado obtenido para '%s': '%s'" % [trainer_name, battle_result])

	# Evaluar según el tipo de resultado esperado
	match result_type:
		ResultType.VICTORY:
			# Verificar si se ganó (resultado = "V")
			return battle_result == "V"
		ResultType.DEFEAT:
			# Verificar si se perdió (resultado = "D")
			return battle_result == "D"
		ResultType.ANY:
			# Verificar si existe el registro (no está vacío)
			return not battle_result.is_empty()
		_:
			return false

## Verifica si esta condición depende de una variable global específica
## Esta condición no depende de variables, solo de defeated_trainers
func depends_on_variable(variable_name: String) -> bool:
	return false

## Verifica si esta condición depende de un flag global específico
## Esta condición no depende de flags, solo de defeated_trainers
func depends_on_flag(flag_name: String) -> bool:
	return false
