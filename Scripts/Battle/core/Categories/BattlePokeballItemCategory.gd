extends BattleItemCategory

class_name BattlePokeballItemCategory


func _create_handler(choice: BattleBagChoice, item_data: ItemData) -> BattleHandler:
	return BattlePokeballItemHandler.new(choice, item_data)
