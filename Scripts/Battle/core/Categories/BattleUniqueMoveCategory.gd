extends BattleMoveCategory

class_name BattleUniqueMoveCategory

func _create_handler(move, user, target) -> BattleHandler:
	return BattleUniqueMoveHandler.new(move, user, target)


