class_name BattleBagChoice
extends BattleChoice

# Identificador del objeto a usar (`DatabaseService`).
var item_id: int = -1

## Inyectado desde `BattleUI` al elegir MOCHILA (necesario para `ItemUseContext` / handlers).
var battle_controller: BattleController = null

func get_priority() -> int:
	# En juegos oficiales, usar objeto suele resolverse antes que los movimientos
	return 6

func is_blocking_action() -> bool:
	# Por defecto, usar objetos NO bloquea (pociones, bayas, etc.)
	# TODO: Poké Balls → true (bloquean secuencia de turno).
	return false

func resolve() -> Array[BattleHandler]:
	var item_data: ItemData = DatabaseService.get_item_by_id(item_id)
	var handler: BattleHandler = BattleUnsupportedItemHandler.new(self, item_data)
	if item_data != null and item_data.category != null and item_data.category.has_method("create_handler"):
		handler = item_data.category.create_handler(self, item_data)
	return [handler]

