extends BattleItemCategory

class_name BattleReviveItemCategory


func _create_handler(choice: BattleBagChoice, item_data: ItemData) -> BattleHandler:
	return BattleReviveItemHandler.new(choice, item_data)
