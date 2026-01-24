extends EventCondition
class_name NotCondition

## Condición que invierte el resultado de su condición hija (operador NOT)
@export var child: EventCondition = null

## Evalúa la negación de la condición hija
func evaluate(context: EventConditionContext) -> bool:
	if not child:
		push_warning("NotCondition: child es null, se retorna true por defecto")
		return true

	return not child.evaluate(context)

## Verifica si esta condición depende de una variable global específica
## Verifica recursivamente la condición hija
func depends_on_variable(variable_name: String) -> bool:
	if child:
		return child.depends_on_variable(variable_name)
	return false

## Verifica si esta condición depende de un flag global específico
## Verifica recursivamente la condición hija
func depends_on_flag(flag_name: String) -> bool:
	if child:
		return child.depends_on_flag(flag_name)
	return false

## Verifica si esta condición depende de un trainer específico
## Verifica recursivamente la condición hija
func depends_on_trainer(trainer_id: String) -> bool:
	if child:
		return child.depends_on_trainer(trainer_id)
	return false

