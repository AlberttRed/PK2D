extends BattleItemCategory

class_name BattleHealingItemCategory


func _create_handler(choice: BattleBagChoice, item_data: ItemData) -> BattleHandler:
	return BattleHealingItemHandler.new(choice, item_data)
