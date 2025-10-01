extends BattleMoveCategory

class_name BattleOhkoMoveCategory

func _create_handler(move, user, target) -> BattleHandler:
	return BattleOhkoMoveHandler.new(move, user, target)


