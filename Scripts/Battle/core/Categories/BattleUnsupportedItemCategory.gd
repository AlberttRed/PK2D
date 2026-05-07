extends BattleItemCategory

class_name BattleUnsupportedItemCategory


func _create_handler(choice: BattleBagChoice, item_data: ItemData) -> BattleHandler:
	return BattleUnsupportedItemHandler.new(choice, item_data)
