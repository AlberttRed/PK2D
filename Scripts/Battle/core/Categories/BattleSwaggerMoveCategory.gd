extends BattleMoveCategory

class_name BattleSwaggerMoveCategory

func _create_handler(move, user, target) -> BattleHandler:
	return BattleSwaggerMoveHandler.new(move, user, target)


