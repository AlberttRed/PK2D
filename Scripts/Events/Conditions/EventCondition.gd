extends Resource
class_name EventCondition

## Clase base abstracta para condiciones de eventos
## Todas las condiciones deben extender esta clase e implementar evaluate()

## Evalúa la condición en el contexto dado
## Retorna true si la condición se cumple, false en caso contrario
func evaluate(context: EventConditionContext) -> bool:
	push_warning("EventCondition.evaluate() debe ser sobrescrito por las clases hijas")
	return true

## Verifica si esta condición depende de una variable global específica
## Retorna true si la condición usa la variable, false en caso contrario
## Por defecto retorna false (las condiciones base no dependen de variables)
func depends_on_variable(variable_name: String) -> bool:
	return false

## Verifica si esta condición depende de un flag global específico
## Retorna true si la condición usa el flag, false en caso contrario
## Por defecto retorna false (las condiciones base no dependen de flags)
func depends_on_flag(flag_name: String) -> bool:
	return false

## Verifica si esta condición depende de un trainer específico (para TrainerDefeatedCondition)
## Retorna true si la condición usa este trainer, false en caso contrario
## Por defecto retorna false (las condiciones base no dependen de trainers)
func depends_on_trainer(trainer_id: String) -> bool:
	return false
