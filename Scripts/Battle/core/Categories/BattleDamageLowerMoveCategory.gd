extends BattleMoveCategory

class_name BattleDamageLowerMoveCategory

func _create_handler(move, user, target) -> BattleHandler:
	return BattleDamageLowerMoveHandler.new(move, user, target)
