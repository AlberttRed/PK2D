extends EventCondition
class_name HasItemCondition

## Condición que comprueba si el jugador tiene un ítem en una cantidad mínima.

@export var item_id: int = 0
@export_range(1, 999, 1) var quantity: int = 1

func evaluate(context: EventConditionContext) -> bool:
	if item_id <= 0:
		return false
	if context == null or context.game_state == null:
		return false
	var bag = context.game_state.get_bag()
	if bag == null:
		return false
	return bag.has_item(item_id, maxi(1, quantity))
