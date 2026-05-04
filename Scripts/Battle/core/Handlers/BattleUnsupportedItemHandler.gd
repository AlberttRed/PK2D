extends BattleItemHandler

class_name BattleUnsupportedItemHandler

var _choice: BattleBagChoice = null
var _item_data: ItemData = null


func _init(choice: BattleBagChoice, item_data: ItemData = null) -> void:
	_choice = choice
	_item_data = item_data


func _apply() -> void:
	if _choice == null:
		item_use_result = ItemUseResult.failure_error("Elección de bolsa inválida.")
	elif _choice.item_id <= 0:
		item_use_result = ItemUseResult.failure_blocked("No hay objeto seleccionado.")
	elif _item_data == null:
		item_use_result = ItemUseResult.failure_error("Objeto desconocido.")
	elif _item_data.effect == null:
		item_use_result = ItemUseResult.failure_error("Este objeto no tiene efecto definido.")
	else:
		item_use_result = ItemUseResult.failure_blocked("Este objeto aún no puede usarse en combate.")

	item_use_result.battle_continuation = ItemUseResult.BattleContinuation.COMPLETE_ACTION
	_should_visualize = true


func _visualize(ui: BattleUI) -> void:
	if item_use_result == null or item_use_result.message.is_empty():
		return
	await ui.show_message_from_dict({
		"type": "display",
		"text": item_use_result.message,
		"wait_time": 0.8,
	})
