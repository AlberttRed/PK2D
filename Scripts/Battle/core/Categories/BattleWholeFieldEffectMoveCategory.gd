extends BattleMoveCategory

class_name BattleWholeFieldEffectMoveCategory

func _create_handler(move, user, target) -> BattleHandler:
	return BattleWholeFieldEffectMoveHandler.new(move, user, target)
