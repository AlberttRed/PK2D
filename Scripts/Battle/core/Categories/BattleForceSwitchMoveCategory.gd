extends BattleMoveCategory

class_name BattleForceSwitchMoveCategory

func _create_handler(move, user, target) -> BattleHandler:
	return BattleForceSwitchMoveHandler.new(move, user, target)


