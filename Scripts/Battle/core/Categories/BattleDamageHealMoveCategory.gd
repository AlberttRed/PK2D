extends BattleMoveCategory

class_name BattleDamageHealMoveCategory

func _create_handler(move, user, target) -> BattleHandler:
	return BattleDamageHealMoveHandler.new(move, user, target)


