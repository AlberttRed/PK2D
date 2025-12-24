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

