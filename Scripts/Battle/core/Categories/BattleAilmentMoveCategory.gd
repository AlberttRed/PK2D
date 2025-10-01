extends BattleMoveCategory

class_name BattleAilmentMoveCategory

func _create_handler(move, user, target) -> BattleHandler:
	return BattleAilmentMoveHandler.new(move, user, target)
