extends Resource
class_name EventCondition

## Clase base abstracta para condiciones de eventos
## Todas las condiciones deben extender esta clase e implementar evaluate()

## Evalúa la condición en el contexto dado
## Retorna true si la condición se cumple, false en caso contrario
func evaluate(context: EventConditionContext) -> bool:
	push_warning("EventCondition.evaluate() debe ser sobrescrito por las clases hijas")
	return true
