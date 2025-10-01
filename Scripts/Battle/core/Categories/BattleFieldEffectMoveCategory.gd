extends BattleMoveCategory

class_name BattleFieldEffectMoveCategory

func _create_handler(move, user, target) -> BattleHandler:
	return BattleFieldEffectMoveHandler.new(move, user, target)


