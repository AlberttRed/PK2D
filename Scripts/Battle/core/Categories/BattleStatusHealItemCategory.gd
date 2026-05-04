extends BattleItemCategory

class_name BattleStatusHealItemCategory


func _create_handler(choice: BattleBagChoice, item_data: ItemData) -> BattleHandler:
	return BattleStatusHealItemHandler.new(choice, item_data)
