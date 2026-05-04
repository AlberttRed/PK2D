extends Resource

class_name BattleItemCategory


func create_handler(choice: BattleBagChoice, item_data: ItemData) -> BattleHandler:
	return _create_handler(choice, item_data)


func _create_handler(_choice: BattleBagChoice, _item_data: ItemData) -> BattleHandler:
	push_error("_create_handler not implemented in " + get_script().resource_path)
	return BattleUnsupportedItemHandler.new(_choice, _item_data)
