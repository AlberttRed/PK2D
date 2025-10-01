extends BattleMoveCategory

class_name BattleNetGoodStatsMoveCategory

func _create_handler(move, user, target) -> BattleHandler:
	return BattleNetGoodStatsMoveHandler.new(move, user, target)


