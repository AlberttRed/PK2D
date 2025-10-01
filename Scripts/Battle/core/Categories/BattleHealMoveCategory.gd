extends BattleMoveCategory

class_name BattleHealMoveCategory

func _create_handler(move, user, target) -> BattleHandler:
	return BattleHealMoveHandler.new(move, user, target)


