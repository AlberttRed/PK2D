extends BattleMoveCategory

class_name BattleDamageAilmentMoveCategory

func _create_handler(move, user, target) -> BattleHandler:
	return BattleDamageAilmentMoveHandler.new(move, user, target)
